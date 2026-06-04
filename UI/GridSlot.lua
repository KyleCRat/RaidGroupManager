local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")
local LPP = LibStub("LibPixelPerfect-1.0")

local ClassSpecRoles = addon.ClassSpecRoles
local FONT = addon.FONT
local SLOT_WIDTH = addon.SLOT_WIDTH
local SLOT_HEIGHT = addon.SLOT_HEIGHT
local SLOT_GAP = addon.SLOT_GAP
local GROUP_GAP = addon.GROUP_GAP
local GROUP_HEADER_HEIGHT = addon.GROUP_HEADER_HEIGHT
local ROLE_ICON_SIZE = 16
local LEADER_ICON_SIZE = addon.LEADERSHIP_ICON_SIZE

local COLOR_WHITE = { r = 1, g = 1, b = 1, a = 1 }
local COLOR_EMPTY_BG = { r = 0.2, g = 0.2, b = 0.2, a = 0.4 }
local COLOR_EMPTY_TEXT = { r = 0.4, g = 0.4, b = 0.4, a = 0.5 }
local COLOR_GRAY = { r = 0.7, g = 0.7, b = 0.7 }
local COLOR_GRAY_BG = { r = 0.5, g = 0.5, b = 0.5, a = 0.25 }
local COLOR_BORDER_NORMAL = { r = 0, g = 0, b = 0 }
local COLOR_BORDER_UNMATCHED = { r = 0.5, g = 0.25, b = 0.3 }
local COLOR_DRAG_HIGHLIGHT = { r = 0.4, g = 0.6, b = 1, a = 0.3 }
local COLOR_DRAG_PREVIEW_BG_FALLBACK = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
local COLOR_DRAG_PREVIEW_BORDER = { r = 0, g = 0, b = 0, a = 1 }
local COLOR_TEMPLATE_GENERIC_TEXT = { r = 0.8, g = 0.8, b = 0.8 }
local COLOR_TEMPLATE_GENERIC_BG = { r = 0.4, g = 0.4, b = 0.4 }
local COLOR_TEMPLATE_FALLBACK_TEXT = { r = 0.6, g = 0.6, b = 0.6 }
local COLOR_TEMPLATE_FALLBACK_BG = { r = 0.3, g = 0.3, b = 0.3 }
local COLOR_GROUP_HEADER = { r = 0.5, g = 0.5, b = 0.5, a = 0.7 }
local DRAG_SOURCE_ALPHA = 0.2
local DRAG_PREVIEW_MIN_BG_ALPHA = 0.75
local TEXT_ALPHA_DEFAULT = 1
local PLAYER_CLASS_BG_ALPHA = 0.5
local COLOR_TEMPLATE_BG_ALPHA = 0.3

local ROLE_ICON_PATH = "Interface\\AddOns\\RaidGroupManager\\Media\\Icons\\"

local ROLE_TEXTURES = {
    TANK = ROLE_ICON_PATH .. "tank",
    HEALER = ROLE_ICON_PATH .. "healer",
    MELEE = ROLE_ICON_PATH .. "meleedps",
    RANGED = ROLE_ICON_PATH .. "rangeddps",
}

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

local function UpdateDragPreviewPosition(frame)
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    x = x / scale
    y = y / scale

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - frame.dragCursorOffsetX, y + frame.dragCursorOffsetY)
end

local function DragPreview_OnUpdate(self)
    UpdateDragPreviewPosition(self)
end

local function GetSourceVertexColor(sourceFrame, key, fallback)
    local region = sourceFrame and sourceFrame[key]
    if region and region.GetVertexColor then
        local r, g, b, a = region:GetVertexColor()

        return r, g, b, a
    end

    return fallback.r, fallback.g, fallback.b, fallback.a
end

local function GetSourceTextColor(sourceFrame)
    local text = sourceFrame and sourceFrame.nameText
    if text and text.GetTextColor then
        local r, g, b, a = text:GetTextColor()

        return r, g, b, a
    end

    return COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, COLOR_WHITE.a
end

