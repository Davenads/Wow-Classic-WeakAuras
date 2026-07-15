# Incoming Heals (self)

| Field | Value |
|---|---|
| **Display name** | `Incoming Heals` |
| **Category / folder** | `UI` |
| **Target flavor(s)** | Classic Era (1.15.x) — Anniversary / Vanilla |
| **Min WeakAuras version** | 5.x |
| **wago URL** | n/a |
| **wago version** | n/a |
| **Region type** | `icon` (v1 — see *Presentation* below) |

## Purpose

A personal "a heal is landing on me" indicator: shows an inbound-heal icon with a native
cooldown countdown to the **land-time**, and carries the predicted **amount** + **caster**
as state fields (surface them with a Text sub-element). Answers the actionable question for
your own character — *how big, and how soon* — so you can time a defensive, stop your own
cast, or not waste a potion.

Data source is a **graceful-degrade chain** (full rationale in `PLAN.md`):

1. **LibHealComm-4.0** (`aura_env.HC`) — amount **+ land-time + caster**, including HoTs,
   channels, cross-player casts and heal modifiers. Requires any loaded addon that ships the
   lib (this machine: standalone **LibHealComm-4.0** — verified `LibHealComm: LOADED`).
2. **Native `UnitGetIncomingHeals("player")`** — amount only, direct casts only, no land-time.
   Used automatically when LibHealComm is absent.
3. Combat-log self-detection (D3) — **not implemented in v1** (see `PLAN.md` §2 / §7).

`load` is gated to **in a group** (party or raid) — the only time others heal you.

## Triggers

- **Trigger 1 — Custom ▸ Trigger State Updater** (`code/tsu.lua`). One state `""`, `timed`
  to the heal's land-time, with custom fields `amount` (number), `hasAmount` (bool),
  `casterName` (string).
  - **Custom Variables:** `{ amount = "number", hasAmount = true, casterName = "string" }`
  - **Events:** `HEALCOMM_INCOMING, UNIT_HEAL_PREDICTION, PLAYER_ENTERING_WORLD`
    (`HEALCOMM_INCOMING` is a custom event fired by the On Init callbacks).

No spell/item IDs are hard-coded — LibHealComm resolves amounts; the icon is generic
`Spell_Holy_Heal` (fileID `135953`).

## Custom code

- `code/init.lua` → **Actions ▸ On Init.** Resolves `LibStub("LibHealComm-4.0", true)` once
  onto `aura_env.HC`; if present, registers `HealComm_Heal*` / `_ModifierChanged` /
  `_GUIDDisappeared` callbacks that fire `WeakAuras.ScanEvents("HEALCOMM_INCOMING")` whenever
  an inbound heal on the player changes.
- `code/tsu.lua` → **Trigger ▸ Custom ▸ TSU.** The degrade chain above; builds the timed state.
- `code/custom_text.lua` → **Display ▸ Text ▸ `%c`.** Formats `caster  +amount` (e.g.
  `Greater Heal  +4.2k`). Optional — a text string of `%casterName  +%amount` needs no `%c`.

## Presentation & in-game finish

v1 ships as an **icon** (verified region schema) so it imports clean and works immediately:
icon art + native swipe/countdown to land-time. Per CLAUDE.md §1 the **WA UI owns geometry**,
so the richer looks are quick in-game tweaks rather than hand-fabricated schema:

- **Amount/caster text:** add a Text sub-element → set its text to `%casterName  +%amount`
  (or `%c` + paste `custom_text.lua`).
- **Timer-bar look (U5, the plan's headline pick):** change Region type to *Progress Bar
  (aurabar)*, keep the same trigger/actions, set the bar text to `%casterName  +%amount` and
  the bar to fill toward `expirationTime`. Re-export and overwrite `export.txt`.

## Testing notes

- Verify the lib first, in-game: `/run local h=LibStub and LibStub("LibHealComm-4.0",true); print(h and "LibHealComm: LOADED" or "not loaded")` → **LOADED** (confirmed).
- Group with a healer; have them cast a direct heal (e.g. Greater Heal) on you → the icon
  should appear immediately with a countdown to land and the predicted amount, and clear on
  land or on cancel. Confirm HoT/channel coverage (Renew / Tranquility) via the LibHealComm path.
- Solo → unloaded (group-gated). Toggle the `load ▸ in group` option if you want it always on.
- **Not verified in-game yet** — needs a live healer to confirm amounts/land-time.

## Changelog

- 2026-07-15 — Initial version: icon indicator, LibHealComm ▸ native degrade chain, group-gated.
