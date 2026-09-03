local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local PixelPerfect = addon.PixelPerfect
local FONT = addon.FONT
local TITLE_HEIGHT = addon.TITLE_HEIGHT
local UI_SPACING = addon.UI_SPACING

local COLOR_BLACK = { r = 0, g = 0, b = 0, a = 1 }
local BUTTON_BACKGROUND = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
local BUTTON_BORDER_NORMAL = { r = 0.45, g = 0.45, b = 0.45, a = 1 }
local BUTTON_BORDER_HOVER = COLOR_BLACK
local BUTTON_HIGHLIGHT = { r = 0.3, g = 0.3, b = 0.3, a = 0.5 }
local BUTTON_BACKGROUND_DISABLED = { r = 0.07, g = 0.07, b = 0.07, a = 0.75 }
local BUTTON_BORDER_DISABLED = { r = 0.25, g = 0.25, b = 0.25, a = 1 }
local BUTTON_TEXT_NORMAL = { r = 1, g = 1, b = 1, a = 1 }
local BUTTON_TEXT_DISABLED = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
local INPUT_BACKGROUND = { r = 0.14, g = 0.14, b = 0.14, a = 0.95 }
local INPUT_BORDER_NORMAL = { r = 0.45, g = 0.45, b = 0.45, a = 1 }
local INPUT_BORDER_FOCUS = { r = 0.7, g = 0.7, b = 0.7, a = 1 }
local INPUT_PLACEHOLDER = { r = 0.55, g = 0.55, b = 0.55, a = 0.9 }
local TITLE_BACKGROUND = { r = 0, g = 0, b = 0, a = 0.2 }
local WINDOW_BACKGROUND = { r = 0.05, g = 0.05, b = 0.05, a = 0.95 }

local INPUT_TEXT_INSET = 6
local MULTILINE_TEXT_INSET = 2
local SCROLL_BAR_OFFSET_X = 6
local SCROLL_BAR_TOP_INSET = 3

local MODERN_CHECKBOX_SIZE = 26
local MODERN_CHECKBOX_LABEL_GAP = 2
local MODERN_CHECKBOX_CHECKMARK_SCALE = 1
local MODERN_CHECKBOX_CHECKMARK_OFFSET_X = 1
local MODERN_CHECKBOX_CHECKMARK_OFFSET_Y = 1

local MODERN_CHECKBOX_ATLASES = {
    normal = "common-button-tertiary-square-normal",
    hover = "common-button-tertiary-square-hover",
    pressed = "common-button-tertiary-square-pressed",
    disabled = "common-button-tertiary-square-disabled",
}

addon.MODERN_CHECKBOX_SIZE = MODERN_CHECKBOX_SIZE

local CLOSE_TEXTURE = "Interface\\AddOns\\RaidGroupManager\\Media\\Textures\\Close"

local function UpdateEditBoxPlaceholder(editBox, placeholder)
    local text = editBox:GetText()
    placeholder:SetShown(not text or text == "")
end

local function SetColor(region, color)
    region:SetVertexColor(color.r, color.g, color.b, color.a)
end

local function UpdateStyledButtonState(button)
    if button:IsEnabled() then
        SetColor(button.bg, BUTTON_BACKGROUND)
        PixelPerfect.SetBorderColor(button, BUTTON_BORDER_NORMAL)
        button.label:SetTextColor(
            BUTTON_TEXT_NORMAL.r,
            BUTTON_TEXT_NORMAL.g,
            BUTTON_TEXT_NORMAL.b,
            BUTTON_TEXT_NORMAL.a
        )

        return
    end

    button.highlight:Hide()
    SetColor(button.bg, BUTTON_BACKGROUND_DISABLED)
    PixelPerfect.SetBorderColor(button, BUTTON_BORDER_DISABLED)
    button.label:SetTextColor(
        BUTTON_TEXT_DISABLED.r,
        BUTTON_TEXT_DISABLED.g,
        BUTTON_TEXT_DISABLED.b,
        BUTTON_TEXT_DISABLED.a
    )
end

local function CreateCheckboxAtlasTexture(checkbox, layer, atlas)
    local texture = checkbox:CreateTexture(nil, layer)
    texture:SetAllPoints(checkbox)
    texture:SetAtlas(atlas, false)

    return texture
