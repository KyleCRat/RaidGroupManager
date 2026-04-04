local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local FONT = addon.FONT
local ROLE_ICON_SIZE = 16
local ROW_HEIGHT = 20
local MAX_ROWS = 40

local ROLE_ICON_PATH = "Interface\\AddOns\\RaidGroupManager\\Media\\Icons\\"

local ROLE_TEXTURES = {
    TANK = ROLE_ICON_PATH .. "tank",
    HEALER = ROLE_ICON_PATH .. "healer",
    MELEE = ROLE_ICON_PATH .. "meleedps",
    RANGED = ROLE_ICON_PATH .. "rangeddps",
}

local MODE_RAID = 1
local MODE_GUILD = 2
local MODE_ROLE = 3
local MODE_ROSTER = 4

local MODE_LABELS = {
    [MODE_RAID] = "Raid",
    [MODE_GUILD] = "Guild",
    [MODE_ROLE] = "Role",
    [MODE_ROSTER] = "Roster",
}

local TAB_MODES = { MODE_RAID, MODE_GUILD, MODE_ROLE, MODE_ROSTER }

local COLOR_TAB_ACTIVE = { r = 0.3, g = 0.3, b = 0.3, a = 0.9 }
local COLOR_TAB_INACTIVE = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }

--------------------------------------------------------------------------------
-- Minimal JSON parser for wowutils roster imports
--------------------------------------------------------------------------------

local function ParseJSON(text)
    local pos = 1
    local len = #text

    local function skip()
        while pos <= len do
            local b = text:byte(pos)
            if b == 32 or b == 9 or b == 10 or b == 13 then
                pos = pos + 1
            else
                break
            end
        end
    end

    local function expect(ch)
        skip()
        if text:byte(pos) ~= ch then
            error("JSON: expected '" .. string.char(ch) .. "' at " .. pos)
        end

        pos = pos + 1
    end

    local parseValue

    local function parseString()
        expect(34)
        local parts = {}

        while pos <= len do
            local b = text:byte(pos)

            if b == 34 then
                pos = pos + 1

                return table.concat(parts)
            end

            if b == 92 then
                pos = pos + 1
                local esc = text:byte(pos)
                if esc == 110 then table.insert(parts, "\n")
                elseif esc == 116 then table.insert(parts, "\t")
                elseif esc == 114 then table.insert(parts, "\r")
                elseif esc == 117 then
                    pos = pos + 5
                else
                    table.insert(parts, string.char(esc))
                    pos = pos + 1
                end
            else
                table.insert(parts, text:sub(pos, pos))
                pos = pos + 1
            end
        end
    end

    local function parseNumber()
        local start = pos
        if text:byte(pos) == 45 then pos = pos + 1 end

        while pos <= len and text:byte(pos) >= 48 and text:byte(pos) <= 57 do
            pos = pos + 1
        end

        if pos <= len and text:byte(pos) == 46 then
            pos = pos + 1

            while pos <= len and text:byte(pos) >= 48 and text:byte(pos) <= 57 do
                pos = pos + 1
            end
        end

        return tonumber(text:sub(start, pos - 1))
    end

    local function parseArray()
        expect(91)
        local arr = {}
        skip()

        if text:byte(pos) == 93 then
            pos = pos + 1

            return arr
        end

        while true do
            table.insert(arr, parseValue())
            skip()

            if text:byte(pos) == 44 then
                pos = pos + 1
            else
                break
            end
        end

        expect(93)

        return arr
    end

    local function parseObject()
        expect(123)
        local obj = {}
        skip()

        if text:byte(pos) == 125 then
            pos = pos + 1

            return obj
        end

        while true do
            local key = parseString()
            expect(58)
            obj[key] = parseValue()
            skip()

            if text:byte(pos) == 44 then
                pos = pos + 1
            else
                break
            end
        end

        expect(125)

        return obj
    end

    parseValue = function()
        skip()
        local b = text:byte(pos)

        if b == 34 then return parseString()
        elseif b == 123 then return parseObject()
        elseif b == 91 then return parseArray()
        elseif b == 116 then pos = pos + 4; return true
        elseif b == 102 then pos = pos + 5; return false
        elseif b == 110 then pos = pos + 4; return nil
        else return parseNumber()
        end
    end

    return parseValue()
