-- WhisperCatcher — Actions ▸ On Init (actions.init.custom)
-- Sets up persistent storage + the helper functions the trigger calls. All state lives in
-- aura_env.saved (survives /reload + logout), so a multi-hour AFK backlog is safe as long as the
-- client keeps running. SavedVariables only flush to disk on a clean logout/reload, so an outright
-- client CRASH would lose the in-memory tail — the one durability caveat for this design.

local s = aura_env.saved
s.whispers = s.whispers or {}
if s.capturing == nil then s.capturing = true end

local PREFIX = "|cff66ccff[WhisperCatcher]|r "

-- strip realm from "Name-Realm"
function aura_env.strip(name)
    return name and (name:gsub("%-.*$", "")) or name
end

-- dump the whole log to your chat frame, newest last
function aura_env.Dump()
    local w = aura_env.saved.whispers or {}
    local n = #w
    if n == 0 then
        print(PREFIX .. "no whispers logged.")
        return
    end
    print(PREFIX .. n .. " whisper" .. (n == 1 and "" or "s") .. " logged:")
    for _, e in ipairs(w) do
        local stamp = date("%m/%d %H:%M", e.t or time())
        print(string.format("|cff999999%s|r |cffffff00%s|r: %s", stamp, e.who or "?", e.msg or ""))
    end
end

-- parse a self-whispered command; a 0.5s guard absorbs the INFORM + self-WHISPER double fire
function aura_env.Command(text)
    local now = GetTime()
    if aura_env.lastCmd and (now - aura_env.lastCmd) < 0.5 then return end
    aura_env.lastCmd = now

    local cmd = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if cmd == "whlog" or cmd == "log" then
        aura_env.Dump()
    elseif cmd == "whlog clear" or cmd == "log clear" then
        wipe(aura_env.saved.whispers)
        print(PREFIX .. "log cleared.")
    elseif cmd == "whlog off" or cmd == "log off" then
        aura_env.saved.capturing = false
        print(PREFIX .. "capturing PAUSED.")
    elseif cmd == "whlog on" or cmd == "log on" then
        aura_env.saved.capturing = true
        print(PREFIX .. "capturing RESUMED.")
    end
end

-- one-line nudge on login/zone-in, and on the AFK -> back transition, if a backlog exists
function aura_env.Remind(event)
    if event == "PLAYER_FLAGS_CHANGED" then
        local afk = (UnitIsAFK and UnitIsAFK("player")) and true or false
        local returned = aura_env.wasAFK and not afk
        aura_env.wasAFK = afk
        if not returned then return end   -- only speak when you come BACK from AFK
    end
    local n = #(aura_env.saved.whispers or {})
    if n > 0 then
        print(PREFIX .. n .. " whisper" .. (n == 1 and "" or "s")
            .. " while you were away — whisper yourself \"whlog\" to read, \"whlog clear\" to reset.")
    end
end
