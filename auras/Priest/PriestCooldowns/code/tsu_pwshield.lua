-- Dwarf Priest Cooldowns — Power Word: Shield (Weakened Soul lockout) — Trigger ▸ Custom ▸ Trigger State Updater
-- PW:S has NO spell cooldown; the re-shield limiter is the Weakened Soul debuff (~15s) on the
-- target. This icon shows PW:S art and paints a swipe = time until you can re-shield YOURSELF
-- (it watches Weakened Soul on the player). Self-hides if the char doesn't know PW:S.
-- Spell ids (reference): Power Word: Shield 17 · Weakened Soul 6788
--   https://www.wowhead.com/classic/spell=17  https://www.wowhead.com/classic/spell=6788
-- Events box: UNIT_AURA:player PLAYER_ENTERING_WORLD LEARNED_SPELL_IN_TAB
function(allstates)
    local sName, _, sIcon = GetSpellInfo("Power Word: Shield")
    if not sName then
        allstates[""] = { show = false, changed = true }    -- PW:S not known -> hide
        return true
    end
    local dur, exp                                           -- Weakened Soul on the player = re-shield lockout
    for i = 1, 40 do
        local n, _, _, _, d, e = UnitDebuff("player", i)
        if not n then break end
        if n == "Weakened Soul" then
            dur, exp = d, e
            break
        end
    end
    local st = allstates[""] or {}
    st.show = true
    st.changed = true
    st.icon = sIcon
    st.name = sName
    if exp and dur and dur > 0 then
        st.progressType = "timed"
        st.duration = dur
        st.expirationTime = exp
    else
        st.progressType = "static"
        st.value, st.total = 1, 1
    end
    allstates[""] = st
    return true
end
