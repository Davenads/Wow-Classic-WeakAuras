# shared/

Reusable Lua snippets used across multiple auras. WeakAuras code blocks don't share
scope in-game, so "sharing" here means **copy the snippet into an aura's code block**
(or into its On Init as an `aura_env` helper). Keeping one canonical, linted copy here
avoids drift between auras that use the same logic.

Convention:
- One concern per file, named for what it does (`gcd.lua`, `class_flavor.lua`).
- Each file starts with a comment explaining what it returns and where to paste it.
- Everything must pass `luacheck`.

When you use a shared snippet in an aura, note it in that aura's `aura.md` so a change
here can be propagated.
