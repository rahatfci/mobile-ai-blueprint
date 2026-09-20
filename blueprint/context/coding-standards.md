# Coding Standards

> **Not set yet.** `install.sh` replaces this file with the conventions for your
> stack: Flutter, native iOS, native Android, or React Native. If you are
> reading this inside a real project, the install did not complete; rerun it, or
> copy the file yourself from `stacks/<your-stack>/coding-standards.md`.
>
> Once installed, edit it freely. It is yours, and `/onboard` tunes it further
> against the actual project.

Every stack pack covers the same ground:

- **Language conventions** - what the type system and null handling demand
- **UI framework** - the rebuild, recomposition, or render rules that decide
  whether the app is fast or janky
- **State and lifecycle** - including process death and configuration change,
  which mobile has and the web mostly does not
- **File organization and naming**
- **Accessibility** - not optional, and verified with the platform's real
  screen reader rather than by reading the code
- **Testing** - the unit, widget or component, and device tiers, and which of
  them gate a build step
- **Comments and writing** - comment the why, never the what

## Shared rules, whatever the stack

These hold across all four packs and survive any edit you make:

- Build for established requirements, not hypothetical scale. Reuse what the
  platform already gives you before adding a dependency.
- A dependency with native code is a structural change, not an install: it needs
  a rebuild, may break the managed workflow, and can conflict with another
  module's native version.
- Never commit signing material: keystores, `.p12`, `.mobileprovision`, `.jks`,
  or service account JSON. Reference them by name.
- Accessibility and real trust-boundary validation are never trimmed for
  simplicity.
- No em dashes (U+2014) in generated content: docs, comments, commit messages,
  READMEs, specs. Use a hyphen for `term - description`, or rephrase. Avoid en
  dashes and the ellipsis character too.
