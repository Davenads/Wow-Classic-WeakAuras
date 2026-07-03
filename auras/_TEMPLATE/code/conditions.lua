-- <Aura Name> — Conditions → Custom Check (or Custom Code)
-- Pastes into: WA options → Conditions → add a condition → "Custom Check".
-- A Custom Check returns a boolean; when true, the condition's property changes apply.
-- (A "Custom Code" change instead RUNS Lua when the condition is met.)

function()
    -- Example: true when the current state has fewer than 5 seconds remaining.
    local state = aura_env.state
    if state and state.expirationTime then
        return (state.expirationTime - GetTime()) < 5
    end
    return false
end
