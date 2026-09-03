# Betty's BG Item Callout (19 bracket)

A level-19 twink **battleground enemy-item callout**. Refactored from **Devmind's**
original BG Item Callout — the detection, spell IDs, and announce behavior are Devmind's
work; this repo copy renames it to the `Betty's` family and cleans up the aura (dead
config removed, load gate hardened, docs). Watches the combat log for a fixed
set of high-impact BG consumables/trinkets used by **hostile** players, then announces
who used what — to your party/raid (`SMARTRAID`) and, for the priority "dispel this"
items, to local `/say` when the enemy is within 40 yd. Every callout shows the enemy's
name in their **class color**. **v2 (Phase 2) also calls out *allies*** who use the
tracked consumables — detected in the `BGICHub` hub, announced to BG chat tagged `(ally)`,
with your own casts excluded — for no-consume-premade accountability. The AGM trinket is
enemy-only (equipment, not a no-consume item).

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
passes a Lua 5.1 parse. The **Phase 3a corroboration logic** in `code/init.lua` is exercised by a
headless harness — `tools/test/` loads the real `init.lua` under a Lua VM (fengari) with the WoW
API stubbed and asserts bucket keying + ±1 tolerance, send-once dedupe, self/AGM/schema/untracked
filters, the ally-announce subset, sender-based witness dedup, per-match wipe, and pvp gating (run
`npm test` in `tools/`; 33 assertions). That covers the **pure logic**; the remaining **in-game**
unknowns (real spellIds firing, `sender` unspoofability in practice, `INSTANCE_CHAT` delivery
scope, `WINDOW` tuning) are **not yet tested in-game** — this repo cannot run WoW.

## Purpose

In the 19 bracket a handful of engineering gadgets, potions, and the Arena Grand Master
trinket swing fights hard. This aura turns each **enemy** use into a chat callout so the
team can react (dispel a Swiftness Potion, focus a shielded target, etc.). Enemy detection is
by **spell ID** with a **hostile-source** filter on the 10 children, so those callouts only
fire on enemies. **v2 Phase 2** adds a parallel **ally** path in the hub: it watches the same
combat log for **friendly** casts of the five true consumables (Swiftness, Leper Gnome, Rocket
Boots, Resistance, Magic Dust), **excludes your own casts** (`AFFILIATION_MINE`), and announces
them tagged `(ally)`. The children never touch allies and the hub never touches enemies, so
there is no double-announce.

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

- **Base children** → `message_type = SMARTRAID` (e.g. `[%c] Swiftness Potion used by
  %1.sourceName`) — party/raid/instance chat, no range limit.
- **`-Say` children** → `message_type = SAY` (e.g. `[%c] Swiftness Potion used! - DISPEL
  %1.sourceName`, `[%c] AGM trinket used! - DISPEL %1.sourceName`, `[%c] AGM down on
  %1.sourceName`) — local `/say`, gated by the 40 yd range check.
- **Timestamp (v2 Phase 1, 2026-09-03).** Every message is prefixed with `[%c]`, where `%c`
  is a per-child **`actions.start.message_custom`** function returning the **server-synced**
  `HH:MM:SS` (`BGICHub.stamp()` → `GetServerTime()`; falls back to local `date()` if the hub
  isn't up). Purely additive — the `message_type` channel and the `%1.sourceName` replacement
  are unchanged, so the only behavior change is the leading timestamp. Full `m/d/y` is reserved
  for the stored log/report (Phase 4), per the locked decisions.
- **Ally callouts (v2 Phase 2, 2026-09-03).** The hub (`code/init.lua`) announces **friendly**
  consumable use itself — it does **not** go through the children. Format mirrors the enemy
  `SMARTRAID` line plus an `(ally)` tag: `[HH:MM:SS] Swiftness Potion used by <Ally> (ally)`,
  routed via a `SMARTRAID`-equivalent channel picker (`INSTANCE_CHAT` in a BG). Only the five
  true consumables get ally callouts; **AGM (23506) is excluded**; **your own casts are excluded**
  (`AFFILIATION_MINE`). The wording per item mirrors the enemy child's `message` text (so
  spellId 4060 reads "Leper Gnome used by …" to match child #3, regardless of the item table
  label below).

## Custom code

- `code/custom_text.lua` — the `%c` display function, **identical in all 10 children**.
  Resolves the caster's class + name from `GetPlayerInfoByGUID(state.sourceGUID)` and
  returns the name wrapped in the class color (`RAID_CLASS_COLORS`), falling back to the raw
  `sourceName` when the GUID isn't a cached player.
