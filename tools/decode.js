#!/usr/bin/env node
// Decode a WeakAuras !WA:2! export string into pretty-printed JSON.
//
//   node decode.js "!WA:2!..."                 -> prints JSON to stdout
//   node decode.js path/to/export.txt          -> reads the string from a file
//   node decode.js path/to/export.txt out.json -> also writes JSON to out.json
//
// The decoded object is the transmission envelope: { m:"d", d:<aura>, v, s, c }.
// The aura table is under `.d`; grouped children under `.c`. See
// docs/weakauras-reference.md §7.
//
// NOTE: JSON is a LOSSY view (it cannot represent every Lua type LibSerialize keeps).
// Use it for reading/diffing. To round-trip, re-encode with encode.js, which uses the
// same library. Requires:  cd tools && npm install

const fs = require("fs");

let parser;
try {
    parser = require("node-weakauras-parser");
} catch (e) {
    console.error("Missing dependency. Run:  cd tools && npm install");
    process.exit(1);
}

async function main() {
    const arg = process.argv[2];
    if (!arg) {
        console.error('Usage: node decode.js "<!WA:2!...>" | <export.txt> [out.json]');
        process.exit(1);
    }

    // Treat the arg as a file path if it exists, otherwise as the literal string.
    let str = arg;
    if (fs.existsSync(arg)) {
        str = fs.readFileSync(arg, "utf8").trim();
    }

    const decoded = await parser.decode(str);
    const json = JSON.stringify(decoded, null, 2);

    const out = process.argv[3];
    if (out) {
        fs.writeFileSync(out, json + "\n");
        console.error(`Wrote ${out}`);
    } else {
        process.stdout.write(json + "\n");
    }
}

main().catch((err) => {
    console.error("Decode failed:", err.message || err);
    process.exit(1);
});
