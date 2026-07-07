-- WSG Enemy FC Announcer — Actions → On Show (actions.start.custom)
-- Arms the announcer: a 1s ticker drives the periodic HP read (so milestones/reminders
-- fire even when the carrier's health is static / no UNIT_HEALTH events), refreshes the
-- top-center widget if present, and re-attempts the widget hook (the flag frame can
-- appear after load / after leaving combat). Warns once if enemy nameplates are off.

if aura_env.ticker then aura_env.ticker:Cancel() end
aura_env.ticker = C_Timer.NewTicker(1, function()
    aura_env.InitWidget()
    aura_env.Tick()
end)

if GetCVar and GetCVar("nameplateShowEnemies") == "0" then
    print("|cffffcc00[EFC Announcer]|r Enemy nameplates are OFF — press V (or run "
        .. "/console nameplateShowEnemies 1) so you can read the flag carrier's health "
        .. "when you're not targeting them. (Teammates targeting them still shares HP.)")
end
