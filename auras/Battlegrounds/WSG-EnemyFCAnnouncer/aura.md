# WSG Enemy FC Announcer

Auto-posts the **enemy flag carrier**'s (EFC) status to battleground chat (`/bg`) in
Warsong Gulch: HP milestones + a periodic low-health reminder, and key debuffs as they
land. "Enemy flag carrier" = the enemy player carrying **your** flag (the one you want
dead).

| Field | Value |
|---|---|
| **Display name** | `WSG Enemy FC Announcer` |
| **Category / folder** | `Battlegrounds` |
| **Target flavor(s)** | Classic Era / SoD / Hardcore (Cata/MoP Classic supported — chat channel auto-branches) |
| **Min WeakAuras version** | 5.x |
| **wago URL** | n/a |
| **Region type** | `text` (single status region; the /bg messages are the real output) |
| **Import string** | `export.txt` — pre-generated, round-trip-verified |

## Status

`export.txt` is machine-generated (built from a known-good text-region envelope + these
`code/*.lua` blocks) and passes a lossless encode/decode round-trip. **Not yet tested
in-game.** Two things must be confirmed live before trusting it — see *Verify first*.

## ⚠️ Verify first (blocking)

1. **Sandbox allows `SendChatMessage`.** WeakAuras' sandbox blocks a set of functions
   (`SendMail`, `CreateMacro`, `loadstring`, `pcall`, …) but **not** `SendChatMessage`
   (announcer auras rely on it). To confirm without sending anything, temporarily put this
   in any aura's **On Init** and reload:
   ```lua
   print(SendChatMessage and "EFC: SendChatMessage OK" or "EFC: BLOCKED")
   ```
   If it prints `BLOCKED`, this aura can't work as custom Lua — tell me and we rethink.
2. **You can only read the EFC's HP/debuffs when you hold a unit token for them** —
   `target`, `focus`, `mouseover`, or a **nameplate** (enemy nameplates must be ON: press
   **V** / `nameplateShowEnemies 1`). A carrier fleeing out of range = no HP data = silence.
   This is a hard WoW-client limit; no addon reads arbitrary off-screen enemy health.

## What it announces (defaults)

- **HP milestones:** once each as the EFC crosses **≤ 65 / 50 / 35 / 20 %** (re-armed only
  after they heal back above tier + 5%). Format: `EFC <Name> 48%`.
- **Periodic reminder:** while **≤ 65 %**, every **5 s**. Same format.
- **New debuffs** (matched by name, so all ranks count):
  - **Hard CC** (stuns/roots/incapacitates — Polymorph, Hammer of Justice, Kidney Shot,
    Frost Nova, Entangling Roots, Fear, Blind, Freezing Trap, …): announced **regardless of
    HP** — the team can catch them now. `EFC <Name> 40% — Polymorph`.
  - **Snares/slows** (Hamstring, Crippling Poison, Wing Clip, Frost Shock, Chilled, …):
    announced **only while ≤ 65 %**.
- **Death:** `EFC <Name> is DOWN`, then state resets.

Every send passes a **global 3 s throttle** (`minGap`) so you can't out-spam the server's
chat limiter. Each debuff announces once per application (re-announces if it fades and
reapplies).

## Config

No Author-Mode options are wired yet — tune the constants at the top of `code/init.lua`:
`enabled`, `mode` (`"BG"` or `"SELF"` = local print for safe testing), `prefix`, `minGap`,
`periodic`, `hpThresh`, `debuffs`, the `TIERS` list, and the `HARD_CC` / `SNARE` watchlists
(lowercase enUS spell names). Wiring these into Custom Options is a future enhancement.

## Import

1. `/wa` → **Import**, paste `export.txt`. It loads only in Warsong Gulch (Load → Zone).
2. **Test safely first:** set `mode = "SELF"` in `init.lua` (via the in-game editor) so it
   `print()`s to your chat frame instead of broadcasting; flip back to `"BG"` when happy.
3. Drag the small `EFC <name> <hp>%` readout wherever you like (default: upper-middle).

## How it works (code → WA blocks)

Single `text` status region. All output is a **side effect** of the trigger; the region
just shows a local readout.

- `code/init.lua` → **Actions → On Init**: builds `aura_env.efc` state, reads config,
  picks the chat channel by flavor (`BATTLEGROUND` on Era, `INSTANCE_CHAT` on Cata/MoP),
  determines your faction (→ which flag the enemy carries), defines the watchlists and all
  helper functions (`Announce`, `ResolveUnit`, `Tick`, `OnSystem`, `OnCLEU`, `SetEFC`, …).
- `code/on_show.lua` → **Actions → On Show**: starts a 1 s `C_Timer` ticker (drives the
  periodic HP check) and warns once if enemy nameplates are disabled.
- `code/on_hide.lua` → **Actions → On Hide**: cancels the ticker (no reload leak).
- `code/trigger.lua` → **Trigger 1 → Custom → Status** (Check On: Event). Events:
  `CHAT_MSG_BG_SYSTEM_ALLIANCE/HORDE/NEUTRAL, COMBAT_LOG_EVENT_UNFILTERED,
  NAME_PLATE_UNIT_ADDED/REMOVED, PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED,
  UPDATE_MOUSEOVER_UNIT, UNIT_HEALTH, PLAYER_ENTERING_WORLD`. Routes each event to a helper;
  returns `true` so the region stays shown all match.
- `code/custom_text.lua` → **Display → Text → `%c`**: renders `EFC <name> <hp>%` (blank
  when no carrier is known).

**Identity** comes from WSG system messages (same parser family as *WSG Flag Carriers*).
**HP** comes from a unit token resolved by name→GUID (target/focus/mouseover/nameplate).
**Debuffs & death** come from the combat log (`SPELL_AURA_APPLIED/_REFRESH/_REMOVED`,
`UNIT_DIED`) matched on the EFC's GUID — CLEU gives a clean `spellName`, dodging the
per-rank-ID and 16-debuff-cap gotchas.

## Testing notes (verify in-game)

- **Plumbing (anywhere):** the `SendChatMessage` snippet above; or set `mode="SELF"` and
  confirm the readout tracks a hostile `target` you mouse over.
- **Full flow (needs a WSG):** let an enemy grab your flag → confirm one milestone/periodic
  post while ≤ 65 %; apply Hamstring while they're low → one snare post; Polymorph them at
  full HP → a hard-CC post; kill them → `is DOWN`; spam events → nothing faster than 3 s.
- **Locale:** system-message and spell-name matching is **enUS** — edit patterns/watchlists
  for other clients.
- **Etiquette / spam:** several teammates running this = duplicate `/bg` spam (no
  cross-player coordination in v1). The `enabled` switch and tight throttle are your guards.

## Changelog

- 2026-07-05 — Initial implementation: status trigger + On Init/Show/Hide + `%c` readout.
  HP tiers (65/50/35/20) + 5 s periodic reminder ≤ 65 %; hard-CC debuffs announced always,
  snares only when low; 3 s global throttle; CLEU-based debuff/death detection; flavor-aware
  chat channel. Import string generated and round-trip-verified; **pending in-game test.**