- `code/init.lua` — **the `BGICHub` hub** (added v2 Phase 0, extended v2 Phase 2 + Phase 3a,
  2026-09-03), pasted into the **group's Actions → On Init**. Creates the `BGICHub` named global
  frame once (children don't share `aura_env`, so cross-child state needs a named global — same
  mechanism as `WSGCalloutHub`): server-time helpers (`GetServerTime`), locked config defaults,
  state stores, and the `BGIC` addon prefix. **Phase 2** added the **ally path**: `refreshZone()`
  arms `COMBAT_LOG_EVENT_UNFILTERED` only inside a BG (`IsInInstance() == "pvp"`), and
  `onCombatLog()` matches non-self `SPELL_CAST_SUCCESS` of the tracked items, skips
  `AFFILIATION_MINE`, and `SendChatMessage`s the `(ally)` callout for the five items in
  `NS.allyAnnounce` (AGM excluded) via `smartChannel()`. **Phase 3a** added the **corroboration
  engine** (runs **silently** — no visible chat change): the six watched IDs now live in
  `NS.trackedItems` (was `NS.allyItems`), with `NS.allyAnnounce` the five-item announce subset.
  Every non-self sighting (enemy **or** ally) is recorded and broadcast once on the `BGIC` addon
  bus (`witnessLocal` → `broadcast`, payload `schema|EVT|guid|spellId|serverTime|reactionChar|name`,
  ≤255 chars, `INSTANCE_CHAT`). Incoming attestations (`onAddon`) are aggregated into a per-event
  **witness set** keyed by `casterGUID|spellId|serverTimeBucket` (`resolveKey`, `NS.WINDOW = 4` s
  with ±1-bucket tolerance). The trusted witness identity is the **server-stamped `sender`** of
  `CHAT_MSG_ADDON` (unspoofable) — the payload's name/reaction are display-only. State
  (`NS.seen/witnesses/events/log`) is wiped per match on `PLAYER_ENTERING_WORLD`. Toggle
  `BGICHub.cfg.debug = true` to watch the ledger build. The live witness-count tag + announce
  election are Phase 3b; the on-demand report that surfaces the ledger is Phase 4. The 10 children
  are still untouched — enemy callouts are 100% as-was.
- `code/message_custom.lua` — **v2 Phase 1** (added 2026-09-03), the `%c` **chat-message**
  function pasted into each child's Send Chat Message → Message (stored in
  `actions.start.message_custom`), **identical in all 10 children**. Returns the server-synced
  `HH:MM:SS` timestamp via `BGICHub.stamp()` (local-time fallback). This is the message `%c`,
  distinct from the display `%c` in `custom_text.lua`.

**Enemy** detection is still all built in the WA UI (the 10 children). **Ally** detection is now
custom Lua in the hub (`init.lua`). Executable custom code today: the `%c` display-text function
(`custom_text.lua`), the `%c` chat-message timestamp function (`message_custom.lua`), and the hub
(`init.lua`, now including the ally combat-log path). The children's action `custom` boxes (On
Show custom Lua) remain enabled but empty — enemy announces still use the built-in Send Chat
Message; ally announces are sent by the hub via `SendChatMessage`.

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
4. Confirm the **enemy children** never fire on friendly uses (hostile-source filter) — ally
   use is handled separately by the hub (item 8), not the children.
5. Confirm Magic Dust actually triggers (see quirk above).
6. **Hub scaffold (v2 Phase 0):** after import, load a BG and confirm no Lua error on group
   init; `/run print(BGICHub)` returns a frame and `/run print(BGICHub.now())` prints a server
   epoch. Behavior must be **unchanged** from v1 (hub is inert — enemy callouts only).
7. **Timestamps (v2 Phase 1):** trigger any callout and confirm the chat line is prefixed with
   the current time, e.g. `[21:14:07] Swiftness Potion used by <Name>`, on the same channel as
   before (SMARTRAID / `/say`). If `BGICHub` failed to init, the time still shows (local-time
   fallback). Confirm the time matches other players' clients (server-synced).
8. **Ally callouts (v2 Phase 2):** in a BG, have a **teammate** use a tracked consumable
   (Swiftness / Leper Gnome / Rocket Boots / Resistance / Magic Dust) → BG chat posts
   `[HH:MM:SS] <Item> used by <Ally> (ally)`. Verify: (a) **your own** use of the same item
   posts **nothing** (`AFFILIATION_MINE` excluded); (b) an ally **AGM** trinket posts nothing
   (AGM is enemy-only); (c) the ally line lands in the same channel as enemy `SMARTRAID` calls
   (BG/`INSTANCE_CHAT`) — if it doesn't, adjust `NS.smartChannel()`; (d) nothing fires outside a
   BG (the watch only arms on `IsInInstance() == "pvp"`); (e) enemy callouts are unchanged.
9. **Corroboration engine (v2 Phase 3a):** set `/run BGICHub.cfg.debug = true`. With **two**
   BGIC users in the same BG, have any tracked consumable used by a **third** player (enemy or
   ally). Verify: (a) each user prints `BGIC <reaction> <item> by <caster> — witnesses: 1` for
   their own sighting, then `BGIC +witness <otherUser> … — witnesses: 2` when the other user's
   addon message arrives; (b) `/run print(BGICHub.witnessCount(next(BGICHub.witnesses)))` reports
   the expected count; (c) the ledger resets on zone-in (`BGICHub.log` empties). Confirm the
   `sender` shown is the real caster's account name (server-stamped) and that no visible chat line
   changed (3a is silent). Tune `BGICHub.WINDOW` if witnesses' detection times split an event.

