-- WSG Enemy FC Announcer — Display → Text → custom "%c" (Display Text is "%c").
-- Local readout of the tracked enemy flag carrier + last-known HP; blank when none.
-- Purely informational for you; the /bg messages are sent from the trigger helpers.

function()
    local e = aura_env.efc
    if not e or not e.name then return "" end
    local hp = e.hp and (" " .. math.floor(e.hp + 0.5) .. "%") or ""
    return "|cffff5555EFC|r " .. e.name .. hp
end
