local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local FONT = addon.FONT
local ROW_HEIGHT = 24
local MAX_LAYOUT_ROWS = 20

local dragSourceIndex = nil

local function CreateLayoutRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

    row.borderTex = row:CreateTexture(nil, "BORDER")
    row.borderTex:SetPoint("TOPLEFT", -1, 1)
    row.borderTex:SetPoint("BOTTOMRIGHT", 1, -1)
    row.borderTex:SetColorTexture(0, 0, 0, 1)

    row.nameText = row:CreateFontString(nil, "ARTWORK")
    row.nameText:SetFont(FONT, 12, "OUTLINE")
    row.nameText:SetPoint("LEFT", 4, 0)
    row.nameText:SetPoint("RIGHT", -24, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    row.nameText:SetTextColor(1, 1, 1, 1)

    -- Delete button
    local deleteBtn = addon.CreateStyledButton(row, 18, 18, "X")
    deleteBtn:SetPoint("RIGHT", -2, 0)
    deleteBtn.label:SetFont(FONT, 10, "OUTLINE")
    deleteBtn:SetScript("OnClick", function()
        if row.layoutIndex then
            addon:DeleteLayout(row.layoutIndex)
        end
    end)
    row.deleteBtn = deleteBtn

    -- Highlight for selected state
    row.selectedHighlight = row:CreateTexture(nil, "ARTWORK")
    row.selectedHighlight:SetAllPoints()
    row.selectedHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.3)
    row.selectedHighlight:SetBlendMode("ADD")
    row.selectedHighlight:Hide()

    -- Hover highlight
    row.hoverHighlight = row:CreateTexture(nil, "ARTWORK")
    row.hoverHighlight:SetAllPoints()
    row.hoverHighlight:SetColorTexture(0.2, 0.2, 0.2, 0.3)
    row.hoverHighlight:SetBlendMode("ADD")
    row.hoverHighlight:Hide()

    row.layoutIndex = nil

    -- Click to load
    row:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self.layoutIndex then
            addon:SelectAndLoadLayout(self.layoutIndex)
        end
    end)

    -- Tooltip
    row:SetScript("OnEnter", function(self)
        self.hoverHighlight:Show()
        if not self.layoutIndex then
            return
        end
        local layout = addon.db.profile.layouts[self.layoutIndex]
        if not layout then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(layout.name)
        GameTooltip:AddLine(date("%Y-%m-%d %H:%M", layout.time), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function(self)
        self.hoverHighlight:Hide()
        GameTooltip:Hide()
    end)

    -- Drag reorder
    row:SetScript("OnDragStart", function(self)
        if not self.layoutIndex then
            return
        end
        dragSourceIndex = self.layoutIndex
        self:SetAlpha(0.5)
    end)

    row:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)
        if not dragSourceIndex then
            return
        end

        -- Find target row
        local targetIndex = nil
        for i = 1, MAX_LAYOUT_ROWS do
            local r = addon.layoutRows[i]
            if r and r:IsMouseOver() and r.layoutIndex then
                targetIndex = r.layoutIndex

                break
            end
        end

        if targetIndex and targetIndex ~= dragSourceIndex then
            addon:ReorderLayout(dragSourceIndex, targetIndex)
        end

        dragSourceIndex = nil
    end)

    row:Hide()

    return row
end

function addon:CreateLayoutPanel(parent)
    local headerText = parent:CreateFontString(nil, "ARTWORK")
    headerText:SetFont(FONT, 12, "OUTLINE")
    headerText:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -2)
    headerText:SetText("Layouts")
    headerText:SetTextColor(1, 1, 1, 1)

    -- Auto-save checkbox
    local autoSaveCheck = CreateFrame("CheckButton", "RGMAutoSaveCheck", parent, "UICheckButtonTemplate")
    autoSaveCheck:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 2)
    autoSaveCheck:SetSize(20, 20)
    autoSaveCheck:SetChecked(false)

    local autoSaveLabel = parent:CreateFontString(nil, "ARTWORK")
    autoSaveLabel:SetFont(FONT, 10, "OUTLINE")
    autoSaveLabel:SetPoint("RIGHT", autoSaveCheck, "LEFT", -2, 0)
    autoSaveLabel:SetText("Auto-save")
    autoSaveLabel:SetTextColor(0.7, 0.7, 0.7, 1)

    autoSaveCheck:SetScript("OnClick", function(self)
        addon.autoSave = self:GetChecked()
    end)

    -- Scroll frame for layout list
    local scrollFrame = CreateFrame("ScrollFrame", "RGMLayoutScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -22)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(content)

    self.layoutContent = content
    self.layoutRows = {}

    for i = 1, MAX_LAYOUT_ROWS do
        self.layoutRows[i] = CreateLayoutRow(content, i)
    end

    self:RefreshLayoutList()
end

function addon:RefreshLayoutList()
    if not self.layoutRows then
        return
    end

    local layouts = self.db.profile.layouts
    -- Display newest first (reverse order)
    local displayOrder = {}
    for i = #layouts, 1, -1 do
        table.insert(displayOrder, i)
    end

    for i = 1, MAX_LAYOUT_ROWS do
        local row = self.layoutRows[i]
        local layoutIdx = displayOrder[i]

        if layoutIdx then
            local layout = layouts[layoutIdx]
            row.nameText:SetText(layout.name)
            row.layoutIndex = layoutIdx

            -- Selected state
            if self.selectedLayout == layout then
                row.selectedHighlight:Show()
            else
                row.selectedHighlight:Hide()
            end

            row:Show()
        else
            row:Hide()
            row.layoutIndex = nil
        end
    end

    local totalHeight = math.max(1, #layouts * ROW_HEIGHT)
    self.layoutContent:SetHeight(totalHeight)
end

function addon:SelectAndLoadLayout(layoutIndex)
    local layout = self.db.profile.layouts[layoutIndex]
    if not layout then
        return
    end

    self.selectedLayout = layout
    self:LoadLayoutToGrid(layout)
    self:RefreshLayoutList()
end

function addon:DeleteLayout(layoutIndex)
    local layout = self.db.profile.layouts[layoutIndex]
    if self.selectedLayout == layout then
        self.selectedLayout = nil
    end

    table.remove(self.db.profile.layouts, layoutIndex)
    self:RefreshLayoutList()
end

function addon:ReorderLayout(fromIndex, toIndex)
    local layouts = self.db.profile.layouts
    local layout = table.remove(layouts, fromIndex)
    table.insert(layouts, toIndex, layout)
    self:RefreshLayoutList()
end

-- Save prompt using StaticPopup
StaticPopupDialogs["RGM_SAVE_LAYOUT"] = {
    text = "Enter a name for this layout:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local name = self.editBox:GetText()
        if name and strtrim(name) ~= "" then
            addon:SaveNewLayout(strtrim(name))
        end
    end,
    OnShow = function(self)
        self.editBox:SetFocus()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function addon:PromptSaveLayout()
    StaticPopup_Show("RGM_SAVE_LAYOUT")
end

function addon:SaveNewLayout(name)
    local layout = {
        name = name,
        time = time(),
        slots = self:GetGridState(),
    }

    table.insert(self.db.profile.layouts, layout)
    self.selectedLayout = layout
    self:RefreshLayoutList()
    self:Print("Layout saved: " .. name)
end