end

--------------------------------------------------------------------------------
-- Wowutils roster parsing
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

local ROLE_FROM_IMPORT = {
    tank   = "TANK",
    healer = "HEALER",
    melee  = "MELEE",
    ranged = "RANGED",
}

local function NormalizeRealm(realm)
    return realm:gsub("%s+", "")
end

local function FindMainCharacter(member)
    local mainId = member.mainCharacterId
    if not mainId or not member.characters then
        return nil
    end

    for _, char in ipairs(member.characters) do
        local charId = char.name:lower() .. "-" .. NormalizeRealm(char.realm):lower()
        if charId == mainId then
            return char
        end
    end

    return member.characters[1]
end

local function ParseWowUtilsRoster(jsonText)
    local ok, data = pcall(ParseJSON, jsonText)
    if not ok or type(data) ~= "table" or not data.members then
        return nil
    end

    local roster = {}
    local playerRealm = addon:GetPlayerRealm()

    for _, member in ipairs(data.members) do
        local char = FindMainCharacter(member)
        if char then
            local normalizedRealm = NormalizeRealm(char.realm)
            local name = char.name:sub(1, 1):upper() .. char.name:sub(2)

            if normalizedRealm:lower() ~= playerRealm:lower() then
                name = name .. "-" .. normalizedRealm
            end

            table.insert(roster, {
                normalizedName = name,
                class = CLASS_TOKEN_FROM_NAME[char.playerClass] or "UNKNOWN",
                role = ROLE_FROM_IMPORT[member.mainRole] or "RANGED",
                displayName = member.displayName,
            })
        end
    end

    table.sort(roster, function(a, b)
        return a.normalizedName < b.normalizedName
    end)

    return roster
end

local function CreateEntryRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)

    row.nameText = row:CreateFontString(nil, "ARTWORK")
    row.nameText:SetFont(FONT, 12, "OUTLINE")
    row.nameText:SetPoint("LEFT", 2, 0)
    row.nameText:SetPoint("RIGHT", -(ROLE_ICON_SIZE + 4), 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.roleIcon = row:CreateTexture(nil, "ARTWORK")
    row.roleIcon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
    row.roleIcon:SetPoint("RIGHT", -2, 0)
    row.roleIcon:Hide()

    row.playerName = nil
    row.template = nil
    row:Hide()

    -- Drag into grid slots
    row:SetScript("OnDragStart", function(self)
        -- Template drag (Role mode)
        if self.template then
            addon.dragSource = self
            addon.dragSourceType = "template"
            addon.dragSourceTemplate = self.template
            self:SetAlpha(0.5)

            return
        end

        -- Player drag (Raid/Guild mode)
        if not self.playerName then
            return
        end

        addon.dragSource = self
        addon.dragSourceType = "unassigned"
        addon.dragSourceName = self.playerName
        self:SetAlpha(0.5)
    end)

    row:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)

        if not addon.dragSource then
            return
        end

        -- Check if cursor is over a grid slot
        for i = 1, 40 do
            local slot = addon.slots[i]
            if slot and slot:IsMouseOver() then
                if addon.dragSourceType == "template" then
                    local t = addon.dragSourceTemplate
                    addon:DropTemplateOnSlot(i, t.class, t.role)
                else
                    addon:DropNameOnSlot(i, addon.dragSourceName)
                end

                ClearDragState()

                return
            end
        end

        ClearDragState()
    end)

    return row
end

local function UpdateTabHighlights(tabs, activeMode)
    for mode, tab in pairs(tabs) do
        local c = (mode == activeMode) and COLOR_TAB_ACTIVE or COLOR_TAB_INACTIVE
        tab.bg:SetVertexColor(c.r, c.g, c.b, c.a)
    end
end

