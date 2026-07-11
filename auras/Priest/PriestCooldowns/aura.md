# Dwarf Priest Cooldowns

| Field | Value |
|---|---|
| **Display name** | `Dwarf Priest Cooldowns` |
| **Category / folder** | `Priest` |
| **Target flavor(s)** | Classic Era (uses legacy `GetSpellInfo`/`GetSpellCooldown`/`GetItemCooldown`) |
| **Min WeakAuras version** | 5.x |
| **wago URL** | n/a |
| **wago version** | n/a |
| **Region type** | `dynamicgroup` of 9 `icon` children |

## Purpose

A centered horizontal row of the cooldowns a level 60 Dwarf Priest cares about, each an icon
with a live cooldown swipe + numeric countdown. Built for a **30 Holy / 21 Disc** build but
self-tailoring. Left → right:

1. **Fade** — threat drop
2. **Psychic Scream** — AoE fear / escape
3. **Fear Ward** (Dwarf racial) — anti-fear
4. **Desperate Prayer** (Dwarf racial) — emergency instant heal
5. **Stoneform** (Dwarf racial) — cleanse bleed/poison/disease + armor
6. **Inner Focus** (Discipline talent) — free + crit next spell
7. **Mind Blast** — hidden unless the character is a **Shadow build** (knows Shadowform)
8. **Major Mana Potion** (item) — shows only while carried
9. **Mana Rune** (item) — Dark or Demonic, whichever is carried

It's a **dynamic group** (`grow = HORIZONTAL`, `space = 0`), so any icon that hides — an
untalented spell, a not-carried item, Mind Blast on a non-Shadow build — collapses out and the
remaining icons stay flush and centered with no gap. For the reference 30/21 build carrying mana
potions + a rune, **8 icons** show (Mind Blast hidden).

## Triggers

Each icon is a **Custom ▸ Trigger State Updater** (one `""` state) — the same proven pattern as
*Betty's Trinket Display* / *Paladin Cooldowns*, reading cooldowns directly rather than via a
native Cooldown Progress trigger. The `dur > 1.5` guard filters the global cooldown; the numeric
countdown is WA's built-in icon cooldown text (`cooldownTextDisabled = false`).

