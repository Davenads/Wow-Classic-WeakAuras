-- WSG Tremor Fear Alert — Actions → On Init (actions.init.custom)
-- Personal HUD for a Shaman in Warsong Gulch: a big on-screen call (+ sound) when a
-- nearby ally is hit by a fear/charm/sleep effect Tremor Totem can remove, and a pre-alert
-- when an enemy BEGINS casting a fearing spell you can pre-empt.
-- Target: WoW Classic (Era/SoD/HC + Cata/MoP Classic). enUS spell/aura strings.
--
-- WHY THIS SPLIT (it mirrors the spell mechanics):
--   * ALLY side is a DIRECT READ — UnitDebuff on friendly units is reliable on Classic, so
--     "is someone I can save feared right now?" is truth, not a guess. Tremor pulses every
--     ~3s and clears Fear/Charm/Sleep, so the call is tied to your OWN tremor status:
--       - ally feared + tremor NOT down  -> RED    "DROP TREMOR" (+ loud sound)
--       - ally feared + tremor pulsing   -> YELLOW  informational (no sound; auto-clears)
--   * ENEMY side uses SPELL_CAST_START from the combat log: Fear / Scare Beast / Hibernate
--     have a ~1.5s cast, so catching the cast START is a pre-empt window ->
--     ORANGE "FEAR INCOMING" (+ soft sound). Instant fears (Psychic Scream) can't be
--     pre-empted, so they only ever surface on the reliable ALLY side once they land.
--
-- No /bg output — personal HUD + sound only.

local c = aura_env.config or {}
aura_env.cfg = {
    enabled    = (c.enabled ~= false),        -- master switch
    allyAlert  = (c.allyAlert ~= false),      -- RED/YELLOW ally-feared call
    enemyCast  = (c.enemyCast ~= false),      -- ORANGE enemy fear-cast pre-alert
    sounds     = (c.sounds ~= false),         -- play sounds on new alerts
    nearbyOnly = (c.nearbyOnly ~= false),     -- only alert for allies in assist range
}

-- Effects Tremor Totem removes = Fear / Charm / Sleep, keyed by LOWERCASE enUS aura name
-- (name match auto-covers all ranks). ONLY list true fear/charm/sleep effects — anything
-- else would raise a "drop tremor" call the totem can't actually clear. Level notes are for
-- the 10-19 twink bracket; harmless higher-level names are kept for wider reuse. VALUE is
-- the pretty display name.
local TREMOR_REMOVES = {
    -- Fear
    ["psychic scream"]     = "Psychic Scream",      -- Priest, instant, 30s CD (L18)
    ["fear"]               = "Fear",                -- Warlock, ~1.5s cast (L8)
    ["scare beast"]        = "Scare Beast",         -- Hunter, ~1.5s cast, beasts only (L14) -> feral druid in form
    ["howl of terror"]     = "Howl of Terror",      -- Warlock AoE (L40+; kept for reuse)
    ["intimidating shout"] = "Intimidating Shout",  -- Warrior AoE (higher level; kept for reuse)
    -- Charm
    ["seduction"]          = "Seduction",           -- Succubus (needs L20 pet; kept for reuse)
    ["mind control"]       = "Mind Control",         -- Priest (L30+; kept for reuse)
    -- Sleep
    ["hibernate"]          = "Hibernate",           -- Druid, ~1.5s cast, beasts/dragonkin -> feral druid in form
    ["wyvern sting"]       = "Wyvern Sting",         -- Hunter (L40+; kept for reuse)
}

-- Enemy spells worth a PRE-ALERT: castable fears/sleeps you can beat by dropping/stomping
-- tremor during the cast. Instant fears are deliberately absent (nothing to pre-empt).
local CAST_FEARS = {
    ["fear"] = true, ["scare beast"] = true, ["hibernate"] = true,
}

-- Localized Tremor Totem name for the GetTotemInfo scan. enUS default; override via
-- config.tremorName on other locales.
local TREMOR_NAME = c.tremorName or "Tremor Totem"

-- Combat-log reaction bit (named global on Classic; numeric fallback documented).
local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40

local function strip(name) return name and (name:gsub("%-.*$", "")) or name end
aura_env.strip = strip

-- ── state ─────────────────────────────────────────────────────────────────────
aura_env.alertText = ""                         -- colored string custom_text renders (or "")
aura_env.redActive = false                      -- edge tracker for the RED sound
aura_env.incoming  = aura_env.incoming or {}    -- [sourceGUID] = { spell, src, expire }
aura_env.lastEval  = 0

function aura_env.Reset()
    aura_env.enabled   = (GetZoneText() == "Warsong Gulch")
    aura_env.alertText = ""
    aura_env.redActive = false
    wipe(aura_env.incoming)
end

-- Seed enabled at load so a /reload while already in WSG shows immediately.
if aura_env.enabled == nil then
    aura_env.enabled = (GetZoneText() == "Warsong Gulch")
end

