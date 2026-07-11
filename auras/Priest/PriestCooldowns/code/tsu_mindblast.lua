-- Dwarf Priest Cooldowns — Mind Blast (Shadow-only) — Trigger ▸ Custom ▸ Trigger State Updater
-- Reveals ONLY when the character knows Shadowform (i.e. a real Shadow build); otherwise stays
-- hidden and the dynamic group collapses the slot. Then tracks Mind Blast's cooldown BY NAME.
-- Spell ids (reference): Mind Blast 8092 · gate spell Shadowform 15473
--   https://www.wowhead.com/classic/spell=8092  https://www.wowhead.com/classic/spell=15473
-- Events box: SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD
function(allstates)
    local name = "Mind Blast"
    if not GetSpellInfo("Shadowform") then                  -- not a Shadow build -> hide
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
