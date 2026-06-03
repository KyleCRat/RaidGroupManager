local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local ASSIST_PROMOTION_TIMEOUT_DELAY = (StaticPopupTimeoutSec or 60) + 2

local assistFrame = CreateFrame("Frame")
local assistState = nil
local assistRetryTimer = nil
local assistTimeoutTimer = nil

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
    assistFrame:UnregisterAllEvents()

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
    if self.IsRosterLeaderChangeLocked and self:IsRosterLeaderChangeLocked() then
        self:Print("Roster leader changes are locked while an invite is active.")

        return
    end

    local normalized = self:NormalizeName(name)
    if not normalized then
        return
    end

    local isLeader = not self:IsRosterLeader(normalized)
    self:SetRosterLeader(normalized, isLeader)
    self:Print((isLeader and "Marked " or "Unmarked ") .. normalized .. " as roster leader.")

    if self.OnRosterLeaderStatusChanged then
        self:OnRosterLeaderStatusChanged(normalized, isLeader)
    end

    if self.RefreshUnassigned then
        self:RefreshUnassigned()
    end
end

function addon:IsRosterLeaderChangeLocked()
    return (self.IsInviteFlowActive and self:IsInviteFlowActive()) or assistState ~= nil
end

function addon:ToggleRaidAssist(name)
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

    if IsEveryoneAssistant and IsEveryoneAssistant() then
        self:Print("Cannot change individual assists while everyone is assistant.")

        return
    end

    if rank == 1 then
        DemoteAssistant(raidName, true)
        self:Print("Demoted Assist: " .. self:NormalizeName(raidName))
    else
        PromoteToAssistant(raidName, true)
        self:Print("Promoted Assist: " .. self:NormalizeName(raidName))
    end
end

function addon:PromotePendingRosterAssists()
    if not assistState then
        return
    end

    if not IsInRaid() or not UnitIsGroupLeader("player") then
        return
    end

    local promoted = {}

    for i = 1, 40 do
        local rosterName, rank = GetRaidRosterInfo(i)
        local normalized = rosterName and self:NormalizeName(rosterName)

        if normalized and assistState.pending[normalized] then
            if rank == 0 and not assistState.requested[normalized] then
                PromoteToAssistant(rosterName, true)
                assistState.requested[normalized] = true
            end

            if rank == 1 or rank == 2 then
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

    local pending, count = BuildNameSet(names)

    if count == 0 then
        return
    end

    assistState = {
        pending = pending,
        requested = {},
        count = count,
    }

    assistFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    assistFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    assistFrame:RegisterEvent("GROUP_LEFT")
    assistTimeoutTimer = C_Timer.NewTimer(ASSIST_PROMOTION_TIMEOUT_DELAY, function()

        local remaining = GetPendingAssistNames()

        if #remaining > 0 then
            addon:Debug("Roster leaders not promoted to assist: " .. addon:FormatNameList(remaining))
        end

        StopAssistPromotion()
    end)

    self:PromotePendingRosterAssists()

    if assistState then
        ScheduleAssistPromotionCheck(1)
    end
end

function addon:OnRosterLeaderStatusChanged(name, isLeader)
    local raidName, rank = FindRaidMemberByName(name)
    if not raidName then
        return
    end

    if not UnitIsGroupLeader("player") then
        return
    end

    if IsEveryoneAssistant and IsEveryoneAssistant() then
        return
    end

    if isLeader then
        if rank == 0 then
            PromoteToAssistant(raidName, true)
            self:Print("Promoted Assist: " .. self:NormalizeName(raidName))
        end

        return
    end

    if rank == 1 then
        DemoteAssistant(raidName, true)
        self:Print("Demoted Assist: " .. self:NormalizeName(raidName))
    end
end

assistFrame:SetScript("OnEvent", function(_, event)
    if event == "GROUP_LEFT" then
        StopAssistPromotion()

        return
    end

    addon:PromotePendingRosterAssists()
end)
