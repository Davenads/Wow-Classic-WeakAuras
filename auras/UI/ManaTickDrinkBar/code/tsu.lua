-- Mana Tick Drink Bar — Trigger ▸ Custom ▸ Trigger State Updater (triggers[1].trigger.custom)
-- Events box:  UNIT_POWER_UPDATE PLAYER_ENTERING_WORLD
--
-- Persistent metronome. Drives allstates[""] as a 2 s "timed" progress bar re-anchored at
-- EVERY observed mana-regen tick (drinking OR out-of-combat spirit regen — both are the same
-- 2 s server heartbeat), so the region animates a fresh sweep each cycle and the spark reaches
-- the far-right edge exactly when the next tick lands. It shows whenever mana is below max and
-- NEVER blinks out when you stop drinking / stutter-step. Between events WA interpolates the bar
-- on its own — no per-frame code. REGION MUST BE SET TO INVERSE so the spark travels
-- left→right toward expirationTime (default timed bars deplete right→left).
function(allstates, event, unit, powerType)
    local ae  = aura_env
    local now = GetTime()

    if event == "PLAYER_ENTERING_WORLD" then
        ae.lastMana   = ae.ManaNow()
        ae.tickAnchor = now
    end

    -- Seed a cadence anchor so the metronome shows immediately, even before the first
    -- witnessed tick; it self-corrects the moment a real mana-regen tick is observed.
    if not ae.tickAnchor then ae.tickAnchor = now end

    -- A mana-regen tick = mana rose. Re-anchor the cycle to this instant. DEDUPE rejects a
    -- second UNIT_POWER_UPDATE reporting the same tick. No drinking gate: out-of-combat
    -- spirit regen ticks on the same heartbeat and keeps the metronome synced between drinks.
    if event == "UNIT_POWER_UPDATE" and unit == "player" and powerType == "MANA" then
        local m = ae.ManaNow()
        if m > ae.lastMana and (now - ae.tickAnchor) >= ae.DEDUPE then
            ae.tickAnchor = now
        end
        ae.lastMana = m
    end

    local s = allstates[""]
    -- Show a synced, sweeping bar whenever mana is below max (nothing to time once capped).
    if not ae.ManaFull() then
        local nextTick = ae.tickAnchor + ae.TICK
        while nextTick <= now do nextTick = nextTick + ae.TICK end   -- keep prediction in the future
        allstates[""] = {
            show           = true,
            changed        = true,
            progressType   = "timed",
            duration       = ae.TICK,
            expirationTime = nextTick,
            autoHide       = false,
        }
    elseif s and s.show then
        s.show = false
        s.changed = true
    end
    return true
end
