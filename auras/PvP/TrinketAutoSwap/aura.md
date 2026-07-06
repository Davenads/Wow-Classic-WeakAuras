# Betty's 19 Twink Trinket Manager (AGM / Insignia / Minor Recombobulator)

> In-game names: controller = **Betty's 19 Twink Trinket Manager**; display group = **Betty's
> Trinket Display**. (Repo folder stays `TrinketAutoSwap`.)

- **Category:** PvP (level-19 twink)
- **Target flavor:** Classic Era (Anniversary / SoD / HC). Item-cooldown call branches for Cata/MoP Classic.
- **Status:** Built + round-trip verified. **NOT yet tested in-game** (linting ≠ working).
- **wago:** —
- **Min WeakAuras:** 5.x (uses standard custom-code blocks + `C_Timer`).

Keeps the best 2-of-3 trinkets in slots 13/14 by live cooldown, so **Arena Grand Master stays
equipped as the fallback** (for its +1% dodge passive) that Trinket Menu can't prioritise.
Full design + decision table live in `plan.md`.

Trinkets (verified): **AGM 19024** · **Insignia of the Alliance (Paladin) 18864** · **Minor Recombobulator 4381**.

---

## ⚠️ Verify first (in-game — cannot be checked from the repo)

1. **Sandbox permits equipping.** Temporarily add to Actions ▸ On Init:
   `print(EquipItemByName and "TRK OK" or "TRK BLOCKED")` → `/reload` → read chat. Expect **TRK OK**.
   (Same drill that confirmed `SendChatMessage` for the FC announcer.)
2. **No in-combat swapping — a client rule, not a code limit.** Equipment can't change in combat,
   so this applies swaps **out of combat only** (on `PLAYER_REGEN_ENABLED` + cooldown/bag events).
   During combat it just marks the target loadout *pending* and applies it the instant combat drops.
3. **AGM 20 s lock assumption:** unequipping AGM is assumed to strip its absorb buff, so the code
   force-keeps AGM equipped for 20 s after its on-use fires. Confirm the buff behaves that way.

---

## Structure — one controller + one display group

Two separate importable units. Import both `!WA:2!` strings:

**A. Controller** — import `export.txt`. It's a Text region; leave it where you like (blank unless
the `debug` option is on). All swapping logic lives here.

**B. "Betty's Trinket Display" group** — import `display.txt`. A movable WA group of **3 custom-TSU icons**:

| Icon | Shows | Size | Trigger source |
|---|---|---|---|
| Trinket Slot 1 | live-equipped trinket in inv slot **13** + its cooldown | 40 | `displays/slot13.lua` |
| Trinket Slot 2 | live-equipped trinket in inv slot **14** + its cooldown | 40 | `displays/slot14.lua` |
| Trinket Bench | whichever tracked trinket is **not** in 13/14 (soonest-ready if two) | 26 | `displays/benched.lua` |

Each icon is a `Trigger ▸ Custom ▸ Trigger State Updater` populating `allstates[""]` with
icon/name and a timed `duration`/`expirationTime` for the cooldown swipe + number. Drag the group
(or individual icons) anywhere — they keep independent offsets. The bench icon **auto-detects** your
Insignia by name (like the controller), so it's zero-config on either faction — no per-character
edit. (Non-English clients: swap the `18864` fallback in `displays/benched.lua` for your Insignia id.)

*Hand-fabricated icon/group regions:* the import IS the test. If any icon mis-imports, export me one
native WA icon to clone the exact region schema from.

**B-alt. "Betty's Trinket Bar" group** — import `display2.txt`. Same three TSUs
(`displays/slot13.lua` / `slot14.lua` / `benched.lua`) laid out as a horizontal **bar**: two larger
44px slot windows side by side + a 30px 3rd-trinket icon hugging slot 2, cooldown numbers overlaid
on each. Independent `uid`s, so it imports **alongside** "Betty's Trinket Display" (doesn't overwrite
it) — pick whichever layout you prefer; you don't need both.

