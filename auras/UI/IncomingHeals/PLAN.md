# Incoming Heals Indicator — Planning Review

> **Status:** BUILT (v1). Icon indicator authored + encoded (`export.txt`, round-trip lossless);
> pending in-game test with a live healer. This doc reviews *how to detect* incoming heals on
> Classic Era and *how to display* them, then recommends an approach; §5 records the locked decisions.
> **Date:** 2026-07-15 · **Target flavor:** Classic Era (Vanilla / Anniversary, 1.15.x).
> **Scope:** heals landing on **your own character only** (`unit = "player"`). Absorbs
> (PW:Shield, etc.) are out of scope for v1 (see §7 Extensions).
> **Location note:** `auras/UI/IncomingHeals/` is provisional — trivial to move to
> `Utility/` or `Raid/` once we settle the catalog category.

---

## 1. The core problem — Classic Era has no *reliable* native heal prediction

On Retail, `UnitGetIncomingHeals("player")` + the `UNIT_HEAL_PREDICTION` event give a complete,
trustworthy number and the default frames draw the "ghost" bar. **Classic Era is not that.**

- `UnitGetIncomingHeals(unit [, healerGUID])` **was backported to Era** (patch 1.14.0), and it
  *does* exist — but it is **only partially functional**: it predicts **direct spell casts only**.
  **HoTs (Renew, Rejuvenation), channelled heals (Tranquility), and cross-player casts are not
  factored in**, and in practice it returns **0** for many common situations. Blizzard never wired
  up working default-frame heal prediction on Era — which is exactly why community addons exist.
- The community answer is **LibHealComm-4.0**: a library that watches every group member's heal
  casts, shares amounts over an addon comm channel, and estimates landed amounts from rank + gear +
  talents + modifiers. It is what VuhDo / HealBars / ClassicHealPrediction use. It is **accurate and
  complete** — but it is an **external library**, usable from a WeakAura only if *some other loaded
  addon* provides it (`LibStub("LibHealComm-4.0", true)`); it cannot be embedded in a standalone WA.
