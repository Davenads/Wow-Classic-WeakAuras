-- WSG Res-Deny Callout — Actions → On Init (actions.init.custom)
-- Target: WoW Classic (Era/SoD/HC 1.15 + Cata/MoP Classic). enUS system strings.
--
-- PURPOSE
--   Inside Warsong Gulch, when an enemy player is at LOW HP, is NOT the enemy flag
--   carrier (EFC), AND the graveyard resurrection wave is IMMINENT, post a rate-limited
--   /bg callout telling teammates to HOLD the kill until the res timer resets — so when
--   the enemy is then killed they eat a near-full ~30s corpse/res timer (max downtime).
--
-- REUSE / ATTRIBUTION
--   * Res-cycle clock (aura_env.rc): ported from the "BG Rez Timer" WeakAura
--     (wago wm2BS70cN, semver 1.0.2). Cannot read the ENEMY graveyard timer directly
--     (GetAreaSpiritHealerTime only returns YOUR group's, and only while a groupmate is
--     a ghost). Instead: seed from the WSG start message, then self-correct by detecting
--     friendly res WAVES (alive-count jumps) and optional manual/addon sync. Premise:
--     both graveyards share ONE ~31.5s cycle, so a friendly-derived countdown predicts
--     enemy waves.
--   * strip / detectFaction / OnSystem EFC identity / Announce / enemy-HP acquisition:
--     adapted from "WSG Enemy FC Announcer" (auras/Battlegrounds/WSG-EnemyFCAnnouncer).
--
-- SAFETY: ships in dry-run (mode "SELF" → local print) by default; flip dryRun off to go
-- live on /bg. SendChatMessage is sandbox-allowed and needs no hardware event.

-- ── config ────────────────────────────────────────────────────────────────────
local c = aura_env.config or {}
local dry = (c.dryRun ~= false)                       -- default TRUE (safe local print)
aura_env.cfg = {
    enabled           = (c.enabled ~= false),         -- master switch
    chat              = (c.announceChat ~= false),    -- master for ALL sends
    mode              = dry and "SELF" or (c.channel or "BG"),  -- SELF | BG | RAID
    prefix            = c.messagePrefix or "",        -- optional leading tag on each line
    hpThreshold       = tonumber(c.hpThreshold) or 20,        -- only enemies at/under this % (%)
    gyLowThreshold    = tonumber(c.gyLowThreshold) or 7,      -- only fire when rez ≤ this many s
    perTargetCooldown = tonumber(c.perTargetCooldown) or 20,  -- min gap between calls on SAME enemy (s)
    globalMinInterval = tonumber(c.globalMinInterval) or 8,   -- min gap between ANY two sends (s)
    rollingCap        = tonumber(c.rollingCap) or 3,          -- max sends per rolling window
    rollingWindow     = tonumber(c.rollingWindow) or 30,      -- rolling-cap window (s)
    enemyGyOffset     = tonumber(c.enemyGyOffset) or 0,       -- +/- s: enemy GY phase vs ours
    wsgRezThreshold   = tonumber(c.wsgRezThreshold) or 2,     -- alive-jump size to call a wave
    startOffset       = tonumber(c.startOffset) or 5,         -- WSG gate opens ~5s after start msg
    showIndicator     = (c.showIndicator ~= false),          -- draw the local status readout
}

-- Manual/addon sync bus — SAME prefix/event as BG Rez Timer, so we interoperate with its
-- existing userbase (their macro re-anchors our clock too, and vice-versa).
aura_env.syncPrefix = "AuroBGRez"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(aura_env.syncPrefix)
end
aura_env.bgChannel = "INSTANCE_CHAT"                  -- "BATTLEGROUND" was removed in 4.0

local WSG_START = "Let the battle for Warsong Gulch begin!"

local function strip(name) return name and (name:gsub("%-.*$", "")) or name end
aura_env.strip = strip

-- Effective faction (mercenary-aware): a merc fights for the OTHER side, so the EFC is the
-- carrier of your EFFECTIVE faction's flag. 81748/81744 are the merc buffs; fall back to
-- UnitFactionGroup where absent. Guarded so a nil spell id can't error.
local function detectFaction()
    if GetSpellInfo and AuraUtil and AuraUtil.FindAuraByName then
        local ally  = GetSpellInfo(81748)
        local horde = GetSpellInfo(81744)
        if ally  and AuraUtil.FindAuraByName(ally,  "player") then return "Alliance" end
        if horde and AuraUtil.FindAuraByName(horde, "player") then return "Horde" end
    end
    return UnitFactionGroup("player")
