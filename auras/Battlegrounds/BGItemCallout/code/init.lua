-- Betty's BG Item Callout (19 bracket) — Actions → On Init (GROUP container)
-- Pastes into: WA options → (the GROUP) → Actions → On Init → Custom code.
--
-- Phase 0 scaffold ONLY. This block creates the shared BGICHub named global frame exactly
-- once. WeakAuras children do NOT share aura_env, so any cross-child state (server-time
-- stamps, multi-witness corroboration, the addon bus) must live on a *named* global frame —
-- the same mechanism proven by WSGCalloutHub in this repo.
--
-- IMPORTANT: this changes NO announce behavior. The 10 children keep their existing
-- combat-log triggers and built-in Send Chat Message actions. The hub merely exists,
-- registers its addon prefix, and listens; nothing broadcasts and the receiver is a no-op
-- until later phases wire it up. If in-game testing shows a dynamicgroup's On Init does not
-- run, paste this same (idempotent) block into any one child's On Init instead.
if not BGICHub then
    local NS = CreateFrame("Frame", "BGICHub")
    NS.schema = 0                 -- addon-payload/schema version; bumped as phases land
    NS.ADDON_PREFIX = "BGIC"      -- <= 16 chars (C_ChatInfo prefix limit)

    -- Realm-strip a name: "Betty-Whitemane" -> "Betty".
    local function strip(n) return n and n:gsub("%-.*$", "") or n end
    NS.strip = strip

    -- Server-synced wall clock: identical integer for every client on the realm. This is both
    -- the human timestamp source (Phase 1) and the cross-witness event-key clock (Phase 3).
    function NS.now()
        return (GetServerTime and GetServerTime()) or time()
    end
    -- Timestamp formatters (Phase 1 attaches these to announces; unused/no-op in Phase 0).
    function NS.stamp(t)      return date("%H:%M:%S", t or NS.now()) end          -- live chat
    function NS.stampFull(t)  return date("%m/%d/%y %H:%M:%S", t or NS.now()) end -- log/report

    -- Locked config defaults (2026-09-03 decisions). Custom Options may override in later
    -- phases. See .plans/bg-item-callout/00-overview.md section 5.
    NS.cfg = {
        trackAllies    = true,        -- detect friendly casters too (Phase 2)
        announceAllies = true,        -- announce ally use in BG/instance chat (not silent-log)
        corroborate    = true,        -- multi-witness aggregation over the addon bus (Phase 3)
        minWitnesses   = 2,           -- >= 2 distinct server-verified witnesses == "evidence"
        reportMode     = "ondemand",  -- corroboration report is posted on demand, not auto-spam
    }

    -- Cross-child state stores. Empty and unused in Phase 0; later phases populate them.
    NS.seen      = {}   -- de-dupe: eventKey -> lastServerTime (avoid double-announce per child)
    NS.witnesses = {}   -- eventKey -> { [strippedSender] = true } (Phase 3 corroboration)
    NS.log       = {}   -- rolling in-memory sighting log (Phase 4 persists to aura_env.saved)

    -- Register the hidden addon bus prefix now. Harmless in Phase 0: nothing broadcasts, so
    -- there is no traffic to receive. Guarded for clients without C_ChatInfo.
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(NS.ADDON_PREFIX)
    end

    -- Reset per-match volatile state on zone-in. The CHAT_MSG_ADDON branch is an intentional
    -- no-op in Phase 0 (Phase 3 will parse + aggregate corroboration payloads here).
    NS:RegisterEvent("PLAYER_ENTERING_WORLD")
    NS:RegisterEvent("CHAT_MSG_ADDON")
    NS:SetScript("OnEvent", function(_, event, prefix)
        if event == "PLAYER_ENTERING_WORLD" then
            wipe(NS.seen)
            wipe(NS.witnesses)
            wipe(NS.log)
            return
        end
        if event == "CHAT_MSG_ADDON" then
            if prefix ~= NS.ADDON_PREFIX then return end
            -- Phase 3: parse payload, dedupe by server-verified sender, aggregate witnesses.
            return
        end
    end)
end
