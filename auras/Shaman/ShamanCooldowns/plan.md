# Plan — 19 Shaman Cooldowns

Planning doc for a new cooldown/utility display for a **level 19 twink Tauren Shaman**,
mirroring *Betty's 19 Paladin Cooldowns* and *Dwarf Priest Cooldowns* (icons whose TSU
reads cooldown directly and self-hides when the ability isn't known/carried).
**Not built in-game yet — this is the locked design.**

| Field | Value |
|---|---|
| **Display name** | `Betty's 19 Shaman Cooldowns` (matches the Paladin naming) |
| **Category / folder** | `Shaman` |
| **Target flavor(s)** | Classic Era / SoD / Hardcore (legacy `GetSpellInfo`/`GetSpellCooldown`/`GetItemCooldown`/`GetTotemInfo`) |
| **Race** | **Tauren** (War Stomp) — confirmed |
| **Region type** | parent `group` holding **Tier 1** (`dynamicgroup`, full-size primary row) + **Tier 2** (`dynamicgroup`, smaller totem sub-row) |

---

## Locked decisions (2026-07-27)

1. **Dynamic** groups (collapse hidden icons flush), not static.
2. **Consumables:** **Healing Potion** (item 929, req level 12) + **Big Bronze Bomb** (item 4380).
3. **Tauren** confirmed → War Stomp is in.
4. **Two size-tiers by PvP priority.** Primary abilities full-size; the low-relevance totem
   CDs (Fire Nova, Stoneclaw) go **smaller / off to the side** — visual hierarchy, per user.
5. **Presence folded into the CD icons via a "planted" glow** (no separate active-totem
   strip). One icon = recast-CD swipe + glow-while-down. Removes the old double-Earthbind.

---

## Totem cooldowns at 19 — verified in-game (tooltips)

| Totem | CD | Element slot | PvP relevance | Placement |
|---|---|---|---|---|
| **Earthbind** | **15 s** | Earth | High — the *only* snare (no Frost Shock / Ghost Wolf) | **Tier 1** |
| **Fire Nova** | **15 s** | Fire | Low-ish — situational AoE burst (5 s fuse) | **Tier 2** |
| **Stoneclaw** | **30 s** | Earth | Low — body-block / eat a cast; niche | **Tier 2** |
| Tremor | none | Earth | Reactive fear-break | not shown (optional presence dot) |
| Searing | none | Fire | Passive DPS, set-and-forget | not shown (optional presence dot) |

Note the original vanilla 1.12 behavior (CD-less totems) does **not** apply to this client —
Earthbind/Fire Nova/Stoneclaw all carry recast cooldowns here. Tremor and Searing do not.

---

## Structure

### Tier 1 — Primary row (`dynamicgroup`, full-size icons, grow HORIZONTAL)

Left → right (stun → shock → snare → items):

1. **War Stomp** (racial) — 120 s CD. Self-hides on non-Tauren (by-name `GetSpellInfo` → nil).
2. **Earth Shock** — 6 s shock CD (shared w/ Flame Shock); interrupt/burst readiness.
3. **Earthbind Totem** — **15 s recast CD**; your only snare. **Glows while planted** (see below).
4. **Healing Potion** (item 929) — ~2 min, possession-gated (collapses when not carried).
5. **Big Bronze Bomb** (item 4380) — AoE stun, ~1 min throw CD, possession-gated.

Code: `tsu_spell.lua` (by-name `GetSpellCooldown`) for icons 1–3 — Earthbind works with the
exact same by-name pattern since it reports a real 15 s CD; `tsu_item.lua` for icons 4–5.

### Tier 2 — Totem sub-row (`dynamicgroup`, ~0.6 scale, anchored below Tier 1, left-aligned)

Low-priority totem CDs, demoted by size + position (not by behavior):

1. **Fire Nova Totem** — 15 s CD. **Glows while planted.**
2. **Stoneclaw Totem** — 30 s CD. **Glows while planted.**

Same cloned `tsu_spell.lua` (by-name). Smaller icon size is the whole demotion mechanism —
same swipe language as Tier 1 so the display reads consistently.

### Presence — "planted" glow instead of a separate strip