local function CreateDragPreviewFrame()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:Hide()

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture("Interface\\Buttons\\WHITE8x8")

    frame.borderTop = frame:CreateTexture(nil, "BORDER")
    frame.borderTop:SetPoint("TOPLEFT")
    frame.borderTop:SetPoint("TOPRIGHT")
    frame.borderTop:SetHeight(1)
    frame.borderTop:SetColorTexture(COLOR_DRAG_PREVIEW_BORDER.r, COLOR_DRAG_PREVIEW_BORDER.g, COLOR_DRAG_PREVIEW_BORDER.b, COLOR_DRAG_PREVIEW_BORDER.a)

    frame.borderBottom = frame:CreateTexture(nil, "BORDER")
    frame.borderBottom:SetPoint("BOTTOMLEFT")
    frame.borderBottom:SetPoint("BOTTOMRIGHT")
    frame.borderBottom:SetHeight(1)
    frame.borderBottom:SetColorTexture(COLOR_DRAG_PREVIEW_BORDER.r, COLOR_DRAG_PREVIEW_BORDER.g, COLOR_DRAG_PREVIEW_BORDER.b, COLOR_DRAG_PREVIEW_BORDER.a)

    frame.borderLeft = frame:CreateTexture(nil, "BORDER")
    frame.borderLeft:SetPoint("TOPLEFT")
    frame.borderLeft:SetPoint("BOTTOMLEFT")
    frame.borderLeft:SetWidth(1)
    frame.borderLeft:SetColorTexture(COLOR_DRAG_PREVIEW_BORDER.r, COLOR_DRAG_PREVIEW_BORDER.g, COLOR_DRAG_PREVIEW_BORDER.b, COLOR_DRAG_PREVIEW_BORDER.a)

    frame.borderRight = frame:CreateTexture(nil, "BORDER")
    frame.borderRight:SetPoint("TOPRIGHT")
    frame.borderRight:SetPoint("BOTTOMRIGHT")
    frame.borderRight:SetWidth(1)
    frame.borderRight:SetColorTexture(COLOR_DRAG_PREVIEW_BORDER.r, COLOR_DRAG_PREVIEW_BORDER.g, COLOR_DRAG_PREVIEW_BORDER.b, COLOR_DRAG_PREVIEW_BORDER.a)

    frame.nameText = frame:CreateFontString(nil, "ARTWORK")
    frame.nameText:SetFont(FONT, 13, "OUTLINE")
    frame.nameText:SetPoint("LEFT", 4, 0)
    frame.nameText:SetPoint("RIGHT", -(ROLE_ICON_SIZE + 4), 0)
    frame.nameText:SetJustifyH("LEFT")
    frame.nameText:SetWordWrap(false)

    frame.roleIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.roleIcon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
    frame.roleIcon:SetPoint("RIGHT", -2, 0)
    frame.roleIcon:Hide()

    frame.leaderIcon = addon:CreateLeadershipIcon(frame, frame.roleIcon)

    return frame
end

addon.dragPreviewFrame = CreateDragPreviewFrame()

local function GetFrameCursorOffset(sourceFrame)
    local cursorX, cursorY = GetCursorPosition()
    local left, bottom, width, height = sourceFrame:GetScaledRect()

    if left and bottom and width and height then
        local sourceScale = sourceFrame:GetEffectiveScale()

        return (cursorX - left) / sourceScale, ((bottom + height) - cursorY) / sourceScale
    end
end

function addon:CaptureDragCursorOffset(sourceFrame)
    sourceFrame.dragCursorOffsetX, sourceFrame.dragCursorOffsetY = GetFrameCursorOffset(sourceFrame)
end

local function SetDragPreviewCursorOffset(frame, sourceFrame)
    if sourceFrame.dragCursorOffsetX and sourceFrame.dragCursorOffsetY then
        frame.dragCursorOffsetX = sourceFrame.dragCursorOffsetX
        frame.dragCursorOffsetY = sourceFrame.dragCursorOffsetY

        return
    end

    frame.dragCursorOffsetX, frame.dragCursorOffsetY = GetFrameCursorOffset(sourceFrame)
    frame.dragCursorOffsetX = frame.dragCursorOffsetX or 0
    frame.dragCursorOffsetY = frame.dragCursorOffsetY or 0
end

