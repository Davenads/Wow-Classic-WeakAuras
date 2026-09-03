-- Headless WoW-API stubs for testing auras/Battlegrounds/BGItemCallout/code/init.lua
-- under a plain Lua VM (fengari). Nothing here ships in-game; it only fakes the
-- Classic globals init.lua touches so the corroboration logic can be exercised.

-- ---- controllable clocks ---------------------------------------------------
_now = 0                                   -- GetServerTime() returns this (realm epoch)
function GetServerTime() return _now end
function time() return _now end
function date(_, _) return "00:00:00" end  -- format irrelevant to logic tests
_clock = 0                                  -- GetTime() returns this (local monotonic, s)
function GetTime() return _clock end

-- Persistent SavedVariables table (aura_env.saved survives reload in-game; a plain table here).
aura_env = { saved = {} }

-- ---- capture sinks ---------------------------------------------------------
_sent = {}   -- {prefix, payload, channel} pushed by C_ChatInfo.SendAddonMessage
_chat = {}   -- {msg, chan} pushed by SendChatMessage
function resetSinks() _sent = {}; _chat = {} end

-- ---- combat log ------------------------------------------------------------
_cle = {}    -- the tuple CombatLogGetCurrentEventInfo() returns
function CombatLogGetCurrentEventInfo() return (table.unpack or unpack)(_cle) end

-- CLEU source-flag bits (real WoW values).
COMBATLOG_OBJECT_AFFILIATION_MINE  = 0x00000001
COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x00000010
COMBATLOG_OBJECT_REACTION_HOSTILE  = 0x00000040

-- 5.1-faithful bit.band (WoW provides `bit`; fengari is 5.3, so supply our own).
bit = {
    band = function(a, b)
        local r, v = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then r = r + v end
            a = math.floor(a / 2); b = math.floor(b / 2); v = v * 2
        end
        return r
    end,
}

-- ---- misc WoW globals ------------------------------------------------------
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function UnitName(_) return "Me" end       -- our own character (the self-witness)
LE_PARTY_CATEGORY_INSTANCE = 2

_instanceType = "pvp"                       -- flip to gate-test refreshZone()
function IsInInstance() return true, _instanceType end
function IsInGroup(_) return true end
function IsInRaid() return false end
function SendChatMessage(msg, chan) _chat[#_chat + 1] = { msg = msg, chan = chan } end

C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(prefix, payload, channel)
        _sent[#_sent + 1] = { prefix = prefix, payload = payload, channel = channel }
    end,
}

-- Plain-text strsplit (WoW semantics), pipe-safe (no pattern escaping needed).
function strsplit(delim, s)
    local t, last = {}, 1
    while true do
        local i = string.find(s, delim, last, true)
        if not i then t[#t + 1] = string.sub(s, last); break end
        t[#t + 1] = string.sub(s, last, i - 1)
        last = i + #delim
    end
    return (table.unpack or unpack)(t)
end

-- CreateFrame: a fake frame that records handlers + registrations so the harness
-- can invoke OnEvent directly and inspect which events are armed.
function CreateFrame(_, name)
    local f = { registered = {} }
    function f.RegisterEvent(self, e) self.registered[e] = true end
    function f.UnregisterEvent(self, e) self.registered[e] = nil end
    function f.SetScript(self, script, fn) if script == "OnEvent" then self._on = fn end end
    if name then _G[name] = f end
    return f
end