end

local function CreateCheckboxCheckmark(checkbox, disabled)
    local texture = checkbox:CreateTexture(nil, "ARTWORK")
    texture:SetPoint(
        "CENTER",
        checkbox,
        "CENTER",
        MODERN_CHECKBOX_CHECKMARK_OFFSET_X,
        MODERN_CHECKBOX_CHECKMARK_OFFSET_Y
    )
    texture:SetAtlas("common-icon-checkmark-yellow", true)
    texture:SetScale(MODERN_CHECKBOX_CHECKMARK_SCALE)

    if disabled then
        texture:SetDesaturated(true)
        texture:SetVertexColor(0.5, 0.5, 0.5, 1)
    end

    return texture
end

function addon.CreateScrollFrame(parent, name)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "ScrollFrameTemplate")
    local scrollBar = scrollFrame.ScrollBar

    PixelPerfect.RegisterLayout(scrollFrame, function()
        scrollBar:ClearAllPoints()
        PixelPerfect.Point(
            scrollBar,
            "TOPLEFT",
            scrollFrame,
            "TOPRIGHT",
            SCROLL_BAR_OFFSET_X,
            -SCROLL_BAR_TOP_INSET
        )
        PixelPerfect.Point(scrollBar, "BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", SCROLL_BAR_OFFSET_X, 0)
    end)

    return scrollFrame
end

function addon.SetStyledButtonSize(button, width, height)
    button.rgmWidth = width or button.rgmWidth
    button.rgmHeight = height or button.rgmHeight
    PixelPerfect.Size(button, button.rgmWidth, button.rgmHeight)
end

function addon.CreateStyledButton(parent, width, height, label)
    local button = CreateFrame("Button", nil, parent)
    button.rgmWidth = width
    button.rgmHeight = height
    button.bg = PixelPerfect.CreateBackground(button, BUTTON_BACKGROUND)
    button.highlight = PixelPerfect.CreateBackground(button, BUTTON_HIGHLIGHT, "ARTWORK")
    button.highlight:SetBlendMode("ADD")
    button.highlight:Hide()

    PixelPerfect.CreateBorder(button, 1, BUTTON_BORDER_NORMAL)
    PixelPerfect.RegisterLayout(button, function()
        addon.SetStyledButtonSize(button, button.rgmWidth, button.rgmHeight)
    end)

    button.label = button:CreateFontString(nil, "OVERLAY")
    button.label:SetFont(FONT, 12, "OUTLINE")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    button.label:SetTextColor(
        BUTTON_TEXT_NORMAL.r,
        BUTTON_TEXT_NORMAL.g,
        BUTTON_TEXT_NORMAL.b,
        BUTTON_TEXT_NORMAL.a
    )

    button:SetScript("OnEnter", function(self)
        if not self:IsEnabled() then
            return
        end

        self.highlight:Show()
        PixelPerfect.SetBorderColor(self, BUTTON_BORDER_HOVER)
    end)

    button:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        UpdateStyledButtonState(self)
    end)

    button:SetScript("OnEnable", UpdateStyledButtonState)
    button:SetScript("OnDisable", UpdateStyledButtonState)
    UpdateStyledButtonState(button)

    return button
end

function addon.SetStyledButtonEnabled(button, enabled)
    button:SetEnabled(enabled == true)
    UpdateStyledButtonState(button)
end

