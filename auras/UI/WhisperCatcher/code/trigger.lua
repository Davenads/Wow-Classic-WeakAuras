-- WhisperCatcher — Trigger 1 ▸ Custom ▸ Status (Check On: Event)
-- Silent whisper logger. Captures every INCOMING whisper into aura_env.saved so you can read
-- them after a long AFK (e.g. while an AHK script spams trade). Nothing ever shows on screen —
-- the trigger ALWAYS returns false — so the aura is invisible; it only prints to chat on demand.
--
-- READ-BACK "command": the WA sandbox BLOCKS SlashCmdList, so a real /whlog slash cannot be
-- registered from a WeakAura. Instead you issue commands by whispering YOURSELF — caught either
-- as the outgoing CHAT_MSG_WHISPER_INFORM or the self-copy CHAT_MSG_WHISPER (a self-whisper is
-- treated as a command and is NEVER logged):
--     /w <YourName> whlog          -> dump the whole log to chat
--     /w <YourName> whlog clear     -> wipe the log
--     /w <YourName> whlog off|on    -> pause / resume capturing
-- A one-line nudge also prints on login/zone-in and when you return from AFK, if a backlog exists.
--
-- Events box (comma-separated):
--   CHAT_MSG_WHISPER, CHAT_MSG_BN_WHISPER, CHAT_MSG_WHISPER_INFORM,
--   PLAYER_ENTERING_WORLD, PLAYER_FLAGS_CHANGED
function(event, ...)
    local s = aura_env.saved
    s.whispers = s.whispers or {}
    if s.capturing == nil then s.capturing = true end

    local me = aura_env.strip(UnitName("player"))

    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        local text, sender = ...
        -- a whisper from yourself is the command channel, not a real whisper -> never logged
        if sender and aura_env.strip(sender) == me then
            aura_env.Command(text or "")
            return false
        end
        if s.capturing and text and text ~= "" then
            table.insert(s.whispers, { t = time(), who = sender or "?", msg = text })
            if #s.whispers > 1000 then table.remove(s.whispers, 1) end   -- bound memory
        end

    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        -- outgoing whisper: only a command if you whispered YOURSELF
        local text, target = ...
        if target and aura_env.strip(target) == me and text then
            aura_env.Command(text)
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_FLAGS_CHANGED" then
        aura_env.Remind(event)
    end

    return false   -- always hidden: silent, side-effect-only logger
end
