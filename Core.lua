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
        framePosition = nil,
        gridState = nil,
        importedRoster = {},
        specCache = {},
        debugMode = false,
    },
}

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RaidGroupManagerDB", defaults, true)
    self.slots = {}
    self.selectedLayout = nil
    self.autoSave = false
    self.debugMode = self.db.profile.debugMode
    self.specCache = self.db.profile.specCache
    self.wasInRaid = IsInRaid()
    self.inspectQueue = {}
    self.inspectQueueSet = {}
    self.inspectBusy = false
    self.inspectSafetyTimer = nil

    self:InstallPresetLayouts()
    self:RegisterChatCommand("rgm", "SlashCommand")
    self:SetupMinimapButton()
end

function addon:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("INSPECT_READY", "OnInspectReady")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
end

function addon:WipeSpecCache()
    wipe(self.specCache)
    wipe(self.inspectQueue)
    wipe(self.inspectQueueSet)
    self.inspectBusy = false

    if self.inspectSafetyTimer then
        self.inspectSafetyTimer:Cancel()
        self.inspectSafetyTimer = nil
    end

    self:Debug("Spec cache wiped")
end

function addon:OnRosterUpdate()
    local inRaid = IsInRaid()

    -- Detect raid join/leave transitions
    if inRaid and not self.wasInRaid then
        self:WipeSpecCache()
        self:Debug("Joined raid, cache reset")
    end

    if not inRaid and self.wasInRaid then
        self:WipeSpecCache()
        self:Debug("Left raid, cache reset")
    end

    self.wasInRaid = inRaid

    -- Maintain the inspect cache regardless of frame visibility
    if inRaid then
        self:QueueAllInspects()
    end

    if not self.mainFrame or not self.mainFrame:IsShown() then

        return
    end

    self:RefreshAllSlots()
    self:RefreshUnassigned()
end

function addon:OnEncounterStart()
    if not self.mainFrame or not self.mainFrame:IsShown() then
        return
    end

    self.hiddenByEncounter = true
    self.mainFrame:Hide()
end

function addon:OnEncounterEnd()
    if not self.hiddenByEncounter then
        return
    end

    if not UnitIsDeadOrGhost("player") then
        self:ReopenAfterEncounter()

        return
    end

    self:RegisterEvent("PLAYER_UNGHOST", "OnPlayerAlive")
    self:RegisterEvent("PLAYER_ALIVE", "OnPlayerAlive")
end

function addon:OnPlayerAlive()
    self:UnregisterEvent("PLAYER_UNGHOST")
    self:UnregisterEvent("PLAYER_ALIVE")
    self:ReopenAfterEncounter()
end

function addon:ReopenAfterEncounter()
    self.hiddenByEncounter = false
    self.mainFrame:Show()
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

    if cmd == "debug" then
        self.debugMode = not self.debugMode
        self.db.profile.debugMode = self.debugMode
        self:Print("Debug mode " .. (self.debugMode and "enabled" or "disabled"))

        return
    end

    if cmd == "help" then
        self:Print("Commands:")
        self:Print("  /rgm - Toggle the main window")
        self:Print("  /rgm apply <name> - Apply a saved layout")
        self:Print("  /rgm presets - Add preset layouts to your list")
        self:Print("  /rgm debug - Toggle debug messages")
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
        self:RestoreGridState()
    end

    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:RefreshAllSlots()
        self:RefreshUnassigned()
    end
end

function addon:Debug(...)
    if self.debugMode then
        self:Print("[DEBUG]", ...)
    end
end

--------------------------------------------------------------------------------
-- Inspect cache — queue NotifyInspect calls and cache spec IDs
--------------------------------------------------------------------------------

local INSPECT_INTERVAL = 1.5
local INSPECT_SAFETY_TIMEOUT = 3.0

