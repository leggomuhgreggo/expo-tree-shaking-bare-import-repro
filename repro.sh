#!/usr/bin/env bash
# Bundles index.js three ways and runs each bundle in Node:
#   off     - tree shaking disabled
#   on      - tree shaking enabled (bug: lib/polyfill.js is dropped)
#   control - tree shaking enabled, bare import moved first in lib/index.js
set -euo pipefail
cd "$(dirname "$0")"
rm -rf out && mkdir -p out

bundle() {
  local name=$1
  npx expo export:embed --platform ios --dev false --minify false \
    --entry-file index.js --bundle-output "out/$name.js" \
    --assets-dest "out/assets-$name" --reset-cache >"out/$name.log" 2>&1
}

run() {
  local name=$1
  printf '%-8s polyfill in bundle: %s | ' "$name" "$(grep -c '__POLYFILLED__ = true' "out/$name.js" || true)"
  node -e "globalThis.global = globalThis; require('./out/$name.js')"
}

bundle off

EXPO_UNSTABLE_METRO_OPTIMIZE_GRAPH=1 EXPO_UNSTABLE_TREE_SHAKING=1 bundle on

cp lib/index.js out/index.js.orig
trap 'cp out/index.js.orig lib/index.js' EXIT
printf "import './polyfill';\nimport { value } from './value';\n\nexport { value };\n" > lib/index.js
EXPO_UNSTABLE_METRO_OPTIMIZE_GRAPH=1 EXPO_UNSTABLE_TREE_SHAKING=1 bundle control

echo
run off
run on
run control
