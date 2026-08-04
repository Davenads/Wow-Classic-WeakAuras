# WSG Res-Deny Callout

| Field | Value |
|---|---|
| **Display name** | `WSG Res Deny Callout` |
| **Category / folder** | `PvP` (`auras/PvP/WSGResDenyCallout/`) |
| **Target flavor(s)** | Classic Era / SoD / Hardcore / Cata Classic / MoP Classic |
| **Min WeakAuras version** | `5.x` |
| **wago URL** | n/a (not yet published) |
| **wago version** | n/a |
| **Region type** | `text` (status trigger; local indicator only) |

## Purpose

Inside **Warsong Gulch**, coordinate kill-timing against the enemy graveyard resurrection
wave. When an **enemy player is at low HP**, is **not the enemy flag carrier (EFC)**, and
the **enemy graveyard res wave is imminent**, the aura posts a **rate-limited** `/bg`
callout asking teammates to **hold the kill** until the res timer resets — so the enemy,
once killed, eats a **near-full ~30s corpse/res timer** (maximum downtime).

The EFC is always excluded: you want the flag carrier dead regardless of the res clock.

Ships in **dry-run** (local print) by default; a Custom Option flips it to live `/bg`.

## The res-clock problem (and how it's solved)

`GetAreaSpiritHealerTime()` only returns **your** group's timer, and only while a groupmate
is a ghost — the **enemy** graveyard timer is not directly readable. This aura ports the
inference model from the **"BG Rez Timer"** WeakAura (wago `wm2BS70cN`, v1.0.2):

1. **Seed** the ~31.5s cycle from the WSG start system message (`+startOffset`, default 5s).
2. **Self-correct** by detecting friendly **res waves** — an alive-count jump of
   `≥ wsgRezThreshold` across `WA_IterateGroupMembers()` with the roster unchanged means a
   spirit healer just fired, so re-anchor the cycle.
3. **Manual/addon sync** on the shared `BG_REZ_SYNC` scan-event + `AuroBGRez` addon prefix
   (interoperates with the existing BG Rez Timer userbase).
4. **Spirit-healer fallback** — if the aura is imported/reloaded **mid-match** (start message
   already missed), the 0.1s ticker calls `GetAreaSpiritHealerTime()`; while you or a
   groupmate is a ghost at a graveyard it returns the seconds to your next res wave, which
   anchors the clock accurately without waiting for a wave or a manual sync. No-op once
   seeded or when nobody is at a healer.

Premise: both graveyards share **one** cycle, so a friendly-derived countdown predicts the
enemy wave. `enemyGyOffset` lets you nudge the enemy phase if it drifts.

## Triggers

- **Trigger 1 — Custom → Status (Check On: Event).** Side-effect trigger; returns
  `aura_env.enabled` (true only inside WSG). Events:
  `PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, CHAT_MSG_BG_SYSTEM_ALLIANCE,
  CHAT_MSG_BG_SYSTEM_HORDE, CHAT_MSG_BG_SYSTEM_NEUTRAL, CHAT_MSG_ADDON, BG_REZ_SYNC,
  NAME_PLATE_UNIT_ADDED, NAME_PLATE_UNIT_REMOVED, PLAYER_TARGET_CHANGED,
  UPDATE_MOUSEOVER_UNIT`.

## Custom code

- `init.lua` — config, faction detection, res-cycle clock (`aura_env.rc`), EFC identity
  parser (`aura_env.OnSystem`), multi-enemy HP scanner (`aura_env.ScanEnemies`), rate
  limiter (`aura_env.rl`), sender (`aura_env.Announce`), decision core (`aura_env.Evaluate`).
- `trigger.lua` — event routing; keeps the region shown while in WSG.
- `on_show.lua` — arms a 0.1s ticker (`rc:detectWave` + `Evaluate`); nameplate/dry-run hints.
- `on_hide.lua` — cancels the ticker on leaving WSG.
- `custom_text.lua` — `%c` local indicator: predicted enemy rez countdown + hold-candidate count.

### Custom Options

Only **`dryRun`** is exposed as a clickable WeakAuras author option (a checkbox in the
aura's **Custom Options** tab): **checked = local prints only (default), unchecked = post to
`/bg`**. The remaining keys below are code-level defaults in `init.lua` — edit them there (or
promote any to author options later). All are read from `aura_env.config` with these
fallbacks:

| Key | Default | Meaning |
|---|---|---|
| `dryRun` | `true` | **WA checkbox.** Print callouts locally instead of sending to `/bg`. |
| `channel` | `BG` | Live channel when dry-run off: `BG` (INSTANCE_CHAT) or `RAID`. |
| `hpThreshold` | `20` | Only enemies at/under this HP % are callout candidates. |
| `gyLowThreshold` | `7` | Only fire when predicted enemy rez ≤ this many seconds. |
| `perTargetCooldown` | `20` | Min seconds between callouts on the **same** enemy. |
| `globalMinInterval` | `8` | Min seconds between **any** two sends. |
| `rollingCap` | `3` | Max sends allowed per rolling window. |
| `rollingWindow` | `30` | Rolling-cap window (seconds). |
| `enemyGyOffset` | `0` | ± seconds to phase-shift the enemy GY vs ours. |
| `wsgRezThreshold` | `2` | Alive-count jump that counts as a res wave. |
| `startOffset` | `5` | Seconds after the WSG start message the gate opens. |
| `messagePrefix` | `""` | Optional leading tag on each line. |
| `showIndicator` | `true` | Draw the local `%c` status readout. |

Worst-case chat load with defaults: **≤ 3 terse lines per 30s**, ≥ 8s apart, ≥ 20s per
enemy — designed to read as coordination, not spam.

## Testing notes

**Not yet tested in-game.** Phased QA plan:

1. **Dry-run detection (Phase 1).** Enter WSG with `dryRun = true`. Confirm the indicator
   seeds after the start message and the countdown rolls ~31.5s. Fight low-HP enemies and
   verify `Don't kill yet: <name> @<hp>% …` lines print **locally** with correct names/HP.
2. **Res clock (Phase 2).** Watch friendly deaths/waves; confirm the countdown re-anchors on
   waves and the `BG_REZ_SYNC` macro resyncs. Sanity-check the enemy phase (adjust
   `enemyGyOffset`) — the "both GYs in phase" assumption needs live confirmation.
3. **EFC exclusion (Phase 3).** Confirm the current flag carrier never triggers a HOLD line.
4. **Rate limiter (Phase 4).** Confirm global/per-target/rolling caps hold under a chaotic
   midfield with several low-HP enemies.
5. **Go live (Phase 5).** Flip `dryRun` off only after the above pass.

Requires **enemy nameplates on** (or teammates targeting the enemy) to read enemy HP.

## Changelog

- 2026-08-02 — Initial scaffold: res-clock (ported from BG Rez Timer), multi-enemy
  scanner + EFC exclusion, layered rate limiter, dry-run default. Not yet tested in-game.
- 2026-08-02 — Add `GetAreaSpiritHealerTime()` fallback seed so the clock self-anchors when
  imported/reloaded mid-match (fixes the indefinite "waiting for match start…" state).
- 2026-08-02 — Expose `dryRun` as a real WA author option (checkbox in Custom Options) so
  live `/bg` posting can be toggled without editing code. Default stays dry-run (checked).
