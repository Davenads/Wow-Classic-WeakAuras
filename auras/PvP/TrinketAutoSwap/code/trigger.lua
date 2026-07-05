-- PvP Trinket Auto-Swap — Controller — Trigger ▸ Custom ▸ Status
-- Events box (Trigger ▸ Custom ▸ Events):
--   PLAYER_ENTERING_WORLD PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED
--   BAG_UPDATE_COOLDOWN SPELL_UPDATE_COOLDOWN UNIT_INVENTORY_CHANGED
--   PLAYER_EQUIPMENT_CHANGED BAG_UPDATE
function(event, arg1)
    local e = aura_env
    if not e.cfg then return false end

    if event == "PLAYER_REGEN_ENABLED" then
        e.pending = false
        e.Apply()                       -- left combat: apply any pending swap
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- entered combat: equipment is locked; wait for combat end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then e.Apply() end
    elseif event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
        e.WatchAGM()
        e.Apply()
    else
        -- PLAYER_ENTERING_WORLD, PLAYER_EQUIPMENT_CHANGED, BAG_UPDATE
        e.Apply()
    end

    return e.cfg.enabled == true         -- shown while enabled -> On Show/Hide drive the ticker
end
