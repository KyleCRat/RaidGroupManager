# RaidGroupManager Addon Specification

## Overview

RaidGroupManager is a World of Warcraft (Retail) addon that provides a UI for organizing raid members into specific group/slot positions, saving/loading layout presets, and applying the desired arrangement to the live raid. All organizing can be done in combat; applying changes requires out-of-combat.

**Target WoW version:** Retail (11.x / The War Within)
**Addon name:** RaidGroupManager
**Slash command:** `/rgm`

---

## Libraries

This addon uses the Ace3 library family for standard addon infrastructure. All libraries should be bundled in the `Libs/` directory.

### Required Libraries

| Library | Purpose |
|---|---|
| **LibStub** | Library version management (required by all other libs) |
| **CallbackHandler-1.0** | Event callback system (dependency of Ace libs) |
| **AceAddon-3.0** | Addon object lifecycle (`OnInitialize`, `OnEnable`), module system |
| **AceDB-3.0** | Saved variable management with per-character/profile/global scoping and defaults |
| **AceConsole-3.0** | Slash command registration via `self:RegisterChatCommand()` |
| **AceEvent-3.0** | WoW event registration via `self:RegisterEvent()` / `self:UnregisterEvent()` |
| **AceSerializer-3.0** | Table serialization/deserialization for import/export encoded strings |
| **LibDataBroker-1.1** | Data object standard for minimap button integration |
| **LibDBIcon-1.0** | Minimap button rendering (uses LibDataBroker data objects) |

### Addon Object Creation

```lua
local addon = LibStub("AceAddon-3.0"):NewAddon("RaidGroupManager",
    "AceConsole-3.0", "AceEvent-3.0", "AceSerializer-3.0")
```

This gives the addon object access to:
- `self:RegisterChatCommand(slash, handler)` — from AceConsole
- `self:RegisterEvent(event, handler)` / `self:UnregisterEvent(event)` — from AceEvent
- `self:Serialize(table)` / `self:Deserialize(string)` — from AceSerializer
- `self:OnInitialize()` — called once on ADDON_LOADED
- `self:OnEnable()` — called after all addons are loaded

Other files access the addon object via:
```lua
local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")
```

---

## Data Model

### Saved Variables (AceDB)

Use `AceDB-3.0` to manage the SavedVariables table `RaidGroupManagerDB`. AceDB handles profile management (per-character, shared defaults, etc.) automatically.

Initialize in `OnInitialize`:
```lua
function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RaidGroupManagerDB", defaults, true)
    -- "true" = use "Default" profile shared across all characters
end
```

**Defaults table:**
```lua
local defaults = {
    profile = {
        minimap = { hide = false },   -- LibDBIcon minimap button state
        layouts = {
            -- Array of layout objects, ordered by creation time (newest last)
            -- [1] = {
            --     name = "Mythic Roster",     -- string: user-given name
            --     time = 1712000000,          -- number: Unix timestamp from time()
            --     slots = {
            --         [1] = "PlayerName",     -- string or nil
            --         [2] = "AnotherPlayer",
            --         -- ...up to [40]
            --     },
            -- },
        },
    },
}
```

**Accessing data:**
- Layouts: `self.db.profile.layouts`
- Minimap state: `self.db.profile.minimap`

Note: The term "layouts" is used for saved raid arrangements to avoid confusion with AceDB's own "profile" concept. Throughout the rest of this spec, "layout" = a saved raid group arrangement, "profile" = AceDB profile (per-character settings).

The layout slots table maps slot indices 1-40 to player names:

**Slot indexing formula:**
- Slot index for Group `g`, Position `p` (both 1-based): `(g - 1) * 5 + p`
- Group from slot index `i`: `math.ceil(i / 5)`
- Position within group from slot index `i`: `((i - 1) % 5) + 1`

---

## Core Features

### 1. Raid Group Grid (Main UI)

Display an 8-group x 5-slot grid (40 total slots). Each slot is an editable text field showing a player name.

**Layout:** 4 rows of 2 groups side-by-side:
```
  Group 1          Group 2
  [slot 1]         [slot 6]
  [slot 2]         [slot 7]
  [slot 3]         [slot 8]
  [slot 4]         [slot 9]
  [slot 5]         [slot 10]

  Group 3          Group 4
  [slot 11]        [slot 16]
  ...              ...

  Group 5          Group 6
  ...              ...

  Group 7          Group 8
  ...              ...
```

Each group column should have a header label: "Group 1", "Group 2", etc.

