-- Trinket Display — Slot 2 (inventory slot 14) — Trigger ▸ Custom ▸ Trigger State Updater
-- Shows the live-equipped trinket in slot 14 with its cooldown swipe + number.
-- Events box: UNIT_INVENTORY_CHANGED PLAYER_EQUIPMENT_CHANGED BAG_UPDATE_COOLDOWN
--             SPELL_UPDATE_COOLDOWN PLAYER_ENTERING_WORLD
function(allstates)
    local slot = 14
    local id = GetInventoryItemID("player", slot)
    if not id then
        allstates[""] = { show = false, changed = true }
        return true
    end
    local start, dur = GetInventoryItemCooldown("player", slot)
    local st = allstates[""] or {}
    st.show = true
    st.changed = true
    st.icon = GetInventoryItemTexture("player", slot)
    st.name = (GetItemInfo(id)) or tostring(id)
    if start and dur and dur > 1.5 then
        st.progressType = "timed"
        st.duration = dur
        st.expirationTime = start + dur
    else
        st.progressType = "static"
        st.value, st.total = 1, 1
    end
    allstates[""] = st
    return true
end
