-- Betty's 19 Paladin Cooldowns — ITEM icon — Trigger ▸ Custom ▸ Trigger State Updater
-- One instance of this block per item icon; only ITEM_ID changes:
--   Healing Potion = 929   https://www.wowhead.com/classic/item=929
--   Big Bronze Bomb = 4380 https://www.wowhead.com/classic/item=4380
-- Tracks the item cooldown (potions share a ~2-min combat CD; bombs share a ~1-min throwable CD).
-- The icon always shows (art from GetItemIcon, which needs no item cache) so the slot stays fixed;
-- the swipe + number appear only while on cooldown. Flavor-aware getter: global GetItemCooldown on
-- Era, C_Container/C_Item on Cata/MoP. Swap ITEM_ID for a different consumable (e.g. Lesser Healing
-- Potion 858, Discolored Healing Potion 3826).
-- Events box: BAG_UPDATE_COOLDOWN SPELL_UPDATE_COOLDOWN BAG_UPDATE PLAYER_ENTERING_WORLD
function(allstates)
    local ITEM_ID = 929                                     -- <- per-icon: 929 potion / 4380 bomb
    local function itemCd(itemId)
        if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(itemId) end
        if C_Item and C_Item.GetItemCooldown then return C_Item.GetItemCooldown(itemId) end
        return GetItemCooldown(itemId)
    end
    local start, dur = itemCd(ITEM_ID)
    local st = allstates[""] or {}
    st.show = true
    st.changed = true
    st.icon = GetItemIcon(ITEM_ID)
    st.name = (GetItemInfo(ITEM_ID)) or "Healing Potion"
    if start and dur and dur > 1.5 then
        st.progressType = "timed"
        st.duration = dur
        st.expirationTime = start + dur
    else
        st.progressType = "timed"   -- ready: 0-duration draws no swipe (icon stays bright)
        st.duration = 0
        st.expirationTime = 0
    end
    allstates[""] = st
    return true
end
