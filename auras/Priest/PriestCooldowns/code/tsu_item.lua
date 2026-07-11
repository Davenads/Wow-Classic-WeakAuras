-- Dwarf Priest Cooldowns — Major Mana Potion — Trigger ▸ Custom ▸ Trigger State Updater
-- Possession-gated ITEM icon: shows ONLY while you carry >=1 (dynamic group collapses the slot
-- when you don't), then paints the shared ~2-min combat-potion cooldown. Swap ITEM_ID for a
-- different potion (e.g. Superior Mana Potion 3827). Flavor-aware getters: global on Era,
-- C_Container/C_Item on Cata/MoP.
-- Item id (reference): 13444  https://www.wowhead.com/classic/item=13444
-- Events box: BAG_UPDATE_COOLDOWN SPELL_UPDATE_COOLDOWN BAG_UPDATE PLAYER_ENTERING_WORLD
function(allstates)
    local ITEM_ID = 13444
    local function itemCd(itemId)
        if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(itemId) end
        if C_Item and C_Item.GetItemCooldown then return C_Item.GetItemCooldown(itemId) end
        return GetItemCooldown(itemId)
    end
    local function itemCount(itemId)
        if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemId) end
        return GetItemCount(itemId)
    end
    if (itemCount(ITEM_ID) or 0) < 1 then                   -- not carried -> hide
        allstates[""] = { show = false, changed = true }
        return true
    end
    local start, dur = itemCd(ITEM_ID)
    local st = allstates[""] or {}
    st.show = true
    st.changed = true
    st.icon = GetItemIcon(ITEM_ID)
    st.name = (GetItemInfo(ITEM_ID)) or "Major Mana Potion"
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
