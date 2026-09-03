-- Betty's BG Item Callout (19 bracket) — Display → Text, custom "%c" function
-- Pastes into: WA options → Display → Text → the "%c" custom function box.
-- Identical in all 10 children. Renders the ENEMY caster's name in their class color.
-- state.sourceGUID / state.sourceName come from the combat-log trigger's source unit.

function()
    local state = aura_env.state

    if state and state.sourceGUID and state.sourceName then
        local class = select(2, GetPlayerInfoByGUID(state.sourceGUID))
        local name = select(6, GetPlayerInfoByGUID(state.sourceGUID))

        if not class then
            -- The GUID isn't for a known player, or data isn't cached yet
            return (name or state.sourceName)
        end

        local color = RAID_CLASS_COLORS[class]
        return string.format("|cFF%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name or state.sourceName)
    end
    return state and state.sourceName or nil
end
