# Dwarf Priest Cooldowns

| Field | Value |
|---|---|
| **Display name** | `Dwarf Priest Cooldowns` |
| **Category / folder** | `Priest` |
| **Target flavor(s)** | Classic Era (uses legacy `GetSpellInfo`/`GetSpellCooldown`/`GetItemCooldown`) |
| **Min WeakAuras version** | 5.x |
| **wago URL** | n/a |
| **wago version** | n/a |
| **Region type** | `dynamicgroup` of 10 `icon` children |

## Purpose

A centered horizontal row of the cooldowns a level 60 Dwarf Priest cares about, each an icon
with a live cooldown swipe + numeric countdown. Built for a **30 Holy / 21 Disc** build but
self-tailoring. Left → right:

1. **Power Word: Shield** — 4 s spell cooldown + Weakened Soul re-shield lockout (see Triggers)
2. **Fade** — threat drop
3. **Psychic Scream** — AoE fear / escape
4. **Fear Ward** (Dwarf racial) — anti-fear
5. **Desperate Prayer** (Dwarf racial) — emergency instant heal
6. **Stoneform** (Dwarf racial) — cleanse bleed/poison/disease + armor
7. **Inner Focus** (Discipline talent) — free + crit next spell
8. **Mind Blast** — hidden unless the character is a **Shadow build** (knows Shadowform)
9. **Major Mana Potion** (item) — shows only while carried
10. **Mana Rune** (item) — Dark or Demonic, whichever is carried

It's a **dynamic group** (`grow = HORIZONTAL`, `space = 0`), so any icon that hides — an
untalented spell, a not-carried item, Mind Blast on a non-Shadow build — collapses out and the
remaining icons stay flush and centered with no gap. For the reference 30/21 build carrying mana
potions + a rune, **9 icons** show (Mind Blast hidden).

## Triggers

Each icon is a **Custom ▸ Trigger State Updater** (one `""` state) — the same proven pattern as
*Betty's Trinket Display* / *Paladin Cooldowns*, reading cooldowns directly rather than via a
native Cooldown Progress trigger. The `dur > 1.5` guard filters the global cooldown; the numeric
countdown is WA's built-in icon cooldown text (`cooldownTextDisabled = false`).

- **Power Word: Shield icon (1, readiness):** PW:S has two re-cast limiters in Classic Era — a real
  **4 s spell cooldown** (`GetSpellCooldown`, applies to any target) and the **Weakened Soul** debuff
  (~15 s) that blocks re-shielding the *same* unit. The icon shows PW:S art (`GetSpellInfo`) and
  paints whichever ends **later**: the 4 s cooldown always, plus the 15 s Weakened Soul window when
  you shield *yourself* (it scans `UnitDebuff("player", i)` for `"Weakened Soul"`). Self-hides if PW:S
  isn't known. Because Weakened Soul lands on the *target*, the longer 15 s window reflects **self**
  -shields only — shielding a party member shows just the 4 s spell cooldown.
  Events: `SPELL_UPDATE_COOLDOWN UNIT_AURA:player PLAYER_ENTERING_WORLD LEARNED_SPELL_IN_TAB`.
  Reference IDs: Power Word: Shield [17](https://www.wowhead.com/classic/spell=17), Weakened Soul
  [6788](https://www.wowhead.com/classic/spell=6788).
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

- `code/tsu_pwshield.lua` — the Power Word: Shield icon (4 s spell CD + Weakened Soul self-lockout).
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
| Power Word: Shield | 4 s CD, +~15 s (Weakened Soul) | 4 s spell CD (any target); Weakened Soul blocks re-shielding the same unit — shows the longer of the two |
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
- Cast **Power Word: Shield on yourself** — the PW:S icon should paint the ~15 s Weakened Soul swipe
  and clear when it fades. Shielding a *party member* shows only the 4 s spell cooldown (Weakened
  Soul lands on them, not you).
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
- 2026-07-11 — Add Power Word: Shield (17) as the new leftmost icon; row is now 10 icons. Tracks the
  Weakened Soul (6788) self-lockout via `UnitDebuff` on the player (~15 s until you can re-shield
  yourself). Re-exported (round-trip lossless).
- 2026-07-11 — Fix: PW:S DOES have a real 4 s spell cooldown in Classic Era. TSU now reads
  `GetSpellCooldown("Power Word: Shield")` too and shows the longer of the 4 s CD (any target) and
  the ~15 s Weakened Soul window (self-shields); added `SPELL_UPDATE_COOLDOWN` to the events box.
  Re-exported (round-trip lossless).
- 2026-07-11 — Flip cooldown swipe direction (`inverse = true`) on all 10 icons so the dark
  overlay starts full and clears as the cooldown counts down (was filling in). Re-exported.
- 2026-07-11 — Fix the ready (off-CD) state painting a full dark swipe: the TSU no longer emits a
  `static` value=1/total=1 progress when ready (WA rendered that as a 100% swipe, dark under
  `inverse`). Ready now emits a zero-duration `timed` state that draws no swipe, so idle icons stay
  bright. Re-exported.