**Slot behavior:**
- Slots are editable EditBox frames. The user can type a player name directly.
- Text color indicates status:
  - **Class color** if the name matches someone currently in the raid (use `UnitClass(name)` to get class, then `RAID_CLASS_COLORS` or `C_ClassColor.GetClassColor()` for the color).
  - **Gray (0.7, 0.7, 0.7)** if the name does not match anyone in the raid (offline/absent/unknown).
  - **Red-tinted border (0.5, 0.25, 0.3)** on non-empty slots that don't match a raid member.
- Show a **role icon** (16x16) on the right side of each slot if the player is in the raid:
  - Tank: atlas `"groupfinder-icon-role-large-tank"`
  - Healer: atlas `"groupfinder-icon-role-large-heal"`
  - DPS: atlas `"groupfinder-icon-role-large-dps"`
  - Use `UnitGroupRolesAssigned(name)` to determine role. Hide the icon if role is `"NONE"` or player not found.

### 2. Drag-and-Drop Swapping

Slots in the grid must support drag-and-drop to swap player names between slots.

**Behavior:**
- Each slot EditBox is movable and registered for left-button drag.
- On `OnDragStart`: begin moving the frame.
- On `OnDragStop`: check if the cursor is over another grid slot. If so, swap the text contents of the two slots. Then snap the dragged frame back to its original anchored position and clear focus.
- After any swap, update the active profile (if one is selected) and refresh visual state (colors, icons).

### 3. Unassigned Roster Panel

On the right side of the grid, display a list of raid members who are NOT currently assigned to any slot in the grid.

**Behavior:**
- Iterate all raid members via `GetNumGroupMembers()` / `GetRaidRosterInfo(i)`.
- Compare each name against all 40 grid slots. If a name is not found in any slot, add it to the "unassigned" list.
- Handle realm-qualified names: if `"Player-Realm"` is in the raid but `"Player"` (without realm) is in a slot, consider it matched. Strip realm suffix for same-realm players.
- Display each unassigned player as a small, non-editable text field with class coloring and role icon.
- Unassigned entries support drag-and-drop INTO the grid: dragging an unassigned name onto a grid slot fills that slot with the name.
- If more than ~40 entries, provide a scroll bar.
- Include a toggle at the top of this panel to switch between showing "Raid" members and "Guild" members.
  - **Raid mode** (default): shows unassigned current raid members.
  - **Guild mode**: shows guild members at or above the player's level who are not already in a grid slot. Display format: `"[rankIndex] Name"`. Sort by rank index, then alphabetically. Call `C_GuildInfo.GuildRoster()` when switching to guild mode to refresh data.

### 4. "Load Current Roster" Button

A button that populates the grid with the current raid roster arrangement.

**Behavior:**
- Clear all 40 slots.
- For each raid member (1 to `GetNumGroupMembers()`), call `GetRaidRosterInfo(i)` to get `name, rank, subgroup`.
- Place the name into the grid at the appropriate group. Fill positions sequentially within each group (first empty slot in that group).
- Refresh the unassigned list afterward.
- If in combat and names are inaccessible (protected API), print a warning message.

### 5. Apply Groups Button

A button labeled "Apply" (or "Set Groups") that moves raid members to match the grid layout. **Must only work out of combat.**

**Behavior on click:**

1. **Pre-flight check:** If not in a raid (`IsInRaid()` is false), do nothing.
2. **Combat check:** Iterate all 40 raid units (`"raid1"` through `"raid40"`). If any unit returns true for `UnitAffectingCombat(unit)`, print an error listing the in-combat players and abort.
3. **Build desired state:** From the 40 grid slots, build a table mapping `playerName -> desiredGroup` and `playerName -> desiredPositionInGroup`. Only include names that are actually in the raid (i.e., `UnitName(name)` returns a value).
4. **Execute group moves** using the algorithm described in the "Group Assignment Algorithm" section below.
5. Disable the Apply button while processing. Re-enable when done.

### 6. Layout Management

A scrollable list on the right side showing saved layouts (presets).

**Features:**
- **Save:** Prompt for a name via an input dialog. Save the current grid state (40 slots + timestamp) as a new layout entry appended to `self.db.profile.layouts`.
- **Load:** Click a layout in the list to populate the 40 grid slots from that layout's data. Refresh unassigned list.
- **Delete:** Each layout entry in the list has a delete button (small X or trash icon) that removes it from `self.db.profile.layouts`.
- **Reorder:** Layouts in the list can be reordered via drag-and-drop within the list.
- **Auto-save (optional toggle):** A checkbox "Auto-save changes". When enabled, any edits to the grid (typing, drag-swap) automatically update the currently-selected layout in place. When disabled, edits are transient until explicitly saved.
- Display order: newest layouts first (reverse iteration of the array).
- Tooltip on hover: show layout name and formatted date/time of last save.

