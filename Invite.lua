local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local function AddUniqueName(names, seen, name)
    if not name or name == "" then
        return
    end

    local normalized = addon:NormalizeName(name)
    if not normalized or seen[normalized] then
        return
    end

    seen[normalized] = true
    table.insert(names, normalized)
end

local function SetOnlineStatus(status, name, isOnline)
    if not name or name == "" then
        return
    end

    local normalized = addon:NormalizeName(name)
    if not normalized then
        return
    end

    if isOnline then
        status[normalized] = true
    elseif status[normalized] == nil then
        status[normalized] = false
    end
end

local function BuildKnownOnlineStatus()
    local status = {}

    local grouped = addon:BuildCurrentGroupSet()
    for name in pairs(grouped) do
        status[name] = true
    end

    if IsInGuild() then
        if C_GuildInfo and C_GuildInfo.GuildRoster then
            C_GuildInfo.GuildRoster()
        end

        local count = GetNumGuildMembers and GetNumGuildMembers() or 0
        for i = 1, count do
            local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
            SetOnlineStatus(status, name, isOnline)
        end
    end

    if C_FriendList then
        if C_FriendList.ShowFriends then
            C_FriendList.ShowFriends()
        end

        local count = C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or 0
        for i = 1, count do
            local info = C_FriendList.GetFriendInfoByIndex and C_FriendList.GetFriendInfoByIndex(i)
            if info then
                SetOnlineStatus(status, info.name, info.connected)
            end
        end
    end

    return status
end

local PARTY_TOTAL_LIMIT = (MAX_PARTY_MEMBERS or 4) + 1
local CONVERT_CHECK_DELAY = 1.5
local INVITE_TIMEOUT_REPORT_DELAY = (StaticPopupTimeoutSec or 60) + 2

local StopInviteFlow
local ContinueInviteFlow
local ScheduleInviteTimeoutReportFromState

local inviteFrame = CreateFrame("Frame")
local inviteState = nil
local inviteTimer = nil
local inviteReportState = nil
local inviteReportTimer = nil

function addon:IsInviteFlowActive()
    return inviteState ~= nil or inviteReportState ~= nil
end

local function GetCurrentGroupCount()
    local count = GetNumGroupMembers() or 0
    if count > 0 then
        return count
    end

    return 1
end

local function GetOpenPartyInviteSlots()
    if IsInRaid() then
        return 0
    end

    return math.max(0, PARTY_TOTAL_LIMIT - GetCurrentGroupCount())
end

local function NeedsRaidForInvites(inviteCount)
    if IsInRaid() then
        return false
    end

    return GetCurrentGroupCount() + inviteCount > PARTY_TOTAL_LIMIT
end

local function HasPartyForRaidConversion()
    return not IsInRaid() and IsInGroup() and GetCurrentGroupCount() > 1
end

local function CanConvertToRaid()
    if IsInRaid() then
        return false
    end

    if C_PartyInfo and C_PartyInfo.AllowedToDoPartyConversion then
        return C_PartyInfo.AllowedToDoPartyConversion(true)
    end

    return HasPartyForRaidConversion()
end

local function RegisterInviteEvents()
    inviteFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    inviteFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    inviteFrame:RegisterEvent("GROUP_LEFT")
end

local function ScheduleInviteContinue(delay)
    if inviteTimer then
        inviteTimer:Cancel()
    end

    inviteTimer = C_Timer.NewTimer(delay or 0, function()
        inviteTimer = nil
        ContinueInviteFlow()
    end)
end

local function CopyNameList(names)
    local copy = {}

    for _, name in ipairs(names or {}) do
        table.insert(copy, name)
    end

    return copy
end

local function GetQueuedInviteNames(queue)
    local names = {}

    for _, entry in ipairs(queue or {}) do
        table.insert(names, entry.name)
    end

    return names
end

local function CancelInviteTimeoutReport()
    if inviteReportTimer then
        inviteReportTimer:Cancel()
        inviteReportTimer = nil
    end

    inviteReportState = nil
end

StopInviteFlow = function()
    inviteFrame:UnregisterAllEvents()

    if inviteTimer then
        inviteTimer:Cancel()
        inviteTimer = nil
    end

    inviteState = nil
end

local function BuildInviteQueue(names)
    local queue = {}
    local grouped = addon:BuildCurrentGroupSet()
    local onlineStatus = BuildKnownOnlineStatus()
    local skippedOffline = {}

    for _, name in ipairs(names) do
        if not grouped[name] then
            local knownStatus = onlineStatus[name]
            if knownStatus == false then
                table.insert(skippedOffline, name)
            else
                table.insert(queue, {
                    name = name,
                    knownOnline = knownStatus == true,
                })
                grouped[name] = true
            end
        end
    end

    return queue, skippedOffline
end

