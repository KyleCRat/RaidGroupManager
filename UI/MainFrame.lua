local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 600
local TITLE_HEIGHT = addon.TITLE_HEIGHT
local FONT = addon.FONT
local BUTTON_HEIGHT = 24
local BUTTON_PADDING = 6
local BOTTOM_BAR_HEIGHT = 40

local GRID_WIDTH = 330
local UNASSIGNED_WIDTH = 140
local LAYOUT_WIDTH = 200

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

-- Create a styled button matching ReadyCheckConsumables pattern
local function CreateStyledButton(parent, width, height, label)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

    btn.border = btn:CreateTexture(nil, "BORDER")
    btn.border:SetPoint("TOPLEFT", -1, 1)
    btn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.border:SetColorTexture(0, 0, 0, 1)

    btn.highlight = btn:CreateTexture(nil, "ARTWORK")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    btn.highlight:SetBlendMode("ADD")
    btn.highlight:Hide()

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont(FONT, 12, "OUTLINE")
    btn.label:SetPoint("CENTER")
    btn.label:SetText(label)

    btn:SetScript("OnEnter", function(self)
        self.highlight:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        self.highlight:Hide()
    end)

    return btn
end

addon.CreateStyledButton = CreateStyledButton

function addon:CreateMainFrame()
    if self.mainFrame then
        return
    end

    local frame = CreateFrame("Frame", "RGMFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:SetMovable(true)
    frame:EnableMouse(true)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(TITLE_HEIGHT)
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
    titleBar.text:SetText("Raid Group Manager")
    titleBar.text:SetTextColor(1, 1, 1, 1)

    -- Close button — use Blizzard template so ElvUI can skin it
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    frame.titleBar = titleBar
    self.mainFrame = frame

    -- Content area starts below title bar
    local contentTop = -(TITLE_HEIGHT + 4)

    -- Helper text at top of body
    local helperText = frame:CreateFontString(nil, "ARTWORK")
    helperText:SetFont(FONT, 12, "OUTLINE")
    helperText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, contentTop)
    helperText:SetText("Drag slots to swap players")
    helperText:SetTextColor(0.5, 0.5, 0.5, 0.7)

    local gridTop = contentTop - 16

    -- Grid area (left)
    local gridArea = CreateFrame("Frame", nil, frame)
    gridArea:SetPoint("TOPLEFT", 10, gridTop)
    gridArea:SetSize(GRID_WIDTH, FRAME_HEIGHT - TITLE_HEIGHT - BOTTOM_BAR_HEIGHT - 32)
    frame.gridArea = gridArea

    -- Create grid slots
    self:CreateGrid(gridArea)

    -- Unassigned panel (center-right) — bottom aligns with grid
    local unassignedArea = CreateFrame("Frame", nil, frame)
    unassignedArea:SetPoint("TOPLEFT", gridArea, "TOPRIGHT", 10, 16)
    unassignedArea:SetPoint("BOTTOM", gridArea, "BOTTOM", 0, 0)
    unassignedArea:SetWidth(UNASSIGNED_WIDTH)
    frame.unassignedArea = unassignedArea

    self:CreateUnassignedPanel(unassignedArea)

    -- Layout panel (far right) — bottom aligns with grid
    local layoutArea = CreateFrame("Frame", nil, frame)
    layoutArea:SetPoint("TOPLEFT", unassignedArea, "TOPRIGHT", 10, 0)
    layoutArea:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    layoutArea:SetPoint("BOTTOM", gridArea, "BOTTOM", 0, 0)
    frame.layoutArea = layoutArea

    self:CreateLayoutPanel(layoutArea)

    -- Bottom button bar
    local bottomBar = CreateFrame("Frame", nil, frame)
    bottomBar:SetPoint("BOTTOMLEFT", 10, 8)
    bottomBar:SetPoint("BOTTOMRIGHT", -10, 8)
    bottomBar:SetHeight(BUTTON_HEIGHT)
    frame.bottomBar = bottomBar

    local btnLoadRoster = CreateStyledButton(bottomBar, 100, BUTTON_HEIGHT, "Load Roster")
    btnLoadRoster:SetPoint("LEFT")
    btnLoadRoster:SetScript("OnClick", function()
        self:LoadCurrentRoster()
    end)

    local btnApply = CreateStyledButton(bottomBar, 60, BUTTON_HEIGHT, "Apply")
    btnApply:SetPoint("LEFT", btnLoadRoster, "RIGHT", BUTTON_PADDING, 0)
    btnApply:SetScript("OnClick", function()
        self:StartApply()
    end)
    self.applyButton = btnApply

    local btnSave = CreateStyledButton(bottomBar, 50, BUTTON_HEIGHT, "Save")
    btnSave:SetPoint("LEFT", btnApply, "RIGHT", BUTTON_PADDING, 0)
    btnSave:SetScript("OnClick", function()
        self:PromptSaveLayout()
    end)

    local btnExport = CreateStyledButton(bottomBar, 55, BUTTON_HEIGHT, "Export")
    btnExport:SetPoint("LEFT", btnSave, "RIGHT", BUTTON_PADDING, 0)
    btnExport:SetScript("OnClick", function()
        self:ShowExportWindow()
    end)

    local btnImport = CreateStyledButton(bottomBar, 55, BUTTON_HEIGHT, "Import")
    btnImport:SetPoint("LEFT", btnExport, "RIGHT", BUTTON_PADDING, 0)
    btnImport:SetScript("OnClick", function()
        self:ShowImportWindow()
    end)
end

function addon:LoadCurrentRoster()
    if InCombatLockdown() then
        self:Print("Cannot load roster while in combat.")

        return
    end

    -- Clear all slots
    for i = 1, 40 do
        self:SetSlotText(i, "")
    end

    if not IsInRaid() then
        self:Print("Not in a raid group.")
        self:RefreshAllSlots()
        self:RefreshUnassigned()

        return
    end

    local groupCounts = {}
    for g = 1, 8 do
        groupCounts[g] = 0
    end

    local count = GetNumGroupMembers()
    for i = 1, count do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name and subgroup then
            local pos = groupCounts[subgroup] + 1
            if pos <= 5 then
                local slotIndex = (subgroup - 1) * 5 + pos
                self:SetSlotText(slotIndex, self:NormalizeName(name))
                groupCounts[subgroup] = pos
            end
        end
    end

    self:RefreshAllSlots()
    self:RefreshUnassigned()
    self:TryAutoSave()
end
