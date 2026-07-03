-- WSG Flag Carriers — Trigger 1 → Type: Custom → Custom Trigger: "Status"
-- "Check On:" = Event(s). Events box (comma-separated):
--   CHAT_MSG_BG_SYSTEM_ALLIANCE, CHAT_MSG_BG_SYSTEM_HORDE, CHAT_MSG_BG_SYSTEM_NEUTRAL, PLAYER_ENTERING_WORLD
--
-- Parses Warsong Gulch flag system messages (enUS) and updates aura_env.fc, then
-- returns whether either flag is currently being carried (controls show/hide).
-- The text itself is rendered by the "%c" custom-text function (see custom_text.lua).
--
-- Why chat parsing: you can only scan auras on your own team, so the enemy carrier is
-- invisible to UnitAura across the map. The game announces every pickup/drop/return/
-- capture to everyone via CHAT_MSG_BG_SYSTEM_* (arg1 = the message text). The patterns
-- below are the only locale-specific part — edit them for non-enUS clients.

function(event, msg)
    local fc = aura_env.fc
    if not fc then fc = {}; aura_env.fc = fc end

    if event == "PLAYER_ENTERING_WORLD" then
        fc.alliance, fc.horde = nil, nil                     -- new match / zoning: reset
    elseif type(msg) == "string" then
        local faction = msg:match("The (%a+) [Ff]lag")       -- "Alliance" or "Horde"
        local picked  = msg:match("[Ff]lag was picked up by (.-)!")
        if picked and faction then
            picked = picked:gsub("%-.*$", "")                -- strip "-Realm" (cross-realm BGs)
            if faction == "Alliance" then
                fc.alliance = picked                         -- Horde player took the Alliance flag
            elseif faction == "Horde" then
                fc.horde = picked                            -- Alliance player took the Horde flag
            end
        elseif msg:find("was dropped by") or msg:find("was returned") then
            if faction == "Alliance" then fc.alliance = nil
            elseif faction == "Horde" then fc.horde = nil end
        elseif msg:find("[Cc]aptured") or msg:find("[Ff]lags are reset")
            or msg:find("flags are now placed") or msg:find("battle has begun") then
            -- A capture requires your own flag home, so only one flag is carried at
            -- capture time — clearing both is safe and self-correcting.
            fc.alliance, fc.horde = nil, nil
        end
    end

    return (fc.alliance ~= nil) or (fc.horde ~= nil)
end
