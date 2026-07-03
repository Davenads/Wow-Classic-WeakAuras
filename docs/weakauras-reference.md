# WeakAuras 2 — Technical Reference

Deep reference for the data model, triggers, conditions, custom code, and the
import/export string format. CLAUDE.md links here; read this when you need the
exact field names or behavior.

Field names below reflect the real saved-variable model
(`WeakAurasSaved.displays[id]`), verified against `Transmission.lua` and the
WeakAuras wiki. Sources are listed at the bottom.

---

## 1. Aura data model

Every aura is a Lua table under `WeakAurasSaved.displays[id]`. On export it is
this table (plus children) that gets serialized.

| Field | Type | Purpose |
|---|---|---|
| `id` | string | Human-readable display name. **Unique per account**; used as the table key. |
| `uid` | string | Short base64 unique id, **stable across renames**. Used for parent/child linkage and import dedup. |
| `regionType` | string | Display type — see §2. |
| `triggers` | table | Array of triggers + combination logic (§3). |
| `conditions` | array | Conditional property changes (§5). |
| `load` | table | Load conditions — when the aura is active at all (§6). |
| `actions` | table | Custom actions/messages/sounds/glow with sub-tables `init`, `start`, `finish` (§4). |
| `animation` | table | Animation config: `start`, `main`, `finish`. |
| `config` | table | User-defined config values (the `aura_env.config` values). |
| `authorOptions` | array | Schema for the Custom Options UI (sliders, toggles, selects). |
| `information` | table | Metadata: author notes, `forceEvents`, `debugLog`, wago URL, `saved`. |
| `parent` | string/nil | `id` of the parent group (nil for top-level). |
| `controlledChildren` | array | (Groups only) ordered list of child `id`s. |
| `internalVersion` | number | Schema/migration version. **Leave as WA sets it.** |
| region-specific | mixed | `xOffset`, `yOffset`, `width`, `height`, `selfPoint`, `anchorPoint`, `anchorFrameType`, `frameStrata`, `color`, `alpha`, `scale`, `font`, `fontSize`, `texture`, `cooldown`, `icon`, `desaturate`, … |

`anchorFrameType` values: `SCREEN`, `PRD`, `MOUSE`, `SELECTFRAME`, `NAMEPLATE`,
`UNITFRAME`, `CUSTOM`.

---

## 2. Region types (`regionType`)

- **`icon`** — square texture + optional cooldown swipe, stack text, glow. Most common (buffs/debuffs/cooldowns). Fields: `icon`, `cooldown`, `cooldownSwipe`, `cooldownEdge`, `desaturate`, `keepAspectRatio`, `zoom`.
- **`aurabar`** — custom progress bar with optional embedded icon, spark, gradient, text. Fields: `texture`, `orientation`, `barColor`, `backgroundColor`, `icon_side`, `spark`.
- **`text`** — pure dynamic text with placeholders/format/custom `%c`. Fields: `displayText`, `font`, `fontSize`, `outline`, `justify`.
- **`texture`** — static image for the aura's duration. Fields: `texture`, `blendMode`, `rotation`, `color`.
- **`progresstexture`** — texture that fills over progress (radial/linear/clockwise). Fields: `foregroundTexture`, `backgroundTexture`, `progressSource`, `orientation`, `compress`.
- **`model`** — 3D model. Fields: `model_path`/`model_fileId`, `modelIsUnit`, camera transform.
- **`stopmotion`** — sprite-sheet frame animation (needs the **WeakAurasStopMotion** addon). Fields: `foregroundTexture`, `rows`, `columns`, `frameNumbers`, `animationType`.
- **`group`** — static container; children keep absolute offsets, move/scale/show together.
- **`dynamicgroup`** — auto-layout container; arranges visible children (row/column/grid/circle) and reflows on show/hide. Fields: `grow`, `align`, `space`, `stagger`, `rotation`, `sort`, `limit`, `useAnchorPerUnit`.

---

## 3. Trigger system

### 3.1 `triggers` table

