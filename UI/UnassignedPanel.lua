local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local PixelPerfect = addon.PixelPerfect
local FONT = addon.FONT
local ROLE_ICON_SIZE = 16
local ROW_HEIGHT = 20
local MAX_ROWS = 40
local ROW_BG_ALPHA = addon.ROW_BG_ALPHA
local PANEL_BG_COLOR = addon.PANEL_BG_COLOR
local UI_SPACING = addon.UI_SPACING

local TAB_HEIGHT = 18
local TAB_FOOTER_GAP = 4
local ADD_CONTROL_HEIGHT = 20
local ADD_BUTTON_WIDTH = 40
local IMPORT_BUTTON_HEIGHT = 24

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
local COLOR_TAB_HOVER = { r = 0.22, g = 0.22, b = 0.22, a = 0.95 }
local COLOR_BLACK = { r = 0, g = 0, b = 0, a = 1 }

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

local ClassSpecRoles = addon.ClassSpecRoles

local function GetCharacterID(char)
    if not char or not char.name or not char.realm then
        return nil
    end

    local normalizedRealm = addon:NormalizeRealm(char.realm)
    if not normalizedRealm then
        return nil
    end

    return char.name:lower() .. "-" .. normalizedRealm:lower()
end

local function ShouldImportCharacter(member, char)
    local charId = GetCharacterID(char)
    if not charId then
        return false
    end

    local statuses = member.characterStatuses
    if type(statuses) == "table" then
        local status = statuses[charId]

        return status == "main" or status == "alt"
    end

    return charId == member.mainCharacterId
end

local function ParseWowUtilsRoster(jsonText)
    local ok, data = pcall(ParseJSON, jsonText)
    if not ok or type(data) ~= "table" or not data.members then
        return nil
    end

    local roster = {}
    local playerRealm = addon:GetPlayerRealm()

    for _, member in ipairs(data.members) do
        if type(member.characters) == "table" then
            for _, char in ipairs(member.characters) do
                if ShouldImportCharacter(member, char) then
                    local normalizedRealm = addon:NormalizeRealm(char.realm)
                    local name = char.name:sub(1, 1):upper() .. char.name:sub(2)

                    if normalizedRealm and normalizedRealm:lower() ~= playerRealm:lower() then
                        name = name .. "-" .. normalizedRealm
                    end

                    local classToken = ClassSpecRoles:GetClassTokenFromName(char.playerClass) or "UNKNOWN"
                    table.insert(roster, {
                        normalizedName = name,
                        class = classToken,
                        role = ClassSpecRoles:GetImportedCharacterRole(member, classToken, char),
                        displayName = member.displayName,
                    })
                end
            end
        end
    end

    table.sort(roster, ClassSpecRoles.CompareRosterEntriesByRoleThenName)

    return roster
end

local function CreateEntryRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row.rowIndex = index
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    PixelPerfect.DisablePixelSnap(row.bg)
    row.bg:SetVertexColor(0.5, 0.5, 0.5, ROW_BG_ALPHA)

    row.nameText = row:CreateFontString(nil, "ARTWORK")
    row.nameText:SetFont(FONT, 12, "OUTLINE")
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.roleIcon = row:CreateTexture(nil, "ARTWORK")
    row.roleIcon:Hide()

    row.leaderIcon = addon:CreateLeadershipIcon(row, row.roleIcon)

    row.playerName = nil
    row.template = nil
    row:Hide()

    row:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and (self.template or self.playerName) then
            addon:CaptureDragCursorOffset(self)

            return
        end

        if button == "MiddleButton" and self.playerName then
            if addon.unassignedMode == MODE_RAID then
                addon:ToggleRaidAssist(self.playerName)
            elseif addon.unassignedMode == MODE_ROSTER then
                addon:ToggleRosterLeader(self.playerName)
            end
        end
    end)

    -- Drag into grid slots
    row:SetScript("OnDragStart", function(self)
        -- Template drag (Role mode)
        if self.template then
            addon.dragSource = self
            addon.dragSourceType = "template"
            addon.dragSourceTemplate = self.template
            addon:StartDragVisual(self)

            return
        end

        -- Player drag (Raid/Guild mode)
        if not self.playerName then
            return
        end

        addon.dragSource = self
        addon.dragSourceType = "unassigned"
        addon.dragSourceName = self.playerName
        addon:StartDragVisual(self)
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

                addon:ClearDragState()

                return
            end
        end

        addon:ClearDragState()
    end)

    return row