- **Plain spell icons (6):** `GetSpellCooldown(name)` / `GetSpellInfo(name)`, tracked **by name**.
  By-name resolves the highest known rank automatically (Classic's per-rank spell IDs are the #1
  "aura won't fire" bug) and returns nil when the spell isn't in the spellbook — which hides
  untalented (Inner Focus) or wrong-race (racials) icons.
  Events: `SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD`.
  Reference IDs (comment-only, not used by the logic): Fade
  [586](https://www.wowhead.com/classic/spell=586), Psychic Scream
  [8122](https://www.wowhead.com/classic/spell=8122), Fear Ward
  [6346](https://www.wowhead.com/classic/spell=6346), Desperate Prayer
  [13908](https://www.wowhead.com/classic/spell=13908), Stoneform
  [20594](https://www.wowhead.com/classic/spell=20594), Inner Focus
  [14751](https://www.wowhead.com/classic/spell=14751).
- **Mind Blast icon (1, Shadow-gated):** same by-name logic, but first checks
  `GetSpellInfo("Shadowform")` — if the character doesn't know Shadowform it stays hidden, so the
  icon only appears on a real Shadow build (and pops into the row automatically after a respec).
  Reference IDs: Mind Blast [8092](https://www.wowhead.com/classic/spell=8092), gate spell
  Shadowform [15473](https://www.wowhead.com/classic/spell=15473).
- **Item icons (2, possession-gated):** `GetItemCooldown` (flavor-aware `C_Container`/`C_Item`
  fallback) with art from `GetItemIcon`. Both first check `GetItemCount` and **hide when you carry
  none** (avoids a phantom icon painting the shared potion category CD when you have zero). Major
  Mana Potion = item [13444](https://www.wowhead.com/classic/item=13444). The Mana Rune icon scans
  `{ Dark Rune 20520, Demonic Rune 12662 }` and shows whichever you carry.
  Events: `BAG_UPDATE_COOLDOWN SPELL_UPDATE_COOLDOWN BAG_UPDATE PLAYER_ENTERING_WORLD`.

## Custom code

- `code/tsu_spell.lua` — shared TSU pasted into the six plain spell icons; only the
  `name = "..."` line changes per icon (Fade / Psychic Scream / Fear Ward / Desperate Prayer /
  Stoneform / Inner Focus).
- `code/tsu_mindblast.lua` — the Shadowform-gated Mind Blast icon.
- `code/tsu_item.lua` — the possession-gated Major Mana Potion icon (change `ITEM_ID` for a
  different potion).
- `code/tsu_rune.lua` — the Dark/Demonic mana-rune picker icon.

No Init/Show/Hide/Condition code — the cooldown swipe animates itself once a state has
`duration` + `expirationTime`.

## Cooldowns (Classic Era — verified 2026-07-11)

Durations are read **live** from `GetSpellCooldown`/`GetItemCooldown`, so the on-icon number
is always whatever the game reports; these are the reference values used to sanity-check the
design (Wowhead Classic + Wowpedia):

| Icon | Cooldown | Notes |
|---|---|---|
| Fade | 30 s | 10 s threat-drop |
| Psychic Scream | 30 s | base (Improved Psychic Scream — Shadow — would lower it) |
| Fear Ward | 30 s | **Era keeps the 1.x value** (10-min ward); TBC 2.3.0 changed it to a 3-min CD |
| Desperate Prayer | 10 min | instant, off-GCD emergency heal |
| Stoneform | 3 min | 8 s active |
| Inner Focus | 3 min | Discipline talent |
| Mind Blast | 8 s (5.5 s w/ 5/5 Improved Mind Blast) | Shadow-only; short CD blinks in the row |
| Major Mana Potion | 2 min | shared combat-**potion** category |
| Mana Rune (Dark/Demonic) | 2 min | **separate** category from potions — chainable with a potion |

Design checks: the `dur > 1.5` GCD guard is safe — the shortest real CD (Mind Blast, 8 s / 5.5 s
talented) clears it. Because potions and runes are on **independent** 2-min cooldowns, having both
the Mana Potion and Mana Rune icons is meaningful (each shows its own timer; a potion doesn't
grey out the rune and vice-versa).

## Testing notes

- Import `export.txt`, drag the group where you want it, then cast each ability / drink a potion /
  use a rune — the swipe + number should appear over the matching icon.
- On the 30/21 build the **Mind Blast** slot should be absent (no Shadowform); respec Shadow and
  it should appear. Empty bags → the **Mana Potion / Rune** slots should collapse out.
- **Power Infusion** (needs 30 pts Disc) and **Silence** (Shadow) are intentionally omitted for
  this build; add spell icons for them if you respec.
- Spell/item **names are enUS**; non-English clients need the localized names in each TSU.

## Changelog

- 2026-07-11 — Initial version. Dynamic group of 9 cooldown icons (fabricated export,
  round-trip-verified lossless; cloned from the Paladin Cooldowns group/icon + TSU pattern):
  Fade (586), Psychic Scream (8122), Fear Ward (6346), Desperate Prayer (13908), Stoneform
  (20594), Inner Focus (14751), Mind Blast (8092, Shadowform-gated), Major Mana Potion (13444),
  Mana Rune (Dark 20520 / Demonic 12662). Spells by name; items possession-gated; horizontal
  flush layout collapses hidden icons.
- 2026-07-11 — Verify cooldown durations against Classic Era (Wowhead/Wowpedia) and record them:
  Fade/Psychic Scream/Fear Ward 30s, Desperate Prayer 10 min, Stoneform/Inner Focus 3 min, Mind
  Blast 8s (5.5s talented), Major Mana Potion 2 min, Mana Rune 2 min (separate category from
  potions). No code change — durations are read live; GCD guard confirmed safe.
