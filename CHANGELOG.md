# Changelog

All notable changes to Raid Group Manager will be documented in this file.

## [12.0.1-3] - 2026-04-07

### Fixed
- Fix cycle-based group swaps (3+ player chains) placing everyone in wrong groups
- Fix Feral Druid, Enhancement Shaman, and Devourer DH being classified as ranged DPS
- Fix split odd/even and split halves not equalizing group sizes across roles

### Added
- Generic templates (e.g. ~MELEE-ANY) now use class-paired distribution across groups during Apply
- Background inspect cache: queues `NotifyInspect` calls as players join, caching spec IDs over time
- Spec cache persists across reloads; wipes on raid join/leave or zone change
- Watches `PLAYER_SPECIALIZATION_CHANGED` to re-inspect players who swap specs mid-raid
- `/rgm debug` toggle for debug messages

### Changed
- Removed Demon Hunter from always-melee fallback list (Devourer spec is ranged)
- Melee vs ranged detection now uses a layered approach: inspect cache → GetSpecialization (self) → class defaults → Agility vs Intellect stat comparison
- Player's own spec now detected via GetSpecialization instead of unreliable GetInspectSpecialization

## [12.0.1-2] - 2026-04-06

Attempt to fix group sorting

## [12.0.1-1] - 2026-04-04

Initial Addon Release: See README.md for features
