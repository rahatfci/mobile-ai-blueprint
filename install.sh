#!/bin/sh
# Mobile Blueprint installer.
#
# Installs a spec-driven AI coding workflow into an existing mobile app.
# Flutter, native iOS, native Android, and React Native.
#
# Requires only sh and tar, plus curl when fetching a remote release.
# Deliberately not Node-dependent: most Flutter, iOS, and Android projects have
# no Node toolchain and should not need one to get a workflow.
#
#   ./install.sh                       install into the current directory
#   ./install.sh --target ../my-app    install elsewhere
#   ./install.sh --dry-run             show the plan, change nothing
#
set -eu

VERSION="0.1.0"
BASE_URL="${BLUEPRINT_BASE_URL:-https://github.com/rahatfci/mobile-ai-blueprint/releases/latest/download}"

STACK=""
ADAPTERS=""
SOURCE=""
TARGET="$PWD"
DRY_RUN=0
FORCE=0
ASSUME_YES=0
TMPDIR_CREATED=""

# ----------------------------------------------------------------- output ----

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_BOLD=$(printf '\033[1m'); C_DIM=$(printf '\033[2m')
  C_RED=$(printf '\033[31m'); C_GREEN=$(printf '\033[32m')
  C_YELLOW=$(printf '\033[33m'); C_OFF=$(printf '\033[0m')
else
  C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_OFF=''
fi

say()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '%s!%s %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }
die()  { printf '%serror%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }
ok()   { printf '%s+%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }

cleanup() { [ -n "$TMPDIR_CREATED" ] && rm -rf "$TMPDIR_CREATED"; return 0; }
trap cleanup EXIT INT TERM

usage() {
  cat <<'USAGE'
Mobile Blueprint installer

USAGE
  install.sh [options]

OPTIONS
  --stack <name>      flutter | ios | android | react-native
                      Detected from project files when omitted.
  --adapter <list>    Comma separated: claude, codex, copilot, opencode.
                      Detected from existing files, else prompted.
  --from <dir>        Install from a local checkout instead of downloading.
  --target <dir>      Project to install into. Defaults to the current dir.
  --dry-run           Print the plan and change nothing.
  --force             Overwrite existing Blueprint files without asking.
  --yes               Accept detected values without prompting.
  --version           Print the installer version.
  --help              Print this help.

EXAMPLES
  ./install.sh --target ~/my-flutter-app
  ./install.sh --stack react-native --adapter claude,codex
  ./install.sh --dry-run
USAGE
}

# ------------------------------------------------------------------- args ----

while [ $# -gt 0 ]; do
  case "$1" in
    --stack)     STACK="${2:-}"; shift 2 ;;
    --stack=*)   STACK="${1#*=}"; shift ;;
    --adapter)   ADAPTERS="${2:-}"; shift 2 ;;
    --adapter=*) ADAPTERS="${1#*=}"; shift ;;
    --from)      SOURCE="${2:-}"; shift 2 ;;
    --from=*)    SOURCE="${1#*=}"; shift ;;
    --target)    TARGET="${2:-}"; shift 2 ;;
    --target=*)  TARGET="${1#*=}"; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --force)     FORCE=1; shift ;;
    --yes|-y)    ASSUME_YES=1; shift ;;
    --version)   say "$VERSION"; exit 0 ;;
    --help|-h)   usage; exit 0 ;;
    *)           die "unknown option: $1 (try --help)" ;;
  esac
done

[ -d "$TARGET" ] || die "target directory does not exist: $TARGET"
TARGET=$(cd "$TARGET" && pwd)

# --------------------------------------------------------------- detection ---

# A glob that matches nothing is passed through literally, and that literal
# never exists on disk. Testing the first argument is therefore the portable way
# to ask whether a pattern matched. `ls pattern1 pattern2` cannot be used: it
# exits non-zero when any one pattern misses, even if another matched.
glob_matches() { [ -e "$1" ]; }

