# WoW Classic API Reference for WeakAuras (2025–2026)

Custom Lua in these auras runs on a **Classic** client, not Retail. The API surface
differs — code copied from Retail auras will often break. This is the reference for
those differences. Verify version-sensitive numbers against your actual client with
`select(4, GetBuildInfo())` when scaffolding.

---

## 1. Classic flavors in service

The live "Classic" clients are **not** interchangeable for authoring.

| Flavor | Version | Talent model | Notes |
|---|---|---|---|
| **Classic Era** (Vanilla / Anniversary) | 1.15.x | Old 3-tree (`GetTalentInfo`) | Base client, continually re-patched. |
| **Season of Discovery (SoD)** | 1.15.x (same client) | Old 3-tree **+ Runes** | Same API/Interface as Era; adds rune-granted spells (unique IDs). |
| **Hardcore** | 1.15.x (same client) | Same as Era | A ruleset, **not** an API difference — author identically to Era. |
| **Cataclysm Classic** | 4.4.x | Cata trees + `GetSpecialization` | Separate client; **has** the spec system. |
| **Mists of Pandaria Classic** | 5.5.x | MoP 6-row tiered + spec | Launched 2025; current progression stop. Has spec system. |
| **Retail** (for contrast) | 12.x | Modern loadouts | Not a target here. |

**Key mental model:** SoD and Hardcore *are* the Classic Era client — old talents,
spell ranks, **no `GetSpecialization`**. Cata/MoP Classic are *separate* clients that
**do** have the specialization system. Branch on `WOW_PROJECT_ID`:

```lua
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then            -- Era / SoD / Hardcore
elseif WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC then
elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
elseif WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then       -- Retail
end
```

---

## 2. Key API differences vs Retail

### Aura scanning
- **`UnitAura` / `UnitBuff` / `UnitDebuff` are available on all Classic flavors.** They were removed on **Retail 11.0.2** — the single biggest divergence.
  ```lua
  name, icon, count, dispelType, duration, expirationTime, source, isStealable,
  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, ...
    = UnitAura(unit, index [, filter])   -- filter: "HELPFUL"/"HARMFUL"/"PLAYER"...
  ```
  - 7th return `source` is the applying unit token (filter own auras with `castByPlayer` or `source == "player"`).
  - **No rank field** — the `rank` return was removed globally in 8.0.1.
- **`C_UnitAuras` IS backported to current Classic** (`C_UnitAuras.GetAuraDataByIndex(unit, index [, filter])` present in Era 1.15.8, BCC 2.5.6, MoP 5.5.4). Works on current clients, but `UnitAura` remains the safest common denominator for older installs.
- `AuraUtil.ForEachAura`, `AuraUtil.FindAuraByName` exist; on older builds `ForEachAura` wraps index-based `UnitAura`.
- **Debuff cap:** Classic Era caps visible debuffs at **16** (BCC+ raises to 40). Don't hard-loop to 40 on Era.

### Spell info / cooldowns
- **`GetSpellInfo` available on all Classic flavors** (removed on Retail 11.0.0). Still accepts a spell **name** and returns 8 values:
  ```lua
  name, subtext, icon, castTime, minRange, maxRange, spellID, originalIcon = GetSpellInfo(spell)
  ```
  `subtext`/rank is nil since 8.0.1 — read a rank string with `GetSpellSubtext(spellID)`.
- **`C_Spell` backported** — `C_Spell.GetSpellInfo`, `C_Spell.GetSpellCooldown(spellId)` present in Era 1.15.8 / BCC / MoP. `GetSpellCooldown` returns a table `{ startTime, duration, isEnabled, isActive, modRate, ... }`.
- **Legacy `GetSpellCooldown`** still works on Classic (`start, duration, enabled, modRate`); removed on Retail 11.0.0. Prefer the legacy globals on Classic for install-compat, or branch.

### Combat log
- **Identical to Retail:** register `COMBAT_LOG_EVENT_UNFILTERED`, then read the payload with `CombatLogGetCurrentEventInfo()` inside the handler (args are not passed directly).
  ```lua
  local ts, subevent, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags,
        dstGUID, dstName, dstFlags, dstRaidFlags, ... = CombatLogGetCurrentEventInfo()
  ```
- In WeakAuras, prefer a **CLEU trigger with a subevent filter** (`CLEU:SPELL_CAST_START`). WA warns about unfiltered CLEU custom triggers (performance).

### Talents / specialization
- **Era / SoD / Hardcore:** old talents — `GetTalentInfo(tabIndex, talentIndex [, isInspect])`; **no `GetSpecialization`**. WA's talent-loading branches on flavor; a Blizzard shift toward `C_SpecializationInfo.GetTalentInfo{ tier=, column= }` on newer Anniversary builds caused a WA breakage (issue #6072) — pin a recent WA build.
- **Cata / MoP Classic:** `GetSpecialization()` / `GetSpecializationInfo()` exist, plus their own talent APIs. **Retail loadout APIs (`C_ClassTalents`, `C_Traits`) do not exist** on any Classic flavor.

