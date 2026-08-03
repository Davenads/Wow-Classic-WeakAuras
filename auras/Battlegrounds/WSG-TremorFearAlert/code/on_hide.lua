-- WSG Tremor Fear Alert — Actions → On Hide (actions.finish.custom)
-- Cancel the ticker when the aura hides (leaving WSG) so nothing scans outside the BG.

if aura_env.ticker then
    aura_env.ticker:Cancel()
    aura_env.ticker = nil
end