-- ── sound ─────────────────────────────────────────────────────────────────────
local function playSound(which)
    if not aura_env.cfg.sounds or not PlaySound or not SOUNDKIT then return end
    if which == "red" then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")      -- loud: act now
    else
        PlaySound(SOUNDKIT.READY_CHECK, "Master")       -- softer: pre-alert
    end
end

-- ── is my Tremor Totem down and pulsing? ──────────────────────────────────────
-- GetTotemInfo(slot) -> haveTotem, name, startTime, duration, icon. We only need "is a
-- totem named Tremor Totem currently out" (it pulses for its whole duration).
local function tremorActive()
    if not GetTotemInfo then return false end
    local wanted = TREMOR_NAME:lower()
    for slot = 1, (MAX_TOTEMS or 4) do
        local have, name = GetTotemInfo(slot)
        if have and name and name:lower() == wanted then return true end
    end
    return false
end
aura_env.TremorActive = tremorActive

-- ── which nearby allies are hit by a tremor-removable effect? ─────────────────
-- Direct, reliable read: UnitDebuff on friendly group members (incl. yourself). "nearby"
-- is approximated by UnitInRange (assist range ~40yd) — fail-OPEN when the API can't tell,
-- so we never miss a truly-nearby ally. Returns a list of { name, effect }.
local function scanFearedAllies()
    local out = {}
    for unit in WA_IterateGroupMembers() do
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            local near = true
            if aura_env.cfg.nearbyOnly and unit ~= "player" then
                local inr, checked = UnitInRange(unit)
                if checked and not inr then near = false end   -- only exclude a CONFIRMED far ally
            end
            if near then
                for i = 1, 40 do
                    local name = UnitDebuff(unit, i)
                    if not name then break end
                    local eff = TREMOR_REMOVES[name:lower()]
                    if eff then
                        out[#out + 1] = { name = strip(UnitName(unit)), effect = eff }
                        break
                    end
                end
            end
        end
    end
    return out
end
aura_env.ScanFearedAllies = scanFearedAllies

-- ── enemy fear-cast pre-alert (combat log SPELL_CAST_START) ───────────────────
function aura_env.OnCLEU()
    if not aura_env.cfg.enemyCast then return end
    local _, sub, _, srcGUID, srcName, srcFlags, _, _, _, _, _, _, spellName =
        CombatLogGetCurrentEventInfo()
    if sub ~= "SPELL_CAST_START" or not spellName then return end
    if not CAST_FEARS[spellName:lower()] then return end
    if bit.band(srcFlags or 0, HOSTILE) == 0 then return end        -- enemy casters only
    local now = GetTime()
    local key = srcGUID or spellName
    local prev = aura_env.incoming[key]
    aura_env.incoming[key] = { spell = spellName, src = strip(srcName) or "?", expire = now + 1.6 }
    if not (prev and prev.expire > now) then playSound("orange") end -- one sound per cast
    aura_env.lastEval = 0                                            -- refresh HUD immediately
    aura_env.Evaluate()
end

-- ── decision core (drives the HUD text + RED sound edge) ──────────────────────
function aura_env.Evaluate()
    local cfg, now = aura_env.cfg, GetTime()
    if now - aura_env.lastEval < 0.1 then return end                -- coalesce event storms
    aura_env.lastEval = now

    if not aura_env.enabled or not cfg.enabled then
        aura_env.alertText, aura_env.redActive = "", false
        return
    end

    -- prune expired incoming casts; keep the first still-live one for the ORANGE line
    local incomingSrc, incomingSpell
    for k, info in pairs(aura_env.incoming) do
        if info.expire <= now then
            aura_env.incoming[k] = nil
        elseif not incomingSrc then
            incomingSrc, incomingSpell = info.src, info.spell
        end
    end

    local feared   = (cfg.allyAlert and scanFearedAllies()) or {}
    local tremorOn = tremorActive()

    -- "Name1, Name2 (Effect)" with a +N overflow past 3
    local function fmtAllies()
        local names = {}
        for i = 1, math.min(#feared, 3) do names[i] = feared[i].name end
        local s = table.concat(names, ", ")
        if #feared > 3 then s = s .. " +" .. (#feared - 3) end
        local effect = feared[1] and feared[1].effect
        return s .. (effect and (" (" .. effect .. ")") or "")
    end

    -- Priority: RED (act) > ORANGE (pre-empt) > YELLOW (handled). See header.
    if #feared > 0 and not tremorOn then
        aura_env.alertText = "|cffff2020DROP TREMOR|r  |cffffffff" .. fmtAllies() .. "|r"
        if not aura_env.redActive then aura_env.redActive = true; playSound("red") end
    elseif cfg.enemyCast and incomingSrc then
        aura_env.alertText = "|cffff9020FEAR INCOMING|r  |cffffffff"
            .. incomingSpell .. " — " .. incomingSrc .. "|r"
        aura_env.redActive = false
    elseif #feared > 0 and tremorOn then
        aura_env.alertText = "|cffffdd40" .. fmtAllies() .. " — tremor pulsing|r"
        aura_env.redActive = false
    else
        aura_env.alertText, aura_env.redActive = "", false
    end
end
