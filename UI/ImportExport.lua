local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local FONT = addon.FONT

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local FORMAT_PAIRED = 1
local FORMAT_HORIZONTAL = 2
local FORMAT_VERTICAL = 3
local FORMAT_ENCODED = 4

local formatNames = {
    [FORMAT_PAIRED] = "Paired Columns",
    [FORMAT_HORIZONTAL] = "Horizontal",
    [FORMAT_VERTICAL] = "Vertical",
    [FORMAT_ENCODED] = "Encoded String",
}

-- Export formatting functions

local function ExportPaired(slots)
    local lines = {}
    -- Groups 1&2, 3&4, 5&6, 7&8
    for pair = 0, 3 do
        local g1 = pair * 2 + 1
        local g2 = pair * 2 + 2
        for p = 1, 5 do
            local name1 = slots[(g1 - 1) * 5 + p] or ""
            local name2 = slots[(g2 - 1) * 5 + p] or ""
            table.insert(lines, name1 .. "\t" .. name2)
        end
        if pair < 3 then
            table.insert(lines, "")
        end
    end

    return table.concat(lines, "\n")
end

local function ExportHorizontal(slots)
    local lines = {}
    -- 5 rows, 8 columns (each column = a group)
    for p = 1, 5 do
        local cols = {}
        for g = 1, 8 do
            local name = slots[(g - 1) * 5 + p] or ""
            table.insert(cols, name)
        end
        table.insert(lines, table.concat(cols, "\t"))
    end

    return table.concat(lines, "\n")
end

local function ExportVertical(slots)
    local lines = {}
    for g = 1, 8 do
        for p = 1, 5 do
            local name = slots[(g - 1) * 5 + p] or ""
            table.insert(lines, name)
        end
        if g < 8 then
            table.insert(lines, "")
        end
    end

    return table.concat(lines, "\n")
end

local function ExportEncoded(slots)
    local serialized = addon:Serialize(slots)

    return "RGM1" .. serialized
end

-- Import parsing functions

local function SplitLines(text)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    return lines
end

local function SplitTabs(line)
    local parts = {}
    for part in line:gmatch("[^\t]+") do
        table.insert(parts, strtrim(part))
    end

    return parts
end

local function TryImportEncoded(text)
    if not text:find("^RGM1") then
        return nil
    end

    local data = text:sub(5)
    local success, slots = addon:Deserialize(data)
    if not success then
        return nil
    end

    if type(slots) ~= "table" then
        return nil
    end

    -- Normalize to 40-slot table
    local result = {}
    for i = 1, 40 do
        result[i] = slots[i] or ""
    end

    return result
end

local function TryImportText(text)
    local lines = SplitLines(text)
    if #lines == 0 then
        return nil
    end

    -- Detect format by structure
    local firstLineParts = SplitTabs(lines[1])

    -- Horizontal: 5 lines with 8 tab-separated columns
    if #lines >= 5 and #firstLineParts >= 8 then
        local slots = {}
        for p = 1, 5 do
            local parts = SplitTabs(lines[p])
            for g = 1, 8 do
                slots[(g - 1) * 5 + p] = parts[g] or ""
            end
        end

        return slots
    end

    -- Paired: lines with 2 tab-separated columns, groups of 5
    if #firstLineParts == 2 then
        local slots = {}
        local nameLines = {}
        for _, line in ipairs(lines) do
            local trimmed = strtrim(line)
            if trimmed ~= "" then
                table.insert(nameLines, trimmed)
            end
        end

        if #nameLines >= 20 then
            for pair = 0, 3 do
                local g1 = pair * 2 + 1
                local g2 = pair * 2 + 2
                for p = 1, 5 do
                    local lineIdx = pair * 5 + p
                    local parts = SplitTabs(nameLines[lineIdx])
                    slots[(g1 - 1) * 5 + p] = parts[1] or ""
                    slots[(g2 - 1) * 5 + p] = parts[2] or ""
                end
            end

            return slots
        end
    end

    -- Vertical: one name per line, groups of 5
    local allNames = {}
    for _, line in ipairs(lines) do
        local trimmed = strtrim(line)
        if trimmed ~= "" then
            table.insert(allNames, trimmed)
        end
    end

    if #allNames >= 1 then
        local slots = {}
        for i = 1, math.min(40, #allNames) do
            slots[i] = allNames[i]
        end

        -- Fill remaining
        for i = #allNames + 1, 40 do
            slots[i] = ""
        end

        return slots
    end

    return nil
end

-- Modal window creation

local function CreateModalFrame(title, width, height)
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)

    -- Title bar
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
    titleBar.text:SetText(title)
    titleBar.text:SetTextColor(1, 1, 1, 1)

    local close = addon.CreateStyledButton(titleBar, 20, 20, "X")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    return frame
