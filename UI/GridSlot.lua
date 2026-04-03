local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local FONT = addon.FONT
local SLOT_WIDTH = addon.SLOT_WIDTH
local SLOT_HEIGHT = addon.SLOT_HEIGHT
local GROUP_PADDING = addon.GROUP_PADDING
local ROLE_ICON_SIZE = 16

local COLOR_GRAY = { r = 0.7, g = 0.7, b = 0.7 }
local COLOR_BORDER_NORMAL = { r = 0, g = 0, b = 0 }
local COLOR_BORDER_UNMATCHED = { r = 0.5, g = 0.25, b = 0.3 }

local ROLE_ATLAS = {
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps",
}

local dragSource = nil

local function GetSlotGroup(slotIndex)

    return math.ceil(slotIndex / 5)
end

local function GetSlotPosition(slotIndex)

    return ((slotIndex - 1) % 5) + 1
end

local function CreateSlotFrame(parent, slotIndex)
    local slot = CreateFrame("Frame", "RGMSlot" .. slotIndex, parent, "BackdropTemplate")
    slot:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
    slot.slotIndex = slotIndex

    -- Background
    slot.bg = slot:CreateTexture(nil, "BACKGROUND")
    slot.bg:SetAllPoints()
    slot.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    slot.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)

    -- Border (1px outset, like RCC)
    slot.borderTex = slot:CreateTexture(nil, "BORDER")
    slot.borderTex:SetPoint("TOPLEFT", -1, 1)
    slot.borderTex:SetPoint("BOTTOMRIGHT", 1, -1)
    slot.borderTex:SetColorTexture(0, 0, 0, 1)

    -- EditBox
    local editBox = CreateFrame("EditBox", nil, slot)
    editBox:SetPoint("TOPLEFT", 2, -1)
    editBox:SetPoint("BOTTOMRIGHT", -(ROLE_ICON_SIZE + 4), 1)
    editBox:SetFont(FONT, 16, "OUTLINE")
    editBox:SetAutoFocus(false)
    editBox:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
    editBox:SetMaxLetters(30)
    editBox.slotIndex = slotIndex

    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addon:RefreshSlot(slotIndex)
        addon:RefreshUnassigned()
        addon:TryAutoSave()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnEditFocusLost", function()
        addon:RefreshSlot(slotIndex)
        addon:RefreshUnassigned()
        addon:TryAutoSave()
    end)

    slot.editBox = editBox

    -- Role icon
    local roleIcon = slot:CreateTexture(nil, "ARTWORK")
    roleIcon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
    roleIcon:SetPoint("RIGHT", -2, 0)
    roleIcon:Hide()
    slot.roleIcon = roleIcon

    -- Drag-and-drop
    slot:EnableMouse(true)
    slot:RegisterForDrag("LeftButton")

    slot:SetScript("OnDragStart", function(self)
        dragSource = self
        self:SetAlpha(0.5)
    end)

    slot:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)
        if not dragSource then
            return
        end

        local target = FindSlotUnderCursor()
        if target and target ~= dragSource then
            SwapSlotContents(dragSource.slotIndex, target.slotIndex)
        end

        dragSource = nil
    end)

    return slot
end

-- Find which slot frame the cursor is hovering over
function FindSlotUnderCursor()
    for i = 1, 40 do
        local slot = addon.slots[i]
        if slot and slot:IsMouseOver() then
            return slot
        end
    end

    return nil
end

-- Swap text between two slots
function SwapSlotContents(indexA, indexB)
    local textA = addon:GetSlotText(indexA)
    local textB = addon:GetSlotText(indexB)
    addon:SetSlotText(indexA, textB)
    addon:SetSlotText(indexB, textA)
    addon:RefreshSlot(indexA)
    addon:RefreshSlot(indexB)
    addon:RefreshUnassigned()
    addon:TryAutoSave()
end

-- Accept a drop from the unassigned panel
function addon:DropNameOnSlot(slotIndex, name)
    self:SetSlotText(slotIndex, name)
    self:RefreshSlot(slotIndex)
    self:RefreshUnassigned()
    self:TryAutoSave()
end

function addon:RefreshSlot(slotIndex)
    local slot = self.slots[slotIndex]
    if not slot then
        return
    end

    local text = self:GetSlotText(slotIndex)
    local editBox = slot.editBox
    local roleIcon = slot.roleIcon

    if text == "" then
        editBox:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        slot.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)
        slot.borderTex:SetColorTexture(COLOR_BORDER_NORMAL.r, COLOR_BORDER_NORMAL.g, COLOR_BORDER_NORMAL.b, 1)
        roleIcon:Hide()

        return
    end

    local roster = self:GetRaidRoster()
    local normalized = self:NormalizeName(text)
    local member = roster[normalized]

    if member then
        -- In raid — class color
        local classColor = C_ClassColor.GetClassColor(member.class)
        if classColor then
            editBox:SetTextColor(classColor.r, classColor.g, classColor.b)
            slot.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, 0.25)
        else
            editBox:SetTextColor(1, 1, 1)
            slot.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)
        end

        slot.borderTex:SetColorTexture(COLOR_BORDER_NORMAL.r, COLOR_BORDER_NORMAL.g, COLOR_BORDER_NORMAL.b, 1)

        -- Role icon
        local atlas = ROLE_ATLAS[member.role]
        if atlas then
            roleIcon:SetAtlas(atlas)
            roleIcon:Show()
        else
            roleIcon:Hide()
        end
    else
        -- Not in raid — gray text, red-tinted border
        editBox:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        slot.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)
        slot.borderTex:SetColorTexture(COLOR_BORDER_UNMATCHED.r, COLOR_BORDER_UNMATCHED.g, COLOR_BORDER_UNMATCHED.b, 1)
        roleIcon:Hide()
    end
end

function addon:RefreshAllSlots()
    for i = 1, 40 do
        self:RefreshSlot(i)
    end
end

-- Create the 8-group x 5-slot grid layout
-- Layout: 4 rows of 2 groups side by side
function addon:CreateGrid(parent)
    local colWidth = SLOT_WIDTH + 10
    local groupHeaderHeight = 18

    for g = 1, 8 do
        -- Grid position: groups 1,3,5,7 on left; 2,4,6,8 on right
        local col = ((g - 1) % 2)       -- 0 = left, 1 = right
        local row = math.floor((g - 1) / 2) -- 0..3

        local groupOffsetX = col * (colWidth + GROUP_PADDING)
        local groupOffsetY = -(row * (5 * SLOT_HEIGHT + groupHeaderHeight + GROUP_PADDING + 6))

        -- Group header
        local header = parent:CreateFontString(nil, "ARTWORK")
        header:SetFont(FONT, 16, "OUTLINE")
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", groupOffsetX, groupOffsetY)
        header:SetText("Group " .. g)
        header:SetTextColor(1, 1, 1, 1)

        -- Slots
        for p = 1, 5 do
            local slotIndex = (g - 1) * 5 + p
            local slot = CreateSlotFrame(parent, slotIndex)

            local slotOffsetY = groupOffsetY - groupHeaderHeight - ((p - 1) * SLOT_HEIGHT)
            slot:SetPoint("TOPLEFT", parent, "TOPLEFT", groupOffsetX, slotOffsetY)

            self.slots[slotIndex] = slot
        end
    end
end
