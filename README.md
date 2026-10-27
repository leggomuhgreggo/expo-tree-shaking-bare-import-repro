# Expo tree shaking drops a bare `import './x'` unless it is the first import

Minimal repro for an `@expo/metro-config` tree-shaking bug.

With `EXPO_UNSTABLE_METRO_OPTIMIZE_GRAPH=1` and `EXPO_UNSTABLE_TREE_SHAKING=1`, a side-effect-only import is removed from the bundle when an import with specifiers comes before it in the same module:

```js
// lib/index.js
import { value } from './value';
import './polyfill'; // <- dropped from the tree-shaken bundle

export { value };
```

`lib/polyfill.js` sets `globalThis.__POLYFILLED__ = true`. The project has no `sideEffects` field, so bare imports should be kept.

## Run it

```sh
npm install
./repro.sh
```

`repro.sh` bundles `index.js` three ways with `npx expo export:embed --platform ios --dev false --minify false` and runs each bundle in Node:

| run       | flags | `lib/index.js` order          |
| --------- | ----- | ----------------------------- |
| `off`     | off   | `{ value }` import, then bare |
| `on`      | on    | `{ value }` import, then bare |
| `control` | on    | bare import first             |

Output on expo 58.0.20 / @expo/metro-config 58.0.18:

```
off      polyfill in bundle: 1 | value: hello polyfilled: true
on       polyfill in bundle: 0 | value: hello polyfilled: undefined
control  polyfill in bundle: 1 | value: hello polyfilled: true
```

**Expected:** `on` prints `polyfilled: true`, the same as `off`.

## Manual steps

```sh
# tree shaking off
npx expo export:embed --platform ios --dev false --minify false --entry-file index.js \
  --bundle-output off.js --assets-dest a-off --reset-cache

# tree shaking on
EXPO_UNSTABLE_METRO_OPTIMIZE_GRAPH=1 EXPO_UNSTABLE_TREE_SHAKING=1 \
npx expo export:embed --platform ios --dev false --minify false --entry-file index.js \
  --bundle-output on.js --assets-dest a-on --reset-cache

grep -c '__POLYFILLED__ = true' off.js on.js
node -e "globalThis.global = globalThis; require('./off.js')"
node -e "globalThis.global = globalThis; require('./on.js')"
```

## Cause

`removeUnusedImportsFromModule` in `packages/@expo/metro-config/src/serializer/treeShakeSerializerPlugin.ts` caches each import's original specifier count with `path.opts.originalSpecifiers ??= path.node.specifiers.length`. `@babel/traverse` sets `path.opts` to the traversal's shared options object, so the first import's count is reused for every later import in the module. A later bare import then isn't flagged as side-effecty and gets disposed of.
