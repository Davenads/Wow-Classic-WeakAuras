-- Betty's 19 Shaman Cooldowns — "totem planted" GLOW check — Conditions ▸ Custom Check
-- Paste as a Custom Check condition on each TOTEM cooldown icon, then set the condition's
-- change to "Glow". Returns true while the named totem is physically down, so the icon glows
-- while planted — the icon's own swipe still shows the recast cooldown (from tsu_spell.lua).
-- ONE template — change the `name` line per icon:
--     Earthbind Totem (primary row)  /  Fire Nova Totem  /  Stoneclaw Totem (totem sub-row)
-- Add PLAYER_TOTEM_UPDATE to the condition's check-on events so the glow updates on drop/expire.
-- Scans all totem slots (Fire=1 Earth=2 Water=3 Air=4); slot order is irrelevant.
function()
    local name = "Earthbind Totem"                          -- ← change per icon
    for slot = 1, (MAX_TOTEMS or 4) do
        local _, tName, _, tDur = GetTotemInfo(slot)
        if tName == name and tDur and tDur > 0 then
            return true
        end
    end
    return false
end
