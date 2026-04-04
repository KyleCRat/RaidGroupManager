local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")
local LPP = LibStub("LibPixelPerfect-1.0")

local FONT = addon.FONT
local SLOT_WIDTH = addon.SLOT_WIDTH
local SLOT_HEIGHT = addon.SLOT_HEIGHT
local SLOT_GAP = addon.SLOT_GAP
local GROUP_GAP = addon.GROUP_GAP
local GROUP_HEADER_HEIGHT = addon.GROUP_HEADER_HEIGHT
local ROLE_ICON_SIZE = 16

local COLOR_EMPTY_BG = { r = 0.2, g = 0.2, b = 0.2, a = 0.4 }
local COLOR_EMPTY_TEXT = { r = 0.4, g = 0.4, b = 0.4, a = 0.5 }
local COLOR_GRAY = { r = 0.7, g = 0.7, b = 0.7 }
local COLOR_BORDER_NORMAL = { r = 0, g = 0, b = 0 }
local COLOR_BORDER_UNMATCHED = { r = 0.5, g = 0.25, b = 0.3 }
local COLOR_DRAG_HIGHLIGHT = { r = 0.4, g = 0.6, b = 1, a = 0.3 }

local ROLE_ATLAS = {
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps",
}

-- Template roles include MELEE/RANGED which both use the DPS icon
local TEMPLATE_ROLE_ATLAS = {
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal",
    MELEE = "groupfinder-icon-role-large-dps",
    RANGED = "groupfinder-icon-role-large-dps",
}

local COLOR_TEMPLATE_BG_ALPHA = 0.3

local ROLE_DISPLAY_NAMES = {
    TANK = "Tank",
    HEALER = "Healer",
    MELEE = "Melee",
    RANGED = "Ranged",
}

-- Global drag state
addon.dragSource = nil
addon.dragSourceType = nil -- "slot", "unassigned", or "template"
addon.dragSourceName = nil
addon.dragSourceTemplate = nil

