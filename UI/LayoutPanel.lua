local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local PixelPerfect = addon.PixelPerfect
local FONT = addon.FONT
local ROW_HEIGHT = 24
local HEADER_HEIGHT = addon.MODERN_CHECKBOX_SIZE
local PANEL_BG_COLOR = addon.PANEL_BG_COLOR
local COLOR_BLACK = { r = 0, g = 0, b = 0, a = 1 }
local ROW_BACKGROUND = { r = 0.15, g = 0.15, b = 0.15, a = 0.9 }
local ADD_ROW_BACKGROUND = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }

local dragSourceIndex = nil

local function IsValidLayoutId(layoutId)
    return type(layoutId) == "number"
        and layoutId >= 1
        and layoutId == math.floor(layoutId)
end

local function CopyLayoutSlots(slots)
    local copy = {}

    for slotIndex = 1, 40 do
        copy[slotIndex] = slots and slots[slotIndex] or ""
    end

    return copy
end

function addon:FindLayoutById(layoutId)
    if not IsValidLayoutId(layoutId) then
        return nil
    end

    for _, layout in ipairs(self.db.profile.layouts) do
        if layout.id == layoutId then
            return layout
        end
    end

    return nil
end

function addon:InitializeLayoutState()
    local profile = self.db.profile
    local usedIds = {}
    local layoutsNeedingIds = {}
    local nextLayoutId = profile.nextLayoutId

    if not IsValidLayoutId(nextLayoutId) then
        nextLayoutId = 1
    end

    for _, layout in ipairs(profile.layouts) do
        local layoutId = layout.id

        if IsValidLayoutId(layoutId) and not usedIds[layoutId] then
            usedIds[layoutId] = true
            nextLayoutId = math.max(nextLayoutId, layoutId + 1)
        else
            layoutsNeedingIds[#layoutsNeedingIds + 1] = layout
        end
    end

    for _, layout in ipairs(layoutsNeedingIds) do
        while usedIds[nextLayoutId] do
            nextLayoutId = nextLayoutId + 1
        end

        layout.id = nextLayoutId
        usedIds[nextLayoutId] = true
        nextLayoutId = nextLayoutId + 1
    end

    profile.nextLayoutId = nextLayoutId
    self.selectedLayout = self:FindLayoutById(profile.selectedLayoutId)

    if not self.selectedLayout then
        profile.selectedLayoutId = nil
    end
end

function addon:AllocateLayoutId()
    local profile = self.db.profile
    local layoutId = profile.nextLayoutId

    if not IsValidLayoutId(layoutId) then
        layoutId = 1
    end

    while self:FindLayoutById(layoutId) do
        layoutId = layoutId + 1
    end

    profile.nextLayoutId = layoutId + 1

    return layoutId
end

function addon:CreateLayoutRecord(name, slots, insertIndex)
    local trimmedName = strtrim(name or "")

    if trimmedName == "" then
        return nil, "empty"
    end

    if self:FindLayoutByName(trimmedName) then
        return nil, "duplicate"
    end

    local layout = {
        id = self:AllocateLayoutId(),
        name = trimmedName,
        time = time(),
        slots = CopyLayoutSlots(slots),
    }

    if insertIndex then
        table.insert(self.db.profile.layouts, insertIndex, layout)
    else
        table.insert(self.db.profile.layouts, layout)
    end

    return layout
end

function addon:SetSelectedLayout(layout)
    self.selectedLayout = layout
    self.db.profile.selectedLayoutId = layout and layout.id or nil
    self:RefreshLayoutList()
    self:RefreshLayoutHeader()
end

local function RefreshLayoutRowTooltip(row)
    if not row.layoutIndex then
        addon:HideTooltip(row)

        return
    end

    local layout = addon.db.profile.layouts[row.layoutIndex]
    if not layout then
        addon:HideTooltip(row)

        return
    end

    local lines = {}

    if layout.time then
        lines[#lines + 1] = date("%Y-%m-%d %H:%M", layout.time)
    end

    if addon.selectedLayout == layout then
        lines[#lines + 1] = "Click again to deselect. The board stays unchanged."
    else
        lines[#lines + 1] = "Click to load and select."
    end

    lines[#lines + 1] = "Drag to reorder."
    addon:ShowTooltip(row, layout.name, lines, "ANCHOR_RIGHT")
end

local function CreateLayoutRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")
    row:RegisterForDrag("LeftButton")

    row.bg = PixelPerfect.CreateBackground(row, ROW_BACKGROUND)
    PixelPerfect.CreateBorder(row, 1, COLOR_BLACK)

    row.nameText = row:CreateFontString(nil, "ARTWORK")
    row.nameText:SetFont(FONT, 12, "OUTLINE")
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    row.nameText:SetTextColor(1, 1, 1, 1)

    local deleteBtn = CreateFrame("Button", nil, row)
    deleteBtn.icon = deleteBtn:CreateTexture(nil, "ARTWORK")
    deleteBtn.icon:SetAllPoints()
    deleteBtn.icon:SetTexture("Interface\\AddOns\\RaidGroupManager\\Media\\Textures\\Close")
    deleteBtn.icon:SetVertexColor(0.7, 0.7, 0.7, 1)

    deleteBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1)
        addon:ShowTooltip(self, nil, "Delete this saved layout.", "ANCHOR_RIGHT")
    end)

    deleteBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.7, 0.7, 0.7, 1)
        addon:HideTooltip(self)

        if row:IsMouseOver() then
            RefreshLayoutRowTooltip(row)
        end
    end)

    deleteBtn:SetScript("OnClick", function()
        if row.layoutIndex then
            addon:PromptDeleteLayout(row.layoutIndex)
        end
    end)
    row.deleteBtn = deleteBtn

    row.selectedHighlight = row:CreateTexture(nil, "ARTWORK")
    row.selectedHighlight:SetAllPoints()
    row.selectedHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)
    PixelPerfect.DisablePixelSnap(row.selectedHighlight)
    row.selectedHighlight:SetBlendMode("ADD")
    row.selectedHighlight:Hide()

    row.hoverHighlight = row:CreateTexture(nil, "ARTWORK")
    row.hoverHighlight:SetAllPoints()
    row.hoverHighlight:SetColorTexture(0.2, 0.2, 0.2, 0.3)
    PixelPerfect.DisablePixelSnap(row.hoverHighlight)
    row.hoverHighlight:SetBlendMode("ADD")
    row.hoverHighlight:Hide()

    row:SetScript("OnClick", function(self, button)
        if self.rgmWasDragged then
            self.rgmWasDragged = false

            return
        end

        if button == "LeftButton" and self.layoutIndex then
            addon:SelectAndLoadLayout(self.layoutIndex)
        end
    end)

    row:SetScript("OnEnter", function(self)
        self.hoverHighlight:Show()
        RefreshLayoutRowTooltip(self)
    end)

    row:SetScript("OnLeave", function(self)
        self.hoverHighlight:Hide()
        addon:HideTooltip(self)
    end)

    row:SetScript("OnDragStart", function(self)
        if not self.layoutIndex then
            return
        end

        self.rgmWasDragged = true
        dragSourceIndex = self.layoutIndex
        self:SetAlpha(0.5)
    end)

    row:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)

        if not dragSourceIndex then
            return
        end

        local targetIndex = nil

        for _, candidate in ipairs(addon.layoutRows) do
            if candidate:IsShown() and candidate:IsMouseOver() and candidate.layoutIndex then
                targetIndex = candidate.layoutIndex

                break
            end
        end

        if targetIndex and targetIndex ~= dragSourceIndex then
            addon:ReorderLayout(dragSourceIndex, targetIndex)
        end

        dragSourceIndex = nil

        C_Timer.After(0, function()
            self.rgmWasDragged = false
        end)
    end)

    row:Hide()

    return row
