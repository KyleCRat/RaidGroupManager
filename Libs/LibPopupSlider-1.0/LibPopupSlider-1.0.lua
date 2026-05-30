-- LibPopupSlider-1.0 - a vertical drag-to-adjust slider popup
-- Attach to any button: click-and-drag opens a vertical slider at the cursor.
-- The button's OnMouseDown script is hooked so existing visual handlers remain.
-- The popup positions itself so the thumb aligns with the cursor on open.
--
-- Usage:
--   local LibPopupSlider = LibStub("LibPopupSlider-1.0")
--   local popup = LibPopupSlider:Create(button, {
--       minValue       = 50,
--       maxValue       = 150,
--       step           = 5,
--       label          = "Scale",
--       formatValue    = function(v) return v .. "%" end,
--       onValueChanged = function(v) ... end,
--       -- Optional overrides:
--       sliderHeight   = 180,
--       sensitivity    = 1,
--       popupWidth     = 44,
--       paddingY       = 4,
--       labelGap       = 4,
--       font           = "Fonts\\FRIZQT__.TTF",
--       fontFlags      = "OUTLINE",
--       fontPaddingX   = 4,
--       fontMinSize    = 6,
--       fontMaxSize    = nil, -- auto max caps at 72 unless overridden
--       fontSize       = nil,
--       labelFontSize  = nil,
--       valueFontSize  = nil,
--       valueFitText   = nil,
--       labelOffsetX   = 0,
--       labelOffsetY   = 0,
--       valueOffsetX   = 0,
--       valueOffsetY   = 0,
--       bgColor        = { r=0.1, g=0.1, b=0.1, a=0.95 },
--       trackColor     = { r=0.5, g=0.5, b=0.5, a=1 },
--       thumbSize      = 20,
--       thumbColor     = { r=1, g=1, b=1, a=1 },
--       showEndMarkers = true,
--       showMiddleMarker = true,
--       markerSize     = 8,
--       markerColor    = { r=0.5, g=0.5, b=0.5, a=1 },
--   })
--
--   popup:SetValue(100)
--   popup:SetValue(100, true) -- update without onValueChanged
--   popup:GetValue()

local MAJOR_VERSION = "LibPopupSlider-1.0"
local MINOR_VERSION = 1

local function raiseError(message, level)
    error(MAJOR_VERSION .. ": " .. message, (level or 1) + 1)
end

if not LibStub then raiseError("requires LibStub.") end
local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local floor = floor
local gmatch = string.gmatch

local MIN_SLIDER_HEIGHT = 72
local MIN_POPUP_WIDTH   = 30
local MIN_PADDING_Y     = 2
local MIN_LABEL_GAP     = 2
local MIN_THUMB_SIZE    = 10
local MIN_MARKER_SIZE   = 4
local MIN_FONT_SIZE     = 1

local DEFAULT_MIN_VALUE          = 0
local DEFAULT_MAX_VALUE          = 100
local DEFAULT_STEP               = 1
local DEFAULT_SLIDER_HEIGHT      = 180
local DEFAULT_SENSITIVITY        = 1
local DEFAULT_POPUP_WIDTH        = 44
local DEFAULT_PADDING_Y          = 4
local DEFAULT_LABEL_GAP          = 4
local DEFAULT_THUMB_SIZE         = 20
local DEFAULT_MARKER_SIZE        = 8
local DEFAULT_SHOW_END_MARKERS   = true
local DEFAULT_SHOW_MIDDLE_MARKER = true
local DEFAULT_FONT_SIZE          = nil
local DEFAULT_LABEL_FONT_SIZE    = nil
local DEFAULT_VALUE_FONT_SIZE    = nil
local DEFAULT_FONT_PADDING_X     = 4
local DEFAULT_FONT_MIN_SIZE      = 6
local DEFAULT_FONT_MAX_SIZE      = nil
local DEFAULT_LABEL_OFFSET_X     = 0
local DEFAULT_LABEL_OFFSET_Y     = 0
local DEFAULT_VALUE_OFFSET_X     = 0
local DEFAULT_VALUE_OFFSET_Y     = 0
local DEFAULT_FORMAT_VALUE       = tostring
local DEFAULT_FONT               = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_FLAGS         = "OUTLINE"
local DEFAULT_VALUE_FIT_TEXT     = nil

