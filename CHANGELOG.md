# Changelog

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
