local addon = LibStub("AceAddon-3.0"):NewAddon("RaidGroupManager",
    "AceConsole-3.0", "AceEvent-3.0", "AceSerializer-3.0")

addon.FONT = "Interface\\AddOns\\RaidGroupManager\\Media\\Fonts\\PTSansNarrow-Bold.ttf"

addon.SLOT_WIDTH = 150
addon.SLOT_HEIGHT = 20
addon.SLOT_GAP = 2
addon.GROUP_GAP = 6
addon.GROUP_HEADER_HEIGHT = 16
addon.TITLE_HEIGHT = 28

local playerRealm = nil

local defaults = {
    profile = {
        minimap = { hide = false },
        layouts = {},
    },
}

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RaidGroupManagerDB", defaults, true)
    self.slots = {}
    self.selectedLayout = nil
    self.autoSave = false

    self:InstallPresetLayouts()
    self:RegisterChatCommand("rgm", "SlashCommand")
    self:SetupMinimapButton()
end

function addon:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")
end

function addon:OnRosterUpdate()
    if not self.mainFrame or not self.mainFrame:IsShown() then
        return
    end

    self:RefreshAllSlots()
    self:RefreshUnassigned()
end

function addon:SlashCommand(input)
    local cmd = self:GetArgs(input, 1)

    if not cmd or cmd == "" then
        self:ToggleMainFrame()

        return
    end

    if cmd == "apply" then
        local _, layoutName = self:GetArgs(input, 2, nil, cmd)
        if not layoutName or layoutName == "" then
            self:Print("Usage: /rgm apply <layout name>")

            return
        end

        local layout = self:FindLayoutByName(layoutName)
        if not layout then
            self:Print("Layout not found: " .. layoutName)

            return
        end

        self:LoadLayoutToGrid(layout)
        self:StartApply()

        return
    end

    if cmd == "presets" then
        self:InstallPresetLayouts(true)
        self:RefreshLayoutList()

        return
    end

    if cmd == "help" then
        self:Print("Commands:")
        self:Print("  /rgm - Toggle the main window")
        self:Print("  /rgm apply <name> - Apply a saved layout")
        self:Print("  /rgm presets - Add preset layouts to your list")
        self:Print("  /rgm help - Show this help")

        return
    end

    self:Print("Unknown command. Type /rgm help for usage.")
end

function addon:FindLayoutByName(name)
    local nameLower = name:lower()
    for _, layout in ipairs(self.db.profile.layouts) do
        if layout.name:lower() == nameLower then
            return layout
        end
    end

    return nil
end

function addon:ToggleMainFrame()
    if not self.mainFrame then
        self:CreateMainFrame()
    end

    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:RefreshAllSlots()
        self:RefreshUnassigned()
    end
end

--------------------------------------------------------------------------------
-- Name handling
--------------------------------------------------------------------------------

function addon:GetPlayerRealm()
    if not playerRealm then
        playerRealm = GetNormalizedRealmName()
    end

    return playerRealm
end

-- Normalize a name: strip realm suffix if it matches the player's realm.
-- Cross-realm names keep their realm suffix.
function addon:NormalizeName(name)
    if not name then
        return nil
    end

    local dashPos = name:find("-")
    if not dashPos then
        return name
    end

    local realm = name:sub(dashPos + 1)
    if realm == self:GetPlayerRealm() then
        return name:sub(1, dashPos - 1)
    end

    return name
end

--------------------------------------------------------------------------------
-- Raid roster
--------------------------------------------------------------------------------

-- Build a lookup table of current raid members: normalizedName -> info
function addon:GetRaidRoster()
    local roster = {}
    local count = GetNumGroupMembers()

    if not IsInRaid() or count == 0 then
        return roster
    end

    for i = 1, count do
        local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
        if name then
            local normalized = self:NormalizeName(name)
            local role = UnitGroupRolesAssigned(name)
            roster[normalized] = {
                name = name,
                normalizedName = normalized,
                class = class,
                role = role,
                subgroup = subgroup,
                raidIndex = i,
            }
        end
    end

    return roster
end

--------------------------------------------------------------------------------
-- Template encoding
-- Templates are stored as strings with a ~ prefix: "~ROLE-CLASS"
-- e.g. "~TANK-WARRIOR", "~RANGED-SHAMAN"
--------------------------------------------------------------------------------

local TEMPLATE_PREFIX = "~"

function addon:EncodeTemplate(class, role)
    return TEMPLATE_PREFIX .. role .. "-" .. class
end

function addon:DecodeTemplate(text)
    if not text or text:sub(1, 1) ~= TEMPLATE_PREFIX then

        return nil
    end

    local role, class = text:sub(2):match("^(%u+)-(%u+)$")
    if role and class then

        return { role = role, class = class }
    end

    return nil
end

--------------------------------------------------------------------------------
-- Grid slot data access
--------------------------------------------------------------------------------

function addon:GetSlotText(slotIndex)
    local slot = self.slots[slotIndex]
    if not slot then
        return ""
    end

    return slot.playerName or ""
