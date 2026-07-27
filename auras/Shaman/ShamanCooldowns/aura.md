# Betty's 19 Shaman Cooldowns

| Field | Value |
|---|---|
| **Display name** | `Betty's 19 Shaman Cooldowns` |
| **Category / folder** | `Shaman` |
| **Target flavor(s)** | Classic Era / SoD / Hardcore (legacy `GetSpellInfo`/`GetSpellCooldown`/`GetItemCooldown`/`GetTotemInfo`) |
| **Race** | Tauren (War Stomp) |
| **Min WeakAuras version** | 5.x |
| **wago URL** | n/a |
| **wago version** | n/a |
| **Region type** | parent `group` → **Tier 1** `dynamicgroup` (5 full-size 40px icons, y 0) + **Tier 2** `dynamicgroup` (2 × 24px icons, y −44) + **Slots** `dynamicgroup` (2 × 20px slot dots, y −74) — all three sub-rows grow `HORIZONTAL` (centered) so they line up under Tier 1 |
| **Load conditions** | `class == SHAMAN` **and** `level == 19` (applied to every region, since children load independently) |
| **export.txt** | **Fabricated + round-trip-verified lossless** (cloned from the Paladin/Priest `dynamicgroup` shapes; `tools/decode.js` reproduces the same tree). **Imported in-game once (v1)**; layout re-centered/re-spaced in v2 — re-import and re-verify per the testing notes. |

## Purpose

A cooldown/utility display for a **level 19 twink Tauren Shaman**, mirroring *Betty's 19
Paladin Cooldowns* / *Dwarf Priest Cooldowns*. A 19 Shaman's kit is mostly totems, and on
this client the relevant totems carry **real recast cooldowns** (Earthbind 15s, Fire Nova
15s, Stoneclaw 30s — tooltip-verified in-game). The display uses a **two-tier visual
hierarchy** plus slot dots:

**Tier 1 — primary row (full size), left → right:**
1. **War Stomp** (racial) — 120 s stun. Self-hides on non-Tauren.
2. **Earth Shock** — 6 s shock CD (shared with Flame Shock); interrupt/burst readiness.
3. **Earthbind Totem** — 15 s recast CD; the *only* snare (no Frost Shock / Ghost Wolf at 19).
4. **Healing Potion** (item 929, req level 12) — ~2 min, collapses when not carried.
5. **Big Bronze Bomb** (item 4380) — Engineering AoE stun, ~1 min, collapses when not carried.

**Tier 2 — totem sub-row (24px, anchored below Tier 1, centered):** low-priority totem CDs
demoted by size, not behavior.
6. **Fire Nova Totem** — 15 s CD (5 s fuse AoE).
7. **Stoneclaw Totem** — 30 s CD (body-block / eat a cast).

**Slot dots (small, appear only while a totem is planted):** two icons that mirror the **Fire
slot** (`GetTotemInfo(1)`) and **Earth slot** (`GetTotemInfo(2)`) — each shows *whatever* totem
currently occupies that slot, with its own icon and remaining-lifetime swipe. Because a 19 only
has a Fire and an Earth slot (one totem each), these two dots cover the entire totem kit with no
name list to maintain: Stoneskin, Strength of Earth, Earthbind, Stoneclaw, Tremor (Earth) and
Searing, Fire Nova (Fire) all light the right dot automatically the moment they're planted.

**"Planted" glow:** the three totem CD icons (Earthbind, Fire Nova, Stoneclaw) **glow while
that totem is physically down** (Condition ▸ Custom Check ▸ Glow). One icon then carries two
facts: swipe = when you can re-drop it, glow = it's currently active. (The glow and the slot
dot are complementary: the glow flags *this specific CD totem is up*, the slot dot shows *what's
in each slot right now* — including totems with no CD icon.)

All three sub-rows are **dynamic groups**, so item/slot icons that hide collapse out and the row
stays flush.

## Triggers

Every icon is a **Custom ▸ Trigger State Updater** (one `""` state), the proven pattern from
the Paladin/Priest rows. `dur > 1.5` filters the GCD; the numeric countdown is WA's built-in
icon cooldown text (`cooldownTextDisabled = false`); swipe `inverse = true` (dark clears as it
counts down) on the CD icons.

