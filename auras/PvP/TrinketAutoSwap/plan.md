# Plan — PvP Trinket Auto-Swap (AGM / Insignia / Minor Recombobulator)

> **Status: PLAN ONLY — nothing implemented yet.** This file exists to confirm the design
> and surface the hard constraints before any Lua/export is authored.
> Target flavor: **Classic Era** (level-19 twink PvP, Paladin `Sweatybetty` + other twinks).

---

## 1. Intent

Auto-manage which two trinkets sit in **slots 13 & 14** based on the live cooldown state of
three items, so the character always fields the most useful pair without hand-swapping
through the Trinket Menu addon. Trinket Menu can't make Arena Grand Master the *fallback*
trinket when everything is down — this aura resolves that with an explicit priority engine.

Also provide a **detached, movable display** of slots 13 & 14 showing the currently-equipped
trinket icons with cooldown swipe + numeric cooldown text.

---

## 2. The three trinkets (verified on Classic Wowhead)

| Trinket | Item ID | On-use | Equip passive | CD | Notes |
|---|---|---|---|---|---|
| **Arena Grand Master (AGM)** | **19024** | Absorb 750–1250 dmg, 20 sec | **+1% dodge** | **30 min** | On-use is once-per-game; ongoing value = the passive. Not marked Unique. |
| **Insignia of the Alliance (IoTA)** | **18864** (Paladin/Alliance — confirmed in-game) | Dispels Fear + Poly + Stun | none | 5 min | **Unique** (one copy). ID is class/faction-specific → still a **config value** so Horde/other-class twinks fill their own. |
| **Minor Recombobulator (MR)** | **4381** | Dispel Poly on friendly + restore 150–250 HP/mana | none | 5 min | **Consumable / charge-limited** — poofs when depleted; carry spares. Resolve by item ID, never bag slot. |

**No-invent note:** 19024 and 4381 confirmed on Wowhead; **IoTA=18864 confirmed in-game** via
`GetInventoryItemID("player",13)` on the Alliance Paladin (`Sweatybetty`). The Insignia family
(`18854/18863/18864/...`) is class/faction-specific with different dispel sets, so it stays a
Custom Option. **Paladins are Alliance-only in Classic** → any Horde twink is a different class
with its own Insignia ID; fill per character. Defaults: AGM=19024, MR=4381, IoTA=18864.

---

## 3. Decision engine (priority resolver)

Inputs each evaluation: `Iready`, `Aready`, `Mready` (off-cooldown?) + `Mowned` (any MR copy in
bags/equipped) + `agmLocked` (within 20s of AGM on-use). Output: desired 2-trinket set.

Full state table (readiness → desired loadout):

| # | IoTA | AGM | MR | Desired loadout | Source rule |
|---|---|---|---|---|---|
| 1 | ✓ | ✓ | ✓ | **IoTA + AGM** | R1 (both best up) |
| 2 | ✓ | ✓ | ✗ | **IoTA + AGM** | R1 |
| 3 | ✓ | ✗ | ✓ | **IoTA + MR** | R2 (AGM down → MR; keep a 2nd dispel) |
| 4 | ✓ | ✗ | ✗ | **IoTA + AGM** | *inferred* (MR unavailable → keep AGM passive) |
| 5 | ✗ | ✓ | ✓ | **AGM + MR** | R2 (IoTA down → MR) |
| 6 | ✗ | ✓ | ✗ | **AGM + IoTA** | *inferred* (AGM kept + soonest-returning) |
| 7 | ✗ | ✗ | ✓ | **AGM + MR** | R3 (both down, keep AGM passive + MR) |
| 8 | ✗ | ✗ | ✗ | **AGM + soonest(IoTA,MR)** | R4 (AGM passive + whichever returns first) |

**Overrides (highest priority first):**
1. **AGM 20-sec lock** — when AGM's on-use has fired, keep AGM equipped for ≥20 s
   (its absorb buff is item-bound; unequipping strips the shield, and unequipping loses the
   +1% passive). While locked, force AGM into the loadout regardless of the table.
2. **In-combat freeze** — never swap in combat (see §4). Compute the desired set, mark it
   *pending*, apply on leaving combat.
3. **No-op guard** — if the desired set already occupies {13,14} (any order), do nothing.

