-- WSG Enemy FC Announcer — Actions → On Hide (actions.finish.custom)
-- Disarms: cancel the ticker so it doesn't leak across /reload or zone changes.

if aura_env.ticker then aura_env.ticker:Cancel(); aura_env.ticker = nil end