function addon:CreateUnassignedPanel(parent)
    -- Tab bar
    self.unassignedMode = MODE_RAID
    self.unassignedTabs = {}

    local tabWidth = math.floor(parent:GetWidth() / #TAB_MODES)
    local prevTab

    for _, mode in ipairs(TAB_MODES) do
        local tab = CreateFrame("Button", nil, parent)
        tab:SetSize(tabWidth, 18)

        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", 0, 0)
        else
            tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        end

        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetTexture("Interface\\Buttons\\WHITE8x8")

        tab.label = tab:CreateFontString(nil, "OVERLAY")
        tab.label:SetFont(FONT, 11, "OUTLINE")
        tab.label:SetPoint("CENTER")
        tab.label:SetText(MODE_LABELS[mode])

        tab:SetScript("OnClick", function()
            self.unassignedMode = mode
            UpdateTabHighlights(self.unassignedTabs, mode)

            if mode == MODE_GUILD then
                C_GuildInfo.GuildRoster()
            end

            self:UpdateRosterImportButton()
            self:RefreshUnassigned()
        end)

        self.unassignedTabs[mode] = tab
        prevTab = tab
    end

    UpdateTabHighlights(self.unassignedTabs, MODE_RAID)

    -- Roster import button (visible only in Roster mode)
    local importRosterBtn = self.CreateStyledButton(parent, parent:GetWidth(), 18, "Import Roster from WowUtils")
    importRosterBtn.label:SetFont(FONT, 10, "OUTLINE")
    importRosterBtn:SetPoint("TOPLEFT", 0, -20)
    importRosterBtn:SetPoint("TOPRIGHT", 0, -20)
    importRosterBtn:Hide()

    importRosterBtn:SetScript("OnClick", function()
        self:ShowRosterImportWindow()
    end)

    self.importRosterBtn = importRosterBtn

    -- Dark background container for scroll area
    local scrollBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    scrollBg:SetPoint("TOPLEFT", 0, -20)
    scrollBg:SetPoint("BOTTOMRIGHT", 0, 30)
    self.unassignedScrollBg = scrollBg
    scrollBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    scrollBg:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    scrollBg:SetBackdropBorderColor(0, 0, 0, 1)

    -- Scroll frame for entries
    local scrollFrame = CreateFrame("ScrollFrame", "RGMUnassignedScroll", scrollBg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 2)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(content)

    self.unassignedContent = content
    self.unassignedRows = {}

    for i = 1, MAX_ROWS do
        self.unassignedRows[i] = CreateEntryRow(content, i)
    end

    -- Name input field + Add button at the bottom
    local addEditBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    addEditBox:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    addEditBox:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -44, 0)
    addEditBox:SetHeight(20)
    addEditBox:SetFont(FONT, 12, "OUTLINE")
    addEditBox:SetAutoFocus(false)
    addEditBox:SetTextColor(1, 1, 1, 1)
    addEditBox:SetMaxLetters(40)
    addEditBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    addEditBox:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    addEditBox:SetBackdropBorderColor(0, 0, 0, 1)
    addEditBox:SetTextInsets(4, 4, 0, 0)

    addEditBox:SetScript("OnEnterPressed", function(self)
        local name = strtrim(self:GetText())
        if name ~= "" then
            addon:AddNameToGrid(addon:NormalizeName(name))
            self:SetText("")
        end
    end)

    addEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local addBtn = self.CreateStyledButton(parent, 40, 20, "Add")
    addBtn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    addBtn:SetScript("OnClick", function()
        local name = strtrim(addEditBox:GetText())
        if name ~= "" then
            addon:AddNameToGrid(addon:NormalizeName(name))
            addEditBox:SetText("")
        end
    end)
end

-- Build the set of player names currently assigned in the grid (excludes templates)
local function GetAssignedPlayerNames()
    local assigned = {}
    for i = 1, 40 do
        if addon:IsSlotPlayer(i) then
            assigned[addon:GetSlotText(i)] = true
        end
    end

    return assigned
end

function addon:GetUnassignedRaidMembers()
    local assigned = GetAssignedPlayerNames()
    local unassigned = {}
    local roster = self:GetRaidRoster()

    for normalized, member in pairs(roster) do
        if not assigned[normalized] then
            table.insert(unassigned, member)
        end
    end

    table.sort(unassigned, function(a, b)
        return a.normalizedName < b.normalizedName
    end)

    return unassigned
end

