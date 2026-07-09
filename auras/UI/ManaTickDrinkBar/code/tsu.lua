-- Mana Tick Drink Bar — Trigger ▸ Custom ▸ Trigger State Updater (triggers[1].trigger.custom)
-- Events box:  UNIT_POWER_UPDATE UNIT_AURA PLAYER_ENTERING_WORLD
--
-- Drives allstates[""] as a 2 s "timed" progress bar re-anchored at EVERY observed drink tick,
-- so the region animates a fresh 0→1 sweep each cycle and the spark reaches the far-right edge
-- exactly when the next tick lands ("instant restart"). Between events WA interpolates the bar
-- on its own — no per-frame code. REGION MUST BE SET TO INVERSE so the spark travels
-- left→right toward expirationTime (default timed bars deplete right→left).
function(allstates, event, unit, powerType)
    local ae  = aura_env
    local now = GetTime()

    -- drink on / off
    if event == "UNIT_AURA" or event == "PLAYER_ENTERING_WORLD" then
        local d = ae.IsDrinking()
        if not d then ae.tickAnchor = nil end   -- drop sync the instant we stop drinking
        ae.drinking = d
    end

    -- Track mana every update; a drink tick = mana rose WHILE drinking → (re)anchor the cycle
    -- to this instant. DEDUPE rejects a second UNIT_POWER_UPDATE for the same tick.
    if event == "UNIT_POWER_UPDATE" and unit == "player" and powerType == "MANA" then
        local m = ae.ManaNow()
        if ae.drinking and m > ae.lastMana
           and (not ae.tickAnchor or (now - ae.tickAnchor) >= ae.DEDUPE) then
            ae.tickAnchor = now
        end
        ae.lastMana = m
    end

    local s = allstates[""]
    -- Show a synced, sweeping bar only while drinking, after the first tick locks the phase,
    -- and while not already at full mana (nothing to time once you're capped).
    if ae.drinking and ae.tickAnchor and not ae.ManaFull() then
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