function addon:ShowDragPreviewFromFrame(sourceFrame)
    if not sourceFrame then
        return
    end

    if not self.dragPreviewFrame then
        self.dragPreviewFrame = CreateDragPreviewFrame()
    end

    local frame = self.dragPreviewFrame
    local width = sourceFrame:GetWidth() or SLOT_WIDTH
    local height = sourceFrame:GetHeight() or SLOT_HEIGHT
    local sourceScale = sourceFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local text = sourceFrame.nameText and sourceFrame.nameText:GetText() or ""
    local textWidth = 0
    local textR, textG, textB, textA = GetSourceTextColor(sourceFrame)
    local bgR, bgG, bgB, bgA = GetSourceVertexColor(sourceFrame, "bg", COLOR_DRAG_PREVIEW_BG_FALLBACK)
    local leadershipTexture
    local roleTexture
    local roleAtlas

    if sourceFrame.leaderIcon and sourceFrame.leaderIcon:IsShown() then
        leadershipTexture = sourceFrame.leaderIcon:GetTexture()
    end

    if sourceFrame.nameText then
        textWidth = sourceFrame.nameText:GetStringWidth() or 0
        if sourceFrame.nameText.GetUnboundedStringWidth then
            textWidth = sourceFrame.nameText:GetUnboundedStringWidth() or textWidth
        end
    end

    if sourceFrame.roleIcon and sourceFrame.roleIcon:IsShown() then
        if sourceFrame.roleIcon.GetAtlas then
            roleAtlas = sourceFrame.roleIcon:GetAtlas()
        end

        if not roleAtlas then
            roleTexture = sourceFrame.roleIcon:GetTexture()
        end
    end

    local iconWidth = ROLE_ICON_SIZE + (leadershipTexture and LEADER_ICON_SIZE + 3 or 0)

    frame:SetSize(math.max(80, width, math.ceil(textWidth + iconWidth + 16)), math.max(SLOT_HEIGHT, height))
    frame:SetScale(sourceScale)
    SetDragPreviewCursorOffset(frame, sourceFrame)
    frame.bg:SetVertexColor(bgR, bgG, bgB, math.max(bgA or 0, DRAG_PREVIEW_MIN_BG_ALPHA))
    frame.nameText:SetText(text)
    frame.nameText:SetTextColor(textR, textG, textB, textA or TEXT_ALPHA_DEFAULT)
    self:SetLeadershipIconState(frame, leadershipTexture, 4, ROLE_ICON_SIZE)

    if roleAtlas and frame.roleIcon.SetAtlas then
        frame.roleIcon:SetAtlas(roleAtlas)
        frame.roleIcon:Show()
    elseif roleTexture then
        frame.roleIcon:SetTexCoord(0, 1, 0, 1)
        frame.roleIcon:SetTexture(roleTexture)
        frame.roleIcon:Show()
    else
        frame.roleIcon:Hide()
    end

    UpdateDragPreviewPosition(frame)
    frame:SetScript("OnUpdate", DragPreview_OnUpdate)
    frame:Show()
end

function addon:HideDragPreview()
    if self.dragPreviewFrame then
        self.dragPreviewFrame:SetScript("OnUpdate", nil)
        self.dragPreviewFrame:Hide()
    end
end

function addon:StartDragVisual(sourceFrame)
    if sourceFrame then
        sourceFrame:SetAlpha(DRAG_SOURCE_ALPHA)
        self:ShowDragPreviewFromFrame(sourceFrame)
    end
end

local function FindSlotUnderCursor()
    for i = 1, 40 do
        local slot = addon.slots[i]
        if slot and slot:IsMouseOver() then
            return slot
        end
    end

    return nil
end

local function SwapSlotContents(indexA, indexB)
    local textA = addon:GetSlotText(indexA)
    local textB = addon:GetSlotText(indexB)
    addon:SetSlotText(indexA, textB)
    addon:SetSlotText(indexB, textA)
    addon:RefreshSlot(indexA)
    addon:RefreshSlot(indexB)
    addon:RefreshUnassigned()
    addon:TryAutoSave()
end

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

    slot.leaderIcon = addon:CreateLeadershipIcon(slot, slot.roleIcon)

    -- Drag hover highlight
    slot.dragHighlight = slot:CreateTexture(nil, "OVERLAY")
    slot.dragHighlight:SetAllPoints()
    slot.dragHighlight:SetColorTexture(COLOR_DRAG_HIGHLIGHT.r, COLOR_DRAG_HIGHLIGHT.g, COLOR_DRAG_HIGHLIGHT.b, COLOR_DRAG_HIGHLIGHT.a)
    slot.dragHighlight:SetBlendMode("ADD")
    slot.dragHighlight:Hide()

    -- Right-click to clear slot (player or template)
    slot:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self.playerName ~= "" then
            addon:CaptureDragCursorOffset(self)
        end

        if button == "MiddleButton" and self.playerName ~= "" and not addon:DecodeTemplate(self.playerName) then
            addon:ToggleRaidAssist(self.playerName)
        end

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
        addon:StartDragVisual(self)
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

        addon:ClearDragState()
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

