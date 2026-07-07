# WSG Enemy FC Announcer

Auto-posts the **enemy flag carrier**'s (EFC) status to battleground chat (`/bg`) in
Warsong Gulch: HP milestones + a periodic low-health reminder, key debuffs as they land,
and **diminishing-returns (DR) calls** on the carrier. "Enemy flag carrier" = the enemy
player carrying **your** flag (the one you want dead).

Built to **piggyback on the community messager** (wago `gpIg2OhpG`, *WSG Flag Carrier
Names*): it reuses that aura's proven **crowdsourced HP** model — HP read from whatever
*any* raid member is targeting (`raidNtarget`) and shared over the same addon prefix
(`WSGFCNamesHP`), so we interoperate with the large existing userbase — then layers debuff
+ DR callouts on top (the net-new value).

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
in-game.** Confirm the items under *Verify first* live before trusting it.

## ⚠️ Verify first (blocking)

1. **Sandbox allows `SendChatMessage`.** WeakAuras' sandbox blocks a set of functions
   (`SendMail`, `CreateMacro`, `loadstring`, `pcall`, …) but **not** `SendChatMessage`
   (announcer auras rely on it). To confirm without sending anything, temporarily put this
   in any aura's **On Init** and reload:
   ```lua
   print(SendChatMessage and "EFC: SendChatMessage OK" or "EFC: BLOCKED")
   ```
   If it prints `BLOCKED`, this aura can't work as custom Lua — tell me and we rethink.
2. **HP is crowdsourced across the raid.** A read comes from *any* unit token on the EFC
   — your `target` / `focus` / `mouseover` / a **nameplate** (enemy nameplates ON: **V** /
   `nameplateShowEnemies 1`) **or `raidNtarget`** = the HP of whatever any teammate is
   targeting. Your direct read is broadcast over addon prefix `WSGFCNamesHP` so peers (incl.
   users of the original messager) can display it. Hard floor that remains: if *nobody* in
   the raid can see the carrier, there's no HP to share. **`SendChatMessage` announces and
   debuff/DR calls fire only from the client that directly witnessed them** — received addon
   HP updates the on-screen readout only, never re-announces (so a raid full of this aura
   does not multiply `/bg` spam).
3. **Flavor note (widget display).** The optional top-center **flag-widget readout + click**
   needs the modern UI-widget flag frame (`UIWidgetTopCenterContainerFrame`), present on
   **Cata/MoP Classic** (and retail) but **not Classic Era** (old WorldState frames). Absent
   → it silently falls back to the movable `%c` text region. HP/debuff/DR all still work on
   every flavor; only the widget placement is flavor-gated.

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
- **Diminishing returns:** on each fresh in-category CC applied to the EFC, calls the level
  the **next** cast will get: `EFC <Name> stun DR: next 50%` → `… next 75%` → `… next
  IMMUNE`. Categories: `stun / root / fear / incap / disorient` (by spell name). A category
  resets ~18 s after its debuff fades. **⚠ DR category membership is flavor-specific (Era vs
  Cata differ) — verify in-game and edit `DR_CAT` in `init.lua` as needed.**
- **Death:** `EFC <Name> is DOWN`, then state resets.

Every send passes a **global 3 s throttle** (`minGap`) so you can't out-spam the server's
chat limiter. Each debuff announces once per application (re-announces if it fades and
reapplies).

## Config (constants at the top of `code/init.lua` → `aura_env.cfg`)

Read from `aura_env.config` with the defaults below (not yet wired to Author-Mode options,
so edit the `init.lua` constants for now):

| Key | Default | Meaning |
|---|---|---|
| `enabled` | on | Master switch. |
| `announceChat` | on | Master for **all** `/bg` sends (off = display-only, still shares HP). |
| `announceHP` | on | HP milestones + periodic reminder. |
| `announceDebuffs` | on | Hard-CC (always) + snare (while low) calls. |
| `announceDR` | on | Diminishing-returns calls. |
| `shareAddon` | on | Send/receive HP over the `WSGFCNamesHP` addon bus. |
| `channel` | `"BG"` | `"BG"` (INSTANCE_CHAT/BATTLEGROUND) · `"RAID"` (/ra) · `"SELF"` (local print, safe testing). |
| `messagePrefix` | `"EFC"` | Prefix prepended to every line. |
| `minGap` | 3 | Global throttle (s) between any two chat sends. |
| `periodicInterval` | 5 | Low-HP reminder cadence (s). |
| `hpThreshold` | 65 | Gate (%) for the periodic reminder + snare calls. |
| `useWidget` | on | Hook the top-center flag widget where present (else `%c` text). |

Also editable: the `TIERS` milestone list and the `HARD_CC` / `SNARE` / `DR_CAT` watchlists
(lowercase enUS spell names).

## Import

1. `/wa` → **Import**, paste `export.txt`. It loads only in Warsong Gulch (Load → Zone).
2. **Test safely first:** set `channel = "SELF"` in `init.lua` (via the in-game editor) so
   it `print()`s to your chat frame instead of broadcasting; flip back to `"BG"` when happy.
