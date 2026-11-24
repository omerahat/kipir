// Verifies the production build and writes the Chrome Web Store upload ZIP to release/.
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist');
const fail = (m) => { console.error(`package: ${m}`); process.exit(1); };
if (!existsSync(join(dist, 'manifest.json'))) fail('dist/ is missing; run npm run build');

const manifest = JSON.parse(readFileSync(join(dist, 'manifest.json'), 'utf8'));
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
if (manifest.manifest_version !== 3) fail('manifest_version must be 3');
if (manifest.version !== pkg.version) fail('manifest/package version mismatch');
const expected = ['alarms', 'idle', 'notifications', 'offscreen', 'storage'];
if (JSON.stringify([...manifest.permissions].sort()) !== JSON.stringify(expected)) fail(`unexpected permissions ${manifest.permissions}`);
if (manifest.host_permissions || manifest.content_scripts || manifest.optional_host_permissions) fail('no host access or content scripts allowed');

const files = [];
const walk = (d) => { for (const f of readdirSync(d)) { const p = join(d, f); if (statSync(p).isDirectory()) walk(p); else files.push(p); } };
walk(dist);
for (const size of [16, 32, 48, 128]) if (!files.includes(join(dist, `icons/icon-${size}.png`))) fail(`missing icon ${size}`);
for (const f of files.filter((p) => /\.(js|html)$/.test(p))) {
  const text = readFileSync(f, 'utf8');
  if (text.includes('kipir-debug')) fail(`e2e debug hook found in ${relative(dist, f)}`);
  if (/\beval\s*\(|new Function\s*\(/.test(text)) fail(`dynamic code in ${relative(dist, f)}`);
  if (/<script(?![^>]*\bsrc=)[^>]*>/.test(text) && f.endsWith('.html')) fail(`inline script in ${relative(dist, f)}`);
  if (/https?:\/\/(?!www\.w3\.org|react\.dev|reactjs\.org)[a-z0-9.-]+\.[a-z]{2,}/i.test(text) && !f.endsWith('.html')) {
    const hits = [...text.matchAll(/https?:\/\/[a-z0-9.-]+\.[a-z]{2,}[^\s"'`)]*/gi)].map((m) => m[0]).filter((u) => !/w3\.org|react\.dev|reactjs\.org/.test(u));
    if (hits.length) fail(`remote URL in ${relative(dist, f)}: ${hits.slice(0, 3).join(', ')}`);
  }
}
const out = join(root, 'release');
mkdirSync(out, { recursive: true });
const zip = join(out, `kipir-chrome-${pkg.version}.zip`);
rmSync(zip, { force: true });
execFileSync('zip', ['-q', '-r', '-X', zip, '.', '-x', '.*'], { cwd: dist });
const kb = Math.round(statSync(zip).size / 1024);
console.log(`package: ${relative(root, zip)} (${kb} KB, ${files.length} files) — manifest ${manifest.version}, permissions ${expected.join(', ')}`);
