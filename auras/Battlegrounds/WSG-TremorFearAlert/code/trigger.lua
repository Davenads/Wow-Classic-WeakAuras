-- WSG Tremor Fear Alert — Trigger 1 → Custom → Status (Check On: Event)
-- Events box (comma-separated):
--   PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, PLAYER_TOTEM_UPDATE,
--   UNIT_AURA, COMBAT_LOG_EVENT_UNFILTERED:SPELL_CAST_START
--
-- Side-effect trigger: all real work is in aura_env helpers. Returns aura_env.enabled so
-- the text region stays shown for the whole WSG match (On Show/On Hide arm/cancel the
-- ticker exactly once); custom_text draws the alert line or "" and refreshes every frame
-- (customTextUpdate = update). The combat-log event is registered filtered to
-- SPELL_CAST_START but still arrives as COMBAT_LOG_EVENT_UNFILTERED.

function(event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        aura_env.Reset()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        aura_env.OnCLEU()
    else
        -- UNIT_AURA (an ally's debuffs changed) / PLAYER_TOTEM_UPDATE (tremor up or down)
        aura_env.Evaluate()
    end

    return aura_env.enabled == true
end