end
aura_env.myFaction = detectFaction()

-- ── res-cycle clock (ported from BG Rez Timer wm2BS70cN) ──────────────────────
local REZ_INTERVAL = 31.5                              -- observed WSG/AV spirit-healer cycle
aura_env.rc = {
    nextRez = nil, aliveLC = nil, totalLC = nil, lastChk = 0, throttle = 0.1,

    -- alive / total group members (both graveyards share the cycle, so ours predicts theirs)
    getRaid = function()
        local alive, total = 0, 0
        for unit in WA_IterateGroupMembers() do
            total = total + 1
            if not UnitIsDeadOrGhost(unit) then alive = alive + 1 end
        end
        return alive, total
    end,

    seedStart = function(self, offset)
        self.nextRez = GetTime() + REZ_INTERVAL + (offset or 0)
    end,

    -- Re-anchor on a manual/addon SYNC or a friendly res wave.
    syncNow = function(self)
        self.nextRez = GetTime() + REZ_INTERVAL
    end,

    -- Detect a res WAVE: alive count jumps by ≥ threshold with the roster unchanged →
    -- a spirit-healer just fired, so re-anchor the cycle. Throttled to ~0.1s.
    detectWave = function(self, threshold)
        local now = GetTime()
        if self.aliveLC == nil or self.totalLC == nil then
            self.aliveLC, self.totalLC = self.getRaid()
            return
        end
        if self.lastChk + self.throttle > now then return end
        local alive, total = self.getRaid()
        if self.aliveLC + threshold <= alive and total == self.totalLC then
            self.nextRez = now + REZ_INTERVAL
        end
        self.lastChk = now
        self.aliveLC = alive
        self.totalLC = total
    end,

    isSeeded = function(self) return self.nextRez ~= nil end,

    -- Fallback seed for import/reload MID-MATCH (start message already missed). While you
    -- or a groupmate is a ghost at a graveyard, GetAreaSpiritHealerTime() returns seconds to
    -- YOUR next res wave — both graveyards share the cycle, so it anchors the clock accurately
    -- without waiting for a wave-detection or a manual sync. No-op once seeded, when the API is
    -- absent, or when nobody's at a healer (returns nil / out-of-range).
    trySeedFromHealer = function(self)
        if self.nextRez or not GetAreaSpiritHealerTime then return end
        local t = GetAreaSpiritHealerTime()
        if t and t > 0 and t <= REZ_INTERVAL + 3.5 then
            self.nextRez = GetTime() + t
        end
    end,

    -- Seconds until the ENEMY graveyard's next wave (with optional phase offset). Rolls the
    -- cycle forward if we've drifted past a wave without a resync.
    enemyRemaining = function(self, offset)
        if not self.nextRez then return nil end
        local r = self.nextRez - GetTime() + (offset or 0)
        while r <= 0 do r = r + REZ_INTERVAL end
        return r
    end,

    reset = function(self)
        self.nextRez, self.aliveLC, self.totalLC, self.lastChk = nil, nil, nil, 0
    end,
}

-- ── EFC identity (never suppress kills on the flag carrier) ───────────────────
aura_env.efc = aura_env.efc or { name = nil }
function aura_env.SetEFC(name) aura_env.efc.name = name end
function aura_env.ClearEFC() aura_env.efc.name = nil end

-- Enemy carries YOUR (effective) faction's flag → EFC = whoever picked up that flag.
function aura_env.OnSystem(msg)
    if type(msg) ~= "string" then return end
    if msg == WSG_START then
        aura_env.rc:seedStart(aura_env.cfg.startOffset)
        return
    end
    local faction = msg:match("[Tt]he (%a+) [Ff]lag")
    if not faction then
        if msg:find("[Cc]aptured") or msg:find("flags are reset")
           or msg:find("flags are now placed") then
            aura_env.ClearEFC()
        end
        return
    end
    if faction ~= aura_env.myFaction then return end          -- not OUR flag → ignore
    local picked = msg:match("picked up by (.-)!")
    if picked then
        aura_env.SetEFC(strip(picked))
    elseif msg:find("was dropped by") or msg:find("was returned") or msg:find("[Cc]aptured") then
        aura_env.ClearEFC()
    end
end

