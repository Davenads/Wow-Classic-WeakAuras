-- Betty's 19 Shaman Cooldowns — <SLOT> slot totem — Trigger ▸ Custom ▸ Trigger State Updater
-- Shows WHATEVER totem currently occupies one totem SLOT (Fire = 1, Earth = 2), with that
-- totem's own icon and remaining lifetime swipe. ONE shared TSU for the two slot dots — only
-- the SLOT line changes per icon. A 19 only ever has a Fire and an Earth slot, and each slot
-- holds one totem at a time, so two slot icons cover the whole kit with NO name list to keep:
-- Stoneskin, Strength of Earth, Earthbind, Stoneclaw, Tremor (Earth) / Searing, Fire Nova (Fire)
-- all light the right dot automatically the moment they're planted.
-- GetTotemInfo(slot) -> haveTotem, name, startTime, duration, icon  (native on current Classic
--   Era / SoD / Cata / MoP). If a client ever stubs it, the dot just never shows (safe no-op).
-- Events box: PLAYER_TOTEM_UPDATE PLAYER_ENTERING_WORLD
function(allstates)
    local SLOT = 2                                          -- ← 1 = Fire slot, 2 = Earth slot
    local have, tName, startTime, duration, tIcon = GetTotemInfo(SLOT)
    if have and tName and tName ~= "" and duration and duration > 0 then
        local st = allstates[""] or {}
        st.show = true
        st.changed = true
        st.icon = tIcon
        st.name = tName
        st.progressType = "timed"                           -- swipe = totem's remaining lifetime
        st.duration = duration
        st.expirationTime = startTime + duration
        allstates[""] = st
    else
        allstates[""] = { show = false, changed = true }    -- slot empty → dot collapses out
    end
    return true
end