end

function addon:SetSlotText(slotIndex, text)
    local slot = self.slots[slotIndex]
    if not slot then
        return
    end

    slot.playerName = text or ""
end

function addon:IsSlotTemplate(slotIndex)
    local text = self:GetSlotText(slotIndex)

    return text:sub(1, 1) == TEMPLATE_PREFIX
end

function addon:GetSlotTemplate(slotIndex)
    return self:DecodeTemplate(self:GetSlotText(slotIndex))
end

function addon:SetSlotTemplate(slotIndex, class, role)
    self:SetSlotText(slotIndex, self:EncodeTemplate(class, role))
end

function addon:IsSlotEmpty(slotIndex)
    return self:GetSlotText(slotIndex) == ""
end

function addon:IsSlotPlayer(slotIndex)
    local text = self:GetSlotText(slotIndex)

    return text ~= "" and text:sub(1, 1) ~= TEMPLATE_PREFIX
end

-- Get all 40 slot texts as a table (templates encoded as strings)
function addon:GetGridState()
    local state = {}
    for i = 1, 40 do
        state[i] = self:GetSlotText(i)
    end

    return state
end

-- Load a layout's slot data into the grid
function addon:LoadLayoutToGrid(layout)
    for i = 1, 40 do
        local text = layout.slots and layout.slots[i] or ""
        self:SetSlotText(i, text)
    end

    self:RefreshAllSlots()
    self:RefreshUnassigned()
end

-- Save current grid state to the selected layout
function addon:SaveToSelectedLayout()
    if not self.selectedLayout then
        return
    end

    self.selectedLayout.slots = self:GetGridState()
    self.selectedLayout.time = time()
end

-- Auto-save if enabled and a layout is selected
function addon:TryAutoSave()
    if self.autoSave and self.selectedLayout then
        self:SaveToSelectedLayout()
    end
end

-- Add a name to the first empty grid slot (skips template slots)
function addon:AddNameToGrid(name)
    if not name or name == "" then
        return
    end

    for i = 1, 40 do
        if self:IsSlotEmpty(i) then
            self:SetSlotText(i, name)
            self:RefreshSlot(i)
            self:RefreshUnassigned()
            self:TryAutoSave()

            return
        end
    end

    self:Print("No empty slots available.")
end

--------------------------------------------------------------------------------
-- Group splitting
--------------------------------------------------------------------------------

local MYTHIC_DIFFICULTY_ID = 16

local function IsMythicDifficulty()
    local _, _, difficultyID = GetInstanceInfo()

    return difficultyID == MYTHIC_DIFFICULTY_ID
end

-- Collect all non-empty slot contents (players and templates) from groups
local function CollectSlotContents(groups)
    local items = {}
    for _, g in ipairs(groups) do
        for p = 1, 5 do
            local slotIndex = (g - 1) * 5 + p
            local text = addon:GetSlotText(slotIndex)
            if text ~= "" then
                table.insert(items, text)
            end
        end
    end

    return items
end

-- Clear all slots in groups
local function ClearGroups(groups)
    for _, g in ipairs(groups) do
        for p = 1, 5 do
            local slotIndex = (g - 1) * 5 + p
            addon:SetSlotText(slotIndex, "")
        end
    end
end

-- Place items (player names or encoded templates) into groups
local function PlaceItemsInGroups(items, groups)
    local idx = 1
    for _, g in ipairs(groups) do
        for p = 1, 5 do
            if idx > #items then

                return
            end

            local slotIndex = (g - 1) * 5 + p
            addon:SetSlotText(slotIndex, items[idx])
            idx = idx + 1
        end
    end
end

local function GroupsNeeded(count)
    return math.ceil(count / 5)
end

--------------------------------------------------------------------------------
-- Role detection for balanced splits
--------------------------------------------------------------------------------

-- Melee DPS specialization IDs
local MELEE_DPS_SPECS = {
    [71]  = true, [72]  = true,                   -- Arms, Fury Warrior
    [259] = true, [260] = true, [261] = true,     -- Assassination, Outlaw, Subtlety Rogue
    [251] = true, [252] = true,                   -- Frost, Unholy Death Knight
    [577] = true,                                 -- Havoc Demon Hunter
    [269] = true,                                 -- Windwalker Monk
    [70]  = true,                                 -- Retribution Paladin
    [103] = true,                                 -- Feral Druid
    [263] = true,                                 -- Enhancement Shaman
    [255] = true,                                 -- Survival Hunter
}

-- Fallback: classes where DPS is melee when spec ID is unavailable
local DEFAULT_MELEE_CLASSES = {
    WARRIOR = true,
    ROGUE = true,
    DEATHKNIGHT = true,
    DEMONHUNTER = true,
    MONK = true,
    PALADIN = true,
}