function addon.CreateModernCheckbox(parent, labelText, options)
    options = options or {}

    local checkbox = CreateFrame("CheckButton", nil, parent)
    local labelSide = options.labelSide == "LEFT" and "LEFT" or "RIGHT"
    local labelGap = options.labelGap or MODERN_CHECKBOX_LABEL_GAP

    checkbox:SetNormalTexture(CreateCheckboxAtlasTexture(
        checkbox,
        "BACKGROUND",
        MODERN_CHECKBOX_ATLASES.normal
    ))
    checkbox:SetPushedTexture(CreateCheckboxAtlasTexture(
        checkbox,
        "BACKGROUND",
        MODERN_CHECKBOX_ATLASES.pressed
    ))
    checkbox:SetHighlightTexture(CreateCheckboxAtlasTexture(
        checkbox,
        "HIGHLIGHT",
        MODERN_CHECKBOX_ATLASES.hover
    ))
    checkbox:SetDisabledTexture(CreateCheckboxAtlasTexture(
        checkbox,
        "BACKGROUND",
        MODERN_CHECKBOX_ATLASES.disabled
    ))
    checkbox:SetCheckedTexture(CreateCheckboxCheckmark(checkbox, false))
    checkbox:SetDisabledCheckedTexture(CreateCheckboxCheckmark(checkbox, true))
    checkbox:SetMotionScriptsWhileDisabled(true)

    checkbox.label = checkbox:CreateFontString(nil, "ARTWORK")
    checkbox.label:SetFont(FONT, options.fontSize or 11, "OUTLINE")
    checkbox.label:SetText(labelText or "")
    checkbox.label:SetTextColor(0.75, 0.75, 0.75, 1)
    checkbox.label:SetWordWrap(false)

    local labelWidth = checkbox.label:GetStringWidth() or 0

    if checkbox.label.GetUnboundedStringWidth then
        labelWidth = checkbox.label:GetUnboundedStringWidth() or labelWidth
    end

    labelWidth = math.ceil(labelWidth)
    checkbox.rgmControlWidth = MODERN_CHECKBOX_SIZE + labelGap + labelWidth

    if labelSide == "LEFT" then
        checkbox:SetHitRectInsets(-(labelGap + labelWidth), 0, 0, 0)
    else
        checkbox:SetHitRectInsets(0, -(labelGap + labelWidth), 0, 0)
    end

    PixelPerfect.RegisterLayout(checkbox, function()
        PixelPerfect.Size(checkbox, MODERN_CHECKBOX_SIZE, MODERN_CHECKBOX_SIZE)

        checkbox.label:ClearAllPoints()
        if labelSide == "LEFT" then
            PixelPerfect.Point(checkbox.label, "RIGHT", checkbox, "LEFT", -labelGap, 0)
        else
            PixelPerfect.Point(checkbox.label, "LEFT", checkbox, "RIGHT", labelGap, 0)
        end
    end)

    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked() == true
        PlaySound(
            checked
                and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
        )

        if options.onChanged then
            options.onChanged(checked)
        end
    end)

    checkbox:SetScript("OnEnable", function(self)
        self.label:SetTextColor(0.75, 0.75, 0.75, 1)
    end)

    checkbox:SetScript("OnDisable", function(self)
        self.label:SetTextColor(0.4, 0.4, 0.4, 1)
    end)

    return checkbox
end

function addon.SetModernCheckboxEnabled(checkbox, enabled)
    checkbox:SetEnabled(enabled == true)

    if enabled then
        checkbox.label:SetTextColor(0.75, 0.75, 0.75, 1)
    else
        checkbox.label:SetTextColor(0.4, 0.4, 0.4, 1)
    end
end

function addon.SetEditBoxPlaceholder(editBox, placeholderText)
    local placeholder = editBox.rgmPlaceholder or editBox.Instructions
    if not placeholder then
        return
    end

    placeholder:SetText(placeholderText)
    UpdateEditBoxPlaceholder(editBox, placeholder)
end

