local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local PixelPerfect = {}
addon.PixelPerfect = PixelPerfect

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local DEFAULT_BORDER_COLOR = { r = 0, g = 0, b = 0, a = 1 }
local LAYOUT_REFRESH_PASSES = 2

local borders = setmetatable({}, { __mode = "k" })
local layouts = setmetatable({}, { __mode = "k" })
local refreshPending = false
local refreshing = false

local function SetTextureColor(texture, color)
    texture:SetVertexColor(color.r, color.g, color.b, color.a or 1)
end

function PixelPerfect.DisablePixelSnap(texture)
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
end

function PixelPerfect.Scale(region, value, minPixels)
    return PixelUtil.GetNearestPixelSize(value or 0, region:GetEffectiveScale(), minPixels)
end

function PixelPerfect.Size(region, width, height, minWidthPixels, minHeightPixels)
    PixelUtil.SetSize(region, width, height, minWidthPixels, minHeightPixels)
end

function PixelPerfect.Width(region, width, minPixels)
    PixelUtil.SetWidth(region, width, minPixels)
end

function PixelPerfect.Height(region, height, minPixels)
    PixelUtil.SetHeight(region, height, minPixels)
end

function PixelPerfect.Point(region, point, relativeTo, relativePoint, offsetX, offsetY, minOffsetXPixels, minOffsetYPixels)
    PixelUtil.SetPoint(
        region,
        point,
        relativeTo,
        relativePoint,
        offsetX or 0,
        offsetY or 0,
        minOffsetXPixels,
        minOffsetYPixels
    )
end

function PixelPerfect.SnapCurrentPoint(region)
    local point, relativeTo, relativePoint, offsetX, offsetY = region:GetPoint(1)
    if not point then
        return
    end

    region:ClearAllPoints()
    PixelPerfect.Point(
        region,
        point,
        relativeTo or UIParent,
        relativePoint or point,
        offsetX or 0,
        offsetY or 0
    )
end

function PixelPerfect.CreateBackground(frame, color, drawLayer, subLevel)
    local texture = frame:CreateTexture(nil, drawLayer or "BACKGROUND", nil, subLevel)
    texture:SetAllPoints()
    texture:SetTexture(WHITE_TEXTURE)
    PixelPerfect.DisablePixelSnap(texture)
    SetTextureColor(texture, color)

    return texture
end

local function RefreshBorder(frame, border)
    local size = border.size
    if size <= 0 then
        border.container:Hide()

        return
    end

    border.container:SetFrameLevel(frame:GetFrameLevel() + 1)
    border.container:Show()

    local pixelSize = PixelUtil.GetPixelToUIUnitFactor() / border.container:GetEffectiveScale()
    local edgeSize = math.max(1, math.floor(size + 0.5)) * pixelSize
    local top = border.top
    local bottom = border.bottom
    local left = border.left
    local right = border.right

    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", border.container, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", border.container, "TOPRIGHT", 0, 0)
    top:SetHeight(edgeSize)

    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", border.container, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", border.container, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(edgeSize)

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", border.container, "TOPLEFT", 0, -edgeSize)
    left:SetPoint("BOTTOMLEFT", border.container, "BOTTOMLEFT", 0, edgeSize)
    left:SetWidth(edgeSize)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", border.container, "TOPRIGHT", 0, -edgeSize)
    right:SetPoint("BOTTOMRIGHT", border.container, "BOTTOMRIGHT", 0, edgeSize)
    right:SetWidth(edgeSize)
end

local function CreateBorderTexture(container, drawLayer, subLevel, color)
    local texture = container:CreateTexture(nil, drawLayer, nil, subLevel)
    texture:SetTexture(WHITE_TEXTURE)
    PixelPerfect.DisablePixelSnap(texture)
    SetTextureColor(texture, color)

    return texture
end

function PixelPerfect.CreateBorder(frame, size, color, drawLayer, subLevel)
    local border = borders[frame]
    if border then
        border.size = size or border.size
        PixelPerfect.SetBorderColor(frame, color or border.color)
        RefreshBorder(frame, border)

        return border.container
    end

    drawLayer = drawLayer or "OVERLAY"
    subLevel = subLevel or 7
    color = color or DEFAULT_BORDER_COLOR

    local container = CreateFrame("Frame", nil, frame)
    container:SetAllPoints(frame)
    container:EnableMouse(false)

    border = {
        container = container,
        size = size or 1,
        color = color,
        top = CreateBorderTexture(container, drawLayer, subLevel, color),
        bottom = CreateBorderTexture(container, drawLayer, subLevel, color),
        left = CreateBorderTexture(container, drawLayer, subLevel, color),
        right = CreateBorderTexture(container, drawLayer, subLevel, color),
    }
    borders[frame] = border
    RefreshBorder(frame, border)
    PixelPerfect.RequestRefresh()

    return container
end

function PixelPerfect.SetBorderColor(frame, color)
    local border = borders[frame]
    border.color = color
    SetTextureColor(border.top, color)
    SetTextureColor(border.bottom, color)
    SetTextureColor(border.left, color)
    SetTextureColor(border.right, color)
end

function PixelPerfect.SetBorderSize(frame, size)
    local border = borders[frame]
    border.size = size
    RefreshBorder(frame, border)
end

function PixelPerfect.CreateSurface(frame, backgroundColor, borderColor, borderSize)
    local background = PixelPerfect.CreateBackground(frame, backgroundColor)
    if borderColor then
        PixelPerfect.CreateBorder(frame, borderSize or 1, borderColor)
    end

    return background
end

function PixelPerfect.RegisterLayout(owner, callback)
    local callbacks = layouts[owner]
    if not callbacks then
        callbacks = {}
        layouts[owner] = callbacks
    end

    callbacks[#callbacks + 1] = callback
    callback()
    PixelPerfect.RequestRefresh()
end

local function RefreshRegisteredGeometry()
    -- A second pass lets child layouts observe parent dimensions snapped during
    -- the first pass without relying on weak-table iteration order.
    for _ = 1, LAYOUT_REFRESH_PASSES do
        for _, callbacks in pairs(layouts) do
            for index = 1, #callbacks do
                callbacks[index]()
            end
        end
    end

    for frame, border in pairs(borders) do
        RefreshBorder(frame, border)
    end
end

function PixelPerfect.RefreshAll()
    if refreshing then
        return
    end

    refreshing = true
    local success, message = pcall(RefreshRegisteredGeometry)
    refreshing = false

    if not success then
        error(message, 0)
    end
end

function PixelPerfect.RequestRefresh()
    if refreshPending then
        return
    end

    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        PixelPerfect.RefreshAll()
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", PixelPerfect.RequestRefresh)
