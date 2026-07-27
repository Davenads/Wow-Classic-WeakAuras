-- Betty's 19 Shaman Cooldowns — <SPELL> — Trigger ▸ Custom ▸ Trigger State Updater
-- Tracks a spell's cooldown BY NAME (rank-proof; self-hides if the char doesn't know it).
-- ONE shared TSU for every plain cooldown icon in the primary + totem sub-row — only the
-- `name` line changes per icon:
--     War Stomp (120s)  /  Earth Shock (6s, shared w/ Flame Shock)
--     Earthbind Totem (15s)  /  Fire Nova Totem (15s)  /  Stoneclaw Totem (30s)
-- The three totem icons ALSO get a "planted" Glow via conditions.lua (that's a Condition,
-- not part of this TSU). Cloned verbatim from Betty's 19 Paladin Cooldowns tsu_spell.
-- Spell id (reference, War Stomp): 20549  https://www.wowhead.com/classic/spell=20549
-- Events box: SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD
function(allstates)
    local name = "War Stomp"                                -- ← change per icon
    local sName, _, sIcon = GetSpellInfo(name)
    if not sName then
        allstates[""] = { show = false, changed = true }    -- spell not known (e.g. War Stomp on non-Tauren)
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
