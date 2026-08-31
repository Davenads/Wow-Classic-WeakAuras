-- Priest Cooldowns — Fade (PvE-instance-gated) — Trigger ▸ Custom ▸ Trigger State Updater
-- Shows ONLY inside a PvE instance (5-man "party" or "raid"); hidden in the open world,
-- battlegrounds ("pvp") and arenas ("arena"). Then tracks Fade's cooldown BY NAME (rank-proof).
-- IsInInstance() -> isInstance, instanceType; PLAYER_ENTERING_WORLD/ZONE_CHANGED_NEW_AREA re-gate on zone.
-- Spell id (reference): 586  https://www.wowhead.com/classic/spell=586
-- Events box: SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD ZONE_CHANGED_NEW_AREA
function(allstates)
    local _, instType = IsInInstance()
    if instType ~= "party" and instType ~= "raid" then      -- PvE instances only; hides in pvp/arena/world
        allstates[""] = { show = false, changed = true }
        return true
    end
    local name = "Fade"
    local sName, _, sIcon = GetSpellInfo(name)
    if not sName then
        allstates[""] = { show = false, changed = true }   -- spell not known -> hide (group collapses)
        return true
    end
    local start, dur = GetSpellCooldown(name)
    local st = allstates[""] or {}
    st.show = true
    st.changed = true
    st.icon = sIcon
    st.name = sName
    if start and dur and dur > 1.5 then                     -- dur > 1.5 filters the GCD
        st.progressType = "timed"
        st.duration = dur
        st.expirationTime = start + dur
    else
        st.progressType = "timed"   -- ready: 0-duration draws no swipe (icon stays bright)
        st.duration = 0
        st.expirationTime = 0
    end
    allstates[""] = st
    return true
end