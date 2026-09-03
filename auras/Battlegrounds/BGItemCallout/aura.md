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
- **Match:** `use_spellId = true` on the spellId above (`use_spellName = false` — the
  `spellName = "Goblin Sapper Charge"` present on every trigger is inert leftover template
  data and is **not** evaluated).
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

No custom triggers, conditions, or action code — detection and messaging are all built in
the WA UI (the children's action `custom` boxes are enabled but empty).

## Known quirks / iteration hooks

- **No load gate.** The group loads everywhere (empty `load`), so it also fires in the open
  world / dungeons whenever a hostile unit uses these items. A `Load → Instance type = PvP`
  restriction would confine it to battlegrounds (same pattern used to gate PriestCooldowns'
  Fade).
- **Coverage gaps for a 19 kit** — notably missing **Free Action Potion** (6615, stun/root
  immunity), stun grenades (Thermal/Iron Grenade), and Net-o-Matic (13099). Each would be a
  cloned child.
- **`_AURA_REMOVED` false positives** — "AGM down" fires on the shield's natural 20 s expiry
  too, not only on an actual dispel.
- **Magic Dust (1090)** — wowhead maps 1090 to the mage Sleep line; confirm in-game that
  Magic Dust's on-use logs 1090, or it may never fire.
- **Inert `spellName` leftovers** on every trigger — harmless but worth clearing.

## Testing notes

1. Import `export.txt`; enter a BG, no Lua error on load.
2. Have an enemy use a Swiftness Potion → `Swiftness Potion used by <Name>` posts to
   party/raid; if they're within 40 yd, the `DISPEL` `/say` also fires. Name shows in class
   color.
3. Enemy pops the Arena Grand Master trinket → AGM callout; when the shield drops, `AGM
   down on <Name>` fires (note: also on natural expiry).
4. Confirm nothing fires for **friendly** uses (hostile-source filter).
5. Confirm Magic Dust actually triggers (see quirk above).

## Changelog

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