```lua
data.triggers = {
  disjunctive        = "all" | "any" | "custom",   -- how triggers combine
  customTriggerLogic = "return trigger[1] and (trigger[2] or trigger[3])",
  activeTriggerMode  = -1,                          -- which trigger supplies dynamic info (-1 = first active)
  [1] = {
    trigger = {
      type        = "aura2" | "unit" | "spell" | "item" | "custom" | "event",
      event       = "Health" | "Cooldown Progress (Spell)" | ...,  -- prose name for status/event
      custom_type = "event" | "status" | "stateupdate",            -- only when type == "custom"
      events      = "PLAYER_REGEN_DISABLED\nUNIT_HEALTH:player",    -- custom event registration
      custom      = "function(event, ...) ... end",
      customVariables = "{ myField = 'number' }",                  -- declares state fields
    },
    untrigger = { custom = "function(event, ...) ... end" },
  },
}
```

- `disjunctive`: `"all"` (AND), `"any"` (OR), `"custom"` (evaluate `customTriggerLogic`).
- `activeTriggerMode`: which trigger's state supplies icon/name/duration/stacks. `-1` = first active.

### 3.2 Built-in trigger types (from `Prototypes.lua`)

Aura (Aura2), Health, Power/Alternate Power, Cooldown Progress (Spell)/(Item)/(Equipment Slot),
Spell Known, Action Usable, Spell Cast Succeeded, Cast, Combat Log, Unit Characteristics,
Spell Activation Overlay, Item Equipped/Set/Type, Weapon Enchant, Threat Situation,
Global Cooldown, Swing Timer, Totem, Stance/Form, Range Check, Faction/Reputation,
Currency, Character Stats, and more. (Some are flavor-specific — see `docs/classic-api.md`.)

### 3.3 event vs status vs custom — the core distinction

- **Status triggers** — values computable on demand (health, aura present, cooldown remaining). WA sends a synthetic **`STATUS`** event on login/reload/options-close so they evaluate immediately, and also register real events to know when to re-check.
- **Event triggers** — transient events carrying info (a hit landed, a cast succeeded). Fire only on a registered event; do **not** get `STATUS`. Hide via `autoHide`/duration or a custom untrigger.
- **Custom triggers** (`type="custom"`), sub-typed by `custom_type`:
  - `"event"` — event-driven custom function.
  - `"status"` — status custom function (gets `STATUS`).
  - `"stateupdate"` — **Trigger State Updater (TSU)**, the advanced multi-state mode.

Synthetic events for custom triggers: **`STATUS`** (load/options-close), **`OPTIONS`** (options preview),
**`FRAME_UPDATE`** (every frame — OnUpdate logic; use sparingly). Event-name filters in the `events` box:
- Unit filter: `UNIT_SPELLCAST_SUCCEEDED:player`, multi-unit `UNIT_TARGET:boss1:boss2`.
- CLEU subevent filter (WA 2.12.4+): `CLEU:SPELL_CAST_START`.
- Watch another trigger: `TRIGGER:2` → fn receives `(event, updatedTriggerNumber, updatedTriggerStates)`.

### 3.4 Simple custom trigger + untrigger (non-TSU)

```lua
-- Custom trigger: return true = activate, false = deactivate
function(event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        return true
    elseif event == "PLAYER_REGEN_ENABLED" then
        return false
    end
end

-- Custom untrigger (optional; separate hide logic): return true = deactivate
function(event)
    return event == "PLAYER_REGEN_ENABLED"
end
```

Optional "Dynamic Information" functions (only if the region needs them):
`duration()` → `duration, expirationTime` (timed) or `value, total, true` (static);
`name()` → string; `icon()` → texture; `stacks()` → number; `texture()` → path.

### 3.5 Trigger State Updater (TSU) and the state table

TSU (`custom_type="stateupdate"`) drives **many** independent states ("clones"), each
rendered as its own region in a dynamic group.

```lua
function(allstates, event, ...)
    -- allstates keyed by cloneId (any string; "" for the single/base state)
    allstates[cloneId] = {
        show           = true,          -- required to display
        changed        = true,          -- REQUIRED so WA re-reads this state
        progressType   = "timed",       -- or "static"
        duration       = dur,           -- timed
        expirationTime = GetTime() + dur,
        autoHide       = true,          -- auto-remove at expiration
        value          = cur,           -- static
        total          = max,           -- static
        name           = "Label",       -- %n
        icon           = 134400,        -- fileID or path
        stacks         = 3,             -- %s
        index          = 1,             -- sort order in dynamic group
        -- any custom field is also allowed (exposed to text/conditions)
    }
    return true   -- tells WA to process state changes
end
```

