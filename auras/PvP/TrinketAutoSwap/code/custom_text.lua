-- PvP Trinket Auto-Swap — Controller — Display ▸ text %c (optional debug readout)
-- Returns "" unless the debug Custom Option is on, so the controller can stay invisible.
function()
    local e = aura_env
    if not e.cfg or not e.cfg.debug then return "" end
    local function nm(slot)
        local id = GetInventoryItemID("player", slot)
        if not id then return "-" end
        return (GetItemInfo(id)) or tostring(id)
    end
    return "T1 " .. nm(13) .. " | T2 " .. nm(14) .. (e.pending and "  (pending OOC)" or "")
end
