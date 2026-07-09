-- Mana Tick Drink Bar — Actions ▸ On Init (actions.init.custom)
-- State + helpers for a spark line that sweeps the player mana bar and reaches the far-right
-- edge at each 2 s mana-regen tick (the rolling server heartbeat). The bar is a PERSISTENT
-- metronome: it stays visible whenever mana is below max and re-syncs to every observed tick
-- (drinking OR out-of-combat spirit regen), so it never blinks out when you stutter-step /
-- briefly stop drinking — you're already synced to the tick before you even sit down.
-- Target: WoW Classic Era (mana ticks every 2.0 s).

-- Enum.PowerType.Mana is 0 on Classic; fall back to the literal if Enum is unavailable.
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
aura_env.MANA   = MANA
aura_env.TICK   = 2.0     -- Classic mana-regen tick period (seconds)
aura_env.DEDUPE = 1.5     -- ignore mana gains within this many s of the last tick (event dedupe)

aura_env.lastMana   = UnitPower("player", MANA) or 0
aura_env.tickAnchor = nil    -- GetTime() of the most recently observed regen tick (sync point)

function aura_env.ManaNow()  return UnitPower("player", MANA) or 0 end
function aura_env.ManaFull() return aura_env.ManaNow() >= (UnitPowerMax("player", MANA) or 0) end
