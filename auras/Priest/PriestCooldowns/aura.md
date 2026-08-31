# Priest Cooldowns

| Field | Value |
|---|---|
| **Display name** | `Priest Cooldowns` |
| **Category / folder** | `Priest` |
| **Target flavor(s)** | Classic Era (uses legacy `GetSpellInfo`/`GetSpellCooldown`/`GetItemCooldown`) |
| **Min WeakAuras version** | 5.x |
| **wago URL** | n/a |
| **wago version** | n/a |
| **Region type** | `dynamicgroup` of 12 `icon` children |

## Purpose

A centered horizontal row of the cooldowns a level 60 Priest cares about, each an icon
with a live cooldown swipe + numeric countdown. Built for a **30 Holy / 21 Disc** build but
self-tailoring — and **race-adaptive**: the Dwarf racials show for Dwarves, the Undead racial +
Devouring Plague show for Undead, and each hides on the other race. Left → right:

1. **Power Word: Shield** — 4 s spell cooldown + Weakened Soul re-shield lockout (see Triggers)
2. **Fade** — threat drop; **PvE-instance-only** (shows inside 5-man/raid dungeons, hidden in the open world and battlegrounds)
3. **Psychic Scream** — AoE fear / escape
4. **Fear Ward** (Dwarf racial) — anti-fear
5. **Desperate Prayer** (Dwarf racial) — emergency instant heal
6. **Stoneform** (Dwarf racial) — cleanse bleed/poison/disease + armor
7. **Will of the Forsaken** (Undead racial) — break/immune charm, fear, sleep
8. **Inner Focus** (Discipline talent) — free + crit next spell
9. **Power Infusion** (Discipline talent) — deep-Disc cooldown; hidden unless **talented**
10. **Mind Blast** — hidden unless the character has **Mind Flay talented** (a real shadow investment)
11. **Devouring Plague** (Undead priest spell) — hidden until learned (trained lvl 20, Undead-only)
12. **Major Mana Potion** (item) — shows only while carried
13. **Mana Rune** (item) — Dark or Demonic, whichever is carried

