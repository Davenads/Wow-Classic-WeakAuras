# Sweatybetty's WSG Callout Bars (Solid Colors)

A grid of **27 clickable icon bars** for Warsong Gulch. A normal left-click pings an
**enemy flag carrier location** callout to battleground chat (`/bg`, `INSTANCE_CHAT`) —
e.g. `EFC Is Horde Tunnel`. **Ctrl+click** the same bar instead posts a report on **your
own team's flag carrier** — name + HP, plus mana % when the carrier is a mana class —
e.g. `Our FC Is Horde Tunnel — Xandrella 47% HP, 80% mana`. **Shift+click** instead posts
an **enemy flag carrier** status line — the clicked location plus the enemy carrier's HP,
mana (mana class only), and any relevant PvP crowd-control on them — escalated to a
`RAID_WARNING` when you're the BG group's leader/assistant, otherwise sent to `/bg` —
e.g. `EFC Horde Tunnel — Grimfang 34% HP, 12% mana, Hamstring 4s`.

| Field | Value |
|---|---|
| **Display name** | `!Sweatybetty's WSG Callout Bars (Solid Colors)` (leading `!` sorts it to the top of the WA list) |
| **Category / folder** | `Battlegrounds` |
| **Target flavor(s)** | Classic Era / SoD / HC + Cata/MoP Classic (all use `INSTANCE_CHAT`) |
| **WA version at export** | 5.21.9 (`v:1421`) |
| **Region type** | `group` of 27 `icon` children (always shown; Load → Zone = Warsong Gulch) |
| **Import string** | `export.txt` — round-trip-verified (lossless), **pending in-game test** |
| **Decoded view** | `aura.json` (regenerate after any `export.txt` change) |

## Status

`export.txt` is the source of truth. It was produced by decoding the original import
string, programmatically rewriting every child's **On Init** block to add the Ctrl+click
**and** Shift+click features, re-encoding, and confirming a **lossless**
decode→encode→decode round-trip (`tools/cmp.js` → `LOSSLESS`). **Not yet tested in-game** —
this repo cannot run WoW.

> **luacheck note:** no Lua toolchain was available in the authoring environment, so
> `luacheck` was not run. `code/init.lua` passed a Lua 5.1 syntax parse; `code/trigger.lua`
> is the standard bare-function WA fragment (same style as `WSG-FlagCarriers`). Run
> `luacheck auras/Battlegrounds/WSG-CalloutBars/code` before trusting it.

## What each click does

- **Normal click** — unchanged from the original: sends this bar's fixed enemy-carrier
  location string (`EFC Is <Faction> <Location>`, or `---CAP---` / `---PICK UP FLAG---`).
- **Ctrl+click** — sends the **friendly carrier** report:
  - Location bars → `Our FC Is <Faction> <Location> — <Name> NN% HP[, MM% mana]`.
  - The two special bars (`---CAP---`, `---PICK---`) → **bare** `Our FC — <Name> NN% HP…`
    (no `---CAP---`/`---PICK---` prefix, by request).
  - **Mana** is appended only when the carrier is mana-primary (`UnitPowerType == 0`) —
    warriors/rogues and shifted feral druids (rage/energy) show HP only.
  - **Who our carrier is** is resolved by a **live raid-aura scan** — the hub scans your own
    group for the WSG flag-carry buff (`23333 Warsong Flag` / `23335 Silverwing Flag`,
    matched by spell ID) and reports the holder. Own-team auras are always readable across the
    map, so this works even after a reload mid-carry, with no dependence on chat parsing. The
    chat-tracked name is only a fallback if the scan somehow misses.
  - If no carrier can be found at all → `— FC unknown`.