function addon:QueueInspect(name)
    if self.specCache[name] then

        return
    end

    if self.inspectQueueSet[name] then

        return
    end

    table.insert(self.inspectQueue, name)
    self.inspectQueueSet[name] = true

    if not self.inspectBusy and #self.inspectQueue == 1 then
        self:ProcessNextInspect()
    end
end

function addon:FindRaidUnit(name)
    local count = GetNumGroupMembers()
    for i = 1, count do
        local rosterName = GetRaidRosterInfo(i)
        if rosterName and self:NormalizeName(rosterName) == name then

            return "raid" .. i
        end
    end

    return nil
end

function addon:ProcessNextInspect()
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")

        return
    end

    -- Skip stale entries until we find a valid target
    while #self.inspectQueue > 0 do
        local name = self.inspectQueue[1]
        table.remove(self.inspectQueue, 1)
        self.inspectQueueSet[name] = nil

        if self.specCache[name] then
            -- Already cached (e.g. from a tooltip inspect), skip
        else
            local unit = self:FindRaidUnit(name)
            if unit and UnitIsConnected(unit) then
                self.inspectBusy = true
                self:Debug("Inspecting " .. name .. " (" .. unit .. ")")
                NotifyInspect(unit)

                -- Safety timer in case INSPECT_READY never fires
                if self.inspectSafetyTimer then
                    self.inspectSafetyTimer:Cancel()
                end

                self.inspectSafetyTimer = C_Timer.NewTimer(INSPECT_SAFETY_TIMEOUT, function()
                    self.inspectSafetyTimer = nil
                    if self.inspectBusy then
                        self:Debug("Inspect safety timeout for " .. name)
                        self.inspectBusy = false
                        self:ProcessNextInspect()
                    end
                end)

                return
            end
        end
    end

    self.inspectBusy = false
end

function addon:OnInspectReady(_, inspecteeGUID)
    if not self.inspectBusy then

        return
    end

    if self.inspectSafetyTimer then
        self.inspectSafetyTimer:Cancel()
        self.inspectSafetyTimer = nil
    end

    self.inspectBusy = false

    -- Find which raid member matches this GUID
    local count = GetNumGroupMembers()
    for i = 1, count do
        local unit = "raid" .. i
        if UnitGUID(unit) == inspecteeGUID then
            local specID = GetInspectSpecialization(unit)
            if specID and specID > 0 then
                local rosterName = GetRaidRosterInfo(i)
                if rosterName then
                    local name = self:NormalizeName(rosterName)
                    self.specCache[name] = specID
                    self:Debug(name .. " spec cached: " .. specID)
                end
            end

            break
        end
    end

    ClearInspectPlayer()

    C_Timer.After(INSPECT_INTERVAL, function()
        self:ProcessNextInspect()
    end)
end

function addon:OnCombatEnd()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:ProcessNextInspect()
end

function addon:OnSpecChanged(_, unit)
    if not unit or not IsInRaid() then
        return
    end

    if UnitIsUnit(unit, "player") then
        return
    end

    local fullName, _ = UnitName(unit)
    if not fullName then
        return
    end

    local name = self:NormalizeName(fullName)
    self.specCache[name] = nil
    self:QueueInspect(name)
    self:Debug(name .. " changed spec, re-queued for inspect")
end

function addon:QueueAllInspects()
    local roster = self:GetRaidRoster()
    self:PruneSpecCache(roster)
    for name, member in pairs(roster) do
        if not UnitIsUnit("raid" .. member.raidIndex, "player") then
            self:QueueInspect(name)
        end
    end
end

function addon:OnZoneChanged()
    if not IsInRaid() then
        return
    end

    self:WipeSpecCache()
    self:Debug("Zone changed, cache reset")
    self:QueueAllInspects()
end

function addon:PruneSpecCache(roster)
    for name in pairs(self.specCache) do
        if not roster[name] then
            self.specCache[name] = nil
        end
    end

    for i = #self.inspectQueue, 1, -1 do
        local name = self.inspectQueue[i]
        if not roster[name] then
            table.remove(self.inspectQueue, i)
            self.inspectQueueSet[name] = nil
        end
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
    self:PersistGridState()
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

    self:PersistGridState()
