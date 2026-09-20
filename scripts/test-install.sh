#!/bin/sh
# Install test suite. Builds throwaway fixtures for each stack and asserts the
# installer does the right thing. No devices or SDKs required.
#
#   ./scripts/test-install.sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM

PASS=0; FAIL=0
chk() {
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (got "%s" want "%s")\n' "$1" "$2" "$3"; fi
}
has() { [ -e "$1" ] && echo y || echo n; }

# ------------------------------------------------------------- fixtures -----
mk() { mkdir -p "$WORK/$1" && (cd "$WORK/$1" && git init -q . 2>/dev/null || true); }

mk flutter
printf 'name: myapp\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$WORK/flutter/pubspec.yaml"
mkdir -p "$WORK/flutter/ios" "$WORK/flutter/android"

mk rn
printf '{"name":"rn","dependencies":{"react-native":"0.76.0"}}' > "$WORK/rn/package.json"
mkdir -p "$WORK/rn/ios" "$WORK/rn/android"

mk ios && mkdir -p "$WORK/ios/App.xcodeproj"
mk ios-ws && mkdir -p "$WORK/ios-ws/App.xcworkspace"
mk ios-spm && touch "$WORK/ios-spm/Package.swift"
mk android && printf 'rootProject.name="app"\n' > "$WORK/android/settings.gradle"

echo "Stack detection"
for pair in "flutter:flutter" "rn:react-native" "ios:ios" "ios-ws:ios" "ios-spm:ios" "android:android"; do
  dir=${pair%%:*}; want=${pair##*:}
  got=$(sh "$ROOT/install.sh" --target "$WORK/$dir" --dry-run --yes 2>&1 |
        sed -n 's/^  stack *\(.*\)$/\1/p' | head -1)
  chk "$dir detects as $want" "$got" "$want"
done

echo
echo "Install"
for s in flutter rn ios android; do
  rc=0; sh "$ROOT/install.sh" --target "$WORK/$s" --adapter claude --yes >/dev/null 2>&1 || rc=$?
  chk "$s exit 0" "$rc" "0"
  chk "$s AGENTS.md" "$(has "$WORK/$s/AGENTS.md")" "y"
  chk "$s platform.md" "$(has "$WORK/$s/blueprint/context/platform.md")" "y"
  chk "$s device skill" "$(has "$WORK/$s/.claude/skills/device/SKILL.md")" "y"
  chk "$s state ignored" "$(grep -c 'blueprint/.state/' "$WORK/$s/.gitignore")" "1"
done

echo
echo "Stack-correct content"
grep -q 'flutter analyze' "$WORK/flutter/AGENTS.md" && chk "flutter Verify" y y || chk "flutter Verify" n y
grep -q 'gradlew'         "$WORK/android/AGENTS.md" && chk "android Verify" y y || chk "android Verify" n y
grep -q 'xcodebuild'      "$WORK/ios/AGENTS.md"     && chk "ios Verify" y y     || chk "ios Verify" n y
grep -q 'tsc --noEmit'    "$WORK/rn/AGENTS.md"      && chk "rn Verify" y y      || chk "rn Verify" n y
chk "no TODO left in Commands" "$(grep -c '^- Run: .TODO' "$WORK/flutter/AGENTS.md")" "0"

echo
echo "No web references reach an installed project"
for s in flutter rn ios android; do
  n=$(grep -rniE 'next\.js|vercel|playwright|tailwind|prisma|localhost:3000|npm run dev|browser' \
      "$WORK/$s/AGENTS.md" "$WORK/$s/blueprint" "$WORK/$s/.claude" 2>/dev/null |
      grep -v '/blueprint/history' | wc -l | tr -d ' ')
  chk "$s is web-free" "$n" "0"
done

echo
echo "Idempotency"
before=$(find "$WORK/flutter" -path '*/.git' -prune -o -type f -print | sort | md5sum 2>/dev/null || \
         find "$WORK/flutter" -path '*/.git' -prune -o -type f -print | sort | md5)
sh "$ROOT/install.sh" --target "$WORK/flutter" --adapter claude --yes --force >/dev/null 2>&1
after=$(find "$WORK/flutter" -path '*/.git' -prune -o -type f -print | sort | md5sum 2>/dev/null || \
        find "$WORK/flutter" -path '*/.git' -prune -o -type f -print | sort | md5)
chk "reinstall is stable" "$before" "$after"
chk "gitignore not duplicated" "$(grep -c 'blueprint/.state/' "$WORK/flutter/.gitignore")" "1"

echo
echo "Multi-adapter"
sh "$ROOT/install.sh" --target "$WORK/rn" --adapter claude,codex --yes --force >/dev/null 2>&1
chk "claude tree" "$(has "$WORK/rn/.claude/skills/device/SKILL.md")" "y"
chk "agents tree" "$(has "$WORK/rn/.agents/skills/device/SKILL.md")" "y"

echo
echo "Bad input is rejected"
rc=0; sh "$ROOT/install.sh" --target "$WORK/flutter" --stack windows-phone --yes >/dev/null 2>&1 || rc=$?
chk "bad stack" "$rc" "1"
rc=0; sh "$ROOT/install.sh" --target "$WORK/flutter" --adapter emacs --yes >/dev/null 2>&1 || rc=$?
chk "bad adapter" "$rc" "1"
rc=0; sh "$ROOT/install.sh" --target "$WORK/nope" --yes >/dev/null 2>&1 || rc=$?
chk "bad target" "$rc" "1"
rc=0; sh "$ROOT/install.sh" --target "$ROOT" --yes >/dev/null 2>&1 || rc=$?
chk "self-install refused" "$rc" "1"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
