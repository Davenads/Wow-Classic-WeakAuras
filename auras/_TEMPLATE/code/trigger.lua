-- <Aura Name> — Trigger → Custom (event or status)
-- Pastes into: WA options → Trigger → Type: Custom → Custom Trigger box.
-- Return true to activate the aura, false to deactivate.
-- Register the events this needs in the WA "Events" box (e.g. UNIT_SPELLCAST_SUCCEEDED:player).
-- For status triggers, WA also sends a synthetic "STATUS" event on load/reload/options-close.
--
-- Classic note: verify any spell IDs against wowhead.com/classic and remember that each
-- spell RANK is a separate ID. See docs/classic-api.md.

function(event, ...)
    -- Example: activate while the player is in combat.
    if event == "PLAYER_REGEN_DISABLED" or event == "STATUS" then
        return UnitAffectingCombat("player")
    elseif event == "PLAYER_REGEN_ENABLED" then
        return false
    end
end