State fields WA reads: `show`, `changed`, `progressType`, `duration`, `expirationTime`,
`autoHide`, `value`, `total`, `paused`, `remaining`, `name`, `icon`, `stacks`, `index`,
`additionalProgress`. Remove a clone with `allstates[cloneId] = nil`. **Always set
`changed = true` on any modified state and `return true`.** The returned boolean does not
itself set activation — the states do.

> Verify the TSU helper method names (`allstates:Remove`/`:RemoveAll`) and the
> `additionalProgress` shape against the live TSU wiki page before relying on them —
> the researcher captured those from a partial render.

Expose custom state fields to Conditions/text via **Custom Variables**:

```lua
{
  myNumber = "number",
  myBool   = true,
  mySelect = { display = "Mode", type = "select", values = { a = "A", b = "B" } },
}
```

---

## 4. Custom code hooks

All custom code runs in a sandboxed environment with `aura_env` as context. See
`docs/workflow.md` §6 for the full `aura_env` / sandbox reference.

| Hook | Location | Signature / notes |
|---|---|---|
| Custom trigger | Triggers | `function(event, ...)` → bool, or TSU `function(allstates, event, ...)` |
| Custom untrigger | Triggers | `function(event, ...)` → bool (deactivate) |
| Dynamic info fns | Triggers | `duration()/name()/icon()/stacks()/texture()` |
| Custom Variables | Triggers | table declaring state field types |
| Custom trigger logic | Triggers | `return trigger[1] and trigger[2]` |
| **Custom text `%c`** | Display (text) | Each `%c` maps positionally to one `function() return "..." end` |
| Custom text format | Display | Per-placeholder format functions |
| On Init | Actions (`actions.init.custom`) | Runs once on load/config change — setup, helpers |
| On Show | Actions (`actions.start.custom`) | Runs each time the aura shows; `aura_env.region` available |
| On Hide | Actions (`actions.finish.custom`) | Runs when the aura hides |
| Custom condition code / check | Conditions | "Custom Code" runs Lua on match; "Custom Check" is `function() return bool end` |
| Custom anchor | Position | `anchorFrameType="CUSTOM"` + fn returning a frame |
| Custom animation | Animations | `function(progress, start, delta) return value end` |

Text placeholders: `%p` (progress/remaining), `%t` (total), `%n` (name), `%i` (icon),
`%s` (stacks), `%c` (custom fn). Multi-trigger: `%2.p`, `%2.n`; TSU custom field: `%myNumber`.

---

## 5. Conditions system

Conditions change region **properties** based on trigger state or custom checks.

```lua
data.conditions = {
  [1] = {
    check = {
      trigger  = 1,                -- which trigger's state (-1 = global/any)
      variable = "expirationTime", -- state field, or "customcheck" for a Lua fn
      op       = "<",
      value    = 5,
      -- optional nested: checks = { ... } for AND/OR groups
    },
    changes = {
      [1] = { property = "alpha",       value = 0.5 },
      [2] = { property = "sub.1.color", value = { 1, 0, 0, 1 } }, -- sub-region property
      [3] = { property = "chat",        value = { ... } },        -- message/sound/custom code
    },
    linked = false,   -- if true, ANDed with previous condition
  },
}
```

- `variable = "customcheck"` uses a `function() return bool end`.
- Properties: `alpha`, `color`, `scale`, `glow`, `desaturate`, `xOffset`/`yOffset`,
  sub-region `sub.N.*`, plus non-visual `sound`, `chat`, `customcode`, `glowexternal`.
- Property reversion is automatic when no condition sets a given property.

---

## 6. Load conditions

`load` decides whether the aura is active at all — unloaded auras cost zero runtime.
Each check is gated by a paired `use_<option>` boolean, e.g.
`use_class = true, class = { single = "MAGE" }` or
`use_level = true, level = 60, level_operator = ">="`.

- **Identity**: `class`, `spec`, `talent`/`talent2`/`talent3`, `pvptalent`, `role`, `race`, `faction`, `player`, `namerealm`.
- **Level**: `level`, `effectiveLevel`, `class_and_spec`.
- **Zone/instance**: `zone`, `zoneId`, `zonegroup`, `instance_type`, `difficulty`/`instance_difficulty`, `size`, `affixes`.
- **Group**: `group`, `groupSize`, `grouptype`, `ingroup`.
- **State**: `combat`, `never`, `vehicle`, `petbattle`, `mounted`, `alive`, `resting`, `dragonriding`.
- **Item**: `itemequiped`, `itemtypeequipped`, `item_bonusid_equipped`.