Rows **4 and 6 are inferred** (user didn't specify) — flagged for confirmation.

---

## 4. HARD CONSTRAINTS (design is shaped by these — read first)

### 4a. You cannot change equipment in combat
`EquipItemByName` / cursor-swap are blocked while `InCombatLockdown()` is true — a client
restriction, not something code can bypass. **Therefore this is an OUT-OF-COMBAT optimizer.**
- Drive swaps off `PLAYER_REGEN_ENABLED` (combat end) + cooldown/bag events while out of combat.
- During combat: only **display** the pending target loadout; queue and apply the instant
  combat drops. For twink WSG this is fine — you re-optimize between fights / after res / before
  engaging, which is when swaps are legal anyway. **Confirm this matches the user's expectation
  (no true mid-fight hot-swap is possible for anyone).**

### 4b. Sandbox must be verified to allow equipping (same drill as SendChatMessage)
The documented WA blocklist (`workflow.md §6`) is `getfenv/setfenv/loadstring/pcall/xpcall`,
`SendMail/SetTradeMoney/EditMacro/CreateMacro/GuildDisband`, `SlashCmdList/WeakAurasSaved/
WeakAurasOptions`. **`EquipItemByName` / `PickupInventoryItem` / `PickupContainerItem` /
`EquipCursorItem` are NOT listed** — expected to pass through. **Verify in-game before building
logic** with a print test in On Init:
```lua
print(EquipItemByName and "TRK: EquipItemByName OK" or "TRK: BLOCKED")
```
"OK" → proceed. "BLOCKED" → rethink (macro/secure-button fallback, which has its own limits).

### 4c. Item cooldowns persist in bags; MR is consumable
- Unequipping a trinket does **not** reset its on-use cooldown — it keeps ticking in the bag,
  readable via `GetItemCooldown(itemID)`. This is what makes the resolver correct.
- MR poofs on depletion → its bag slot changes. Always target MR by **item ID**
  (`EquipItemByName(4381, slot)` grabs any copy; `GetItemCount(4381)` tests availability).

---

## 5. Architecture — a WeakAuras **group** of 3 children

```
PvP Trinket Auto-Swap (group)
├── Controller        (logic; no/minimal visible region — optional debug text)
├── Trinket Slot 13   (detached icon: current trinket + cooldown swipe + number)
└── Trinket Slot 14   (detached icon: current trinket + cooldown swipe + number)
```

**Controller** — holds all logic in custom code:
- `init.lua` (On Init): read config (item IDs, enable, BG-only, min-swap-gap); build
  `aura_env` state; flavor branch for the cooldown API.
- `trigger.lua` / `tsu.lua`: react to events, recompute, apply out of combat.
- `on_show`/`on_hide`: start/stop a `C_Timer` ticker (~1s) for "soonest off CD" ordering +
  AGM-lock expiry.

**Slot 13 / Slot 14 displays** — cleanest native path: WA trigger **"Cooldown Progress
(Item Slot)"** targeting inventory slot 13 / 14 (auto-shows the equipped item's icon + CD).
Fallback if that trigger type is missing on the installed WA build: custom TSU using
`GetInventoryItemTexture("player",slot)` + `GetInventoryItemCooldown("player",slot)`.
"Detached / movable" = the two icons are free-positioned regions the user drags in WA.
Numeric CD = WA's Cooldown text on the icon.

---

## 6. Events the controller listens to

| Event | Purpose |
|---|---|
| `PLAYER_REGEN_ENABLED` | left combat → apply any pending swap |
| `PLAYER_REGEN_DISABLED` | entered combat → freeze swapping |
| `BAG_UPDATE_COOLDOWN` | a trinket's cooldown started/refreshed → recompute |
| `UNIT_INVENTORY_CHANGED` (player) / `PLAYER_EQUIPMENT_CHANGED` | equipment changed → resync state + display |
| `BAG_UPDATE` / `ITEM_COUNT_CHANGED` | MR consumed/poofed → find next copy / re-eval availability |
| `PLAYER_ENTERING_WORLD` | init/resync on load & zone |
| `C_Timer` ticker (~1s) | AGM-lock expiry + "soonest returning" ordering for rows 6/8 |

Detect AGM on-use → set `agmLockUntil = GetTime()+20`: watch `GetItemCooldown(19024)` start-time
change, or the absorb buff via `UnitAura`.

---

## 7. Cooldown / equip API (Classic Era; guard for Cata/MoP)

- Equipped slot CD: `GetInventoryItemCooldown("player", 13|14)` → `start, duration, enable`.
- Any item by ID (bag or worn): `GetItemCooldown(itemID)` → `start, duration, enable`.
  (Global on Era; on Cata/MoP Classic it moved to `C_Container.GetItemCooldown` /
  `C_Item.GetItemCooldown` — branch on `WOW_PROJECT_ID`.)
- Availability: `GetItemCount(itemID)` (bags).
- Equip: `EquipItemByName(itemID, dstSlot)` where `dstSlot` = 13 or 14. Compute the minimal diff
  vs current {13,14}; equip only the missing piece into the slot holding the unwanted trinket.

---

## 8. Config (Custom Options) + anti-thrash

- `iotaId=18864` (Alliance Paladin default — other twinks override), `agmId=19024`, `mrId=4381`.
- `enabled` (master toggle), `bgOnly` (Load only in BG/PvP, or a manual on/off).
- `minGap` (seconds) debounce between swaps; **no-op guard** so it never re-equips an
  already-correct loadout; never issues equips in combat.
- Optional canonical slot ordering (e.g., AGM prefers slot 14) purely for display stability.

---

## 9. Decisions (confirmed) + remaining in-game checks

1. ~~Out-of-combat-only swapping acceptable?~~ **CONFIRMED** — OOC is the only mechanically
   possible path; aura is an OOC optimizer.
2. ~~Rows 4 & 6 inferred loadouts~~ **AGREED** as written.
3. ~~BG-only vs always-on?~~ **ALWAYS-ON with a manual toggle** (`enabled` Custom Option; no
   zone Load restriction).
4. ~~Insignia item ID~~ **done: 18864.** Per-character IDs still needed for Horde/other-class twinks.

Remaining (in-game verification, not blockers):
- **A.** Sandbox permits `EquipItemByName` (print test — expect OK).
- **B.** Does unequipping AGM strip its absorb buff? (Assumed yes → 20 s lock built in.)
- **C.** Native "Cooldown Progress (Item Slot)" trigger available on the installed WA build for
  the two slot displays (fallback: custom TSU).

---

## 10. Testing (cannot be validated from the repo)

1. Sandbox print test for `EquipItemByName` (§4b) → expect OK.
2. Out of combat at a target dummy / duel: fire each trinket, watch the resolver land the
   correct loadout per §3; confirm no swaps attempt in combat.
3. Confirm AGM stays put for 20 s after use; confirm MR re-equips a fresh copy after one poofs.
4. Confirm slot 13/14 display tracks equips + shows correct cooldown numbers.
5. Only then: mark tested, export string → `export.txt`, fill `aura.md`, add catalog row.

---

## 11. Files to be produced on implementation (not yet created)

`auras/PvP/TrinketAutoSwap/` → `aura.md`, `export.txt`, `aura.json`, and
`code/{init.lua, trigger.lua, tsu.lua, on_show.lua, on_hide.lua, custom_text.lua}`.

---

## 12. Zero-config faction support (Insignia auto-detection) — implemented 2026-07-05

**Goal:** drop-in for both Alliance and Horde with **no config**. AGM (19024) and MR (4381) are
engineering trinkets with the **same item ID on both factions**, so they never need config. The
Insignia is the only faction/class-specific ID — so auto-detect it at runtime instead of hardcoding.

**Mechanism:** `DetectInsignia()` scans worn trinket slots (13/14) then bags 0–4 for an item whose
name contains **"Insignia of the"** (matches "…of the Alliance"/"…of the Horde", all classes).
`RefreshInsignia()` writes the found id into `cfg.iotaId` unless the user pinned `iotaId` as a
Custom Option (explicit override always wins). Runs on init + every 1 s tick, so a bagged Insignia
that isn't item-info-cached yet resolves within a tick.

**Why name-scan, not an ID table:** the per-class Insignia IDs aren't all verified, and the repo
rule is *don't invent IDs*. Name-matching needs no ID list. Trade-off: **English clients only** —
non-English locales pin `iotaId` (the fallback default 18864 keeps the resolver nil-safe meanwhile).

**Why NOT a shared `TRK_IDS` global:** the WA sandbox only falls through to real `_G` on *reads*
(how the macro-set `TRK_PAUSED` is read). A global *written* from aura code stays in that aura's
environment and wouldn't reach the separate bench display. So the bench icon (`benched.lua`) runs
its **own** copy of the same name-scan instead of consuming a controller-published global. The two
slot icons never referenced item IDs (they read live slot contents), so they were already agnostic.

**Net:** English Era = true zero-config on either faction. Off-locale = one `iotaId` override.
