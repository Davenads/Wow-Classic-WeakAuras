-- <Aura Name> — Trigger → Custom Untrigger
-- Pastes into: WA options → Trigger → Custom Untrigger box (only when you check
-- "Custom Untrigger"). Return true to deactivate the aura.
-- Use only when hide logic differs from "trigger returned false".

function(event, ...)
    return event == "PLAYER_REGEN_ENABLED"
end
