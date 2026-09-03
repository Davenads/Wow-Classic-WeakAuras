-- Betty's BG Item Callout (19 bracket) — Send Chat Message → Message "%c" custom function
-- Pastes into: each child → Actions → On Show → Send Chat Message. Put the "%c" token in the
-- Message text (e.g. "[%c] Swiftness Potion used by %1.sourceName"); WA replaces "%c" with
-- this function's return. Stored in the child's actions.start.message_custom. Identical in
-- all 10 children.
--
-- Returns the server-synced HH:MM:SS timestamp: BGICHub.stamp() wraps GetServerTime(), which
-- is identical across every client on the realm (so screenshots line up between witnesses).
-- Falls back to local machine time only if the hub hasn't initialized yet. Purely additive —
-- the message channel (SMARTRAID / SAY) and the %1.sourceName replacement are unchanged.
function()
    return (BGICHub and BGICHub.stamp()) or date("%H:%M:%S")
end