function addon:ClearDragState()
    if self.dragSource then
        self.dragSource:SetAlpha(1)
        self.dragSource.dragCursorOffsetX = nil
        self.dragSource.dragCursorOffsetY = nil
    end

    self:HideDragPreview()

    -- Hide all drag highlights
    for i = 1, 40 do
        local slot = self.slots[i]
        if slot then
            slot.dragHighlight:Hide()
        end
    end

    self.dragSource = nil
    self.dragSourceType = nil
    self.dragSourceName = nil
    self.dragSourceTemplate = nil
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
        roleIcon:SetDesaturated(false)
        roleIcon:Hide()
        self:SetLeadershipIconState(slot, nil, 4, ROLE_ICON_SIZE)

        return
    end

    slot.emptyText:Hide()

    -- Template slot — show class name (or role name for generic) + role icon
    local template = self:DecodeTemplate(text)
    if template then
        local isGeneric = template.class == "ANY"

        if isGeneric then
            slot.nameText:SetText(ROLE_DISPLAY_NAMES[template.role] or template.role)
            slot.nameText:SetTextColor(COLOR_TEMPLATE_GENERIC_TEXT.r, COLOR_TEMPLATE_GENERIC_TEXT.g, COLOR_TEMPLATE_GENERIC_TEXT.b)
            slot.bg:SetVertexColor(COLOR_TEMPLATE_GENERIC_BG.r, COLOR_TEMPLATE_GENERIC_BG.g, COLOR_TEMPLATE_GENERIC_BG.b, COLOR_TEMPLATE_BG_ALPHA)
        else
            slot.nameText:SetText(ClassSpecRoles:GetClassName(template.class))

            local classColor = C_ClassColor.GetClassColor(template.class)
            if classColor then
                slot.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
                slot.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, COLOR_TEMPLATE_BG_ALPHA)
            else
                slot.nameText:SetTextColor(COLOR_TEMPLATE_FALLBACK_TEXT.r, COLOR_TEMPLATE_FALLBACK_TEXT.g, COLOR_TEMPLATE_FALLBACK_TEXT.b)
                slot.bg:SetVertexColor(COLOR_TEMPLATE_FALLBACK_BG.r, COLOR_TEMPLATE_FALLBACK_BG.g, COLOR_TEMPLATE_FALLBACK_BG.b, COLOR_TEMPLATE_BG_ALPHA)
            end
        end

        local texture = ROLE_TEXTURES[template.role]
        if texture then
            roleIcon:SetTexture(texture)
            roleIcon:SetDesaturated(false)
            roleIcon:Show()
        else
            roleIcon:SetDesaturated(false)
            roleIcon:Hide()
        end

        self:SetLeadershipIconState(slot, nil, 4, ROLE_ICON_SIZE)

        return
    end

    -- Player slot
    slot.nameText:SetText(text)
    local normalizedText = self:NormalizeName(text)
    local roster = self:GetGroupDisplayRoster()
    local member = roster[normalizedText]

    if member then
        local isOffline = member.online == false
        self:SetLeadershipIconState(slot, self:GetLeadershipIconTextureForRank(member.rank), 4, ROLE_ICON_SIZE, isOffline)

        -- In raid — class color
        local classColor = C_ClassColor.GetClassColor(member.class)
        if classColor then
            slot.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
            slot.bg:SetVertexColor(classColor.r, classColor.g, classColor.b, PLAYER_CLASS_BG_ALPHA)
        else
            slot.nameText:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
            slot.bg:SetVertexColor(COLOR_GRAY_BG.r, COLOR_GRAY_BG.g, COLOR_GRAY_BG.b, COLOR_GRAY_BG.a)
        end

        -- Role icon
        local combatRole = self:GetCombatRole(member)
        local texture = ROLE_TEXTURES[combatRole]
        if texture then
            roleIcon:SetTexture(texture)
            roleIcon:SetDesaturated(isOffline)
            roleIcon:Show()
        else
            roleIcon:SetDesaturated(false)
            roleIcon:Hide()
        end
    else
        local rosterEntry = self:GetImportedRosterEntry(text)
        if rosterEntry then
            local assistTexture = self:IsRosterLeader(text) and self.ASSIST_ICON_TEXTURE or nil
            self:SetLeadershipIconState(slot, assistTexture, 4, ROLE_ICON_SIZE, true)

            slot.nameText:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
            slot.bg:SetVertexColor(COLOR_GRAY_BG.r, COLOR_GRAY_BG.g, COLOR_GRAY_BG.b, COLOR_GRAY_BG.a)

            local texture = rosterEntry.role and ROLE_TEXTURES[rosterEntry.role]
            if texture then
                roleIcon:SetTexture(texture)
                roleIcon:SetDesaturated(true)
                roleIcon:Show()
            else
                roleIcon:SetDesaturated(false)
                roleIcon:Hide()
            end

            return
        end
        -- Not in raid — gray text
        self:SetLeadershipIconState(slot, nil, 4, ROLE_ICON_SIZE)
        slot.nameText:SetTextColor(COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        slot.bg:SetVertexColor(COLOR_GRAY_BG.r, COLOR_GRAY_BG.g, COLOR_GRAY_BG.b, COLOR_GRAY_BG.a)
        roleIcon:SetDesaturated(false)
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
        header:SetTextColor(COLOR_GROUP_HEADER.r, COLOR_GROUP_HEADER.g, COLOR_GROUP_HEADER.b, COLOR_GROUP_HEADER.a)

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
