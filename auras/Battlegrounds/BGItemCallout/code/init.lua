-- Betty's BG Item Callout (19 bracket) — Actions → On Init (GROUP container)
-- Pastes into: WA options → (the GROUP) → Actions → On Init → Custom code.
--
-- Creates the shared BGICHub named global frame exactly once. WeakAuras children do NOT share
-- aura_env, so any cross-child state (server-time stamps, ally detection, multi-witness
-- corroboration, the addon bus) must live on a *named* global frame — the mechanism proven by
-- WSGCalloutHub in this repo. If a dynamicgroup's On Init proves unreliable in-game, paste this
-- same (idempotent) block into any one child's On Init instead.
--
-- ENEMY callouts are UNCHANGED: the 10 children keep their Hostile-filtered combat-log triggers
-- and built-in Send Chat Message actions.
--   Phase 2 — the hub also ANNOUNCES friendly (ally) consumable use, tagged "(ally)", self
--             excluded. Children never touch allies; the hub never touches enemy announces.
--   Phase 3a — the hub also CORROBORATES: every first-hand sighting (enemy OR ally, not self) is
--             recorded and broadcast on the hidden BGIC addon bus; incoming broadcasts are
--             aggregated into a per-event witness set keyed by the caster's GUID + spellId + a
--             server-time bucket. The `sender` of a CHAT_MSG_ADDON is server-stamped and cannot
--             be spoofed — that is the whole basis of the anti-forgery evidence. This runs
--             SILENTLY: no visible chat change (live witness-count tag + announce election are
--             Phase 3b; the on-demand report that surfaces the ledger is Phase 4). Toggle
--             BGICHub.cfg.debug = true to watch the ledger build in-game.
if not BGICHub then
    local NS = CreateFrame("Frame", "BGICHub")
    NS.schema = 1                 -- addon-payload/schema version (Phase 3a: "1|EVT|..." format)
    NS.ADDON_PREFIX = "BGIC"      -- <= 16 chars (C_ChatInfo prefix limit)
    NS.WINDOW = 4                 -- event-key time bucket in seconds (±1 bucket tolerance on match)

    -- Realm-strip a name: "Betty-Whitemane" -> "Betty".
    local function strip(n) return n and n:gsub("%-.*$", "") or n end
    NS.strip = strip

    -- Server-synced wall clock: identical integer for every client on the realm. This is both
    -- the human timestamp source (Phase 1) and the cross-witness event-key clock (Phase 3).
    function NS.now()
        return (GetServerTime and GetServerTime()) or time()
    end
    -- Timestamp formatters. NS.stamp() is the live HH:MM:SS used on every callout (enemy + ally).
    function NS.stamp(t)      return date("%H:%M:%S", t or NS.now()) end          -- live chat
    function NS.stampFull(t)  return date("%m/%d/%y %H:%M:%S", t or NS.now()) end -- log/report

    -- Locked config defaults (2026-09-03 decisions). Custom Options may override in later phases.
    -- See .plans/bg-item-callout/00-overview.md section 5.
    NS.cfg = {
        trackAllies    = true,        -- detect friendly casters (Phase 2)
        announceAllies = true,        -- announce ally use in BG/instance chat (not silent-log)
        corroborate    = true,        -- multi-witness aggregation over the addon bus (Phase 3)
        minWitnesses   = 2,           -- >= 2 distinct server-verified witnesses == "evidence"
        reportMode     = "ondemand",  -- corroboration report is posted on demand, not auto-spam
        debug          = false,       -- when true, print each recorded witness to chat (testing)
    }

    -- Cross-child / cross-witness state (wiped each match on PLAYER_ENTERING_WORLD).
    NS.seen      = {}   -- eventKey -> serverTime  : keys WE have already broadcast (send-once)
    NS.witnesses = {}   -- eventKey -> { [strippedName] = true }  : distinct server-verified witnesses
    NS.events    = {}   -- eventKey -> { guid, spellId, label, reaction, name, t }  : sighting record
    NS.log       = {}   -- ordered list of eventKeys (insertion order; Phase 4 persists to saved)

    -- Consumables the hub WATCHES on _CAST_SUCCESS. SpellIds mirror the v1 children's proven
    -- triggers. Used for corroboration of BOTH enemy and ally casts.
    NS.trackedItems = {
        [2379]  = "Swiftness Potion",   -- wowhead.com/classic/spell=2379
        [4060]  = "Leper Gnome",        -- wowhead.com/classic/spell=4060
        [8892]  = "Rocket Boots",       -- wowhead.com/classic/spell=8892
        [2380]  = "Resistance Potion",  -- wowhead.com/classic/spell=2380
        [1090]  = "Magic Dust",         -- wowhead.com/classic/spell=1090
        [23506] = "AGM trinket",        -- wowhead.com/classic/spell=23506
    }
    -- Subset that produces an ALLY chat callout. AGM (23506) is intentionally EXCLUDED from ally
    -- callouts (equipment, not a no-consume-ruleset item); it is still corroborated above, and
    -- enemies still get the full AGM callouts from the children.
    NS.allyAnnounce = {
        [2379] = true, [4060] = true, [8892] = true, [2380] = true, [1090] = true,
    }

    -- Mirror of WeakAuras' "SMARTRAID" routing so ally callouts land in the same channel the
    -- enemy children use. In a battleground you are in an instance group -> INSTANCE_CHAT (BG
    -- chat); the other branches are safety fallbacks for grouped/solo testing outside a BG.
    function NS.smartChannel()
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
        if IsInRaid() then return "RAID" end
        if IsInGroup() then return "PARTY" end
        return "SAY"
    end

    -- Register the hidden addon bus prefix. Phase 3 broadcasts + receives event attestations.
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(NS.ADDON_PREFIX)
    end

    -- ---- Corroboration engine (Phase 3a) --------------------------------------------------
    -- Canonical event key = casterGUID | spellId | serverTimeBucket. GUID (not the spoofable
    -- name) is the record key; the bucket lets witnesses whose detection times differ slightly
    -- still agree. resolveKey() applies a ±1 bucket tolerance so a boundary can't split one event.
    local function bucketOf(t) return math.floor(t / NS.WINDOW) end
    local function keyFor(guid, spellId, bucket) return guid .. "|" .. spellId .. "|" .. bucket end
    function NS.resolveKey(guid, spellId, t)
        local b = bucketOf(t)
        for _, d in ipairs({ 0, -1, 1 }) do
            local k = keyFor(guid, spellId, b + d)
            if NS.witnesses[k] then return k end
        end
        return keyFor(guid, spellId, b)
    end

    function NS.witnessCount(key)
        local n, w = 0, NS.witnesses[key]
        if w then for _ in pairs(w) do n = n + 1 end end
        return n
    end

    local function recordEvent(key, guid, spellId, reaction, name)
        local e = NS.events[key]
        if not e then
            e = {
                guid     = guid,
                spellId  = spellId,
                label    = NS.trackedItems[spellId],
                reaction = reaction,
                name     = NS.strip(name),
                t        = NS.now(),
            }
            NS.events[key] = e
            NS.log[#NS.log + 1] = key
        elseif reaction and not e.reaction then
            e.reaction = reaction               -- fill reaction if the local sighting arrives later
        end
        return e
    end

    local function recordWitness(key, who)
        who = NS.strip(who)
        if not who or who == "" then return end
        local w = NS.witnesses[key]
        if not w then w = {}; NS.witnesses[key] = w end
        w[who] = true
    end

    -- Broadcast OUR first-hand sighting once per key. Payload (<=255): schema|EVT|guid|spellId|
    -- serverTime|reactionChar|name. Receivers key on guid+spellId+bucket; name is display-only.
    local function broadcast(guid, spellId, t, reactionChar, name)
        if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
        local payload = string.format("%d|EVT|%s|%d|%d|%s|%s",
            NS.schema, guid, spellId, t, reactionChar, NS.strip(name) or "?")
        if #payload > 255 then payload = payload:sub(1, 255) end
        C_ChatInfo.SendAddonMessage(NS.ADDON_PREFIX, payload, "INSTANCE_CHAT")
    end

    -- Fold in a first-hand local sighting: record the event + ourselves as a witness, then
    -- broadcast (send-once per key). Caller has already excluded self-casts.
    local function witnessLocal(guid, spellId, reaction, name)
        if not NS.cfg.corroborate then return end
        if not guid or guid == "" then return end
        local now = NS.now()
        local key = NS.resolveKey(guid, spellId, now)
        recordEvent(key, guid, spellId, reaction, name)
        recordWitness(key, UnitName("player"))
        if not NS.seen[key] then
            NS.seen[key] = now
            broadcast(guid, spellId, now, reaction == "ally" and "a" or "e", name)
        end
        if NS.cfg.debug then
            print("|cff88ccffBGIC|r " .. reaction .. " " .. (NS.trackedItems[spellId] or "?")
                .. " by " .. (NS.strip(name) or "?") .. " — witnesses: " .. NS.witnessCount(key))
        end
    end

    -- Receive another witness's attestation. `sender` is server-stamped (unspoofable) — that is
    -- the only trusted field; the payload's name/reaction are display-only.
    function NS.onAddon(payload, sender)
        if not NS.cfg.corroborate then return end
        if type(payload) ~= "string" then return end
        local ver, kind, guid, spellIdStr, tStr, rc, name = strsplit("|", payload)
        if kind ~= "EVT" then return end
        if tonumber(ver) ~= NS.schema then return end
        local spellId, t = tonumber(spellIdStr), tonumber(tStr)
        if not (guid and guid ~= "" and spellId and t) then return end
        if not NS.trackedItems[spellId] then return end
        local reaction = rc == "a" and "ally" or "enemy"
        local key = NS.resolveKey(guid, spellId, t)
        recordEvent(key, guid, spellId, reaction, name)
        recordWitness(key, sender)
        if NS.cfg.debug then
            print("|cff88ccffBGIC|r +witness " .. (NS.strip(sender) or "?") .. " for "
                .. (NS.trackedItems[spellId] or "?") .. " — witnesses: " .. NS.witnessCount(key))
        end
    end

    -- Combat log: a tracked consumable _CAST_SUCCESS. Corroborate any non-self cast (enemy or
    -- ally); additionally announce ally use (Phase 2) for the five ally-announce items.
    function NS.onCombatLog()
        local _, sub, _, srcGUID, srcName, srcFlags, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()
        if sub ~= "SPELL_CAST_SUCCESS" then return end
        if not NS.trackedItems[spellId] then return end
        if not srcFlags then return end

        local isSelf     = bit.band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0
        if isSelf then return end
        local isFriendly = bit.band(srcFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) ~= 0
        local reaction   = isFriendly and "ally" or "enemy"

        -- Corroboration (Phase 3a): record + broadcast our own sighting of enemy AND ally casts.
        witnessLocal(srcGUID, spellId, reaction, srcName)

        -- Ally announce (Phase 2): friendly, and one of the five ally-announce items (AGM excluded).
        if isFriendly and NS.cfg.announceAllies and NS.allyAnnounce[spellId] then
            SendChatMessage(
                string.format("[%s] %s used by %s (ally)", NS.stamp(), NS.trackedItems[spellId], NS.strip(srcName) or "?"),
                NS.smartChannel()
            )
        end
    end

    -- Only watch the combat log while inside a battleground, and only if ally tracking is on.
    function NS.refreshZone()
        local _, instanceType = IsInInstance()
        if NS.cfg.trackAllies and instanceType == "pvp" then
            NS:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        else
            NS:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        end
    end

    -- Reset per-match volatile state and (re)arm the combat-log watch on every zone-in.
    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("CHAT_MSG_ADDON")
    NS:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            NS.onCombatLog()
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            wipe(NS.seen)
            wipe(NS.witnesses)
            wipe(NS.events)
            wipe(NS.log)
            NS.refreshZone()
            return
        end
        if event == "CHAT_MSG_ADDON" then
            -- args: prefix(a1), text(a2), channel(a3), sender(a4)
            if a1 ~= NS.ADDON_PREFIX then return end
            NS.onAddon(a2, a4)
            return
        end
    end)

    -- Handle the case where the hub is created while already inside a BG (import or /reload).
    NS.refreshZone()
end
