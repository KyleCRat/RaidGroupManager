local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local FONT = addon.FONT
local ROLE_ICON_SIZE = 16
local ROW_HEIGHT = 20
local MAX_ROWS = 40

local ROLE_ATLAS = {
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps",
}

local MODE_RAID = 1
local MODE_GUILD = 2

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
    row:Hide()

    -- Drag into grid slots
    row:SetScript("OnDragStart", function(self)
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
                addon:DropNameOnSlot(i, addon.dragSourceName)
                ClearDragState()

                return
            end
        end

        ClearDragState()
    end)

    return row
end

function addon:CreateUnassignedPanel(parent)
    -- Header
    local headerText = parent:CreateFontString(nil, "ARTWORK")
    headerText:SetFont(FONT, 12, "OUTLINE")
    headerText:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -2)
    headerText:SetText("Unassigned")
    headerText:SetTextColor(1, 1, 1, 1)

    -- Mode toggle button
    local toggleBtn = self.CreateStyledButton(parent, 40, 16, "Raid")
    toggleBtn.label:SetFont(FONT, 10, "OUTLINE")
    toggleBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    self.unassignedMode = MODE_RAID

    toggleBtn:SetScript("OnClick", function(btn)
        if self.unassignedMode == MODE_RAID then
            self.unassignedMode = MODE_GUILD
            btn.label:SetText("Guild")
            C_GuildInfo.GuildRoster()
        else
            self.unassignedMode = MODE_RAID
            btn.label:SetText("Raid")
        end

        self:RefreshUnassigned()
    end)

    -- Dark background container for scroll area
    local scrollBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    scrollBg:SetPoint("TOPLEFT", 0, -20)
    scrollBg:SetPoint("BOTTOMRIGHT", 0, 30)
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

-- Build the set of names currently assigned in the grid
local function GetAssignedNames()
    local assigned = {}
    for i = 1, 40 do
        local text = addon:GetSlotText(i)
        if text ~= "" then
            assigned[text] = true
        end
    end

    return assigned
end

function addon:GetUnassignedRaidMembers()
    local assigned = GetAssignedNames()
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
    local assigned = GetAssignedNames()
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
            local atlas = ROLE_ATLAS[entry.role]
            if atlas then
                row.roleIcon:SetAtlas(atlas)
                row.roleIcon:Show()
            else
                row.roleIcon:Hide()
            end

            row:Show()
        else
            row:Hide()
            row.playerName = nil
        end
    end

    local totalHeight = math.max(1, #entries * ROW_HEIGHT)
    self.unassignedContent:SetHeight(totalHeight)
end
