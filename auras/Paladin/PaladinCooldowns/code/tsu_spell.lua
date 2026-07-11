-- Betty's 19 Paladin Cooldowns — Divine Protection — Trigger ▸ Custom ▸ Trigger State Updater
-- Tracks Divine Protection's cooldown BY NAME (rank-proof; self-hides if the char doesn't know it,
-- e.g. Stoneform on a non-Dwarf). WA renders the swipe + number from the state's timer.
-- Spell id (reference): 498  https://www.wowhead.com/classic/spell=498
-- Events box: SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD
--
-- SHARED template for all seven spell icons. Each pastes an identical block; the ONLY line that
-- changes per icon is `local name = "..."` (and the reference comment):
--   Hammer of Justice (853) · Divine Protection (498) · Blessing of Protection (1022)
--   Blessing of Freedom (1044) · Lay on Hands (633) · Judgement (20271)
--   Stoneform (20594, self-hides on non-Dwarf)
function(allstates)
    local name = "Divine Protection"
    local sName, _, sIcon = GetSpellInfo(name)
    if not sName then
        allstates[""] = { show = false, changed = true }   -- spell not known (e.g. Stoneform on non-Dwarf)
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
