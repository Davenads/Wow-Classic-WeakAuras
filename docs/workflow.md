# Authoring & Version-Control Workflow

How to author WeakAuras in this repo (VS Code + git) and move them in/out of the game.
Covers the round-trip tooling, the `aura_env` sandbox, and editor setup.

---

## The core problem

WeakAuras are normally authored entirely in the in-game UI, and the only portable
artifact is an opaque `!WA:2!...` export string (serialized + compressed + base64 Lua
table). "In git with VS Code" therefore means one of two workflows:

1. **Code-only** (simplest): author the *custom Lua* in `.lua` files here, paste it into
   the aura's code blocks in-game via the **Expand** editor. The `export.txt` string is
   the source of truth for the whole aura; the `.lua` files are the readable, linted,
   diffable copies of the custom code.
2. **Full round-trip** (advanced): decode the whole `!WA:2!` string to a table with
   tooling (see below), edit, re-encode. Use for programmatic edits or full-aura diffs.

This repo supports both. Default to workflow 1; reach for 2 when you need it.

---

## 1. Getting code in and out of the game

- Every code box in the WA options UI has an **Expand** button → large editor with syntax
  highlighting and line numbers. This is the paste target for code authored here.
- **Snippets manager** — WA's built-in named-snippet store (toolbar in the code editor).
  Snippets export/import as their own strings; community ones at <https://wago.io/snippets>.
