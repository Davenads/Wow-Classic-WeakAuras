-- PvP Trinket Auto-Swap — Controller — Actions ▸ On Show
-- 1s ticker handles AGM-lock expiry and "soonest returning" re-ordering (rows 6/8).
if aura_env.ticker then aura_env.ticker:Cancel() end
aura_env.ticker = C_Timer.NewTicker(1, function()
    aura_env.RefreshInsignia()
    aura_env.WatchAGM()
    aura_env.Apply()
end)
