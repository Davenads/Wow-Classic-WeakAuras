-- WSG Enemy FC Announcer — Actions → On Init (actions.init.custom)
-- Sets up state, config, watchlists, chat channel, and every helper function on
-- aura_env. The trigger / on_show / on_hide blocks only CALL into these helpers.
-- Target: WoW Classic (Era/SoD/HC + Cata/MoP Classic). enUS system/spell strings.
--
-- "Enemy flag carrier" (EFC) = the enemy player carrying YOUR flag (the one you want
-- dead). Identity comes from WSG system messages.
--
-- HP MODEL (adapted from wago "WSG Flag Carrier Names" gpIg2OhpG, the community
-- messager this piggybacks on):
--   * Your OWN read: any unit token on the EFC (target/focus/mouseover/nameplate) OR
--     the *raidNtarget* scan — the HP of whatever ANY raid member is targeting. That
--     crowdsources the read across the whole team, not just your own target.
--   * Shared read: broadcast our direct read over addon prefix "WSGFCNamesHP" (the
--     SAME prefix + "name@hp" format the original uses) so we interoperate with the
--     large existing userbase, and receive theirs for the on-screen readout.
--   * ANTI-SPAM RULE: chat /bg announces (HP milestones, periodic, debuffs, DR) fire
--     ONLY from the client that DIRECTLY witnessed them. Received addon HP updates the
--     display only — it is never re-announced. So a raid full of this aura does not
--     multiply /bg spam; chat itself is the human-readable bus for debuff/DR calls.

local c = aura_env.config or {}
aura_env.cfg = {
    enabled    = (c.enabled ~= false),              -- master switch
    chat       = (c.announceChat ~= false),         -- master for ALL /bg sends
    hp         = (c.announceHP ~= false),           -- HP milestones + periodic
    debuffs    = (c.announceDebuffs ~= false),      -- hard-CC / snare calls
    dr         = (c.announceDR ~= false),           -- diminishing-returns calls
    share      = (c.shareAddon ~= false),           -- send/receive HP over addon bus
    mode       = c.channel or "BG",                 -- "BG" (/bg) | "RAID" (/ra) | "SELF" (local print)
    prefix     = c.messagePrefix or "EFC",
    minGap     = tonumber(c.minGap) or 3,           -- hard throttle between ANY two sends (s)
    periodic   = tonumber(c.periodicInterval) or 5, -- HP reminder cadence while low (s)
    hpThresh   = tonumber(c.hpThreshold) or 65,     -- gate for periodic + snare debuffs (%)
    widget     = (c.useWidget ~= false),            -- hook the top-center flag widget if present
}

-- HP milestones (descending %). Each announced ONCE on crossing down; re-armed only
-- after the carrier heals back above tier + REARM.
aura_env.TIERS = { 65, 50, 35, 20 }
local REARM = 5

-- Addon bus (interop with the original messager). Fraction HP as "name@0.4213".
local ADDON_PREFIX = "WSGFCNamesHP"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
end
aura_env.ADDON_PREFIX = ADDON_PREFIX

-- Chat channel: BG chat was renamed INSTANCE_CHAT in patch 4.0 (Cata/MoP Classic).
local pid = WOW_PROJECT_ID
aura_env.bgChannel = (pid == WOW_PROJECT_CATACLYSM_CLASSIC or pid == WOW_PROJECT_MISTS_CLASSIC)
    and "INSTANCE_CHAT" or "BATTLEGROUND"

-- Effective faction (mercenary-mode aware): a merc fights for the OTHER side, so the
-- enemy FC is the carrier of your EFFECTIVE faction's flag. 81748/81744 are the merc
-- buffs the original checks; if absent (or on flavors without merc mode) we fall back
-- to UnitFactionGroup. Guarded so a nil spell id can't error.
local function detectFaction()
    if GetSpellInfo and AuraUtil and AuraUtil.FindAuraByName then
        local ally = GetSpellInfo(81748)
        local horde = GetSpellInfo(81744)
        if ally and AuraUtil.FindAuraByName(ally, "player") then return "Alliance" end
        if horde and AuraUtil.FindAuraByName(horde, "player") then return "Horde" end
    end
    return UnitFactionGroup("player")
