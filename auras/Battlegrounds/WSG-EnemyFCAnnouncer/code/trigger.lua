-- WSG Enemy FC Announcer — Trigger 1 → Custom → Status (Check On: Event)
-- Events box (comma-separated):
--   CHAT_MSG_BG_SYSTEM_ALLIANCE, CHAT_MSG_BG_SYSTEM_HORDE, CHAT_MSG_BG_SYSTEM_NEUTRAL,
--   CHAT_MSG_ADDON, COMBAT_LOG_EVENT_UNFILTERED, NAME_PLATE_UNIT_ADDED,
--   NAME_PLATE_UNIT_REMOVED, PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED,
--   UPDATE_MOUSEOVER_UNIT, UNIT_HEALTH, PLAYER_ENTERING_WORLD
--
-- All real work is side effects (announcing / HP sharing) done in aura_env helpers.
-- Returning true keeps the status region shown for the whole match so custom_text can
-- display the EFC and so On Show/On Hide fire once per load (arming/canceling the ticker).

function(event, ...)
    local e = aura_env.efc
    if not e then return false end

    if event == "PLAYER_ENTERING_WORLD" then
        aura_env.Reset()
        aura_env.InitWidget()
    elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"
        or event == "CHAT_MSG_BG_SYSTEM_HORDE"
        or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        aura_env.OnSystem(...)
        aura_env.InitWidget()
    elseif event == "CHAT_MSG_ADDON" then
        aura_env.OnAddon(...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        aura_env.OnCLEU()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if (...) == e.unit then e.unit = nil end
    elseif event == "UNIT_HEALTH" then
        if (...) == e.unit then aura_env.Tick() end
    elseif event == "NAME_PLATE_UNIT_ADDED"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "PLAYER_FOCUS_CHANGED"
        or event == "UPDATE_MOUSEOVER_UNIT" then
        aura_env.Tick()
    end

    return true
end