Rather than a third cluster duplicating these icons, each totem CD icon (Earthbind in Tier 1;
Fire Nova + Stoneclaw in Tier 2) gets a **glow condition while that totem is physically down**,
read from `GetTotemInfo`. One icon then conveys two facts:

- **Swipe** → when you can re-drop it (recast CD).
- **Glow** → it's currently planted (up to its full physical duration: Earthbind 45 s,
  Stoneclaw 15 s, Fire Nova 5 s).

Driver: a tiny helper (in `init.lua` or a `conditions.lua` custom check) scans the 4 totem
slots via `GetTotemInfo(slot)` and returns true when the named totem is active; a WA
**Condition** turns on Glow for that icon. Scanning all slots avoids hardcoding the Classic
slot order (commonly Fire=1, Earth=2, Water=3, Air=4). Refresh on `PLAYER_TOTEM_UPDATE`.

> **Tremor / Searing (no CD):** omitted by default — Tremor is reactive, Searing is passive.
> If you want them visible, add tiny **presence-only** dots to Tier 2 (glow-when-planted, no
> swipe) via the same `GetTotemInfo` helper. Flagged as optional, not in the baseline.

---

## Full ability availability at level 19

Levels are when a Shaman **learns** the spell (warcraft.wiki.gg, Classic ability list).

### Available at 19

| Ability | Learned | CD | In display? |
|---|---|---|---|
| War Stomp (racial) | 1 | 120 s | **Tier 1** |
| Earth Shock | 4 | 6 s (shared) | **Tier 1** |
| Flame Shock | 10 | 6 s (shares Earth Shock) | folded into the shock CD |
| Earthbind Totem | 6 | **15 s** | **Tier 1** (+ planted glow) |
| Fire Nova Totem | 12 | **15 s** | **Tier 2** (+ planted glow) |
| Stoneclaw Totem | 8 | **30 s** | **Tier 2** (+ planted glow) |
| Tremor Totem | 18 | none | optional presence dot |
| Searing Totem | 10 | none | optional presence dot |
| Purge | 12 | none | not shown |
| Lightning Shield | 8 | none | not shown |
| Cure Poison | 16 | none | not shown |

### NOT available at 19 — excluded by level, not by choice

| Ability | Learned | Why it matters |
|---|---|---|
| **Frost Shock** | **20** | The famous snare+nuke — **absent**. Earthbind is the only slow. |
| **Ghost Wolf** | **20** | **No sprint/escape.** Reinforces Earthbind's importance. |
| Frostbrand Weapon | 20 | No on-hit snare buff. |
| **Grounding Totem** | **30** | Spell-eater totem — **absent**; don't plan around it. |
| Cure Disease | 22 | Only Cure Poison exists. |

---

## Totem-slot facts

Classic totems fill one of four element slots, one per slot. At 19 only Earth + Fire matter:

- **Earth slot:** Earthbind / Tremor / Stoneclaw / Stoneskin / Strength of Earth — mutually
  exclusive (only one Earth totem down at a time).
- **Fire slot:** Searing / Fire Nova — mutually exclusive.
- Water/Air combat totems are level 20+ → none at 19.

Implication for the glow: at most one Earth totem and one Fire totem can be planted at once,
so at most Earthbind **or** Stoneclaw glows (Earth), and Fire Nova glows independently (Fire).

---

## Cooldown / duration reference (verified in-game)

| Icon | CD | Physical duration | Source in code |
|---|---|---|---|
| War Stomp | 120 s | — | `GetSpellCooldown("War Stomp")` |
| Earth Shock | 6 s (shared w/ Flame Shock) | — | `GetSpellCooldown("Earth Shock")` |
| Earthbind Totem | **15 s** | 45 s | `GetSpellCooldown` + `GetTotemInfo` (glow) |
| Fire Nova Totem | **15 s** | 5 s fuse | `GetSpellCooldown` + `GetTotemInfo` (glow) |
| Stoneclaw Totem | **30 s** | 15 s | `GetSpellCooldown` + `GetTotemInfo` (glow) |
| Healing Potion (929) | ~2 min | — | `GetItemCooldown` |
| Big Bronze Bomb (4380) | ~1 min | — | `GetItemCooldown` |

`dur > 1.5` GCD guard is safe (shortest real CD is the 6 s shock).