It's a **dynamic group** (`grow = HORIZONTAL`, `space = 0`), so any icon that hides — an
untalented spell (Inner Focus, Power Infusion), a not-carried item, Mind Blast without Mind Flay,
Fade outside a PvE instance, a wrong-race racial — collapses out and the remaining icons stay flush
and centered with no gap. For the reference 30/21 **Dwarf** build carrying mana potions + a rune,
**9 icons** show inside a dungeon (Mind Blast + Power Infusion + both Undead icons hidden); out in
the open world Fade also collapses, leaving **8**. An **Undead** priest of the same build sees the
Undead pair instead of the Dwarf racials, so the row stays clean either way.

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
- **Plain spell icons (8):** `GetSpellCooldown(name)` / `GetSpellInfo(name)`, tracked **by name**.
  By-name resolves the highest known rank automatically (Classic's per-rank spell IDs are the #1
  "aura won't fire" bug) and returns nil when the spell isn't in the spellbook — which hides
  untalented (Inner Focus), wrong-race (Dwarf racials / Will of the Forsaken), or not-yet-trained
  (Devouring Plague) icons with **no `UnitRace`/level check**: "known" already encodes race + skill.
  Events: `SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD`.
  Reference IDs (comment-only, not used by the logic): Power Infusion
  [10060](https://www.wowhead.com/classic/spell=10060), Psychic Scream
  [8122](https://www.wowhead.com/classic/spell=8122), Fear Ward
  [6346](https://www.wowhead.com/classic/spell=6346), Desperate Prayer
  [13908](https://www.wowhead.com/classic/spell=13908), Stoneform
  [20594](https://www.wowhead.com/classic/spell=20594), Inner Focus
  [14751](https://www.wowhead.com/classic/spell=14751), Will of the Forsaken
  [7744](https://www.wowhead.com/classic/spell=7744), Devouring Plague (rank 1)
  [19276](https://www.wowhead.com/classic/spell=19276).
- **Fade icon (1, PvE-instance-gated):** same by-name logic, but first checks `IsInInstance()` and
  shows the icon only when `instanceType` is `"party"` (5-man) or `"raid"` — so Fade stays collapsed
  in the open world, **battlegrounds** (`"pvp"`), and arenas (`"arena"`). This is an **allow-list**
  on purpose: a deny-list ("hide when pvp") would leak Fade into the open world. `PLAYER_ENTERING_WORLD`
  (plus `ZONE_CHANGED_NEW_AREA`) re-evaluates the gate on every instance enter/exit with no `/reload`.
  Reference: Fade [586](https://www.wowhead.com/classic/spell=586).
- **Mind Blast icon (1, Shadow-gated):** same by-name logic, but first checks
  `GetSpellInfo("Mind Flay")` — Mind Flay is a **talent-only** spell (tier 3 Shadow, 10 pts), so
  "knows it" == "talented it" with no talent-tree parsing (`GetTalentInfo` indices shift; there's no
  `GetSpecialization` on Era). If Mind Flay isn't talented the icon stays hidden, so Mind Blast
  appears for any real shadow investment — full Shadow *and* shadow hybrids, not just 31-pt
  Shadowform builds. `CHARACTER_POINTS_CHANGED` in the events box makes it pop in/out immediately on
  respec (no `/reload`). Reference IDs: Mind Blast
  [8092](https://www.wowhead.com/classic/spell=8092), gate spell Mind Flay
  [15407](https://www.wowhead.com/classic/spell=15407).
- **Item icons (2, possession-gated):** `GetItemCooldown` (flavor-aware `C_Container`/`C_Item`
  fallback) with art from `GetItemIcon`. Both first check `GetItemCount` and **hide when you carry
  none** (avoids a phantom icon painting the shared potion category CD when you have zero). Major
  Mana Potion = item [13444](https://www.wowhead.com/classic/item=13444). The Mana Rune icon scans
  `{ Dark Rune 20520, Demonic Rune 12662 }` and shows whichever you carry.
  Events: `BAG_UPDATE_COOLDOWN SPELL_UPDATE_COOLDOWN BAG_UPDATE PLAYER_ENTERING_WORLD`.

## Custom code

- `code/tsu_pwshield.lua` — the Power Word: Shield icon (4 s spell CD + Weakened Soul self-lockout).
- `code/tsu_spell.lua` — shared TSU pasted into the eight plain spell icons; only the
  `name = "..."` line changes per icon (Psychic Scream / Fear Ward / Desperate Prayer / Stoneform /
  Will of the Forsaken / Inner Focus / Power Infusion / Devouring Plague). By-name self-hiding is what
  makes Will of the Forsaken "Undead-only", Devouring Plague "only once trained", and Power Infusion
  "only when talented" for free.
- `code/tsu_fade.lua` — the PvE-instance-gated Fade icon (shows only in `"party"`/`"raid"` instances).
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
| Fade | 30 s | 10 s threat-drop; **shown only inside PvE dungeons/raids** (hidden in the world & BGs) |
| Psychic Scream | 30 s | base (Improved Psychic Scream — Shadow — would lower it) |
| Fear Ward | 30 s | **Era keeps the 1.x value** (10-min ward); TBC 2.3.0 changed it to a 3-min CD |
| Desperate Prayer | 10 min | instant, off-GCD emergency heal |
| Stoneform | 3 min | 8 s active |
| Will of the Forsaken | 3 min | Undead racial; Era value (TBC 2.x lowered it to 2 min) — shows only for Undead |
| Inner Focus | 3 min | Discipline talent |
| Power Infusion | 3 min | Discipline talent; **shown only when talented** |
| Mind Blast | 8 s (5.5 s w/ 5/5 Improved Mind Blast) | Mind Flay-gated; short CD blinks in the row |
| Devouring Plague | 3 min | Undead priest DoT; hidden until trained (lvl 20) |
| Major Mana Potion | 2 min | shared combat-**potion** category |
| Mana Rune (Dark/Demonic) | 2 min | **separate** category from potions — chainable with a potion |

Design checks: the `dur > 1.5` GCD guard is safe — the shortest real CD (Mind Blast, 8 s / 5.5 s
talented) clears it. Because potions and runes are on **independent** 2-min cooldowns, having both
the Mana Potion and Mana Rune icons is meaningful (each shows its own timer; a potion doesn't
grey out the rune and vice-versa).

## Testing notes

- Import `export.txt`, drag the group where you want it, then cast each ability / drink a potion /
  use a rune — the swipe + number should appear over the matching icon.
- On the 30/21 build the **Mind Blast** slot should be absent (no Mind Flay); respec into Mind Flay
  (10 pts Shadow) and it should appear immediately — `CHARACTER_POINTS_CHANGED` catches the respec
  without a `/reload`. Empty bags → the **Mana Potion / Rune** slots should collapse out.
- Cast **Power Word: Shield on yourself** — the PW:S icon should paint the ~15 s Weakened Soul swipe
  and clear when it fades. Shielding a *party member* shows only the 4 s spell cooldown (Weakened
  Soul lands on them, not you).
- On an **Undead** priest the **Will of the Forsaken** slot should appear (and the Dwarf racials
  collapse out); **Devouring Plague** should appear once trained at level 20 (`LEARNED_SPELL_IN_TAB`
  pops it in without a `/reload`). On a **Dwarf** both Undead slots should be absent.
- **Fade** should be **hidden** in the open world and inside any **battleground** (WSG/AB/AV) or arena,
  and **appear** the moment you zone into a 5-man or raid — then collapse again on the way out (no
  `/reload`; `PLAYER_ENTERING_WORLD`/`ZONE_CHANGED_NEW_AREA` re-gate it).
- **Power Infusion** should appear only when it's **talented** (deep Discipline) and pop in/out
  immediately on respec (`CHARACTER_POINTS_CHANGED`); on the reference 30/21 build it stays hidden.
- **Silence** (Shadow) is still intentionally omitted — add a spell icon for it if you want it.
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
- 2026-08-10 — Change the Mind Blast reveal gate from Shadowform (31 pts) to **Mind Flay** (10 pts,
  talent-only spell). Now surfaces for any real shadow investment — full Shadow *and* shadow hybrids
  — not just 31-pt Shadowform builds. Added `CHARACTER_POINTS_CHANGED` to the Mind Blast events box so
  the icon appears/disappears immediately on respec. Re-exported (round-trip lossless). Mind Flay ref
  [15407](https://www.wowhead.com/classic/spell=15407).
- 2026-08-16 — Make the row **race-adaptive** for Undead priests: add **Will of the Forsaken**
  ([7744](https://www.wowhead.com/classic/spell=7744), Undead racial, after Stoneform) and
  **Devouring Plague** ([19276](https://www.wowhead.com/classic/spell=19276), Undead priest spell,
  after Mind Blast). Row is now 12 icons. Both reuse the shared by-name TSU (`code/tsu_spell.lua`),
  so no new logic and no `UnitRace`/level check: by-name returns nil off-race / before training, so
  Will of the Forsaken shows only for Undead and Devouring Plague only once learned; both collapse
  out on a Dwarf. Re-exported (round-trip lossless).
- 2026-08-16 — Rename the display from *Dwarf Priest Cooldowns* to **Priest Cooldowns** now that the
  row is race-adaptive (the "Dwarf" label was misleading for Undead priests). Same `uid`
  (`priCdGrp1`), so WA still recognizes it as the same aura on re-import. Updated the group `id`,
  every child `parent`, all in-code comment headers, docs, and catalog. Re-exported (round-trip
  lossless).
- 2026-08-31 — Gate **Fade** to PvE instances only. Its TSU now checks `IsInInstance()` and shows the
  icon only when `instanceType` is `"party"` (5-man) or `"raid"` — hidden in the open world,
  **battlegrounds** (`"pvp"`) and arenas. Allow-list by design (a deny-list would leak it into the
  world); `PLAYER_ENTERING_WORLD` + the added `ZONE_CHANGED_NEW_AREA` re-gate on every zone/instance
  transition with no `/reload`. New `code/tsu_fade.lua` (the rest of the body is byte-identical to the
  old Fade TSU). Re-exported, decode→encode→decode **lossless**; Lua 5.1 parse clean. **Pending in-game
  test** (and `luacheck`, unavailable in the authoring environment).
- 2026-08-31 — Add **Power Infusion** ([10060](https://www.wowhead.com/classic/spell=10060), Discipline
  talent) after Inner Focus; the row is now **13 icons**. Reuses the shared by-name TSU
  (`code/tsu_spell.lua`): Power Infusion is a talent-only spell, so by-name returns nil until talented
  and the icon self-hides — it appears exactly when the priest is specced into it, with no talent-tree
  parsing. Its events box adds `CHARACTER_POINTS_CHANGED` so it pops in/out immediately on respec.
  New child `uid=priCdPInf1`, inserted into `controlledChildren` after `Inner Focus`. Re-exported,
  decode→encode→decode **lossless**; Lua 5.1 parse clean. **Pending in-game test**.
