-- WSG Res-Deny Callout — Display → Text, custom "%c" function
-- Local status readout (this player only — never sent to chat). Shows the predicted enemy
-- graveyard countdown and how many low-HP non-EFC targets are currently in "hold" range,
-- so you can eyeball that the clock is seeded and the detector is live.

function()
    if not aura_env.cfg.showIndicator then return "" end
    if not aura_env.enabled then return "" end
    if not aura_env.rc:isSeeded() then
        return "|cff888888Res Deny: waiting for match start…|r"
    end
    local rem = aura_env.lastRem or aura_env.rc:enemyRemaining(aura_env.cfg.enemyGyOffset)
    local n = aura_env.candidateCount or 0
    local col = (rem and rem <= aura_env.cfg.gyLowThreshold) and "|cff55ff55" or "|cffffffff"
    return string.format("%sEnemy rez: %.1fs|r  |cffff5555hold: %d|r", col, rem or 0, n)
end