end

-- Persist the current grid to saved variables so it survives reloads
function addon:PersistGridState()
    self.db.profile.gridState = self:GetGridState()
end

-- Restore grid contents from saved variables
function addon:RestoreGridState()
    local state = self.db.profile.gridState
    if not state then
        return
    end

    for i = 1, 40 do
        self:SetSlotText(i, state[i] or "")
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

-- Fallback: classes where ALL DPS specs are melee
local DEFAULT_MELEE_CLASSES = {
    WARRIOR = true,
    ROGUE = true,
    DEATHKNIGHT = true,
    MONK = true,
    PALADIN = true,
}

-- Get a unit's specialization ID. GetInspectSpecialization requires an
-- active inspect session, so it returns 0 for most raid members. For the
-- player character we can use GetSpecialization directly.
local function GetUnitSpecID(unit)
    if UnitIsUnit(unit, "player") then
        local specIndex = GetSpecialization()
        if specIndex then
            return GetSpecializationInfo(specIndex)
        end

        return 0
    end

    return GetInspectSpecialization(unit) or 0
end

-- Returns "TANK", "HEALER", "MELEE", or "RANGED"
function addon:GetCombatRole(member)
    if member.role == "TANK" then

        return "TANK"
    end

    if member.role == "HEALER" then

        return "HEALER"
    end

    -- DPS — check spec ID for melee vs ranged (cache first, then live API)
    local unit = "raid" .. member.raidIndex
    local specID = self.specCache[member.normalizedName] or GetUnitSpecID(unit)
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

    -- Hunter: all specs are Agility so stat comparison can't distinguish;
    -- BM/MM (ranged) are far more common than Survival (melee)
    if member.class == "HUNTER" then

        return "RANGED"
    end

    -- Hybrid melee/ranged classes (Druid, Shaman, DH, etc.):
    -- melee DPS specs use Agility, ranged DPS specs use Intellect
    local agi = UnitStat(unit, 2) or 0
    local int = UnitStat(unit, 4) or 0
    if agi > int then

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

-- Split a list of same-role items (player names or encoded templates) into
-- two class-balanced sides.  Paired classes alternate evenly; unpaired
-- remainders go to the smaller side.
-- offsetA/offsetB: optional accumulated counts from prior roles so that
-- remainder distribution stays balanced across the full split.
function addon:ClassPairSplit(items, roster, offsetA, offsetB)
    offsetA = offsetA or 0
    offsetB = offsetB or 0

    local classGroups = {}
    local classOrder = {}

    for _, item in ipairs(items) do
        local itemClass = GetItemClass(item, roster)

        if not classGroups[itemClass] then
            classGroups[itemClass] = {}
            table.insert(classOrder, itemClass)
        end

        table.insert(classGroups[itemClass], item)
    end

    table.sort(classOrder)

    for _, cls in ipairs(classOrder) do
        table.sort(classGroups[cls])
    end

    local sideA, sideB = {}, {}

    for _, cls in ipairs(classOrder) do
        local group = classGroups[cls]

        for i = 1, #group - 1, 2 do
            table.insert(sideA, group[i])
            table.insert(sideB, group[i + 1])
        end
    end

    for _, cls in ipairs(classOrder) do
        local group = classGroups[cls]

        if #group % 2 == 1 then
            if (#sideA + offsetA) <= (#sideB + offsetB) then
                table.insert(sideA, group[#group])
            else
                table.insert(sideB, group[#group])
            end
        end
    end

    return sideA, sideB
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

    local sideA, sideB = {}, {}

    for _, role in ipairs(ROLE_ORDER) do
        local a, b = addon:ClassPairSplit(buckets[role], roster, #sideA, #sideB)
        for _, item in ipairs(a) do table.insert(sideA, item) end
        for _, item in ipairs(b) do table.insert(sideB, item) end
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