local DEFAULT_AUTO_FONT_MAX_SIZE = 72

local FONT_MEASURE_WIDTH  = 4096
local FONT_FIT_FUDGE      = 2
local MAX_VALUE_FIT_STEPS = 1000

-- -----------------------------------------------------------------------------
--- Helpers
-- -----------------------------------------------------------------------------

local function clamp(value, lo, hi)
    return max(lo, min(hi, value))
end

local function getNumberOption(options, key, defaultValue)
    local value = options[key]

    if value == nil then
        return defaultValue
    end

    if type(value) ~= "number" then
        raiseError(key .. " must be a number.", 3)
    end

    return value
end

local function getStringOption(options, key, defaultValue)
    local value = options[key]

    if value == nil then
        return defaultValue
    end

    if type(value) ~= "string" then
        raiseError(key .. " must be a string.", 3)
    end

    return value
end

local function getBooleanOption(options, key, defaultValue)
    local value = options[key]

    if value == nil then
        return defaultValue
    end

    if type(value) ~= "boolean" then
        raiseError(key .. " must be a boolean.", 3)
    end

    return value
end

local function getColorOption(options, key, defaultValue)
    local color = options[key]

    if color == nil then
        return defaultValue
    end

    if type(color) ~= "table" then
        raiseError(key .. " must be a color table.", 3)
    end

    if type(color.r) ~= "number"
        or type(color.g) ~= "number"
        or type(color.b) ~= "number"
    then
        raiseError(key .. " must include numeric r, g, and b values.", 3)
    end

    if color.a ~= nil and type(color.a) ~= "number" then
        raiseError(key .. ".a must be a number.", 3)
    end

    return color
end

local function applyColorTexture(texture, color)
    texture:SetColorTexture(color.r, color.g, color.b, color.a or 1)
end

local function applyVertexColor(texture, color)
    texture:SetVertexColor(color.r, color.g, color.b, color.a or 1)
end

local function setShown(region, shown)
    if shown then
        region:Show()
    else
        region:Hide()
    end
end

local function prepareFontString(fontString)
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end

    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(false)
    end

    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end
end

local function getFontStringWidth(fontString)
    if fontString.GetUnboundedStringWidth then
        return fontString:GetUnboundedStringWidth()
    end

    return fontString:GetStringWidth()
end

local function countDigits(text)
    local digitCount = 0

    for _ in gmatch(text, "%d") do
        digitCount = digitCount + 1
    end

    return digitCount
end

local function fitFontString(
    fontString,
    text,
    fontPath,
    fontFlags,
    fontSize,
    minSize,
    maxSize,
    maxWidth
)
    prepareFontString(fontString)

    if fontSize then
        fontString:SetWidth(FONT_MEASURE_WIDTH)
        fontString:SetFont(fontPath, fontSize, fontFlags)
        fontString:SetText(text)

        local height = fontString:GetStringHeight()
        fontString:SetWidth(maxWidth)

        return fontSize, height
    end

    local minFitSize = floor(minSize + 0.5)
    local maxFitSize = floor(maxSize + 0.5)
    local fitWidth = max(1, maxWidth - FONT_FIT_FUDGE)
    local bestSize = minFitSize

    if maxFitSize < minFitSize then
        maxFitSize = minFitSize
    end

    for size = minFitSize, maxFitSize do
        fontString:SetWidth(FONT_MEASURE_WIDTH)
        fontString:SetFont(fontPath, size, fontFlags)
        fontString:SetText(text)

        if getFontStringWidth(fontString) > fitWidth then
            break
        end

        bestSize = size
    end

    fontString:SetWidth(FONT_MEASURE_WIDTH)
    fontString:SetFont(fontPath, bestSize, fontFlags)
    fontString:SetText(text)

    local height = fontString:GetStringHeight()
    fontString:SetWidth(maxWidth)

    return bestSize, height