end

local function CreateMultiLineEditBox(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -(addon.TITLE_HEIGHT + 10))
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(FONT, 12, "OUTLINE")
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    scrollFrame:SetScrollChild(editBox)

    return scrollFrame, editBox
end

-- Export window

function addon:ShowExportWindow()
    if self.exportFrame then
        self.exportFrame:Show()
        self:UpdateExportText()

        return
    end

    local frame = CreateModalFrame("Export Layout", 500, 400)
    self.exportFrame = frame
    self.exportFormat = FORMAT_PAIRED

    -- Format radio buttons
    local prevBtn = nil
    for fmt = FORMAT_PAIRED, FORMAT_ENCODED do
        local radioBtn = CreateFrame("CheckButton", "RGMExportRadio" .. fmt, frame, "UIRadioButtonTemplate")
        if prevBtn then
            radioBtn:SetPoint("LEFT", prevBtn, "RIGHT", 80, 0)
        else
            radioBtn:SetPoint("TOPLEFT", 10, -(addon.TITLE_HEIGHT + 6))
        end
        radioBtn:SetSize(16, 16)
        radioBtn:SetChecked(fmt == FORMAT_PAIRED)

        local label = radioBtn:CreateFontString(nil, "ARTWORK")
        label:SetFont(FONT, 10, "OUTLINE")
        label:SetPoint("LEFT", radioBtn, "RIGHT", 2, 0)
        label:SetText(formatNames[fmt])
        label:SetTextColor(0.8, 0.8, 0.8, 1)

        radioBtn:SetScript("OnClick", function()
            self.exportFormat = fmt
            -- Uncheck others
            for f = FORMAT_PAIRED, FORMAT_ENCODED do
                local rb = _G["RGMExportRadio" .. f]
                if rb then
                    rb:SetChecked(f == fmt)
                end
            end
            self:UpdateExportText()
        end)

        prevBtn = radioBtn
    end

    -- Text area
    local scrollFrame, editBox = CreateMultiLineEditBox(frame)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", 10, -(addon.TITLE_HEIGHT + 30))
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    self.exportEditBox = editBox

    frame:Show()
    self:UpdateExportText()
end

function addon:UpdateExportText()
    if not self.exportEditBox then
        return
    end

    local slots = self:GetGridState()
    local text

    if self.exportFormat == FORMAT_PAIRED then
        text = ExportPaired(slots)
    elseif self.exportFormat == FORMAT_HORIZONTAL then
        text = ExportHorizontal(slots)
    elseif self.exportFormat == FORMAT_VERTICAL then
        text = ExportVertical(slots)
    elseif self.exportFormat == FORMAT_ENCODED then
        text = ExportEncoded(slots)
    end

    self.exportEditBox:SetText(text or "")
    self.exportEditBox:HighlightText()
    self.exportEditBox:SetFocus()
end

-- Import window

function addon:ShowImportWindow()
    if self.importFrame then
        self.importFrame:Show()
        self.importEditBox:SetText("")
        self.importEditBox:SetFocus()

        return
    end

    local frame = CreateModalFrame("Import Layout", 500, 400)
    self.importFrame = frame

    local scrollFrame, editBox = CreateMultiLineEditBox(frame)
    self.importEditBox = editBox

    -- Import button
    local importBtn = addon.CreateStyledButton(frame, 80, 24, "Import")
    importBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    importBtn:SetScript("OnClick", function()
        self:DoImport()
    end)

    frame:Show()
    editBox:SetFocus()
end

-- Import prompt for naming
StaticPopupDialogs["RGM_IMPORT_LAYOUT"] = {
    text = "Enter a name for the imported layout:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local name = self.editBox:GetText()
        if name and strtrim(name) ~= "" then
            addon:FinishImport(strtrim(name))
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

function addon:DoImport()
    local text = self.importEditBox:GetText()
    if not text or strtrim(text) == "" then
        self:Print("Nothing to import.")

        return
    end

    -- Try encoded first
    local slots = TryImportEncoded(text)
    if not slots then
        slots = TryImportText(text)
    end

    if not slots then
        self:Print("Could not parse import data. Check the format.")

        return
    end

    self.pendingImportSlots = slots
    StaticPopup_Show("RGM_IMPORT_LAYOUT")
end

function addon:FinishImport(name)
    if not self.pendingImportSlots then
        return
    end

    local layout = {
        name = name,
        time = time(),
        slots = self.pendingImportSlots,
    }

    table.insert(self.db.profile.layouts, layout)
    self.selectedLayout = layout
    self:LoadLayoutToGrid(layout)
    self:RefreshLayoutList()
    self:Print("Layout imported: " .. name)

    self.pendingImportSlots = nil

    if self.importFrame then
        self.importFrame:Hide()
    end
end
