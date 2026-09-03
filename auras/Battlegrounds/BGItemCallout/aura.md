# Betty's BG Item Callout (19 bracket)

A level-19 twink **battleground enemy-item callout**. Refactored from **Devmind's**
original BG Item Callout — the detection, spell IDs, and announce behavior are Devmind's
work; this repo copy renames it to the `Betty's` family and cleans up the aura (dead
config removed, load gate hardened, docs). Watches the combat log for a fixed
set of high-impact BG consumables/trinkets used by **hostile** players, then announces
who used what — to your party/raid (`SMARTRAID`) and, for the priority "dispel this"
items, to local `/say` when the enemy is within 40 yd. Every callout shows the enemy's
name in their **class color**.

| Field | Value |
|---|---|
| **Display name** | `Betty's BG Item Callout (19 bracket)` (refactored from Devmind's original) |
| **Category / folder** | `Battlegrounds` |
| **Target flavor(s)** | Classic Era / SoD / HC (uses combat log + `SMARTRAID`/`SAY`) |
| **WA version at export** | `v:1421` |
| **Region type** | `dynamicgroup` of 10 `text` children (grows DOWN, screen-anchored, centered) |
| **Load** | Instance Type = Battleground (`size = pvp`) **and** player level `< 20` — on the group and every child |
| **wago URL** | n/a (imported from a shared string) |
| **Import string** | `export.txt` — round-trip-verified (lossless), **pending in-game test** |
| **Decoded view** | `aura.json` (regenerate after any `export.txt` change) |

## Status

`export.txt` is the source of truth — imported verbatim from the shared string, unchanged.
`decode → encode → decode` is **lossless** (`tools/cmp.js` → `LOSSLESS`). `code/custom_text.lua`
passes a Lua 5.1 parse. **Not yet tested in-game** — this repo cannot run WoW; run
`luacheck auras/Battlegrounds/BGItemCallout/code` before trusting the Lua.

## Purpose

In the 19 bracket a handful of engineering gadgets, potions, and the Arena Grand Master
trinket swing fights hard. This aura turns each **enemy** use into a chat callout so the
team can react (dispel a Swiftness Potion, focus a shielded target, etc.). Detection is by
**spell ID** with a **hostile-source** filter, so it only fires on enemies, never on your
own team.

## Consumables covered

Six distinct items across 10 text children (some items have extra `-Say` / dispelled
variants). All IDs verified on wowhead.com/classic.

| Child(ren) | spellId | Spell | Item / source | Effect |
|---|---|---|---|---|
| Swiftness, Swiftness-Say | [2379](https://www.wowhead.com/classic/spell=2379) | Speed | Swiftness Potion | +50% run speed, 15 s |
| Discombob | [4060](https://www.wowhead.com/classic/spell=4060) | Discombobulate | Discombobulator Ray (eng.) | −dmg, −20% speed, 12 s |
| RocketBoots | [8892](https://www.wowhead.com/classic/spell=8892) | Rocket Boots | Goblin Rocket Boots (eng.) | +run speed, 20 s |
| Resistance | [2380](https://www.wowhead.com/classic/spell=2380) | Resistance | Minor Magic Resistance Potion | +25 all resist, 3 min |
| MagicDust | [1090](https://www.wowhead.com/classic/spell=1090) | Sleep | Magic Dust | sleep/incapacitate |
| ArenaGrandMaster (+ -Say) | [23506](https://www.wowhead.com/classic/spell=23506) | Aura of Protection | Arena Grand Master trinket | absorbs 750–1250 dmg, 20 s |
| ArenaGrandMaster-Dispeled (+ -Say) | 23506 | Aura of Protection (`_AURA_REMOVED`) | — | fires when the AGM shield drops → "AGM down" |

## Triggers

Each child is a `text` region driven by a **Combat Log** trigger:

- **Prefix/Suffix:** `SPELL` / `_CAST_SUCCESS` (the `ArenaGrandMaster-Dispeled` pair use
  `_AURA_REMOVED`).
- **Match:** `use_spellId = true` on the spellId above. (The original also carried an inert
  `spellName = "Goblin Sapper Charge"` / `use_spellName = false` pair on every trigger — dead
  template data that was **not** evaluated; it was removed in this refactor.)
- **Source filter:** `use_sourceFlags2 = true`, `Hostile` — enemy casters only.
- **Duration:** `10` — each callout stays shown ~10 s after firing.
- The three `-Say` children add a second trigger: **Range Check ≤ 40 yd** (player), gating
  the `/say` to local-chat range.

## Actions (announces)

- **Base children** → `message_type = SMARTRAID` (e.g. `Swiftness Potion used by
  %1.sourceName`) — party/raid/instance chat, no range limit.
- **`-Say` children** → `message_type = SAY` (e.g. `Swiftness Potion used! - DISPEL
  %1.sourceName`, `AGM trinket used! - DISPEL %1.sourceName`, `AGM down on %1.sourceName`) —
  local `/say`, gated by the 40 yd range check.

## Custom code

- `code/custom_text.lua` — the `%c` display function, **identical in all 10 children**.
  Resolves the caster's class + name from `GetPlayerInfoByGUID(state.sourceGUID)` and
  returns the name wrapped in the class color (`RAID_CLASS_COLORS`), falling back to the raw
  `sourceName` when the GUID isn't a cached player.
- `code/init.lua` — **v2 Phase 0 hub scaffold** (added 2026-09-03), pasted into the **group's
  Actions → On Init**. Creates the `BGICHub` named global frame once (children don't share
  `aura_env`, so cross-child state needs a named global — same mechanism as `WSGCalloutHub`).
  Sets up server-time helpers (`GetServerTime`), locked config defaults, empty state stores,
  and registers the `BGIC` addon prefix with a **no-op receiver**. **Changes no behavior yet**
  — the 10 children keep their existing triggers and built-in announces. Later phases route
  announces through the hub (timestamps → teammates → corroboration).

Detection and the live announces are still all built in the WA UI (the children's action
`custom` boxes are enabled but empty). The only executable custom code today is the `%c` text
function and the (inert) On Init hub scaffold.

## Notes / iteration hooks

- **Load gate (corrected).** An earlier note here wrongly claimed there was no load gate —
  that was based on reading only the group's `load`. In fact **every child** already loads
  only in an Instance Type = Battleground (`size = pvp`) **and** at player level `< 20`. This
  refactor also **mirrored that same gate onto the group container**, so the restriction is
  now explicit at the group level too (visible in the group's Load tab) and the group unloads
  entirely outside a BG / at level 20+ rather than loading empty.
- **`_AURA_REMOVED` is intentional, not a false dispel.** The `ArenaGrandMaster-Dispeled`
  pair fire on `SPELL_AURA_REMOVED` of 23506 and post `AGM down on <Name>`. This fires when
  the shield ends for *any* reason (20 s expiry or fully absorbed) — which is the useful
  signal ("the shield is gone, burst now"). The message says "down", not "dispelled", so it's
  accurate; the child's `-Dispeled` id is just the original author's label. AGM's Aura of
  Protection is a physical absorb (not magic-dispellable), so there is no cleaner combat-log
  distinction to make here.
- **Magic Dust (1090)** — wowhead maps 1090 to the mage Sleep line; confirm in-game that
  Magic Dust's on-use logs 1090, or that child may never fire.
- **Coverage (future enhancement, not part of this refactor).** A fuller 19 kit could add
  **Free Action Potion** (6615, stun/root immunity), stun grenades (Thermal/Iron Grenade),
  and Net-o-Matic (13099) as cloned children. Deferred pending a decision on which items and
  their announce style.

## Testing notes

1. Import `export.txt`; enter a BG, no Lua error on load.
2. Have an enemy use a Swiftness Potion → `Swiftness Potion used by <Name>` posts to
   party/raid; if they're within 40 yd, the `DISPEL` `/say` also fires. Name shows in class
   color.
3. Enemy pops the Arena Grand Master trinket → AGM callout; when the shield drops, `AGM
   down on <Name>` fires (note: also on natural expiry).
4. Confirm nothing fires for **friendly** uses (hostile-source filter).
5. Confirm Magic Dust actually triggers (see quirk above).
6. **Hub scaffold (v2 Phase 0):** after import, load a BG and confirm no Lua error on group
   init; `/run print(BGICHub)` returns a frame and `/run print(BGICHub.now())` prints a server
   epoch. Behavior must be **unchanged** from v1 (hub is inert — enemy callouts only).

## Changelog

- 2026-09-03 — **v2 Phase 0: hub scaffold (no behavior change).** Added `code/init.lua` and
  wired it into the **group's Actions → On Init**: creates the `BGICHub` named global frame
  once (server-time helpers, locked config defaults, empty state stores, `BGIC` addon prefix
  with a no-op receiver). Foundation for v2 (timestamps → teammate tracking → multi-witness
  corroboration; see `.plans/bg-item-callout/`). Decisions locked: announce ally use in BG
  chat, Structure A (hub + 10 children), on-demand corroboration reports, `minWitnesses = 2`.
  Added `BGICHub` to `.luacheckrc` globals. The 10 children are untouched — enemy callouts
  behave exactly as v1. Rebuilt `export.txt`, regenerated `aura.json`, decode→encode→decode
  **lossless**. Lua 5.1 syntax OK. **Pending in-game test** (confirm no error on group init).
- 2026-09-03 — **Refactor: harden the load gate + correct the review.** Every child already
  loaded only in an Instance Type = Battleground (`size = pvp`) at level `< 20`; **mirrored
  that gate onto the group container** so it's explicit at the group level and the group
  unloads entirely outside a BG / at level 20+. Corrected the docs: the earlier "no load
  gate" note was wrong (it read only the group `load`), and the `_AURA_REMOVED` "AGM down"
  behavior is intentional/accurate (fires when the shield ends for any reason; AGM's absorb
  isn't magic-dispellable). Rebuilt `export.txt`, regenerated `aura.json`, decode→encode→decode
  **lossless**.
- 2026-09-03 — **Refactor: remove dead `spellName` config.** Stripped the inert
  `spellName = "Goblin Sapper Charge"` / `use_spellName = false` pair from all 10
  combat-log triggers (20 keys) — it was never evaluated (detection is `use_spellId`).
  `spellId` and every other field unchanged. Rebuilt `export.txt`, regenerated `aura.json`,
  decode→encode→decode **lossless**.
- 2026-09-03 — **Refactor: rename to `Betty's BG Item Callout (19 bracket)`** (was
  `Devmind's …`). Changed only the group `d.id`; children carry no `parent`/`controlledChildren`
  references (transmission format — the `c` array defines the group), so no child updates were
  needed. Credited Devmind as the original author in the description. Rebuilt `export.txt`,
  regenerated `aura.json`, decode→encode→decode **lossless**.
- 2026-09-03 — Initial import into the repo. Saved the shared string verbatim to
  `export.txt` (round-trip lossless), decoded `aura.json`, and extracted the shared `%c`
  class-color function to `code/custom_text.lua` (Lua 5.1 parse OK). Documented all six
  covered consumables (spell IDs verified on wowhead.com/classic), the hostile-source /
  spellId detection, `SMARTRAID` + `/say` announces, and iteration hooks (PvP load gate,
  coverage gaps, `_AURA_REMOVED` expiry false-positive, Magic Dust ID check, inert
  `spellName`). No behavior changes. **Pending in-game test** (and `luacheck`).