- There is **no official live-sync** between VS Code and a running aura's code blocks
  (feature request: WA issue #4523). Keep canonical Lua in this repo, paste on change.

---

## 2. Decode / encode tooling (full round-trip)

The string is `!WA:2!` + `EncodeForPrint(CompressDeflate(LibSerialize(table)))`.
See `docs/weakauras-reference.md` §7 for the exact format.

| Tool | Lang | Notes |
|---|---|---|
| **[node-weakauras-parser](https://github.com/Zireael-N/node-weakauras-parser)** | Node (native Rust) | **Most robust / lossless.** `encode()/decode()` + `encodeSync()/decodeSync()`. Same lineage as wago's tooling. Use this. |
| [python-weakauras-tool](https://github.com/geexmmo/python-weakauras-tool) | Python (Lupa) | Wraps the real WA libs; string ⇄ JSON. |
| [WeakAuras-Decoder](https://github.com/SoftCreatR/WeakAuras-Decoder) | PHP | Decode-only. |

Scripts wrapping `node-weakauras-parser` live in `tools/` (`decode.js`, `encode.js`).

**Round-trip caveat:** LibSerialize preserves Lua types (number vs string, mixed-key
tables) that JSON can't represent 1:1. Decode and re-encode with the **same** library.
Prefer `node-weakauras-parser`; treat JSON as a lossy view only.

---

## 3. wago.io & WeakAuras Companion

- **[wago.io](https://wago.io/)** — the community DB for sharable UI (WeakAuras, Plater,
  snippets). Publishing gives a short URL (`wago.io/xxxxx`) and tracks **version + changelog**
  per aura. Has an [API](https://docs.wago.io/) with keys.
- **[WeakAuras Companion](https://github.com/WeakAuras/WeakAuras-Companion)** — desktop
  (Electron) app that compares installed auras against wago and writes updates into a
  generated `WeakAurasCompanion` addon, surfacing an in-game "update available" prompt.
  Auto-fetches ~hourly. Newer web app: <https://addons.wago.io/app>.
- For this repo: mirror wago **URL + version + changelog** in each aura's `aura.md`.

---

## 4. Repository structure conventions

The most-referenced public collection is
[ahakola/WeakAuras](https://github.com/ahakola/WeakAuras): `ExportStrings/` (one `.txt`
per aura), `Pictures/`, and Markdown catalog files grouped by class/content. This repo
extends that with extracted, linted code and per-aura metadata. See the root `README.md`
and `auras/_TEMPLATE/` for our layout.

Track per aura: display name, wago URL, version, changelog, target flavor(s), and the
minimum WeakAuras version.

---

## 5. Editor setup (VS Code)

- **[Ketho's vscode-wow-api](https://github.com/Ketho/vscode-wow-api)** ([Marketplace](https://marketplace.visualstudio.com/items?itemName=ketho.wow-api)) — LuaLS annotation set for the WoW API. Auto-activates when a folder contains a `.toc`, auto-populates `Lua.diagnostics.globals`, gives autocomplete + signatures. We ship a stub `.toc` in `lib/` so it activates without a real addon.
- **[Lua Language Server (LuaLS)](https://github.com/LuaLS/lua-language-server)** — IntelliSense + EmmyLua annotations (`---@param`, `---@type`).
- **[Septh/vscode-wow-bundle](https://github.com/Septh/vscode-wow-bundle)** — better Lua/WoW + `.toc` grammar.
- **[EditorConfig](https://editorconfig.org/)** — obeys our `.editorconfig`.
- **luacheck** — static analysis; our `.luacheckrc` declares WoW + `aura_env`/`WeakAuras` globals.

`.vscode/settings.json` and `.luacheckrc` in this repo are pre-seeded for all of the above.

---

## 6. The custom-code environment (`aura_env` / sandbox)

Custom code runs in a **per-aura sandbox** that proxies global access through a metatable —
safe WoW API + standard Lua allowed, dangerous operations blocked.

**`aura_env` fields:**
- `aura_env.id` — the aura's name. `aura_env.uid` — internal unique id.
- `aura_env.cloneId` — per-clone id (relevant in TSU / dynamic-info auras).
- `aura_env.region` — the display region (frame) object; manipulate the visual directly.
- `aura_env.state` — the current active state table (`stacks`, `duration`, `expirationTime`, `icon`, `spellId`, text-replacement values…).
- `aura_env.states` — all triggers' states, indexed by trigger number (`aura_env.states[2]`); **not** accessible from within trigger functions.
- `aura_env.config` — the user's **Custom Options** values, keyed by the Option Key you define in Author Mode (`aura_env.config.<key>`); option groups nest. (WA 2.10+, nested groups 2.13+.)
- `aura_env.saved` — persistent storage that survives reload/logout.

**Two-stage init:** a **config stage** (safe subset: `id`, `uid`, `config` — used for
conditions/options) and a **full stage** (adds `region`, `state`, `states`, `saved`).

**Blocked in the sandbox:** `getfenv`, `setfenv`, `loadstring`, `pcall`/`xpcall`, and
dangerous APIs (`SendMail`, `SetTradeMoney`, `EditMacro`, `CreateMacro`, `GuildDisband`),
plus sensitive tables (`SlashCmdList`, `WeakAurasSaved`, `WeakAurasOptions`). Curated
helpers are exposed for unit auras, group iteration, and string formatting.

Refs: [aura_env wiki](https://github.com/WeakAuras/WeakAuras2/wiki/aura_env) ·
[Custom Options](https://github.com/WeakAuras/WeakAuras2/wiki/Custom-Options) ·
[AuraEnvironment.lua](https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/AuraEnvironment.lua) ·
[sandboxing (DeepWiki)](https://deepwiki.com/WeakAuras/WeakAuras2/2.4-aura-environment-and-sandboxing)

---

## Sources

- [Lua Dev Environment (wiki)](https://github.com/WeakAuras/WeakAuras2/wiki/Lua-Dev-Environment) · [CONTRIBUTING](https://github.com/WeakAuras/WeakAuras2/blob/main/CONTRIBUTING.md) · [Custom Code Blocks](https://github.com/WeakAuras/WeakAuras2/wiki/Custom-Code-Blocks) · [Useful Snippets](https://github.com/WeakAuras/WeakAuras2/wiki/Useful-Snippets)
- Tools: [node-weakauras-parser](https://github.com/Zireael-N/node-weakauras-parser) · [python-weakauras-tool](https://github.com/geexmmo/python-weakauras-tool) · [WeakAuras-Companion](https://github.com/WeakAuras/WeakAuras-Companion)
- Editor: [vscode-wow-api](https://github.com/Ketho/vscode-wow-api) · [vscode-wow-bundle](https://github.com/Septh/vscode-wow-bundle) · [ahakola/WeakAuras](https://github.com/ahakola/WeakAuras)
