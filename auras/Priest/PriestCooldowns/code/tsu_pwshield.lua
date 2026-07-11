-- Dwarf Priest Cooldowns — Power Word: Shield (4s CD + Weakened Soul lockout) — Trigger ▸ Custom ▸ Trigger State Updater
-- PW:S has TWO re-cast limiters in Classic Era: a real 4s spell cooldown (any target) and the
-- Weakened Soul debuff (~15s) that blocks re-shielding the SAME unit. This icon shows PW:S art
-- and paints whichever lockout ends later — the 4s cooldown always, plus the 15s Weakened Soul
-- window when you shield YOURSELF (it watches Weakened Soul on the player). Self-hides if the
-- char doesn't know PW:S.
-- Spell ids (reference): Power Word: Shield 17 · Weakened Soul 6788
--   https://www.wowhead.com/classic/spell=17  https://www.wowhead.com/classic/spell=6788
-- Events box: SPELL_UPDATE_COOLDOWN UNIT_AURA:player PLAYER_ENTERING_WORLD LEARNED_SPELL_IN_TAB
function(allstates)
    local sName, _, sIcon = GetSpellInfo("Power Word: Shield")
    if not sName then
        allstates[""] = { show = false, changed = true }    -- PW:S not known -> hide
        return true
    end
    local bestDur, bestExp                                   -- show whichever lockout ends later
    local start, dur = GetSpellCooldown("Power Word: Shield") -- real 4s spell cooldown
    if start and dur and dur > 1.5 then                      -- (> 1.5 skips the GCD)
        bestDur, bestExp = dur, start + dur
    end
    for i = 1, 40 do                                         -- Weakened Soul on self = re-shield lockout
        local n, _, _, _, d, e = UnitDebuff("player", i)
        if not n then break end
        if n == "Weakened Soul" then
            if not bestExp or e > bestExp then
                bestDur, bestExp = d, e
            end
            break
        end
    end
    local st = allstates[""] or {}
    st.show = true
    st.changed = true
    st.icon = sIcon
    st.name = sName
    if bestExp and bestDur and bestDur > 0 then
        st.progressType = "timed"
        st.duration = bestDur
        st.expirationTime = bestExp
    else
        st.progressType = "timed"   -- ready: 0-duration draws no swipe (icon stays bright)
        st.duration = 0
        st.expirationTime = 0
    end
    allstates[""] = st
    return true
end