- Tracking **other players'** heal casts yourself is non-trivial: Classic Era does **not** natively
  fire `UNIT_SPELLCAST_START` for party/raid units (that's why `LibClassicCasterino` exists). You'd
  have to reconstruct casts from the **combat log** (`CLEU:SPELL_CAST_START`, which carries
  `srcGUID`/`destGUID`) and gate on `destGUID == UnitGUID("player")`.

**Bottom line:** there is no single zero-dependency call that "just works." We pick a data source
(or a graceful chain of them) with eyes open about the trade-offs.

---

## 2. Detection options (data sources)

| # | Source | Dependency | Gives amount? | Gives land-time? | HoTs/channels? | Cross-player? | Reliability |
|---|---|---|---|---|---|---|---|
| **D1** | Native `UnitGetIncomingHeals("player")` + `UNIT_HEAL_PREDICTION` | **none** | yes (direct only) | no | ❌ | partial | ⚠️ low on Era (often 0) |
| **D2** | `LibHealComm-4.0` via `LibStub` | needs a provider addon loaded | **yes** (modeled) | **yes** (`GetNextHealAmount`) | ✅ | ✅ | ✅ high (when present) |
| **D3** | Self-rolled `CLEU:SPELL_CAST_START` on `destGUID==player` | **none** | ❌ (or coarse table) | yes (cast start + `GetSpellInfo` cast time) | ❌ direct only | ✅ | ⚠️ fuzzy, amount-less |

### D1 — Native API (zero dependency, weak)
- Trigger: status/custom on `UNIT_HEAL_PREDICTION` (+ a `FRAME_UPDATE` or timer poll fallback),
  read `UnitGetIncomingHeals("player")`.
- **Pros:** trivial, no external deps, no spell tables.
- **Cons:** direct casts only; **misses HoTs and channels**; commonly returns 0 on Era; no
  land-time; no caster. Not trustworthy as the *sole* source.

### D2 — LibHealComm-4.0 (best data, opt-in)
- Detect at runtime: `local HC = LibStub and LibStub("LibHealComm-4.0", true)`. If `nil`, degrade.
- Amount now: `HC:GetHealAmount(UnitGUID("player"), HC.ALL_HEALS, GetTime() + window)`.
- Next heal + when + who: `HC:GetNextHealAmount(UnitGUID("player"))` → `amount, stacks, endTime, healerGUID`.
- Modifier (e.g. Mortal Strike / Spirit Link): `HC:GetHealModifier(guid)`.
- Live updates via `HC.RegisterCallback`: `HealComm_HealStarted`, `_HealUpdated`, `_HealDelayed`,
  `_HealStopped`, `_ModifierChanged`, `_GUIDDisappeared`.
- Heal-type flags: `DIRECT_HEALS`, `CHANNEL_HEALS`, `HOT_HEALS`/`OVERTIME_HEALS`, `BOMB_HEALS`,
  `CASTED_HEALS`, `ALL_HEALS`.
- **Pros:** amount **and** land-time **and** caster; includes HoTs/channels/modifiers; cross-player
  accurate. Everything a good indicator needs.
- **Cons:** only works if the user runs an addon that ships the lib (HealBars Classic /
  ClassicHealPrediction / VuhDo / ElvUI heal-prediction / etc.). Must handle "lib absent."

### D3 — Self-rolled combat-log detection (zero dependency, coarse)
- Trigger: `CLEU:SPELL_CAST_START`; keep casts where `destGUID == UnitGUID("player")` and
  `spellId ∈ heal-spell set`. Land-time ≈ cast start + `select(4, GetSpellInfo(spellId))/1000`.
- **Pros:** no external deps, catches *other players'* direct casts on you, gives caster + a
  usable land-time.
- **Cons:** **amount is unknown** (Classic ranks + variable +healing make a static table fragile —
  best we can do is a coarse per-rank estimate or show no number); misses HoTs and instant heals;
  reinvents a slice of LibHealComm badly. Fine as a *fallback*, not a primary.

### Recommended detection: **graceful-degrade chain**
1. **LibHealComm present →** use D2 (rich: amount + time + caster, all heal types).
2. **Else `UnitGetIncomingHeals` returns > 0 →** use D1 (amount only, direct casts).
3. **Else →** D3 combat-log detection (binary "heal inbound" + caster + land-time, no amount).

This makes the WA work for *everyone* (never dead), and automatically "levels up" to full fidelity
for users who run a heal-prediction addon. The `init.lua` picks the source once; the TSU reads
whichever is active. One caveat to accept: without LibHealComm, the amount is missing or direct-only.

---

## 3. UI conveyance options (how to show it)

Independent of the data source. Ordered roughly simplest → richest.

| # | Presentation | WA region | Needs amount? | Needs time? | Best for | Cost |
|---|---|---|---|---|---|---|
| **U1** | Numeric text `+3.2k` | `text` | yes | no | overheal avoidance | low |
| **U2** | Predicted-health **ghost bar** (overlay on a HP bar) | `aurabar`/`progresstexture` + `additionalProgress` | yes | no | the retail/VuhDo look | **high** |
| **U3** | Simple **icon flag** (green cross), optional stack = count | `icon` | no | no | "someone's healing me" | low |
| **U4** | **Glow / pulse** cue | `texture` + glow subregion | no | no | peripheral awareness | low |
| **U5** | **Incoming-heal timer bar** — caster + amount + fills to land-time | `aurabar` | optional | **yes** | reaction timing | med |
| **U6** | Combo (bar + number, HealBars style) | `dynamicgroup` of the above | yes | yes | full HUD | high |

Notes:
- **U2 (ghost bar)** is the polished heal-prediction visual and WA supports it via a bar state's
  `additionalProgress` (secondary overlay segment) — but it means **building/duplicating your own
  player health bar** and it's only worth it with **reliable amounts (⇒ LibHealComm)**. Overkill for
  a personal "is a heal coming" cue.
- **U5 (timer bar)** is the most *actionable* for a **self** indicator: for your own character the
  key question is usually "how big, and *how soon*, so do I press a defensive / stop my own cast /
  not waste a potion." Land-time is the standout datum, and it degrades gracefully (show the bar
  with no number when amount is unknown).
- **U3/U4** need no amount or time, so they work even on the weakest data source (D3) — good minimum.

---

## 4. Recommendation (critical take)

**For a personal "incoming heals on me" indicator, land-time matters more than a pixel-accurate
ghost bar.** A predicted-health overlay (U2) shines when you're the *healer* deciding whom to top;
for *yourself* the actionable signal is "a heal is inbound, ~this big, landing in ~Ns."

So I recommend:

- **v1 (build first):** **U5 incoming-heal timer bar** driven by the **§2 degrade chain**.
  - With LibHealComm: bar shows caster + amount + fills toward land-time; colour-shift if a heal
    modifier is active.
  - Without it: bar still shows caster + land-time (from cast start + cast time), amount hidden.
  - Add a subtle **glow (U4)** on show for peripheral catch. Anchor to `PRD`/player, or screen-center
    under your other bars.
- **v2 (optional upgrade, only if you run a heal-pred addon):** add the **U2 ghost bar** on a real
  player HP bar via `additionalProgress`, for the full VuhDo look.
- **Minimalist alternative (if you want near-zero footprint):** skip the bar, ship just **U3 icon +
  U4 glow** — "a heal is coming" with no numbers. Cheapest, works on any data source.

Net: **U5 + graceful-degrade detection** is the sweet spot — informative, actionable, never dead,
and it auto-upgrades for users with LibHealComm.

---

## 5. Decisions — LOCKED for v1

> Chosen 2026-07-15 (defaults per the recommendations above; LibHealComm confirmed `LOADED`).
> 1 → **(a) full degrade chain**, D2 LibHealComm ▸ D1 native (D3 combat-log deferred).
> 2 → **Yes** — standalone LibHealComm-4.0 installed and loaded, so v1 runs at full fidelity.
> 3 → **Icon** region for v1 (verified schema, imports clean); bar (U5) is a quick in-game reskin.
> 4 → **Both** land-time (native icon countdown) + amount (state field `amount`).
> 5 → **Include HoTs & channels** (comes free via the LibHealComm path).
> 6 → **Screen**, `CENTER`, `yOffset = -100`; retune in-game.
> 7 → **In a group** (`use_ingroup`); `unit = "player"`.
> 8 → Keep **`UI/IncomingHeals`**.

