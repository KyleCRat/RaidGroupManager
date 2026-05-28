local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local ClassSpecRoles = {}
addon.ClassSpecRoles = ClassSpecRoles

--------------------------------------------------------------------------------
-- Class and role metadata
--------------------------------------------------------------------------------

local CLASS_TOKEN_FROM_NAME = {
    ["Death Knight"] = "DEATHKNIGHT",
    ["Demon Hunter"] = "DEMONHUNTER",
    ["Druid"]        = "DRUID",
    ["Evoker"]       = "EVOKER",
    ["Hunter"]       = "HUNTER",
    ["Mage"]         = "MAGE",
    ["Monk"]         = "MONK",
    ["Paladin"]      = "PALADIN",
    ["Priest"]       = "PRIEST",
    ["Rogue"]        = "ROGUE",
    ["Shaman"]       = "SHAMAN",
    ["Warlock"]      = "WARLOCK",
    ["Warrior"]      = "WARRIOR",
}

local CLASS_NAMES = {}
local CLASS_ID_BY_TOKEN = {}

for i = 1, GetNumClasses() do
    local name, token, classID = GetClassInfo(i)
    if token then
        CLASS_NAMES[token] = name
        CLASS_ID_BY_TOKEN[token] = classID or i
    end
end

local ROLE_DISPLAY_NAMES = {
    TANK   = "Tank",
    HEALER = "Healer",
    MELEE  = "Melee",
    RANGED = "Ranged",
}

local ROLE_FROM_IMPORT = {
    tank   = "TANK",
    healer = "HEALER",
    melee  = "MELEE",
    ranged = "RANGED",
}

local ROSTER_ROLE_SORT_ORDER = {
    TANK   = 1,
    HEALER = 2,
    MELEE  = 3,
    RANGED = 4,
}

--------------------------------------------------------------------------------
-- Template class/role combinations
--------------------------------------------------------------------------------

local CLASS_ROLES = {
    { class = "DEATHKNIGHT", role = "TANK" },
    { class = "DEATHKNIGHT", role = "MELEE" },

    { class = "DEMONHUNTER", role = "TANK" },
    { class = "DEMONHUNTER", role = "MELEE" },
    { class = "DEMONHUNTER", role = "RANGED" },

    { class = "DRUID", role = "TANK" },
    { class = "DRUID", role = "HEALER" },
    { class = "DRUID", role = "MELEE" },
    { class = "DRUID", role = "RANGED" },

    { class = "EVOKER", role = "HEALER" },
    { class = "EVOKER", role = "RANGED" },

    { class = "HUNTER", role = "MELEE" },
    { class = "HUNTER", role = "RANGED" },

    { class = "MAGE", role = "RANGED" },

    { class = "MONK", role = "TANK" },
    { class = "MONK", role = "HEALER" },
    { class = "MONK", role = "MELEE" },

    { class = "PALADIN", role = "TANK" },
    { class = "PALADIN", role = "HEALER" },
    { class = "PALADIN", role = "MELEE" },

    { class = "PRIEST", role = "HEALER" },
    { class = "PRIEST", role = "RANGED" },

    { class = "ROGUE", role = "MELEE" },

    { class = "SHAMAN", role = "HEALER" },
    { class = "SHAMAN", role = "MELEE" },
    { class = "SHAMAN", role = "RANGED" },

    { class = "WARLOCK", role = "RANGED" },

    { class = "WARRIOR", role = "TANK" },
    { class = "WARRIOR", role = "MELEE" },
}

local GENERIC_ROLES = {
    { class = "ANY", role = "TANK" },
    { class = "ANY", role = "HEALER" },
    { class = "ANY", role = "MELEE" },
    { class = "ANY", role = "RANGED" },
}

local TEMPLATE_ROLE_ORDER = { "TANK", "HEALER", "MELEE", "RANGED" }

--------------------------------------------------------------------------------
-- Spec role classification
--------------------------------------------------------------------------------

local MELEE_DPS_SPECS = {
    [70]  = true,                             -- Retribution Paladin
    [71]  = true, [72]  = true,               -- Arms, Fury Warrior
    [103] = true,                             -- Feral Druid
    [251] = true, [252] = true,               -- Frost, Unholy Death Knight
    [255] = true,                             -- Survival Hunter
    [259] = true, [260] = true, [261] = true, -- Assassination, Outlaw, Subtlety Rogue
    [263] = true,                             -- Enhancement Shaman
    [269] = true,                             -- Windwalker Monk
    [577] = true,                             -- Havoc Demon Hunter
}