end

local function SetRowLeadershipIconState(row, iconTexture)
    addon:SetLeadershipIconState(row, iconTexture, 2, ROLE_ICON_SIZE)
end

local function SetRowLeaderState(row, isLeader)
    addon:SetLeaderIconState(row, isLeader, 2, ROLE_ICON_SIZE)
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

    for _, mode in ipairs(TAB_MODES) do
        local tab = CreateFrame("Button", nil, parent)

        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        PixelPerfect.DisablePixelSnap(tab.bg)

        tab.label = tab:CreateFontString(nil, "OVERLAY")
        tab.label:SetFont(FONT, 11, "OUTLINE")
        tab.label:SetPoint("CENTER")
        tab.label:SetText(MODE_LABELS[mode])

        tab:SetScript("OnEnter", function()
            tab.bg:SetVertexColor(COLOR_TAB_HOVER.r, COLOR_TAB_HOVER.g, COLOR_TAB_HOVER.b, COLOR_TAB_HOVER.a)
        end)

        tab:SetScript("OnLeave", function()
            local c = (self.unassignedMode == mode) and COLOR_TAB_ACTIVE or COLOR_TAB_INACTIVE
            tab.bg:SetVertexColor(c.r, c.g, c.b, c.a)
        end)

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
    end

    UpdateTabHighlights(self.unassignedTabs, MODE_RAID)

    -- Bordered tab content area
    local scrollBg = CreateFrame("Frame", nil, parent)
    self.unassignedScrollBg = scrollBg
    PixelPerfect.CreateSurface(scrollBg, PANEL_BG_COLOR, COLOR_BLACK, 1)

    -- Roster-only footer below the tab content area
    local importRosterBtn = addon.CreateStyledButton(parent, 1, ADD_CONTROL_HEIGHT, "Import Roster from WowUtils")
    importRosterBtn.label:SetFont(FONT, 10, "OUTLINE")
    importRosterBtn:Hide()

    importRosterBtn:SetScript("OnClick", function()
        self:ShowRosterImportWindow()
    end)

    self.importRosterBtn = importRosterBtn

    -- Scroll frame for entries
    local scrollFrame = addon.CreateScrollFrame(scrollBg, "RGMUnassignedScroll")

    local content = CreateFrame("Frame", nil, scrollFrame)
    PixelPerfect.Size(content, 1, 1, 1, 1)
    scrollFrame:SetScrollChild(content)

    self.unassignedContent = content
    self.unassignedRows = {}

    for i = 1, MAX_ROWS do
        self.unassignedRows[i] = CreateEntryRow(content, i)
    end

    -- Name input field + Add button at the bottom
    local addEditBox = CreateFrame("EditBox", nil, parent)
    addEditBox:SetMaxLetters(40)
    addon.StyleEditBox(addEditBox, "Character name")

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

    local addBtn = addon.CreateStyledButton(parent, ADD_BUTTON_WIDTH, ADD_CONTROL_HEIGHT, "Add")
    addBtn:SetScript("OnClick", function()
        local name = strtrim(addEditBox:GetText())
        if name ~= "" then
            addon:AddNameToGrid(addon:NormalizeName(name))
            addEditBox:SetText("")
        end
    end)

    PixelPerfect.RegisterLayout(parent, function()
        local parentWidth = parent:GetWidth()
        local rowHeight = PixelPerfect.Scale(content, ROW_HEIGHT)
        local minimumContentHeight = PixelPerfect.Scale(content, 1, 1)

        for tabIndex, mode in ipairs(TAB_MODES) do
            local tab = self.unassignedTabs[mode]
            local left = PixelPerfect.Scale(parent, parentWidth * (tabIndex - 1) / #TAB_MODES)
            local right = PixelPerfect.Scale(parent, parentWidth * tabIndex / #TAB_MODES)

            tab:ClearAllPoints()
            tab:SetSize(right - left, PixelPerfect.Scale(tab, TAB_HEIGHT))
            tab:SetPoint("TOPLEFT", parent, "TOPLEFT", left, 0)
        end

        local tabContentBottom = ADD_CONTROL_HEIGHT + UI_SPACING
        if self.unassignedMode == MODE_ROSTER then
            tabContentBottom = tabContentBottom + ADD_CONTROL_HEIGHT + TAB_FOOTER_GAP
        end

        scrollBg:ClearAllPoints()
        PixelPerfect.Point(scrollBg, "TOPLEFT", parent, "TOPLEFT", 0, -TAB_HEIGHT)
        PixelPerfect.Point(
            scrollBg,
            "BOTTOMRIGHT",
            parent,
            "BOTTOMRIGHT",
            0,
            tabContentBottom
        )

        importRosterBtn:ClearAllPoints()
        addon.SetStyledButtonSize(importRosterBtn, parentWidth, ADD_CONTROL_HEIGHT)
        PixelPerfect.Point(
            importRosterBtn,
            "BOTTOMLEFT",
            parent,
            "BOTTOMLEFT",
            0,
            ADD_CONTROL_HEIGHT + UI_SPACING
        )

        scrollFrame:ClearAllPoints()
        PixelPerfect.Point(scrollFrame, "TOPLEFT", scrollBg, "TOPLEFT", 2, -2)
        PixelPerfect.Point(scrollFrame, "BOTTOMRIGHT", scrollBg, "BOTTOMRIGHT", -22, 2)

        content:SetWidth(math.max(PixelPerfect.Scale(content, 1, 1), scrollFrame:GetWidth()))
        content:SetHeight(math.max(minimumContentHeight, (content.rgmEntryCount or 0) * rowHeight))

        for index = 1, MAX_ROWS do
            local row = self.unassignedRows[index]
            row:ClearAllPoints()
            row:SetHeight(rowHeight)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((index - 1) * rowHeight))
            row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

            row.roleIcon:ClearAllPoints()
            PixelPerfect.Size(row.roleIcon, ROLE_ICON_SIZE, ROLE_ICON_SIZE)
            PixelPerfect.Point(row.roleIcon, "RIGHT", row, "RIGHT", -2, 0)
        end

        addEditBox:ClearAllPoints()
        PixelPerfect.Point(addEditBox, "BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        PixelPerfect.Point(
            addEditBox,
            "BOTTOMRIGHT",
            parent,
            "BOTTOMRIGHT",
            -(ADD_BUTTON_WIDTH + UI_SPACING),
            0
        )
        PixelPerfect.Height(addEditBox, ADD_CONTROL_HEIGHT)

        addBtn:ClearAllPoints()
        PixelPerfect.Point(addBtn, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    end)
end

local function SetUnassignedContentHeight(entryCount)
    local content = addon.unassignedContent
    local rowHeight = PixelPerfect.Scale(content, ROW_HEIGHT)
    local minimumHeight = PixelPerfect.Scale(content, 1, 1)

    content.rgmEntryCount = entryCount
    content:SetHeight(math.max(minimumHeight, entryCount * rowHeight))
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
            SetRowLeadershipIconState(row, self:GetLeadershipIconTextureForRank(entry.rank))

            -- Class color
            local classColor = entry.class and C_ClassColor.GetClassColor(entry.class)
            if classColor then
                row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
                row.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, ROW_BG_ALPHA)
            else
                row.nameText:SetTextColor(0.5, 0.5, 0.5)
                row.bg:SetVertexColor(0.5, 0.5, 0.5, ROW_BG_ALPHA)
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
            SetRowLeaderState(row, false)
        end
    end

    SetUnassignedContentHeight(#entries)
end

function addon:RefreshUnassignedRoleMode()
    local entries = ClassSpecRoles:GetClassRoleCombos()

    for i = 1, MAX_ROWS do
        local row = self.unassignedRows[i]
        local entry = entries[i]

        if entry then
            row.nameText:SetText(entry.className)
            row.playerName = nil
            row.template = { class = entry.class, role = entry.role }
            SetRowLeaderState(row, false)

            -- Class color
            local classColor = C_ClassColor.GetClassColor(entry.class)
            if classColor then
                row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
                row.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, ROW_BG_ALPHA)
            else
                row.nameText:SetTextColor(0.5, 0.5, 0.5)
                row.bg:SetVertexColor(0.5, 0.5, 0.5, ROW_BG_ALPHA)
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
            SetRowLeaderState(row, false)
        end
    end

    SetUnassignedContentHeight(#entries)
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
    else
        self.importRosterBtn:Hide()
    end

    PixelPerfect.RequestRefresh()
end

function addon:RefreshUnassignedRosterMode()
    local roster = self.db.char.importedRoster or {}
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

    table.sort(entries, ClassSpecRoles.CompareRosterEntriesByRoleThenName)

    for i = 1, MAX_ROWS do
        local row = self.unassignedRows[i]
        local entry = entries[i]

        if entry then
            row.nameText:SetText(entry.normalizedName)
            row.playerName = entry.normalizedName
            row.template = nil
            SetRowLeaderState(row, self:IsRosterLeader(entry.normalizedName))

            local classColor = entry.class and C_ClassColor.GetClassColor(entry.class)
            if classColor then
                row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
                row.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, ROW_BG_ALPHA)
            else
                row.nameText:SetTextColor(0.5, 0.5, 0.5)
                row.bg:SetVertexColor(0.5, 0.5, 0.5, ROW_BG_ALPHA)
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
            SetRowLeaderState(row, false)
        end
    end

    SetUnassignedContentHeight(#entries)
end

--------------------------------------------------------------------------------
-- Roster import modal
--------------------------------------------------------------------------------

local WOWUTILS_ROSTER_URL = "https://wowutils.com/viserio-cooldowns/groups"
local ROSTER_IMPORT_FRAME_LEVEL = 100
local ROSTER_URL_FRAME_LEVEL = 110
local ROSTER_IMPORT_STEPS = {
    "Select the Group you wish to import from",
    "Click the 'v' dropdown in the top-right corner",
    "Select 'Export Roster JSON'",
    "Select the members you want to export",
    "Select 'Copy to Clipboard'",
    "Paste the roster JSON below",
}

local function CreateRosterImportInstructionLine(parent, text, yOffset)
    local line = parent:CreateFontString(nil, "ARTWORK")
    line:SetFont(FONT, 12, "OUTLINE")
    line:SetTextColor(0.9, 0.9, 0.9, 1)
    line:SetText(text)

    PixelPerfect.RegisterLayout(line, function()
        line:ClearAllPoints()
        PixelPerfect.Point(line, "TOPLEFT", parent, "TOPLEFT", UI_SPACING, yOffset)
    end)

    return line
end

function addon:ShowWowutilsRosterURLWindow()
    if self.wowutilsRosterURLFrame then
        self.wowutilsRosterURLFrame:SetFrameLevel(ROSTER_URL_FRAME_LEVEL)
        self.wowutilsRosterURLFrame:Show()
        self.wowutilsRosterURLEditBox:SetText(WOWUTILS_ROSTER_URL)
        self.wowutilsRosterURLEditBox:SetCursorPosition(0)
        self.wowutilsRosterURLEditBox:HighlightText()
        self.wowutilsRosterURLEditBox:SetFocus()

        return
    end

    local frame = addon.CreateWindowFrame("Wowutils URL", 430, 120, 0.98)

    local hint = frame:CreateFontString(nil, "ARTWORK")
    hint:SetFont(FONT, 12, "OUTLINE")
    hint:SetText("Press Ctrl+C to copy.")
    hint:SetTextColor(0.85, 0.85, 0.85, 1)

    local editBox = CreateFrame("EditBox", nil, frame)
    editBox:SetText(WOWUTILS_ROSTER_URL)
    editBox:SetScript("OnEscapePressed", function(eb)
        eb:ClearFocus()
        frame:Hide()
    end)
    editBox:SetScript("OnEditFocusGained", function(eb)
        eb:HighlightText()
    end)
    editBox:SetScript("OnKeyDown", function(eb, key)
        if IsControlKeyDown() and (key == "C" or key == "c") then
            C_Timer.After(0, function()
                if frame:IsShown() then
                    eb:ClearFocus()
                    frame:Hide()
                end
            end)
        end
    end)
    addon.StyleEditBox(editBox, "WowUtils roster URL")
    editBox:SetCursorPosition(0)

    self.wowutilsRosterURLFrame = frame
    self.wowutilsRosterURLEditBox = editBox

    PixelPerfect.RegisterLayout(frame, function()
        hint:ClearAllPoints()
        PixelPerfect.Point(hint, "TOPLEFT", frame, "TOPLEFT", UI_SPACING, -(addon.TITLE_HEIGHT + UI_SPACING))

        editBox:ClearAllPoints()
        PixelPerfect.Point(editBox, "TOPLEFT", hint, "BOTTOMLEFT", 0, -UI_SPACING)
        PixelPerfect.Point(editBox, "RIGHT", frame, "RIGHT", -UI_SPACING, 0)
        PixelPerfect.Height(editBox, 24)
    end)

    frame:SetFrameLevel(ROSTER_URL_FRAME_LEVEL)

    frame:Show()
    editBox:HighlightText()
    editBox:SetFocus()
end

function addon:ShowRosterImportWindow()
    if self.rosterImportFrame then
        self.rosterImportFrame:Show()
        self.rosterImportEditBox:SetText("")
        self.rosterImportEditBox:SetFocus()

        return
    end

    local frame, titleBar = addon.CreateWindowFrame("Import Roster from Wowutils via JSON", 580, 520)
    frame:SetFrameLevel(ROSTER_IMPORT_FRAME_LEVEL)
    frame:SetMovable(true)
    titleBar:EnableMouse(true)

    titleBar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)

    titleBar:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        PixelPerfect.SnapCurrentPoint(frame)
    end)

    local instructionTop = addon.TITLE_HEIGHT + UI_SPACING
    local instructionLineHeight = 17
    local instructionTextHeight = 12
    local firstLine = CreateRosterImportInstructionLine(frame, "1. Go to", -instructionTop)

    local urlText = frame:CreateFontString(nil, "ARTWORK")
    urlText:SetFont(FONT, 12, "OUTLINE")
    urlText:SetTextColor(0.45, 0.75, 1, 1)
    urlText:SetText(WOWUTILS_ROSTER_URL)

    local copyURLBtn = addon.CreateStyledButton(frame, 68, 20, "Copy URL")
    copyURLBtn.label:SetFont(FONT, 10, "OUTLINE")
    copyURLBtn:SetScript("OnClick", function()
        self:ShowWowutilsRosterURLWindow()
    end)

    for i, instruction in ipairs(ROSTER_IMPORT_STEPS) do
        local stepText = string.format("%d. %s", i + 1, instruction)
        CreateRosterImportInstructionLine(frame, stepText, -(instructionTop + (i * instructionLineHeight)))
    end

    -- Edit box area
    local editBg = CreateFrame("Frame", nil, frame)

    local scrollFrame = addon.CreateScrollFrame(editBg)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)

    editBox:SetScript("OnEscapePressed", function(eb)
        eb:ClearFocus()
    end)

    scrollFrame:SetScrollChild(editBox)
    addon.StyleEditBox(editBox, "Paste WowUtils roster JSON here", {
        multiline = true,
        surface = editBg,
    })
    scrollFrame:EnableMouse(true)

    scrollFrame:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    self.rosterImportEditBox = editBox
    self.rosterImportFrame = frame

    local importBtn = addon.CreateStyledButton(frame, 80, IMPORT_BUTTON_HEIGHT, "Import")
    importBtn:SetScript("OnClick", function()
        self:DoRosterImport()
    end)

    PixelPerfect.RegisterLayout(frame, function()
        local importFooterHeight = UI_SPACING + IMPORT_BUTTON_HEIGHT + UI_SPACING
        local editTopOffset = instructionTop
            + (#ROSTER_IMPORT_STEPS * instructionLineHeight)
            + instructionTextHeight
            + UI_SPACING

        urlText:ClearAllPoints()
        PixelPerfect.Point(urlText, "LEFT", firstLine, "RIGHT", 2, 0)

        copyURLBtn:ClearAllPoints()
        PixelPerfect.Point(copyURLBtn, "LEFT", urlText, "RIGHT", UI_SPACING, 0)

        editBg:ClearAllPoints()
        PixelPerfect.Point(editBg, "TOPLEFT", frame, "TOPLEFT", UI_SPACING, -editTopOffset)
        PixelPerfect.Point(editBg, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI_SPACING, importFooterHeight)

        scrollFrame:ClearAllPoints()
        PixelPerfect.Point(scrollFrame, "TOPLEFT", editBg, "TOPLEFT", 4, -4)
        PixelPerfect.Point(scrollFrame, "BOTTOMRIGHT", editBg, "BOTTOMRIGHT", -22, 4)
        editBox:SetWidth(math.max(PixelPerfect.Scale(editBox, 1, 1), scrollFrame:GetWidth()))

        importBtn:ClearAllPoints()
        PixelPerfect.Point(importBtn, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI_SPACING, UI_SPACING)
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

    self.db.char.importedRoster = roster
    self:Print("Imported " .. #roster .. " roster members.")
    self:RefreshUnassigned()

    if self.rosterImportFrame then
        self.rosterImportFrame:Hide()
    end
end
