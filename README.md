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
- Raid leader aware: split and apply actions keep the raid leader in slot 1 of their subgroup

### Unassigned Panel
Four browsing modes via tab bar:
- **Raid**: Shows current raid members not yet placed in the grid
- **Guild**: Shows guild members at your level or above
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
- Imported roster persists across sessions
- Drag roster members directly into grid slots
- Mark imported roster members who should receive assistant when you invite or lead the raid
- Built-in import popup includes the Wowutils roster export steps and a copyable URL

### Group Invites
- Invite assigned group members or imported roster characters from the button bar
- Skips known-offline characters using group, guild, and friend status data
- Automatically converts parties to raids when needed, including starter invites when you are solo
- Promotes saved assistant choices during invite flows when you are raid leader
- Prints invite summaries for invited, offline, not invited, and did-not-accept characters

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
- Pixel-perfect grid rendering via LibPixelPerfect

## Slash Commands

| Command | Description |
|---------|-------------|
| `/rgm` | Toggle the main window |
| `/rgm apply <name>` | Apply a saved layout by name |
| `/rgm presets` | Re-add preset layouts to your list |
| `/rgm debug` | Toggle debug messages |
| `/rgm help` | Show command help |

## Dependencies

All libraries are bundled in the `Libs/` folder:
- Ace3 (AceAddon, AceDB, AceConsole, AceEvent, AceSerializer)
- LibDataBroker-1.1
- LibDBIcon-1.0
- LibPixelPerfect-1.0
- LibPopupSlider-1.0
