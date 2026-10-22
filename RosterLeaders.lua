local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local ASSIST_PROMOTION_TIMEOUT_DELAY = (StaticPopupTimeoutSec or 60) + 2

local assistFrame = CreateFrame("Frame")
local assistState = nil
local assistRetryTimer = nil
local assistTimeoutTimer = nil
local wasRaidLeader = false
local knownRaidMembers = {}

local function BuildNameSet(names)
    local set = {}
    local count = 0

    for _, name in ipairs(names or {}) do
        local normalized = addon:NormalizeName(name)
        if normalized and normalized ~= "" and not set[normalized] then
            set[normalized] = true
            count = count + 1
        end
    end

    return set, count
end

local function BuildAssistPromotionNames(leaderNames, queue, canPromoteAssists)
    if not leaderNames or not canPromoteAssists then
        return nil
    end

    local grouped = addon:BuildCurrentGroupSet()
    local queued = {}

    for _, entry in ipairs(queue or {}) do
        queued[entry.name] = true
    end

    local names = {}
    local seen = {}

    for _, name in ipairs(leaderNames) do
        local normalized = addon:NormalizeName(name)
        if normalized and not seen[normalized] and (grouped[normalized] or queued[normalized]) then
            seen[normalized] = true
            table.insert(names, normalized)
        end
    end

    return names
end

local function FindRaidMemberByName(name)
    if not IsInRaid() then
        return nil
    end

    local normalizedName = addon:NormalizeName(name)
    if not normalizedName then
        return nil
    end

    for i = 1, 40 do
        local rosterName, rank = GetRaidRosterInfo(i)
        if rosterName and addon:NormalizeName(rosterName) == normalizedName then
            return rosterName, rank
        end
    end
end

local function GetPendingAssistNames()
    local names = {}

    if assistState then
        for name in pairs(assistState.pending) do
            table.insert(names, name)
        end
    end

    table.sort(names)

    return names
end

local function StopAssistPromotion()
    if assistRetryTimer then
        assistRetryTimer:Cancel()
        assistRetryTimer = nil
    end

    if assistTimeoutTimer then
        assistTimeoutTimer:Cancel()
        assistTimeoutTimer = nil
    end

    assistState = nil
end

local function CancelPendingAssistPromotion(name)
    if not assistState or not assistState.pending[name] then
        return
    end

    assistState.pending[name] = nil
    assistState.requested[name] = nil
    assistState.count = assistState.count - 1
    if assistState.count == 0 then
        StopAssistPromotion()
    end
end

local function ScheduleAssistPromotionCheck(delay)
    if assistRetryTimer then
        assistRetryTimer:Cancel()
    end

    assistRetryTimer = C_Timer.NewTimer(delay or 1, function()
        assistRetryTimer = nil

        if assistState then
            addon:PromotePendingRosterAssists()

            if assistState then
                ScheduleAssistPromotionCheck(1)
            end
        end
    end)
end

local function QueueAssistPromotions(names)
    local pending, count = BuildNameSet(names)
    if count == 0 then
        return
    end

    if not assistState then
        assistState = {
            pending = {},
            requested = {},
            count = 0,
        }
    end

    for name in pairs(pending) do
        if not assistState.pending[name] then
            assistState.pending[name] = true
            assistState.requested[name] = nil
            assistState.count = assistState.count + 1
        end
    end

    if assistTimeoutTimer then
        assistTimeoutTimer:Cancel()
    end

    assistTimeoutTimer = C_Timer.NewTimer(ASSIST_PROMOTION_TIMEOUT_DELAY, function()
        local remaining = GetPendingAssistNames()
        if #remaining > 0 then
            addon:Debug("Roster leaders not promoted to assist: " .. addon:FormatNameList(remaining))
        end

        StopAssistPromotion()
    end)

    if not assistRetryTimer then
        ScheduleAssistPromotionCheck(1)
    end
end

