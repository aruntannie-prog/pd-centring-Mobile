// Runs every *.e2e.js against the built web app and fails if any check
// prints FAIL or the page logged errors.
//   cd sd_centring && flutter build web --no-web-resources-cdn
//   python3 -m http.server 8765 --directory build/web &
//   cd e2e_web && npm install && npm test
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const out = fs.mkdtempSync(path.join(os.tmpdir(), 'sd-e2e-'));
const fixtures = path.join(__dirname, 'fixtures');
let failed = 0;
for (const file of fs.readdirSync(__dirname).filter((f) => f.endsWith('.e2e.js')).sort()) {
  const r = spawnSync('node', [path.join(__dirname, file), out, fixtures], { encoding: 'utf8' });
  const text = `${r.stdout}${r.stderr}`;
  process.stdout.write(`== ${file}\n${text}\n`);
  if (r.status !== 0 || /^FAIL/m.test(text) || /PAGE ERRORS/.test(text)) failed++;
}
console.log(failed ? `${failed} suite(s) failed` : 'All browser suites passed');
console.log(`Screenshots: ${out}`);
process.exit(failed ? 1 : 0);
