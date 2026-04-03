## While trying to save a layout
7x RaidGroupManager/UI/LayoutPanel.lua:245: attempt to index field 'editBox' (a nil value)
[RaidGroupManager/UI/LayoutPanel.lua]:245: in function 'OnAccept'
[Blizzard_StaticPopup/StaticPopup.lua]:680: in function 'StaticPopup_OnClick'
[Blizzard_StaticPopup_Game/GameDialog.lua]:46: in function <...faceBlizzard_StaticPopup_Game/GameDialog.lua:44>


Locals:
self = StaticPopup1 {
 ProgressBarSpacer = Texture {
 }
 visibleButtons = <table> {
 }
 widthPadding = 0
 minimumWidth = 320
 TopEdge = Texture {
 }
 ButtonContainer = Frame {
 }
 LeftEdge = Texture {
 }
 SubText = FontString {
 }
 MoneyInputFrame = StaticPopup1MoneyInputFrame {
 dirty = false
 }
 Spinner = Frame {
 }
 MoneyFrame = StaticPopup1MoneyFrame {
 }
 timeleft = 0
 Separator = Texture {
 }
 BG = Frame {
 }
 _eqolScaleResetHooked = true
 TopSpacer = FontString {
 }
 _eqolScaleHoverHooked = true
 PixelSnapDisabled = true
 previousRegionKey = "ButtonContainer"
 ProgressBarBorder = Texture {
 }
 numButtons = 2
 BottomRightCorner = Texture {
 }
 RightEdge = Texture {
 }
 _eqolDragHooked = true
 which = "RGM_SAVE_LAYOUT"
 Center = Texture {
 }
 hideOnEscape = true
 ItemFrame = Frame {
 }
 BottomEdge = Texture {
 }
 BottomLeftCorner = Texture {
 }
 TopRightCorner = Texture {
 }
 TopLeftCorner = Texture {
 }
 _eqolMoverDefaults = <table> {
 }
 _eqolLayoutEntryId = "StaticPopup"
 template = "Transparent"
 Buttons = <table> {
 }
 _eqolTimeoutReleaseOnHideHooked = true
 EditBox = StaticPopup1EditBox {
 }
 Dropdown = Button {
 }
 DarkOverlay = Frame {
 }
 _eqolMoveDragTargets = <table> {
 }
 _eqolLayoutHooks = true
 _eqolScaleTargetHooked = true
 backdropInfo = <table> {
 }
 CoverFrame = Frame {
 }
 AlertIcon = Texture {
 }
 _eqolDefaultPoints = <table> {
 }
 ProgressBarFill = Texture {
 }
 _eqolMoverEntry = <table> {
 }
 dialogInfo = <table> {
 }
 Text = StaticPopup1Text {
 }
 CloseButton = StaticPopup1CloseButton {
 }
 ExtraButton = StaticPopup1ExtraButton {
 }
 heightPadding = 16
}
(*temporary) = nil
(*temporary) = nil
(*temporary) = nil
(*temporary) = nil
(*temporary) = nil
(*temporary) = "attempt to index field 'editBox' (a nil value)"
addon = <table> {
 moveIndex = 0
 slots = <table> {
 }
 modules = <table> {
 }
 baseName = "RaidGroupManager"
 unassignedContent = Frame {
 }
 exportEditBox = EditBox {
 }
 defaultModuleState = true
 autoSave = false
 layoutContent = Frame {
 }
 FONT = "Interface\AddOns\RaidGroupManager\Media\fonts\PTSansNarrow-Bold.ttf"
 enabledState = true
 GROUP_PADDING = 8
 importEditBox = EditBox {
 }
 importFrame = Frame {
 }
 exportFormat = 4
 exportFrame = Frame {
 }
 layoutRows = <table> {
 }
 unassignedRows = <table> {
 }
 defaultModuleLibraries = <table> {
 }
 db = <table> {
 }
 unassignedMode = 2
 name = "RaidGroupManager"
 orderedModules = <table> {
 }
 SLOT_HEIGHT = 20
 applyButton = Button {
 }
 moveQueue = <table> {
 }
 assignState = 0
 mainFrame = RGMFrame {
 }
 SLOT_WIDTH = 150
 TITLE_HEIGHT = 28
}