---

## Custom Options (Author Mode → aura_env.config)

| Option Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | toggle | on | Master on/off (the "manual toggle"). |
| `agmId` | number | 19024 | Arena Grand Master item ID. |
| `iotaId` | number | auto | Insignia item ID. **Auto-detected by name** (works Alliance + Horde, zero config); set this only to pin/override on non-English clients. |
| `mrId` | number | 4381 | Minor Recombobulator item ID. |
| `minGap` | number | 1.0 | Seconds between equip attempts (debounce). |
| `agmLock` | number | 20 | Keep AGM equipped this long (s) after its on-use. |
| `equipCd` | number | 30 | Ignore cooldowns ≤ this (s) — the trinket equip lockout, not a real CD. |
| `debug` | toggle | off | Print each swap + show a slot readout in the controller text. |

Defaults are baked into `init.lua`, so it works with **zero options set** on either faction — the
Insignia is auto-detected by name at runtime. Set `iotaId` only to override (e.g. a non-English
client where the name-scan can't match).

## Toggle on/off (macro)

The sandbox blocks `SlashCmdList`, so the aura can't register its own `/command`. Instead it
honors a plain global `TRK_PAUSED` that an out-of-sandbox macro flips. Make one macro:

```
/run TRK_PAUSED = not TRK_PAUSED; print("|cff66ccff[Trinket Swap]|r "..(TRK_PAUSED and "PAUSED" or "ACTIVE"))
```

Click / keybind it to pause & resume. It resets to **ACTIVE** on `/reload` or login (default-on).
For a persistent off, disable the aura in `/wa` (right-click ▸ Disable).

---

## Code blocks (`code/`)

| File | WA block |
|---|---|
| `init.lua` | Actions ▸ On Init — config, helpers, resolver, `Apply()` |
| `trigger.lua` | Trigger ▸ Custom ▸ Status (+ Events box, listed in-file) |
| `on_show.lua` | Actions ▸ On Show — start 1 s ticker |
| `on_hide.lua` | Actions ▸ On Hide — cancel ticker |
| `custom_text.lua` | Display ▸ text `%c` — optional debug readout |
| `displays/slot13.lua` | "Trinket Display" group ▸ Slot 1 icon ▸ TSU |
| `displays/slot14.lua` | "Trinket Display" group ▸ Slot 2 icon ▸ TSU |
| `displays/benched.lua` | "Trinket Display" group ▸ Bench icon ▸ TSU |

Resolver = the §3 table in `plan.md`. AGM 20 s lock + out-of-combat gate + no-op guard + debounce.

---

## Testing checklist (out of combat, at a dummy / duel)

1. Sandbox print test → TRK OK.
2. Fire each trinket; confirm the resolver lands the correct pair per `plan.md` §3.
3. Confirm nothing swaps while in combat; the pending swap applies on combat end.
4. Confirm AGM stays put ~20 s after use; confirm a fresh MR re-equips after one poofs.
5. Confirm slot 13/14 icons track equips + show cooldown numbers; confirm the bench icon shows the
   third trinket and its cooldown, and blanks when all three are equipped/none owned.

---

## Changelog

- **2026-07-05** — Initial build. Controller (5 code blocks) + native slot-display recipe.
  Item IDs verified (AGM 19024, MR 4381 on Wowhead; Insignia 18864 in-game). Export round-trip
  verified (4522 bytes). Untested in-game.
- **2026-07-05** — Added `TRK_PAUSED` macro toggle (sandbox blocks self-registered slash
  commands). Rebuilt export (4773 bytes). Untested in-game.
- **2026-07-05** — Added movable "Trinket Display" group (`display.txt`, 2594 bytes): 3 custom-TSU
  icons for slots 13/14 + a smaller bench icon for the unequipped tracked trinket, each with live
  cooldown swipe/number. Round-trip verified. Untested in-game.
- **2026-07-05** — Fix: `Owned()` ignored equipped copies (`GetItemCount` excludes equipped items),
  so a ready-but-equipped Minor Recombobulator read as unavailable and got swapped out for AGM.
  Now falls back to `SlotOf()`. Rebuilt export (4840 bytes). Round-trip verified.
- **2026-07-05** — Fix (oscillation): equipping a trinket triggers a ~30s equip lockout that
  `CdLeft()` mistook for a real cooldown, so a just-equipped MR read as on-CD and got reverted to
  AGM one tick later. `CdLeft()` now ignores cooldowns ≤ `cfg.equipCd` (default 30s); real use CDs
  (300s/1800s) are unaffected. Rebuilt export (5090 bytes). Round-trip verified.
- **2026-07-05** — Zero-config faction support: Insignia now **auto-detected by name**
  ("Insignia of the …") across slots 13/14 + bags on both controller and bench icon, so it works
  Alliance + Horde with no config (AGM/MR are faction-neutral). `iotaId` becomes an override.
  Dropped the `TRK_IDS` shared-global idea (sandbox writes don't reach `_G`) in favor of each unit
  self-detecting. Rebuilt export (5873 bytes) + display (3021 bytes). Round-trip verified.
  English clients only; non-English pin `iotaId` / edit the bench fallback.
- **2026-07-05** — Renamed in-game: controller → **Betty's 19 Twink Trinket Manager**, group →
  **Betty's Trinket Display** (child parents rewired, `controlledChildren` intact). Rewrote the
  controller/group `desc` to call out the Trinket-Menu-beating AGM-passive fallback. Rebuilt export
  (6114 bytes) + display (3186 bytes). Round-trip verified.
- **2026-07-05** — Added alt layout **Betty's Trinket Bar** (`display2.txt`, 3169 bytes): the same
  three TSUs as a horizontal bar (two 44px slot windows + a 30px 3rd hugging slot 2, cooldown
  numbers overlaid), cloned from the verified icon schema with independent `uid`s so it coexists
  with Betty's Trinket Display. Round-trip verified. Untested in-game.
- **2026-07-06** — Fix (icons showed as "?" + per-event Lua errors): all six display TSUs had an
  invalid `custom_type` of `"stateupdater"` instead of `"stateupdate"`. WA fell back to calling each
  as a plain event trigger `function(event, ...)`, so `allstates` received the event-name string and
  the first `allstates[""] = {…}` raised "attempt to index a string value" — no state ever built, so
  the icon regions drew the default `?` placeholder. Corrected in `display.json`/`display2.json`,
  rebuilt both strings (`display.txt` 3185 bytes, `display2.txt` 3169 bytes). Round-trip verified.
- **2026-07-06** — Added all-in-one **`package.txt`** (8060 bytes) for end-user distribution: a single
  group `Betty's 19 Twink Trinket Manager` containing the swap engine (the controller text region,
  renamed child `Trinket Swap Engine`, invisible by default — `customText` returns "" unless `debug`)
  plus the three Bar icons (`Trinket Bar 1/2/3`). One import string = engine + visuals. Fresh `uid`s
  on every member (`trkPkgGrp1`/`trkPkgEng1`/`trkPkgB13/14/BBn`) so importing it does not clobber a
  user's standalone auras — migrate by importing the package and deleting the separate ones. Engine
  `init`/`start`/`status` blocks and all three `stateupdate` TSUs verified intact via round-trip.
  Untested in-game.
- **2026-07-06** — Fix (on-import error `unknown or incompatible element type 'subforeground'`): the
  fabricated icon schema carried `subRegions:[{subbackground},{subforeground}]`, which current WA
  rejects on icon regions. Icons render texture + cooldown swipe/number natively (no sub-regions
  needed), so `subRegions` is now `[]` on every icon in `display.json`/`display2.json`/`package.json`.
  Rebuilt `display.txt` (3152), `display2.txt` (3134), `package.txt` (8025). Round-trip verified.
