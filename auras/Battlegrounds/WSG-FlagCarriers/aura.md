# WSG Flag Carriers

Shows the name of the player currently carrying each flag in Warsong Gulch, at top-center
of the screen next to the capture scores. Alliance carrier (holding the Horde flag) on the
left in blue; Horde carrier (holding the Alliance flag) on the right in red. Each name
appears only while that flag is actually being carried.

| Field | Value |
|---|---|
| **Display name** | `WSG Flag Carriers` |
| **Category / folder** | `Battlegrounds` |
| **Target flavor(s)** | Classic Era / SoD / Hardcore (see note for Cata/MoP) |
| **Min WeakAuras version** | 5.x |
| **wago URL** | n/a |
| **Region type** | `dynamicgroup` containing a `text` child |

## Purpose

In Warsong Gulch each team scores by carrying the **enemy** flag to their base. You can
only scan auras on your own team, so the enemy carrier is invisible to `UnitAura` across
the map. The game instead announces every flag pickup/drop/return/capture to everyone via
`CHAT_MSG_BG_SYSTEM_*` system messages. This aura parses those messages and displays both
carriers' names near the score counters.

Placement maps each name to its team's score: a team's score increments from capturing the
enemy flag its own player carries, so the **Alliance** score (left) pairs with the Alliance
player holding the **Horde** flag, and the **Horde** score (right) pairs with the Horde
player holding the **Alliance** flag.

## Triggers

Single **Trigger State Updater** custom trigger on the child text aura. See
`code/tsu.lua`. It maintains two states:

- `horde_flag` (index 1, left, blue) — the Alliance player carrying the Horde flag.
- `alliance_flag` (index 2, right, red) — the Horde player carrying the Alliance flag.

**Events** (paste into the trigger's Events box, one per line):

```
CHAT_MSG_BG_SYSTEM_ALLIANCE
CHAT_MSG_BG_SYSTEM_HORDE
CHAT_MSG_BG_SYSTEM_NEUTRAL
PLAYER_ENTERING_WORLD
```

**Custom Variables** (paste into the trigger's Custom Variables box) — optional, only
needed if you later add Conditions referencing these fields:

```lua
{
  carrier = "string",
  team    = "string",
}
```

The colored display string is baked into the built-in `name` field, so the text just uses
`%n` — no custom-text function required.

## In-game build steps

1. **New aura → Dynamic Group.** This is the container you position at top-center.
   - Group tab: **Grow** = `Horizontal (Centered)`, **Space** ≈ 60, **Sort** = `ascending`
     by the state `index` (Alliance left, Horde right).
   - Position: **Anchored to** `Screen/Parent`, **To** `TOP`, self point `TOP`,
     Y offset ≈ `-18` (nudge to sit right by the 0/3 · 0/3 counters).
2. **Add a child → Text** (right-click the group → New → Text, or create Text and drag it
   into the group).
3. On the **child text** aura:
   - **Trigger 1** → Type `Custom` → Custom Trigger `Trigger State Updater` → paste
     `code/tsu.lua`. Set the **Events** and **Custom Variables** boxes as above.
   - **Display** → Text: `%n`. Font size ≈ 16, outline `Thick`. (Color is baked into the
     name string, so leave the text color white.)
   - **Load** → check **Zone** = `Warsong Gulch` (and optionally **Instance type** = `PvP`)
     so the aura only runs in WSG.
4. Join a WSG match and confirm names appear/clear on pickups, drops, returns, and captures.
5. **Export** the Dynamic Group (which exports the child too) and paste the `!WA:2!` string
   into `export.txt` on a single line.

## Testing notes

- Verify: on "The Horde Flag was picked up by X!" a blue name appears left; on a drop/return
  it clears; on a capture both clear. Repeat for the Alliance flag (red, right).
- Locale: the message patterns in `code/tsu.lua` are enUS. On another client locale, edit
  the `:match`/`:find` patterns — they're the only locale-specific part.
- Known limitation: a carrier who grabbed the flag **before** you zoned in won't be known
  until the next flag event (no message was sent to you). Optional enhancement: additionally
  scan your own raid for the flag aura (Warsong Flag / Silverwing Flag — verify current IDs
  on the Classic Wowhead) to recover your team's carrier on join.
- Cata/MoP Classic: the same `CHAT_MSG_BG_SYSTEM_*` mechanism applies; only confirm the
  message wording matches the patterns.

## Changelog

- 2026-07-03 — Initial implementation: TSU chat-parser + dynamic-group layout. Code
  complete; pending in-game build and export string.
