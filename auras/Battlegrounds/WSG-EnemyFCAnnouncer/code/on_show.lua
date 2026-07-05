-- WSG Enemy FC Announcer — Actions → On Show (actions.start.custom)
-- Arms the announcer: starts a 1s ticker that drives periodic HP checks (so reminders
-- fire even when the carrier's health is static / no UNIT_HEALTH events), and warns
-- once if enemy nameplates are disabled (needed to read HP when you can't target them).

if aura_env.ticker then aura_env.ticker:Cancel() end
aura_env.ticker = C_Timer.NewTicker(1, function() aura_env.Tick() end)

if GetCVar and GetCVar("nameplateShowEnemies") == "0" then
    print("|cffffcc00[EFC Announcer]|r Enemy nameplates are OFF — press V (or run "
        .. "/console nameplateShowEnemies 1) so the announcer can read the flag "
        .. "carrier's health when you're not targeting them.")
end
