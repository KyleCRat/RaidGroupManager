# Changelog

## [12.0.7-7] - 2026-05-28

### Added
- Added support for WoW Interface 120007
- Added an Invite to Group button for assigned group members or imported roster characters
- Added invite flow reporting for invited, offline, not-invited, and did-not-accept characters
- Added automatic raid conversion handling for invite flows, including starter invites when solo
- Added Wowutils roster import instructions with a copyable URL popup
- Added an example Wowutils roster export under Docs

### Changed
- Roster imports now handle main and alt characters with role/spec context more accurately
- Roster view sorting now groups imported characters by role
- Addon chat output now uses the shorter RGM prefix
- Bottom button bar sizing and padding is normalized across actions
- Internal project notes and examples moved under Docs

### Fixed
- Abort group assignment if raid membership changes while applying a layout
- Fixed leaked globals from GridSlot drag/drop helpers
- Hardened raid conversion checks to use Blizzard's allowed-conversion gate before converting

## [12.0.5-6] - 2026-04-15

### Fixed
- Fix offline raid members causing uncapped inspect retries indefinitely

### Changed
- Debug messages now print in execution order (decision → action) for clearer troubleshooting
- Inspect retry delay reduced from 10s to 5s
- Offline/disconnected players now count toward the 3-retry limit (previously skipped without counting)
- Retry counter resets when an offline player reconnects

### Added
- Keybinding support — bindable "Toggle Window" in Key Bindings UI under "Raid Group Manager"
