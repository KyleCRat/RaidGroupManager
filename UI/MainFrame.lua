local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")
local LibPopupSlider = LibStub("LibPopupSlider-1.0")
local PixelPerfect = addon.PixelPerfect

local FRAME_WIDTH = 700
local FRAME_INITIAL_HEIGHT = 600
local FRAME_SCALE_MIN = 50
local FRAME_SCALE_MAX = 150
local FRAME_SCALE_STEP = 5

local SCALE_BUTTON_WIDTH = 60
local SCALE_BUTTON_HEIGHT = 20

local TITLE_ICON_BUTTON_SIZE = 18
local TITLE_HEIGHT = addon.TITLE_HEIGHT
local UI_SPACING = addon.UI_SPACING

local FONT = addon.FONT

local BUTTON_HEIGHT = 24
local HELPER_TEXT_HEIGHT = 12
local BOTTOM_BUTTON_FONT_SIZE = 12
local BOTTOM_BUTTON_TEXT_PADDING = 6
local BOTTOM_BUTTON_TEXT_FIT_BUFFER = 6
local BOTTOM_BUTTON_MIN_WIDTH = 30

local UNASSIGNED_WIDTH = 180

local COLOR_BLACK = { r = 0, g = 0, b = 0, a = 1 }
local MAIN_BACKGROUND = { r = 0.05, g = 0.05, b = 0.05, a = 0.9 }
local TITLE_BACKGROUND = { r = 0, g = 0, b = 0, a = 0.2 }

local function CreateBottomBarButton(parent, label)
    local btn = addon.CreateStyledButton(parent, BOTTOM_BUTTON_MIN_WIDTH, BUTTON_HEIGHT, label)
    btn.label:SetFont(FONT, BOTTOM_BUTTON_FONT_SIZE, "OUTLINE")

    local textWidth = btn.label:GetStringWidth() or 0
    if btn.label.GetUnboundedStringWidth then
        textWidth = btn.label:GetUnboundedStringWidth() or textWidth
    end

    local width = math.max(BOTTOM_BUTTON_MIN_WIDTH, math.ceil(textWidth + (BOTTOM_BUTTON_TEXT_PADDING * 2) + BOTTOM_BUTTON_TEXT_FIT_BUFFER))
    addon.SetStyledButtonSize(btn, width, BUTTON_HEIGHT)
    btn.label:SetJustifyH("CENTER")
    btn.label:SetWordWrap(false)

    PixelPerfect.RegisterLayout(btn, function()
        btn.label:ClearAllPoints()
        PixelPerfect.Point(btn.label, "LEFT", btn, "LEFT", BOTTOM_BUTTON_TEXT_PADDING, 0)
        PixelPerfect.Point(btn.label, "RIGHT", btn, "RIGHT", -BOTTOM_BUTTON_TEXT_PADDING, 0)
    end)

    return btn
end

local function ClampScalePercent(value)
    if type(value) ~= "number" then
        return 100
    end

    if value < FRAME_SCALE_MIN then
        return FRAME_SCALE_MIN
    end

    if value > FRAME_SCALE_MAX then
        return FRAME_SCALE_MAX
    end

    return value
end

local function SnapScalePercent(value)
    value = ClampScalePercent(value)

    return math.floor(value / FRAME_SCALE_STEP + 0.5) * FRAME_SCALE_STEP
end

local function GetSavedScalePercent(owner)
    local scale = owner.db and owner.db.profile.frameScale
    if type(scale) ~= "number" then
        scale = 1
    end

    return SnapScalePercent(scale * 100)
end

local function SetScaleButtonText(button, value)
    button.label:SetText("Scale: " .. value .. "%")
end

