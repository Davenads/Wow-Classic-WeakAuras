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
-- and built-in Send Chat Message actions. Phase 2 adds ONLY an ALLY path here: the hub watches
-- the combat log in battlegrounds, matches friendly casts of the tracked consumables, EXCLUDES
-- the player themselves, and announces them to BG/instance chat tagged "(ally)". Children never
-- touch allies; the hub never touches enemies. No overlap, no double-announce.
if not BGICHub then
    local NS = CreateFrame("Frame", "BGICHub")
    NS.schema = 0                 -- addon-payload/schema version; bumped when the bus format lands
    NS.ADDON_PREFIX = "BGIC"      -- <= 16 chars (C_ChatInfo prefix limit)

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
    }

    -- Cross-child state stores. Populated by later phases (corroboration / rolling log).
    NS.seen      = {}   -- de-dupe: eventKey -> lastServerTime
    NS.witnesses = {}   -- eventKey -> { [strippedSender] = true } (Phase 3 corroboration)
    NS.log       = {}   -- rolling in-memory sighting log (Phase 4 persists to aura_env.saved)

    -- ALLY-callout consumables (Phase 2). SpellIds mirror the v1 children's proven triggers.
    -- AGM trinket (23506) is intentionally EXCLUDED from ally callouts (it is equipment, not a
    -- no-consume-ruleset item); enemies still get the full AGM callouts from the children.
    NS.allyItems = {
        [2379] = "Swiftness Potion",   -- wowhead.com/classic/spell=2379
        [4060] = "Leper Gnome",        -- wowhead.com/classic/spell=4060
        [8892] = "Rocket Boots",       -- wowhead.com/classic/spell=8892
        [2380] = "Resistance Potion",  -- wowhead.com/classic/spell=2380
        [1090] = "Magic Dust",         -- wowhead.com/classic/spell=1090
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

    -- Register the hidden addon bus prefix now (Phase 3 broadcasts/receives on it; inert here).
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(NS.ADDON_PREFIX)
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

    -- Ally path: a friendly cast of a tracked consumable, excluding the player's own casts.
    function NS.onCombatLog()
        local _, sub, _, _, srcName, srcFlags, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()
        if sub ~= "SPELL_CAST_SUCCESS" then return end
        local label = NS.allyItems[spellId]
        if not label then return end
        if not srcFlags then return end
        -- Friendly source only, and never the player themselves.
        if bit.band(srcFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then return end
        if bit.band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 then return end
        if not NS.cfg.announceAllies then return end
        SendChatMessage(
            string.format("[%s] %s used by %s (ally)", NS.stamp(), label, NS.strip(srcName) or "?"),
            NS.smartChannel()
        )
    end

    -- Reset per-match volatile state and (re)arm the combat-log watch on every zone-in. The
    -- CHAT_MSG_ADDON branch is a Phase 3 no-op for now.
    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("CHAT_MSG_ADDON")
    NS:SetScript("OnEvent", function(_, event, prefix)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            NS.onCombatLog()
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            wipe(NS.seen)
            wipe(NS.witnesses)
            wipe(NS.log)
            NS.refreshZone()
            return
        end
        if event == "CHAT_MSG_ADDON" then
            if prefix ~= NS.ADDON_PREFIX then return end
            -- Phase 3: parse payload, dedupe by server-verified sender, aggregate witnesses.
            return
        end
    end)

    -- Handle the case where the hub is created while already inside a BG (import or /reload).
    NS.refreshZone()
end
