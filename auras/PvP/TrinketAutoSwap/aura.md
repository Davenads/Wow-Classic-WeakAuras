# PvP Trinket Auto-Swap (AGM / Insignia / Minor Recombobulator)

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

**B. "Trinket Display" group** — import `display.txt`. A movable WA group of **3 custom-TSU icons**:

| Icon | Shows | Size | Trigger source |
|---|---|---|---|
| Trinket Slot 1 | live-equipped trinket in inv slot **13** + its cooldown | 40 | `displays/slot13.lua` |
| Trinket Slot 2 | live-equipped trinket in inv slot **14** + its cooldown | 40 | `displays/slot14.lua` |
| Trinket Bench | whichever tracked trinket is **not** in 13/14 (soonest-ready if two) | 26 | `displays/benched.lua` |

Each icon is a `Trigger ▸ Custom ▸ Trigger State Updater` populating `allstates[""]` with
icon/name and a timed `duration`/`expirationTime` for the cooldown swipe + number. Drag the group
(or individual icons) anywhere — they keep independent offsets. The bench icon carries its **own**
`IDS = {19024, 18864, 4381}` copy (separate auras don't share `aura_env`); **edit it to match your
character's Insignia ID** just like the controller's `iotaId`.

*Hand-fabricated icon/group regions:* the import IS the test. If any icon mis-imports, export me one
native WA icon to clone the exact region schema from.

---

## Custom Options (Author Mode → aura_env.config)

| Option Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | toggle | on | Master on/off (the "manual toggle"). |
| `agmId` | number | 19024 | Arena Grand Master item ID. |
| `iotaId` | number | 18864 | Insignia item ID (per character — Horde/other class differs). |
| `mrId` | number | 4381 | Minor Recombobulator item ID. |
| `minGap` | number | 1.0 | Seconds between equip attempts (debounce). |
| `agmLock` | number | 20 | Keep AGM equipped this long (s) after its on-use. |
| `debug` | toggle | off | Print each swap + show a slot readout in the controller text. |

Defaults are baked into `init.lua`, so it works with **zero options set**; add options only to
override (e.g. a Horde twink's Insignia ID).

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