> Classic caveat: `spec` and `pvptalent` are meaningful only on flavors with the
> specialization system (Cata/MoP Classic). On Classic Era/SoD/Hardcore use `talent`.
> See `docs/classic-api.md`.

---

## 7. Import / Export string format

Pipeline: **serialize → compress → print-safe encode**, with a version prefix.
Confirmed against `Transmission.lua`.

### 7.1 Encode (current, version 2)

```lua
local serialized = LibSerialize:SerializeEx({ errorOnUnserializableType = false }, inTable)
local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
local encoded    = LibDeflate:EncodeForPrint(compressed)   -- chat/export box
return "!WA:2!" .. encoded
```

### 7.2 Version prefixes (decoder matches `^(!WA:%d+!)(.+)$`)

| Version | Prefix | Serializer | Compression | Encoding |
|---|---|---|---|---|
| 0 (legacy) | *(none)* | AceSerializer-3.0 | LibCompress | LibCompress Base64 |
| 1 | `!` | AceSerializer-3.0 | LibDeflate | `DecodeForPrint` |
| **2 (current)** | `!WA:2!` | **LibSerialize** | LibDeflate | `DecodeForPrint` |

### 7.3 Wrapped payload envelope

`Private.DisplayToString` wraps the aura(s) before encoding:

```lua
transmit = {
  m = "d",              -- message type: "display"
  d = <auraData table>, -- the aura data (root)
  v = 1421 | 2000,      -- transmission format version (2000 if subgroups present)
  s = "<addonVersion>",
  c = { ... },          -- controlled children data (groups)
}
```

So a decoded export is `{ m="d", d={...}, v=..., s=..., c={...} }` — the aura table is
under `.d`, grouped children under `.c`.

### 7.4 Round-trip caveat

LibSerialize preserves Lua types (number vs string, mixed-key tables) that JSON cannot
represent 1:1. For lossless version control, decode/encode with the **same** library —
prefer `node-weakauras-parser`. Treat JSON as a lossy intermediate only. See
`docs/workflow.md` §2 and `tools/`.

---

## 8. Groups and dynamic groups

- A `group`/`dynamicgroup` holds `controlledChildren = { "ChildA", "ChildB" }` (ordered).
- Each child has `parent = "<GroupId>"` and its own `uid`. Order = render/sort order.
- **Static `group`**: children keep absolute offsets; group moves/scales/shows them together.
- **Dynamic `dynamicgroup`**: children auto-arranged (`grow` = LEFT/RIGHT/UP/DOWN/HORIZONTAL/VERTICAL/CIRCLE/GRID with `align`, `space`, `stagger`, `limit`); child offsets ignored. Reflows when children (e.g. TSU clones) show/hide. `sort` + each state's `index` control order.
- On export, a group + all descendants serialize together (`transmit.d` root, `transmit.c` children); on import WA remaps `uid`s and rebuilds `parent`/`controlledChildren`.
- Groups can nest.

---

## Sources

- Wiki: [Custom Triggers](https://github.com/WeakAuras/WeakAuras2/wiki/Custom-Triggers) · [Trigger State Updater (TSU)](https://github.com/WeakAuras/WeakAuras2/wiki/Trigger-State-Updater-(TSU)) · [Useful variables and functions](https://github.com/WeakAuras/WeakAuras2/wiki/Useful-variables-and-functions-within-WeakAuras) · [aura_env](https://github.com/WeakAuras/WeakAuras2/wiki/aura_env) · [Editing Aura Regions](https://github.com/WeakAuras/WeakAuras2/wiki/Editing-Aura-Regions)
- Source: [Transmission.lua](https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Transmission.lua) · [Prototypes.lua](https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Prototypes.lua) · [AuraEnvironment.lua](https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/AuraEnvironment.lua)
- DeepWiki (code-derived): [Region Types](https://deepwiki.com/WeakAuras/WeakAuras2/3.1-region-types) · [Region Configuration](https://deepwiki.com/WeakAuras/WeakAuras2/4.2-region-configuration) · [Trigger & Condition Configuration](https://deepwiki.com/WeakAuras/WeakAuras2/4.3-trigger-and-condition-configuration)
- Format issue: [#3384](https://github.com/WeakAuras/WeakAuras2/issues/3384)
