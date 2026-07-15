-- Incoming Heals Indicator — Display ▸ Text, custom "%c" function
-- Pastes into the "%c" custom function box of a Text sub-element on the region.
-- Renders the predicted amount (and caster when known): "Greater Heal  +4.2k".
-- Simpler alternative that needs NO %c: put the raw custom fields in the text string,
-- e.g.  %casterName  +%amount  — WA substitutes them directly from the state.
function()
    local s = aura_env.state
    if not s or not s.show or not s.hasAmount then return "" end

    local amt = s.amount or 0
    local amtStr = ""
    if amt > 0 then
        if amt >= 1000 then
            amtStr = string.format("+%.1fk", amt / 1000)
        else
            amtStr = "+" .. amt
        end
    end

    local who = s.casterName
    if who and amtStr ~= "" then
        return who .. "  " .. amtStr
    end
    return who or amtStr
end
