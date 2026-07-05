-- WSG Enemy FC Announcer — Actions → On Init (actions.init.custom)
-- Sets up state, config, watchlists, chat channel, and every helper function on
-- aura_env. The trigger / on_show / on_hide blocks only CALL into these helpers.
-- Target: WoW Classic (Era/SoD/HC + Cata/MoP Classic). enUS system/spell strings.
--
-- "Enemy flag carrier" (EFC) = the enemy player carrying YOUR flag (the one you want
-- dead). Identity comes from WSG system messages; live HP/debuffs need a unit token
-- (target/focus/mouseover/nameplate) — so announcements only fire while the EFC is
-- near you or targeted. That range limit is a hard WoW-client constraint.

local c = aura_env.config or {}
aura_env.cfg = {
    enabled  = (c.enabled ~= false),               -- master switch
    mode     = c.channel or "BG",                  -- "BG" = /bg, "SELF" = local print (safe testing)
    prefix   = c.messagePrefix or "EFC",
    minGap   = tonumber(c.minGap) or 3,            -- hard throttle between ANY two sends (s)
    periodic = tonumber(c.periodicInterval) or 5,  -- HP reminder cadence while low (s)
    hpThresh = tonumber(c.hpThreshold) or 65,      -- gate for periodic + snare debuffs (%)
    debuffs  = (c.announceDebuffs ~= false),
}

-- HP milestones (descending). Each announced ONCE on crossing down; re-armed only
-- after the carrier heals back above tier + REARM. Edit to taste.
aura_env.TIERS = { 65, 50, 35, 20 }
local REARM = 5

-- BG chat was renamed INSTANCE_CHAT in patch 4.0, so Cata/MoP Classic differ from Era.
local pid = WOW_PROJECT_ID
aura_env.channel = (pid == WOW_PROJECT_CATACLYSM_CLASSIC or pid == WOW_PROJECT_MISTS_CLASSIC)
    and "INSTANCE_CHAT" or "BATTLEGROUND"

-- Enemy carries OUR flag, so the enemy FC is whoever picked up our own faction's flag.
aura_env.myFlag = UnitFactionGroup("player")       -- "Alliance" / "Horde"

-- Debuff watchlists, keyed by LOWERCASE enUS spell name. Matching by name (not ID)
-- auto-handles Classic's per-rank spell IDs. HARD_CC announces regardless of HP (the
-- team can catch the carrier NOW); SNARE announces only while HP <= hpThresh. enUS only
-- — edit the keys for other locales. Trim/extend these lists freely.
local HARD_CC = {
    ["hammer of justice"]=true, ["kidney shot"]=true, ["cheap shot"]=true,
    ["bash"]=true, ["concussion blow"]=true, ["intimidation"]=true, ["war stomp"]=true,
    ["frost nova"]=true, ["entangling roots"]=true, ["counterattack"]=true, ["frostbite"]=true,
    ["polymorph"]=true, ["freezing trap effect"]=true, ["blind"]=true, ["gouge"]=true,
    ["sap"]=true, ["fear"]=true, ["psychic scream"]=true, ["seduction"]=true,
    ["howl of terror"]=true, ["scatter shot"]=true,
}
local SNARE = {
    ["hamstring"]=true, ["crippling poison"]=true, ["wing clip"]=true,
    ["concussive shot"]=true, ["frost shock"]=true, ["curse of exhaustion"]=true,
    ["piercing howl"]=true, ["mind flay"]=true, ["cone of cold"]=true,
    ["blast wave"]=true, ["chilled"]=true, ["frostbolt"]=true, ["earthbind"]=true,
}

local function strip(name) return name and (name:gsub("%-.*$", "")) or name end

-- ── state ─────────────────────────────────────────────────────────────────────
local function newState()
    return { name=nil, guid=nil, unit=nil, hp=nil,
             lastSent=0, lastPeriodic=0, seen={}, tier={} }
end
aura_env.efc = aura_env.efc or newState()

function aura_env.Reset()
    aura_env.efc = newState()
end

function aura_env.SetEFC(name)
    local e = aura_env.efc
    e.name, e.guid, e.unit, e.hp = name, nil, nil, nil
    e.lastPeriodic = 0
    wipe(e.seen); wipe(e.tier)
    aura_env.ResolveUnit()
end

function aura_env.ClearEFC()
    local e = aura_env.efc
    e.name, e.guid, e.unit, e.hp = nil, nil, nil, nil
    wipe(e.seen); wipe(e.tier)
end

