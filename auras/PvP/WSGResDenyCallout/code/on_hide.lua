-- WSG Res-Deny Callout — Actions → On Hide (actions.finish.custom)
-- Cancels the ticker when the aura hides (leaving WSG) so it doesn't keep scanning /
-- announcing outside the battleground.

if aura_env.ticker then
    aura_env.ticker:Cancel()
    aura_env.ticker = nil
end
