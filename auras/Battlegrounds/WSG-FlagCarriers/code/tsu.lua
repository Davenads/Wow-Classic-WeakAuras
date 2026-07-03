-- WSG Flag Carriers — Trigger → Custom → "Trigger State Updater"
--
-- Paste into: child Text aura → Trigger 1 → Type: Custom → Custom Trigger:
--   "Trigger State Updater". Set the trigger's "Events" box (newline-separated) to:
--     CHAT_MSG_BG_SYSTEM_ALLIANCE
--     CHAT_MSG_BG_SYSTEM_HORDE
--     CHAT_MSG_BG_SYSTEM_NEUTRAL
--     PLAYER_ENTERING_WORLD
--
-- Why chat parsing: in a battleground you can only scan auras on your OWN team, so the
-- enemy flag carrier is invisible to UnitAura across the map. The game instead announces
-- every pickup/drop/return/capture to everyone via CHAT_MSG_BG_SYSTEM_* (arg1 = text).
-- We parse that text. This aura is Load-gated to Warsong Gulch, so it only runs there.
--
-- Message strings are enUS. On another locale, edit the patterns below (they are the
-- only locale-specific part). Examples parsed:
--   "The Horde Flag was picked up by <name>!"
--   "The Alliance Flag was dropped by <name>!"
--   "The Horde Flag was returned to its base."
--   "<name> captured the flag!"
--
-- Limitation: chat-based tracking can't know a carrier who picked up BEFORE you zoned in
-- (no message was sent to you). New pickups/drops after you arrive are tracked correctly.

function(allstates, event, ...)
    aura_env.carriers = aura_env.carriers or {}
    local c = aura_env.carriers   -- c.alliance = who holds the Alliance flag (a Horde player)
                                  -- c.horde    = who holds the Horde flag    (an Alliance player)

    if event == "PLAYER_ENTERING_WORLD" then
        -- New match / zoning: start clean.
        c.alliance, c.horde = nil, nil
    elseif event == "STATUS" or event == "OPTIONS" then
        -- Initial build / options preview: fall through and (re)build states.
    else
        local text = ...
        if type(text) == "string" then
            local faction = text:match("The (%a+) [Ff]lag")   -- "Alliance" or "Horde"
            local picked  = text:match("[Ff]lag was picked up by (.-)!")

            if picked and faction then
                picked = picked:gsub("%-.*$", "")             -- strip "-Realm" (cross-realm BGs)
                if faction == "Alliance" then
                    c.alliance = picked
                elseif faction == "Horde" then
                    c.horde = picked
                end
            elseif text:find("was dropped by") or text:find("was returned") then
                if faction == "Alliance" then
                    c.alliance = nil
                elseif faction == "Horde" then
                    c.horde = nil
                end
            elseif text:find("[Cc]aptured") or text:find("[Ff]lags are reset")
                or text:find("flags are now placed") or text:find("battle has begun") then
                -- A capture requires your own flag to be home, so only one flag is ever
                -- carried at capture time — clearing both is safe and self-correcting.
                c.alliance, c.horde = nil, nil
            end
        end
    end

    -- Slot 1 (index 1 → left, next to the Alliance score): Alliance player holding the
    -- Horde flag. Colored Alliance blue.
    allstates["horde_flag"] = {
        show    = c.horde ~= nil,
        changed = true,
        index   = 1,
        carrier = c.horde,
        team    = "alliance",
        name    = c.horde and ("|cff3399ff" .. c.horde .. "|r") or "",
    }

    -- Slot 2 (index 2 → right, next to the Horde score): Horde player holding the
    -- Alliance flag. Colored Horde red.
    allstates["alliance_flag"] = {
        show    = c.alliance ~= nil,
        changed = true,
        index   = 2,
        carrier = c.alliance,
        team    = "horde",
        name    = c.alliance and ("|cffff3333" .. c.alliance .. "|r") or "",
    }

    return true
end
