# Aura Catalog

One row per aura. Keep this in sync as auras are added or changed. `_TEMPLATE/` is the
scaffold to copy for a new aura — it is not a real aura and has no catalog row.

| Aura | Folder | Flavor(s) | Region | wago | Status |
|---|---|---|---|---|---|
| WSG Flag Carriers | [Battlegrounds/WSG-FlagCarriers](Battlegrounds/WSG-FlagCarriers) | Era / SoD / HC | text | — | Import-ready (generated string); pending in-game test |
| WSG Enemy FC Announcer | [Battlegrounds/WSG-EnemyFCAnnouncer](Battlegrounds/WSG-EnemyFCAnnouncer) | Era / SoD / HC (+ Cata/MoP) | text | — | Import-ready (generated string); pending in-game test |
| Betty's 19 Twink Trinket Manager | [PvP/TrinketAutoSwap](PvP/TrinketAutoSwap) | Era (+ Cata/MoP) | text (controller) + icon group (3 displays) | — | Import-ready; zero-config both factions (Insignia auto-detected); pending in-game test |

## How to add an aura

1. Copy `_TEMPLATE/` → `<Category>/<AuraName>/` (e.g. `Mage/FrostboltProc/`).
2. Follow the checklist in `../CLAUDE.md` §3.
3. Add a row above with a link to the folder.

Suggested categories: class names (`Mage`, `Warrior`, …) for class/spec auras;
`Raid`, `Dungeon`, `PvP`, `UI`, `Utility` for the rest.