function addon:GetUnassignedGuildMembers()
    local assigned = GetAssignedPlayerNames()
    local unassigned = {}
    local playerLevel = UnitLevel("player")
    local numGuild = GetNumGuildMembers()

    for i = 1, numGuild do
        local name, _, rankIndex, level, _, _, _, _, _, _, classFile = GetGuildRosterInfo(i)
        if name and level >= playerLevel then
            local normalized = self:NormalizeName(name)
            if not assigned[normalized] then
                table.insert(unassigned, {
                    normalizedName = normalized,
                    displayName = "[" .. rankIndex .. "] " .. normalized,
                    class = classFile,
                    role = "NONE",
                    rankIndex = rankIndex,
                })
            end
        end
    end

    table.sort(unassigned, function(a, b)
        if a.rankIndex ~= b.rankIndex then
            return a.rankIndex < b.rankIndex
        end

        return a.normalizedName < b.normalizedName
    end)

    return unassigned
end

function addon:RefreshUnassigned()
    if not self.unassignedRows then
        return
    end

    if self.unassignedMode == MODE_ROLE then
        self:RefreshUnassignedRoleMode()

        return
    end

    if self.unassignedMode == MODE_ROSTER then
        self:RefreshUnassignedRosterMode()

        return
    end

    local entries
    if self.unassignedMode == MODE_GUILD then
        entries = self:GetUnassignedGuildMembers()
    else
        entries = self:GetUnassignedRaidMembers()
    end

    for i = 1, MAX_ROWS do
        local row = self.unassignedRows[i]
        local entry = entries[i]

        if entry then
            local displayName = entry.displayName or entry.normalizedName
            row.nameText:SetText(displayName)
            row.playerName = entry.normalizedName
            row.template = nil

            -- Class color
            local classColor = entry.class and C_ClassColor.GetClassColor(entry.class)
            if classColor then
                row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
                row.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, 0.25)
            else
                row.nameText:SetTextColor(0.5, 0.5, 0.5)
                row.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)
            end

            -- Role icon
            local combatRole
            if entry.raidIndex then
                combatRole = addon:GetCombatRole(entry)
            end

            local texture = combatRole and ROLE_TEXTURES[combatRole]
            if texture then
                row.roleIcon:SetTexture(texture)
                row.roleIcon:Show()
            else
                row.roleIcon:Hide()
            end

            row:Show()
        else
            row:Hide()
            row.playerName = nil
            row.template = nil
        end
    end

    local totalHeight = math.max(1, #entries * ROW_HEIGHT)
    self.unassignedContent:SetHeight(totalHeight)
end

function addon:RefreshUnassignedRoleMode()
    local entries = self:GetClassRoleCombos()

    for i = 1, MAX_ROWS do
        local row = self.unassignedRows[i]
        local entry = entries[i]

        if entry then
            row.nameText:SetText(entry.className)
            row.playerName = nil
            row.template = { class = entry.class, role = entry.role }

            -- Class color
            local classColor = C_ClassColor.GetClassColor(entry.class)
            if classColor then
                row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
                row.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, 0.25)
            else
                row.nameText:SetTextColor(0.5, 0.5, 0.5)
                row.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)
            end

            -- Role icon
            local texture = ROLE_TEXTURES[entry.role]
            if texture then
                row.roleIcon:SetTexture(texture)
                row.roleIcon:Show()
            else
                row.roleIcon:Hide()
            end

            row:Show()
        else
            row:Hide()
            row.playerName = nil
            row.template = nil
        end
    end

    local totalHeight = math.max(1, #entries * ROW_HEIGHT)
    self.unassignedContent:SetHeight(totalHeight)
end

--------------------------------------------------------------------------------
-- Roster mode
--------------------------------------------------------------------------------

function addon:UpdateRosterImportButton()
    if not self.importRosterBtn then
        return
    end

    if self.unassignedMode == MODE_ROSTER then
        self.importRosterBtn:Show()
        self.unassignedScrollBg:SetPoint("TOPLEFT", 0, -40)
    else
        self.importRosterBtn:Hide()
        self.unassignedScrollBg:SetPoint("TOPLEFT", 0, -20)
    end
end

function addon:RefreshUnassignedRosterMode()
    local roster = self.db.profile.importedRoster or {}
    local assigned = {}

    for i = 1, 40 do
        if self:IsSlotPlayer(i) then
            assigned[self:GetSlotText(i)] = true
        end
    end

    local entries = {}
    for _, entry in ipairs(roster) do
        if not assigned[entry.normalizedName] then
            table.insert(entries, entry)
        end
    end

    for i = 1, MAX_ROWS do
        local row = self.unassignedRows[i]
        local entry = entries[i]

        if entry then
            row.nameText:SetText(entry.normalizedName)
            row.playerName = entry.normalizedName
            row.template = nil

            local classColor = entry.class and C_ClassColor.GetClassColor(entry.class)
            if classColor then
                row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
                row.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, 0.25)
            else
                row.nameText:SetTextColor(0.5, 0.5, 0.5)
                row.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)
            end

            local texture = entry.role and ROLE_TEXTURES[entry.role]
            if texture then
                row.roleIcon:SetTexture(texture)
                row.roleIcon:Show()
            else
                row.roleIcon:Hide()
            end

            row:Show()
        else
            row:Hide()
            row.playerName = nil
            row.template = nil
        end
    end

    local totalHeight = math.max(1, #entries * ROW_HEIGHT)
    self.unassignedContent:SetHeight(totalHeight)
end

--------------------------------------------------------------------------------
-- Roster import modal
--------------------------------------------------------------------------------

local ROSTER_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

function addon:ShowRosterImportWindow()
    if self.rosterImportFrame then
        self.rosterImportFrame:Show()
        self.rosterImportEditBox:SetText("")
        self.rosterImportEditBox:SetFocus()

        return
    end

    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER")
    frame:SetBackdrop(ROSTER_BACKDROP)
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(addon.TITLE_HEIGHT)
    titleBar:EnableMouse(true)

    titleBar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)

    titleBar:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
    end)

    titleBar.bg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBar.bg:SetAllPoints()
    titleBar.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    titleBar.bg:SetVertexColor(0, 0, 0, 0.2)

    titleBar.text = titleBar:CreateFontString(nil, "ARTWORK")
    titleBar.text:SetFont(FONT, 16, "OUTLINE")
    titleBar.text:SetPoint("LEFT", 8, 0)
    titleBar.text:SetText("Import Roster from Wowutils via JSON")
    titleBar.text:SetTextColor(1, 1, 1, 1)

    local close = addon.CreateCloseButton(titleBar, frame)
    close:SetPoint("RIGHT", -6, 1)

    -- Edit box area
    local editBg = frame:CreateTexture(nil, "BACKGROUND")
    editBg:SetPoint("TOPLEFT", 10, -(addon.TITLE_HEIGHT + 10))
    editBg:SetPoint("BOTTOMRIGHT", -10, 50)
    editBg:SetColorTexture(0, 0, 0, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", editBg, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", editBg, "BOTTOMRIGHT", -22, 4)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(FONT, 12, "OUTLINE")
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetWidth(scrollFrame:GetWidth())

    editBox:SetScript("OnEscapePressed", function(eb)
        eb:ClearFocus()
    end)

    scrollFrame:SetScrollChild(editBox)
    scrollFrame:EnableMouse(true)

    scrollFrame:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    self.rosterImportEditBox = editBox
    self.rosterImportFrame = frame

    local importBtn = addon.CreateStyledButton(frame, 80, 24, "Import")
    importBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    importBtn:SetScript("OnClick", function()
        self:DoRosterImport()
    end)

    frame:Show()
    editBox:SetFocus()
end

function addon:DoRosterImport()
    local text = self.rosterImportEditBox:GetText()
    if not text or strtrim(text) == "" then
        self:Print("Nothing to import.")

        return
    end

    local roster = ParseWowUtilsRoster(text)
    if not roster then
        self:Print("Could not parse roster JSON. Check the format.")

        return
    end

    self.db.profile.importedRoster = roster
    self:Print("Imported " .. #roster .. " roster members.")
    self:RefreshUnassigned()

    if self.rosterImportFrame then
        self.rosterImportFrame:Hide()
    end
end
