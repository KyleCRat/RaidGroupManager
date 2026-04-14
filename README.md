# Raid Group Manager

A World of Warcraft addon for organizing and applying raid group layouts. Design your raid composition with drag-and-drop, save layouts for reuse, and apply them to your raid with a single click.

## Features

### Grid-Based Layout Editor
- 8-group grid (40 slots) with drag-and-drop support
- Swap players between slots, drag from unassigned panels, or type names manually
- Right-click any slot to clear it
- Grid state persists across reloads — pick up where you left off

### Role/Class Templates
- Place template slots like "Tank - Warrior" or generic "Healer" instead of specific player names
- Templates auto-resolve to matching raid members when you click Apply
- Two-pass resolution: class+role specific templates match first, then generic role-only templates
- Generic templates use class-paired distribution across groups (e.g. 2 DKs split one per side)
- Unmatched templates remain in place for manual assignment

### Layout Management
- Save and load named layouts
- Auto-save option to keep your active layout in sync with grid changes
- Import/export layouts in multiple formats: paired columns, horizontal, vertical, or encoded strings
- Preset layouts included for common mythic and heroic compositions

### Smart Group Splitting
- **Split Odd/Even**: Distribute players across odd (1/3/5/7) and even (2/4/6/8) groups
- **Split Halves**: Pack players into two contiguous group blocks (1-2 and 3-4 for mythic)
- Role-balanced: each side gets equal tanks, healers, melee, and ranged
- Class-paired: duplicate classes land at matching positions on each side
- Deterministic: same roster always produces the same split
- Mythic-aware: automatically uses 4 groups in mythic difficulty

### Unassigned Panel
Four browsing modes via tab bar:
- **Raid**: Shows current raid members not yet placed in the grid
- **Guild**: Shows guild members at your level or above
- **Role**: Shows all role/class template combinations for drag-and-drop
- **Roster**: Import your external roster from wowutils/Party Shark JSON exports

### Roster Import
- Import your guild roster from [wowutils](https://wowutils.com) / Party Shark JSON exports
- Extracts each member's main character with class and role information
- Imported roster persists across sessions
- Drag roster members directly into grid slots

### Spec Detection
- Background inspect cache queues raid members for inspection as they join
- Cached spec IDs persist across reloads and between instances within a raid group
- Cache resets on raid join/leave to stay fresh; zone changes re-queue uncached members
- Failed inspects automatically retry (up to 3 attempts per player)
- Live spec swaps detected automatically via PLAYER_SPECIALIZATION_CHANGED (debounced)
- Layered fallback: inspect cache → tank/healer spec IDs → melee DPS spec IDs → class defaults → Agility vs Intellect stats
- Pure-melee classes (DK, Warrior, Rogue, Monk, Paladin) can never be misclassified as ranged

### Quality of Life
- Minimap button to toggle the window
- Frame position remembers where you left it
- Auto-hides during boss encounters, reopens when you're alive after
- Toast notifications for layout apply results and other feedback
- Custom role icons distinguishing melee DPS from ranged DPS
- Pixel-perfect grid rendering via LibPixelPerfect

## Slash Commands

| Command | Description |
|---------|-------------|
| `/rgm` | Toggle the main window |
| `/rgm apply <name>` | Apply a saved layout by name |
| `/rgm presets` | Re-add preset layouts to your list |
| `/rgm debug` | Toggle debug messages |
| `/rgm help` | Show command help |

## Installation

1. Download and extract to `Interface/AddOns/RaidGroupManager`
2. Ensure all library dependencies are in the `Libs/` folder
3. Reload UI or restart WoW

## Dependencies

All libraries are bundled in the `Libs/` folder:
- Ace3 (AceAddon, AceDB, AceConsole, AceEvent, AceSerializer)
- LibDataBroker-1.1
- LibDBIcon-1.0
- LibPixelPerfect-1.0
