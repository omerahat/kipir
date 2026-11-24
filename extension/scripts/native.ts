// Build-time bridge to the native app's resources, so the extension never keeps a second copy of the copy or the art.
// - `Kipir/Resources/{tr,en}.lproj/Localizable.strings` -> virtual module `virtual:native-strings`
// - `Kipir/Resources/Assets.xcassets/exercise-*.imageset/*.png` -> `exercises/<movement>-<pose>.png` in the build
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Plugin } from 'vite';

const here = dirname(fileURLToPath(import.meta.url));
export const NATIVE_RESOURCES = resolve(here, '../../Kipir/Resources');

/** Parses an Apple `.strings` file: `"key" = "value";` pairs, block and line comments, standard escapes. */
export function parseStrings(source: string): Record<string, string> {
  const out: Record<string, string> = {};
  let i = 0;
  const n = source.length;
  const skip = () => {
    for (;;) {
      while (i < n && /\s/.test(source[i])) i++;
      if (source.startsWith('/*', i)) { const e = source.indexOf('*/', i + 2); i = e < 0 ? n : e + 2; continue; }
      if (source.startsWith('//', i)) { const e = source.indexOf('\n', i); i = e < 0 ? n : e + 1; continue; }
      return;
    }
  };
  const str = (): string => {
    if (source[i] !== '"') throw new Error(`Expected string at ${i}`);
    i++;
    let s = '';
    while (i < n && source[i] !== '"') {
      if (source[i] === '\\') {
        const c = source[i + 1];
        s += c === 'n' ? '\n' : c === 't' ? '\t' : c === 'r' ? '\r' : c;
        i += 2;
      } else s += source[i++];
    }
    i++;
    return s;
  };
  for (;;) {
    skip();
    if (i >= n) break;
    const key = str();
    skip();
    if (source[i] !== '=') throw new Error(`Expected = after ${key}`);
    i++; skip();
    out[key] = str();
    skip();
    if (source[i] === ';') i++;
  }
  return out;
}

export function loadNativeStrings(): { tr: Record<string, string>; en: Record<string, string> } {
  const read = (lang: string) => parseStrings(readFileSync(join(NATIVE_RESOURCES, `${lang}.lproj/Localizable.strings`), 'utf8'));
  return { tr: read('tr'), en: read('en') };
}

/** Pose images as { 'walk-start': absolutePath, ... }. */
export function nativeExerciseImages(): Record<string, string> {
  const root = join(NATIVE_RESOURCES, 'Assets.xcassets');
  const out: Record<string, string> = {};
  if (!existsSync(root)) return out;
  for (const dir of readdirSync(root)) {
    const m = /^exercise-(.+)\.imageset$/.exec(dir);
    if (!m) continue;
    const png = readdirSync(join(root, dir)).find((f) => f.endsWith('.png'));
    if (png) out[m[1]] = join(root, dir, png);
  }
  return out;
}

export function nativeResources(): Plugin {
  const id = 'virtual:native-strings';
  return {
    name: 'kipir-native-resources',
    resolveId(source) { return source === id ? '\0' + id : null; },
    load(source) {
      if (source !== '\0' + id) return null;
      for (const lang of ['tr', 'en']) this.addWatchFile(join(NATIVE_RESOURCES, `${lang}.lproj/Localizable.strings`));
      return `export default ${JSON.stringify(loadNativeStrings())};`;
    },
    generateBundle() {
      for (const [name, path] of Object.entries(nativeExerciseImages())) {
        this.emitFile({ type: 'asset', fileName: `exercises/${name}.png`, source: readFileSync(path) });
      }
    },
  };
}
