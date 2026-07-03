# WoW Classic WeakAuras Workshop

A version-controlled workshop for authoring [WeakAuras](https://github.com/WeakAuras/WeakAuras2)
for **World of Warcraft Classic** (Classic Era / SoD / Hardcore / Cata Classic / MoP Classic).

WeakAuras are normally built entirely in-game and shared as opaque `!WA:2!` export
strings. This repo makes them reviewable and maintainable: each aura keeps its export
string **and** its custom Lua as separate, linted, diffable files, plus metadata and a
changelog.

## Start here

- **`CLAUDE.md`** — the operating guide. Read it before creating or editing an aura:
  directory layout, the authoring loop, Classic API rules, and custom-code conventions.
- **`auras/_TEMPLATE/`** — copy this folder to start a new aura.
- **`auras/README.md`** — the catalog of auras in this repo.

## Layout

| Path | What |
|---|---|
| `auras/` | One folder per aura: `export.txt` (the string), `code/*.lua` (custom Lua), `aura.md` (metadata + changelog). |
| `shared/` | Reusable Lua snippets shared across auras. |
| `tools/` | Node scripts to decode/encode `!WA:2!` strings for full-aura diffs. |
| `lib/` | Stub `.toc` so VS Code's WoW-API extension activates. |
| `docs/` | Deep references — see below. |

## Reference docs

- `docs/weakauras-reference.md` — aura data model, region types, triggers, TSU/state tables, conditions, load options, and the import/export string format.
- `docs/classic-api.md` — Classic flavors, API differences vs Retail, spell-ID gotchas, TOC/Interface numbers.
- `docs/workflow.md` — decode/encode tooling, wago & WeakAuras Companion, the `aura_env` sandbox, and VS Code setup.

## Editor setup (optional but recommended)

Install [Ketho's vscode-wow-api](https://marketplace.visualstudio.com/items?itemName=ketho.wow-api),
the [Lua Language Server](https://marketplace.visualstudio.com/items?itemName=sumneko.lua),
and [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig).
`.vscode/settings.json`, `.luacheckrc`, and `lib/`'s stub `.toc` are pre-seeded to make
autocomplete and linting work. Lint custom Lua with `luacheck auras shared`.

## Testing

This repo can lint Lua but cannot run WoW. An aura is only "done" once its `export.txt`
has been imported and verified **in-game**.
