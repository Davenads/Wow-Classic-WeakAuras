-- WSG Res-Deny Callout — Actions → On Show (actions.start.custom)
-- Arms the engine: a fast ticker drives the res-wave detector (needs ~0.1s resolution to
-- catch a graveyard wave) and the decision core. Warns once if enemy nameplates are off —
-- without them (or a teammate targeting the enemy) we can't read low-HP enemies.

if aura_env.ticker then aura_env.ticker:Cancel() end
aura_env.ticker = C_Timer.NewTicker(0.1, function()
    aura_env.rc:trySeedFromHealer()                 -- self-seed if we imported/reloaded mid-match
    aura_env.rc:detectWave(aura_env.cfg.wsgRezThreshold)
    aura_env.Evaluate()
end)

if aura_env.cfg.mode == "SELF" then
    print("|cffffcc00[ResDeny]|r Dry-run ON — callouts print locally only. "
        .. "Uncheck 'Dry run' in the aura's Custom Options to post to /bg.")
end

if GetCVar and GetCVar("nameplateShowEnemies") == "0" then
    print("|cffffcc00[ResDeny]|r Enemy nameplates are OFF — press V (or run "
        .. "/console nameplateShowEnemies 1) so low-HP enemies can be read. "
        .. "(Teammates targeting them still shares HP via raid-target scan.)")
end
