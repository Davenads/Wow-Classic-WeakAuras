# WhisperCatcher

| Field | Value |
|---|---|
| **Display name** | `WhisperCatcher` |
| **Category / folder** | `UI` |
| **Target flavor(s)** | Classic Era (+ any flavor — uses only baseline chat events) |
| **Min WeakAuras version** | 5.x |
| **wago URL** | n/a |
| **wago version** | n/a |
| **Region type** | `text` (invisible — the trigger always returns `false`) |

## Purpose

A **silent, invisible** whisper logger. While you're AFK — e.g. an AHK script is spamming
trade — incoming whispers scroll off the top of chat and are lost by the time you get back.
This aura captures **every incoming whisper** into persistent storage so you can read the
whole backlog later. It draws nothing on screen; it only prints to chat when you ask.

## How you read the log — the "`/whlog`" command

WeakAuras runs custom code in a **sandbox that blocks `SlashCmdList`**, so a real `/whlog`
slash command **cannot** be registered from a WeakAura (it would silently do nothing). The
working equivalent is to **whisper yourself** a keyword — the aura hears your own outgoing
whisper (`CHAT_MSG_WHISPER_INFORM`, and the self-copy `CHAT_MSG_WHISPER`) and treats it as a
command. A whisper from yourself is **never logged**.

| Whisper to yourself | Effect |
|---|---|
| `/w <YourName> whlog`        | Dump the whole log to chat (timestamp · sender · message) |
| `/w <YourName> whlog clear`  | Wipe the log |
| `/w <YourName> whlog off`    | Pause capturing |
| `/w <YourName> whlog on`     | Resume capturing |

(`log` works as a shorthand for `whlog` on every command.)

A one-line nudge also prints on **login / zone-in** and when you **return from AFK** if a
backlog exists, e.g. `[WhisperCatcher] 12 whispers while you were away — whisper yourself
"whlog" to read`. Capturing itself is silent (no per-whisper spam, nothing on screen).

## Triggers

Single **Custom ▸ Status** trigger, **Check On: Event**, that always returns `false` so the
region never shows — it exists only for its side effects. Events box:

```
CHAT_MSG_WHISPER, CHAT_MSG_BN_WHISPER, CHAT_MSG_WHISPER_INFORM,
PLAYER_ENTERING_WORLD, PLAYER_FLAGS_CHANGED
```

- `CHAT_MSG_WHISPER` / `CHAT_MSG_BN_WHISPER` — an incoming whisper (`arg1` text, `arg2`
  sender). Appended to the log unless the sender is **you** (self-whisper = command channel).
- `CHAT_MSG_WHISPER_INFORM` — your **outgoing** whisper; a command only if the target is
  yourself. A 0.5 s guard in `aura_env.Command` absorbs the INFORM + self-`WHISPER` double fire.
- `PLAYER_ENTERING_WORLD` / `PLAYER_FLAGS_CHANGED` — fire the login / AFK-return nudge
  (`PLAYER_FLAGS_CHANGED` only speaks on the AFK → back transition, tracked via `aura_env.wasAFK`).

## Persistence

All state lives in **`aura_env.saved`** (WeakAuras' per-aura persistent table), so the log
survives `/reload` and logout:

```lua
aura_env.saved = {
    whispers  = { { t = <epoch>, who = "<Name>", msg = "<text>" }, ... },  -- capped at last 1000
    capturing = true,
}
```

**Durability caveat:** SavedVariables only flush to disk on a **clean** logout/reload/exit.
For the intended use — walking away and coming back to a still-running client — nothing is
ever at risk (the table lives in memory the whole time). An outright client **crash** during
the AFK would lose the in-memory tail. If you need crash-durable logging, use a dedicated
addon (Elephant / WIM) instead.

## Custom code

- `code/trigger.lua` — the capture + self-whisper command dispatcher (Trigger 1 ▸ Custom ▸ Status).
- `code/init.lua` — Actions ▸ On Init: initializes `aura_env.saved` and defines the helpers
  (`strip`, `Dump`, `Command`, `Remind`). Uses only sandbox-safe globals (`print`, `date`,
  `time`, `wipe`, `GetTime`, `UnitName`, `UnitIsAFK`).

No On Show / On Hide code (the region never shows).

## Testing notes

- Import `export.txt`. The aura is invisible — confirm it appears in the WeakAuras list and is
  enabled. It has **no** load restriction, so it runs on every character; disable it per-character
  if you only want it on your trade-spam mule.
- Have a friend (or a second account) whisper you a few lines. Then `/w <YourName> whlog` — the
  backlog should print with timestamps. `/w <YourName> whlog clear` empties it.
- Test the AFK path: `/afk`, receive a whisper, then move to clear AFK — you should get the
  one-line "N whispers while you were away" nudge.
- `whlog off` then receive a whisper → nothing logged; `whlog on` re-enables.
- **enUS assumption:** command matching is plain lowercase text, locale-independent; sender
  names keep their realm suffix stripped.

## Changelog

- 2026-08-11 — Initial version. Invisible `text` region, single Custom ▸ Status trigger that
  always returns false. Captures incoming `CHAT_MSG_WHISPER` / `CHAT_MSG_BN_WHISPER` into
  `aura_env.saved.whispers` (capped 1000); self-whisper command channel (`whlog` /
  `clear` / `off` / `on`) since the sandbox blocks `SlashCmdList`; login + AFK-return nudge.
  Fabricated export (cloned from the WSG Enemy FC Announcer text-region shape), round-trip
  verified lossless.
