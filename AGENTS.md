# Raid Group Manager Development

Use the installed client's local Blizzard code and art exports through the
wow-blizzard-ref skill. Do not substitute GitHub UI-source mirrors. If the export
is stale, missing, or its build is unknown, ask in plain chat for a refreshed
export before making build-dependent conclusions.

Ask questions in plain chat, not interactive prompt widgets. Do not stage,
commit, tag, push, or install development tools unless explicitly requested.

## Lua Style

Baseline: StyLua 2.5.2 and Selene 0.31.0. Configuration targets Lua 5.1, UTF-8,
LF, four spaces, and an 80-column wrapping guide. Keep nonempty functions,
callbacks, loops, and multi-branch conditionals multiline. Short simple
single-branch conditionals may collapse. Review logical spacing and structure
even when formatting passes.

Owned Lua is the addon root and UI directory. Explicit formatter ignores cover
upstream libraries only; preserve their source. LibPopupSlider-1.0 is maintained
in its own submodule, with its own style configuration and checks. Root StyLua
also traverses it; root Selene excludes Libs because the maintained library is
linted separately. Add only reviewed globals to each repository's wow.yml.

Before handoff, run from this root:

```powershell
stylua --check .
selene .
git diff --check
```

Run the same three checks from Libs/LibPopupSlider-1.0 when it changes, plus its
existing Lua 5.1 tests. Apply formatting with stylua --verify . and use
--respect-ignores for explicit file arguments. Require zero lint findings.

Validate owned Lua with luac5.1 -p and resolve TOC/XML load paths. Do not write
automated addon tests unless explicitly requested; use static review and
in-game checks. Reusable libraries retain automated tests. Do not claim in-game
validation from static tooling. Keep CHANGELOG.md current for behavioral work.

## In-Game Changelog

Follow `Docs/CHANGELOG_AUTHORING.md` when preparing release notes. Generated
`Changelog/ReleaseNotes.lua` is a release artifact; do not edit it by hand or
regenerate it during routine development. LibChangelog read status and notice
preferences must remain in account-wide `db.global.changelog`, outside profiles.
