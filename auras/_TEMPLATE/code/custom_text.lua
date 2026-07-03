-- <Aura Name> — Display → Text, custom "%c" function(s)
-- Pastes into: WA options → Display → Text → the "%c" custom function box.
-- Each %c in the text string maps positionally to one function here.
-- Return the string to display.

function()
    -- Example: show remaining seconds with one decimal.
    local state = aura_env.state
    if state and state.expirationTime then
        return string.format("%.1f", state.expirationTime - GetTime())
    end
    return ""
end
