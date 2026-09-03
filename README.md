# Raid Group Manager

A World of Warcraft addon for organizing and applying raid group layouts. Design your raid composition with drag-and-drop, save layouts for reuse, and apply them to your raid with a single click.

## Features

### Grid-Based Layout Editor
- 8-group grid (40 slots) with drag-and-drop support
- Swap players between slots, drag from unassigned panels, or type names manually
- Right-click any slot to clear it
- Raid leader and raid assistant icons display directly on placed raid members
- Offline roster-backed members keep their role and assistant context with muted row styling
- Grid state persists across reloads — pick up where you left off

### Role/Class Templates
- Place template slots like "Tank - Warrior" or generic "Healer" instead of specific player names
- Templates auto-resolve to matching raid members when you click Apply
- Two-pass resolution: class+role specific templates match first, then generic role-only templates
- Generic templates use class-paired distribution across groups (e.g. 2 DKs split one per side)
- Unmatched templates remain in place for manual assignment

### Layout Management
- Select a named layout as the current save target, or click it again to keep the board without a selected layout
- Save changes back to the selected layout, create a copy with Save As, or start with a new blank layout
- Clear the board without deleting the selected layout
- Selected layouts persist across reloads, with an optional Auto-save mode for grid changes
- Import/export layouts in multiple formats: paired columns, horizontal, vertical, or encoded strings
- Preset layouts included for common mythic and heroic compositions

### Smart Group Splitting
- **Split Odd/Even**: Distribute players across odd and even active raid groups
- **Split Halves**: Pack players into two contiguous active group blocks
- Role-balanced: each side gets equal tanks, healers, melee, and ranged
- Class-paired: duplicate classes land at matching positions on each side
- Deterministic: same roster always produces the same split
- Raid-size aware: uses 1 group for party difficulties, 6 groups for Normal, Heroic, Looking For Raid, and Timewalking raids, 4 for fixed Mythic, 5 for Mythic Flexible, and 8 for unknown raid types
- Raid leader aware: split and apply actions keep the raid leader in slot 1 of their subgroup

### Unassigned Panel
Four browsing modes via tab bar:
- **Raid**: Shows current raid members not yet placed in the grid
- **Guild**: Shows guild members at your level or above, grouped by guild rank
- **Role**: Shows all role/class template combinations for drag-and-drop
- **Roster**: Import your external roster from wowutils JSON exports

### Assistant Management
- Middle-click subgroup slots or Raid tab rows to promote or demote raid assistants when you are raid leader
- Middle-click Roster tab members to save who should be assistant in your ideal raid roster
- Saved assistant choices are promoted during invites and sync to the live raid while you are raid leader
- Title-bar crown help icon summarizes the assistant controls in-game

### Roster Import
- Import your guild roster from [wowutils](https://wowutils.com) JSON exports
- Extracts each member's main and alt characters with class and role information
- Optionally groups characters under compact member-name headings in the order defined by the export
- Imported roster persists across sessions
- Drag roster members directly into grid slots
- Mark imported roster members who should receive assistant when you invite or lead the raid
- Built-in import popup includes the Wowutils roster export steps and a copyable URL

### Group Management
- Invite assigned group members or imported roster characters from the button bar
- Skips known-offline characters using group, guild, and friend status data
- Automatically converts parties to raids when needed, including starter invites when you are solo
- Promotes saved assistant choices during invite flows when you are raid leader
- Prints invite summaries for invited, offline, not invited, and did-not-accept characters
- Raid leaders can disband the current raid from the button bar after confirmation

### Spec Detection
- Background inspect cache queues raid members for inspection as they join
- Cached spec IDs persist across reloads and between instances within a raid group
- Cache resets on raid join/leave to stay fresh; zone changes re-queue uncached members
- Failed inspects automatically retry (up to 3 attempts per player, including offline members)
- Retry counter resets when an offline player reconnects
- Live spec swaps detected automatically via PLAYER_SPECIALIZATION_CHANGED (debounced)
- Layered fallback: inspect cache → tank/healer spec IDs → melee DPS spec IDs → class defaults → Agility vs Intellect stats
- Pure-melee classes (DK, Warrior, Rogue, Monk, Paladin) can never be misclassified as ranged

### Quality of Life
- Minimap button to toggle the window
- Keybinding support — bind "Toggle Window" in the Key Bindings UI
- Frame position and scale remember where you left them
- Auto-hides during boss encounters, reopens when you're alive after
- Group assignment aborts if raid membership changes while applying a layout
- Player and party members show as online in subgroup slots outside raids without applying party reshapes
- Toast notifications for layout apply results and other feedback
- Clearer button borders and tab hover states for easier interaction
- Custom role icons distinguishing melee DPS from ranged DPS
- Scale-aware pixel snapping for consistent grid spacing and interface borders

## Slash Commands

| Command | Description |
|---------|-------------|
| `/rgm` | Toggle the main window |
| `/rgm apply <name>` | Apply a saved layout by name |
| `/rgm presets` | Re-add preset layouts to your list |
| `/rgm debug` | Toggle debug messages |
| `/rgm help` | Show command help |

## Dependencies

All libraries are bundled in the `Libs/` folder, with LibPopupSlider maintained as a Git submodule:
- Ace3 (AceAddon, AceDB, AceConsole, AceEvent, AceSerializer)
- LibDataBroker-1.1
- LibDBIcon-1.0
- LibPopupSlider-1.0

Development clones should initialize embedded submodules with `git submodule update --init --recursive`.
