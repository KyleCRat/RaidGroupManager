# Changelog

## [12.0.1-5] - 2026-04-14

### Fixed
- Fix pure-melee classes (DK, Warrior, Rogue, Monk, Paladin) sometimes showing as ranged when role assignment or spec lookup returned unexpected values
- Fix spec change detection not working for cross-realm players (only same-realm players were updating)
- Fix failed inspects (timeouts, out-of-range) never being retried, leaving players permanently uncached
- Fix rapid PLAYER_SPECIALIZATION_CHANGED events clearing freshly cached spec data

### Changed
- Spec cache now persists between instances within the same raid group (no longer wipes on every zone change)
- Spec-based fallback now detects tank and healer specs directly, covering cases where role assignment returns NONE
- Added retry system for failed inspects (up to 3 attempts per player, resets on zone change)
- Debounced spec change handler to prevent redundant re-inspects

### Added
- Roster imports now saved per-character instead of globally

## [12.0.1-4] - 2026-04-09

### Fixed
- Fix group moves involving the raid leader placing players in wrong groups
- Fix staging group incorrectly containing bench players
- Refresh grid slot display after caching a player's spec via inspect

### Added
- Toast notifications for layout apply results and other actions
- Raid leader is now placed first during group assignment to avoid move conflicts
