local addon = LibStub("AceAddon-3.0"):NewAddon("RaidGroupManager",
    "AceConsole-3.0", "AceEvent-3.0", "AceSerializer-3.0")

addon.FONT = "Interface\\AddOns\\RaidGroupManager\\Media\\fonts\\PTSansNarrow-Bold.ttf"

addon.SLOT_WIDTH = 150
addon.SLOT_HEIGHT = 20
addon.GROUP_PADDING = 8
addon.TITLE_HEIGHT = 28

local defaults = {
    profile = {
        minimap = { hide = false },
        layouts = {},
    },
}

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RaidGroupManagerDB", defaults, true)
    self.slots = {}
    self.selectedLayout = nil
    self.autoSave = false

    self:RegisterChatCommand("rgm", "SlashCommand")
    self:SetupMinimapButton()
end

function addon:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")
end

function addon:OnRosterUpdate()
    if not self.mainFrame or not self.mainFrame:IsShown() then
        return
    end

    self:RefreshAllSlots()
    self:RefreshUnassigned()
end

function addon:SlashCommand(input)
    local cmd = self:GetArgs(input, 1)

    if not cmd or cmd == "" then
        self:ToggleMainFrame()

        return
    end

    if cmd == "apply" then
        local _, layoutName = self:GetArgs(input, 2, nil, cmd)
        if not layoutName or layoutName == "" then
            self:Print("Usage: /rgm apply <layout name>")

            return
        end

        local layout = self:FindLayoutByName(layoutName)
        if not layout then
            self:Print("Layout not found: " .. layoutName)

            return
        end

        self:LoadLayoutToGrid(layout)
        self:StartApply()

        return
    end

    if cmd == "help" then
        self:Print("Commands:")
        self:Print("  /rgm - Toggle the main window")
        self:Print("  /rgm apply <name> - Apply a saved layout")
        self:Print("  /rgm help - Show this help")

        return
    end

    self:Print("Unknown command. Type /rgm help for usage.")
end

function addon:FindLayoutByName(name)
    local nameLower = name:lower()
    for _, layout in ipairs(self.db.profile.layouts) do
        if layout.name:lower() == nameLower then
            return layout
        end
    end

    return nil
end

function addon:ToggleMainFrame()
    if not self.mainFrame then
        self:CreateMainFrame()
    end

    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:RefreshAllSlots()
        self:RefreshUnassigned()
    end
end

-- Strip realm suffix for same-realm comparisons
function addon:NormalizeName(name)
    if not name then
        return nil
    end

    local dashPos = name:find("-")
    if dashPos then
        return name:sub(1, dashPos - 1)
    end

    return name
end

-- Build a lookup table of current raid members: normalizedName -> { name, class, role, subgroup, raidIndex }
function addon:GetRaidRoster()
    local roster = {}
    local count = GetNumGroupMembers()

    if not IsInRaid() or count == 0 then
        return roster
    end

    for i = 1, count do
        local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
        if name then
            local normalized = self:NormalizeName(name)
            local role = UnitGroupRolesAssigned(name)
            roster[normalized] = {
                name = name,
                normalizedName = normalized,
                class = class,
                role = role,
                subgroup = subgroup,
                raidIndex = i,
            }
        end
    end

    return roster
end

-- Get the text from a grid slot, trimmed
function addon:GetSlotText(slotIndex)
    local slot = self.slots[slotIndex]
    if not slot then
        return ""
    end

    local text = slot.editBox:GetText()

    return strtrim(text or "")
end

-- Set the text of a grid slot
function addon:SetSlotText(slotIndex, text)
    local slot = self.slots[slotIndex]
    if not slot then
        return
    end

    slot.editBox:SetText(text or "")
    slot.editBox:SetCursorPosition(0)
end

-- Get all 40 slot texts as a table
function addon:GetGridState()
    local state = {}
    for i = 1, 40 do
        state[i] = self:GetSlotText(i)
    end

    return state
end

-- Load a layout's slot data into the grid
function addon:LoadLayoutToGrid(layout)
    for i = 1, 40 do
        local name = layout.slots and layout.slots[i] or ""
        self:SetSlotText(i, name)
    end

    self:RefreshAllSlots()
    self:RefreshUnassigned()
end

-- Save current grid state to the selected layout
function addon:SaveToSelectedLayout()
    if not self.selectedLayout then
        return
    end

    self.selectedLayout.slots = self:GetGridState()
    self.selectedLayout.time = time()
end

-- Auto-save if enabled and a layout is selected
function addon:TryAutoSave()
    if self.autoSave and self.selectedLayout then
        self:SaveToSelectedLayout()
    end
end