local function CreateSlotFrame(parent, slotIndex)
    local slot = CreateFrame("Frame", "RGMSlot" .. slotIndex, parent)
    slot:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
    slot.slotIndex = slotIndex
    slot.playerName = ""

    slot:EnableMouse(true)
    slot:RegisterForDrag("LeftButton")

    -- Background fill (above border so it's visible)
    slot.bg = slot:CreateTexture(nil, "BORDER")
    slot.bg:SetAllPoints()
    slot.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    slot.bg:SetVertexColor(COLOR_EMPTY_BG.r, COLOR_EMPTY_BG.g, COLOR_EMPTY_BG.b, COLOR_EMPTY_BG.a)

    -- Name text
    slot.nameText = slot:CreateFontString(nil, "ARTWORK")
    slot.nameText:SetFont(FONT, 14, "OUTLINE")
    slot.nameText:SetPoint("LEFT", 4, 0)
    slot.nameText:SetPoint("RIGHT", -(ROLE_ICON_SIZE + 4), 0)
    slot.nameText:SetJustifyH("LEFT")
    slot.nameText:SetWordWrap(false)

    -- Faded "Empty" text
    slot.emptyText = slot:CreateFontString(nil, "ARTWORK")
    slot.emptyText:SetFont(FONT, 12, "OUTLINE")
    slot.emptyText:SetPoint("CENTER")
    slot.emptyText:SetText("Empty")
    slot.emptyText:SetTextColor(COLOR_EMPTY_TEXT.r, COLOR_EMPTY_TEXT.g, COLOR_EMPTY_TEXT.b, COLOR_EMPTY_TEXT.a)

    -- Role icon
    slot.roleIcon = slot:CreateTexture(nil, "ARTWORK")
    slot.roleIcon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
    slot.roleIcon:SetPoint("RIGHT", -2, 0)
    slot.roleIcon:Hide()

    -- Drag hover highlight
    slot.dragHighlight = slot:CreateTexture(nil, "OVERLAY")
    slot.dragHighlight:SetAllPoints()
    slot.dragHighlight:SetColorTexture(COLOR_DRAG_HIGHLIGHT.r, COLOR_DRAG_HIGHLIGHT.g, COLOR_DRAG_HIGHLIGHT.b, COLOR_DRAG_HIGHLIGHT.a)
    slot.dragHighlight:SetBlendMode("ADD")
    slot.dragHighlight:Hide()

    -- Right-click to clear slot (player or template)
    slot:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and self.playerName ~= "" then
            addon:SetSlotText(self.slotIndex, "")
            addon:RefreshSlot(self.slotIndex)
            addon:RefreshUnassigned()
            addon:TryAutoSave()
        end
    end)

    -- Drag start
    slot:SetScript("OnDragStart", function(self)
        if self.playerName == "" then
            return
        end

        addon.dragSource = self
        addon.dragSourceType = "slot"
        addon.dragSourceName = self.playerName
        self:SetAlpha(0.5)
    end)

    -- Drag stop
    slot:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)

        if not addon.dragSource then
            return
        end

        local target = FindSlotUnderCursor()
        if target and target ~= addon.dragSource then
            if addon.dragSourceType == "slot" then
                SwapSlotContents(addon.dragSource.slotIndex, target.slotIndex)
            elseif addon.dragSourceType == "unassigned" then
                addon:DropNameOnSlot(target.slotIndex, addon.dragSourceName)
            elseif addon.dragSourceType == "template" then
                local t = addon.dragSourceTemplate
                addon:DropTemplateOnSlot(target.slotIndex, t.class, t.role)
            end
        end

        ClearDragState()
    end)

    -- Hover highlight during drag
    slot:SetScript("OnEnter", function(self)
        if addon.dragSource and addon.dragSource ~= self then
            self.dragHighlight:Show()
        end
    end)

    slot:SetScript("OnLeave", function(self)
        self.dragHighlight:Hide()
    end)

    return slot
end

function ClearDragState()
    if addon.dragSource then
        addon.dragSource:SetAlpha(1)
    end

    -- Hide all drag highlights
    for i = 1, 40 do
        local slot = addon.slots[i]
        if slot then
            slot.dragHighlight:Hide()
        end
    end

    addon.dragSource = nil
    addon.dragSourceType = nil
    addon.dragSourceName = nil
    addon.dragSourceTemplate = nil
end

function FindSlotUnderCursor()
    for i = 1, 40 do
        local slot = addon.slots[i]
        if slot and slot:IsMouseOver() then
            return slot
        end
    end

    return nil
end

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

function addon:DropNameOnSlot(slotIndex, name)
    self:SetSlotText(slotIndex, name)
    self:RefreshSlot(slotIndex)
    self:RefreshUnassigned()
    self:TryAutoSave()
end

function addon:DropTemplateOnSlot(slotIndex, class, role)
    self:SetSlotTemplate(slotIndex, class, role)
    self:RefreshSlot(slotIndex)
    self:RefreshUnassigned()
    self:TryAutoSave()
end

