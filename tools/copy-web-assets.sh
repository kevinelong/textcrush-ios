#!/bin/sh
# Stage the game into assets/www, which is what the app bundles and the localhost server serves.
#
# Run before every build (Codemagic runs it too):  sh tools/copy-web-assets.sh
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WWW="$ROOT/assets/www"

rm -rf "$WWW"
mkdir -p "$WWW"

cp -r "$ROOT/game/source/web" "$WWW/web"
cp -r "$ROOT/game/source/game" "$WWW/game"

# The page loads the compiled JavaScript; the TypeScript is the source it was built from.
find "$WWW" -name '*.ts' -delete

# The manifest, the icon set and the service worker are for installing the game in a browser. Inside
# the app the assets are already local, the launcher icon is the native one, and a worker could only
# fail to register, so they are staged out.
rm -rf "$WWW/web/icons" "$WWW/web/manifest.webmanifest" "$WWW/web/sw.js"

[ -f "$WWW/web/index.html" ] || { echo "game/ is not vendored - see game/UPSTREAM"; exit 1; }
find "$WWW" -type f | wc -l | tr -d ' ' | sed 's/^/staged files: /'
