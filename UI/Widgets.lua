local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local PixelPerfect = addon.PixelPerfect
local FONT = addon.FONT
local TITLE_HEIGHT = addon.TITLE_HEIGHT

local COLOR_BLACK = { r = 0, g = 0, b = 0, a = 1 }
local BUTTON_BACKGROUND = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
local BUTTON_BORDER_NORMAL = { r = 0.45, g = 0.45, b = 0.45, a = 1 }
local BUTTON_BORDER_HOVER = COLOR_BLACK
local BUTTON_HIGHLIGHT = { r = 0.3, g = 0.3, b = 0.3, a = 0.5 }
local TITLE_BACKGROUND = { r = 0, g = 0, b = 0, a = 0.2 }
local WINDOW_BACKGROUND = { r = 0.05, g = 0.05, b = 0.05, a = 0.95 }

local CLOSE_TEXTURE = "Interface\\AddOns\\RaidGroupManager\\Media\\Textures\\Close"

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

    button:SetScript("OnEnter", function(self)
        self.highlight:Show()
        PixelPerfect.SetBorderColor(self, BUTTON_BORDER_HOVER)
    end)

    button:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        PixelPerfect.SetBorderColor(self, BUTTON_BORDER_NORMAL)
    end)

    return button
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
        PixelPerfect.Point(titleBar.text, "LEFT", titleBar, "LEFT", 8, 0)

        close:ClearAllPoints()
        PixelPerfect.Point(close, "RIGHT", titleBar, "RIGHT", -6, 1)
    end)

    frame:HookScript("OnShow", PixelPerfect.RequestRefresh)

    return frame, titleBar
end
