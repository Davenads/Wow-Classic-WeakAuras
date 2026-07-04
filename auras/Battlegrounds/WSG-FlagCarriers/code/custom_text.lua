-- WSG Flag Carriers — Display → Text → custom "%c" function.
-- Set the region's Display Text to "%c". Renders both carriers as TWO STACKED LINES so
-- each name sits beside its own native WSG counter row instead of colliding on one line:
--   line 1 (top)    = Alliance player carrying the HORDE flag    → Alliance blue
--   line 2 (bottom) = Horde player carrying the ALLIANCE flag     → Horde red
-- Both lines are ALWAYS emitted (blank when that flag isn't held) so the row that IS
-- shown stays vertically pinned to its counter rather than recentering onto the icons.
-- The region is right-justified and anchored just left of the counter column (see the
-- geometry in aura.json / export.txt), so names flank the counters without covering the
-- flag icons. Row order (top vs bottom) is trivially swappable — verify in-game.

function()
    local fc = aura_env.fc or {}
    local top    = fc.horde    and ("|cff3399ff" .. fc.horde    .. "|r") or ""
    local bottom = fc.alliance and ("|cffff3333" .. fc.alliance .. "|r") or ""
    return top .. "\n" .. bottom
end
