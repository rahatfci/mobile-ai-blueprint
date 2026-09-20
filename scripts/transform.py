#!/usr/bin/env python3
"""Turn an upstream AI Blueprint checkout into the mobile base.

Run by scripts/sync-upstream.sh. Every edit is asserted, so an upstream
rewording fails loudly here instead of silently shipping web guidance in a
mobile install.
"""
import shutil, sys, os
from pathlib import Path

UP = Path(sys.argv[1])       # upstream checkout
DEST = Path(sys.argv[2])     # mobile repo root
MOBILE = Path(sys.argv[3])   # mobile/ source (skills + stacks)

misses = []

def edit(relpath, pairs, required=True):
    f = DEST / relpath
    if not f.exists():
        if required: misses.append(f"missing file: {relpath}")
        return
    s = f.read_text()
    for old, new in pairs:
        if old not in s:
            if required: misses.append(f"{relpath}: pattern not found: {old[:70]}")
            continue
        s = s.replace(old, new)
    f.write_text(s)

# ---------------------------------------------------------------- base copy --
for entry in ["AGENTS.md", "CLAUDE.md", "blueprint", ".claude", ".agents", "LICENSE"]:
    src, dst = UP / entry, DEST / entry
    if not src.exists(): continue
    if src.is_dir(): shutil.copytree(src, dst, dirs_exist_ok=True)
    else: shutil.copy2(src, dst)

# Generated local state never ships.
shutil.rmtree(DEST / "blueprint" / ".state", ignore_errors=True)

# ------------------------------------------------------------- AGENTS.md -----
edit("AGENTS.md", [
# What this is
("""A description of your project and the problem it solves.

This project is built with the **AI Blueprint**, a workflow layer, not an
app skeleton. To start a new project, scaffold the app first in an empty folder
(create-next-app, Vite, etc.), then overlay these files on top. Never run a
framework scaffolder inside a directory that already holds the blueprint files
(`AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, `blueprint/`); it fails
because the directory isn't empty.""",
"""A description of your mobile app and the problem it solves.

This project is built with the **Mobile Blueprint**, a workflow layer, not an
app skeleton. To start a new project, scaffold the app first in an empty folder
(`flutter create`, Xcode, Android Studio, `npx react-native init`, `create-expo-app`),
then overlay these files on top. Never run a framework scaffolder inside a
directory that already holds the blueprint files (`AGENTS.md`, `CLAUDE.md`,
`.agents/`, `.claude/`, `blueprint/`); it fails because the directory isn't empty.

Supported stacks: Flutter, native iOS, native Android, and React Native. The
installer detects which one you have and writes the matching conventions,
commands, and evidence rules."""),

# Skill list entries
("- `release` - optional Render or Vercel deployment readiness, local config, env review, and smoke-test planning",
 "- `release` - optional App Store, Google Play, and internal distribution readiness: versioning, signing, permissions, store requirements, and a real release build"),
("- `prototype` - optional, pre-build static mockups to lock the look",
 "- `prototype` - optional, pre-build throwaway native screens to lock navigation and design tokens"),
("- `tests` - set up unit testing by default, or a repeatable browser harness with `tests browser`",
 "- `tests` - set up unit, widget, and component testing by default, or a device-level harness with `tests e2e`"),
("- `check` - prove the current spec against the running app, or use `check guide`\n  for a read-only manual review guide: where to go, what to click, what to expect",
 "- `check` - prove the current spec on a real simulator, emulator, or device, per\n  platform, or use `check guide` for a read-only manual guide: where to go, what\n  to tap, what to expect"),

# Deployment paragraph
("""Deployment is also explicit. `/release` can prepare local Render or Vercel config
and run readiness checks, but it must stop before deploy, remote service changes,
push, or publish unless the user gives a separate yes in the current chat.""",
"""Distribution is also explicit. `/release` can prepare local store and signing
config and run readiness checks, but it must stop before any upload, store
submission, track promotion, push, or publish unless the user gives a separate
yes in the current chat. A mobile release cannot be rolled back: you cannot
unpublish a build users installed, and you cannot reuse a build number."""),
])