end
aura_env.myFaction = detectFaction()

-- Debuff watchlists, keyed by LOWERCASE enUS spell name (matching by name auto-handles
-- Classic's per-rank spell IDs). HARD_CC announces regardless of HP; SNARE only while
-- HP <= hpThresh. enUS only — edit keys for other locales.
local HARD_CC = {
    ["hammer of justice"]=true, ["kidney shot"]=true, ["cheap shot"]=true,
    ["bash"]=true, ["concussion blow"]=true, ["intimidation"]=true, ["war stomp"]=true,
    ["frost nova"]=true, ["entangling roots"]=true, ["counterattack"]=true, ["frostbite"]=true,
    ["polymorph"]=true, ["freezing trap effect"]=true, ["blind"]=true, ["gouge"]=true,
    ["sap"]=true, ["fear"]=true, ["psychic scream"]=true, ["seduction"]=true,
    ["howl of terror"]=true, ["scatter shot"]=true, ["intimidating shout"]=true,
    ["wyvern sting"]=true, ["repentance"]=true, ["scare beast"]=true,
}
local SNARE = {
    ["hamstring"]=true, ["crippling poison"]=true, ["wing clip"]=true,
    ["concussive shot"]=true, ["frost shock"]=true, ["curse of exhaustion"]=true,
    ["piercing howl"]=true, ["mind flay"]=true, ["cone of cold"]=true,
    ["blast wave"]=true, ["chilled"]=true, ["frostbolt"]=true, ["earthbind"]=true,
    ["dazed"]=true, ["improved hamstring"]=true, ["daze"]=true,
}

-- Diminishing-returns categories, keyed by LOWERCASE enUS spell name. DR membership is
-- FLAVOR-SPECIFIC (Era vs Cata differ) — VERIFY in-game before trusting; edit freely.
-- Spells not listed here are still announced as CC, they just don't feed the DR chain.
local DR_CAT = {
    -- stuns
    ["hammer of justice"]="stun", ["kidney shot"]="stun", ["cheap shot"]="stun",
    ["bash"]="stun", ["concussion blow"]="stun", ["intimidation"]="stun",
    ["war stomp"]="stun", ["pounce"]="stun",
    -- roots
    ["frost nova"]="root", ["entangling roots"]="root", ["frostbite"]="root",
    ["counterattack"]="root",
    -- fears
    ["fear"]="fear", ["psychic scream"]="fear", ["howl of terror"]="fear",
    ["seduction"]="fear", ["intimidating shout"]="fear", ["scare beast"]="fear",
    -- incapacitates
    ["polymorph"]="incap", ["gouge"]="incap", ["sap"]="incap",
    ["freezing trap effect"]="incap", ["wyvern sting"]="incap", ["repentance"]="incap",
    -- disorients
    ["blind"]="disorient", ["scatter shot"]="disorient",
}
-- The multiplier the NEXT application in-category will get after N applications.
local DR_NEXT = { [1]="50%", [2]="75%", [3]="IMMUNE" }
local DR_RESET = 18   -- seconds after a DR debuff fades before the category resets

local function strip(name) return name and (name:gsub("%-.*$", "")) or name end
aura_env.strip = strip

-- ── state ─────────────────────────────────────────────────────────────────────
local function newState()
    return { name=nil, guid=nil, unit=nil,
             hp=nil, hpTS=0,                 -- our own direct read (fraction) + timestamp
             recvHP=nil, recvTS=0,           -- addon-received read (fraction) + timestamp
             lastSent=0, lastPeriodic=0, lastCast=0,
             seen={}, tier={}, dr={} }
end
aura_env.efc = aura_env.efc or newState()

function aura_env.Reset() aura_env.efc = newState() end

function aura_env.SetEFC(name)
    local e = aura_env.efc
    e.name, e.guid, e.unit = name, nil, nil
    e.hp, e.hpTS, e.recvHP, e.recvTS = nil, 0, nil, 0
    e.lastPeriodic = 0
    wipe(e.seen); wipe(e.tier); wipe(e.dr)
end

function aura_env.ClearEFC()
    local e = aura_env.efc
    e.name, e.guid, e.unit = nil, nil, nil
    e.hp, e.recvHP = nil, nil
    wipe(e.seen); wipe(e.tier); wipe(e.dr)
end

-- ── send (with global anti-spam throttle) ─────────────────────────────────────
function aura_env.Announce(body)
    local cfg, e = aura_env.cfg, aura_env.efc
    if not cfg.enabled or not cfg.chat then return end
    local now = GetTime()
    if now - e.lastSent < cfg.minGap then return end          -- drop: too soon
    if cfg.mode == "SELF" then
        print("|cff33ff99[EFC]|r " .. body)                   -- local only (safe testing)
    else
        local ch = (cfg.mode == "RAID") and "RAID" or aura_env.bgChannel
        SendChatMessage(cfg.prefix .. " " .. body, ch)
    end
    e.lastSent = now
end

-- ── HP acquisition (own token OR raidNtarget crowdsource) ─────────────────────
local function nameOf(unit)
    if not UnitExists(unit) then return nil end
    local n, realm = UnitName(unit)
    if realm and realm ~= "" then return n .. "-" .. realm end
    return n
end

local function tokenMatches(u)
    local e = aura_env.efc
    if not u or not UnitExists(u) then return false end
    if e.guid then return UnitGUID(u) == e.guid end
    if not e.name then return false end
    return strip(UnitName(u)) == e.name and UnitCanAttack("player", u)
end

-- Return the EFC's HP fraction (0-1) from a live unit token, or nil. Also GUID-locks
-- the EFC the first time any token resolves (tightens later CLEU + token matching).
function aura_env.ReadEnemyHP()
    local e = aura_env.efc
    if not e.name then return nil end
    local function fromUnit(u)
        if not tokenMatches(u) then return nil end
        e.unit = u
        e.guid = e.guid or UnitGUID(u)
        local mx = UnitHealthMax(u)
        if mx and mx > 0 then return UnitHealth(u) / mx end
        return nil
    end
    -- own tokens first (cheap, and they GUID-lock)
    for _, u in ipairs({ "target", "focus", "mouseover" }) do
        local hp = fromUnit(u); if hp then return hp end
    end
    -- nameplates (enemy nameplates must be ON)
    for i = 1, 40 do
        local hp = fromUnit("nameplate" .. i); if hp then return hp end
    end
    -- crowdsource: HP of whatever any raid member is targeting
    for i = 1, 40 do
        local u = "raid" .. i .. "target"
        if UnitExists(u) and strip(UnitName(u)) == e.name and UnitCanAttack("player", u) then
            e.guid = e.guid or UnitGUID(u)
            local mx = UnitHealthMax(u)
            if mx and mx > 0 then return UnitHealth(u) / mx end
        end
    end
    return nil
end

-- Broadcast our direct read so peers (incl. users of the original messager) can display
-- it. Throttled; never used to re-announce chat (display only on the receiving side).
function aura_env.BroadcastHP(frac)
    local e, cfg = aura_env.efc, aura_env.cfg
    if not cfg.share or not e.name or not frac then return end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local now = GetTime()
    if now - (aura_env.lastBroadcast or 0) < 1 then return end
    aura_env.lastBroadcast = now
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX,
        string.format("%s@%.4f", e.name, frac), aura_env.bgChannel)
