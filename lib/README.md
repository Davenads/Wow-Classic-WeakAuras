# lib/

Editor-support stubs. Nothing here is loaded in-game.

- **`WeakAuras-Stub_Vanilla.toc`** — an empty `.toc` so
  [Ketho's vscode-wow-api](https://github.com/Ketho/vscode-wow-api) extension activates
  and provides WoW API autocomplete + diagnostics across the repo. Update its
  `## Interface:` number to match your client (see `docs/classic-api.md` §4).

If you install the WoW API definitions locally, point `Lua.workspace.library` in
`.vscode/settings.json` at them for richer IntelliSense.
