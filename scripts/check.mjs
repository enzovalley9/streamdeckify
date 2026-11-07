// The checks that keep this repo honest. `npm run check` runs them, and so does CI.
// 1. Every prompt keeps its ground rules.
// 2. Nothing private: LAN addresses, MAC addresses, personal paths.
// 3. No em or en dashes in the copy.
// 4. Every path named in AGENTS.md exists.
// 5. Wall photos stay under 1 MB.
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const problems = [];
const fail = (file, msg) => problems.push(`${relative(root, file)}: ${msg}`);

const walk = (dir, out = []) => {
  for (const name of readdirSync(dir)) {
    if (['node_modules', '.git', 'dist', '.astro'].includes(name)) continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
};
const files = walk(root);

// 1. Ground rules in every prompt.
const MUST = [
  [/^## Ground rules/m, 'its "## Ground rules" section'],
  [/^## Undo/m, 'its "## Undo" section'],
  [/token/i, 'the random token'],
  [/fixed list/i, 'the fixed list of actions'],
  [/ask me/i, 'asking before changing anything'],
  [/local network|my Wi-Fi|my LAN/i, 'staying on the local network'],
];
const prompts = readdirSync(join(root, 'prompts')).filter((n) => n.endsWith('.md'));
for (const name of prompts) {
  const file = join(root, 'prompts', name);
  const text = readFileSync(file, 'utf8');
  for (const [re, what] of MUST) if (!re.test(text)) fail(file, `the prompt lost ${what}`);
}

// 2 and 3. Private data and dashes, line by line.
const TEXT = /\.(md|astro|ts|mjs|yml|yaml|json|css|txt)$/;
const IPV4 = /(?<![\d.])(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?![\d.])/g;
const isPrivate = (a, b) =>
  a === 10 || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 169 && b === 254) || (a === 100 && b >= 64 && b <= 127);
const MAC = /\b[0-9a-f]{2}(?::[0-9a-f]{2}){5}\b/i;
const HOME = /\/Users\/[A-Za-z]|\/home\/[a-z][a-z0-9_-]*\//;
for (const file of files.filter((f) => TEXT.test(f) && !f.endsWith('package-lock.json'))) {
  readFileSync(file, 'utf8')
    .split('\n')
    .forEach((line, i) => {
      const at = `line ${i + 1}`;
      for (const m of line.matchAll(IPV4)) {
        const [a, b, , d] = m.slice(1).map(Number);
        if (isPrivate(a, b) && d !== 0 && d !== 255) fail(file, `${at}: a real-looking LAN address (${m[0]}). Write 192.168.1.x instead.`);
      }
      if (MAC.test(line)) fail(file, `${at}: something that looks like a MAC address.`);
      if (HOME.test(line)) fail(file, `${at}: a personal path.`);
      if (/[\u2013\u2014]/.test(line)) fail(file, `${at}: an em or en dash. Use a comma, a colon or a full stop.`);
    });
}

// 4. Paths named in AGENTS.md.
const agents = join(root, 'AGENTS.md');
for (const [, path] of readFileSync(agents, 'utf8').matchAll(/`([\w.-]+\/[\w./-]*|[\w-]+\.(?:md|ts|mjs|astro|yml|json))`/g)) {
  if (!existsSync(join(root, path))) fail(agents, `names \`${path}\`, which doesn't exist.`);
}

// 5. Wall photos.
for (const file of files.filter((f) => f.includes('/src/content/decks/') && /\.(jpe?g|png|webp)$/i.test(f))) {
  const kb = Math.round(statSync(file).size / 1024);
  if (kb > 1024) fail(file, `the photo is ${kb} KB. Keep it under 1 MB.`);
}

if (problems.length) {
  console.error(`check: ${problems.length} problem${problems.length === 1 ? '' : 's'}\n- ${problems.join('\n- ')}`);
  process.exit(1);
}
console.log(`check: ok (${prompts.length} prompts, ${files.length} files)`);
