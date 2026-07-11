-- Dwarf Priest Cooldowns — Mana Rune (Dark/Demonic) — Trigger ▸ Custom ▸ Trigger State Updater
-- One smart icon for whichever mana rune you carry: scans the list, shows the FIRST one in your
-- bags (its own art + live rune cooldown), and hides if you carry neither (group collapses).
-- Item ids (reference): Dark Rune 20520 · Demonic Rune 12662
--   https://www.wowhead.com/classic/item=20520  https://www.wowhead.com/classic/item=12662
-- Events box: BAG_UPDATE_COOLDOWN SPELL_UPDATE_COOLDOWN BAG_UPDATE PLAYER_ENTERING_WORLD
function(allstates)
    local RUNES = { 20520, 12662 }                          -- Dark Rune (Scholo), Demonic Rune (DM)
    local function itemCd(itemId)
        if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(itemId) end
        if C_Item and C_Item.GetItemCooldown then return C_Item.GetItemCooldown(itemId) end
        return GetItemCooldown(itemId)
    end
    local function itemCount(itemId)
        if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemId) end
        return GetItemCount(itemId)
    end
    local have
    for _, id in ipairs(RUNES) do
        if (itemCount(id) or 0) > 0 then
            have = id
            break
        end
    end
    if not have then                                        -- no rune carried -> hide
        allstates[""] = { show = false, changed = true }
        return true
    end
    local start, dur = itemCd(have)
    local st = allstates[""] or {}
    st.show = true
    st.changed = true
    st.icon = GetItemIcon(have)
    st.name = (GetItemInfo(have)) or "Mana Rune"
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
