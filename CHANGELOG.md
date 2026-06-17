# Changelog

## [12.0.7-10] - 2026-06-17

### Added
- Added difficulty-based active subgroup rules for party, Normal, Heroic, Looking For Raid, Timewalking, Mythic, and Mythic Flexible raid sizes

### Changed
- Mythic Flexible raids now use groups 1-5 for split, template resolution, and apply logic
- Split and apply now share the same active subgroup sizing rules, with unknown raid types defaulting to all 8 groups

## [12.0.7-9] - 2026-06-04

### Added
- Added middle-click assistant controls for subgroup slots and Raid tab rows when you are raid leader
- Added saved assistant choices for imported roster members from the Roster tab
- Added automatic assistant promotion during invite flows and live raid sync while you are raid leader
- Added a title-bar crown help icon describing the assistant controls

### Changed
- Subgroup rows now distinguish the actual raid leader icon from raid assistant icons
- Offline roster-backed subgroup members now use muted row styling while keeping desaturated role and assistant icons
- Player and party members now display as online in subgroup slots outside raids without applying party reshapes
- Split and apply flows now keep the raid leader in slot 1 of their subgroup
- Raid roster scanning and name matching now handle sparse raid slots and normalized names more consistently

### Fixed
- Assist changes outside a raid now report that you are not in a raid before checking the target player
- Applying a layout now moves the raid leader into slot 1 and shows the required-position message when needed