# Flutter and React Native projects contain ios/ and android/ subdirectories, so
# they must be matched before the native stacks or every cross-platform project
# would be misread as native Android.
detect_stack() {
  if [ -f "$TARGET/pubspec.yaml" ] && grep -q '^ *flutter *:' "$TARGET/pubspec.yaml" 2>/dev/null; then
    echo flutter; return
  fi
  if [ -f "$TARGET/package.json" ] &&
     grep -Eq '"(react-native|expo)"' "$TARGET/package.json" 2>/dev/null; then
    echo react-native; return
  fi
  if glob_matches "$TARGET"/*.xcodeproj || glob_matches "$TARGET"/*.xcworkspace ||
     [ -f "$TARGET/Package.swift" ]; then
    echo ios; return
  fi
  if [ -f "$TARGET/settings.gradle" ] || [ -f "$TARGET/settings.gradle.kts" ] ||
     [ -f "$TARGET/build.gradle" ] || [ -f "$TARGET/build.gradle.kts" ]; then
    echo android; return
  fi
  echo ""
}

describe_stack() {
  case "$1" in
    flutter)      echo "Flutter (pubspec.yaml)" ;;
    react-native) echo "React Native or Expo (package.json)" ;;
    ios)          echo "native iOS (Xcode project or Package.swift)" ;;
    android)      echo "native Android (Gradle)" ;;
    *)            echo "$1" ;;
  esac
}

valid_stack() {
  case "$1" in flutter|ios|android|react-native) return 0 ;; *) return 1 ;; esac
}

detect_adapters() {
  found=""
  [ -d "$TARGET/.claude" ] && found="claude"
  if [ -d "$TARGET/.agents" ]; then
    [ -n "$found" ] && found="$found,codex" || found="codex"
  fi
  echo "$found"
}

valid_adapter() {
  case "$1" in claude|codex|copilot|opencode) return 0 ;; *) return 1 ;; esac
}

# Prompts read from /dev/tty so they still work under `curl | sh`, where stdin
# is the script itself rather than the terminal.
ask() {
  prompt="$1"; default="$2"; reply=""
  if [ "$ASSUME_YES" -eq 1 ] || [ ! -r /dev/tty ]; then echo "$default"; return; fi
  printf '%s [%s]: ' "$prompt" "$default" > /dev/tty
  read -r reply < /dev/tty || reply=""
  [ -z "$reply" ] && reply="$default"
  echo "$reply"
}

# ---------------------------------------------------------------- preflight --

say ""
say "${C_BOLD}Mobile Blueprint${C_OFF} ${C_DIM}v$VERSION${C_OFF}"
say ""

if ! (cd "$TARGET" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
  warn "$TARGET is not a Git repository."
  warn "The workflow relies on branches and commits. Run 'git init' first."
  answer=$(ask "Continue anyway? (y/N)" "N")
  case "$answer" in y|Y|yes|Yes) ;; *) die "stopped. Initialize Git, then rerun." ;; esac
fi

if [ -z "$STACK" ]; then
  STACK=$(detect_stack)
  if [ -n "$STACK" ]; then
    ok "Detected stack: $(describe_stack "$STACK")"
  else
    warn "Could not detect a mobile stack in $TARGET"
    STACK=$(ask "Stack (flutter/ios/android/react-native)" "flutter")
  fi
else
  info "Stack: $(describe_stack "$STACK") (specified)"
fi

valid_stack "$STACK" || die "unsupported stack: $STACK (expected flutter, ios, android, or react-native)"

if [ -z "$ADAPTERS" ]; then
  ADAPTERS=$(detect_adapters)
  if [ -n "$ADAPTERS" ]; then
    ok "Detected AI tools: $ADAPTERS"
  else
    ADAPTERS=$(ask "AI tool adapters (claude,codex,copilot,opencode)" "claude")
  fi
else
  info "Adapters: $ADAPTERS (specified)"
fi

OLD_IFS="$IFS"; IFS=','
for a in $ADAPTERS; do
  valid_adapter "$a" || { IFS="$OLD_IFS"; die "unknown adapter: $a"; }
done
IFS="$OLD_IFS"

# ------------------------------------------------------------------ source ---
#
# One layout, whether run from a checkout or an unpacked release: the workflow
# base sits next to this script. That is why the release tarball is just the
# repository content rather than a rearranged bundle.

resolve_source() {
  if [ -n "$SOURCE" ]; then
    [ -d "$SOURCE" ] || die "--from directory not found: $SOURCE"
    SOURCE=$(cd "$SOURCE" && pwd)
    return
  fi

  script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || echo "")
  if [ -n "$script_dir" ] && [ -d "$script_dir/stacks" ] && [ -f "$script_dir/AGENTS.md" ]; then
    SOURCE="$script_dir"
    return
  fi

  command -v curl >/dev/null 2>&1 || die "curl is required to download the release"
  command -v tar  >/dev/null 2>&1 || die "tar is required to unpack the release"

  TMPDIR_CREATED=$(mktemp -d 2>/dev/null || mktemp -d -t blueprint)
  url="$BASE_URL/mobile-blueprint-$VERSION.tar.gz"
  info "Downloading $url"
  curl -fsSL "$url" -o "$TMPDIR_CREATED/release.tar.gz" ||
    die "download failed. Use --from with a local checkout instead."
  tar -xzf "$TMPDIR_CREATED/release.tar.gz" -C "$TMPDIR_CREATED" || die "could not unpack the release"
  SOURCE="$TMPDIR_CREATED/mobile-blueprint-$VERSION"
  [ -d "$SOURCE/stacks" ] || die "unexpected release layout under $SOURCE"
}

resolve_source

PACK="$SOURCE/stacks/$STACK"
[ -d "$PACK" ] || die "no stack pack for '$STACK' at $PACK"
[ -f "$SOURCE/AGENTS.md" ] || die "missing workflow base at $SOURCE"

if [ -d "$SOURCE/.claude/skills" ]; then
  SOURCE_SKILLS="$SOURCE/.claude/skills"
elif [ -d "$SOURCE/.agents/skills" ]; then
  SOURCE_SKILLS="$SOURCE/.agents/skills"
else
  die "missing skills tree under $SOURCE"
fi

# Refuse to install a project into itself, which would otherwise half-overwrite
# this repository with its own template.
if [ "$SOURCE" = "$TARGET" ]; then
  die "source and target are the same directory. Use --target to pick a project."
fi

# ------------------------------------------------------------------- plan ----

say ""
say "${C_BOLD}Plan${C_OFF}"
info "project   $TARGET"
info "stack     $STACK"
info "adapters  $ADAPTERS"
info "source    $SOURCE"
say ""

planned_paths() {
  echo "AGENTS.md"
  echo "blueprint/"
  OLD_IFS="$IFS"; IFS=','
  for a in $ADAPTERS; do
    case "$a" in
      claude)                  echo "CLAUDE.md"; echo ".claude/skills/" ;;
      codex|copilot|opencode)  echo ".agents/skills/" ;;
    esac
  done
  IFS="$OLD_IFS"
}

CONFLICTS=""
for p in $(planned_paths | sort -u); do
  [ -e "$TARGET/$p" ] && CONFLICTS="$CONFLICTS $p"
done

if [ -n "$CONFLICTS" ] && [ "$FORCE" -eq 0 ]; then
  warn "These paths already exist and would be overwritten:"
  for c in $CONFLICTS; do info "$c"; done
  if [ "$DRY_RUN" -eq 0 ]; then
    answer=$(ask "Overwrite? (y/N)" "N")
    case "$answer" in y|Y|yes|Yes) ;; *) die "stopped. Nothing was changed." ;; esac
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  say "${C_BOLD}Would write${C_OFF}"
  for p in $(planned_paths | sort -u); do info "$p"; done
  say ""
  say "${C_DIM}Dry run: nothing was changed.${C_OFF}"
  exit 0
fi

# ---------------------------------------------------------------- install ----

copy_tree() { mkdir -p "$2"; (cd "$1" && tar cf - .) | (cd "$2" && tar xf -); }

say "${C_BOLD}Installing${C_OFF}"

copy_tree "$SOURCE/blueprint" "$TARGET/blueprint"
cp "$SOURCE/AGENTS.md" "$TARGET/AGENTS.md"
rm -rf "$TARGET/blueprint/.state"
info "blueprint/ and AGENTS.md"

WROTE_AGENTS=0
OLD_IFS="$IFS"; IFS=','
for a in $ADAPTERS; do
  case "$a" in
    claude)
      copy_tree "$SOURCE_SKILLS" "$TARGET/.claude/skills"
      cp "$SOURCE/CLAUDE.md" "$TARGET/CLAUDE.md"
      info ".claude/skills/ and CLAUDE.md"
      ;;
    codex|copilot|opencode)
      if [ "$WROTE_AGENTS" -eq 0 ]; then
        copy_tree "$SOURCE_SKILLS" "$TARGET/.agents/skills"
        info ".agents/skills/"
        WROTE_AGENTS=1
      fi
      ;;
  esac
done
IFS="$OLD_IFS"

# The stack pack supplies the two context files and the Commands block. Unlike
# an overlay onto a web workflow, nothing here needs patching afterward: the
# skills already ship mobile-native.
cp "$PACK/coding-standards.md" "$TARGET/blueprint/context/coding-standards.md"
cp "$PACK/platform.md"         "$TARGET/blueprint/context/platform.md"
info "blueprint/context/ stack pack ($STACK)"

awk -v cmdfile="$PACK/commands.md" '
  /^## Commands$/ { print; print ""; while ((getline line < cmdfile) > 0) print line; skip=1; next }
  skip && /^## / { skip=0 }
  !skip { print }
' "$TARGET/AGENTS.md" > "$TARGET/AGENTS.md.tmp" && mv "$TARGET/AGENTS.md.tmp" "$TARGET/AGENTS.md"
info "AGENTS.md Commands block"

# Generated state is local only and must never enter a feature commit.
mkdir -p "$TARGET/blueprint/.state"
if [ -f "$TARGET/.gitignore" ]; then
  grep -q '^blueprint/\.state/' "$TARGET/.gitignore" 2>/dev/null ||
    printf '\n# Blueprint generated state\nblueprint/.state/\n' >> "$TARGET/.gitignore"
else
  printf '# Blueprint generated state\nblueprint/.state/\n' > "$TARGET/.gitignore"
fi

cat > "$TARGET/blueprint/.state/manifest.json" <<MANIFEST
{
  "schemaVersion": 1,
  "version": "$VERSION",
  "stack": "$STACK",
  "adapters": [$(echo "$ADAPTERS" | sed 's/[^,]*/"&"/g')],
  "installedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
MANIFEST

say ""
ok "Installed Mobile Blueprint for $(describe_stack "$STACK")"
say ""
say "${C_BOLD}Next${C_OFF}"
info "1. Run /onboard in your AI tool so it learns your real commands and devices."
info "2. Write blueprint/project-plan.md and blueprint/build-plan.md."
info "3. Run /overview, then /feature for the first item."
say ""
say "${C_DIM}blueprint/context/platform.md defines what counts as proof.${C_OFF}"
say ""