end

local function CreateAddLayoutRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.bg = PixelPerfect.CreateBackground(row, ADD_ROW_BACKGROUND)
    PixelPerfect.CreateBorder(row, 1, COLOR_BLACK)

    row.nameText = row:CreateFontString(nil, "ARTWORK")
    row.nameText:SetFont(FONT, 12, "OUTLINE")
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    row.nameText:SetText("+ New Blank Layout")
    row.nameText:SetTextColor(0.75, 0.75, 0.75, 1)

    row.highlight = PixelPerfect.CreateBackground(row, {
        r = 0.3,
        g = 0.3,
        b = 0.3,
        a = 0.35,
    }, "ARTWORK")
    row.highlight:SetBlendMode("ADD")
    row.highlight:Hide()

    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        self.nameText:SetTextColor(1, 1, 1, 1)
    end)

    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        self.nameText:SetTextColor(0.75, 0.75, 0.75, 1)
    end)

    row:SetScript("OnClick", function()
        addon:PromptCreateBlankLayout()
    end)

    return row
end

local function PositionLayoutRow(row, displayIndex, rowHeight)
    row:ClearAllPoints()
    row:SetHeight(rowHeight)
    row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 0, -((displayIndex - 1) * rowHeight))
    row:SetPoint("RIGHT", row:GetParent(), "RIGHT", 0, 0)

    row.nameText:ClearAllPoints()
    PixelPerfect.Point(row.nameText, "LEFT", row, "LEFT", 4, 0)

    if row.deleteBtn then
        PixelPerfect.Point(row.nameText, "RIGHT", row, "RIGHT", -22, 0)

        row.deleteBtn:ClearAllPoints()
        PixelPerfect.Size(row.deleteBtn, 14, 14)
        PixelPerfect.Point(row.deleteBtn, "RIGHT", row, "RIGHT", -4, 0)
    else
        PixelPerfect.Point(row.nameText, "RIGHT", row, "RIGHT", -4, 0)
    end
