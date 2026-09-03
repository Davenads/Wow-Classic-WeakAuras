// Headless test runner for the BGICHub corroboration engine.
// Loads the WoW-API stubs, the real code/init.lua, then the test suite into one
// fengari Lua state. init.lua is executed verbatim (never reimplemented), so the
// tests exercise exactly what ships in export.txt.
//
//   node bgic_test.cjs
//
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const base = "../auras/Battlegrounds/BGItemCallout/";
const chunks = [
    ["stubs", fs.readFileSync("test/bgic_stubs.lua", "utf8")],
    ["init.lua", fs.readFileSync(base + "code/init.lua", "utf8")],
    ["tests", fs.readFileSync("test/bgic_tests.lua", "utf8")],
];

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

for (const [name, src] of chunks) {
    const status = lauxlib.luaL_dostring(L, to_luastring(src));
    if (status !== lua.LUA_OK) {
        const err = lua.lua_tojsstring(L, -1);
        console.error(`\n[${name}] Lua error: ${err}`);
        process.exit(1);
    }
}
console.log("\nAll harness chunks ran clean.");
