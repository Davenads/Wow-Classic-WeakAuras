# Betty's 19 Paladin Cooldowns

| Field | Value |
|---|---|
| **Display name** | `Betty's 19 Paladin Cooldowns` |
| **Category / folder** | `Paladin` |
| **Target flavor(s)** | Classic Era / SoD / Hardcore (uses legacy `GetSpellInfo`/`GetSpellCooldown`) |
| **Min WeakAuras version** | 5.x |
| **wago URL** | n/a |
| **wago version** | n/a |
| **Region type** | `group` (static) of 8 `icon` children |

## Purpose

A fixed horizontal row of the cooldowns a 19-bracket twink Paladin cares about, each an
icon with a live cooldown swipe + numeric countdown. Left → right:

1. **Divine Protection**
2. **Blessing of Protection**
3. **Blessing of Freedom**
4. **Lay on Hands**
5. **Judgement**
6. **Healing Potion** (item)
7. **Big Bronze Bomb** (item — Engineering AoE stun)
8. **Stoneform** (Dwarf racial — self-hides if the character can't cast it)

Icons are always shown (bright = ready, swipe + number = on cooldown). It's a **static
group** so hiding Stoneform (non-Dwarf) leaves its trailing slot empty without reflowing
the rest of the row.

## Triggers

Each icon is a **Custom ▸ Trigger State Updater** (one `""` state) — the same proven
pattern as *Betty's Trinket Display*, reading cooldowns directly rather than via a native
Cooldown Progress trigger.

- **Spell icons (6):** `GetSpellCooldown(name)` / `GetSpellInfo(name)`, tracked **by name**.
  By-name resolves the highest known rank automatically (Classic's per-rank spell IDs are
  the #1 "aura won't fire" bug) and returns nil when the spell isn't in the spellbook —
  which is exactly how the Stoneform icon hides itself on a non-Dwarf.
  Events: `SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE LEARNED_SPELL_IN_TAB PLAYER_ENTERING_WORLD`.
  Reference IDs (comment-only, not used by the logic): Divine Protection
  [498](https://www.wowhead.com/classic/spell=498), Blessing of Protection
  [1022](https://www.wowhead.com/classic/spell=1022), Blessing of Freedom
  [1044](https://www.wowhead.com/classic/spell=1044), Lay on Hands
  [633](https://www.wowhead.com/classic/spell=633), Judgement
  [20271](https://www.wowhead.com/classic/spell=20271), Stoneform
  [20594](https://www.wowhead.com/classic/spell=20594).
- **Item icons (2):** `GetItemCooldown` (flavor-aware `C_Container`/`C_Item` fallback) with
  art from `GetItemIcon` (needs no item cache, so the slot never blanks). Healing Potion =
  item [929](https://www.wowhead.com/classic/item=929) (all healing potions share the same
  ~2-min combat cooldown, so the swipe is identical regardless of which you carry — only the
  art differs; swap `ITEM_ID` for e.g. Lesser Healing Potion 858 / Discolored Healing Potion
  3826). Big Bronze Bomb = item [4380](https://www.wowhead.com/classic/item=4380) (Engineering
  AoE stun, shares the ~1-min throwable/bomb cooldown).
  Events: `BAG_UPDATE_COOLDOWN SPELL_UPDATE_COOLDOWN BAG_UPDATE PLAYER_ENTERING_WORLD`.

The `dur > 1.5` guard filters the global cooldown so only real cooldowns paint a swipe.
The numeric countdown is WA's built-in icon cooldown text (`cooldownTextDisabled = false`).

## Custom code

- `code/tsu_spell.lua` — the shared TSU pasted into all six spell icons; only the
  `name = "..."` line changes per icon (Divine Protection / Blessing of Protection /
  Blessing of Freedom / Lay on Hands / Judgement / Stoneform).
- `code/tsu_item.lua` — the shared TSU for the two item icons; only `ITEM_ID` changes
  (929 Healing Potion / 4380 Big Bronze Bomb).

No Init/Show/Hide/Condition code — the cooldown swipe animates itself once a state has
`duration` + `expirationTime`.

## Testing notes

- Import `export.txt`, drag the group where you want it, then cast each ability and use a
  potion / throw a bomb — the swipe + number should appear over the matching icon.
- On a **non-Dwarf**, the Stoneform slot should be empty (trailing gap only).
- If your potion/bomb of choice isn't item 929 / 4380, edit `ITEM_ID` in that icon's TSU
  (and `code/tsu_item.lua`) and re-export.
- Spell **names are enUS**; non-English clients need the localized names in each spell TSU.

## Changelog

- 2026-07-10 — Initial version. Static group of 8 cooldown icons (fabricated export,
  cloned from the trinket-display group/icon + TSU pattern): Divine Protection, Blessing of
  Protection, Blessing of Freedom, Lay on Hands, Judgement, Healing Potion (929), Big Bronze
  Bomb (4380), Stoneform. Spells tracked by name; Stoneform self-hides on non-Dwarf.
- 2026-07-11 — Re-pitch the row flush: pitch now equals icon width (40px) so the 8 squares
  touch edge-to-edge with no gap (xOffsets -140…140).