### 7. Import / Export

Provide Import and Export buttons that open modal windows for transferring layouts as text strings.

**Export formats (user selects one):**
1. **Paired columns** — Groups 1&2 side by side, 3&4, 5&6, 7&8, tab-separated, newline per row.
2. **Horizontal** — 5 rows, 8 tab-separated columns (each column = a group).
3. **Vertical** — 8 groups sequentially, 5 names per group, one name per line.
4. **Encoded string** — Use `AceSerializer-3.0` to serialize the slots table into a string, then prepend a header prefix `"RGM1"`. This allows sharing complete layouts as a single copy-paste string.

**Import:** Accept any of the above formats. For the encoded string, validate the `"RGM1"` header prefix, strip it, then use `self:Deserialize(string)` to reconstruct the table. Show an error popup if invalid. For text formats, parse names by splitting on whitespace/newlines. After successful import, prompt for a layout name and save.

### 8. Minimap Button

Use `LibDataBroker-1.1` and `LibDBIcon-1.0` to provide a minimap button.

**Setup (in `OnInitialize`):**
```lua
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local dataObject = LDB:NewDataObject("RaidGroupManager", {
    type = "launcher",
    icon = "Interface\\AddOns\\RaidGroupManager\\icon",  -- or a standard atlas/texture
    OnClick = function(_, button)
        if button == "LeftButton" then
            -- Toggle main frame visibility
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Raid Group Manager")
        tooltip:AddLine("|cffffffffLeft-click|r to toggle window", 0.8, 0.8, 0.8)
    end,
})

LDBIcon:Register("RaidGroupManager", dataObject, self.db.profile.minimap)
```

The minimap button position/hidden state is persisted automatically via `self.db.profile.minimap`.

### 9. Slash Command

Use `AceConsole-3.0`'s `RegisterChatCommand` (mixed in via the addon object) to register `/rgm`.

```lua
self:RegisterChatCommand("rgm", "SlashCommand")
```

- `/rgm` — Open the main UI.
- `/rgm apply <layoutname>` — Apply a saved layout by name (look it up in `self.db.profile.layouts`, apply via the same logic as the Apply button).
- `/rgm help` — Print available commands.

---

## Group Assignment Algorithm

This is the core logic that moves raid members from their current groups/positions to the desired groups/positions. It must handle the WoW API constraints:

### WoW API Functions
- `SetRaidSubgroup(raidIndex, targetGroup)` — Move a player to a group (only works if the target group has fewer than 5 members).
- `SwapRaidSubgroup(raidIndex1, raidIndex2)` — Swap two players between their groups.
- `GetRaidRosterInfo(raidIndex)` — Returns `name, rank, subgroup, level, class, ...`
- `GetNumGroupMembers()` — Number of players in the group.

### Algorithm (Two-Phase)

**Phase 1: Get everyone into the correct group.**

This phase runs iteratively (one operation per `GROUP_ROSTER_UPDATE` event cycle) because the API is asynchronous.

1. Build current state: for each raid member, record their `currentGroup`, `currentPositionInGroup`, and `raidIndex` (the `i` in `GetRaidRosterInfo(i)`).
2. For each player who needs to change groups:
   a. If their desired group has fewer than 5 members, use `SetRaidSubgroup(raidIndex, desiredGroup)`. Update local tracking.
   b. If the desired group is full, find a player in the desired group who themselves need to move OUT. Use `SwapRaidSubgroup()` to swap them.
3. After each API call, return and wait for the next `GROUP_ROSTER_UPDATE` event to re-evaluate. The roster state updates asynchronously.
4. When all players are in their correct groups, mark Phase 1 complete and proceed to Phase 2.

**Phase 2: Arrange positions within groups (optional refinement).**

WoW's position within a group (the sub-ordering) is determined by the order players were added. To rearrange positions within a group:

1. For each player whose `currentPosition` differs from `desiredPosition`:
   a. Find the player currently occupying the desired position in the same group.
   b. Find a "bridge" player in a DIFFERENT group.
   c. Execute a 3-swap maneuver:
      - `SwapRaidSubgroup(player, bridge)` — moves player out
      - `SwapRaidSubgroup(bridge, occupant)` — moves bridge to occupant's spot
      - `SwapRaidSubgroup(player, bridge)` — moves player back into the now-correct position
   d. Mark the player as "locked" (position finalized) to avoid re-processing.