3. On Cata/MoP Classic the readout appears by the top-center flag counter (click it to target
   the FC). On Era it's the movable `%c` text region — drag it wherever you like.

## How it works (code → WA blocks)

Single `text` status region. All output is a **side effect** of the trigger; the region
just shows a local readout.

- `code/init.lua` → **Actions → On Init**: builds `aura_env.efc` state, reads config, picks
  the chat channel by flavor (`BATTLEGROUND` on Era, `INSTANCE_CHAT` on Cata/MoP), detects
  your **effective** faction (mercenary-aware, `81748`/`81744`), registers the `WSGFCNamesHP`
  addon prefix, defines the watchlists (`HARD_CC` / `SNARE` / `DR_CAT`) and all helpers
  (`Announce`, `ReadEnemyHP`, `BroadcastHP`, `OnAddon`, `DisplayHP`, `Tick`, `OnSystem`,
  `OnCLEU`, `ReadoutText`, `InitWidget`/`UpdateWidget`, `SetEFC`, …).
- `code/on_show.lua` → **Actions → On Show**: starts a 1 s `C_Timer` ticker (drives the HP
  read/broadcast, milestone/periodic checks, widget refresh + re-hook) and warns once if
  enemy nameplates are disabled.
- `code/on_hide.lua` → **Actions → On Hide**: cancels the ticker (no reload leak).
- `code/trigger.lua` → **Trigger 1 → Custom → Status** (Check On: Event). Events add
  `CHAT_MSG_ADDON` (HP receive) to the prior set. Routes each event to a helper; returns
  `true` so the region stays shown all match.
- `code/custom_text.lua` → **Display → Text → `%c`**: `aura_env.ReadoutText()` — the EFC +
  best-known HP (own read white, addon-shared read grey); blank when no carrier.

**Identity** comes from WSG system messages (enemy carries *your effective faction's* flag).
**HP** is crowdsourced: own token *or* `raidNtarget` scan, GUID-locked when seen, broadcast
+ received over `WSGFCNamesHP`. **Debuffs, DR & death** come from the combat log
(`SPELL_AURA_APPLIED/_REFRESH/_REMOVED`, `UNIT_DIED`) matched on the EFC's GUID/name — CLEU
gives a clean `spellName`, dodging per-rank-ID and 16-debuff-cap gotchas. **DR** tracks an
in-category application chain (full → ½ → ¼ → immune), resetting ~18 s after the debuff fades.

## Testing notes (verify in-game)

- **Plumbing (anywhere):** the `SendChatMessage` snippet above; or set `mode="SELF"` and
  confirm the readout tracks a hostile `target` you mouse over.
- **Full flow (needs a WSG):** let an enemy grab your flag → confirm one milestone/periodic
  post while ≤ 65 %; apply Hamstring while they're low → one snare post; Polymorph them at
  full HP → a hard-CC post; kill them → `is DOWN`; spam events → nothing faster than 3 s.
- **Locale:** system-message and spell-name matching is **enUS** — edit patterns/watchlists
  for other clients.
- **Etiquette / spam:** chat announces fire only from the client that *directly* witnessed
  the HP/debuff/DR (received addon HP is display-only), so a raid full of this aura naturally
  limits `/bg` output to whoever can see the carrier. The `announceChat` switch + 3 s throttle
  are your extra guards. **DR calls:** verify `DR_CAT` categories on your flavor.

## Changelog

- 2026-07-05 — Initial implementation: status trigger + On Init/Show/Hide + `%c` readout.
  HP tiers (65/50/35/20) + 5 s periodic reminder ≤ 65 %; hard-CC debuffs announced always,
  snares only when low; 3 s global throttle; CLEU-based debuff/death detection; flavor-aware
  chat channel. Import string generated and round-trip-verified; **pending in-game test.**
- 2026-07-06 — Rebuilt on the community messager's engine (wago `gpIg2OhpG`) + added DR.
  **Crowdsourced HP:** `ReadEnemyHP` now reads from own token *or* the `raidNtarget` scan
  (any teammate's target), GUID-locks the EFC, and broadcasts/receives over the original's
  `WSGFCNamesHP` addon prefix (interop with the existing userbase); received HP is display-
  only (anti-spam: chat fires only from the direct witness). **Mercenary-aware faction**
  (`81748`/`81744` → effective flag). **DR tracking:** in-category chain (stun/root/fear/
  incap/disorient) calling next-cast level (½/¼/immune), 18 s fade reset — `DR_CAT` is
  flavor-specific, needs in-game verification. **Optional widget display**: hooks the
  top-center flag frame (Cata/MoP/retail) with a click-to-target readout, else falls back to
  `%c`. Added config keys `announceChat/HP/Debuffs/DR`, `shareAddon`, `channel` (BG/RAID/SELF),
  `useWidget`. Trigger gains `CHAT_MSG_ADDON`. Rebuilt `export.txt` (10768 bytes). Round-trip
  verified; **pending in-game test.**
