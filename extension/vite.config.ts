import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { nativeResources } from './scripts/native';

const root = resolve(__dirname, 'src');

/** Copies manifest.json into the build and refuses to build if its version drifts from package.json. */
function manifest() {
  return {
    name: 'kipir-manifest',
    generateBundle(this: { emitFile: (f: { type: 'asset'; fileName: string; source: string }) => void }) {
      const m = JSON.parse(readFileSync(resolve(__dirname, 'manifest.json'), 'utf8'));
      const pkg = JSON.parse(readFileSync(resolve(__dirname, 'package.json'), 'utf8'));
      if (m.version !== pkg.version) throw new Error(`manifest version ${m.version} != package.json ${pkg.version}`);
      this.emitFile({ type: 'asset', fileName: 'manifest.json', source: JSON.stringify(m, null, 2) });
    },
  };
}

export default defineConfig(({ mode }) => ({
  root,
  base: '',
  publicDir: resolve(__dirname, 'public'),
  plugins: [react(), nativeResources(), manifest()],
  build: {
    outDir: resolve(__dirname, mode === 'e2e' ? 'dist-e2e' : 'dist'),
    emptyOutDir: true,
    target: 'chrome127',
    modulePreload: false,
    sourcemap: false,
    rollupOptions: {
      input: {
        popup: resolve(root, 'popup.html'),
        options: resolve(root, 'options.html'),
        offscreen: resolve(root, 'offscreen.html'),
        background: resolve(root, 'background/index.ts'),
      },
      output: {
        entryFileNames: (chunk) => (chunk.name === 'background' ? 'background.js' : 'assets/[name]-[hash].js'),
      },
    },
  },
  test: {
    root: __dirname,
    include: ['tests/unit/**/*.test.ts', 'tests/integration/**/*.test.ts'],
    environment: 'node',
  },
}));
