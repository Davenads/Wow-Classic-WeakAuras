#!/usr/bin/env node
// Encode a JSON aura table back into a WeakAuras !WA:2! export string.
//
//   node encode.js path/to/aura.json            -> prints the !WA:2! string to stdout
//   node encode.js path/to/aura.json export.txt -> also writes it to export.txt
//
// The input JSON must be the full transmission envelope { m:"d", d:{...}, v, s, c },
// i.e. exactly what decode.js produced. See docs/weakauras-reference.md §7.
//
// WARNING: JSON is a lossy intermediate. Only re-encode JSON that decode.js produced in
// this repo (same library, same session) — hand-authored/edited JSON may produce a
// string WeakAuras rejects. Requires:  cd tools && npm install

const fs = require("fs");

let parser;
try {
    parser = require("node-weakauras-parser");
} catch (e) {
    console.error("Missing dependency. Run:  cd tools && npm install");
    process.exit(1);
}

async function main() {
    const inPath = process.argv[2];
    if (!inPath) {
        console.error("Usage: node encode.js <aura.json> [export.txt]");
        process.exit(1);
    }

    const table = JSON.parse(fs.readFileSync(inPath, "utf8"));
    const str = await parser.encode(table);

    const out = process.argv[3];
    if (out) {
        fs.writeFileSync(out, str);
        console.error(`Wrote ${out}`);
    } else {
        process.stdout.write(str + "\n");
    }
}

main().catch((err) => {
    console.error("Encode failed:", err.message || err);
    process.exit(1);
});
