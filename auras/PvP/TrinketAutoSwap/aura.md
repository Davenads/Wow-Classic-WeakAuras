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

## Structure — one controller + two native displays

This folder ships the **controller** only (all the logic). The two detached slot displays are
pure-native WA with no custom code — make them in ~30 s each:

**A. Controller** — import `export.txt` (`!WA:2!…`). It's a Text region; leave it where you like
(it stays blank unless the `debug` option is on). All swapping logic lives here.

**B & C. Slot 13 / Slot 14 displays** — for each, `New ▸ Icon`, then
`Trigger ▸ Type: Cooldown Progress (Item Slot)` → pick **Trinket (Slot 1)** = 13 and
**Trinket (Slot 2)** = 14. Enable the cooldown swipe + cooldown text. Drag each icon wherever you
want ("detached / movable"). These auto-show whatever trinket is currently in the slot with its
cooldown number — no code needed.
*(If your WA build lacks that trigger type, use a custom TSU with
`GetInventoryItemTexture("player",13|14)` + `GetInventoryItemCooldown("player",13|14)`.)*

Optionally drag all three into a WA group for tidy management.

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

---

## Code blocks (`code/`)

| File | WA block |
|---|---|
| `init.lua` | Actions ▸ On Init — config, helpers, resolver, `Apply()` |
| `trigger.lua` | Trigger ▸ Custom ▸ Status (+ Events box, listed in-file) |
| `on_show.lua` | Actions ▸ On Show — start 1 s ticker |
| `on_hide.lua` | Actions ▸ On Hide — cancel ticker |
| `custom_text.lua` | Display ▸ text `%c` — optional debug readout |

Resolver = the §3 table in `plan.md`. AGM 20 s lock + out-of-combat gate + no-op guard + debounce.

---

## Testing checklist (out of combat, at a dummy / duel)

1. Sandbox print test → TRK OK.
2. Fire each trinket; confirm the resolver lands the correct pair per `plan.md` §3.
3. Confirm nothing swaps while in combat; the pending swap applies on combat end.
4. Confirm AGM stays put ~20 s after use; confirm a fresh MR re-equips after one poofs.
5. Confirm slot 13/14 displays track equips + show cooldown numbers.

---

## Changelog

- **2026-07-05** — Initial build. Controller (5 code blocks) + native slot-display recipe.
  Item IDs verified (AGM 19024, MR 4381 on Wowhead; Insignia 18864 in-game). Export round-trip
  verified (4522 bytes). Untested in-game.
