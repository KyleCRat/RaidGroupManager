# Changelog

## [Unreleased]

### Added
- Added an optional WowUtils import mode that groups roster characters under member names while preserving export order

### Changed
- Reworked interface scaling so borders remain one physical pixel, rows retain consistent pixel-snapped spacing, and the frame height follows the resulting content at every supported scale
- Standardized main frame padding, column spacing, and action gaps at 8 pixels while keeping tab and list headers attached to their content
- Made text inputs easier to identify with consistent surfaces, focus borders, and placeholder labels
- Replaced legacy panel scrollbars with Blizzard's modern minimal scrollbar style and balanced their vertical spacing
- Updated the WowUtils roster import instructions for its current Group Hub export workflow
- Replaced the embedded LibPixelPerfect copy with RGM-owned pixel utilities and moved LibPopupSlider to its canonical Git submodule

## [12.1.0-13] - 2026-09-03

### Added
- Added a confirmed, raid-leader-only Disband control to remove all other raid members

### Changed
- Shortened the bottom-bar invite button label to Invite
- Routed chat output directly through Raid Group Manager with a light-gray RGM: prefix so chat addons can identify its messages correctly

## [12.1.0-12] - 2026-08-11

### Fixed
- Updated specialization inspection to use the World of Warcraft 12.1 API and safely fall back when specialization data is restricted or unavailable

### Changed
- Updated client metadata to require World of Warcraft Retail 12.1.0