local function FormatNameListOrNone(names)
    if not names or #names == 0 then
        return "none"
    end

    return addon:FormatNameList(names)
end

local function CombineNameLists(firstNames, secondNames)
    local combined = {}
    local seen = {}

    for _, name in ipairs(firstNames or {}) do
        if not seen[name] then
            seen[name] = true
            table.insert(combined, name)
        end
    end

    for _, name in ipairs(secondNames or {}) do
        if not seen[name] then
            seen[name] = true
            table.insert(combined, name)
        end
    end

    return combined
end

local function FilterMissingNames(names)
    local missing = {}
    local grouped = addon:BuildCurrentGroupSet()

    for _, name in ipairs(names or {}) do
        if not grouped[name] then
            table.insert(missing, name)
        end
    end

    return missing
end

local function PrintMissingInviteSummary(sourceLabel, invitedMissing, skippedOffline, notSentNames)
    local notInvited = CombineNameLists(skippedOffline, notSentNames)

    if #invitedMissing == 0 and #notInvited == 0 then
        addon:Print("Invite check for " .. sourceLabel .. ": no missing characters.")

        return
    end

    addon:Print("Invite Finished:")
    addon:Print("Not Invited: " .. FormatNameListOrNone(notInvited))
    addon:Print("Did Not Accept: " .. FormatNameListOrNone(invitedMissing))
end

local function PrintInviteTimeoutReport()
    local report = inviteReportState
    if not report then
        return
    end

    inviteReportState = nil
    inviteReportTimer = nil

    local invitedMissing = FilterMissingNames(report.invitedNames)
    local skippedOffline = FilterMissingNames(report.skippedOffline)
    local notSentNames = FilterMissingNames(report.notSentNames)

    PrintMissingInviteSummary(report.sourceLabel, invitedMissing, skippedOffline, notSentNames)

    if inviteState == report.flowState then
        StopInviteFlow()
    end
end

ScheduleInviteTimeoutReportFromState = function()
    if not inviteState or #inviteState.invitedNames == 0 then
        return
    end

    if inviteReportTimer then
        inviteReportTimer:Cancel()
    end

    inviteReportState = {
        sourceLabel = inviteState.sourceLabel,
        invitedNames = CopyNameList(inviteState.invitedNames),
        skippedOffline = CopyNameList(inviteState.skippedOffline),
        notSentNames = GetQueuedInviteNames(inviteState.queue),
        flowState = inviteState,
    }

    inviteReportTimer = C_Timer.NewTimer(INVITE_TIMEOUT_REPORT_DELAY, PrintInviteTimeoutReport)
end

local function PopNextInvite(requireKnownOnline)
    if not inviteState then
        return nil
    end

    if not requireKnownOnline then
        return table.remove(inviteState.queue, 1)
    end

    for i, entry in ipairs(inviteState.queue) do
        if entry.knownOnline then
            table.remove(inviteState.queue, i)

            return entry
        end
    end

    return nil
end

local function SendQueuedInvites(limit, requireKnownOnline)
    local grouped = addon:BuildCurrentGroupSet()
    local sent = 0

    while inviteState and #inviteState.queue > 0 and (not limit or sent < limit) do
        local entry = PopNextInvite(requireKnownOnline)
        if not entry then
            break
        end

        local name = entry.name
        if not grouped[name] then
            C_PartyInfo.InviteUnit(name)
            grouped[name] = true
            table.insert(inviteState.invitedNames, name)
            sent = sent + 1
            inviteState.sent = inviteState.sent + 1
        end
    end

    if sent > 0 then
        ScheduleInviteTimeoutReportFromState()
    end

    return sent
end

local function PrintInviteStarted(names)
    local count = names and #names or 0
    if count == 0 then
        return
    end

    addon:Print(count .. " Invited: " .. addon:FormatNameList(names))
end

local function PrintSkippedOffline(names)
    local count = names and #names or 0
    if count > 0 then
        addon:Print(count .. " Offline: " .. addon:FormatNameList(names))
    end
end

local function FinishInviteFlow()
    local invitedNames = inviteState and inviteState.invitedNames or {}
    local sourceLabel = inviteState and inviteState.sourceLabel or "characters"
    local skippedOffline = inviteState and inviteState.skippedOffline or {}

    StopInviteFlow()

    if #invitedNames > 0 then
        PrintInviteStarted(invitedNames)
        PrintSkippedOffline(skippedOffline)
    else
        addon:Print("All " .. sourceLabel .. " are already in your group.")
        PrintSkippedOffline(skippedOffline)
    end
end

