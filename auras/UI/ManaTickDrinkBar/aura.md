# Mana Tick Drink Bar

A thin **spark line** that sweeps left → right across the player frame's mana bar and hits the
**far-right edge at the exact moment a mana-regen tick lands**, while you're **drinking**. Lets you
*stutter-step*: move between ticks, be stationary the instant a tick fires, and never waste regen.

| Field | Value |
|---|---|
| **Display name** | `Mana Tick Drink Bar` |
| **Category / folder** | `UI` |
| **Target flavor(s)** | Classic Era / SoD / Hardcore (mana ticks every 2.0 s). enUS buff names. |
| **Region type** | `aurabar` (Progress Bar) — overlays the Blizzard mana bar, spark = the line |
| **Min WeakAuras** | 5.x |
| **Import string** | `export.txt` — **fabricated** (see *Status* below). Round-trip verified, untested in-game. |

## Status

Code blocks (`code/init.lua`, `code/tsu.lua`) are authored and embedded. `export.txt` **is now
fabricated**: rather than hand-build a bar schema from scratch (the exact thing that has mis-imported
before — `unknown or incompatible element type`), it was cloned from a **known-good imported aura's
envelope** and the region transformed to `aurabar`, keeping every shared substructure WA already
accepted (`internalVersion 33`, `tocversion`, trigger meta, animation, load shape). `subRegions` is
left empty so WA's own import validator fills in the bar's default foreground/background — the same
way the repo's real icon/text auras import. The TSU is embedded at `triggers[1].trigger.custom`
(`custom_type: stateupdate`, events `UNIT_POWER_UPDATE UNIT_AURA PLAYER_ENTERING_WORLD`) and
`init.lua` at `actions.init.custom`. Decode round-trip is lossless.

**Still untested in-game** — import is the real test. If WA rejects it, the fallback is unchanged:
build the bar in-game from the recipe below (or hand me a native Progress Bar export to clone) and
re-export. Likely in-game touch-ups: spark color/width, exact width/height match to your mana bar,
frame strata, and the **Inverse** toggle if the spark sweeps the wrong way.

## The mechanic (why the line = the tick)

- Classic regenerates mana in **discrete ticks every 2.0 s** — a rolling server heartbeat.
- **Drinking** grants mana on each of those ticks; you're not casting, so the 5-second rule never
  applies while you drink. That makes the tick trivially observable: **mana just went up ⇒ a tick
  just fired.** We timestamp that instant (`tickAnchor`) and predict the next tick at `+2 s`.
- The bar is a 2 s **timed** progress re-anchored at every tick, so its spark starts at the left the
  moment a tick lands and reaches the right edge as the next tick lands. Re-anchoring each tick also
  corrects any drift and gives the "instant restart" snap.

> The wider "5-second rule" only matters *outside* drinking (Spirit regen pauses 5 s after a cast).
> This aura is **drinking-only** by request, so it ignores that case — it shows nothing unless the
> Drink/Refreshment buff is up.

## Building the region (in-game recipe)

1. `/wa` → **New** → **Progress Bar**. Name it `Mana Tick Drink Bar`.
2. **Trigger 1 → Type: Custom → Custom Trigger: Trigger State Updater (TSU).**
   - Paste `code/tsu.lua` into the code box.
   - **Events** box: `UNIT_POWER_UPDATE UNIT_AURA PLAYER_ENTERING_WORLD`
   - Check On: **Event**.
3. **Actions → On Init:** paste `code/init.lua`.
4. **Display (the "line" look):**
   - **Bar Color:** set alpha to **0** (transparent fill) so only the spark shows. (Or leave a faint
     fill if you like seeing the sweep body.) Background alpha **0** too.
   - **Spark:** **enabled**. Pick a bright color, width ~2–3, height ≈ the mana bar height.
   - **Inverse:** **ON** — this makes the spark travel **left → right** toward the tick. If it runs
     the wrong way, toggle this.
   - Hide the bar's text/icon (no icon, no timer text) so it reads as a bare moving line.
5. **Position → Anchored To:** **Select Frame** → type `PlayerFrameManaBar`. Set self-point and
   anchor-point both **CENTER** (offset 0,0), then match **width/height** to the mana bar (Classic
   default ≈ 119 × 12). Frame strata a notch above the unit frame so the line sits on top.
6. **Load:** Player Class → your mana users (or leave broad); optionally In Combat: **No**.
7. **Export** → paste the string into this folder's `export.txt` (single line, no trailing newline).

## Verify first (in-game — can't be checked from the repo)

1. **Buff name.** `IsDrinking()` matches buffs named **"Drink"** (enUS) and **"Refreshment"**
   (Cata/MoP conjured food). Confirm your drink shows one of those; edit the names in `init.lua`
   for other locales / odd items.
2. **Anchor frame.** `PlayerFrameManaBar` is the default Blizzard player mana bar. If you run a
   unitframe addon (ElvUI / Shadowed / SUF), anchor to that addon's mana bar frame instead, or use a
   standalone bar you position by hand.
3. **Sweep direction** reaches the RIGHT edge at the tick (toggle **Inverse** if reversed).
4. **Power type constant.** Uses `Enum.PowerType.Mana` (0 on Classic) via `UnitPower`.

## Code blocks

| File | WA block |
|---|---|
| `code/init.lua` | Actions ▸ On Init — power-type const, tick period, `IsDrinking` / mana helpers, state |
| `code/tsu.lua` | Trigger ▸ Custom ▸ Trigger State Updater (+ Events box listed in-file) |

## Behavior notes / limits

- **First sweep** appears only after the first observed tick (up to ~2 s after you sit) so the phase
  is real, not guessed. Sync then holds for the whole drink.
- **At full mana** the bar hides (nothing left to time).
- **Stop drinking** (move, get hit, buff drops) → sync is dropped and the bar hides immediately.
- Drinking-only by design; it does **not** track ticks during normal regen / the 5-second rule.

## Changelog

- 2026-07-08 — Initial authoring. `init.lua` (drink + mana-tick detection, 2 s cadence) and `tsu.lua`
  (re-anchored 2 s timed bar driving a spark). Overlay-on-mana-bar via `PlayerFrameManaBar` anchor,
  spark-line look, drinking-only, instant restart. Region not yet fabricated → `export.txt` pending
  an in-game build/export or a native Progress Bar to clone. Untested in-game.
- 2026-07-08 — Fabricated `export.txt` (`aurabar`, ~3.3 KB): cloned a known-good aura envelope,
  transformed region to a progress bar (transparent fill/bg, spark on, inverse on, `HORIZONTAL`,
  119×12, `SELECTFRAME`→`PlayerFrameManaBar` CENTER/CENTER, broad load), embedded `tsu.lua` as a
  Custom TSU + `init.lua` On Init, left `subRegions` empty for WA to fill. Decode round-trip lossless.
  Still untested in-game — import is the test.