## Changelog

- 2026-09-03 — **v2 Phase 3a: multi-witness corroboration engine (silent).** Extended
  `code/init.lua` (the `BGICHub` hub) with the anti-forgery corroboration ledger. Renamed
  `NS.allyItems` → `NS.trackedItems` (now the six watched IDs, used for both enemy and ally
  corroboration) and added `NS.allyAnnounce` (the five-item ally-announce subset, unchanged
  behavior). `onCombatLog()` now folds **every non-self sighting** (enemy or ally) into the ledger
  via `witnessLocal()`, which records the event, adds ourselves as a witness, and `broadcast()`s
  once per event on the `BGIC` addon bus (payload `schema|EVT|guid|spellId|serverTime|reactionChar|
  name`, ≤255 chars, `INSTANCE_CHAT`). Incoming attestations (`onAddon` via `CHAT_MSG_ADDON`) are
  aggregated into a witness set keyed by `casterGUID|spellId|serverTimeBucket` (`resolveKey`,
  `NS.WINDOW = 4` s, ±1-bucket tolerance); the trusted identity is the **server-stamped `sender`**
  (unspoofable) — payload name/reaction are display-only. State (`seen/witnesses/events/log`) wipes
  per match on `PLAYER_ENTERING_WORLD`. Runs **silently** (no chat change); `BGICHub.cfg.debug =
  true` prints the ledger building. Deferred: live witness-count tag + announce election (Phase 3b),
  presence census (Phase 3c), on-demand report (Phase 4). No new `.luacheckrc` globals needed
  (`strsplit`, `UnitName`, `math`, `print`, `C_ChatInfo` already allowlisted). Rebuilt `export.txt`,
  regenerated `aura.json`, decode→encode→decode **lossless** (10 children intact). Lua 5.1 syntax
  OK; free globals all allowlisted. **Pending in-game test** (see testing note 9 — esp. `sender`
  unspoofability, `INSTANCE_CHAT` addon delivery scope, and `WINDOW` bucket tuning).
- 2026-09-03 — **v2 Phase 2: ally callouts (announce friendly consumable use).** Extended
  `code/init.lua` (the `BGICHub` hub) with an ally-only combat-log path: `refreshZone()` arms
  `COMBAT_LOG_EVENT_UNFILTERED` only inside a battleground, and `onCombatLog()` announces
  **friendly** `SPELL_CAST_SUCCESS` of the five consumables (`NS.allyItems`: Swiftness 2379,
  Leper Gnome 4060, Rocket Boots 8892, Resistance 2380, Magic Dust 1090) to BG chat tagged
  `(ally)`, **excluding your own casts** (`AFFILIATION_MINE`) and **excluding AGM** (23506,
  equipment not a no-consume item). Ally wording mirrors the enemy child `message` text; channel
  via a `SMARTRAID`-equivalent `smartChannel()` (`INSTANCE_CHAT` in a BG). Architecture: the ally
  path lives entirely in the hub — the 10 enemy children are **untouched** (no widened filters,
  no self-exclusion needed, no nonsensical ally `DISPEL`/`AGM down` calls), so enemy callouts are
  100% as v1 and there is no double-announce. Added `COMBATLOG_OBJECT_REACTION_FRIENDLY`,
  `COMBATLOG_OBJECT_AFFILIATION_MINE`, and `LE_PARTY_CATEGORY_INSTANCE` to `.luacheckrc`
  read_globals. Rebuilt `export.txt`, regenerated `aura.json`, decode→encode→decode **lossless**.
  Lua 5.1 syntax OK; free globals all allowlisted. **Pending in-game test** (esp. the
  `smartChannel()` routing and self/AGM exclusions — see testing note 8).
- 2026-09-03 — **v2 Phase 1: server-synced timestamps on every callout.** Added
  `code/message_custom.lua` and wired a `%c` chat-message function into all 10 children's Send
  Chat Message (`actions.start.message_custom`), prefixing each message with `[%c]` →
  `[HH:MM:SS]` from `BGICHub.stamp()` / `GetServerTime()` (local-time fallback). Chose the
  message-`%c` mechanism over a custom-code announce rewrite: it's purely additive — channel
  (`message_type`) and `%1.sourceName` are untouched, so the only change is the leading
  timestamp. Field name `message_custom` verified against the WeakAuras2 source
  (`WeakAuras.lua`: `LoadFunction("return "..actions.start.message_custom)`). Rebuilt
  `export.txt`, regenerated `aura.json`, decode→encode→decode **lossless**. Lua 5.1 syntax OK.
  **Pending in-game test.**
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
