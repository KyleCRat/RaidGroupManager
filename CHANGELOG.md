# Changelog

## [12.0.7-8] - 2026-05-29

### Added
- Added a top-right Scale button with a 50% to 150% frame scale slider
- Added LibPopupSlider-1.0 and moved embedded library loading into embeds.xml
- Added cursor-following drag previews for grid slots, raid/guild/roster rows, and role templates

### Changed
- Drag sources now fade more strongly while dragging so the cursor preview is the primary visual
- Button borders now use a clearer normal and hover state
- Unassigned panel tabs now show a background hover state
- Main and modal frames now raise as a whole when selected to avoid child-frame layering issues
- Bottom button width calculation now accounts for unbounded text width to prevent label clipping
- Removed the redundant Scale tooltip from the scale button

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