2. Never swap raidIndex 1 (the raid leader's index — this is always slot 1 and cannot be swapped).
3. After each set of swaps, wait for `GROUP_ROSTER_UPDATE`.

**Event-driven execution:**
- Register for `GROUP_ROSTER_UPDATE` while processing is active.
- On each event, debounce with a 0.5-second timer (`C_Timer.NewTimer`) to batch rapid events, then call the processing function again.
- When processing is complete (all players in correct groups and positions), unregister the event and re-enable the Apply button.

**Raid Leader handling:**
- The raid leader is always at `GetRaidRosterInfo(1)` (raidIndex 1). This index cannot be used with `SwapRaidSubgroup`.
- If the raid leader is part of the layout, their group assignment works via `SetRaidSubgroup` or by swapping other players around them.
- For position-within-group: if the RL is in a group, offset desired positions by +1 for other players in that group (since the RL occupies position 1 implicitly).

**Combat interruption:**
- Before each processing step, re-check `UnitAffectingCombat()` for all raid members.
- If anyone enters combat mid-process, print an error, abort, unregister the event, re-enable the button, and clear state.

---

## UI Structure

### Main Frame
- **Frame type:** Standard `Frame` with `BasicFrameTemplateWithInset` or a custom backdrop.
- **Size:** Approximately 700x650 pixels.
- **Movable:** Yes, with title bar drag.
- **Closable:** Standard close button (X).
- **Title:** "Raid Group Manager"

### Layout Sections (left to right)

| Section | Position | Width | Contents |
|---|---|---|---|
| Group Grid | Left | ~330px | 8 groups (4 rows x 2 cols), 5 slots each |
| Unassigned List | Center-right | ~130px | Scrollable list of unassigned players |
| Layout List | Far right | ~200px | Scrollable list of saved layouts |

### Bottom Controls (below the grid)

| Control | Type | Description |
|---|---|---|
| Load Current Roster | Button | Populates grid from live raid |
| Apply | Button (prominent) | Executes group assignments |
| Save | Button | Save current grid as a named layout |
| Export | Button | Open export window |
| Import | Button | Open import window |

### Visual Guidelines
- Use standard WoW UI frame templates and textures where possible.
- Slot EditBoxes: ~150x18 pixels each, with a subtle border.
- Group headers: white text with shadow.
- The note "Drag slots to swap players" should appear as small helper text near the grid.

---

## Event Handling

Use `AceEvent-3.0`'s `self:RegisterEvent()` / `self:UnregisterEvent()` instead of raw frame-based event registration. AceAddon handles `ADDON_LOADED` internally via `OnInitialize`.

| Event | When to Register | Purpose |
|---|---|---|
| *(handled by AceAddon)* | Automatic | `OnInitialize` called on ADDON_LOADED, `OnEnable` after |
| `GROUP_ROSTER_UPDATE` | While Apply is processing | Drive the iterative group assignment |
| `GROUP_ROSTER_UPDATE` | While UI is visible | Refresh text colors and unassigned list |
| `PLAYER_REGEN_ENABLED` | Optional | Could be used to auto-retry Apply after combat ends (not required for MVP) |

---

## File Structure

```
RaidGroupManager/
  RaidGroupManager.toc            -- TOC file
  Core.lua                        -- AceAddon creation, OnInitialize, OnEnable, slash commands
  MinimapButton.lua               -- LibDataBroker + LibDBIcon minimap button setup
  GroupAssignment.lua              -- The Apply algorithm (Phase 1 + Phase 2)
  UI/
    MainFrame.lua                 -- Main frame creation and layout
    GridSlot.lua                  -- Grid slot (EditBox) creation, drag-drop, coloring
    UnassignedPanel.lua           -- Unassigned roster panel
    LayoutPanel.lua               -- Layout list, save/load/delete
    ImportExport.lua              -- Import/export windows and parsing
  Libs/
    LibStub/
      LibStub.lua
    CallbackHandler-1.0/
      CallbackHandler-1.0.lua
      CallbackHandler-1.0.xml
    AceAddon-3.0/
      AceAddon-3.0.lua
      AceAddon-3.0.xml
    AceDB-3.0/
      AceDB-3.0.lua
      AceDB-3.0.xml
    AceConsole-3.0/
      AceConsole-3.0.lua
      AceConsole-3.0.xml
    AceEvent-3.0/
      AceEvent-3.0.lua
      AceEvent-3.0.xml
    AceSerializer-3.0/
      AceSerializer-3.0.lua
      AceSerializer-3.0.xml
    LibDataBroker-1.1/
      LibDataBroker-1.1.lua
    LibDBIcon-1.0/
      LibDBIcon-1.0.lua
      lib.xml
```

### TOC File

```toc
## Interface: 110105
## Title: Raid Group Manager
## Notes: Organize and apply raid group layouts
## Author: <your name>
## Version: 1.0.0
## SavedVariables: RaidGroupManagerDB

# Libraries (load order matters — LibStub first, then CallbackHandler, then Ace libs)
Libs/LibStub/LibStub.lua
Libs/CallbackHandler-1.0/CallbackHandler-1.0.xml
Libs/AceAddon-3.0/AceAddon-3.0.xml
Libs/AceDB-3.0/AceDB-3.0.xml
Libs/AceConsole-3.0/AceConsole-3.0.xml
Libs/AceEvent-3.0/AceEvent-3.0.xml
Libs/AceSerializer-3.0/AceSerializer-3.0.xml
Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua
Libs/LibDBIcon-1.0/lib.xml

# Addon files
Core.lua
MinimapButton.lua
GroupAssignment.lua
UI/MainFrame.lua
UI/GridSlot.lua
UI/UnassignedPanel.lua
UI/LayoutPanel.lua
UI/ImportExport.lua
```

---

## API Reference (WoW Functions Used)

| Function | Purpose |
|---|---|
| `IsInRaid()` | Check if in a raid |
| `GetNumGroupMembers()` | Number of raid members |
| `GetRaidRosterInfo(index)` | Get name, rank, subgroup, etc. |
| `SetRaidSubgroup(index, group)` | Move player to a group (group must have < 5) |
| `SwapRaidSubgroup(index1, index2)` | Swap two players between groups |
| `UnitName(unitOrName)` | Validate a player name |
| `UnitClass(unitOrName)` | Get class for coloring |
| `UnitGroupRolesAssigned(unitOrName)` | Get role (TANK/HEALER/DAMAGER/NONE) |
| `UnitAffectingCombat(unit)` | Check if a unit is in combat |
| `C_ClassColor.GetClassColor(classFile)` | Get class color (returns ColorMixin) |
| `C_GuildInfo.GuildRoster()` | Request guild roster refresh |
| `GetNumGuildMembers()` | Number of guild members |
| `GetGuildRosterInfo(index)` | Get guild member info |
| `C_Timer.NewTimer(seconds, callback)` | Debounce timer |
| `UnitLevel(unit)` | Get unit level |

---

## Edge Cases to Handle

1. **Same-realm name matching:** Raid roster may return `"Player-Realm"` while the grid has just `"Player"`. Strip the realm suffix for same-realm comparisons.
2. **Player leaves during Apply:** If a player in the desired layout leaves the raid mid-process, skip them gracefully.
3. **Full groups with no valid swap targets:** If a group is full and no one in it needs to leave, the algorithm may stall. Log a warning. (In practice this is rare because the total roster size is fixed.)
4. **Raid leader (index 1):** Cannot be used with `SwapRaidSubgroup`. The algorithm must work around this.
5. **Empty slots:** Slots with empty or whitespace-only text are ignored during Apply.
6. **Duplicate names:** If the same name appears in multiple slots, only the first occurrence should be honored.
7. **40-man vs smaller raids:** The grid always shows 40 slots. Unused slots are simply empty. The algorithm only operates on players actually in the raid.
8. **Protected API in combat:** `GetRaidRosterInfo()` name return value may be restricted in combat for cross-realm players. The "Load Current Roster" button should warn if this occurs.

---

## What This Addon Does NOT Do

- No automatic group optimization by role/class (no "auto-sort" feature in MVP).
- No sync/sharing of layouts between players via addon comms (can be added later).
- No integration with other addons.

---

## Summary of User Workflow

1. Open the UI with `/rgm`.
2. Click "Load Current Roster" to populate the grid with the live raid layout.
3. Rearrange players by dragging slots or typing names. Drag unassigned players from the side panel into slots.
4. Optionally save the arrangement as a named layout for future use.
5. When satisfied, click "Apply" (must be out of combat) to execute the group changes.
6. The addon iteratively moves players via the WoW API, handling full groups with swaps, and reports completion or errors.