function addon:RefreshSlot(slotIndex)
    local slot = self.slots[slotIndex]
    if not slot then
        return
    end

    local text = slot.playerName or ""
    local roleIcon = slot.roleIcon

    if text == "" then
        slot.nameText:SetText("")
        slot.emptyText:Show()
        slot.bg:SetVertexColor(COLOR_EMPTY_BG.r, COLOR_EMPTY_BG.g, COLOR_EMPTY_BG.b, COLOR_EMPTY_BG.a)
        roleIcon:Hide()

        return
    end

    slot.emptyText:Hide()

    -- Template slot — show class name (or role name for generic) + role icon
    local template = self:DecodeTemplate(text)
    if template then
        local isGeneric = template.class == "ANY"

        if isGeneric then
            slot.nameText:SetText(ROLE_DISPLAY_NAMES[template.role] or template.role)
            slot.nameText:SetTextColor(0.8, 0.8, 0.8)
            slot.bg:SetVertexColor(0.4, 0.4, 0.4, COLOR_TEMPLATE_BG_ALPHA)
        else
            slot.nameText:SetText(self:GetClassName(template.class))

            local classColor = C_ClassColor.GetClassColor(template.class)
            if classColor then
                slot.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
                slot.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, COLOR_TEMPLATE_BG_ALPHA)
            else
                slot.nameText:SetTextColor(0.6, 0.6, 0.6)
                slot.bg:SetVertexColor(0.3, 0.3, 0.3, COLOR_TEMPLATE_BG_ALPHA)
            end
        end

        local atlas = TEMPLATE_ROLE_ATLAS[template.role]
        if atlas then
            roleIcon:SetAtlas(atlas)
            roleIcon:Show()
        else
            roleIcon:Hide()
        end

        return
    end

    -- Player slot
    slot.nameText:SetText(text)

    local roster = self:GetRaidRoster()
    local member = roster[text]

    if member then
        -- In raid — class color
        local classColor = C_ClassColor.GetClassColor(member.class)
        if classColor then
            slot.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
            slot.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, 0.5)
        else
            slot.nameText:SetTextColor(1, 1, 1)
            slot.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)
        end

        -- Role icon
        local atlas = ROLE_ATLAS[member.role]
        if atlas then
            roleIcon:SetAtlas(atlas)
            roleIcon:Show()
        else
            roleIcon:Hide()
        end
    else
        -- Not in raid — gray text
        slot.nameText:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        slot.bg:SetVertexColor(0.5, 0.5, 0.5, 0.25)
        roleIcon:Hide()
    end
end

function addon:RefreshAllSlots()
    for i = 1, 40 do
        self:RefreshSlot(i)
    end
end

-- Create the 8-group x 5-slot grid layout
-- Create the 8-group x 5-slot grid layout
-- 4 rows of 2 groups side by side, pixel-perfect spacing
function addon:CreateGrid(parent)
    local PS = LPP.PScale

    local slotWidth = PS(SLOT_WIDTH)
    local slotHeight = PS(SLOT_HEIGHT)
    local slotGap = PS(SLOT_GAP)
    local groupGap = PS(GROUP_GAP)
    local headerHeight = PS(GROUP_HEADER_HEIGHT)
    local colWidth = PS(SLOT_WIDTH + 10)
    local colSpacing = PS(4)

    local groupSlotHeight = 5 * slotHeight + 4 * slotGap
    local groupStride = headerHeight + groupSlotHeight + groupGap

    for g = 1, 8 do
        local col = (g - 1) % 2
        local row = (g - 1 - col) / 2

        local groupOffsetX = col * (colWidth + colSpacing)
        local groupOffsetY = -(row * groupStride)

        -- Group header — small, centered, faded
        local header = parent:CreateFontString(nil, "ARTWORK")
        header:SetFont(FONT, 12, "OUTLINE")
        header:SetText("Group " .. g)
        header:SetTextColor(0.5, 0.5, 0.5, 0.7)

        local headerCenterX = groupOffsetX + (slotWidth / 2)
        header:SetPoint("TOP", parent, "TOPLEFT", headerCenterX, groupOffsetY)

        -- Slots
        for p = 1, 5 do
            local slotIndex = (g - 1) * 5 + p
            local slot = CreateSlotFrame(parent, slotIndex)

            LPP.PSize(slot, SLOT_WIDTH, SLOT_HEIGHT)

            local slotOffsetY = groupOffsetY - headerHeight - ((p - 1) * (slotHeight + slotGap))
            slot:SetPoint("TOPLEFT", parent, "TOPLEFT", groupOffsetX, slotOffsetY)

            self.slots[slotIndex] = slot
        end
    end
end
