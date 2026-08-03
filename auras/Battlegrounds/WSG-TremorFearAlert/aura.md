# WSG Tremor Fear Alert

A **personal HUD + sound** for a Shaman in Warsong Gulch that tells you *when to drop
Tremor Totem*. Two reliable signals:

1. **Ally feared → DROP TREMOR** (the core): a big on-screen call the moment a **nearby
   ally** is hit by a **fear / charm / sleep** effect Tremor Totem can remove.
2. **Enemy fear incoming** (pre-empt): a flash when an enemy **begins casting** Fear /
   Scare Beast / Hibernate — the ~1.5 s cast is your window to drop/stomp tremor first.

Never posts to chat — it's a heads-up display and sound for you only.

| Field | Value |
|---|---|
| **Display name** | `WSG Tremor Fear Alert` |
| **Category / folder** | `Battlegrounds` |
| **Target flavor(s)** | Classic Era / SoD / Hardcore (+ Cata/MoP Classic) |
| **Load** | Class = **Shaman**, Level = **19**, Zone = **Warsong Gulch** |
| **Region type** | `text` (single status region; the on-screen line + sound are the output) |
| **Import string** | `export.txt` — generated from the envelope + `code/*.lua`, round-trip verified |

## Status

`export.txt` is machine-generated (cloned from the known-good `WSGResDenyCallout` text-region
envelope + these `code/*.lua` blocks) and passes a lossless encode/decode round-trip.
**Not yet tested in-game.** Confirm the items under *Verify first* live before trusting it.

## Why this design (it mirrors the spell mechanics)

You **cannot** read an enemy's cooldowns, but you **can** read a friendly unit's debuffs
directly (`UnitDebuff` is reliable on Classic). So the split is deliberate:

- The **ally side is the truth** — "is someone I can save feared *right now*?" — and it's the
  most actionable piece, so it's the centerpiece. Tremor pulses every ~3 s and clears
  Fear/Charm/Sleep, so the call is tied to **your own tremor status**:
  - ally feared **+ tremor NOT down** → 🔴 **RED "DROP TREMOR"** + loud sound (act now)
  - ally feared **+ tremor already pulsing** → 🟡 **YELLOW** informational, no sound (auto-clears)
- The **enemy side is a pre-empt** — Fear / Scare Beast / Hibernate have a ~1.5 s cast, caught
  via `SPELL_CAST_START`, so you get 🟠 **ORANGE "FEAR INCOMING"** + a soft sound to drop tremor
  *before* it lands. Instant fears (Psychic Scream) can't be pre-empted, so they only ever
  surface on the reliable ally side once they've landed.

**Priority when several apply:** RED (act) > ORANGE (pre-empt) > YELLOW (already handled).

## ⚠️ Verify first (blocking / important)

1. **Tremor removes what's on the list.** The alert only fires for **fear/charm/sleep**
   effects (the categories Tremor clears). At 19 the live ones are **Psychic Scream, Fear,
   Scare Beast** (Scare Beast lands only on **beasts** → a **feral druid ally in bear/cat
   form**, or a hunter pet). `Hibernate`/`Seduction`/etc. are listed for reuse but need their
   own level/availability check. If in testing a listed effect is **not** actually cleared by
   Tremor, remove it from `TREMOR_REMOVES` in `init.lua` so it can't raise a false call.
2. **Tremor Totem name is matched in enUS** (`"Tremor Totem"`) via `GetTotemInfo`. On another
   locale set `config.tremorName`, or the RED/YELLOW split (which depends on knowing your
   tremor is down) won't work.
3. **`SOUNDKIT` sounds.** Uses `SOUNDKIT.RAID_WARNING` (RED) and `SOUNDKIT.READY_CHECK`
   (ORANGE), both guarded with `if SOUNDKIT`. Confirm they play on your client; swap the two
   `PlaySound` calls in `init.lua` if you want different cues.
4. **"Nearby" is approximate.** There's no exact totem-radius check for arbitrary allies, so
   `nearbyOnly` uses `UnitInRange` (~40 yd assist range) and **fails open** — an ally whose
   range can't be checked is still shown, so you never miss a truly-close one. Turn the toggle
   off to alert on **all** feared allies regardless of range.

## What it shows

| Line | When | Color | Sound |
|---|---|---|---|
| `DROP TREMOR  Name1, Name2 (Psychic Scream)` | nearby ally feared, **your tremor is not down** | red | loud (once per episode) |
| `FEAR INCOMING  Fear — Caster` | enemy begins casting a castable fear | orange | soft (once per cast) |
| `Name feared — tremor pulsing` | nearby ally feared, **tremor already down** | yellow | none |
| *(hidden — empty text)* | nothing to call | — | — |

The region stays loaded the whole match and simply renders empty when idle (so no
show/hide churn); the text refreshes every frame.

## Config (Custom Options — clickable toggles after import)

