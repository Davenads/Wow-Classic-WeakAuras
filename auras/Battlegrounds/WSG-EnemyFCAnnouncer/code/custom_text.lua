-- WSG Enemy FC Announcer — Display → Text → custom "%c" (Display Text is "%c").
-- Local readout of the tracked enemy flag carrier + best-known HP (own read white,
-- addon-shared read grey); blank when no carrier. Purely informational for you — the
-- /bg messages are sent from the trigger helpers.
--
-- The widget hook (Cata/MoP Classic) mirrors this readout next to the flag-capture
-- counter. To avoid showing the EFC TWICE, this region collapses to "" whenever the
-- widget is live (aura_env.widgetText set). On flavors WITHOUT the widget (e.g. Era)
-- widgetText stays nil, so this region remains the sole display (the intended fallback).

function()
    if aura_env.widgetText then return "" end
    return aura_env.ReadoutText and aura_env.ReadoutText() or ""
end
