## Fixes

- Verify Apply confirmation in a real-player raid: simple moves, full-group
  swaps, longer cycles, leader moves, ordering with empty/occupied staging
  groups, offline members, sparse board slots, and bench groups. Check that
  unrelated role/assist updates do not advance the queue, including bursts or
  updates near the timeout. Verify the 50 ms minimum request spacing and that
  roster changes during a pacing wait are rechecked before another move.
  Check that timeouts stop without resending moves,
  and that combat, roster/leadership changes, lost assist, or external group
  moves stop the current run. Recheck a new Apply after an
  aborted run and final ordering after evacuation/refill. Story-mode follower
  movement is restricted and is not a reliable movement test.
- Validate cross-group swaps for player ordering without an empty staging group
  before changing the working evacuation/refill path. In a test raid, place
  non-leaders A and B in one group and X in another, then swap `A <-> X`,
  `A <-> B`, and `B <-> X`. Wait for each roster update and resolve current raid
  indices by name before each swap. Compare `GetRaidRosterInfo` order before and
  after: A/B should exchange positions, with X restored. Check full and partial
  groups and leader pinning before using this in the planner. The old bridge
  sequence replaced in `71e8b4f` attempted a same-group second swap; do not reuse
  that sequence.
