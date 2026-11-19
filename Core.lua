local addon = LibStub("AceAddon-3.0"):NewAddon(
    "RaidGroupManager",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceSerializer-3.0"
)

addon.printName = "RGM"

function addon:Print(...)
    local frame = DEFAULT_CHAT_FRAME
    local firstArgument = ...
    local firstMessageArgument = 1

    if type(firstArgument) == "table" and firstArgument.AddMessage then
        frame = firstArgument
        firstMessageArgument = 2
    end

    local parts = { "|cffb3b3b3" .. self.printName .. ":|r" }
    for index = firstMessageArgument, select("#", ...) do
        parts[#parts + 1] = tostring((select(index, ...)))
    end

    frame:AddMessage(table.concat(parts, " "))
end

local addonMeta = getmetatable(addon)
if addonMeta then
    addonMeta.__tostring = function(self)
        return self.printName or self.name
    end
end

_G["BINDING_NAME_CLICK RGMToggle:LeftButton"] = "Toggle Window"

local toggleBtn =
    CreateFrame("Button", "RGMToggle", nil, "SecureActionButtonTemplate")
toggleBtn:SetScript("OnClick", function()
    addon:ToggleMainFrame()
end)

addon.FONT =
    "Interface\\AddOns\\RaidGroupManager\\Media\\Fonts\\PTSansNarrow-Bold.ttf"

addon.UI_SPACING = 8
addon.SLOT_WIDTH = 150
addon.SLOT_HEIGHT = 20
addon.SLOT_GAP = 2
addon.GROUP_HEADER_HEIGHT = 16
addon.TITLE_HEIGHT = 28
addon.LEADERSHIP_ICON_SIZE = 12
addon.LEADER_ICON_TEXTURE = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
addon.ASSIST_ICON_TEXTURE = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
addon.ROW_BG_ALPHA = 0.4
addon.PANEL_BG_COLOR = { r = 0.05, g = 0.05, b = 0.05, a = 0.8 }

local playerRealm = nil

local defaults = {
    global = {
        changelog = { autoShow = true },
    },
    profile = {
        minimap = { hide = false },
        layouts = {},
        nextLayoutId = 1,
        framePosition = nil,
        frameScale = 1,
        gridState = nil,
        specCache = {},
        specCacheTimes = {},
        specCacheContext = {},
        debugMode = false,
    },
    char = {
        importedRoster = {},
        importedRosterGroupByMember = false,
        rosterLeaders = {},
    },
}

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RaidGroupManagerDB", defaults, true)
    if self.db.profile.importedRoster then
        if
            not self.db.char.importedRoster
            or not next(self.db.char.importedRoster)
        then
            self.db.char.importedRoster = self.db.profile.importedRoster
        end
        self.db.profile.importedRoster = nil
    end

    self.slots = {}
    self.autoSave = false
    self.debugMode = self.db.profile.debugMode
    self.RoleDetection:Initialize()

    self:InitializeLayoutState()
    self:InstallPresetLayouts()
    self:RegisterChatCommand("rgm", "SlashCommand")
    self:SetupMinimapButton()
    self:InitializeChangelog()
end

function addon:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterEvent("UNIT_CONNECTION", "OnRosterUpdate")
    self:RegisterEvent("UNIT_NAME_UPDATE", "OnUnitNameUpdate")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self.RoleDetection:Enable()
    self:EnableRosterLeaderSync()
end

function addon:OnDisable()
    self:StopApply()
    self.RoleDetection:Disable()
    self:DisableRosterLeaderSync()
end

function addon:OnRosterUpdate()
    if not self.mainFrame or not self.mainFrame:IsShown() then return end

    local roster = self:GetGroupDisplayRoster()
    self:RefreshAllSlots(roster)
    self:RefreshUnassigned(roster)
end

function addon:OnUnitNameUpdate(_, unit)
    if issecretvalue(unit) or not unit then return end

    if
        unit ~= "player"
        and not unit:match("^raid%d+$")
        and not unit:match("^party%d+$")
    then
        return
    end

    -- Class/name data can arrive after the member's initial roster update.
    self.RoleDetection:UpdateRoster()
    self:OnRosterUpdate()
end

function addon:OnEncounterStart()
    if not self.mainFrame or not self.mainFrame:IsShown() then return end

    self.hiddenByEncounter = true
    self.mainFrame:Hide()
end

function addon:OnEncounterEnd()
    if not self.hiddenByEncounter then return end

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

        if not self.mainFrame then self:CreateMainFrame() end

        self:SetSelectedLayout(layout)
        self:LoadLayoutToGrid(layout)
        self:StartApply()

        return
    end

    if cmd == "presets" then
        self:InstallPresetLayouts(true)
        self:RefreshLayoutList()

        return
    end

    if cmd == "disband" or cmd == "d" then
        self:PromptDisbandRaid()

        return
    end

    if cmd == "changelog" then
        self:ShowChangelog()

        return
    end

    if cmd == "debug" then
        self.debugMode = not self.debugMode
        self.db.profile.debugMode = self.debugMode
        self:Print(
            "Debug mode " .. (self.debugMode and "enabled" or "disabled")
        )
        self.RoleDetection:OnDebugModeChanged()

        return
    end

    if cmd == "help" then
        self:Print("Commands:")
        self:Print("  /rgm - Toggle the main window")
        self:Print("  /rgm apply <name> - Apply a saved layout")
        self:Print("  /rgm presets - Add preset layouts to your list")
        self:Print("  /rgm disband or /rgm d - Disband the raid")
        self:Print("  /rgm changelog - Show update notes")
        self:Print("  /rgm debug - Toggle debug messages")
        self:Print("  /rgm help - Show this help")

        return
    end

    self:Print("Unknown command. Type /rgm help for usage.")
end

function addon:FindLayoutByName(name)
    local nameLower = name:lower()
    for _, layout in ipairs(self.db.profile.layouts) do
        if layout.name:lower() == nameLower then return layout end
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
    if self.debugMode then self:Print("[DEBUG]", ...) end
end

--------------------------------------------------------------------------------
-- Name handling
--------------------------------------------------------------------------------

function addon:GetPlayerRealm()
    if not playerRealm then playerRealm = GetNormalizedRealmName() end

    return playerRealm
end

function addon:NormalizeRealm(realm)
    if not realm or realm == "" then return nil end

    return realm:gsub("%s+", "")
end

function addon:BuildFullName(name, realm)
    local normalizedRealm = self:NormalizeRealm(realm)
    if normalizedRealm then return name .. "-" .. normalizedRealm end

    return name
end

-- Normalize a name: strip realm suffix if it matches the player's realm.
-- Cross-realm names keep their realm suffix.
function addon:NormalizeName(name)
    if not name then return nil end

    local dashPos = name:find("-")
    if not dashPos then return name end

    local realm = name:sub(dashPos + 1)
    if realm == self:GetPlayerRealm() then return name:sub(1, dashPos - 1) end

    return name
end

--------------------------------------------------------------------------------
-- Raid roster
--------------------------------------------------------------------------------

local function GetPublicAssignedRole(unit)
    local role = UnitGroupRolesAssigned(unit)
    if issecretvalue(role) then return "NONE" end

    return role
end

-- Build a lookup table of current raid members: normalizedName -> info
function addon:GetRaidRoster()
    local roster = {}

    if not IsInRaid() then return roster end

    for i = 1, 40 do
        local name, rank, subgroup, _, _, class, _, online =
            GetRaidRosterInfo(i)
        if name then
            local normalized = self:NormalizeName(name)
            local unit = "raid" .. i
            roster[normalized] = {
                name = name,
                normalizedName = normalized,
                rank = rank,
                class = class,
                role = GetPublicAssignedRole(unit),
                subgroup = subgroup,
                online = online,
                raidIndex = i,
                unitToken = unit,
            }
        end
    end

    return roster
end

local function AddLiveUnitToRoster(roster, unit)
    if not UnitExists(unit) then return end

    local name, realm = UnitFullName(unit)
    if not name then return end

    local fullName = addon:BuildFullName(name, realm)
    local normalized = addon:NormalizeName(fullName)
    local _, class = UnitClass(unit)

    roster[normalized] = {
        name = fullName,
        normalizedName = normalized,
        rank = 0,
        class = class,
        role = GetPublicAssignedRole(unit),
        subgroup = 1,
        online = UnitIsUnit(unit, "player") or UnitIsConnected(unit),
        unitToken = unit,
    }
end

function addon:GetGroupDisplayRoster()
    if IsInRaid() then return self:GetRaidRoster() end

    local roster = {}
    AddLiveUnitToRoster(roster, "player")

    if IsInGroup() then
        for i = 1, 4 do
            AddLiveUnitToRoster(roster, "party" .. i)
        end
    end

    return roster
end

function addon:GetRaidLeaderName()
    local roster = self:GetRaidRoster()

    for name, member in pairs(roster) do
        if member.rank == 2 then return name, member end
    end

    return nil
end

function addon:GetImportedRosterEntry(name)
    local normalized = self:NormalizeName(name)
    if not normalized then return nil end

    for _, entry in ipairs(self.db.char.importedRoster or {}) do
        if self:NormalizeName(entry.normalizedName) == normalized then
            return entry
        end
    end

    return nil
end

function addon:AddUnitToSet(set, unit)
    if not UnitExists(unit) then return end

    local name, realm = UnitFullName(unit)
    if not name then return end

    local fullName = self:BuildFullName(name, realm)
    set[self:NormalizeName(fullName)] = true
end

function addon:BuildCurrentGroupSet()
    local grouped = {}

    self:AddUnitToSet(grouped, "player")

    if IsInRaid() then
        for i = 1, 40 do
            local name = GetRaidRosterInfo(i)
            if name then grouped[self:NormalizeName(name)] = true end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            self:AddUnitToSet(grouped, "party" .. i)
        end
    end

    return grouped
end

function addon:FormatNameList(names)
    if not names or #names == 0 then return "" end

    return table.concat(names, ", ")
end

function addon:GetLeadershipIconTextureForRank(rank)
    if rank == 2 then return self.LEADER_ICON_TEXTURE end

    if rank == 1 then return self.ASSIST_ICON_TEXTURE end

    return nil
end

local function LayoutLeadershipName(frame)
    local normalPadding = frame.rgmLeadershipRoleIconSize + 4
    local leadershipPadding = frame.rgmLeadershipRoleIconSize
        + addon.LEADERSHIP_ICON_SIZE
        + 7

    frame.nameText:ClearAllPoints()
    addon.PixelPerfect.Point(
        frame.nameText,
        "LEFT",
        frame,
        "LEFT",
        frame.rgmLeadershipLeftOffset,
        0
    )

    local offlineIcon = frame.offlineIcon
    if offlineIcon and offlineIcon:IsShown() then
        local nextIcon = frame.rgmHasLeadershipIcon and frame.leaderIcon
            or frame.roleIcon
        offlineIcon:ClearAllPoints()
        addon.PixelPerfect.Point(
            offlineIcon,
            "RIGHT",
            nextIcon,
            "LEFT",
            -offlineIcon.rgmGap,
            0
        )
        addon.PixelPerfect.Point(
            frame.nameText,
            "RIGHT",
            offlineIcon,
            "LEFT",
            -offlineIcon.rgmGap,
            0
        )

        return
    end

    addon.PixelPerfect.Point(
        frame.nameText,
        "RIGHT",
        frame,
        "RIGHT",
        frame.rgmHasLeadershipIcon and -leadershipPadding or -normalPadding,
        0
    )
end

function addon:CreateLeadershipIcon(parent, relativeTo)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    local pixelPerfect = self.PixelPerfect

    pixelPerfect.RegisterLayout(icon, function()
        icon:ClearAllPoints()
        pixelPerfect.Size(
            icon,
            self.LEADERSHIP_ICON_SIZE,
            self.LEADERSHIP_ICON_SIZE
        )
        pixelPerfect.Point(icon, "RIGHT", relativeTo, "LEFT", -1, 0)
    end)

    icon:SetTexture(self.LEADER_ICON_TEXTURE)
    icon:Hide()

    return icon
end

function addon:SetLeadershipIconState(
    frame,
    iconTexture,
    leftOffset,
    roleIconSize,
    desaturated
)
    frame.rgmLeadershipLeftOffset = leftOffset
    frame.rgmLeadershipRoleIconSize = roleIconSize
    frame.rgmHasLeadershipIcon = iconTexture ~= nil

    if not frame.rgmLeadershipLayoutRegistered then
        frame.rgmLeadershipLayoutRegistered = true
        self.PixelPerfect.RegisterLayout(frame, function()
            LayoutLeadershipName(frame)
        end)
    else
        LayoutLeadershipName(frame)
    end

    if iconTexture then
        frame.leaderIcon:SetTexture(iconTexture)
        frame.leaderIcon:SetDesaturated(desaturated == true)
        frame.leaderIcon:Show()
    else
        frame.leaderIcon:SetDesaturated(false)
        frame.leaderIcon:Hide()
    end
end

function addon:SetLeaderIconState(
    frame,
    isLeader,
    leftOffset,
    roleIconSize,
    desaturated
)
    self:SetLeadershipIconState(
        frame,
        isLeader and self.LEADER_ICON_TEXTURE or nil,
        leftOffset,
        roleIconSize,
        desaturated
    )
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
    if not text or text:sub(1, 1) ~= TEMPLATE_PREFIX then return nil end

    local role, class = text:sub(2):match("^(%u+)-(%u+)$")
    if role and class then return { role = role, class = class } end

    return nil
end

--------------------------------------------------------------------------------
-- Grid slot data access
--------------------------------------------------------------------------------

function addon:GetSlotText(slotIndex)
    local slot = self.slots[slotIndex]
    if not slot then return "" end

    return slot.playerName or ""
end

function addon:SetSlotText(slotIndex, text)
    local slot = self.slots[slotIndex]
    if not slot then return end

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

function addon:EnsureRaidLeaderSlotOne(showMessage)
    local leaderName = self:GetRaidLeaderName()
    if not leaderName then return false end

    for slotIndex = 1, 40 do
        if
            self:IsSlotPlayer(slotIndex)
            and self:NormalizeName(self:GetSlotText(slotIndex))
                == leaderName
        then
            local groupStart = math.floor((slotIndex - 1) / 5) * 5 + 1
            if slotIndex == groupStart then return false end

            local leaderText = self:GetSlotText(slotIndex)
            for i = slotIndex, groupStart + 1, -1 do
                self:SetSlotText(i, self:GetSlotText(i - 1))
            end

            self:SetSlotText(groupStart, leaderText)

            if showMessage and self.ShowToast then
                self:ShowToast(
                    "Raid leader must be in the first slot of their group"
                )
            end

            return true
        end
    end

    return false
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
    self:RefreshLayoutHeader()
end

-- Save current grid state to the selected layout
function addon:SaveToSelectedLayout()
    if not self.selectedLayout then return false end

    self.selectedLayout.slots = self:GetGridState()
    self.selectedLayout.time = time()

    return true
end

-- Auto-save if enabled and a layout is selected
function addon:TryAutoSave()
    if self.autoSave and self.selectedLayout then
        self:SaveToSelectedLayout()
    end

    self:PersistGridState()
    self:RefreshLayoutHeader()
end

-- Persist the current grid to saved variables so it survives reloads
function addon:PersistGridState()
    self.db.profile.gridState = self:GetGridState()
end

-- Restore grid contents from saved variables
function addon:RestoreGridState()
    local state = self.db.profile.gridState
    if not state then return end

    for i = 1, 40 do
        self:SetSlotText(i, state[i] or "")
    end

    self:RefreshLayoutHeader()
end

function addon:IsGridEmpty()
    for i = 1, 40 do
        if not self:IsSlotEmpty(i) then return false end
    end

    return true
end

function addon:ClearGrid()
    for i = 1, 40 do
        self:SetSlotText(i, "")
    end

    self:RefreshAllSlots()
    self:RefreshUnassigned()
    self:TryAutoSave()
end

-- Add a name to the first empty grid slot (skips template slots)
function addon:AddNameToGrid(name)
    if not name or name == "" then return end

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

function addon:RebalanceSplitForCapacity(sideA, sideB, capacityA, capacityB)
    while #sideA > capacityA and #sideB < capacityB do
        table.insert(sideB, table.remove(sideA))
    end

    while #sideB > capacityB and #sideA < capacityA do
        table.insert(sideA, table.remove(sideB))
    end
end

-- Collect all non-empty slot contents (players and templates) from groups
local function CollectSlotContents(groups)
    local items = {}
    for _, g in ipairs(groups) do
        for p = 1, 5 do
            local slotIndex = (g - 1) * 5 + p
            local text = addon:GetSlotText(slotIndex)
            if text ~= "" then table.insert(items, text) end
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
            if idx > #items then return end

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

local ROLE_ORDER = { "TANK", "MELEE", "RANGED", "HEALER" }

-- Split a list of slot contents (player names or encoded templates) into
-- two role-balanced sides. Each role bucket is alternated evenly.
local function ClassifyItem(item, roster)
    local template = addon:DecodeTemplate(item)
    if template then return template.role end

    local normalized = addon:NormalizeName(item)

    return addon:GetCombatRole(roster[normalized], normalized)
end

local function GetItemClass(item, roster)
    local template = addon:DecodeTemplate(item)
    if template then return template.class end

    local normalized = addon:NormalizeName(item)
    local member = roster[normalized]
    if member and member.class then return member.class end

    local imported = addon:GetImportedRosterEntry(normalized)

    return imported and imported.class or "UNKNOWN"
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
        for _, item in ipairs(a) do
            table.insert(sideA, item)
        end
        for _, item in ipairs(b) do
            table.insert(sideB, item)
        end
    end

    return sideA, sideB
end

--------------------------------------------------------------------------------
-- Split functions
--------------------------------------------------------------------------------

function addon:SplitOddEven()
    local allGroups = self:GetActiveRaidGroups()
    local oddGroups, evenGroups = {}, {}

    for _, group in ipairs(allGroups) do
        if group % 2 == 1 then
            oddGroups[#oddGroups + 1] = group
        else
            evenGroups[#evenGroups + 1] = group
        end
    end

    local items = CollectSlotContents(allGroups)
    local roster = self:GetGroupDisplayRoster()
    ClearGroups(allGroups)

    local oddItems, evenItems = SplitByRole(items, roster)
    self:RebalanceSplitForCapacity(
        oddItems,
        evenItems,
        self:GetGroupSlotCapacity(oddGroups),
        self:GetGroupSlotCapacity(evenGroups)
    )

    PlaceItemsInGroups(oddItems, oddGroups)
    PlaceItemsInGroups(evenItems, evenGroups)
    self:EnsureRaidLeaderSlotOne(false)

    self:RefreshAllSlots()
    self:RefreshUnassigned()
    self:TryAutoSave()
end

function addon:SplitHalves()
    local allGroups = self:GetActiveRaidGroups()

    local items = CollectSlotContents(allGroups)
    local roster = self:GetGroupDisplayRoster()
    ClearGroups(allGroups)

    local firstItems, secondItems = SplitByRole(items, roster)

    -- Pack each half into only as many groups as needed
    local firstCount = GroupsNeeded(#firstItems)
    local secondCount = GroupsNeeded(#secondItems)

    if firstCount + secondCount > #allGroups then
        local maxSecondCount = math.floor(#allGroups / 2)
        local maxFirstCount = #allGroups - maxSecondCount
        self:RebalanceSplitForCapacity(
            firstItems,
            secondItems,
            maxFirstCount * 5,
            maxSecondCount * 5
        )
        firstCount = math.min(GroupsNeeded(#firstItems), maxFirstCount)
        secondCount = math.min(GroupsNeeded(#secondItems), maxSecondCount)
    end

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
    self:EnsureRaidLeaderSlotOne(false)

    self:RefreshAllSlots()
    self:RefreshUnassigned()
    self:TryAutoSave()
end