end

local function measureTextWidth(
    fontString,
    text,
    fontPath,
    fontFlags,
    fontSize
)
    prepareFontString(fontString)
    fontString:SetWidth(FONT_MEASURE_WIDTH)
    fontString:SetFont(fontPath, fontSize, fontFlags)
    fontString:SetText(text)

    return getFontStringWidth(fontString)
end

local function getValueFitText(
    fontString,
    formatValue,
    minValue,
    maxValue,
    step,
    fontPath,
    fontFlags,
    fontSize
)
    local candidateTexts = {}
    local candidateCount = 0
    local seenTexts = {}
    local maxDigits = -1

    local function addCandidateText(text)
        local digitCount = countDigits(text)

        if digitCount > maxDigits then
            candidateTexts = {}
            candidateCount = 0
            seenTexts = {}
            maxDigits = digitCount
        end

        if digitCount == maxDigits and not seenTexts[text] then
            candidateCount = candidateCount + 1
            candidateTexts[candidateCount] = text
            seenTexts[text] = true
        end
    end

    local function checkValue(value)
        addCandidateText(tostring(formatValue(value)))
    end

    checkValue(minValue)
    checkValue(maxValue)

    local stepCount = floor((maxValue - minValue) / step + 0.5)

    if stepCount > 1 and stepCount <= MAX_VALUE_FIT_STEPS then
        for i = 1, stepCount - 1 do
            checkValue(minValue + i * step)
        end
    end

    local fitText = candidateTexts[1]
    local fitWidth = -1

    for i = 1, candidateCount do
        local text = candidateTexts[i]
        local width = measureTextWidth(
            fontString,
            text,
            fontPath,
            fontFlags,
            fontSize
        )

        if width > fitWidth then
            fitText = text
            fitWidth = width
        end
    end

    return fitText
end

-- -----------------------------------------------------------------------------
--- Create
-- -----------------------------------------------------------------------------

