-- Dwarf Priest Cooldowns — Fade — Trigger ▸ Custom ▸ Trigger State Updater
-- Tracks Fade's cooldown BY NAME (rank-proof; self-hides if the char doesn't know it,
-- e.g. an untalented ability or the wrong race). WA renders the swipe + number from the timer.
-- Spell id (reference): 586  https://www.wowhead.com/classic/spell=586
-- Events box: SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD
--
-- SHARED template for the six plain spell icons. Each pastes an identical block; the ONLY line
-- that changes per icon is `local name = "..."` (and the reference comment):
--   Fade (586) · Psychic Scream (8122) · Fear Ward (6346, Dwarf racial)
--   Desperate Prayer (13908, Dwarf racial) · Stoneform (20594, Dwarf racial)
--   Inner Focus (14751, Discipline talent)
-- Mind Blast uses its own gated block (code/tsu_mindblast.lua); items use tsu_item / tsu_rune.
function(allstates)
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
        st.progressType = "static"
        st.value, st.total = 1, 1
    end
    allstates[""] = st
    return true
end