# Commands block: the installer replaces this per stack, so the template ships a
# placeholder rather than a wrong default.
agents = (DEST / "AGENTS.md").read_text()
start = agents.index("## Commands")
nxt = agents.find("\n## ", start + 5)
end = len(agents) if nxt == -1 else nxt + 1
assert "Next.js" in agents[start:end], "Commands block no longer holds the Next.js default"
agents = agents[:start] + """## Commands

<!-- blueprint:onboarding-required -->
Not set yet. `install.sh` writes your stack's real commands here, and `/onboard`
confirms them against the actual project.

- Run: `TODO`
- Devices: `TODO`
- Tests: `TODO`
- Verify: `TODO`

`Verify` is the umbrella automated gate. It combines only checks this project
actually has, in this order when available: static analysis, tests, then a debug
build. Keep device-dependent and release steps out of it; those belong in
`/check` and `/release`.

Every mobile stack ships a test runner, so testing is usually on from install
rather than opt-in. If this project has no test command yet, run `/tests` or
`$tests` and update this section with the real one.

Device-level testing is separately opt-in. Run `/tests e2e` or `$tests e2e` to
add or normalize a harness and document its exact command as `E2E tests`. Check
and Continuous Mode can then reuse it without installing tooling mid-feature.
Keep it out of `Verify`: it needs a real target and takes minutes.
""" + agents[end:]
(DEST / "AGENTS.md").write_text(agents)

# Automatic verification section
edit("AGENTS.md", [
("""For JavaScript and TypeScript projects, prefer a package script such as `verify`
and use the detected package manager. For other stacks, use the native task
runner or exact combined command. Record the exact command under Commands below.""",
"""Use the stack's native task runner: `flutter` for Flutter, `xcodebuild` for
iOS, `./gradlew` for Android, and the detected package manager for React Native.
Record the exact command under Commands below."""),
("""This setup does not add coverage, browser tests, security scans, or
version matrices; those remain later project choices.""",
"""This setup does not add coverage, device farms, screenshot testing, store
uploads, or OS-version matrices; those remain later project choices. iOS
compilation needs a macOS runner, which costs several times a Linux one, so
scope that job deliberately. Signing secrets never belong in a pull-request
pipeline."""),
])

# Any hand-edit made after a sync is wiped by the next one, so every mobile edit
# belongs here rather than in the file.
edit("AGENTS.md", [
("The workflow is defined by the local skills and context files below.",
 """The workflow is defined by the local skills and context files below.

Stack-specific standards apply only to the stack this project actually uses.
`blueprint/context/platform.md` is authoritative for what counts as proof here;
read it before `/check` and before reporting any step complete."""),
])

# Read-these-when-relevant list gains platform.md
edit("AGENTS.md", [
("- `blueprint/context/coding-standards.md` - read before changing code",
 "- `blueprint/context/coding-standards.md` - read before changing code\n- `blueprint/context/platform.md` - what counts as proof on this stack; read before /check"),
])

# ------------------------------------------------- context and plan files ----
edit("blueprint/context/ai-interaction.md", [
("run `/release render` or `/release vercel`", "run `/release ios` or `/release android`"),
("""declares `Browser tests`, stable browser behavior can include focused harness
   coverage, while remaining UI and integration claims ride on direct browser,
   screenshot, API, and build evidence. Run `/tests` or `/tests browser`""",
 """declares `E2E tests`, stable device behavior can include focused harness
   coverage, while remaining UI and integration claims ride on direct device,
   screenshot, log, and build evidence. Run `/tests` or `/tests e2e`"""),
])

edit("blueprint/project-plan.md", [
("The stack this project will use eg. Next.js, Neon Postgres, ShadCN UI, Claude Haiku for content generation",
 "The stack this app will use eg. Flutter, Riverpod, Supabase, or native iOS with SwiftUI and CloudKit"),
("Target host if known, such as Render or Vercel. Include app type, build command,",
 "Target distribution if known, such as the App Store, Google Play, TestFlight, or an internal track. Include app type, build command,"),
])

