# Aura Catalog

One row per aura. Keep this in sync as auras are added or changed. `_TEMPLATE/` is the
scaffold to copy for a new aura — it is not a real aura and has no catalog row.

| Aura | Folder | Flavor(s) | Region | wago | Status |
|---|---|---|---|---|---|
| WSG Flag Carriers | [Battlegrounds/WSG-FlagCarriers](Battlegrounds/WSG-FlagCarriers) | Era / SoD / HC | text | — | Import-ready (generated string); pending in-game test |
| WSG Enemy FC Announcer | [Battlegrounds/WSG-EnemyFCAnnouncer](Battlegrounds/WSG-EnemyFCAnnouncer) | Era / SoD / HC (+ Cata/MoP) | text | — | Import-ready (generated string); pending in-game test |
| Betty's 19 Twink Trinket Manager | [PvP/TrinketAutoSwap](PvP/TrinketAutoSwap) | Era (+ Cata/MoP) | all-in-one group (engine + 3 icons), `package.txt` | — | Import-ready; single-string `package.txt` bundles engine + bar; zero-config both factions (Insignia auto-detected); pending in-game test |
| Betty's 19 Paladin Cooldowns | [Paladin/PaladinCooldowns](Paladin/PaladinCooldowns) | Era / SoD / HC | static group of 9 icons | — | Import-ready (generated string); cooldown row (Hammer of Justice/DP/BoP/BoF/LoH/Judgement/Healing Potion/Big Bronze Bomb/Stoneform); spells tracked by name, Stoneform self-hides on non-Dwarf; pending in-game test |
| Dwarf Priest Cooldowns | [Priest/PriestCooldowns](Priest/PriestCooldowns) | Era | dynamic group of 10 icons | — | Import-ready (generated string, round-trip lossless); level 60 Dwarf Priest row (Power Word: Shield/Fade/Psychic Scream/Fear Ward/Desperate Prayer/Stoneform/Inner Focus/Mind Blast/Major Mana Potion/Mana Rune); spells by name, items possession-gated, PW:S tracks its 4 s spell CD + Weakened Soul self-lockout, Mind Blast reveals only on Shadow builds, hidden icons collapse; pending in-game test |

## How to add an aura

1. Copy `_TEMPLATE/` → `<Category>/<AuraName>/` (e.g. `Mage/FrostboltProc/`).
2. Follow the checklist in `../CLAUDE.md` §3.
3. Add a row above with a link to the folder.

Suggested categories: class names (`Mage`, `Warrior`, …) for class/spec auras;
`Raid`, `Dungeon`, `PvP`, `UI`, `Utility` for the rest.
