# Changelog

## [Unreleased]

### Added
- Added middle-click automatic assistant choices to Guild rows, with the same crown indicators and live updates as the Roster tab

### Changed
- Reduced inspections by resolving certain roles directly from class and assigned role, with slow cached-spec refreshes after reloads and faster checks for new members, spec changes, or longer logouts
- Reduced repeated roster and role lookups when refreshing group slots and resolving layouts

### Fixed
- Fixed player role detection when WoW's deprecated API fallbacks are disabled
- Prevented role display and group splitting errors when character stats are restricted
- Improved role fallbacks to use imported roster information before assumptions, including role and class balancing before characters join your group
- Fixed Apply leaving generic role templates unfilled despite available players when the slots are unevenly distributed between two groups
- Apply now warns when player ordering must be skipped because no free group is available, instead of reporting that the layout already matches or was fully applied
- Fixed overlapping inspect requests and bypassed retry limits; offline and unavailable members no longer consume failed attempts, and Raid row icons update when inspected roles change

## [12.1.5-17] - 2026-10-21

### Fixed
- Fixed saved assistants not being promoted when a raid forms, leadership is passed to you, or marked members join outside RGM's invite flow
- Fixed assistant controls relying on WoW's deprecated API fallbacks

## [12.1.5-16] - 2026-10-06

- Updated for WoW 12.1.5.

### Added
- Added a right-aligned disconnect icon and offline tooltip status for raid and party members placed in group slots

### Fixed
- Fixed Apply ignoring players and templates placed in bench groups outside the instance's active group limit

## [12.1.0-15] - 2026-09-03

### Added
- Added `/rgm disband` and `/rgm d` commands for the confirmed raid-disband workflow

### Fixed
- Prevented action button labels from being truncated when the window is first opened after login
