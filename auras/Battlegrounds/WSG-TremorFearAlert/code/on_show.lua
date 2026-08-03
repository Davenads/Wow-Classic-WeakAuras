-- WSG Tremor Fear Alert — Actions → On Show (actions.start.custom)
-- Ticker drives the alert between events: expires enemy cast pre-alerts (~1.5s window),
-- re-checks tremor status, and clears the call once a fear fades. 0.3s is responsive
-- without being wasteful.

if aura_env.ticker then aura_env.ticker:Cancel() end
aura_env.ticker = C_Timer.NewTicker(0.3, function()
    aura_env.Evaluate()
end)