-- ── send (with global anti-spam throttle) ─────────────────────────────────────
function aura_env.Announce(body)
    local cfg, e = aura_env.cfg, aura_env.efc
    if not cfg.enabled then return end
    local now = GetTime()
    if now - e.lastSent < cfg.minGap then return end       -- drop: too soon
    if cfg.mode == "SELF" then
        print("|cff33ff99[EFC]|r " .. body)                -- local only (safe testing)
    else
        SendChatMessage(cfg.prefix .. " " .. body, aura_env.channel)
    end
    e.lastSent = now
end

-- ── unit acquisition (target/focus/mouseover/nameplate → GUID lock) ───────────
local function matches(u)
    local e = aura_env.efc
    if not u or not UnitExists(u) then return false end
    if e.guid then return UnitGUID(u) == e.guid end
    if not e.name then return false end
    return strip(UnitName(u)) == e.name and UnitCanAttack("player", u)
end

function aura_env.ResolveUnit()
    local e = aura_env.efc
    if not e.name then e.unit = nil; return nil end
    if matches(e.unit) then return e.unit end
    local cands = { "target", "focus", "mouseover" }
    for _, u in ipairs(cands) do
        if matches(u) then e.unit = u; e.guid = e.guid or UnitGUID(u); return u end
    end
    for i = 1, 40 do
        local u = "nameplate" .. i
        if matches(u) then e.unit = u; e.guid = e.guid or UnitGUID(u); return u end
    end
    e.unit = nil
    return nil
end

-- ── periodic HP tick (driven by on_show's 1s ticker + UNIT_HEALTH) ────────────
local function fmtHP(hp) return aura_env.efc.name .. " " .. math.floor(hp + 0.5) .. "%" end

function aura_env.Tick()
    local e, cfg = aura_env.efc, aura_env.cfg
    if not e.name then return end
    local u = aura_env.ResolveUnit()
    if not u or UnitIsDeadOrGhost(u) then return end
    local maxhp = UnitHealthMax(u)
    if not maxhp or maxhp <= 0 then return end
    local hp = UnitHealth(u) / maxhp * 100
    e.hp = hp
    for _, t in ipairs(aura_env.TIERS) do
        if hp <= t then
            if not e.tier[t] then e.tier[t] = true; aura_env.Announce(fmtHP(hp)) end
        elseif hp > t + REARM then
            e.tier[t] = nil
        end
    end
    if hp <= cfg.hpThresh and (GetTime() - e.lastPeriodic) >= cfg.periodic then
        e.lastPeriodic = GetTime()
        aura_env.Announce(fmtHP(hp))
    end
end

-- ── system-message parser (identity of the enemy flag carrier) ────────────────
function aura_env.OnSystem(msg)
    if type(msg) ~= "string" then return end
    local faction = msg:match("The (%a+) [Ff]lag")
    local picked  = msg:match("[Ff]lag was picked up by (.-)!")
    if picked and faction == aura_env.myFlag then
        aura_env.SetEFC(strip(picked))
    elseif faction == aura_env.myFlag and (msg:find("was dropped by") or msg:find("was returned")) then
        aura_env.ClearEFC()
    elseif msg:find("[Cc]aptured") or msg:find("flags are reset")
        or msg:find("flags are now placed") or msg:find("battle has begun") then
        aura_env.ClearEFC()
    end
end

-- ── combat log (new debuffs + death) ──────────────────────────────────────────
function aura_env.OnCLEU()
    local e = aura_env.efc
    if not e.name then return end
    local _, sub, _, _, _, _, _, dstGUID, dstName, _, _, _, spellName, _, auraType =
        CombatLogGetCurrentEventInfo()
    if e.guid then
        if dstGUID ~= e.guid then return end
    else
        if strip(dstName) ~= e.name then return end
        e.guid = dstGUID                                    -- lock onto GUID once seen
    end
    if sub == "UNIT_DIED" then
        aura_env.Announce(e.name .. " is DOWN")
        aura_env.ClearEFC()                                 -- flag drops on death anyway
        return
    end
    if not aura_env.cfg.debuffs then return end
    if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
        if auraType ~= "DEBUFF" or not spellName then return end
        local key = spellName:lower()
        local hard, snare = HARD_CC[key], SNARE[key]
        if (not hard and not snare) or e.seen[key] then return end
        if hard then
            e.seen[key] = true
            local hp = e.hp and (" " .. math.floor(e.hp + 0.5) .. "%") or ""
            aura_env.Announce(e.name .. hp .. " — " .. spellName)
        elseif e.hp and e.hp <= aura_env.cfg.hpThresh then
            e.seen[key] = true
            aura_env.Announce(e.name .. " " .. math.floor(e.hp + 0.5) .. "% — " .. spellName)
        end
    elseif sub == "SPELL_AURA_REMOVED" then
        if spellName then e.seen[spellName:lower()] = nil end  -- allow re-announce on reapply
    end
end