end

-- Receive a peer's HP read (display only — see ANTI-SPAM RULE at top).
function aura_env.OnAddon(prefix, msg, _, sender)
    local e = aura_env.efc
    if prefix ~= ADDON_PREFIX or not e.name or type(msg) ~= "string" then return end
    if sender and strip(sender) == strip(UnitName("player")) then return end  -- ignore self
    local name = msg:match("^(.*)@")
    local hp = tonumber(msg:match("@(.+)$") or "")
    if name and hp and strip(name) == e.name then
        e.recvHP, e.recvTS = hp, GetTime()
    end
end

-- Best HP fraction to DISPLAY: our fresh direct read, else a fresh received value.
function aura_env.DisplayHP()
    local e = aura_env.efc
    local now = GetTime()
    if e.hp and (now - e.hpTS) < 3 then return e.hp, false end
    if e.recvHP and (now - e.recvTS) < 5 then return e.recvHP, true end
    return nil, false
end

-- ── periodic HP tick (on_show's 1s ticker + UNIT_HEALTH) ──────────────────────
function aura_env.Tick()
    local e, cfg = aura_env.efc, aura_env.cfg
    if not e.name then return end
    local frac = aura_env.ReadEnemyHP()          -- our DIRECT read (nil if nobody sees FC)
    if frac then
        e.hp, e.hpTS = frac, GetTime()
        aura_env.BroadcastHP(frac)
        if cfg.hp then
            local pct = frac * 100
            for _, t in ipairs(aura_env.TIERS) do
                if pct <= t then
                    if not e.tier[t] then e.tier[t] = true
                        aura_env.Announce(e.name .. " " .. math.floor(pct + 0.5) .. "%") end
                elseif pct > t + REARM then
                    e.tier[t] = nil
                end
            end
            if pct <= cfg.hpThresh and (GetTime() - e.lastPeriodic) >= cfg.periodic then
                e.lastPeriodic = GetTime()
                aura_env.Announce(e.name .. " " .. math.floor(pct + 0.5) .. "%")
            end
        end
    end
    aura_env.UpdateWidget()
end

-- ── system-message parser (identity of the enemy flag carrier) ────────────────
-- Enemy carries YOUR (effective) faction's flag, so the EFC is whoever picked up the
-- flag whose faction == myFaction. Case-insensitive to survive Blizzard's mixed casing
-- ("The Alliance Flag" vs "The Horde flag").
function aura_env.OnSystem(msg)
    if type(msg) ~= "string" then return end
    local faction = msg:match("[Tt]he (%a+) [Ff]lag")
    if not faction then
        if msg:find("[Cc]aptured") or msg:find("flags are reset")
           or msg:find("flags are now placed") or msg:find("battle has begun") then
            aura_env.ClearEFC()
        end
        return
    end
    if faction ~= aura_env.myFaction then return end           -- not OUR flag → ignore
    local picked = msg:match("picked up by (.-)!")
    if picked then
        aura_env.SetEFC(strip(picked))
    elseif msg:find("was dropped by") or msg:find("was returned") or msg:find("[Cc]aptured") then
        aura_env.ClearEFC()
    end
end

-- ── combat log (new debuffs + DR + death) ─────────────────────────────────────
function aura_env.OnCLEU()
    local e = aura_env.efc
    if not e.name then return end
    local _, sub, _, _, _, _, _, dstGUID, dstName, _, _, _, spellName, _, auraType =
        CombatLogGetCurrentEventInfo()
    if e.guid then
        if dstGUID ~= e.guid then return end
    else
        if strip(dstName or "") ~= e.name then return end
        e.guid = dstGUID                                       -- lock onto GUID once seen
    end

    if sub == "UNIT_DIED" then
        aura_env.Announce(e.name .. " is DOWN")
        aura_env.ClearEFC()                                    -- flag drops on death anyway
        return
    end
    if not spellName then return end
    local now = GetTime()

    if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
        if auraType ~= "DEBUFF" then return end
        local key = spellName:lower()

        -- DR chain (only on fresh applications, not refreshes)
        local cat = DR_CAT[key]
        if cat and aura_env.cfg.dr and sub == "SPELL_AURA_APPLIED" then
            local s = e.dr[cat]
            if not s or now > (s.resetAt or 0) then s = { apps = 0 }; e.dr[cat] = s end
            s.apps = math.min(s.apps + 1, 4)
            s.resetAt = now + DR_RESET
            local nextLevel = DR_NEXT[s.apps]
            if nextLevel then
                aura_env.Announce(e.name .. " " .. cat .. " DR: next " .. nextLevel)
            end
        end

        -- debuff call (deduped per application via e.seen)
        if aura_env.cfg.debuffs and not e.seen[key] then
            local hard, snare = HARD_CC[key], SNARE[key]
            local pct = e.hp and (" " .. math.floor(e.hp * 100 + 0.5) .. "%") or ""
            if hard then
                e.seen[key] = true
                aura_env.Announce(e.name .. pct .. " — " .. spellName)
            elseif snare and e.hp and (e.hp * 100) <= aura_env.cfg.hpThresh then
                e.seen[key] = true
                aura_env.Announce(e.name .. " " .. math.floor(e.hp * 100 + 0.5) .. "% — " .. spellName)
            end
        end
    elseif sub == "SPELL_AURA_REMOVED" then
        local key = spellName:lower()
        e.seen[key] = nil                                      -- allow re-announce on reapply
        local cat = DR_CAT[key]
        if cat and e.dr[cat] then e.dr[cat].resetAt = now + DR_RESET end  -- DR window from fade
    end
end

-- ── on-screen readout ─────────────────────────────────────────────────────────
-- The %c custom_text fallback uses this string; the widget hook (below) uses it too.
function aura_env.ReadoutText()
    local e = aura_env.efc
    if not e or not e.name then return "" end
    local hp, received = aura_env.DisplayHP()
    if not hp then return "|cffff5555EFC|r " .. e.name end
    local col = received and "|cff7f7f7f" or "|cffffffff"
    return "|cffff5555EFC|r " .. e.name .. col .. string.format(" %.0f%%|r", hp * 100)
end

-- ── optional: hook the top-center flag-capture widget (Cata/MoP/retail UI) ─────
-- On flavors WITH the modern UI-widget flag display (UIWidgetTopCenterContainerFrame),
-- attach a small font string next to the flag score showing the EFC + HP. Absent on
-- Classic Era (old WorldState frames) — there we silently fall back to the %c region.
-- Kept defensive (no pcall — the sandbox blocks it) and combat-safe (no frame creation
-- in combat). Adapted from the wago original's init_fc_text.
function aura_env.InitWidget()
    if not aura_env.cfg.widget then return end
    if not (UIWidgetTopCenterContainerFrame and UIWidgetTopCenterContainerFrame.GetChildren) then return end
    if InCombatLockdown() then return end
    local kids = { UIWidgetTopCenterContainerFrame:GetChildren() }
    for _, f in ipairs(kids) do
        if f and (f.tooltip == "Horde flag captures" or f.tooltip == "Alliance flag captures") then
            if not f.EFC_TEXT then
                local fs = f:CreateFontString(nil, "ARTWORK")
                fs:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
                fs:SetPoint("LEFT", f, "RIGHT", 6, 0)
                fs:SetText("")
                f.EFC_TEXT = fs
            end
            -- The enemy carries OUR flag; that counter is labelled with OUR faction.
            if f.tooltip == (aura_env.myFaction .. " flag captures") then
                aura_env.widgetText = f.EFC_TEXT
            end
        end
    end
end

function aura_env.UpdateWidget()
    if aura_env.widgetText then
        aura_env.widgetText:SetText(aura_env.ReadoutText())
    end
end

aura_env.InitWidget()
