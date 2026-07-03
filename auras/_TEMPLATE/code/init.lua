-- <Aura Name> — Actions → On Init (actions.init.custom)
-- Pastes into: WA options → Actions → On Init.
-- Runs once when the aura loads or its config changes. Good place to define helpers
-- and constants on aura_env for the other blocks to use.

-- Example: stash spell IDs and a helper on aura_env.
aura_env.spells = {
    -- exampleBuff = 12345,  -- https://www.wowhead.com/classic/spell=12345
}

function aura_env.remaining(state)
    if state and state.expirationTime then
        return state.expirationTime - GetTime()
    end
    return 0
end
