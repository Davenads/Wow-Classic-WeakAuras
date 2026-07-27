-- Betty's 19 Shaman Cooldowns — <TOTEM> presence dot — Trigger ▸ Custom ▸ Trigger State Updater
-- Shows a small icon ONLY while the named totem is physically planted (presence only — no
-- cooldown swipe). ONE shared TSU for the two no-CD totem dots — only the `name` line changes:
--     Tremor Totem  (Earth slot, fear/charm/sleep break)
--     Searing Totem (Fire slot, passive DPS)
-- Reads GetTotemInfo (Fire=1 Earth=2 Water=3 Air=4) and scans ALL slots, so the slot order
-- never matters. A slot counts as active when its totem name matches and duration > 0.
-- NOTE: GetTotemInfo is native on current Classic Era / SoD / Cata / MoP clients. If a client
--   ever stubs it, these dots simply never show (safe no-op) — the CD icons are unaffected.
-- Events box: PLAYER_TOTEM_UPDATE PLAYER_ENTERING_WORLD
function(allstates)
    local name = "Tremor Totem"                             -- ← change per icon (Tremor Totem / Searing Totem)
    local foundIcon
    for slot = 1, (MAX_TOTEMS or 4) do
        local _, tName, _, tDur, tIcon = GetTotemInfo(slot)
        if tName == name and tDur and tDur > 0 then
            foundIcon = tIcon
            break
        end
    end
    if foundIcon then
        local st = allstates[""] or {}
        st.show = true
        st.changed = true
        st.icon = foundIcon
        st.name = name
        st.progressType = "timed"   -- presence only: keep the dot lit, no swipe
        st.duration = 0
        st.expirationTime = 0
        allstates[""] = st
    else
        allstates[""] = { show = false, changed = true }    -- totem not down → dot collapses out
    end
    return true
end
