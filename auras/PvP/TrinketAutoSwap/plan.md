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

---

## 13. Two-AGM optimization ("dodge-stacking" mode) — implemented 2026-07-06

**Goal:** a character that owns **two Arena Grand Masters** (item 19024) should wear **both**
whenever neither on-use trinket is needed, so their **+1% dodge passives stack to +2% total**.
AGM 19024 is **not Unique-Equipped**, so two copies can occupy slots 13 & 14 simultaneously.

**The shared-cooldown constraint (why this is passive-only value):** two copies of the *same*
item share **one** on-use cooldown keyed by item ID — firing either AGM puts **both** on the
30-min CD. There is **no absorb-chaining**; the only benefit of the 2nd AGM is the extra +1%
dodge. So the engine treats the 2nd AGM purely as a "best available passive" filler, never as a
second on-use.

**Detection:** `AgmCount()` = `GetItemCount(agmId)` (bags only) + a copy in slot 13 + a copy in
slot 14. `AgmCount() >= 2` (and `cfg.stackAgm` on) enters 2-AGM mode. A 1-AGM character is
**completely unaffected** — the original §3 table still runs.

**Model B — always keep ≥1 AGM equipped** (chosen over "swap freely"). One slot is *always* an
AGM; the engine only decides what fills the **other** slot:

| Other-slot state | Fills with | Rationale |
|---|---|---|
| Insignia ready **or** returning within `swapBackAt` | **Insignia** | dispel is the priority on-use (Insignia > MR) |
| else MR ready **or** returning within `swapBackAt` | **MR** | secondary dispel/heal |
| else (both on-use trinkets >`swapBackAt` out) | **2nd AGM** | nothing useful returning soon → bank +2% dodge |

Baseline (everything off cooldown) → **AGM + Insignia** (Insignia is "ready" ⇒ `usableSoon` true).

**`swapBackAt` pre-equip window (the 31s buffer):** `swapBackAt = equipCd + swapBuffer`
(default `30 + 1 = 31`). Equipping any trinket applies a ~30-s **equip lockout** on its use.
By swapping the on-use trinket back in **~31 s before** its real cooldown expires, the equip
lockout runs out in lock-step with the cooldown — the trinket is usable the **instant** it comes
off CD, with no extra wait. `usableSoon(x) = Owned(x) and CdLeft(x) <= swapBackAt`.