function addon:GetRosterLeaderStore()
    self.db.char.rosterLeaders = self.db.char.rosterLeaders or {}

    return self.db.char.rosterLeaders
end

function addon:IsRosterLeader(name)
    local normalized = self:NormalizeName(name)
    if not normalized then
        return false
    end

    return self:GetRosterLeaderStore()[normalized] == true
end

function addon:GetRosterLeaderNames()
    local names = {}

    for name, enabled in pairs(self:GetRosterLeaderStore()) do
        if enabled then
            table.insert(names, name)
        end
    end

    table.sort(names)

    return names
end

function addon:SetRosterLeader(name, isLeader)
    local normalized = self:NormalizeName(name)
    if not normalized then
        return nil
    end

    if isLeader then
        self:GetRosterLeaderStore()[normalized] = true
    else
        self:GetRosterLeaderStore()[normalized] = nil
    end

    return normalized
end

function addon:ToggleRosterLeader(name)
    if self:IsRosterLeaderChangeLocked() then
        self:Print("Saved assistant choices are locked while invites or promotions are pending.")

        return
    end

    local normalized = self:NormalizeName(name)
    if not normalized then
        return
    end

    local isLeader = not self:IsRosterLeader(normalized)
    self:SetRosterLeader(normalized, isLeader)
    self:Print((isLeader and "Marked " or "Unmarked ") .. normalized .. " as roster leader.")

    self:OnRosterLeaderStatusChanged(normalized, isLeader)
    self:RefreshUnassigned()
end

function addon:IsRosterLeaderChangeLocked()
    return self:IsInviteFlowActive() or assistState ~= nil
end

function addon:GetRaidAssistTooltipLines(name)
    if not IsInRaid() then
        return {
            "Middle-click to change this player's assistant status in the current raid.",
            "You must be the raid leader.",
        }
    end

    local _, rank = FindRaidMemberByName(name)
    if rank == nil then
        return {
            "Middle-click to change this player's assistant status in the current raid.",
            "This player is not in your raid.",
        }
    end

    if rank == 2 then
        return { "The raid leader's status cannot be changed here." }
    end

    local lines = {}
    if rank == 1 then
        lines[1] = "Middle-click to demote this player from assistant."
    else
        lines[1] = "Middle-click to promote this player to assistant."
    end

    if not UnitIsGroupLeader("player") then
        lines[2] = "Only the raid leader can change assistants."
    elseif IsEveryoneAssistant() then
        lines[2] = "Individual assistants cannot be changed while everyone is assistant."
    end

    return lines
end

function addon:GetRosterAssistTooltipLines(name)
    local lines = {}

    if self:IsRosterLeader(name) then
        lines[1] = "Middle-click to stop automatically promoting this player."
    else
        lines[1] = "Middle-click to automatically promote this player to assistant."
    end

    lines[2] = "This choice is saved for invites and raids you lead."

    return lines
end

function addon:ToggleRaidAssist(name)
    if not IsInRaid() then
        self:Print("Cannot change assist: you are not in a raid.")

        return
    end

    local raidName, rank = FindRaidMemberByName(name)
    if not raidName then
        self:Print("Cannot change assist: " .. tostring(name) .. " is not in your raid.")

        return
    end

    if rank == 2 then
        self:Print("Cannot change assist: " .. raidName .. " is the raid leader.")

        return
    end

    if not UnitIsGroupLeader("player") then
        self:Print("You must be the raid leader to change assists.")

        return
    end

    if IsEveryoneAssistant() then
        self:Print("Cannot change individual assists while everyone is assistant.")

        return
    end

    local normalized = self:NormalizeName(raidName)
    -- Remember this live choice before its roster update arrives.
    knownRaidMembers[normalized] = true
    CancelPendingAssistPromotion(normalized)

    if rank == 1 then
        C_PartyInfo.DemoteAssistant(raidName, true)
        self:Print("Demoted Assist: " .. normalized)
    else
        C_PartyInfo.PromoteToAssistant(raidName, true)
        self:Print("Promoted Assist: " .. normalized)
    end
