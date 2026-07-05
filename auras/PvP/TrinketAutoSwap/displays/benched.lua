-- Trinket Display — Bench — Trigger ▸ Custom ▸ Trigger State Updater
-- Shows whichever of the 3 tracked trinkets is NOT in slot 13/14, with its live cooldown.
-- If two are benched, shows the one coming off cooldown soonest. Blank if none benched/owned.
-- Events box: UNIT_INVENTORY_CHANGED PLAYER_EQUIPMENT_CHANGED BAG_UPDATE_COOLDOWN
--             SPELL_UPDATE_COOLDOWN BAG_UPDATE PLAYER_ENTERING_WORLD
function(allstates)
    -- Keep in sync with the controller's item IDs (edit per character).
    local IDS = { 19024, 18864, 4381 }  -- AGM, Insignia (Ally Pala), Minor Recombobulator

    local function itemCd(itemId)
        if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(itemId) end
        if C_Item and C_Item.GetItemCooldown then return C_Item.GetItemCooldown(itemId) end
        return GetItemCooldown(itemId)
    end

    local id13 = GetInventoryItemID("player", 13)
    local id14 = GetInventoryItemID("player", 14)

    local best, bestStart, bestDur, bestLeft
    for _, id in ipairs(IDS) do
        if id ~= id13 and id ~= id14 and (GetItemCount(id) or 0) > 0 then
            local s, d = itemCd(id)
            local left = (s and d and d > 0) and ((s + d) - GetTime()) or 0
            if left < 0 then left = 0 end
            if not best or left < bestLeft then
                best, bestStart, bestDur, bestLeft = id, s, d, left
            end
        end
    end

    if not best then
        allstates[""] = { show = false, changed = true }
        return true
    end

    local st = allstates[""] or {}
    st.show = true
    st.changed = true
    st.icon = (select(10, GetItemInfo(best))) or GetItemIcon(best)
    st.name = (GetItemInfo(best)) or tostring(best)
    if bestStart and bestDur and bestDur > 1.5 then
        st.progressType = "timed"
        st.duration = bestDur
        st.expirationTime = bestStart + bestDur
    else
        st.progressType = "static"
        st.value, st.total = 1, 1
    end
    allstates[""] = st
    return true
end
