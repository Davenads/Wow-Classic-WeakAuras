// cmp.js — deep-compare two JSON files for round-trip verification.
// Usage: node cmp.js a.json b.json
const fs = require("fs");

function load(p) {
    return JSON.parse(fs.readFileSync(p, "utf8"));
}

function stable(v) {
    if (Array.isArray(v)) return v.map(stable);
    if (v && typeof v === "object") {
        const out = {};
        for (const k of Object.keys(v).sort()) out[k] = stable(v[k]);
        return out;
    }
    return v;
}

const [a, b] = process.argv.slice(2);
if (!a || !b) {
    console.error("Usage: node cmp.js a.json b.json");
    process.exit(2);
}

const sa = JSON.stringify(stable(load(a)));
const sb = JSON.stringify(stable(load(b)));

if (sa === sb) {
    console.log("LOSSLESS — round-trip identical");
    process.exit(0);
} else {
    console.log("DIFF — round-trip mismatch");
    // find first divergence for a quick hint
    let i = 0;
    while (i < sa.length && i < sb.length && sa[i] === sb[i]) i++;
    console.log("first diff at char " + i);
    console.log("  A: ..." + sa.slice(Math.max(0, i - 40), i + 60));
    console.log("  B: ..." + sb.slice(Math.max(0, i - 40), i + 60));
    process.exit(1);
}
