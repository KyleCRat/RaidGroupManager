# Changelog

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
