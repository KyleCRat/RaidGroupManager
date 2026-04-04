local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

--------------------------------------------------------------------------------
-- Valid class/role combinations for WoW Retail
-- Update this table when Blizzard adds or changes class/role availability.
--
-- Roles: TANK, HEALER, MELEE, RANGED
-- Class tokens match GetClassInfo() / classFile values.
--------------------------------------------------------------------------------

local CLASS_ROLES = {
    -- Death Knight
    { class = "DEATHKNIGHT", role = "TANK" },
    { class = "DEATHKNIGHT", role = "MELEE" },

    -- Demon Hunter
    { class = "DEMONHUNTER", role = "TANK" },
    { class = "DEMONHUNTER", role = "MELEE" },

    -- Druid
    { class = "DRUID", role = "TANK" },
    { class = "DRUID", role = "HEALER" },
    { class = "DRUID", role = "MELEE" },
    { class = "DRUID", role = "RANGED" },

    -- Evoker
    { class = "EVOKER", role = "HEALER" },
    { class = "EVOKER", role = "RANGED" },

    -- Hunter
    { class = "HUNTER", role = "MELEE" },
    { class = "HUNTER", role = "RANGED" },

    -- Mage
    { class = "MAGE", role = "RANGED" },

    -- Monk
    { class = "MONK", role = "TANK" },
    { class = "MONK", role = "HEALER" },
    { class = "MONK", role = "MELEE" },

    -- Paladin
    { class = "PALADIN", role = "TANK" },
    { class = "PALADIN", role = "HEALER" },
    { class = "PALADIN", role = "MELEE" },

    -- Priest
    { class = "PRIEST", role = "HEALER" },
    { class = "PRIEST", role = "RANGED" },

    -- Rogue
    { class = "ROGUE", role = "MELEE" },

    -- Shaman
    { class = "SHAMAN", role = "HEALER" },
    { class = "SHAMAN", role = "MELEE" },
    { class = "SHAMAN", role = "RANGED" },

    -- Warlock
    { class = "WARLOCK", role = "RANGED" },

    -- Warrior
    { class = "WARRIOR", role = "TANK" },
    { class = "WARRIOR", role = "MELEE" },
}

-- Localized class names by token (populated on load)
local CLASS_NAMES = {}

-- Build localized name lookup from GetClassInfo
for i = 1, GetNumClasses() do
    local name, token = GetClassInfo(i)
    if token then
        CLASS_NAMES[token] = name
    end
end

-- Role display order for grouping in the Role list
local ROLE_ORDER = { "TANK", "HEALER", "MELEE", "RANGED" }

local ROLE_DISPLAY_NAMES = {
    TANK = "Tank",
    HEALER = "Healer",
    MELEE = "Melee",
    RANGED = "Ranged",
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- Generic role-only templates (no class restriction)
local GENERIC_ROLES = {
    { class = "ANY", role = "TANK" },
    { class = "ANY", role = "HEALER" },
    { class = "ANY", role = "MELEE" },
    { class = "ANY", role = "RANGED" },
}

-- Returns the full list of role/class combos.
-- Generic role-only entries appear at the top, then class-specific grouped by role.
function addon:GetClassRoleCombos()
    local ordered = {}

    -- Generic entries first
    for _, entry in ipairs(GENERIC_ROLES) do
        table.insert(ordered, {
            class = entry.class,
            role = entry.role,
            className = ROLE_DISPLAY_NAMES[entry.role],
            roleName = ROLE_DISPLAY_NAMES[entry.role],
        })
    end

    -- Class-specific entries grouped by role
    for _, role in ipairs(ROLE_ORDER) do
        for _, entry in ipairs(CLASS_ROLES) do
            if entry.role == role then
                table.insert(ordered, {
                    class = entry.class,
                    role = entry.role,
                    className = CLASS_NAMES[entry.class] or entry.class,
                    roleName = ROLE_DISPLAY_NAMES[entry.role] or entry.role,
                })
            end
        end
    end

    return ordered
end

-- Returns the localized class name for a class token
function addon:GetClassName(classToken)
    return CLASS_NAMES[classToken] or classToken
end