function addon.StyleEditBox(editBox, placeholderText, options)
    options = options or {}

    local surface = options.surface or editBox
    local multiline = options.multiline == true
    local textInset = multiline and MULTILINE_TEXT_INSET or INPUT_TEXT_INSET

    surface.rgmInputBackground = PixelPerfect.CreateSurface(
        surface,
        INPUT_BACKGROUND,
        INPUT_BORDER_NORMAL,
        1
    )

    editBox:SetAutoFocus(false)
    editBox:SetFont(FONT, 12, "OUTLINE")
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV(multiline and "TOP" or "MIDDLE")
    if multiline then
        editBox:SetTextInsets(textInset, textInset, textInset, textInset)
    else
        editBox:SetTextInsets(textInset, textInset, 0, 0)
    end

    local placeholder = editBox:CreateFontString(nil, "ARTWORK")
    placeholder:SetFont(FONT, 12, "OUTLINE")
    placeholder:SetTextColor(
        INPUT_PLACEHOLDER.r,
        INPUT_PLACEHOLDER.g,
        INPUT_PLACEHOLDER.b,
        INPUT_PLACEHOLDER.a
    )
    placeholder:SetJustifyH("LEFT")
    placeholder:SetJustifyV(multiline and "TOP" or "MIDDLE")
    placeholder:SetWordWrap(multiline)
    editBox.rgmPlaceholder = placeholder

    PixelPerfect.RegisterLayout(editBox, function()
        placeholder:ClearAllPoints()
        if multiline then
            PixelPerfect.Point(placeholder, "TOPLEFT", editBox, "TOPLEFT", textInset, -textInset)
            PixelPerfect.Point(placeholder, "RIGHT", editBox, "RIGHT", -textInset, 0)
        else
            PixelPerfect.Point(placeholder, "LEFT", editBox, "LEFT", textInset, 0)
            PixelPerfect.Point(placeholder, "RIGHT", editBox, "RIGHT", -textInset, 0)
        end
    end)

    addon.SetEditBoxPlaceholder(editBox, placeholderText)

    editBox:HookScript("OnTextChanged", function(self)
        UpdateEditBoxPlaceholder(self, self.rgmPlaceholder)
    end)

    editBox:HookScript("OnEditFocusGained", function()
        PixelPerfect.SetBorderColor(surface, INPUT_BORDER_FOCUS)
    end)

    editBox:HookScript("OnEditFocusLost", function()
        PixelPerfect.SetBorderColor(surface, INPUT_BORDER_NORMAL)
    end)
end

function addon.CreateCloseButton(parent, targetFrame)
    local button = CreateFrame("Button", nil, parent)
    PixelPerfect.RegisterLayout(button, function()
        PixelPerfect.Size(button, 14, 14)
    end)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexture(CLOSE_TEXTURE)
    button.icon:SetVertexColor(0.7, 0.7, 0.7, 1)

    button:SetScript("OnEnter", function()
        button.icon:SetVertexColor(1, 1, 1, 1)
    end)

    button:SetScript("OnLeave", function()
        button.icon:SetVertexColor(0.7, 0.7, 0.7, 1)
    end)

    button:SetScript("OnClick", function()
        targetFrame:Hide()
    end)

    return button
end

function addon.CreateWindowFrame(title, width, height, backgroundAlpha)
    local frame = CreateFrame("Frame", nil, UIParent)
    local backgroundColor = {
        r = WINDOW_BACKGROUND.r,
        g = WINDOW_BACKGROUND.g,
        b = WINDOW_BACKGROUND.b,
        a = backgroundAlpha or WINDOW_BACKGROUND.a,
    }
    frame.bg = PixelPerfect.CreateSurface(frame, backgroundColor, COLOR_BLACK, 1)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    PixelPerfect.Size(frame, width, height)
    PixelPerfect.Point(frame, "CENTER", UIParent, "CENTER", 0, 0)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar.bg = PixelPerfect.CreateBackground(titleBar, TITLE_BACKGROUND)

    titleBar.text = titleBar:CreateFontString(nil, "ARTWORK")
    titleBar.text:SetFont(FONT, 16, "OUTLINE")
    titleBar.text:SetText(title)
    titleBar.text:SetTextColor(1, 1, 1, 1)

    local close = addon.CreateCloseButton(titleBar, frame)

    PixelPerfect.RegisterLayout(frame, function()
        PixelPerfect.Size(frame, width, height)
        PixelPerfect.SnapCurrentPoint(frame)

        titleBar:ClearAllPoints()
        PixelPerfect.Point(titleBar, "TOPLEFT", frame, "TOPLEFT", 1, -1)
        PixelPerfect.Point(titleBar, "TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        PixelPerfect.Height(titleBar, TITLE_HEIGHT)
        titleBar:SetFrameLevel(frame:GetFrameLevel() + 1)

        titleBar.text:ClearAllPoints()
        PixelPerfect.Point(titleBar.text, "LEFT", titleBar, "LEFT", UI_SPACING, 0)

        close:ClearAllPoints()
        PixelPerfect.Point(close, "RIGHT", titleBar, "RIGHT", -UI_SPACING, 1)
    end)

    frame:HookScript("OnShow", PixelPerfect.RequestRefresh)

    return frame, titleBar
end
