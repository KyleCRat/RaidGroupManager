# Changelog

## [12.1.0-14] - 2026-09-03

### Added
- Added an optional WowUtils import mode that groups roster characters under member names while preserving export order
- Added selected-layout Save, Save As, and Clear controls above the group board, plus an inline New Blank Layout action
- Added compact guild-rank headers above draggable characters in the Guild tab
- Added contextual tooltips for layout controls, board workflow actions, draggable entries, and live versus saved assistant behavior
- Added confirmation before deleting a saved layout

### Changed
- Made the selected layout an explicit, reload-persistent save target that can be deselected without changing the board
- Replaced legacy checkboxes with compact Blizzard square tertiary controls and clear disabled states
- Standardized tooltip titles, descriptions, colors, and text sizing across the addon
- Tightened vertical spacing between group blocks to a compact four-pixel gap
- Matched the browsing tab and Layouts header heights so their scroll areas align
- Reworked interface scaling so borders remain one physical pixel, rows retain consistent pixel-snapped spacing, and the frame height follows the resulting content at every supported scale
- Standardized main frame padding, column spacing, and action gaps at 8 pixels while keeping tab and list headers attached to their content
- Made text inputs easier to identify with consistent surfaces, focus borders, and placeholder labels
- Replaced legacy panel scrollbars with Blizzard's modern minimal scrollbar style and balanced their vertical spacing
- Updated the WowUtils roster import instructions for its current Group Hub export workflow
- Replaced the embedded LibPixelPerfect copy with RGM-owned pixel utilities and moved LibPopupSlider to its canonical Git submodule

### Fixed
- Kept Apply-time template resolution synchronized with Auto-save
- Prevented Load Roster from clearing the board when you are not in a raid
- Ensured `/rgm apply <name>` can load its layout before the main window has been opened
- Refreshed layout tooltips immediately when the selected save target changes

## [12.1.0-13] - 2026-09-03

### Added
- Added a confirmed, raid-leader-only Disband control to remove all other raid members

### Changed
- Shortened the bottom-bar invite button label to Invite
- Routed chat output directly through Raid Group Manager with a light-gray RGM: prefix so chat addons can identify its messages correctly
