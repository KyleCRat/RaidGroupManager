local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

--------------------------------------------------------------------------------
-- Preset Layouts
--
-- These layouts ship with the addon and are installed into the user's saved
-- layouts on first use. Each preset follows the same format as user-saved
-- layouts: a table of 40 slot strings, one per grid position.
--
-- Slot indexing:
--   Group 1 = slots 1-5, Group 2 = slots 6-10, ... Group 8 = slots 36-40
--
-- Values:
--   ""                    = empty slot
--   "PlayerName"          = a specific player
--   "~ROLE-CLASS"         = class+role template  (e.g. "~TANK-WARRIOR")
--   "~ROLE-ANY"           = generic role template (e.g. "~TANK-ANY")
--
-- To add a new preset, append an entry to the PRESETS table below.
--------------------------------------------------------------------------------

local PRESETS = {
    {
        name = "Mythic G1+2, 3+4",
        slots = {
            -- Group 1
            "~TANK-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY",
            -- Group 2
            "~RANGED-ANY", "~RANGED-ANY", "~RANGED-ANY", "~HEALER-ANY", "~HEALER-ANY",
            -- Group 3
            "~TANK-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY",
            -- Group 4
            "~RANGED-ANY", "~RANGED-ANY", "~RANGED-ANY", "~HEALER-ANY", "~HEALER-ANY",
            -- Groups 5-8 empty
            "", "", "", "", "",
            "", "", "", "", "",
            "", "", "", "", "",
            "", "", "", "", "",
        },
    },
    {
        name = "Mythic Even/Odd",
        slots = {
            -- Group 1
            "~TANK-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY",
            -- Group 2
            "~TANK-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY",
            -- Group 3
            "~HEALER-ANY", "~HEALER-ANY", "~RANGED-ANY", "~RANGED-ANY", "~RANGED-ANY",
            -- Group 4
            "~HEALER-ANY", "~HEALER-ANY", "~RANGED-ANY", "~RANGED-ANY", "~RANGED-ANY",
            -- Groups 5-8 empty
            "", "", "", "", "",
            "", "", "", "", "",
            "", "", "", "", "",
            "", "", "", "", "",
        },
    },
    {
        name = "Heroic - 2/4/24",
        slots = {
            -- Group 1
            "~TANK-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY",
            -- Group 2
            "~TANK-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY", "~MELEE-ANY",
            -- Group 3
            "~MELEE-ANY", "~MELEE-ANY", "~RANGED-ANY", "~RANGED-ANY", "~RANGED-ANY",
            -- Group 4
            "~MELEE-ANY", "~MELEE-ANY", "~RANGED-ANY", "~RANGED-ANY", "~RANGED-ANY",
            -- Group 5
            "~RANGED-ANY", "~RANGED-ANY", "~RANGED-ANY", "~HEALER-ANY", "~HEALER-ANY",
            -- Group 6
            "~RANGED-ANY", "~RANGED-ANY", "~RANGED-ANY", "~HEALER-ANY", "~HEALER-ANY",
            -- Groups 7-8 empty
            "", "", "", "", "",
            "", "", "", "", "",
        },
    },
}

--------------------------------------------------------------------------------
-- Installation — runs once per profile
--------------------------------------------------------------------------------

function addon:InstallPresetLayouts(force)
    local db = self.db.profile

    if not force and db.presetsInstalled then
        return
    end

    -- Build lookup of existing layout names to skip duplicates
    local existing = {}
    for _, layout in ipairs(db.layouts) do
        existing[layout.name] = true
    end

    local added = 0
    for _, preset in ipairs(PRESETS) do
        if not existing[preset.name] then
            local layout = {
                name = preset.name,
                time = time(),
                slots = {},
            }

            for i = 1, 40 do
                layout.slots[i] = preset.slots[i] or ""
            end

            table.insert(db.layouts, 1, layout)
            added = added + 1
        end
    end

    db.presetsInstalled = true

    if force then
        if added > 0 then
            self:Print("Added " .. added .. " preset layout(s).")
        else
            self:Print("All presets already exist.")
        end
    end
end