# ----------------------------------------------------- surgical skill edits --
for root in [".claude/skills", ".agents/skills"]:
    if not (DEST / root).exists(): continue
    edit(f"{root}/overview/SKILL.md", [
        ("If the plan names Render, Vercel,", "If the plan names the App Store, Google Play,"),
    ])
    edit(f"{root}/status/SKILL.md", [
        ("the shipped `For a standard Next.js project` command marker. When it does,",
         "the shipped `<!-- blueprint:onboarding-required -->` marker. When it does,"),
    ])
    edit(f"{root}/adopt/SKILL.md", [
        ("project's *actual* conventions from Step 1, not the shipped Next.js/Prisma",
         "project's *actual* conventions from Step 1, not the shipped stack-pack"),
        ("standards about Server Actions and Prisma just because that's the default.",
         "standards about a state management library just because that's the default."),
        ("manifest (`package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`,",
         "manifest (`pubspec.yaml`, `build.gradle`, `Package.swift`, `package.json`,"),
    ])
    edit(f"{root}/onboard/SKILL.md", [
        ("- manifest scripts (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, and",
         "- manifest and build files (`pubspec.yaml`, `build.gradle`, `*.xcodeproj`, `package.json`, and"),
        ("- project name, from `package.json`, the folder name, existing docs, or the user",
         "- project name, from the manifest, the folder name, existing docs, or the user"),
        ("""Remove the shipped `<!-- blueprint:onboarding-required -->` marker and the `For
a standard Next.js project` instruction when replacing the placeholder
commands. Status uses the dedicated marker, with the old sentence retained only
as a migration fallback, to distinguish a fresh overlay from a tuned project.""",
         """Remove the shipped `<!-- blueprint:onboarding-required -->` marker and the
`For a standard <stack> project` line when replacing the stack pack's commands
with the project's real ones. Status keys off the marker to tell a fresh
install from a tuned project, so leaving it in place keeps `/status` reporting
that onboarding is still pending."""),
        ("- whether `/check` should require browser evidence for UI work",
         "- whether `/check` should require device evidence for UI work"),
    ])
    edit(f"{root}/doctor/SKILL.md", [
        ("   - If `package.json` exists, compare its scripts against `AGENTS.md` at a high",
         "   - If a manifest exists (`pubspec.yaml`, `build.gradle`, `package.json`), compare its tasks against `AGENTS.md` at a high"),
    ])
    edit(f"{root}/audit/SKILL.md", [
        ("swallowed failures, and missing browser or integration evidence where behavior",
         "swallowed failures, and missing device or integration evidence where behavior"),
        ('"browser flow not audited."', '"device flow not audited."'),
        ("- browser or runtime evidence inspected, when relevant",
         "- device or runtime evidence inspected, when relevant"),
    ])
    edit(f"{root}/feature/SKILL.md", [
        ("""Add focused tests for logic when a test command exists. Add browser coverage only
when a Browser tests command exists and it is proportionate. Do not claim live,
visual, persisted-data, or integration evidence that was not run.""",
         """Add focused tests for logic when a test command exists. Add device coverage only
when an E2E tests command exists and it is proportionate. Every spec carries a
platform matrix: name each target platform the done-whens must hold on. Do not
claim live, visual, persisted-data, or integration evidence that was not run,
and do not claim a platform that was not exercised."""),
    ])
    edit(f"{root}/onboard/SKILL.md", [
        ("""- framework and runtime config (`astro.config.*`, `next.config.*`, `vite.config.*`,
  `tailwind.config.*`, database config, test config)""",
         """- framework and build config (`pubspec.yaml`, `analysis_options.yaml`,
  `build.gradle*`, `*.xcodeproj`, `Podfile`, `app.json`, `metro.config.*`,
  test config)"""),
        ("- source layout, route layout, and app/package directories",
         "- source layout, screen and navigation structure, and module directories"),
    ])
    edit(f"{root}/onboard/SKILL.md", [
        ("- whether `/check` should require device evidence for UI work",
         """- whether `/check` should require device evidence for UI work
- which platforms this project ships, so `/check` knows the full matrix
- which simulators, emulators, or physical devices are available"""),
    ], required=False)

    edit(f"{root}/complete/SKILL.md", [
        ("""- with `verification.uiEvidence: "required"`, UI done-whens have direct browser
  evidence, including screenshots and relevant console and network checks""",
         """- with `verification.uiEvidence: "required"`, UI done-whens have direct device
  evidence on every target platform, including screenshots and the relevant
  device log check"""),
    ])
    edit(f"{root}/implement/SKILL.md", [
        ("""Capture the
configured browser evidence, or stop and ask the user to start the required
server when live evidence cannot run automatically.""",
         """Capture the
configured device evidence through `/device`, or stop and say which target is
missing when live evidence cannot run automatically. Name the evidence tier you
used, per `blueprint/context/platform.md`."""),
    ])
    edit(f"{root}/explore/SKILL.md", [
        ("servers, perform browser interactions, or call state-changing tools. Read",
         "simulators or emulators, install builds, or call state-changing tools. Read"),
    ])

    # autopilot: replace the whole evidence block, since patching one clause
    # leaves the surrounding sentence dangling.
    ap = DEST / root / "autopilot" / "SKILL.md"
    if ap.exists():
        s = ap.read_text()
        old_block = """   - browser, CLI, API, or app-level evidence for behavioral done-whens"""
        assert old_block in s, "autopilot evidence bullet changed upstream"
        s = s.replace(old_block, "   - device evidence for behavioral done-whens, at the tier the claim needs")
        old3 = """3. If UI is involved, inspect the running app when possible. Prefer Playwright if
   it is already installed or declared. Capture screenshots when they add useful
   evidence. Check for console errors and failed requests.
   With `verification.uiEvidence: "required"`, direct browser evidence is
   mandatory and unavailable evidence is a hard stop."""
        assert old3 in s, "autopilot UI block changed upstream"
        s = s.replace(old3, """3. If UI is involved, run it on a real target with `/device`. Pick the cheapest
   tier in `blueprint/context/platform.md` that proves the claim, and name that
   tier. Capture a screenshot per platform the project ships, and read the
   device log: an exception, overflow, skipped frames, or a red box means not a
   pass even when the screen looks right.
   With `verification.uiEvidence: "required"`, direct device evidence is
   mandatory and unavailable evidence is a hard stop.""")
        ap.write_text(s)