local TANK_SPECS = {
    [66]  = true, -- Protection Paladin
    [73]  = true, -- Protection Warrior
    [104] = true, -- Guardian Druid
    [250] = true, -- Blood Death Knight
    [268] = true, -- Brewmaster Monk
    [581] = true, -- Vengeance Demon Hunter
}

local HEALER_SPECS = {
    [65]   = true,               -- Holy Paladin
    [105]  = true,               -- Restoration Druid
    [256]  = true, [257] = true, -- Discipline, Holy Priest
    [264]  = true,               -- Restoration Shaman
    [270]  = true,               -- Mistweaver Monk
    [1468] = true,               -- Preservation Evoker
}

local RANGED_DPS_SPECS = {
    [62]   = true, [63]  = true, [64]  = true, -- Arcane, Fire, Frost Mage
    [102]  = true,                             -- Balance Druid
    [253]  = true, [254] = true,               -- Beast Mastery, Marksmanship Hunter
    [258]  = true,                             -- Shadow Priest
    [262]  = true,                             -- Elemental Shaman
    [265]  = true, [266] = true, [267] = true, -- Affliction, Demonology, Destruction Warlock
    [1467] = true, [1473] = true,             -- Devastation, Augmentation Evoker
    [1480] = true,                            -- Devourer Demon Hunter
}

local DEFAULT_MELEE_CLASSES = {
    WARRIOR     = true,
    ROGUE       = true,
    DEATHKNIGHT = true,
    MONK        = true,
    PALADIN     = true,
}

local SPEC_ID_BY_CLASS_SPEC = {}

function ClassSpecRoles:GetClassTokenFromName(className)
    return CLASS_TOKEN_FROM_NAME[className]
end

function ClassSpecRoles:GetClassName(classToken)
    return CLASS_NAMES[classToken] or classToken
end

function ClassSpecRoles:GetRoleDisplayName(role)
    return ROLE_DISPLAY_NAMES[role] or role
end

function ClassSpecRoles:GetImportRole(role)
    return ROLE_FROM_IMPORT[role] or "RANGED"
end

function ClassSpecRoles:IsDefaultMeleeClass(classToken)
    return DEFAULT_MELEE_CLASSES[classToken]
end

function ClassSpecRoles:GetImportedSpecID(classToken, specName)
    if not classToken or not specName then
        return nil
    end

    if not SPEC_ID_BY_CLASS_SPEC[classToken] then
        local specIDs = {}
        SPEC_ID_BY_CLASS_SPEC[classToken] = specIDs

        local classID = CLASS_ID_BY_TOKEN[classToken]
        if classID and C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
            local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
            for specIndex = 1, numSpecs do
                local specID, name = GetSpecializationInfoForClassID(classID, specIndex)
                if specID and name then
                    specIDs[name] = specID
                end
            end
        end
    end

    return SPEC_ID_BY_CLASS_SPEC[classToken][specName]
end

function ClassSpecRoles:GetCombatRoleForSpecID(specID, classToken)
    if not specID or specID <= 0 then
        return nil
    end

    if TANK_SPECS[specID] then
        return "TANK"
    end

    if HEALER_SPECS[specID] then
        return "HEALER"
    end

    if MELEE_DPS_SPECS[specID] then
        return "MELEE"
    end

    if RANGED_DPS_SPECS[specID] then
        return "RANGED"
    end

    if classToken and DEFAULT_MELEE_CLASSES[classToken] then
        return "MELEE"
    end

    return "RANGED"
end

function ClassSpecRoles:GetImportedCharacterRole(member, classToken, char)
    if char.playerSpec then
        local specID = self:GetImportedSpecID(classToken, char.playerSpec)
        local role = self:GetCombatRoleForSpecID(specID, classToken)
        if role then
            return role
        end
    end

    return self:GetImportRole(member.mainRole)
end

function ClassSpecRoles.CompareRosterEntriesByRoleThenName(a, b)
    local roleA = ROSTER_ROLE_SORT_ORDER[a.role] or 99
    local roleB = ROSTER_ROLE_SORT_ORDER[b.role] or 99

    if roleA ~= roleB then
        return roleA < roleB
    end

    return a.normalizedName < b.normalizedName
end

function ClassSpecRoles:GetClassRoleCombos()
    local ordered = {}

    for _, entry in ipairs(GENERIC_ROLES) do
        table.insert(ordered, {
            class = entry.class,
            role = entry.role,
            className = ROLE_DISPLAY_NAMES[entry.role],
            roleName = ROLE_DISPLAY_NAMES[entry.role],
        })
    end

    for _, role in ipairs(TEMPLATE_ROLE_ORDER) do
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
