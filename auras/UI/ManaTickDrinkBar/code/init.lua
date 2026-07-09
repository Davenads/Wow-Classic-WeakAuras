-- Mana Tick Drink Bar — Actions ▸ On Init (actions.init.custom)
-- State + helpers for a spark line that sweeps the player mana bar and reaches the far-right
-- edge at each 2 s mana-regen tick WHILE DRINKING — so you can stutter-step (move between
-- ticks, be stationary the instant one lands) without losing regen.
-- Target: WoW Classic Era (mana ticks every 2.0 s). enUS buff names.

-- Enum.PowerType.Mana is 0 on Classic; fall back to the literal if Enum is unavailable.
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
aura_env.MANA   = MANA
aura_env.TICK   = 2.0     -- Classic mana-regen tick period (seconds)
aura_env.DEDUPE = 1.5     -- ignore mana gains within this many s of the last tick (event dedupe)

aura_env.lastMana   = UnitPower("player", MANA) or 0
aura_env.tickAnchor = nil    -- GetTime() of the most recently observed regen tick (sync point)
aura_env.drinking   = false

-- Are we drinking? Match the "Drink" buff (enUS); Cata/MoP conjured food is "Refreshment".
-- Localize these two names for non-enUS clients. Uses AuraUtil when present, else a buff scan.
function aura_env.IsDrinking()
    if AuraUtil and AuraUtil.FindAuraByName then
        return AuraUtil.FindAuraByName("Drink", "player") ~= nil
            or AuraUtil.FindAuraByName("Refreshment", "player") ~= nil
    end
    for i = 1, 40 do
        local n = UnitBuff("player", i)
        if not n then break end
        if n == "Drink" or n == "Refreshment" then return true end
    end
    return false
end

function aura_env.ManaNow()  return UnitPower("player", MANA) or 0 end
function aura_env.ManaFull() return aura_env.ManaNow() >= (UnitPowerMax("player", MANA) or 0) end