-- Returns "TANK", "HEALER", "MELEE", or "RANGED"
function addon:GetCombatRole(member)
    if member.role == "TANK" then

        return "TANK"
    end

    if member.role == "HEALER" then

        return "HEALER"
    end

    -- DPS — check spec ID for melee vs ranged
    local specID = GetInspectSpecialization("raid" .. member.raidIndex)
    if specID and specID > 0 then
        if MELEE_DPS_SPECS[specID] then

            return "MELEE"
        end

        return "RANGED"
    end

    -- Spec unavailable — fall back to class
    if DEFAULT_MELEE_CLASSES[member.class] then

        return "MELEE"
    end

    return "RANGED"
end

local ROLE_ORDER = { "TANK", "MELEE", "RANGED", "HEALER" }

-- Split a list of slot contents (player names or encoded templates) into
-- two role-balanced sides. Each role bucket is alternated evenly.
local function ClassifyItem(item, roster)
    local template = addon:DecodeTemplate(item)
    if template then
        return template.role
    end

    local member = roster[item]
    if member then
        return addon:GetCombatRole(member)
    end

    return "RANGED"
end

local function GetItemClass(item, roster)
    local template = addon:DecodeTemplate(item)
    if template then
        return template.class
    end

    local member = roster[item]
    if member then
        return member.class
    end

    return "UNKNOWN"
end

local function SplitByRole(items, roster)
    local buckets = { TANK = {}, HEALER = {}, MELEE = {}, RANGED = {} }

    for _, item in ipairs(items) do
        table.insert(buckets[ClassifyItem(item, roster)], item)
    end

    -- Sort each bucket alphabetically for deterministic splits
    for _, role in ipairs(ROLE_ORDER) do
        table.sort(buckets[role])
    end

    -- Pair matching classes within each role so they land at the same
    -- positional index on each side.  Unpaired remainders for each role
    -- are inserted immediately after that role's pairs to preserve
    -- TANK → MELEE → RANGED → HEALER ordering.
    local sideA, sideB = {}, {}

    for _, role in ipairs(ROLE_ORDER) do
        local bucket = buckets[role]

        -- Sub-group by class
        local classGroups = {}
        local classOrder = {}

        for _, item in ipairs(bucket) do
            local itemClass = GetItemClass(item, roster)

            if not classGroups[itemClass] then
                classGroups[itemClass] = {}
                table.insert(classOrder, itemClass)
            end

            table.insert(classGroups[itemClass], item)
        end

        table.sort(classOrder)

        -- Pass 1: emit all matched pairs
        for _, cls in ipairs(classOrder) do
            local group = classGroups[cls]

            for i = 1, #group - 1, 2 do
                table.insert(sideA, group[i])
                table.insert(sideB, group[i + 1])
            end
        end

        -- Pass 2: distribute this role's unpaired remainders
        for _, cls in ipairs(classOrder) do
            local group = classGroups[cls]

            if #group % 2 == 1 then
                if #sideA <= #sideB then
                    table.insert(sideA, group[#group])
                else
                    table.insert(sideB, group[#group])
                end
            end
        end
    end

    return sideA, sideB
end

--------------------------------------------------------------------------------
-- Split functions
--------------------------------------------------------------------------------

function addon:SplitOddEven()
    local oddGroups, evenGroups, allGroups

    if IsMythicDifficulty() then
        oddGroups = { 1, 3 }
        evenGroups = { 2, 4 }
        allGroups = { 1, 2, 3, 4 }
    else
        oddGroups = { 1, 3, 5, 7 }
        evenGroups = { 2, 4, 6, 8 }
        allGroups = { 1, 2, 3, 4, 5, 6, 7, 8 }
    end

    local items = CollectSlotContents(allGroups)
    local roster = self:GetRaidRoster()
    ClearGroups(allGroups)

    local oddItems, evenItems = SplitByRole(items, roster)

    PlaceItemsInGroups(oddItems, oddGroups)
    PlaceItemsInGroups(evenItems, evenGroups)

    self:RefreshAllSlots()
    self:RefreshUnassigned()
    self:TryAutoSave()
end

function addon:SplitHalves()
    local allGroups

    if IsMythicDifficulty() then
        allGroups = { 1, 2, 3, 4 }
    else
        allGroups = { 1, 2, 3, 4, 5, 6 }
    end

    local items = CollectSlotContents(allGroups)
    local roster = self:GetRaidRoster()
    ClearGroups(allGroups)

    local firstItems, secondItems = SplitByRole(items, roster)

    -- Pack each half into only as many groups as needed
    local firstCount = GroupsNeeded(#firstItems)
    local secondCount = GroupsNeeded(#secondItems)

    local firstGroups = {}
    for i = 1, firstCount do
        firstGroups[i] = allGroups[i]
    end

    local secondGroups = {}
    for i = 1, secondCount do
        secondGroups[i] = allGroups[firstCount + i]
    end

    PlaceItemsInGroups(firstItems, firstGroups)
    PlaceItemsInGroups(secondItems, secondGroups)

    self:RefreshAllSlots()
    self:RefreshUnassigned()
    self:TryAutoSave()
end