- **CD icons (Tier 1 #1–3 + Tier 2 #6–7):** `code/tsu_spell.lua`, tracked **by name**
  (`GetSpellInfo` / `GetSpellCooldown`). By-name is rank-proof and returns nil when unknown
  (War Stomp self-hides on non-Tauren). Earthbind/Fire Nova/Stoneclaw need no special code —
  they report real recast CDs, so the same TSU drives them.
  Events: `SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD`
  (the three totem CD icons additionally carry `PLAYER_TOTEM_UPDATE` so their glow tracks
  drop/expire).
  Reference IDs (comment-only): War Stomp [20549](https://www.wowhead.com/classic/spell=20549),
  Earth Shock [8042](https://www.wowhead.com/classic/spell=8042), Earthbind Totem
  [2484](https://www.wowhead.com/classic/spell=2484), Fire Nova Totem
  [1535](https://www.wowhead.com/classic/spell=1535), Stoneclaw Totem
  [5730](https://www.wowhead.com/classic/spell=5730).
- **Item icons (Tier 1 #4–5):** `code/tsu_item.lua`, `GetItemCooldown` (flavor-aware
  `C_Container`/`C_Item` fallback) + `GetItemIcon`. Healing Potion 929, Big Bronze Bomb 4380.
  Events: `BAG_UPDATE_COOLDOWN SPELL_UPDATE_COOLDOWN BAG_UPDATE PLAYER_ENTERING_WORLD`.
- **Slot dots (Fire slot, Earth slot):** `code/tsu_totem_slot.lua`, reads a single fixed
  `GetTotemInfo(SLOT)` (Fire = 1, Earth = 2) and shows that slot's current totem icon + remaining
  lifetime while occupied; hides when empty. Only the `SLOT` line changes per icon. Slot-driven
  (not name-matched), so it reflects *any* totem a 19 drops — Stoneskin included.
  Events: `PLAYER_TOTEM_UPDATE PLAYER_ENTERING_WORLD`.

## Conditions

- **`code/conditions.lua`** — a **Custom Check** on each of the three totem CD icons
  (Earthbind / Fire Nova / Stoneclaw); change is **Glow**. Returns true while that totem is
  physically planted (`GetTotemInfo` scan). Add `PLAYER_TOTEM_UPDATE` to the condition's
  check-on events so the glow tracks drop/expire. Only the `name` line changes per icon.

## Custom code

- `code/tsu_spell.lua` — shared by-name spell-CD TSU. Pasted into all 5 CD icons; only the
  `name = "..."` line changes (War Stomp / Earth Shock / Earthbind Totem / Fire Nova Totem /
  Stoneclaw Totem).
- `code/tsu_item.lua` — shared item-CD TSU; only `ITEM_ID` (+ fallback name) changes (929 / 4380).
- `code/tsu_totem_slot.lua` — show-whatever-is-planted slot dot + remaining lifetime; only the
  `SLOT` line changes (1 = Fire slot / 2 = Earth slot).
- `code/conditions.lua` — the "totem planted" Custom Check for the Glow condition; only the
  `name` line changes (Earthbind / Fire Nova / Stoneclaw).

## Cooldowns (Classic Era — tooltip-verified in-game)

| Icon | CD | Physical duration |
|---|---|---|
| War Stomp | 120 s | — |
| Earth Shock | 6 s (shared w/ Flame Shock) | — |
| Earthbind Totem | 15 s | 45 s |
| Fire Nova Totem | 15 s | 5 s fuse |
| Stoneclaw Totem | 30 s | 15 s |
| Healing Potion (929) | ~2 min | — |
| Big Bronze Bomb (4380) | ~1 min | — |
| Fire/Earth slot dots | n/a | show planted totem + its remaining life |

`dur > 1.5` GCD guard is safe (shortest real CD is the 6 s shock).

## Not available at 19 (excluded by level)

**Frost Shock** (20), **Ghost Wolf** (20), Frostbrand Weapon (20), **Grounding Totem** (30),
Cure Disease (22). Frost Shock/Ghost Wolf being absent is *why* Earthbind is the only snare
and sits in the primary row.

## Testing notes

- The `export.txt` string is import-ready; just import it (no in-game skeletoning needed).
- Verify: War Stomp 120 s / Earth Shock 6 s / Earthbind + Fire Nova 15 s / Stoneclaw 30 s swipes
  paint; drop each totem and confirm the CD icon **glows** while its totem is down; the **slot
  dots** show whatever totem is in the Fire/Earth slot (Stoneskin, Strength of Earth, Tremor,
  Searing, etc.) with a depleting lifetime swipe; empty bags → the potion/bomb slots collapse
  out; on a non-Tauren the War Stomp slot collapses out.
- Load-gated to **Shaman, level == 19** — the whole aura hides on any other class or level. If you
  want it visible while leveling, switch the level check to `>= 19` or drop it.
- If totem glow/slot dots never fire, confirm `GetTotemInfo` is live on the client (it is on
  current Era/SoD/Cata/MoP; the old 1.13 stub needed LibTotemInfo).
- Spell/item **names are enUS** — non-English clients need localized names in each block. The slot
  dots are name-agnostic and work on any locale.
- After any change to `export.txt`, run `tools/decode.js` to regenerate `aura.json`.

## Changelog

- 2026-07-27 — v3 slot-driven totem dots. Replaced the two name-matched presence dots
  (Tremor/Searing) with two **slot** dots that mirror `GetTotemInfo(1)` (Fire) and
  `GetTotemInfo(2)` (Earth), showing whatever totem occupies each slot + its remaining lifetime.
  Fixes the "Stoneskin doesn't show" gap (and every future totem) with no name list — a 19 has
  only a Fire and an Earth slot, so two dots cover the whole kit. New `code/tsu_totem_slot.lua`;
  removed `code/tsu_totem_presence.lua`. Re-fabricated + round-trip verified lossless.
- 2026-07-27 — v2 layout + load gating (post first in-game import). Fixed the "messy" alignment:
  Tier 2 and the presence dots were `grow = RIGHT` (started at center, extended right → left-
  shifted); switched both to `grow = HORIZONTAL` so all three sub-rows center under Tier 1.
  Re-spaced vertically (Tier 1 y 0 / Tier 2 y −44 / slots y −74) and bumped dots 16 → 20px
  with `space` 4 → 6. Added load conditions `class == SHAMAN` and `level == 19` to every region
  (children load independently, so the gate is applied to all 13). Re-fabricated + round-trip
  verified lossless. Planted glow + CD swipes confirmed working in the v1 in-game test.
- 2026-07-27 — Fabricated `export.txt`. Built the transmission envelope programmatically by
  cloning the round-tripped Paladin/Priest `dynamicgroup` field shapes: parent static `group`
  → Tier 1 `dynamicgroup` (5 × 40px) + Tier 2 `dynamicgroup` (2 × 24px) + Presence
  `dynamicgroup` (2 × 16px dots), `v = 2000` (nested subgroups). Tier sizing is via child
  `width`/`height` (not `scale`). The three totem CD icons carry a WA glow subRegion
  (`subglow`) toggled by a `customcheck` condition on `sub.1.glow` (the `conditions.lua` scan),
  and their triggers gained `PLAYER_TOTEM_UPDATE` so the glow tracks drop/expire. Round-trip
  verified lossless (`encode.js` → `decode.js` reproduces the identical tree; `aura.json`
  regenerated). **Still needs an in-game import + test** — geometry/anchors were authored blind
  and will likely want dragging; the `subglow` field defaults are best-effort and should be
  eyeballed. If the glow doesn't paint on import, re-add it via Condition ▸ Custom Check ▸ Glow.
- 2026-07-27 — Initial build (code authored + linted; export pending in-game). Two-tier layout:
  primary row (War Stomp, Earth Shock, Earthbind 15s, Healing Potion 929, Big Bronze Bomb 4380)
  + smaller totem sub-row (Fire Nova 15s, Stoneclaw 30s), Tremor/Searing presence dots, and a
  "planted" glow on the three totem CD icons. Shared TSUs cloned from the Paladin/Priest rows;
  new `tsu_totem_presence.lua` + `conditions.lua` for the `GetTotemInfo` presence/glow. Added
  `GetTotemInfo`/`MAX_TOTEMS` to `.luacheckrc`.
