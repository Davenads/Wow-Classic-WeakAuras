// Re-embed updated code/*.lua into ManaTickDrinkBar aura.json + refresh trigger events,
// then re-encode export.txt.
const fs = require('fs');
const A = '../auras/UI/ManaTickDrinkBar/';
const read = p => fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n').replace(/\n$/, '');

const j = JSON.parse(fs.readFileSync(A + 'aura.json', 'utf8'));
const d = j.d;

d.actions.init.custom = read(A + 'code/init.lua');
d.triggers[1].trigger.custom = read(A + 'code/tsu.lua');
d.triggers[1].trigger.events = 'UNIT_POWER_UPDATE PLAYER_ENTERING_WORLD';

fs.writeFileSync(A + 'aura.json', JSON.stringify(j, null, 1));
console.log('re-embedded init=' + d.actions.init.custom.length + ' tsu=' + d.triggers[1].trigger.custom.length + ' events="' + d.triggers[1].trigger.events + '"');
