-- shared/flavor.lua — detect the Classic flavor at runtime.
-- Paste into an aura's On Init to branch code that must span flavors. See
-- docs/classic-api.md §1. Returns nothing; sets aura_env.flavor to a short string.

local PID = WOW_PROJECT_ID
if PID == WOW_PROJECT_CLASSIC then
    aura_env.flavor = "era"          -- Classic Era / SoD / Hardcore (old talents, no spec)
elseif PID == WOW_PROJECT_CATACLYSM_CLASSIC then
    aura_env.flavor = "cata"         -- has GetSpecialization
elseif PID == WOW_PROJECT_MISTS_CLASSIC then
    aura_env.flavor = "mists"        -- has GetSpecialization
elseif PID == WOW_PROJECT_MAINLINE then
    aura_env.flavor = "retail"       -- not a target for this repo
else
    aura_env.flavor = "unknown"
end