end

function addon:CreateLayoutPanel(parent)
    local header = CreateFrame("Frame", nil, parent)

    local headerText = header:CreateFontString(nil, "ARTWORK")
    headerText:SetFont(FONT, 12, "OUTLINE")
    headerText:SetText("Layouts")
    headerText:SetTextColor(1, 1, 1, 1)

    local autoSaveCheck = addon.CreateModernCheckbox(header, "Auto-save", {
        fontSize = 10,
        labelSide = "LEFT",
        onChanged = function(checked)
            addon.autoSave = checked
        end,
    })
    autoSaveCheck:SetChecked(self.autoSave == true)
    addon.AttachSimpleTooltip(
        autoSaveCheck,
        "Automatically save board changes to the selected layout."
    )
    self.layoutAutoSaveCheck = autoSaveCheck

    local scrollBg = CreateFrame("Frame", nil, parent)
    PixelPerfect.CreateSurface(scrollBg, PANEL_BG_COLOR, COLOR_BLACK, 1)

    local scrollFrame = addon.CreateScrollFrame(scrollBg, "RGMLayoutScroll")

    local content = CreateFrame("Frame", nil, scrollFrame)
    PixelPerfect.Size(content, 1, 1, 1, 1)
    scrollFrame:SetScrollChild(content)

    self.layoutContent = content
    self.layoutRows = {}
    self.addLayoutRow = CreateAddLayoutRow(content)

    PixelPerfect.RegisterLayout(parent, function()
        local rowHeight = PixelPerfect.Scale(content, ROW_HEIGHT)

        header:ClearAllPoints()
        PixelPerfect.Point(header, "TOPLEFT", parent, "TOPLEFT", 0, 0)
        PixelPerfect.Point(header, "TOPRIGHT", parent, "TOPRIGHT", 0, 0)
        PixelPerfect.Height(header, HEADER_HEIGHT)

        headerText:ClearAllPoints()
        PixelPerfect.Point(headerText, "LEFT", header, "LEFT", 0, 0)

        autoSaveCheck:ClearAllPoints()
        PixelPerfect.Point(autoSaveCheck, "RIGHT", header, "RIGHT", 0, 0)

        scrollBg:ClearAllPoints()
        PixelPerfect.Point(scrollBg, "TOPLEFT", header, "BOTTOMLEFT", 0, 0)
        PixelPerfect.Point(scrollBg, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

        scrollFrame:ClearAllPoints()
        PixelPerfect.Point(scrollFrame, "TOPLEFT", scrollBg, "TOPLEFT", 2, -2)
        PixelPerfect.Point(scrollFrame, "BOTTOMRIGHT", scrollBg, "BOTTOMRIGHT", -22, 2)
        content:SetWidth(math.max(PixelPerfect.Scale(content, 1, 1), scrollFrame:GetWidth()))
        content:SetHeight(math.max(
            PixelPerfect.Scale(content, 1, 1),
            (content.rgmRowCount or 1) * rowHeight
        ))

        local layoutCount = #self.db.profile.layouts

        for displayIndex = 1, layoutCount do
            local row = self.layoutRows[displayIndex]

            if row then
                PositionLayoutRow(row, displayIndex, rowHeight)
            end
        end

        PositionLayoutRow(self.addLayoutRow, layoutCount + 1, rowHeight)
    end)

    self:RefreshLayoutList()
end

function addon:RefreshLayoutList()
    if not self.layoutRows then
        return
    end

    local layouts = self.db.profile.layouts
    local layoutCount = #layouts

    for displayIndex = 1, layoutCount do
        local row = self.layoutRows[displayIndex]
        if not row then
            row = CreateLayoutRow(self.layoutContent)
            self.layoutRows[displayIndex] = row
        end

        local layoutIndex = layoutCount - displayIndex + 1
        local layout = layouts[layoutIndex]
        row.nameText:SetText(layout.name)
        row.layoutIndex = layoutIndex
        row:SetAlpha(1)
        row.selectedHighlight:SetShown(self.selectedLayout == layout)
        row:Show()

        if GameTooltip:IsOwned(row) then
            RefreshLayoutRowTooltip(row)
        end
    end

    for displayIndex = layoutCount + 1, #self.layoutRows do
        local row = self.layoutRows[displayIndex]

        if GameTooltip:IsOwned(row) then
            addon:HideTooltip(row)
        end

        row:Hide()
        row.layoutIndex = nil
        row.selectedHighlight:Hide()
    end

    local rowHeight = PixelPerfect.Scale(self.layoutContent, ROW_HEIGHT)
    local minimumHeight = PixelPerfect.Scale(self.layoutContent, 1, 1)
    local rowCount = layoutCount + 1

    self.layoutContent.rgmRowCount = rowCount
    self.layoutContent:SetHeight(math.max(minimumHeight, rowCount * rowHeight))

    for displayIndex = 1, layoutCount do
        PositionLayoutRow(self.layoutRows[displayIndex], displayIndex, rowHeight)
    end

    PositionLayoutRow(self.addLayoutRow, rowCount, rowHeight)
    self.addLayoutRow:Show()

    self.layoutAutoSaveCheck:SetChecked(self.autoSave == true)
    addon.SetModernCheckboxEnabled(self.layoutAutoSaveCheck, self.selectedLayout ~= nil)
    PixelPerfect.RequestRefresh()
end

function addon:SelectAndLoadLayout(layoutIndex)
    local layout = self.db.profile.layouts[layoutIndex]
    if not layout then
        return
    end

    if self.selectedLayout == layout then
        self:SetSelectedLayout(nil)

        return
    end

    self:SetSelectedLayout(layout)
    self:LoadLayoutToGrid(layout)
end

function addon:DeleteLayoutById(layoutId)
    local layout = self:FindLayoutById(layoutId)
    if not layout then
        return
    end

    local layoutIndex = nil

    for index, candidate in ipairs(self.db.profile.layouts) do
        if candidate == layout then
            layoutIndex = index

            break
        end
    end

    if not layoutIndex then
        return
    end

    local wasSelected = self.selectedLayout == layout
    table.remove(self.db.profile.layouts, layoutIndex)

    if wasSelected then
        self:SetSelectedLayout(nil)
    else
        self:RefreshLayoutList()
    end
end

function addon:ReorderLayout(fromIndex, toIndex)
    local layouts = self.db.profile.layouts
    local layout = table.remove(layouts, fromIndex)

    if not layout then
        return
    end

    table.insert(layouts, toIndex, layout)
    self:RefreshLayoutList()
end

function addon:ReportLayoutCreationError(name, reason)
    if reason == "duplicate" then
        addon:Print("A layout named " .. name .. " already exists.")
    else
        addon:Print("Enter a layout name.")
    end
end

StaticPopupDialogs["RGM_DELETE_LAYOUT"] = {
    text = "Delete layout '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(_, layoutId)
        addon:DeleteLayoutById(layoutId)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["RGM_SAVE_LAYOUT_AS"] = {
    text = "Enter a name for a copy of the current board:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local name = strtrim(self.EditBox:GetText() or "")

        if name ~= "" then
            addon:SaveCurrentLayoutAs(name)
        end
    end,
    OnShow = function(self)
        self.EditBox:SetText("")
        addon.SetEditBoxPlaceholder(self.EditBox, "Layout name")
        self.EditBox:SetFocus()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["RGM_NAME_BLANK_LAYOUT"] = {
    text = "Enter a name for the new blank layout:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local name = strtrim(self.EditBox:GetText() or "")

        if name ~= "" then
            addon:CreateBlankLayout(name)
        end
    end,
    OnShow = function(self)
        self.EditBox:SetText("")
        addon.SetEditBoxPlaceholder(self.EditBox, "Layout name")
        self.EditBox:SetFocus()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["RGM_CONFIRM_BLANK_LAYOUT"] = {
    text = "Create a new blank layout? This clears the current board.",
    button1 = "Continue",
    button2 = "Cancel",
    OnAccept = function()
        C_Timer.After(0, function()
            StaticPopup_Show("RGM_NAME_BLANK_LAYOUT")
        end)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["RGM_CLEAR_LAYOUT_BOARD"] = {
    text = "%s",
    button1 = "Clear",
    button2 = "Cancel",
    OnAccept = function()
        addon:ClearGrid()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function addon:PromptSaveLayoutAs()
    StaticPopup_Show("RGM_SAVE_LAYOUT_AS")
end

function addon:PromptDeleteLayout(layoutIndex)
    local layout = self.db.profile.layouts[layoutIndex]
    if not layout then
        return
    end

    StaticPopup_Show("RGM_DELETE_LAYOUT", layout.name, nil, layout.id)
end

function addon:SaveCurrentLayoutAs(name)
    local layout, reason = self:CreateLayoutRecord(name, self:GetGridState())
    if not layout then
        self:ReportLayoutCreationError(name, reason)

        return
    end

    self:SetSelectedLayout(layout)
    self:Print("Layout saved as: " .. layout.name)
end

function addon:SaveSelectedLayout()
    if not self:SaveToSelectedLayout() then
        return
    end

    self:RefreshLayoutList()
    self:RefreshLayoutHeader()
    self:Print("Layout saved: " .. self.selectedLayout.name)
end

function addon:PromptCreateBlankLayout()
    if self:IsGridEmpty() then
        StaticPopup_Show("RGM_NAME_BLANK_LAYOUT")
    else
        StaticPopup_Show("RGM_CONFIRM_BLANK_LAYOUT")
    end
end

function addon:CreateBlankLayout(name)
    local layout, reason = self:CreateLayoutRecord(name, nil)
    if not layout then
        self:ReportLayoutCreationError(name, reason)

        return
    end

    self:SetSelectedLayout(layout)
    self:LoadLayoutToGrid(layout)
    self:Print("Blank layout created: " .. layout.name)
end

function addon:PromptClearGrid()
    if self:IsGridEmpty() then
        return
    end

    local message = "Clear all group slots from the board?"

    if self.autoSave and self.selectedLayout then
        message = "Clear all group slots and save the empty board to '"
            .. self.selectedLayout.name
            .. "'?"
    end

    StaticPopup_Show("RGM_CLEAR_LAYOUT_BOARD", message)
end
