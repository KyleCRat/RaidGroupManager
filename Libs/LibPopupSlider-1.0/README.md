# LibPopupSlider-1.0

A vertical drag-to-adjust slider popup for WoW addons. Click-and-drag on a button opens a slider at the cursor; release to dismiss.

## Usage

```lua
local LibPopupSlider = LibStub("LibPopupSlider-1.0")

local popup = LibPopupSlider:Create(myButton, {
    minValue       = 50,
    maxValue       = 150,
    step           = 5,
    label          = "Scale",
    formatValue    = function(v) return v .. "%" end,
    onValueChanged = function(v)
        myFrame:SetScale(v / 100)
    end,
})

-- Set initial value
popup:SetValue(100)

-- Sync display without firing onValueChanged
popup:SetValue(100, true)

-- Read current value
local current = popup:GetValue()
```

## Options

| Option | Default | Description |
|---|---|---|
| `minValue` | `0` | Minimum value |
| `maxValue` | `100` | Maximum value |
| `step` | `1` | Snap increment |
| `label` | `""` | Label above the slider |
| `formatValue` | `tostring` | Format the value display |
| `onValueChanged` | `nil` | Callback on value change |
| `sliderHeight` | `180` | Track height in pixels, minimum `72` |
| `sensitivity` | `1` | Cursor-to-thumb ratio (1 = 1:1) |
| `popupWidth` | `44` | Popup frame width, minimum `30` |
| `paddingY` | `4` | Edge padding above label and below value, minimum `2` |
| `labelGap` | `4` | Gap between labels and slider, minimum `2` |
| `font` | `FRIZQT__.TTF` | Font for labels |
| `fontFlags` | `OUTLINE` | Font flags passed to `SetFont()` |
| `fontPaddingX` | `4` | Horizontal padding used by auto-fit text sizing |
| `fontMinSize` | `6` | Minimum auto-fit font size |
| `fontMaxSize` | auto, capped at `72` | Maximum auto-fit font size |
| `fontSize` | auto | Explicit size for both label and value |
| `labelFontSize` | `fontSize` | Explicit size for label only |
| `valueFontSize` | `fontSize` | Explicit size for value only |
| `valueFitText` | widest value | Text used to calculate value auto-fit size |
| `labelOffsetX` | `0` | Label horizontal offset |
| `labelOffsetY` | `0` | Label vertical offset |
| `valueOffsetX` | `0` | Value horizontal offset |
| `valueOffsetY` | `0` | Value vertical offset |
| `bgColor` | dark gray | `{ r, g, b, a }` background |
| `trackColor` | mid gray | `{ r, g, b, a }` track color |
| `thumbSize` | `20` | Thumb width and height, minimum `10` |
| `thumbColor` | atlas default | Optional `{ r, g, b, a }` thumb tint |
| `showEndMarkers` | `true` | Show top and bottom diamond markers |
| `showMiddleMarker` | `true` | Show center diamond marker |
| `markerSize` | `8` | Diamond marker width and height, minimum `4` |
| `markerColor` | `trackColor` | `{ r, g, b, a }` marker color |

## Implementation Notes

**Button event handling** - The library hooks the button's `OnMouseDown`
script so existing visual button handlers can still run. Use a dedicated
button or avoid assigning another left-mouse drag action to the same button.

**Vertical slider art** - WoW's `MinimalSliderTemplate` is horizontal-only; its track textures don't rotate. This library uses a bare `Slider` frame with a custom track line and the `Minimal_SliderBar_Button` atlas for the thumb.

**Auto-fit text** - If no explicit font size is provided, label and value text
start at `fontMinSize` and grow to the largest size whose rendered width fits
inside `popupWidth - fontPaddingX * 2`. The automatic maximum is capped at 72
unless `fontMaxSize` is set. The popup height is then calculated from the fitted
label/value heights, `sliderHeight`, `paddingY`, and `labelGap`. This fit is
calculated the first time the popup opens, then reused. Set `fontSize`,
`labelFontSize`, or `valueFontSize` to bypass auto-fit sizing.

**Stable value size** - The value font size is calculated from `valueFitText`,
or from the widest formatted value among the highest-digit values in the range
when the range has no more than 1000 steps. It is cached after the first popup
open and does not resize while dragging between shorter and longer values.

**Silent value sync** - `popup:SetValue(value)` updates the popup and fires
`onValueChanged` when the value changes. Pass `true` as the second argument to
update the popup without firing the callback: `popup:SetValue(value, true)`.

**Value inversion** - WoW vertical sliders map min=top, max=bottom. The library inverts internally so higher values correspond to dragging up.

**Absolute drag tracking** - The drag delta is computed from the original mousedown position, not incrementally per frame. This prevents compounding rounding error when step-snapping, which would otherwise make the thumb drift ahead of the cursor.

**Boundary reset** - When the cursor overshoots past min/max, the drag origin resets so reversing direction responds immediately with no dead zone.

**Thumb-aligned positioning** - The popup positions itself so the thumb (at its current value) appears directly under the cursor on open.

**Marker positioning** - End markers are offset by half the thumb size so they
align with the usable thumb travel, even when `thumbSize` changes.

**Screen clamping** - The popup is clamped to UIParent bounds so it never opens off-screen.