### Original decision menu (for reference)

1. **Detection posture** — (a) full degrade chain D2→D1→D3 [recommended], (b) LibHealComm-only
   (simplest code, but blank when the lib isn't loaded), or (c) native-only D1 (zero-dep but
   frequently blank/direct-only)?
2. **Do you already run a heal-prediction addon** (VuhDo / HealBars Classic / ClassicHealPrediction /
   ElvUI heal prediction)? If yes, LibHealComm is guaranteed present and v1 gets full fidelity for free.
3. **Presentation** — U5 timer bar [recommended] / U1 number / U3 icon+glow / U2 ghost bar / a combo?
4. **What to emphasize** — land-time (reaction) vs amount (overheal) vs both?
5. **Include HoTs & channels**, or direct casts only? (Only D2 can include HoTs/channels.)
6. **Placement & anchor** — screen position vs anchored to the player frame (`PRD`/`UNITFRAME`);
   size; where it sits relative to your existing bars.
7. **Load conditions** — always on, or only in group / only in combat / only on specific classes?
   (`unit="player"` throughout; §6 `load` options apply.)
8. **Catalog category/name** — keep `UI/IncomingHeals`, or move to `Utility/` or `Raid/`?

---

## 6. Proposed build sketch (once §5 is locked)

- **Region:** `aurabar` (U5) — or a `dynamicgroup` if we combine bar + icon/glow (U6).
- **Trigger:** one **TSU** (`custom_type="stateupdate"`), state `""`:
  - `init.lua` selects the data source once (LibHealComm handle or native or CLEU mode) and stashes
    it on `aura_env`.
  - `tsu.lua` builds the state: `show`, `progressType="timed"`, `duration`/`expirationTime` from
    land-time, `value`/amount as a custom field, `name` = caster, plus a `hasAmount` bool for text.
  - LibHealComm path also registers callbacks in `init.lua` to force re-evaluation on
    `HealComm_Heal*` events (WA custom events / `WeakAuras.ScanEvents`).
  - Events box (varies by source): `UNIT_HEAL_PREDICTION`, `CLEU:SPELL_CAST_START`,
    `CLEU:SPELL_CAST_SUCCEEDED`, `PLAYER_ENTERING_WORLD`, `FRAME_UPDATE` (throttled) as needed.
- **Custom text `%c`:** caster + amount ("Greater Heal · 4.2k") with graceful "amount unknown".
- **Files:** `aura.md`, `export.txt`, `code/init.lua`, `code/tsu.lua`, `code/custom_text.lua`.
- **Load:** `use_class`/`use_level`/`group`/`combat` per decision #7; `unit="player"`.
- **Caveat baked into `aura.md`:** amount fidelity depends on LibHealComm; without it the number is
  direct-cast-only (D1) or hidden (D3). Test in-game with a real healer before declaring done.

---

## 7. Extensions (later, not v1)

- **Absorbs:** `UnitGetTotalAbsorbs("player")` is also backported-but-limited on Era; could add a
  second overlay segment for shields once the heal indicator is solid.
- **Party/raid targets:** generalize `unit` beyond `"player"` to make a healer-side prediction HUD
  (this is where the U2 ghost bar per unit pays off) — a much bigger project.

---

## Sources

- [API UnitGetIncomingHeals (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/API_UnitGetIncomingHeals) ·
  [Incoming Healing/Absorb API for Classic (Blizzard forums)](https://eu.forums.blizzard.com/en/wow/t/incoming-healing-absorb-api-for-classic-wow/561358) ·
  [Heal Prediction & Absorb on TBC/Classic (WoWUIBugs #122)](https://github.com/Stanzilla/WoWUIBugs/issues/122)
- [ClassicHealPrediction (uses LibHealComm)](https://github.com/dev7355608/ClassicHealPrediction) ·
  [ClassicHealPrediction on CurseForge](https://www.curseforge.com/wow/addons/classichealprediction)
- [LibHealComm-4.0 (WowAce project)](https://www.wowace.com/projects/libhealcomm-4-0) ·
  [LibHealComm-4.0 API](https://www.wowace.com/projects/libhealcomm-4-0/pages/api) ·
  [LibHealComm-4.0 source](https://github.com/Carbohydron/heal-comm/blob/master/libs/LibHealComm-4.0/LibHealComm-4.0.lua)
- [UNIT_SPELLCAST_START (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/UNIT_SPELLCAST_START) ·
  [LibClassicCasterino (other-unit casts on Classic)](https://github.com/rgd87/LibClassicCasterino) ·
  [COMBAT_LOG_EVENT (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/COMBAT_LOG_EVENT)
- [WeakAuras TSU wiki (additionalProgress / state fields)](https://github.com/WeakAuras/WeakAuras2/wiki/Trigger-State-Updater-(TSU))
