// Guard (2026-10-21): the public game, its tests and docs use a fictional office. Fails if any word from a private deny-list
// returns. The list is stored as truncated SHA-256 hashes so this public file does not republish the names it guards against.
// Allowed exceptions: database catalog keys that are persistent identifiers, the nickname feature, and one English phrase.
"use strict";
const fs = require("fs"), path = require("path"), crypto = require("crypto"), assert = require("assert");
const DENY = new Set(["00f2e65596ab8c19", "0beca1c4f3e61feb", "1f254faa04cffa0d", "4516ee21fa678eee", "48523aea5533460e", "4b65c5426d398dff", "4f31fa50e5bd5ff4", "576c3cef48a76d9b", "61ea0803f8853523", "6cb09fe72a3471a7", "6e753a6b0a37cd10", "7e632fde8818b2ee", "7f0b629cbb9d794b", "96d9632f363564cc", "bb44bf07cf9a2db0", "e15cecbdf65083f8", "fceac367216ad8d1"]);
const ALLOW = [/\blast_nick\b/g, /\b\w+_extra\b/g, /\bnick(name|names|On)?\b/gi, /a chance to sign in/g, /\.pg-nick\w*/g, /setNick/g];
const ROOT = path.join(__dirname, "..");
const files = ["index.html", "AGENTS.md", "vercel.json"].concat(...["docs", "tests", "sql", "supabase"].map((d) => walk(path.join(ROOT, d))));
function walk(d) { if (!fs.existsSync(d)) return []; return fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => e.isDirectory() ? walk(path.join(d, e.name)) : [path.relative(ROOT, path.join(d, e.name))]); }
let hits = [];
for (const f of files) {
  if (f.endsWith("fictional-names.test.cjs") || !/\.(html|md|cjs|js|json|sql)$/.test(f)) continue;
  let t = fs.readFileSync(path.join(ROOT, f), "utf8"); for (const a of ALLOW) t = t.replace(a, " ");
  // words, and the parts of camelCase / snake_case / kebab-case identifiers (jessDrinksAt → jess, drinks, at)
  const parts = (t.replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase().match(/[a-z]+/g) || []);
  for (const w of new Set(parts)) if (DENY.has(crypto.createHash("sha256").update(w).digest("hex").slice(0, 16))) hits.push(f + ": " + w.length + "-letter denied word");
}
assert.deepStrictEqual(hits, [], "deny-listed words found:\n" + hits.join("\n"));
console.log("fictional-names: " + files.length + " files checked, no deny-listed words");