- **Shift+click** — sends the **enemy carrier** status line:
  - Location bars → `EFC <Location> — <Name> NN% HP[, MM% mana][, <CC> Ns…]`.
  - The two special bars (`---CAP---`, `---PICK---`) → **bare** `EFC <Name> NN% HP…`
    (no location prefix — they have no location).
  - **Channel:** `RAID_WARNING` if you are the group leader or an assistant
    (`UnitIsGroupLeader`/`UnitIsGroupAssistant`), otherwise `/bg` (`INSTANCE_CHAT`).
  - **HP** prefers a live unit read (enemy in your target/focus/mouseover, a nameplate, or
    any teammate's target); if none is readable it falls back to a fresh value from the
    `WSGFCNamesHP` addon bus, **marked `~`** to flag it as second-hand (e.g. `~34% HP`).
  - **Mana** and **CC** require a live hostile token (nameplates carry no power/aura data),
    so they appear only when someone can actually see the carrier. CC is matched against a
    hard-CC + snare watch-list (enUS names), shown as name + remaining seconds, **capped at 3**.
  - If HP/mana/CC are all unreadable → `<Name> (no read)`; if no enemy is carrying, the click
    falls back to the plain `EFC Is <loc>` location callout. Enriched Shift sends are throttled
    to **one per 3 s** (the plain fallback is not throttled).

## How it works (code → WA blocks)

Each icon is an `icon` region with a trivial always-true status trigger; all behavior is
built in **Actions → On Init** (`code/init.lua`), which overlays a `SecureActionButton` on
the region and wires its `OnClick`.

- **Shared carrier tracker** lives on a **named global frame** `WSGCalloutHub`, created
  once by whichever icon loads first (WA children do **not** share `aura_env`, so a global
  is required; a *named* frame is used because that exact mechanism is already proven to
  work in this aura's sandbox). The hub:
  - Listens to `CHAT_MSG_BG_SYSTEM_ALLIANCE/HORDE/NEUTRAL` + `PLAYER_ENTERING_WORLD` and
    parses WSG pickup/drop/return/capture/reset messages (parser lifted from
    `WSG-FlagCarriers`), keeping `WSGCalloutHub.fc.alliance` / `.horde` current.
  - Registers the `WSGFCNamesHP` addon prefix and passively receives `Name@frac` HP messages
    on `CHAT_MSG_ADDON`; when the sender's name matches the current enemy carrier it stores
    `recvHP`/`recvTS` (used as a `~`-marked HP fallback for Shift). It **never broadcasts** —
    it only listens to whatever bus traffic (e.g. `WSG-EnemyFCAnnouncer`) already exists.
  - `ourFCScan()` scans your own group (`player` + `raidN`/`partyN`) for the WSG flag-carry
    buff — `23333 Warsong Flag` (the Horde flag, held by an Alliance carrier) / `23335
    Silverwing Flag` (the Alliance flag, held by a Horde carrier), gated to the enemy-flag
    color by **mercenary-aware effective faction** (buffs `81748`/`81744`) and matched by
    **spell ID** (`UnitAura`'s 10th return, locale-independent). It returns the holder's unit
    **and** name in one pass. This is the primary way our carrier is identified — own-team
    auras are always readable across the map, so it needs no chat and survives a mid-carry
    reload (the FlagCarriers aura's documented "optional enhancement").
  - `ourFCName()` returns the scan's name, falling back to the chat-tracked
    `WSGCalloutHub.fc.*`; `enemyFCName()` returns the enemy carrying **our** flag (chat-only —
    enemy auras can't be scanned).
  - `FCSuffix()` (Ctrl) takes the unit straight from `ourFCScan` (or resolves the fallback
    name to a `raid`/`party`/`player` token) and reads HP (`UnitHealth`/`UnitHealthMax`) +
    mana (`UnitPower(u,0)`, gated on `UnitPowerType==0`). Friendly raid-member health/power is
    always delivered to the client — no token search needed.
  - `EFCStatus()` (Shift) finds a live **hostile** token for the enemy carrier via
    `findEnemyUnit` (target/focus/mouseover → nameplate → any `raidNtarget`), reads HP/mana the
    same way, scans harmful auras against a CC watch-list (`scanCC`, cap 3), and falls back to
    the `~` bus HP when no token is readable; returns nil if no enemy is carrying.
- **Per-icon OnClick** branches on `IsControlKeyDown()` → `OURFC_MSG .. FCSuffix()`, then
  `IsShiftKeyDown()` → `EFCStatus()` line (RAID_WARNING when lead/assist, else `/bg`; 3 s
  throttle), else the original `ENEMY_MSG`. Only three literals differ per icon —
  `ENEMY_MSG` / `OURFC_MSG` / `LOC_LABEL`; the shared bootstrap is identical in all 27
  blocks (guarded, so it runs once).

`code/init.lua` is the representative block for the `horde tun x` icon; the other 26 are
identical except those three literals (full map below).

## Per-icon literals (normal → Ctrl → Shift label)

`LOC_LABEL` is the location text Shift prefixes onto the enemy-status line
(`EFC <LOC_LABEL> — <status>`); it is derived from `ENEMY_MSG` by stripping the leading
`EFC Is ` and is **empty** for the two special bars (they send a bare `EFC <status>`).

| id | Normal (`ENEMY_MSG`) | Ctrl prefix (`OURFC_MSG`) | Shift `LOC_LABEL` |
|---|---|---|---|
| horde/ally tun | `EFC Is <F> Tunnel` | `Our FC Is <F> Tunnel` | `<F> Tunnel` |
| horde/ally fr | `EFC Is <F> Flag Room` | `Our FC Is <F> Flag Room` | `<F> Flag Room` |
| horde/ally con | `EFC Is <F> Connector` | `Our FC Is <F> Connector` | `<F> Connector` |
| horde/ally 2nd | `EFC Is <F> 2nd Lvl` | `Our FC Is <F> 2nd Lvl` | `<F> 2nd Lvl` |
| horde/ally rmp | `EFC Is <F> Ramp` | `Our FC Is <F> Ramp` | `<F> Ramp` |
| horde/ally gy | `EFC Is <F> GY` | `Our FC Is <F> GY` | `<F> GY` |
| horde/ally TOT | `EFC Is <F> TOT (Top Of Tunnel)` | `Our FC Is <F> TOT (Top Of Tunnel)` | `<F> TOT …` |
| horde/ally leaf | `EFC Is <F> Leaf Hut` | `Our FC Is <F> Leaf Hut` | `<F> Leaf Hut` |
| horde/ally zerk | `EFC Is <F> Zerk Hut` | `Our FC Is <F> Zerk Hut` | `<F> Zerk Hut` |
| horde/ally roof | `EFC Is <F> Roof/Banana` | `Our FC Is <F> Roof/Banana` | `<F> Roof/Banana` |
| TOP 3 | `EFC Is TOPSIDE (Alternating Ramp/GY/TOT)` | `Our FC Is TOPSIDE …` | `TOPSIDE …` |
| MID 3 / East / west | `EFC Is Midfield[ EAST/ WEST]` | `Our FC Is Midfield …` | `Midfield …` |
| TREEStump 3 | `EFC Is Midfield (Tree Stump)` | `Our FC Is Midfield (Tree Stump)` | `Midfield (Tree Stump)` |
| ---CAP--- 2 | `---CAP---` | `Our FC` (bare) | `` (empty → bare) |
| ---PICK--- 2 | `---PICK UP FLAG---` | `Our FC` (bare) | `` (empty → bare) |

`<F>` = `Horde` / `Alliance`.

## Housekeeping change vs the original

- The original created **all 27** click buttons with the **same** global name
  `Warsong_Gulch_Ann_TOT_Button_EFC` (a latent collision — only masked because each handler
  uses its own `region.btn_ann`). The rewrite creates the button with a **nil** (anonymous)
  name and reuses `region.btn_ann` (guarded, so re-init doesn't stack duplicate overlays).

## Testing (verify in-game, enUS)

1. Enter WSG → `/dump WSGCalloutHub ~= nil` is true, no Lua error on load.
2. A teammate grabs the enemy flag → `/dump WSGCalloutHub.ourFCName()` returns their name;
   goes nil on drop/return/capture.
3. **Normal click** any bar → `EFC Is <loc>` posts to `/bg` (unchanged).
4. **Ctrl+click**, mana carrier → `Our FC Is <loc> — <Name> NN% HP, MM% mana`.
5. **Ctrl+click**, warrior/rogue/feral carrier → mana omitted.
6. You are the carrier → resolves to `player`, HP/mana correct.
7. Reload mid-carry → the raid-aura scan re-identifies our carrier immediately (no pickup
   message needed); `/dump WSGCalloutHub.ourFCScan()` returns their unit + name.
8. **Shift+click** while targeting the enemy carrier → `EFC <loc> — <Name> NN% HP[, MM% mana]`
   plus any watched CC (e.g. `Hamstring 4s`); as leader/assist it posts as a `RAID_WARNING`,
   otherwise to `/bg`.
9. **Shift+click** with the carrier untargeted but a `WSGFCNamesHP` bus active → HP shows with
   a `~` prefix (second-hand), no mana/CC. With no bus and no token → `<Name> (no read)`.
10. **Shift+click** with no enemy carrier → falls back to the plain `EFC Is <loc>` callout.
11. Spam Shift → enriched sends are throttled to one per 3 s (plain fallback is not).
12. Locale: system-message + CC patterns are **enUS only** — edit the hub for other clients.

## Implemented follow-up: Shift+click (Tier A+)

Shift is a one-shot enemy-carrier status report (no background ticker): on click it looks for
a live hostile token, reads what it can, optionally backfills HP from a passive `WSGFCNamesHP`
bus receiver, and posts once (throttled). See **What each click does → Shift+click** above.
A future **Alt** branch could still drop in cleanly (e.g. request a target-swap or ping a map
pin) — not implemented, pending a decision.

## Changelog

- 2026-08-22 — **Fix Ctrl+click "FC unknown"** by resolving our carrier from a **live
  raid-aura scan** instead of the chat parser. Added `WSGCalloutHub.ourFCScan()`: scans
  `player` + `raidN`/`partyN` for the WSG flag-carry buff (`23333 Warsong Flag` / `23335
  Silverwing Flag`, verified on wowhead.com/classic), gated to the enemy-flag color by
  effective faction and matched by spell ID (`UnitAura` 10th return), returning the holder’s
  unit + name. `ourFCName()` now prefers the scan and falls back to the chat-tracked name;
  `FCSuffix()` consumes the scan’s unit directly (so a scan-found carrier never mis-reports
  "out of group?"). Own-team auras are always readable, so Ctrl now works with no dependence
  on chat parsing, message-format drift, or zone-in/reload timing. All 27 children rebuilt
  from `code/init.lua`; `export.txt` regenerated, `aura.json` refreshed, decode→encode→decode
  **lossless**; `code/init.lua` re-passes a Lua 5.1 parse. **Pending in-game test** (and
  `luacheck`, unavailable in the authoring environment).
- 2026-08-21 — Rename display name to **`!Sweatybetty's WSG Callout Bars (Solid Colors)`**
  (prefix `Sweatybetty's`, kept the leading `!` sort marker). Changed only `d.id`; children
  carry no `parent` field in the transmission format (the `c` array defines the group), so no
  child references needed updating. Rebuilt `export.txt`, regenerated `aura.json`,
  decode→encode→decode **lossless**.
- 2026-08-21 — Add **Shift+click enemy-FC status (Tier A+)**. Rewrote every child's On Init to
  extend `WSGCalloutHub` with an enemy-carrier tracker: `enemyFCName`, `findEnemyUnit`
  (target/focus/mouseover → nameplate → `raidNtarget`), `scanCC` (harmful-aura scan vs a hard-CC
  + snare watch-list, name + remaining seconds, cap 3), and `EFCStatus` (live HP/mana with a
  `~`-marked `WSGFCNamesHP` bus HP fallback; `(no read)` when nothing is legible). Added a
  passive `CHAT_MSG_ADDON` receiver for the `WSGFCNamesHP` prefix (listen-only, never broadcasts).
  Per-icon OnClick gained a Shift branch: posts `EFC <LOC_LABEL> — <status>` (bare `EFC <status>`
  for CAP/PICK) as `RAID_WARNING` when `UnitIsGroupLeader`/`UnitIsGroupAssistant`, else `/bg`;
  3 s throttle; falls back to the plain location callout when no enemy is carrying. Added the
  per-icon `LOC_LABEL` literal (derived from `ENEMY_MSG`). Rebuilt `export.txt`, regenerated
  `aura.json`, decode→encode→decode **lossless**; `code/init.lua` refreshed and re-passes a
  Lua 5.1 parse. `.luacheckrc` gains `UnitIsGroupLeader`/`UnitIsGroupAssistant`. **Pending
  in-game test** (and `luacheck`, unavailable in the authoring environment).
- 2026-08-21 — Import into repo + add **Ctrl+click "Our FC" report**. Decoded the original
  27-icon group, rewrote every child's On Init to (a) bootstrap a shared `WSGCalloutHub`
  frame that tracks the friendly carrier from WSG system messages (parser from
  `WSG-FlagCarriers`; merc-aware faction from `WSG-EnemyFCAnnouncer`), and (b) branch the
  click on `IsControlKeyDown()` to post `Our FC … — <Name> HP%[, mana%]` (mana gated on
  `UnitPowerType==0`; CAP/PICK send a bare `Our FC`). Gave click buttons a nil name +
  `region.btn_ann` reuse guard (was a shared global name across all 27). Rebuilt `export.txt`,
  regenerated `aura.json`, decode→encode→decode **lossless**. `.luacheckrc` gains
  `CreateFrame`, `IsControlKeyDown`/`IsShiftKeyDown`/`IsAltKeyDown`, `WSGCalloutHub`.
  **Pending in-game test** (and `luacheck`, unavailable in the authoring environment).