local function TryConvertToRaid()
    if not C_PartyInfo or not C_PartyInfo.ConvertToRaid then
        addon:Print("Cannot convert the party to a raid.")
        StopInviteFlow()

        return false
    end

    if not CanConvertToRaid() then
        addon:Print("Cannot convert the party to a raid.")
        StopInviteFlow()

        return false
    end

    if not inviteState.convertRequested then
        inviteState.convertRequested = true
        C_PartyInfo.ConvertToRaid()
        ScheduleInviteContinue(CONVERT_CHECK_DELAY)
    end

    return true
end

ContinueInviteFlow = function()
    if not inviteState then
        return
    end

    if not C_PartyInfo or not C_PartyInfo.InviteUnit then
        addon:Print("Group invites are not available.")
        StopInviteFlow()

        return
    end

    if IsInRaid() then
        SendQueuedInvites()
        FinishInviteFlow()

        return
    end

    if inviteState.needsRaid then
        if CanConvertToRaid() then
            TryConvertToRaid()
        elseif HasPartyForRaidConversion() then
            addon:Print("Cannot convert the party to a raid.")
            StopInviteFlow()
        end

        return
    end

    SendQueuedInvites()
    FinishInviteFlow()
end

inviteFrame:SetScript("OnEvent", function(_, event)
    if event == "GROUP_LEFT" then
        if inviteState then
            addon:Print("Invite flow stopped because you left the group.")
            CancelInviteTimeoutReport()
            StopInviteFlow()
        end

        return
    end

    ContinueInviteFlow()
end)

function addon:GetAssignedInviteNames()
    local names = {}
    local seen = {}

    for i = 1, 40 do
        if self:IsSlotPlayer(i) then
            AddUniqueName(names, seen, self:GetSlotText(i))
        end
    end

    return names
end

function addon:GetRosterInviteNames()
    local names = {}
    local seen = {}
    local roster = self.db.char.importedRoster or {}

    for _, entry in ipairs(roster) do
        AddUniqueName(names, seen, entry.normalizedName)
    end

    return names
end

function addon:InviteNamesToGroup(names, sourceLabel)
    if not names or #names == 0 then
        self:Print("No " .. sourceLabel .. " to invite.")

        return
    end

    if not C_PartyInfo or not C_PartyInfo.InviteUnit then
        self:Print("Group invites are not available.")

        return
    end

    if C_PartyInfo.CanInvite and not C_PartyInfo.CanInvite() then
        self:Print("You do not have permission to invite to the group.")

        return
    end

    StopInviteFlow()
    CancelInviteTimeoutReport()

    local queue, skippedOffline = BuildInviteQueue(names)
    if #queue == 0 then
        if #skippedOffline > 0 then
            PrintMissingInviteSummary(sourceLabel, {}, skippedOffline, {})
        else
            self:Print("All " .. sourceLabel .. " are already in your group.")
        end

        return
    end

    local needsRaid = NeedsRaidForInvites(#queue)
    local canPromoteAssists = (IsInRaid() and UnitIsGroupLeader("player")) or needsRaid
    self:StartRosterLeaderAssistPromotion(queue, canPromoteAssists)

    inviteState = {
        queue = queue,
        sourceLabel = sourceLabel,
        sent = 0,
        invitedNames = {},
        needsRaid = needsRaid,
        convertRequested = false,
        skippedOffline = skippedOffline,
    }

    if inviteState.needsRaid then
        RegisterInviteEvents()

        if CanConvertToRaid() then
            self:Print("Converting to raid before inviting " .. sourceLabel .. ".")
            TryConvertToRaid()

            return
        end

        if HasPartyForRaidConversion() then
            self:Print("Cannot convert the party to a raid.")
            StopInviteFlow()

            return
        end

        local startedInvites = SendQueuedInvites(GetOpenPartyInviteSlots(), true)
        if startedInvites == 0 then
            self:Print("Cannot start raid invite flow: no queued " .. sourceLabel .. " are known online.")
            PrintMissingInviteSummary(sourceLabel, {}, skippedOffline, GetQueuedInviteNames(inviteState.queue))
            StopInviteFlow()

            return
        end

        self:Print("Started " .. startedInvites .. " starter invite" .. (startedInvites == 1 and "" or "s") .. " for " .. sourceLabel .. ". Converting to raid when your party forms.")

        return
    end

    SendQueuedInvites()
    FinishInviteFlow()
end

StaticPopupDialogs["RGM_INVITE_TO_GROUP"] = {
    text = "Invite assigned group members or roster characters?",
    button1 = "Assigned Members",
    button2 = "Roster Characters",
    button3 = CANCEL,
    selectCallbackByIndex = true,
    OnButton1 = function()
        addon:InviteNamesToGroup(addon:GetAssignedInviteNames(), "assigned group members")
    end,
    OnButton2 = function()
        addon:InviteNamesToGroup(addon:GetRosterInviteNames(), "roster characters")
    end,
    OnButton3 = function()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function addon:ShowInviteToGroupPopup()
    StaticPopup_Show("RGM_INVITE_TO_GROUP")
end