# ------------------------------------------- mobile skills replace web ones --
# `disable-model-invocation` is a Claude Code frontmatter key. Upstream omits it
# from the Codex tree, so the mobile skills follow the same convention rather
# than shipping a Claude-only key where it means nothing.
def strip_claude_only_frontmatter(path):
    text = path.read_text()
    lines = text.split("\n")
    kept = [l for l in lines if l.strip() != "disable-model-invocation: true"]
    if len(kept) != len(lines):
        path.write_text("\n".join(kept))

for root in [".claude/skills", ".agents/skills"]:
    if not (DEST / root).exists(): continue
    for skill_dir in sorted((MOBILE / "skills").iterdir()):
        if not skill_dir.is_dir(): continue
        target = DEST / root / skill_dir.name
        shutil.rmtree(target, ignore_errors=True)
        shutil.copytree(skill_dir, target)
        if root == ".agents/skills":
            for md in target.rglob("SKILL.md"):
                strip_claude_only_frontmatter(md)

# --------------------------------------------------------- stack packs -------
shutil.copytree(MOBILE / "stacks", DEST / "stacks", dirs_exist_ok=True)

# Root context files are placeholders the installer overwrites per stack. The
# upstream Next.js standards are removed outright rather than edited: nothing in
# them survives the move to mobile.
shutil.copy2(MOBILE / "stacks" / "flutter" / "platform.md",
             DEST / "blueprint" / "context" / "platform.md")
(DEST / "blueprint" / "context" / "coding-standards.md").write_text(
    (MOBILE / "coding-standards-placeholder.md").read_text())

if misses:
    print("TRANSFORM FAILED, upstream wording changed:")
    for m in misses: print("  " + m)
    sys.exit(1)
print("transform applied cleanly")