5x RaidGroupManager/UI/LayoutPanel.lua:251: attempt to index field 'editBox' (a nil value)
[RaidGroupManager/UI/LayoutPanel.lua]:251: in function 'OnShow'
[Blizzard_StaticPopup/StaticPopup.lua]:560: in function 'StaticPopup_OnShow'
[Blizzard_StaticPopup_Game/GameDialog.lua]:685: in function <...faceBlizzard_StaticPopup_Game/GameDialog.lua:684>
[C]: ?
[C]: ?
[C]: ?
[C]: in function 'Show'
[Blizzard_StaticPopup/StaticPopup.lua]:391: in function <Blizzard_StaticPopup/StaticPopup.lua:278>
[C]: ?
[C]: ?
[C]: ?
[C]: ?
[C]: in function 'StaticPopup_Show'
[RaidGroupManager/UI/LayoutPanel.lua]:260: in function 'PromptSaveLayout'
[RaidGroupManager/UI/MainFrame.lua]:171: in function <RaidGroupManager/UI/MainFrame.lua:170>


Locals:
self = StaticPopup1 {
 ProgressBarSpacer = Texture {
 }
 visibleButtons = <table> {
 }
 widthPadding = 0
 minimumWidth = 320
 TopEdge = Texture {
 }
 ButtonContainer = Frame {
 }
 LeftEdge = Texture {
 }
 SubText = FontString {
 }
 MoneyInputFrame = StaticPopup1MoneyInputFrame {
 }
 dirty = false
 Spinner = Frame {
 }
 MoneyFrame = StaticPopup1MoneyFrame {
 }
 timeleft = 0
 Separator = Texture {
 }
 BG = Frame {
 }
 _eqolScaleResetHooked = true
 TopSpacer = FontString {
 }
 _eqolScaleHoverHooked = true
 PixelSnapDisabled = true
 previousRegionKey = "ButtonContainer"
 ProgressBarBorder = Texture {
 }
 numButtons = 2
 BottomRightCorner = Texture {
 }
 RightEdge = Texture {
 }
 _eqolDragHooked = true
 which = "RGM_SAVE_LAYOUT"
 Center = Texture {
 }
 hideOnEscape = true
 ItemFrame = Frame {
 }
 BottomEdge = Texture {
 }
 BottomLeftCorner = Texture {
 }
 TopRightCorner = Texture {
 }
 TopLeftCorner = Texture {
 }
 _eqolMoverDefaults = <table> {
 }
 _eqolLayoutEntryId = "StaticPopup"
 template = "Transparent"
 Buttons = <table> {
 }
 _eqolTimeoutReleaseOnHideHooked = true
 EditBox = StaticPopup1EditBox {
 }
 Dropdown = Button {
 }
 DarkOverlay = Frame {
 }
 _eqolMoveDragTargets = <table> {
 }
 _eqolLayoutHooks = true
 _eqolScaleTargetHooked = true
 backdropInfo = <table> {
 }
 CoverFrame = Frame {
 }
 AlertIcon = Texture {
 }
 _eqolDefaultPoints = <table> {
 }
 ProgressBarFill = Texture {
 }
 _eqolMoverEntry = <table> {
 }
 dialogInfo = <table> {
 }
 Text = StaticPopup1Text {
 }
 CloseButton = StaticPopup1CloseButton {
 }
 ExtraButton = StaticPopup1ExtraButton {
 }
 heightPadding = 16
}
(*temporary) = nil
(*temporary) = nil
(*temporary) = "attempt to index field 'editBox' (a nil value)"



## NEXT ERROR
