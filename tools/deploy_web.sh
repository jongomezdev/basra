#!/usr/bin/env bash
# Exports the Web build and publishes it to the gh-pages branch, which GitHub
# Pages serves at https://jongomezdev.github.io/basra/.
#
# The branch is replaced on every run (one commit, force-pushed), so old
# 40 MB builds never pile up in the repository's history.
#
# Usage: tools/deploy_web.sh
# Set GODOT to use a Godot binary other than /Applications/Godot.app.
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
OUT="$ROOT/build/web"
REMOTE="$(git -C "$ROOT" remote get-url origin)"
SOURCE="$(git -C "$ROOT" rev-parse --short HEAD)"
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
	SOURCE="$SOURCE plus uncommitted changes"
fi

echo "Exporting web build..."
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"
test -f "$OUT/index.wasm" || { echo "Export failed: no index.wasm" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$OUT"/. "$STAGE"/
# Tells GitHub Pages to serve the files as they are, without Jekyll.
touch "$STAGE/.nojekyll"

echo "Publishing to gh-pages..."
git -C "$STAGE" init -q -b gh-pages
git -C "$STAGE" add -A
git -C "$STAGE" -c user.name="$(git -C "$ROOT" config user.name)" \
	-c user.email="$(git -C "$ROOT" config user.email)" \
	commit -q -m "Deploy web build of $SOURCE"
git -C "$STAGE" push -q --force "$REMOTE" gh-pages:gh-pages

echo "Published $SOURCE. Live in a minute or two at https://jongomezdev.github.io/basra/"