function lib:Create(button, options)
    if not button or not button.HookScript then
        raiseError("Create requires a button frame.", 2)
    end

    if options == nil then
        options = {}
    elseif type(options) ~= "table" then
        raiseError("options must be a table.", 2)
    end

    local minValue         =  getNumberOption(options, "minValue",         DEFAULT_MIN_VALUE)
    local maxValue         =  getNumberOption(options, "maxValue",         DEFAULT_MAX_VALUE)
    local step             =  getNumberOption(options, "step",             DEFAULT_STEP)
    local sliderH          =  getNumberOption(options, "sliderHeight",     DEFAULT_SLIDER_HEIGHT)
    local sensitivity      =  getNumberOption(options, "sensitivity",      DEFAULT_SENSITIVITY)
    local popupW           =  getNumberOption(options, "popupWidth",       DEFAULT_POPUP_WIDTH)
    local padY             =  getNumberOption(options, "paddingY",         DEFAULT_PADDING_Y)
    local labelGap         =  getNumberOption(options, "labelGap",         DEFAULT_LABEL_GAP)
    local thumbSize        =  getNumberOption(options, "thumbSize",        DEFAULT_THUMB_SIZE)
    local markerSize       =  getNumberOption(options, "markerSize",       DEFAULT_MARKER_SIZE)
    local showEndMarkers   = getBooleanOption(options, "showEndMarkers",   DEFAULT_SHOW_END_MARKERS)
    local showMiddleMarker = getBooleanOption(options, "showMiddleMarker", DEFAULT_SHOW_MIDDLE_MARKER)
    local fontSize         =  getNumberOption(options, "fontSize",         DEFAULT_FONT_SIZE)
    local labelFontSize    =  getNumberOption(options, "labelFontSize",    DEFAULT_LABEL_FONT_SIZE or fontSize)
    local valueFontSize    =  getNumberOption(options, "valueFontSize",    DEFAULT_VALUE_FONT_SIZE or fontSize)
    local fontPaddingX     =  getNumberOption(options, "fontPaddingX",     DEFAULT_FONT_PADDING_X)
    local fontMinSize      =  getNumberOption(options, "fontMinSize",      DEFAULT_FONT_MIN_SIZE)
    local fontMaxSize      =  getNumberOption(options, "fontMaxSize",      DEFAULT_FONT_MAX_SIZE)
    local labelOffsetX     =  getNumberOption(options, "labelOffsetX",     DEFAULT_LABEL_OFFSET_X)
    local labelOffsetY     =  getNumberOption(options, "labelOffsetY",     DEFAULT_LABEL_OFFSET_Y)
    local valueOffsetX     =  getNumberOption(options, "valueOffsetX",     DEFAULT_VALUE_OFFSET_X)
    local valueOffsetY     =  getNumberOption(options, "valueOffsetY",     DEFAULT_VALUE_OFFSET_Y)
    local formatValue      =                 options.formatValue or        DEFAULT_FORMAT_VALUE
    local font             =  getStringOption(options, "font",             DEFAULT_FONT)
    local fontFlags        =  getStringOption(options, "fontFlags",        DEFAULT_FONT_FLAGS)
    local valueFitText     =  getStringOption(options, "valueFitText",     DEFAULT_VALUE_FIT_TEXT)

    local bgColor = getColorOption(options, "bgColor",
        { r = 0.1, g = 0.1, b = 0.1, a = 0.95 })
    local trackColor = getColorOption(options, "trackColor",
        { r = 0.5, g = 0.5, b = 0.5, a = 1 })
    local markerColor = getColorOption(options, "markerColor", trackColor)
    local thumbColor = getColorOption(options, "thumbColor", nil)

    if maxValue <= minValue then
        raiseError("maxValue must be greater than minValue.", 2)
    end

    if step <= 0 then
        raiseError("step must be greater than 0.", 1)
    end

    if sensitivity <= 0 then
        raiseError("sensitivity must be greater than 0.", 2)
    end

    if sliderH < MIN_SLIDER_HEIGHT then
        raiseError("sliderHeight must be at least "
            .. MIN_SLIDER_HEIGHT .. ".", 2)
    end

    if popupW < MIN_POPUP_WIDTH then
        raiseError("popupWidth must be at least " .. MIN_POPUP_WIDTH .. ".", 2)
    end

    if padY < MIN_PADDING_Y then
        raiseError("paddingY must be at least " .. MIN_PADDING_Y .. ".", 2)
    end

    if labelGap < MIN_LABEL_GAP then
        raiseError("labelGap must be at least " .. MIN_LABEL_GAP .. ".", 2)
    end

    if thumbSize < MIN_THUMB_SIZE then
        raiseError("thumbSize must be at least " .. MIN_THUMB_SIZE .. ".", 2)
    end

    if sliderH <= thumbSize then
        raiseError("sliderHeight must be greater than thumbSize.", 2)
    end

    if markerSize < MIN_MARKER_SIZE then
        raiseError("markerSize must be at least " .. MIN_MARKER_SIZE .. ".", 2)
    end

    if fontPaddingX < 0 then
        raiseError("fontPaddingX must be 0 or greater.", 2)
    end

    if fontMinSize < MIN_FONT_SIZE then
        raiseError("fontMinSize must be at least " .. MIN_FONT_SIZE .. ".", 2)
    end

    if fontMaxSize and fontMaxSize < fontMinSize then
        raiseError("fontMaxSize must be at least fontMinSize.", 2)
    end

    if fontSize and fontSize < MIN_FONT_SIZE then
        raiseError("fontSize must be at least " .. MIN_FONT_SIZE .. ".", 2)
    end

    if labelFontSize and labelFontSize < MIN_FONT_SIZE then
        raiseError("labelFontSize must be at least "
            .. MIN_FONT_SIZE .. ".", 2)
    end

    if valueFontSize and valueFontSize < MIN_FONT_SIZE then
        raiseError("valueFontSize must be at least "
            .. MIN_FONT_SIZE .. ".", 2)
    end

    local fontFitWidth = max(1, popupW - fontPaddingX * 2)
    local autoFontMaxSize = fontMaxSize or max(
        fontMinSize,
        min(fontFitWidth, DEFAULT_AUTO_FONT_MAX_SIZE)
    )

    -- -----------------------------------------------------------------
    --- Popup frame
    -- -----------------------------------------------------------------

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetWidth(popupW)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 1)
    popup:SetBackdropBorderColor(0, 0, 0, 1)
    popup:Hide()

    -- -----------------------------------------------------------------
    --- Track and slider
    -- -----------------------------------------------------------------

    local markerInset = thumbSize / 2

    popup.track = popup:CreateTexture(nil, "ARTWORK")
    popup.track:SetSize(2, sliderH - markerInset * 2)
    applyColorTexture(popup.track, trackColor)

    popup.slider = CreateFrame("Slider", nil, popup)
    popup.slider:SetOrientation("VERTICAL")
    popup.slider:SetSize(thumbSize, sliderH)
    popup.track:SetPoint("CENTER", popup.slider, "CENTER")
    popup.slider:SetMinMaxValues(minValue, maxValue)
    popup.slider:SetValueStep(step)
    popup.slider:SetObeyStepOnDrag(true)
    popup.slider:EnableMouse(false)

    local thumb = popup.slider:CreateTexture(nil, "ARTWORK")
    thumb:SetAtlas("Minimal_SliderBar_Button")
    thumb:SetSize(thumbSize, thumbSize)
    if thumbColor then
        applyVertexColor(thumb, thumbColor)
    end
    popup.slider:SetThumbTexture(thumb)

    -- -----------------------------------------------------------------
    --- Diamond markers (top, center, bottom)
    -- -----------------------------------------------------------------

    local function createDiamond(anchor, relPoint)
        local d = popup:CreateTexture(nil, "OVERLAY")
        d:SetSize(markerSize, markerSize)
        d:SetPoint("CENTER", anchor, relPoint)
        applyColorTexture(d, markerColor)
        d:SetRotation(math.rad(45))

        return d
    end

    popup.diamondTop = createDiamond(popup.slider, "TOP")
    popup.diamondTop:ClearAllPoints()
    popup.diamondTop:SetPoint("CENTER", popup.slider, "TOP", 0, -markerInset)
    setShown(popup.diamondTop, showEndMarkers)

    popup.diamondCenter = createDiamond(popup.slider, "CENTER")
    setShown(popup.diamondCenter, showMiddleMarker)

    popup.diamondBottom = createDiamond(popup.slider, "BOTTOM")
    popup.diamondBottom:ClearAllPoints()
    popup.diamondBottom:SetPoint("CENTER", popup.slider, "BOTTOM",
        0, markerInset)
    setShown(popup.diamondBottom, showEndMarkers)

    -- -----------------------------------------------------------------
    --- Labels
    -- -----------------------------------------------------------------

    popup.label = popup:CreateFontString(nil, "OVERLAY")
    popup.label:SetTextColor(1, 1, 1)

    popup.value = popup:CreateFontString(nil, "OVERLAY")
    popup.value:SetTextColor(1, 1, 1)

    local currentValue
    local valueDisplaySize = valueFontSize or fontSize or fontMinSize
    local topBandH
    local bottomBandH
    local popupH
    local layoutResolved = false

    local function layoutPopup()
        if layoutResolved then
            return
        end

        popup.label:ClearAllPoints()
        popup.label:SetPoint("BOTTOM", popup.slider, "TOP",
            labelOffsetX, labelGap + labelOffsetY)
        popup.label:SetWidth(fontFitWidth)
        popup.label:SetJustifyH("CENTER")

        local _, labelHeight = fitFontString(
            popup.label,
            options.label or "",
            font,
            fontFlags,
            labelFontSize,
            fontMinSize,
            autoFontMaxSize,
            fontFitWidth
        )

        popup.value:ClearAllPoints()
        popup.value:SetPoint("TOP", popup.slider, "BOTTOM",
            valueOffsetX, -labelGap + valueOffsetY)
        popup.value:SetWidth(fontFitWidth)
        popup.value:SetJustifyH("CENTER")

        local fitText = valueFitText or getValueFitText(
            popup.value,
            formatValue,
            minValue,
            maxValue,
            step,
            font,
            fontFlags,
            fontMinSize
        )
        local valueHeight

        valueDisplaySize, valueHeight = fitFontString(
            popup.value,
            fitText,
            font,
            fontFlags,
            valueFontSize,
            fontMinSize,
            autoFontMaxSize,
            fontFitWidth
        )

        topBandH = padY + labelHeight + labelGap
        bottomBandH = padY + valueHeight + labelGap
        popupH = topBandH + sliderH + bottomBandH

        popup:SetHeight(popupH)
        popup.slider:ClearAllPoints()
        popup.slider:SetPoint("CENTER", popup, "BOTTOM",
            0, bottomBandH + sliderH / 2)

        if currentValue ~= nil then
            popup.value:SetFont(font, valueDisplaySize, fontFlags)
            popup.value:SetText(formatValue(currentValue))
        end

        layoutResolved = true
    end

    -- -----------------------------------------------------------------
    --- Value management
    -- -----------------------------------------------------------------

    local function toSlider(value)
        return maxValue + minValue - value
    end

    local function fromSlider(value)
        return maxValue + minValue - value
    end

    local function snap(value)
        return floor(value / step + 0.5) * step
    end

    local function setValue(value, silent)
        value = clamp(snap(value), minValue, maxValue)

        if currentValue == value then
            return false
        end

        currentValue = value
        popup.value:SetFont(font, valueDisplaySize, fontFlags)
        popup.value:SetText(formatValue(value))
        popup.slider:SetValue(toSlider(value))

        if not silent and options.onValueChanged then
            options.onValueChanged(value)
        end

        return true
    end

    -- -----------------------------------------------------------------
    --- Drag logic
    -- -----------------------------------------------------------------

    local dragStartY
    local dragStartValue

    local function finishDrag()
        if not dragStartY then
            return
        end

        dragStartY = nil
        dragStartValue = nil
        popup:SetScript("OnUpdate", nil)
        popup:Hide()
    end

    button:HookScript("OnMouseDown", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then
            return
        end

        local mouseX, mouseY = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        dragStartY = mouseY / uiScale
        dragStartValue = currentValue
            or fromSlider(popup.slider:GetValue())
        currentValue = currentValue or dragStartValue

        popup:ClearAllPoints()
        popup:SetPoint("TOP", UIParent, "BOTTOMLEFT", 0, -10000)
        popup:Show()
        layoutPopup()

        local thumbFraction = (maxValue - dragStartValue)
            / (maxValue - minValue)
        local thumbOffset = topBandH + thumbSize / 2
            + thumbFraction * (sliderH - thumbSize)

        local popupX = mouseX / uiScale
        local popupY = dragStartY + thumbOffset
        local screenW = UIParent:GetWidth()
        local screenH = UIParent:GetHeight()

        popupX = clamp(popupX, popupW / 2, screenW - popupW / 2)
        popupY = clamp(popupY, popupH, screenH)

        popup:ClearAllPoints()
        popup:SetPoint("TOP", UIParent, "BOTTOMLEFT", popupX, popupY)

        popup:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                finishDrag()

                return
            end

            local _, cursorY = GetCursorPosition()
            cursorY = cursorY / UIParent:GetEffectiveScale()

            local delta = cursorY - dragStartY
            local pixelsPerUnit = sliderH * sensitivity
                / (maxValue - minValue)

            local rawValue = dragStartValue + delta / pixelsPerUnit

            setValue(rawValue)

            if rawValue > maxValue or rawValue < minValue then
                dragStartY = cursorY
                dragStartValue = currentValue
            end
        end)
    end)

    button:HookScript("OnHide", finishDrag)

    popup.slider:SetScript("OnValueChanged", function(self, value)
        setValue(fromSlider(value))
    end)

    -- -----------------------------------------------------------------
    --- Public API
    -- -----------------------------------------------------------------

    popup.SetValue = function(self, value, silent)
        setValue(value, silent)
    end

    popup.GetValue = function()
        return currentValue
    end

    return popup
end
