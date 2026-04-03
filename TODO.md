## Fixes
1. Missing minimap icon
2. The backgrounds on the groups can be removed. Blank rows should be slightly more opaque and seperated by very small gap to show that there are 5 rows per group and have a faded "Empty" text within them.
3. Group titles should be smaller, centered and faded, they can be similar to the "Drag slots to swap players" text. 
4. Groups should have less empty space betwen them, maybe twice the very small gap we added betwen the group rows. 
4. I should be able to right click a name in a group to remove it
6. Update frame to high strata
7. The Group rows should have the same class colored background as the unassigned list. 
8. When dragging a name the row I'm currently hovering should be highlighted to show which slot it will be added too
9. Export Layout
  - Should not be radio buttons at the top, should just be normal buttons like the "Load Roster" etc etc. 
  - There are invalid characters: "	" in all export texts. Do not use TAB as seperator. Use spaces
10. The "Drag slots to swap players" text is weirdly between the header and the body of the frame. It should be text at the top of the main frame not in the header. 
11. Elvui changes the defeault X icons to use a nice X icon for the close icon stead of an actual "X" chracter. 

## Larger Fixes
1. Needs to handle cross realm characters with same name. All characters should use name-realm format rather than short name without realm. (Except characters on the same realm as player, those can use the short name and we assume their realm is the same as the player's for any functional purpose)
2. I do not want to be able to type in every player name row to udpate names. Names in group's should be draggable between groups by clicking anywhere on the row of the name, not just the icon. Remove the ability for me to type in each name. I'll need a text field I can type a name and hit enter or press the add "add" to add a character to the group list so I can then drag it around to where I want it. 

## Feature adds
**Do not do these until after all fixes are handled.**
1. Auto split group into Odds / Evens or Group 1+2 3+4
2. Assign each slot by "Roles" (Healer, dps, tank) and "Class" (Warlock, shaman, evoker). And have it auto sort by that role / class.