local function CreateLeadershipHelpButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    PixelPerfect.RegisterLayout(btn, function()
        PixelPerfect.Size(btn, TITLE_ICON_BUTTON_SIZE, TITLE_ICON_BUTTON_SIZE)
    end)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexture(addon.LEADER_ICON_TEXTURE)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine("Leadership Controls")
        GameTooltip:AddLine("Middle-click subgroup slots or Raid rows to promote to assist or demote from assist.", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine("Middle-click Roster tab members to mark who should be assistant.", 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine("Those choices are saved and promoted during invites or while you are raid leader.", 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return btn
end

function addon:CreateMainFrame()
    if self.mainFrame then
        return
    end

    local frame = CreateFrame("Frame", "RGMFrame", UIParent)
    local initialScale = GetSavedScalePercent(self)
    frame:SetScale(initialScale / 100)
    frame.bg = PixelPerfect.CreateSurface(frame, MAIN_BACKGROUND, COLOR_BLACK, 1)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    PixelPerfect.Size(frame, FRAME_WIDTH, FRAME_INITIAL_HEIGHT)
    self:RestoreFramePosition(frame)

    frame:SetMovable(true)
    frame:EnableMouse(true)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    PixelPerfect.Point(titleBar, "TOPLEFT", frame, "TOPLEFT", 1, -1)
    PixelPerfect.Point(titleBar, "TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    PixelPerfect.Height(titleBar, TITLE_HEIGHT)
    titleBar:EnableMouse(true)

    titleBar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)

    titleBar:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        PixelPerfect.SnapCurrentPoint(frame)
        self:SaveFramePosition()
        PixelPerfect.RequestRefresh()
    end)

    titleBar.bg = PixelPerfect.CreateBackground(titleBar, TITLE_BACKGROUND)

    titleBar.text = titleBar:CreateFontString(nil, "ARTWORK")
    titleBar.text:SetFont(FONT, 16, "OUTLINE")
    titleBar.text:SetText("Raid Group Manager")
    titleBar.text:SetTextColor(1, 1, 1, 1)

    -- Close button
    local close = addon.CreateCloseButton(titleBar, frame)

    local scaleButton = addon.CreateStyledButton(titleBar, SCALE_BUTTON_WIDTH, SCALE_BUTTON_HEIGHT, "")
    scaleButton.label:SetFont(FONT, 10, "OUTLINE")
    SetScaleButtonText(scaleButton, initialScale)

    frame.scalePopup = LibPopupSlider:Create(scaleButton, {
        minValue = FRAME_SCALE_MIN,
        maxValue = FRAME_SCALE_MAX,
        step = FRAME_SCALE_STEP,
        label = "Scale",
        font = FONT,
        showBorder = false,
        formatValue = function(value)
            return value .. "%"
        end,
        onValueChanged = function(value)
            self.db.profile.frameScale = value / 100
            frame:SetScale(value / 100)
            SetScaleButtonText(scaleButton, value)
            PixelPerfect.RequestRefresh()
        end,
    })
    local scalePopup = frame.scalePopup
    scalePopup.rgmWidth = scalePopup:GetWidth()
    PixelPerfect.CreateBorder(scalePopup, 1, COLOR_BLACK)
    PixelPerfect.RegisterLayout(scalePopup, function()
        if not scalePopup.rgmHeight and scalePopup:GetHeight() > 0 then
            scalePopup.rgmHeight = scalePopup:GetHeight()
        end

        PixelPerfect.Width(scalePopup, scalePopup.rgmWidth)

        if scalePopup.rgmHeight then
            PixelPerfect.Height(scalePopup, scalePopup.rgmHeight)
        end

        if scalePopup:IsShown() then
            PixelPerfect.SnapCurrentPoint(scalePopup)
        end
    end)
    scalePopup:HookScript("OnShow", PixelPerfect.RequestRefresh)
    scalePopup:SetValue(initialScale, true)
    frame.scaleButton = scaleButton

    local leadershipHelp = CreateLeadershipHelpButton(titleBar)
    frame.leadershipHelpButton = leadershipHelp

    frame.titleBar = titleBar
    self.mainFrame = frame

    -- Content area starts below title bar
    local contentTop = -(TITLE_HEIGHT + UI_SPACING)

    -- Helper text at top of body
    local helperText = frame:CreateFontString(nil, "ARTWORK")
    helperText:SetFont(FONT, HELPER_TEXT_HEIGHT, "OUTLINE")
    helperText:SetText("Drag slots to swap players")
    helperText:SetTextColor(0.5, 0.5, 0.5, 0.7)

    local gridTop = contentTop - HELPER_TEXT_HEIGHT - UI_SPACING

    -- GridSlot.lua owns the snapped grid dimensions.
    local gridArea = CreateFrame("Frame", nil, frame)
    frame.gridArea = gridArea

    -- Create grid slots
    self:CreateGrid(gridArea)

    -- Panels span from helper text level to grid bottom
    -- Unassigned panel (center-right)
    local unassignedArea = CreateFrame("Frame", nil, frame)
    frame.unassignedArea = unassignedArea

    -- Layout panel (far right), bottom-aligned with the grid.
    local layoutArea = CreateFrame("Frame", nil, frame)
    frame.layoutArea = layoutArea

    -- Bottom button bar
    local bottomBar = CreateFrame("Frame", nil, frame)
    frame.bottomBar = bottomBar

    local function LayoutMainContent()
        PixelPerfect.Width(frame, FRAME_WIDTH)

        helperText:ClearAllPoints()
        PixelPerfect.Point(helperText, "TOPLEFT", frame, "TOPLEFT", UI_SPACING, contentTop)

        gridArea:ClearAllPoints()
        PixelPerfect.Point(gridArea, "TOPLEFT", frame, "TOPLEFT", UI_SPACING, gridTop)

        local sidePadding = PixelPerfect.Scale(frame, UI_SPACING)
        local columnGap = PixelPerfect.Scale(frame, UI_SPACING)
        local contentTopOffset = PixelPerfect.Scale(frame, contentTop)
        local unassignedWidth = PixelPerfect.Scale(unassignedArea, UNASSIGNED_WIDTH)

        unassignedArea:ClearAllPoints()
        unassignedArea:SetPoint(
            "TOPLEFT",
            frame,
            "TOPLEFT",
            sidePadding + gridArea:GetWidth() + columnGap,
            contentTopOffset
        )
        unassignedArea:SetPoint("BOTTOMLEFT", gridArea, "BOTTOMRIGHT", columnGap, 0)
        unassignedArea:SetWidth(unassignedWidth)

        layoutArea:ClearAllPoints()
        layoutArea:SetPoint("TOPLEFT", unassignedArea, "TOPRIGHT", columnGap, 0)
        layoutArea:SetPoint("BOTTOMLEFT", unassignedArea, "BOTTOMRIGHT", columnGap, 0)
        layoutArea:SetWidth(
            frame:GetWidth()
            - (sidePadding * 2)
            - gridArea:GetWidth()
            - (columnGap * 2)
            - unassignedWidth
        )

        local gridTopInset = -PixelPerfect.Scale(gridArea, gridTop)
        local bottomBarGap = PixelPerfect.Scale(bottomBar, UI_SPACING)
        local bottomBarHeight = PixelPerfect.Scale(bottomBar, BUTTON_HEIGHT)
        local bottomPadding = PixelPerfect.Scale(frame, UI_SPACING)

        bottomBar:ClearAllPoints()
        bottomBar:SetPoint("TOPLEFT", gridArea, "BOTTOMLEFT", 0, -bottomBarGap)
        bottomBar:SetSize(frame:GetWidth() - (sidePadding * 2), bottomBarHeight)

        frame:SetHeight(
            gridTopInset
            + gridArea:GetHeight()
            + bottomBarGap
            + bottomBarHeight
            + bottomPadding
        )
        self:RestoreFramePosition(frame)
    end

    LayoutMainContent()
    self:CreateUnassignedPanel(unassignedArea)
    self:CreateLayoutPanel(layoutArea)

    local btnLoadRoster = CreateBottomBarButton(bottomBar, "Load Roster")
    btnLoadRoster:SetScript("OnClick", function()
        self:LoadCurrentRoster()
    end)

    local btnApply = CreateBottomBarButton(bottomBar, "Apply")
    btnApply:SetScript("OnClick", function()
        self:StartApply()
    end)
    self.applyButton = btnApply

    local btnSave = CreateBottomBarButton(bottomBar, "Save")
    btnSave:SetScript("OnClick", function()
        self:PromptSaveLayout()
    end)

    local btnSplitOddEven = CreateBottomBarButton(bottomBar, "Split Odd/Even")
    btnSplitOddEven:SetScript("OnClick", function()
        self:SplitOddEven()
    end)

    local btnSplitHalves = CreateBottomBarButton(bottomBar, "Split Halves")
    btnSplitHalves:SetScript("OnClick", function()
        self:SplitHalves()
    end)

    local btnInvite = CreateBottomBarButton(bottomBar, "Invite")
    btnInvite:SetScript("OnClick", function()
        self:ShowInviteToGroupPopup()
    end)

    local btnDisband = CreateBottomBarButton(bottomBar, "Disband")
    btnDisband:SetScript("OnClick", function()
        self:PromptDisbandRaid()
    end)

    local btnImport = CreateBottomBarButton(bottomBar, "Import")
    btnImport:SetScript("OnClick", function()
        self:ShowImportWindow()
    end)

    local btnExport = CreateBottomBarButton(bottomBar, "Export")
    btnExport:SetScript("OnClick", function()
        self:ShowExportWindow()
    end)

    PixelPerfect.RegisterLayout(frame, function()
        titleBar:ClearAllPoints()
        PixelPerfect.Point(titleBar, "TOPLEFT", frame, "TOPLEFT", 1, -1)
        PixelPerfect.Point(titleBar, "TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        PixelPerfect.Height(titleBar, TITLE_HEIGHT)

        titleBar.text:ClearAllPoints()
        PixelPerfect.Point(titleBar.text, "LEFT", titleBar, "LEFT", UI_SPACING, 0)

        close:ClearAllPoints()
        PixelPerfect.Point(close, "RIGHT", titleBar, "RIGHT", -UI_SPACING, 1)

        scaleButton:ClearAllPoints()
        PixelPerfect.Point(scaleButton, "RIGHT", close, "LEFT", -UI_SPACING, 0)

        leadershipHelp:ClearAllPoints()
        PixelPerfect.Point(leadershipHelp, "RIGHT", scaleButton, "LEFT", -UI_SPACING, 0)

        LayoutMainContent()

        btnLoadRoster:ClearAllPoints()
        PixelPerfect.Point(btnLoadRoster, "LEFT", bottomBar, "LEFT", 0, 0)
        btnApply:ClearAllPoints()
        PixelPerfect.Point(btnApply, "LEFT", btnLoadRoster, "RIGHT", UI_SPACING, 0)
        btnSave:ClearAllPoints()
        PixelPerfect.Point(btnSave, "LEFT", btnApply, "RIGHT", UI_SPACING, 0)
        btnSplitOddEven:ClearAllPoints()
        PixelPerfect.Point(btnSplitOddEven, "LEFT", btnSave, "RIGHT", UI_SPACING, 0)
        btnSplitHalves:ClearAllPoints()
        PixelPerfect.Point(btnSplitHalves, "LEFT", btnSplitOddEven, "RIGHT", UI_SPACING, 0)
        btnInvite:ClearAllPoints()
        PixelPerfect.Point(btnInvite, "LEFT", btnSplitHalves, "RIGHT", UI_SPACING, 0)
        btnDisband:ClearAllPoints()
        PixelPerfect.Point(btnDisband, "LEFT", btnInvite, "RIGHT", UI_SPACING, 0)

        btnImport:ClearAllPoints()
        PixelPerfect.Point(btnImport, "RIGHT", bottomBar, "RIGHT", 0, 0)
        btnExport:ClearAllPoints()
        PixelPerfect.Point(btnExport, "RIGHT", btnImport, "LEFT", -UI_SPACING, 0)
    end)

    frame:HookScript("OnShow", PixelPerfect.RequestRefresh)
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

    for i = 1, 40 do
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

function addon:ShowToast(message)
    local frame = self.mainFrame
    if not frame then
        return
    end

    if not frame.toast then
        local toast = frame:CreateFontString(nil, "OVERLAY")
        toast:SetFont(FONT, 14, "OUTLINE")
        PixelPerfect.Point(toast, "TOP", frame, "BOTTOM", 0, -4)
        toast:SetTextColor(1, 0.2, 0.2, 1)
        frame.toast = toast
    end

    local toast = frame.toast
    toast:SetText(message)
    toast:SetAlpha(1)
    toast:Show()

    if toast.fadeTimer then
        toast.fadeTimer:Cancel()
    end

    toast.fadeTimer = C_Timer.NewTimer(1.5, function()
        toast:Hide()
        toast.fadeTimer = nil
    end)
end

function addon:SaveFramePosition()
    local point, _, relPoint, x, y = self.mainFrame:GetPoint()
    self.db.profile.framePosition = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y,
    }
end

function addon:RestoreFramePosition(frame)
    local pos = self.db.profile.framePosition
    frame:ClearAllPoints()

    if pos then
        PixelPerfect.Point(frame, pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        PixelPerfect.Point(frame, "CENTER", UIParent, "CENTER", 0, 0)
    end
end
