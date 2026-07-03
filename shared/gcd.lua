-- shared/gcd.lua — read the current global cooldown on Classic.
-- Paste where needed (e.g. a custom trigger/condition). Returns start, duration.
-- Uses the standard dummy GCD spell ID 61304. See docs/classic-api.md §2.
-- Note: on Classic Era the GCD is ~1.5s and largely not haste-scaled.

local GCD_SPELL = 61304

local function GetGCD()
    local start, duration = GetSpellCooldown(GCD_SPELL)
    if start and duration and duration > 0 then
        return start, duration
    end
    return 0, 0
end

return GetGCD