end

function addon:PromotePendingRosterAssists()
    if not assistState then
        return
    end

    if not IsInRaid() or not UnitIsGroupLeader("player") then
        return
    end

    local everyoneIsAssistant = IsEveryoneAssistant()
    local promoted = {}

    for i = 1, 40 do
        local rosterName, rank = GetRaidRosterInfo(i)
        local normalized = rosterName and self:NormalizeName(rosterName)

        if normalized and assistState.pending[normalized] then
            if rank == 0 and not everyoneIsAssistant and not assistState.requested[normalized] then
                C_PartyInfo.PromoteToAssistant(rosterName, true)
                assistState.requested[normalized] = true
            end

            if rank == 1 or rank == 2 or everyoneIsAssistant then
                if rank == 1 and assistState.requested[normalized] then
                    table.insert(promoted, normalized)
                end

                assistState.pending[normalized] = nil
                assistState.count = assistState.count - 1
            end
        end
    end

    if #promoted > 0 then
        self:Print(#promoted .. " Promoted Assist: " .. self:FormatNameList(promoted))
    end

    if assistState.count <= 0 then
        StopAssistPromotion()
    end
end

function addon:StartRosterLeaderAssistPromotion(queue, canPromoteAssists)
    StopAssistPromotion()

    local names = BuildAssistPromotionNames(self:GetRosterLeaderNames(), queue, canPromoteAssists)
    if not names then
        return
    end

    QueueAssistPromotions(names)
    self:PromotePendingRosterAssists()
end

function addon:OnRosterLeaderStatusChanged(name, isLeader)
    local raidName, rank = FindRaidMemberByName(name)
    if not raidName then
        return
    end

    if not UnitIsGroupLeader("player") then
        return
    end

    if IsEveryoneAssistant() then
        return
    end

    if isLeader then
        if rank == 0 then
            C_PartyInfo.PromoteToAssistant(raidName, true)
            self:Print("Promoted Assist: " .. self:NormalizeName(raidName))
        end

        return
    end

    if rank == 1 then
        C_PartyInfo.DemoteAssistant(raidName, true)
        self:Print("Demoted Assist: " .. self:NormalizeName(raidName))
    end
end

local function UpdateRosterLeaderAssists()
    if not IsInRaid() or not UnitIsGroupLeader("player") then
        if wasRaidLeader then
            StopAssistPromotion()
        end

        wasRaidLeader = false
        wipe(knownRaidMembers)

        return
    end

    local members = {}
    local names = {}
    -- Only new members or a new leadership tenure trigger promotion.
    -- Rank-only updates must not undo deliberate live demotions.
    for i = 1, 40 do
        local name, rank = GetRaidRosterInfo(i)
        local normalized = name and addon:NormalizeName(name)
        if normalized and rank ~= nil then
            members[normalized] = true
            if not knownRaidMembers[normalized] and rank == 0 and addon:IsRosterLeader(normalized) then
                names[#names + 1] = normalized
            end
        end
    end

    for name in pairs(knownRaidMembers) do
        if not members[name] then
            CancelPendingAssistPromotion(name)
        end
    end

    wasRaidLeader = true
    knownRaidMembers = members
    QueueAssistPromotions(names)
    addon:PromotePendingRosterAssists()
end

function addon:EnableRosterLeaderSync()
    assistFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    assistFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    assistFrame:RegisterEvent("GROUP_LEFT")
    assistFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    UpdateRosterLeaderAssists()
end

function addon:DisableRosterLeaderSync()
    assistFrame:UnregisterAllEvents()
    StopAssistPromotion()
    wasRaidLeader = false
    wipe(knownRaidMembers)
end

assistFrame:SetScript("OnEvent", function(_, event)
    if event == "GROUP_LEFT" then
        StopAssistPromotion()
        wasRaidLeader = false
        wipe(knownRaidMembers)

        return
    end

    UpdateRosterLeaderAssists()
end)