Reference spell/item IDs (comment-only; spells tracked **by name**, ranks resolve automatically):
War Stomp [20549](https://www.wowhead.com/classic/spell=20549), Earth Shock
[8042](https://www.wowhead.com/classic/spell=8042), Flame Shock
[8050](https://www.wowhead.com/classic/spell=8050), Earthbind Totem
[2484](https://www.wowhead.com/classic/spell=2484), Fire Nova Totem
[1535](https://www.wowhead.com/classic/spell=1535), Stoneclaw Totem
[5730](https://www.wowhead.com/classic/spell=5730), Tremor Totem
[8143](https://www.wowhead.com/classic/spell=8143), Searing Totem
[3599](https://www.wowhead.com/classic/spell=3599), Healing Potion
[929](https://www.wowhead.com/classic/item=929), Big Bronze Bomb
[4380](https://www.wowhead.com/classic/item=4380). Excluded (level 20+): Frost Shock
[8056](https://www.wowhead.com/classic/spell=8056), Ghost Wolf
[2645](https://www.wowhead.com/classic/spell=2645).

---

## Code files

- `code/tsu_spell.lua` — by-name `GetSpellCooldown` TSU (cloned from Paladin/Priest). Used by
  all 5 spell icons across both tiers (War Stomp, Earth Shock, Earthbind, Fire Nova, Stoneclaw).
- `code/tsu_item.lua` — possession-gated `GetItemCooldown` TSU (cloned). Healing Potion 929,
  Big Bronze Bomb 4380.
- `code/conditions.lua` (**new**) — `GetTotemInfo` scanner returning "is <totem> planted?" for
  the glow conditions on the three totem icons. Only genuinely new code in this aura.

---

## Build checklist (when we go in-game)

1. Parent `group` with two child dynamicgroups: Tier 1 (full size) and Tier 2 (~0.6 scale),
   Tier 2 anchored below Tier 1, left-aligned.
2. Tier 1: 3 spell icons (War Stomp, Earth Shock, Earthbind) via `tsu_spell.lua`; 2 item icons
   (929, 4380) via `tsu_item.lua`.
3. Tier 2: 2 spell icons (Fire Nova, Stoneclaw) via `tsu_spell.lua`, smaller.
4. Add a **Glow condition** to Earthbind, Fire Nova, Stoneclaw driven by the `conditions.lua`
   "is planted?" check.
5. `inverse = true` swipe on all CD icons (match Paladin/Priest).
6. In-game verify: all CDs paint (Earthbind/Fire Nova 15 s, Stoneclaw 30 s, shock 6 s, War
   Stomp 120 s, 929/4380 item CDs); glow lights while each totem is physically down;
   `PLAYER_TOTEM_UPDATE` refreshes the glow on drop/expire.
7. Export → `export.txt`, decode → `aura.json`, write `aura.md`, add to `auras/README.md`.

## Remaining open items
- Tier 2 exact scale + placement (below vs. right; ~0.6?) — tune in-game.
- Include Tremor/Searing as optional presence-only dots, or omit (default omit)?

## Changelog

- 2026-07-27 — Initial plan. Verified 19-bracket availability (Frost Shock, Ghost Wolf,
  Grounding Totem are level 20+, excluded).
- 2026-07-27 — Locked: dynamic groups; Healing Potion 929 + Big Bronze Bomb 4380; Tauren.
- 2026-07-27 — Correction (in-game tooltip): Earthbind Totem has a **15 s cooldown** on this
  client — promoted to a primary cooldown node.
- 2026-07-27 — Totem CDs mapped in-game: Fire Nova **15 s**, Stoneclaw **30 s** (Tremor/Searing
  no CD). Redesigned to a two-tier hierarchy — full-size primary row (War Stomp, Earth Shock,
  Earthbind, Healing Potion, Big Bronze Bomb) + smaller offset totem sub-row (Fire Nova,
  Stoneclaw). Replaced the separate active-totem scanner strip with a **"planted" glow** folded
  into each totem CD icon (swipe = recast, glow = currently down), removing the double-Earthbind
  redundancy. New `conditions.lua` glow driver. Tremor/Searing optional presence dots, default omit.
