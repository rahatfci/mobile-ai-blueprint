#!/bin/sh
# Re-apply the mobile transform against a newer upstream AI Blueprint.
#
#   ./scripts/sync-upstream.sh ../ai-blueprint
#
# The ~18 stack-neutral skills (feature, implement, complete, audit, status,
# doctor, rollback, and the rest) are shared with upstream and improve there.
# This script pulls those improvements forward and reapplies the mobile edits on
# top, so this repo does not slowly drift into a stale fork.
#
# Every edit in transform.py is asserted. If upstream rewords a line the
# transform targets, this FAILS LOUDLY and names the line rather than silently
# shipping web guidance in a mobile install. Fix the pattern, then rerun.
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
UPSTREAM="${1:-}"

[ -n "$UPSTREAM" ] || { echo "usage: sync-upstream.sh <path-to-ai-blueprint-checkout>" >&2; exit 1; }
[ -d "$UPSTREAM" ] || { echo "not a directory: $UPSTREAM" >&2; exit 1; }
[ -f "$UPSTREAM/AGENTS.md" ] || { echo "no AGENTS.md in $UPSTREAM" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || { echo "python3 is required for the transform" >&2; exit 1; }

if [ -n "$(cd "$ROOT" && git status --porcelain 2>/dev/null)" ]; then
  echo "working tree is dirty. Commit or stash first so the sync diff is readable." >&2
  exit 1
fi

# The mobile-authored sources the transform layers back on top.
MOBILE_SRC=$(mktemp -d)
trap 'rm -rf "$MOBILE_SRC"' EXIT INT TERM
mkdir -p "$MOBILE_SRC/skills"
cp -R "$ROOT/stacks" "$MOBILE_SRC/stacks"
for s in check tests release ci device prototype; do
  [ -d "$ROOT/.claude/skills/$s" ] && cp -R "$ROOT/.claude/skills/$s" "$MOBILE_SRC/skills/$s"
done
cp "$ROOT/blueprint/context/coding-standards.md" "$MOBILE_SRC/coding-standards-placeholder.md"

python3 "$SCRIPT_DIR/transform.py" "$UPSTREAM" "$ROOT" "$MOBILE_SRC"

echo
echo "Sync applied. Review the diff before committing:"
echo "  git -C $ROOT diff --stat"
