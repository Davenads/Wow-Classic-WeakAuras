# Archived: 2-AGM dodge-stacking engine

`init.2agm.lua` is the full controller `init.lua` as it stood at commit **`15cdac7`** (the last
2-AGM build), preserved verbatim so the feature can be revived without spelunking git.

## Why it's here

Shipped on 2026-07-08, `code/init.lua` was reverted to **`af82692`** — the last known-good,
in-game-tested **single-AGM** engine — because the 2-AGM work regressed 1-AGM behaviour. The
2-AGM feature was not an additive branch: commit `d9ffe4f` rewrote the core `Desired()` (set →
ordered list) and `Apply()` (multiset `claim`) for *all* cases, dropping two guarantees the
set-based engine had for free, then three follow-ups (`d74091f` hysteresis, `0d52018` re-equip
guard, `15cdac7` thrash-breaker + instrumentation) tried to reconstruct them. See `plan.md`
§13-§16 for the full design + post-mortem.

## What's in `init.2agm.lua`

- `AgmCount()` — bag + worn copies; `>= 2` (with `stackAgm` on) enters 2-AGM mode.
- `Desired()` returns an ordered, duplicate-capable `{id1, id2}`; Model B branch keeps >=1 AGM
  worn and fills the other slot with the best on-use trinket within `swapBackAt`, else `{A, A}`.
- `Apply()` multiset `claim` + `wornCount < wantedCount` re-equip guard + `okToSwap` hysteresis
  + a 10 s thrash-breaker backoff and per-engine `Dbg()` instrumentation (`TRK_DEBUG`).
- Extra config: `swapBuffer`, `swapMargin`, `stackAgm` (+ derived `swapBackAt`).

## How to revive (surgically, if we tackle it again)

Do **not** wholesale-restore this file — that reintroduces the regression risk. Instead keep the
current set-based 1-AGM engine untouched and gate the ordered-list/multiset path behind
`AgmCount() >= 2` only, so a single AGM never enters the 2-AGM code. Re-embed into `aura.json`
**and** the `package.json` `Trinket Swap Engine` child, re-encode `export.txt` + `package.txt`,
round-trip verify, then test on a 2-AGM character before trusting it.