Open the aura → **Custom Options**:

| Key | Default | Meaning |
|---|---|---|
| `allyAlert` | on | The RED/YELLOW ally-feared call. |
| `enemyCast` | on | The ORANGE enemy fear-cast pre-alert. |
| `sounds` | on | Play sounds on new alerts (loud RED, soft ORANGE). |
| `nearbyOnly` | on | Only alert for allies in ~40 yd assist range (fail-open). |

Also editable in `init.lua`: the `TREMOR_REMOVES` effect list, the `CAST_FEARS` pre-alert
list, and `config.tremorName` (locale). Font size / position are set on the region — drag it
in-game, and add a Glow/Flash sub-region there if you want it to pop harder.

## How it works (code → WA blocks)

Single `text` status region; the on-screen line and sound are the output.

- `code/init.lua` → **Actions → On Init**: config, the `TREMOR_REMOVES` / `CAST_FEARS`
  lists, and helpers — `TremorActive` (`GetTotemInfo` scan), `ScanFearedAllies`
  (`UnitDebuff` over `WA_IterateGroupMembers`, with the `UnitInRange` nearby filter), `OnCLEU`
  (hostile `SPELL_CAST_START` → register a ~1.6 s pre-alert + soft sound), `Evaluate` (builds
  the colored line by priority and fires the RED sound on the rising edge), `Reset`.
- `code/on_show.lua` → **Actions → On Show**: a 0.3 s `C_Timer` ticker driving `Evaluate`
  (expires pre-alerts, re-checks tremor, clears the call when a fear fades).
- `code/on_hide.lua` → **Actions → On Hide**: cancels the ticker (no scanning outside WSG).
- `code/trigger.lua` → **Trigger 1 → Custom → Status** (Check On: Event). Events:
  `PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, PLAYER_TOTEM_UPDATE, UNIT_AURA,
  COMBAT_LOG_EVENT_UNFILTERED:SPELL_CAST_START`. Routes each to a helper; returns
  `aura_env.enabled` so the region stays shown all match.
- `code/custom_text.lua` → **Display → Text → `%c`**: returns `aura_env.alertText` (or `""`).

## Import

1. `/wa` → **Import**, paste `export.txt`. Loads only on a **level-19 Shaman** in **Warsong Gulch**.
2. Drag the text where you want it (default: centered, 170 px up).
3. Tune via **Custom Options**; test by having a warlock/hunter/priest fear a groupmate near
   you and confirm the RED call + sound, then drop Tremor and confirm it flips to YELLOW.

## Testing notes (verify in-game)

- **Ally side:** get a groupmate feared while your Tremor is **not** down → RED + sound; drop
  Tremor → flips to YELLOW; let the fear fade → clears. Confirm Scare Beast on a **feral druid
  in form** registers (it's beast-only).
- **Enemy side:** have an enemy warlock/hunter start a Fear / Scare Beast cast near you → ORANGE
  "FEAR INCOMING" for the cast; confirm it clears after ~1.5 s if not recast.
- **Locale:** effect names and the Tremor Totem name are **enUS** — edit the lists /
  `config.tremorName` for other clients.
- **Range:** with `nearbyOnly` on, confirm a far-away feared ally is *not* alerted while a
  close one is; toggle off to alert on all.

## Changelog

- 2026-08-03 — Restrict load to **Level == 19** (`use_level`/`level`/`level_operator`),
  scoping it to the 19 twink WSG bracket. `export.txt` re-encoded, round-trip verified.
- 2026-08-03 — Initial implementation. Phase 1: **ally-feared → DROP TREMOR** indicator
  (`UnitDebuff` scan of group members, filtered to Tremor-removable fear/charm/sleep effects,
  `UnitInRange` fail-open "nearby" gate) tied to **own Tremor status** (`GetTotemInfo`) for a
  RED (act) / YELLOW (already pulsing) split; plus an **enemy castable-fear pre-alert**
  (hostile `SPELL_CAST_START` on Fear/Scare Beast/Hibernate → ORANGE, ~1.6 s window). Sounds:
  loud `RAID_WARNING` on RED (edge-triggered), soft `READY_CHECK` on each new cast. Personal
  HUD only — no `/bg`. Colored inline via `|cff…|r` (no conditions). Four Custom-Option
  toggles (`allyAlert`, `enemyCast`, `sounds`, `nearbyOnly`). Load-gated Shaman + Warsong
  Gulch. Envelope cloned from `WSGResDenyCallout`; `.luacheckrc` gains `UnitInRange`,
  `SOUNDKIT`, `COMBATLOG_OBJECT_REACTION_HOSTILE`. `export.txt` generated (7361 bytes),
  round-trip verified; **pending in-game test.** Deferred (not built): the inferred enemy
  Psychic-Scream / Scare-Beast **cooldown board** (Phase 3 nice-to-have).