-- ── enemy scan (all visible living enemy players, deduped by GUID) ────────────
-- Sources, cheapest first: your own tokens → enemy nameplates (need enemy nameplates ON)
-- → raidNtarget crowdsource (HP of whatever any teammate targets).
function aura_env.ScanEnemies()
    local out, seen = {}, {}
    local function consider(u)
        if not UnitExists(u) or not UnitIsPlayer(u) then return end
        if not UnitCanAttack("player", u) or UnitIsDeadOrGhost(u) then return end
        local guid = UnitGUID(u)
        if not guid or seen[guid] then return end
        local mx = UnitHealthMax(u)
        if not mx or mx <= 0 then return end
        seen[guid] = true
        out[#out + 1] = {
            name = strip(UnitName(u)), guid = guid,
            pct = UnitHealth(u) / mx * 100, unit = u,
        }
    end
    for _, u in ipairs({ "target", "focus", "mouseover" }) do consider(u) end
    for i = 1, 40 do consider("nameplate" .. i) end
    for i = 1, 40 do consider("raid" .. i .. "target") end
    return out
end

-- ── rate limiter (global gap + per-target cooldown + rolling cap) ─────────────
aura_env.rl = {
    lastGlobal = 0, perTarget = {}, recent = {},

    allow = function(self, key)
        local cfg, now = aura_env.cfg, GetTime()
        if now - self.lastGlobal < cfg.globalMinInterval then return false end
        local lt = self.perTarget[key]
        if lt and now - lt < cfg.perTargetCooldown then return false end
        local n = 0
        for i = #self.recent, 1, -1 do
            if now - self.recent[i] > cfg.rollingWindow then
                table.remove(self.recent, i)
            else
                n = n + 1
            end
        end
        if n >= cfg.rollingCap then return false end
        return true
    end,

    commit = function(self, key)
        local now = GetTime()
        self.lastGlobal = now
        self.perTarget[key] = now
        self.recent[#self.recent + 1] = now
    end,

    reset = function(self)
        self.lastGlobal = 0
        wipe(self.perTarget); wipe(self.recent)
    end,
}

-- ── send ──────────────────────────────────────────────────────────────────────
function aura_env.Announce(body, key)
    local cfg = aura_env.cfg
    if not cfg.enabled or not cfg.chat then return end
    local line = (cfg.prefix ~= "" and (cfg.prefix .. " ") or "") .. body
    if cfg.mode == "SELF" then
        print("|cff33ff99[ResDeny]|r " .. line)                -- local only (dry-run)
    else
        local ch = (cfg.mode == "RAID") and "RAID" or aura_env.bgChannel
        SendChatMessage(line, ch)
    end
    aura_env.rl:commit(key)
end

-- ── decision core ─────────────────────────────────────────────────────────────
-- Exposed for custom_text; refreshed every Evaluate().
aura_env.lastRem = nil
aura_env.candidateCount = 0

function aura_env.Evaluate()
    local cfg = aura_env.cfg
    aura_env.candidateCount = 0
    if not aura_env.enabled or not cfg.enabled then return end
    if not aura_env.rc:isSeeded() then return end

    local rem = aura_env.rc:enemyRemaining(cfg.enemyGyOffset)
    aura_env.lastRem = rem
    if not rem or rem > cfg.gyLowThreshold then return end     -- only when wave IMMINENT

    local efcName = aura_env.efc.name
    for _, cand in ipairs(aura_env.ScanEnemies()) do
        if cand.pct <= cfg.hpThreshold and not (efcName and cand.name == efcName) then
            aura_env.candidateCount = aura_env.candidateCount + 1
            local key = cand.guid or cand.name
            if aura_env.rl:allow(key) then
                aura_env.Announce(string.format(
                    "Don't kill yet: %s @%d%% — enemy rez in %ds, wait for reset (full 30s down)",
                    cand.name, math.floor(cand.pct + 0.5), math.floor(rem + 0.5)), key)
                return                                          -- one call per tick; throttle handles the rest
            end
        end
    end
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────
function aura_env.Reset()
    aura_env.enabled = (GetZoneText() == "Warsong Gulch")
    aura_env.myFaction = detectFaction()
    aura_env.rc:reset()
    aura_env.rl:reset()
    aura_env.ClearEFC()
    aura_env.lastRem, aura_env.candidateCount = nil, 0
end

-- Seed enabled at load so a /reload while already in WSG shows the region on the first
-- synthetic STATUS event (before ZONE_CHANGED/PLAYER_ENTERING_WORLD re-fires).
if aura_env.enabled == nil then
    aura_env.enabled = (GetZoneText() == "Warsong Gulch")
end
