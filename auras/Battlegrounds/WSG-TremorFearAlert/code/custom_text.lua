-- WSG Tremor Fear Alert — Display → Text, custom "%c" function
-- Returns the colored alert line built by Evaluate() (or "" when idle). Never sent to
-- chat — this is the on-screen HUD only. Refreshes every frame (customTextUpdate=update).

function()
    return aura_env.alertText or ""
end
