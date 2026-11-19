# Authoring Update Notes

Keep the Unreleased section of `CHANGELOG.md` current during development.
`Changelog/ReleaseNotes.lua` is a generated release artifact, not a live copy of
development notes. Do not edit it by hand or regenerate it after routine changes.
The initial integration includes an Unreleased preview, available manually
without automatic notices or release acknowledgement.

## Release Preparation

Finalize the version and its notes in `CHANGELOG.md`, then curate a few useful
highlights in `Changelog/Highlights.lua`, keyed by that exact version. Keep it
aligned with the addon's TOC version and release tag. Do not list every fix twice.

From the addon root, using Lua 5.1 and the finalized version in place of `VERSION`:

```powershell
lua Libs/LibChangelog-1.0/tools/generate.lua CHANGELOG.md Changelog/ReleaseNotes.lua VERSION
lua Libs/LibChangelog-1.0/tools/generate.lua CHANGELOG.md Changelog/ReleaseNotes.lua VERSION --check
```

Run the generator and its check during release preparation, not routine edits.
The generated file uses WoW's addon namespace; `Changelog.lua` registers its
contents with the AceAddon instance after AceDB initialization. Tagged releases
are eligible for automatic notices. Unreleased previews never set a read tag.

## Storage And Dependencies

LibChangelog's `acknowledgedVersion` and `autoShow` are stored through AceDB at
`RaidGroupManagerDB.global.changelog`, under the account-wide `SavedVariables`
declaration. Neither belongs in `db.char` or `db.profile`. Reading/dismissing a
release or changing notice preferences on one character applies to every
character on the same account, including characters using different profiles.
Opening a page alone is not acknowledgement; LibChangelog owns that behavior.

Keep the LibChangelog and LibModernSettings submodules on reviewed release tags
matching `.pkgmeta`. Load LibStub, LibModernSettings, then LibChangelog. Preserve
the complete LibModernSettings Media directory; no separately installed library
or addon should be needed. Do not modify the embedded library sources.

## In-Game Checks

- Open `/rgm changelog`, `/changelog`, and the Settings page with only RGM enabled.
- Verify a released tag is marked read after selection, scrolling, expanding its
  notes, or dismissing the popup. Switch characters and confirm it stays read.
- Disable automatic notices, reload or switch characters, and confirm the
  preference persists while manual browsing remains available.
- Verify a genuinely newer release notifies once when enabled, but a same-version
  reload does not. Unreleased previews should never open automatically.
- With RCC and AirAuras enabled, confirm all three entries share the changelog
  window and retain independent account-wide read status/preferences.
- Confirm combat, loading, cinematics, and ready checks defer notices without
  marking interrupted updates as read.