**Multiset apply:** `Desired()` now returns an ordered **list** `{ id1, id2 }` that may repeat
(`{ AGM, AGM }`), replacing the old set. `Apply()` greedily **claims** each wanted slot with a
*distinct* equipped copy, so `{ AGM, AGM }` requires two physically equipped AGMs (a single worn
copy can't satisfy both). A fresh equip needs a **bag copy** (`GetItemCount(id) > 0`) because
`EquipItemByName` pulls from bags — guaranteed for the 2nd AGM (the unequipped copy sits in bags).
One equip per call; events reconverge.

**Config additions:** `swapBuffer` (default 1) and `stackAgm` (default true — set false to force
single-AGM behavior even when two are owned). AGM post-use lock is a no-op in 2-AGM mode (AGM is
always worn), so the §3 override block is skipped by the early return.

**Bench display:** unchanged — still **one** bench icon. `benched.lua` dedups by "not in slot
13/14", which correctly handles two worn AGMs (both are in slots, so neither shows as benched).

---

## 14. Anti-thrash hysteresis (1-AGM slot flicker fix) — implemented 2026-07-06

**Symptom:** with Insignia (IoTA) build, MR + AGM equipped, MR used mid-fight — the two equipped
trinkets flickered between slots 13↔14 every ~1 s, re-firing the 30-s equip lockout each swap
(and re-locking AGM). Insignia never settled into the loadout.

**Why it happened:** `Apply()` runs on a 1-s ticker **and** on a fan-out of events
(`PLAYER_EQUIPMENT_CHANGED` + `BAG_UPDATE` + `BAG_UPDATE_COOLDOWN` + `UNIT_INVENTORY_CHANGED`),
so every equip re-enters the resolver almost immediately. The `soonest()` pick in rows 6/8 (and
the `mAvail` branch) can flip its choice between two **on-cooldown** on-use trinkets when their
remaining CDs are close, or when a **duplicate MR copy's** readiness momentarily reads differently
(most players carry several MRs). Because MR has bag spares, the bag-copy guard never blocks
re-equipping it, so each flip produced a physical swap → visible flicker.

**Design decision (do NOT `swapBackAt`-gate 1-AGM):** an earlier idea was to only equip an on-use
trinket within `swapBackAt` (~31 s) of ready. That is **correct for 2-AGM** (there the alternative
is the 2nd AGM's real +1% dodge passive) but **wrong for 1-AGM**: fielding the *soonest-returning*
on-use makes it usable the earliest (a benched trinket coming off CD isn't usable until re-equipped
+ its 30-s lockout), at zero cost (IoTA/MR have no passive to lose while benched). Example the fix
must preserve: leave combat with MR equipped (~4 m) and IoTA benched (~3 m) ⇒ swap IoTA in (it
returns sooner), **once**, then hold.

**Fix — hysteresis in `Apply()` (`okToSwap`)**: before equipping a benched on-use trinket into a
slot that currently holds an **on-cooldown** on-use trinket, require the incoming one to be either
**usable now** (`IsReady`) or **meaningfully sooner** — `CdLeft(incoming) <= CdLeft(displaced) - swapMargin`
(default `swapMargin = 5 s`). Otherwise the swap is skipped and the current loadout is held (no
equip ⇒ no event cascade ⇒ no thrash). AGM (the passive anchor) is never gated; replacing an empty
slot or an untracked/junk trinket is always allowed; row 3 (bench AGM for two ready dispels) still
works because the incoming trinket is ready.

**Why this converges:** once the soonest on-use is equipped, the flip source can no longer pull it
back — the benched alternative is *later*, not sooner, so `okToSwap` returns false and it holds.
Near-ties (< `swapMargin`) never swap. The multiset claim already prevents re-positioning a loadout
that is already present. `minGap` (1 s) still debounces the same-frame event cascade.

**Config addition:** `swapMargin` (default 5). 2-AGM mode is unaffected (its own `swapBackAt`
gating already prevents churn; `okToSwap` allows AGM anchoring and ready/sooner on-use swaps).

## 15. Multiset-aware re-equip guard (1-AGM thrash — regression fix) — implemented 2026-07-06

**Symptom (persisted past §14):** on a 1-AGM character with MR + AGM worn and Insignia benched, the
two equipped trinkets keep trading slots 13↔14 every ~1 s. MR (which has bag spares) is re-equipped
each tick — its 30 s equip lockout resets and never counts down — while AGM (1 copy, no spare) is
merely *dragged* between slots by `EquipItemByName` swapping it out.

**Root cause — a regression from the 2-AGM rewrite (`d9ffe4f`).** The pre-2-AGM `Apply()` gated every
equip with `id ~= id13 and id ~= id14`: **an item already worn was never a candidate for equipping.**
That made re-equipping (and therefore restarting an equip lockout) *structurally impossible*. The
2-AGM rewrite replaced that hard guard with a multiset `claim` over the top-of-`Apply` slot snapshot,
and switched the ownership test to `GetItemCount(id) > 0` (bag-only). Consequences: (a) if the snapshot
misses a worn copy, the item is re-equipped; (b) MR always has a bag spare so it is infinitely
re-equippable, while a 1-AGM AGM (no spare) can only be dragged — exactly the observed picture. The
old guard was dropped because it also blocked the legitimate 2-AGM `{A, A}` (equip a 2nd AGM while one
is already worn).

**Fix — restore the guarantee in multiset-aware form.** Before `EquipItemByName(id, target)`, skip if
`wornCount(id) >= wantedCount(id)`, where `wornCount` re-reads slots 13/14 **fresh** (so a copy equipped
since the snapshot still counts) and `wantedCount` counts `id` in the `want` list. For 1-AGM `{A, M}`
with A+M worn, both counts are equal ⇒ neither is ever re-equipped (matches the bulletproof pre-2-AGM
behavior). For 2-AGM `{A, A}` with one AGM worn, `1 < 2` ⇒ the 2nd AGM still equips. This composes
with the §14 `okToSwap` hysteresis (both retained). No new config. 2-AGM path untested in-game (no
2-AGM test character available); 1-AGM is the target of this fix.

## 16. Diagnostic instrumentation + thrash-breaker (persisted bounce) — implemented 2026-07-06

**Situation.** After both §14 (`okToSwap` hysteresis) and §15 (multiset-aware re-equip guard) shipped
and were re-imported, the 1-AGM bounce STILL reproduced (MR ↔ AGM trading slots 13↔14 every ~1 s, MR
pinned at "30", Insignia benched). The user confirmed it worked before the 2-AGM logic and persists
regardless of which string is imported.

**Static proof a single engine can't do this.** Trace the observed state through the *current* code:
`Desired()` returns `{AGM, MR}` (row 7 — both dispels down, MR available). In `Apply()`, `claim(id13)`
and `claim(id14)` both succeed against `{AGM, MR}`, so `ok13 and ok14` is true and the function returns
at the "already correct" early-out **before** `now`, `target`, `okToSwap`, or any `EquipItemByName` is
ever reached. The §15 `wornCount >= wantedCount` guard would independently block the re-equip even if
execution continued. Both the pre-2-AGM code and two duplicate-identical engines converge on the same
loadout. **Conclusion: a lone instance of this engine cannot generate the observed equip traffic** —
something *outside* the resolver's normal path is driving the swaps.

**Leading hypothesis: two engines fighting.** The most consistent explanation for "worked before 2-AGM,
broke after, survives every reimport" is that a **second controller instance** is running — e.g. a
standalone `export.txt` engine imported earlier still enabled *alongside* the `package.txt` group's
engine, or an "Import as Copy" duplicate. Two engines can each satisfy their own `Desired()` yet, if
their momentary reads differ by a tick, ping-pong the two physical trinkets between slots. Every
debugging reimport that didn't delete the prior aura would have *added* another controller.

**Instrumentation added (not a logic change — observability):**
- **Per-engine `instanceTag`** (`math.random(1000,9999)`) + `aura_env.Dbg(msg)` logger, gated by
  `aura_env.cfg.debug` **or** a global `TRK_DEBUG` (toggle live with `/run TRK_DEBUG = true`).
- **Load banner** printed once per engine load: `engine loaded (tag ####)`. **Two distinct tags in
  chat = two engines** — the smoking gun. Delete extras, keep one.
- **"acting:" decision log** on every tick that intends to change the loadout (settled ticks stay
  silent), showing `want` vs the two worn slot ids — reveals *what* each engine is trying to do.

**Thrash-breaker (behavioral safety net):** in the equip loop, track the last equipped id + time. If
the **same id** is equipped **≥3× within 3 s**, log `THRASH DETECTED …`, set `backoffUntil = now + 10`,
and return without equipping. This converts an invisible perpetual 1-s equip loop into a single
diagnostic line and a held loadout. A healthy one-shot swap never trips it (it reaches `want` and the
early-out returns thereafter). Also added a `backoffUntil` guard near the top of the act path so the
10-s hold is honored across both the ticker and the event fan-out.

**Test protocol.** Import the new string (delete the old aura first — do NOT "Import as Copy"),
`/run TRK_DEBUG = true`, reproduce. Then: (a) count distinct `[TRK ####]` tags at load — **>1 confirms
duplicate engines**; (b) if one tag, read the `acting:`/`EQUIP`/`THRASH DETECTED` lines to see the real
decision the single engine is making (which would mean the state read, not the resolver, differs from
the static trace — e.g. `CdLeft` masking the equip lockout makes MR read falsely-ready, a separate
latent issue). Manually search `/wa` for the engine name and delete any duplicates.
