## Fixes

- Validate cross-group swaps for player ordering without an empty staging group
  before changing the working evacuation/refill path. In a test raid, place
  non-leaders A and B in one group and X in another, then swap `A <-> X`,
  `A <-> B`, and `B <-> X`. Wait for each roster update and resolve current raid
  indices by name before each swap. Compare `GetRaidRosterInfo` order before and
  after: A/B should exchange positions, with X restored. Check full and partial
  groups and leader pinning before using this in the planner. The old bridge
  sequence replaced in `71e8b4f` attempted a same-group second swap; do not reuse
  that sequence.
