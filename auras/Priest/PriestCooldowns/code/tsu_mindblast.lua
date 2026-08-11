-- Dwarf Priest Cooldowns — Mind Blast (Shadow-gated) — Trigger ▸ Custom ▸ Trigger State Updater
-- Reveals ONLY when the character has Mind Flay talented (a real shadow investment, 10+ pts);
-- otherwise stays hidden and the dynamic group collapses the slot. Then tracks Mind Blast BY NAME.
-- Mind Flay is a talent-only spell, so "knows it" == "talented it" (no talent-tree parsing needed).
-- Spell ids (reference): Mind Blast 8092 · gate spell Mind Flay 15407
--   https://www.wowhead.com/classic/spell=8092  https://www.wowhead.com/classic/spell=15407
-- Events box: SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB CHARACTER_POINTS_CHANGED PLAYER_ENTERING_WORLD
function(allstates)
    local name = "Mind Blast"
    if not GetSpellInfo("Mind Flay") then                   -- Mind Flay not talented -> hide
        allstates[""] = { show = false, changed = true }
        return true
    end
    local sName, _, sIcon = GetSpellInfo(name)
    if not sName then
        allstates[""] = { show = false, changed = true }
        return true
    end
    local start, dur = GetSpellCooldown(name)
    local st = allstates[""] or {}
    st.show = true
    st.changed = true
    st.icon = sIcon
    st.name = sName
    if start and dur and dur > 1.5 then
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
