-- WSG Flag Carriers — Display → Text → custom "%c" function.
-- Set the region's Display Text to "%c". Renders both carriers, colored:
--   left  = Alliance player holding the Horde flag    → Alliance blue
--   right = Horde player holding the Alliance flag     → Horde red
-- (Left/right pairs each name with its team's score, since a team scores by capping the
-- enemy flag its own player carries.)

function()
    local fc = aura_env.fc or {}
    local left  = fc.horde    and ("|cff3399ff" .. fc.horde    .. "|r") or ""
    local right = fc.alliance and ("|cffff3333" .. fc.alliance .. "|r") or ""
    if left ~= "" and right ~= "" then
        return left .. "          " .. right
    end
    return left .. right
end
