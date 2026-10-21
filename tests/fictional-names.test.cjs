// The owner explicitly restored the original first-name cast on 2026-10-21.
// Keep the existing CI entry point; guard approved names instead of anonymizing them.
const fs=require('node:fs'),assert=require('node:assert/strict');
const source=fs.readFileSync('index.html','utf8');
const cast=JSON.parse(source.match(/const OFFICE_CAST=(.*?);\nfunction officeVisitorAt/s)[1]);
assert.deepEqual(cast.map(c=>[c.id,c.name]),[['nora','Jess'],['gus','John'],['rory','Kyle'],['theo','Matt'],['iris','Avah'],['bramblewick','Nick'],['pip','Rilie'],['wren','Joey']]);
assert(source.includes('label: "Dave\'s Office"'));
assert(source.includes('name: "Chance",'));
assert(source.includes('Joey\'s Cigar Lounge'));
assert(source.includes('name: "Patron the Ledger Lynx"'));
assert(source.includes('The Patron Group'));
assert(!/\b(Wes|Hal|Nora|Gus|Rory|Theo|Iris|Bramblewick|Pip|Wren|Lena|Fairweather|McNeil)\b|Example Property Co\.|rooftop lounge/i.test(source.replace(/\b(wes|hal|nora|gus|rory|theo|iris|bramblewick|pip|wren)\b/g,'')), 'No replacement display names or surnames');
console.log('PASS: approved first-name cast, owner, lounge, mascot and branding; stable internal cast IDs');
