-- WSG Enemy FC Announcer — Display → Text → custom "%c" (Display Text is "%c").
-- Local readout of the tracked enemy flag carrier + best-known HP (own read white,
-- addon-shared read grey); blank when no carrier. Purely informational for you — the
-- /bg messages are sent from the trigger helpers. On flavors with the top-center flag
-- widget the same readout is mirrored there (aura_env.UpdateWidget).

function()
    return aura_env.ReadoutText and aura_env.ReadoutText() or ""
end
