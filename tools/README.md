# tools/

Scripts to decode/encode WeakAuras `!WA:2!` export strings so whole auras can be diffed
in version control. Built on
[node-weakauras-parser](https://github.com/Zireael-N/node-weakauras-parser) (the most
robust, lossless encoder — same lineage as wago's own tooling).

## Setup

```sh
cd tools
npm install
```

## Usage

```sh
# Decode an export string (or an export.txt file) to readable JSON:
node decode.js ../auras/Mage/FrostboltProc/export.txt aura.json

# Re-encode edited JSON back to a !WA:2! string:
node encode.js aura.json ../auras/Mage/FrostboltProc/export.txt
```

The decoded object is the transmission envelope `{ m:"d", d:<aura>, v, s, c }` — the aura
table is under `.d`, grouped children under `.c` (see `docs/weakauras-reference.md` §7).

## Important caveats

- **JSON is lossy.** LibSerialize preserves Lua types (number vs string, mixed-key
  tables) that JSON can't. Use JSON to **read and diff**, not as the authoritative form.
- **Only re-encode JSON that `decode.js` produced.** Round-tripping through the same
  library is safe; hand-authored JSON may produce a string WeakAuras rejects.
- The **`export.txt` string remains the source of truth** for importing an aura. `aura.json`
  is a convenience view — regenerate it after changing `export.txt`.

Alternative tooling if you prefer Python:
[python-weakauras-tool](https://github.com/geexmmo/python-weakauras-tool).
