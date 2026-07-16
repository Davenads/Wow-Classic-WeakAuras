-- Incoming Heals Indicator — Display ▸ Text, custom "%c" function
-- Pastes into the "%c" custom function box of a Text sub-element on the region.
-- Renders: class-colored caster · amount (green, or red when it would overheal) · a
-- "(-NN%)" flag when a heal-reduction modifier (Mortal Strike, Wound Poison, …) is active.
--   e.g.  Greater Heal  +4.2k        (normal)
--         Flash Heal  +900  (-50%)   (Mortal Strike up)
-- Simpler no-%c alternative: set the text string to  %casterName  +%amount .
function()
    local s = aura_env.state
    if not s or not s.show or not s.hasAmount then return "" end

    -- caster, class-colored when we know the GUID
    local who = s.casterName or s.spellName
    if who and s.casterGUID then
        local _, class = GetPlayerInfoByGUID(s.casterGUID)
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            who = string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, who)
        end
    end

    -- amount, colored red if the heal would overheal, green otherwise
    local amt, amtStr = s.amount or 0, ""
    if amt > 0 then
        amtStr = (amt >= 1000) and string.format("+%.1fk", amt / 1000) or ("+" .. amt)
        amtStr = "|c" .. (s.overheal and "ffff5555" or "ff40ff40") .. amtStr .. "|r"
    end

    -- heal-reduction flag
    local mod = ""
    if s.modifier and s.modifier < 0.999 then
        mod = string.format("  |cffff2020(-%d%%)|r", math.floor((1 - s.modifier) * 100 + 0.5))
    end

    local out = {}
    if who then out[#out + 1] = who end
    if amtStr ~= "" then out[#out + 1] = amtStr end
    return table.concat(out, "  ") .. mod
end
