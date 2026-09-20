# Mobile Blueprint

A file-backed, spec-driven AI coding workflow for mobile apps. Flutter, native
iOS, native Android, and React Native.

Build one feature at a time, behind review gates, with evidence from a real
device instead of a guess from reading the code.

This is the mobile counterpart to [AI Blueprint](https://ai-blueprint.dev),
which targets web projects. The workflow engine is shared; everything that
touches a platform is not.

**Not an app starter.** Scaffold your app first (`flutter create`, Xcode,
Android Studio, `create-expo-app`), then overlay this on top.

## Install

One line, from the root of your app:

```bash
curl -fsSL https://raw.githubusercontent.com/rahatfci/mobile-ai-blueprint/main/install.sh | sh
```

That is the whole install. No Node, no npm, no global tool. `sh`, `curl`, and
`tar` are enough, which covers every macOS machine, every Linux CI runner, and
WSL.

See what it would do first:

```bash
curl -fsSL https://raw.githubusercontent.com/rahatfci/mobile-ai-blueprint/main/install.sh | sh -s -- --dry-run
```

Reading a script before piping it to a shell is reasonable, and these docs are
not going to pretend otherwise:

```bash
curl -fsSL https://raw.githubusercontent.com/rahatfci/mobile-ai-blueprint/main/install.sh -o install.sh
less install.sh
sh install.sh
```

Or clone and run it, with nothing downloaded at install time:

```bash
git clone https://github.com/rahatfci/mobile-ai-blueprint
cd my-app
../mobile-ai-blueprint/install.sh
```

Every path produces an identical result.

### Options

```
--stack <name>      flutter | ios | android | react-native
--adapter <list>    claude, codex, copilot, opencode (comma separated)
--target <dir>      Project to install into. Defaults to the current directory.
--from <dir>        Install from a local checkout instead of downloading.
--dry-run           Print the plan and change nothing.
--force             Overwrite existing Blueprint files without asking.
--yes               Accept detected values without prompting.
```

Pass flags through the one-liner with `sh -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/rahatfci/mobile-ai-blueprint/main/install.sh \
  | sh -s -- --stack flutter --adapter claude,codex
```

**Most of the time you need none of them.** Stack and AI tool are detected, and
the target is wherever you are. Reach for a flag when:

| Flag | When you need it |
| --- | --- |
| `--stack` | Detection failed, or you want a different pack than the obvious one. A React Native project where you intend to work mostly in the native iOS module is the common case: detection says `react-native`, you want `ios`. |
| `--adapter` | You want more than one tool, or a tool that is not already set up. Detection only finds what is already there, so a fresh project has nothing to find. |
| `--target` | You are not standing in the app. Monorepos are the main case: run it from the repo root with `--target apps/mobile`. |
| `--from` | Air-gapped, or testing a local change to the installer. |
| `--force` | Reinstalling or upgrading over an existing install, in a script. |

Detection reads `pubspec.yaml`, `package.json`, `*.xcodeproj` or `Package.swift`,
and Gradle files. Cross-platform projects are matched before native ones, so a
Flutter or React Native app with `ios/` and `android/` directories is not
mistaken for a native Android project.

If the stack cannot be detected and the installer cannot ask, it **stops** and
tells you to pass `--stack`. It never guesses: the wrong pack means wrong
conventions, wrong commands, and wrong evidence rules.

Adapters are additive. Installing `claude` today and `codex` next month leaves
both trees in place.

## What gets installed

```
AGENTS.md                            cross-tool entry point, with your real commands
CLAUDE.md                            Claude Code entry point, imports AGENTS.md
blueprint/
  context/
    coding-standards.md              your stack's conventions
    platform.md                      what counts as proof on your stack
    project-overview.md              generated project context
    current-feature.md               the one thing being built right now
    findings.md                      audit findings ledger
  project-plan.md                    you write this
  build-plan.md                      you write this
  history/                           shipped features, fixes, rollbacks
.claude/skills/  or  .agents/skills/ the workflow commands
```

## The workflow

```
/feature  ->  /implement  ->  /check  ->  /audit current  ->  /complete
(spec)        (build it)      (prove     (review the        (log it,
                               it on      code)              merge it)
                               a device)
```

Approve the spec before implementing. `/check` proves behavior on a real target.
`/audit` records findings, and blocking findings stop `/complete`.

Invoke skills in your AI chat, not your terminal: `/onboard` in Claude Code,
`$onboard` in Codex, or ask OpenCode and Copilot to run the matching skill.

### Mobile-specific commands

| Command | What it does |
| --- | --- |
| `/device` | List, boot, and drive simulators, emulators, and devices. Install builds, capture screenshots and logs. |
| `/check` | Prove each done-when on every target platform, at a named evidence tier. |
| `/check guide` | Read-only manual test instructions for claims needing hardware you do not have. |
| `/tests` | Unit, widget, and component testing. `/tests e2e` for device-level flows. |
| `/prototype` | Throwaway native screens to lock navigation and design tokens. |
| `/release` | Store readiness: versioning, signing, permissions, release build. Stops before upload. |
| `/ci` | One Verify command plus automatic checks, with macOS runner and caching handling. |

The rest of the workflow (`/feature`, `/implement`, `/complete`, `/audit`,
`/status`, `/doctor`, `/rollback`, `/explore`, `/brief`, `/debug`, `/fix`,
`/overview`, `/discovery`, `/adopt`, `/autopilot`, `/continuous`) is the shared
Blueprint loop.

## What is different from the web workflow

### There is no dev server

The web loop starts a server and opens a URL. Mobile has no equivalent, so
evidence means build, install on a target, drive the UI, screenshot.

That is expensive, so `blueprint/context/platform.md` defines an **evidence
ladder**, and `/check` picks the cheapest tier that honestly proves each claim,
then names the tier it used.

    tier 0  static analysis                 seconds
    tier 1  unit and widget tests           seconds
    tier 2  hot reload on a warm target     seconds
    tier 3  full rebuild and install        minutes
    tier 4  integration or e2e flow         many minutes
    tier 5  release build on real hardware  longer

Tier 0 never proves a done-when on its own. A green build is a precondition, not
evidence, and treating it as evidence is the most likely false pass on every one
of these stacks.

### One codebase is two apps

For Flutter and React Native, every feature spec carries a **platform matrix**,
and `/check` reports per platform:

    Done-when                      iOS        Android
    Cart badge updates on add      pass (t2)  pass (t2)
    Back gesture returns to list   skip: n/a  fail (t3): exits app

A done-when proven on iOS and blank on Android is reported as partial, never as
a pass.

### Releases cannot be undone

You cannot unpublish a build users installed, cannot reuse a build number, and a
fix waits in a review queue. So `/release` checks versioning, signing expiry,
permissions, and store requirements, runs a real release build, and then
**stops**. Uploading needs an explicit yes in the chat.

### Prototypes are native

Mocking a mobile screen in HTML answers none of the questions worth prototyping:
safe areas, scroll physics, keyboard behavior, touch targets, font scaling.

## Stack support

| Stack | Detected by | Test gate | Distribution |
| --- | --- | --- | --- |
| Flutter | `pubspec.yaml` | `flutter test` | App Store, Play |
| iOS | `*.xcodeproj`, `Package.swift` | `xcodebuild test` | App Store, TestFlight |
| Android | Gradle files | `testDebugUnitTest` | Play, internal tracks |
| React Native | `package.json` | `npm test` | App Store, Play |

Adding a stack (Kotlin Multiplatform, .NET MAUI) means adding one directory
under `stacks/` with four files. See `DESIGN.md`.

## Development

```bash
./scripts/test-install.sh              # 43 assertions, no SDKs or devices needed
./scripts/build-release.sh dist/       # versioned tarball plus checksum
./scripts/sync-upstream.sh ../ai-blueprint   # pull upstream workflow improvements
```

About eighteen skills are shared with upstream AI Blueprint and improve there.
`sync-upstream.sh` pulls those forward and reapplies the mobile edits. Every
edit is asserted, so an upstream rewording fails loudly and names the line
rather than silently shipping web guidance in a mobile install.

## License

MIT. Derived from [AI Blueprint](https://github.com/aiblueprinthq/ai-blueprint)
by Brad Traversy, which is also MIT.