### Power / GCD / haste
- **GCD probe:** query dummy spell ID **61304** via a cooldown getter (standard trick). Era GCD is ~1.5s and largely not haste-scaled.
- Spell haste barely affects Era; meaningful on Cata/MoP. `UnitPower`/`UnitPowerMax`/`Enum.PowerType` exist across flavors, but secondary resources only where the class/expansion has them.

### Absent / protected on Classic
- Retail-only, **nil on Classic** (guard with `if C_Foo then`): `C_ClassTalents`, `C_Traits`, `GetSpecialization` (on Era), some `C_SpellBook` variants.
- Protected/tainted secure actions behave as on Retail — no unlocking.

---

## 3. Spell / item ID lookup

- **Wowhead per-flavor:** `wowhead.com/classic/` (Era), `wowhead.com/cata/`, and the MoP Classic section. IDs differ between Classic and Retail **and between ranks**.
- **Warcraft Wiki** (`warcraft.wiki.gg`) — authoritative API + spell pages with per-flavor version badges.
- **Critical gotcha:** in Classic **every rank of a spell is a separate spell ID** (Rank 1 vs Rank 6 differ). A WeakAura tracking a ranked spell must track **all** rank IDs or match by **name**. Player-applied auras carry the rank-specific ID.
- **SoD rune spells** have unique IDs not in base 1.12 data — verify on the SoD/Classic Wowhead DB.

---

## 4. Interface / TOC version numbers (current live, 2025–2026)

From Warcraft Wiki "Public client builds." **Re-check against your client** — these
increment every maintenance patch.

| Flavor | Interface (TOC) number | TOC suffix |
|---|---|---|
| **Classic Era / SoD / Hardcore** | **11508** (1.15.8) | `_Vanilla.toc` |
| **Cataclysm Classic** | **40504** (4.4.x) | `_Cata.toc` |
| **Mists of Pandaria Classic** | **50504** (5.5.x) | `_Mists.toc` |
| **Retail** (contrast) | **120007** (12.x) | `_Mainline.toc` |

A single addon ships one `.toc` per flavor, each with its matching `## Interface:`.

---

## 5. Common Classic gotchas

1. **`UnitAura` vs `C_UnitAuras`** — both exist on current Classic, but `UnitAura` is gone on Retail. Don't blindly copy Retail-only aura snippets; write flavor-aware code.
2. **Spell ranks = different IDs** — the #1 "my aura doesn't fire" cause. Track by name or enumerate rank IDs. No rank field from `UnitAura`/`GetSpellInfo`.
3. **No `GetSpecialization` on Era/SoD/Hardcore** — calling it errors. Use `GetTalentInfo`. It *does* exist on Cata/MoP — guard by flavor, not "Classic yes/no."
4. **Combat log** — must call `CombatLogGetCurrentEventInfo()`; always filter by subevent.
5. **Retail-only namespaces are nil** — `C_ClassTalents`, `C_Traits`, loadout APIs. Guard with `if C_Foo then`.
6. **Debuff cap 16 on Era** (40 on BCC+).
7. **`GetSpellInfo` name lookups** resolve only spells in your spellbook on Classic — prefer numeric IDs.
8. **Unit tokens** — `boss1`–`boss5` exist but many encounters don't populate them; no arenas on Era; `focus` exists everywhere.
9. **Interface mismatches** flag the addon "out of date" — keep per-flavor TOCs current (§4).
10. **SoD runes** grant spells absent from 1.12 data — verify IDs on the SoD DB; SoD has no spec system.

---

## Sources

- [API_UnitAura](https://warcraft.wiki.gg/wiki/API_UnitAura) · [C_UnitAuras.GetAuraDataByIndex](https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDataByIndex) · [API_GetSpellInfo](https://warcraft.wiki.gg/wiki/API_GetSpellInfo) · [C_Spell.GetSpellCooldown](https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCooldown)
- [COMBAT_LOG_EVENT](https://warcraft.wiki.gg/wiki/COMBAT_LOG_EVENT) · [API_GetTalentInfo/Classic](https://warcraft.wiki.gg/wiki/API_GetTalentInfo/Classic)
- [Public client builds](https://warcraft.wiki.gg/wiki/Public_client_builds) · [TOC format](https://warcraft.wiki.gg/wiki/TOC_format)
- [SoD](https://warcraft.wiki.gg/wiki/World_of_Warcraft_Classic:_Season_of_Discovery) · [WA issue #6072](https://github.com/WeakAuras/WeakAuras2/issues/6072) · [Prototypes.lua](https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Prototypes.lua)
