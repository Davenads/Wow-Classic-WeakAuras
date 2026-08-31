-- Priest Cooldowns — Psychic Scream — Trigger ▸ Custom ▸ Trigger State Updater
-- Tracks Psychic Scream's cooldown BY NAME (rank-proof; self-hides if the char doesn't know it,
-- e.g. an untalented ability or the wrong race). WA renders the swipe + number from the timer.
-- Spell id (reference): 8122  https://www.wowhead.com/classic/spell=8122
-- Events box: SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD
--
-- SHARED template for the eight plain spell icons. Each pastes an identical block; the ONLY line
-- that changes per icon is `local name = "..."` (and the reference comment):
--   Psychic Scream (8122) · Fear Ward (6346, Dwarf racial) · Desperate Prayer (13908, Dwarf racial)
--   Stoneform (20594, Dwarf racial) · Will of the Forsaken (7744, Undead racial)
--   Inner Focus (14751, Discipline talent) · Power Infusion (10060, Discipline talent)
--   Devouring Plague (19276, Undead priest spell, trained lvl 20)
-- Because by-name resolves nil when the spell isn't in the spellbook, the racials/class/talent
-- spells self-gate: Will of the Forsaken shows only for Undead, Devouring Plague only once learned,
-- Power Infusion only when talented. Mind Blast uses its own gated block (code/tsu_mindblast.lua)
-- and Fade its PvE-instance-gated block (code/tsu_fade.lua); items use tsu_item / tsu_rune.
function(allstates)
    local name = "Psychic Scream"
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
