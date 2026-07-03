-- <Aura Name> — Trigger → Custom (Trigger State Updater / "stateupdate")
-- Pastes into: WA options → Trigger → Type: Custom → Custom Trigger box,
-- with the trigger's "Custom Trigger" dropdown set to "Trigger State Updater".
-- Drives many independent states ("clones"), each rendered by a dynamic group.
--
-- allstates is keyed by cloneId (any string; "" for a single/base state).
-- ALWAYS set changed = true on a modified state and return true.

function(allstates, event, ...)
    -- Example: one timed state that lasts 10s, started by a custom event.
    local cloneId = ""
    allstates[cloneId] = {
        show           = true,
        changed        = true,          -- REQUIRED so WA re-reads the state
        progressType   = "timed",       -- or "static" with value/total
        duration       = 10,
        expirationTime = GetTime() + 10,
        autoHide       = true,
        name           = "Example",     -- %n
        icon           = 134400,        -- fileID or texture path; %i
        stacks         = 1,             -- %s
        -- add custom fields here and declare them in the Custom Variables box
    }
    return true
end
