-- WSG Res-Deny Callout — Trigger 1 → Custom → Status (Check On: Event)
-- Events box (comma-separated):
--   PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA,
--   CHAT_MSG_BG_SYSTEM_ALLIANCE, CHAT_MSG_BG_SYSTEM_HORDE, CHAT_MSG_BG_SYSTEM_NEUTRAL,
--   CHAT_MSG_ADDON, BG_REZ_SYNC,
--   NAME_PLATE_UNIT_ADDED, NAME_PLATE_UNIT_REMOVED,
--   PLAYER_TARGET_CHANGED, UPDATE_MOUSEOVER_UNIT
--
-- Side-effect trigger: all real work is in aura_env helpers. Returning aura_env.enabled
-- keeps the status region shown for the whole WSG match (so On Show/On Hide arm/cancel the
-- ticker exactly once, and custom_text can draw the indicator). BG_REZ_SYNC is the SAME
-- scan-event the BG Rez Timer macro fires — handling it keeps both auras' clocks aligned.

function(event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        aura_env.Reset()

    elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"
        or event == "CHAT_MSG_BG_SYSTEM_HORDE"
        or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        aura_env.OnSystem(...)

    elseif event == "BG_REZ_SYNC" then
        -- Local manual resync (macro: /script WeakAuras.ScanEvents("BG_REZ_SYNC","SYNC"))
        local _, inst = IsInInstance()
        if inst == "pvp" and (...) == "SYNC" then
            aura_env.rc:syncNow()
            if C_ChatInfo and C_ChatInfo.SendAddonMessage then
                C_ChatInfo.SendAddonMessage(aura_env.syncPrefix, "SYNC", "INSTANCE_CHAT")
            end
        end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text = ...
        if prefix == aura_env.syncPrefix and text == "SYNC" then
            aura_env.rc:syncNow()                     -- peer (or BG Rez Timer user) resynced
        end

    elseif event == "NAME_PLATE_UNIT_ADDED"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "UPDATE_MOUSEOVER_UNIT" then
        -- A fresh enemy just became readable — opportunistic evaluate between ticks.
        aura_env.Evaluate()
    end

    return aura_env.enabled == true
end
