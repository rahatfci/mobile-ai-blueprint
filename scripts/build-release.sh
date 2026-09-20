#!/bin/sh
# Assemble the release tarball that every install path resolves to.
#
#   ./scripts/build-release.sh [output-dir]
#
# The tarball is simply the repository content, because install.sh expects the
# workflow base to sit next to itself. One layout, checkout or release.
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
OUT_DIR="${1:-$ROOT/dist}"

VERSION=$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$ROOT/install.sh" | head -1)
[ -n "$VERSION" ] || { echo "could not read VERSION from install.sh" >&2; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT INT TERM

NAME="mobile-blueprint-$VERSION"
DEST="$STAGE/$NAME"
mkdir -p "$DEST"

for entry in AGENTS.md CLAUDE.md README.md DESIGN.md LICENSE install.sh \
             .claude .agents blueprint stacks; do
  [ -e "$ROOT/$entry" ] || continue
  cp -R "$ROOT/$entry" "$DEST/$entry"
done

# Generated local state never ships.
rm -rf "$DEST/blueprint/.state"
chmod +x "$DEST/install.sh"

mkdir -p "$OUT_DIR"
TARBALL="$OUT_DIR/$NAME.tar.gz"
(cd "$STAGE" && tar -czf "$TARBALL" "$NAME")

# install.sh is published beside the tarball so `curl | sh` can fetch it alone.
cp "$ROOT/install.sh" "$OUT_DIR/install.sh"

if command -v shasum >/dev/null 2>&1; then
  (cd "$OUT_DIR" && shasum -a 256 "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
elif command -v sha256sum >/dev/null 2>&1; then
  (cd "$OUT_DIR" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
fi

echo "built $TARBALL"
echo "size  $(du -h "$TARBALL" | cut -f1)"
echo
echo "Publish both files as a GitHub release asset:"
echo "  $TARBALL"
echo "  $OUT_DIR/install.sh"
