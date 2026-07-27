-- Betty's 19 Shaman Cooldowns — <ITEM> — Trigger ▸ Custom ▸ Trigger State Updater
-- Tracks an ITEM cooldown (shared category CD). Icon always shows so the slot stays fixed;
-- the swipe + number appear while on cooldown. ONE shared TSU for both consumable icons —
-- only the ITEM_ID (and fallback name) changes per icon:
--     Healing Potion  = 929   (req level 12; ~2-min combat-potion category)
--     Big Bronze Bomb = 4380  (Engineering AoE stun; ~1-min throwable/bomb category)
-- Cloned verbatim from Betty's 19 Paladin Cooldowns tsu_item.
-- Item id (reference, Healing Potion): 929  https://www.wowhead.com/classic/item=929
-- Events box: BAG_UPDATE_COOLDOWN SPELL_UPDATE_COOLDOWN BAG_UPDATE PLAYER_ENTERING_WORLD
function(allstates)
    local ITEM_ID = 929                                     -- ← change per icon (929 / 4380)
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
    st.name = (GetItemInfo(ITEM_ID)) or "Healing Potion"    -- ← change fallback per icon
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
