local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local NORMAL_INTERVAL = 1.5
local BACKGROUND_INTERVAL = 10
local INSPECT_TIMEOUT = 3
local RETRY_DELAY = 5
local AVAILABILITY_DELAY = 5
local MAX_ATTEMPTS = 3

local Inspect = { NORMAL = 1, BACKGROUND = 2 }
addon.Inspect = Inspect
local eventFrame = CreateFrame("Frame")

local function InspectWindowOpen()
    return InspectFrame and InspectFrame:IsShown()
end

function Inspect:Initialize()
    self.entries = {}
    self.sequence = 0
    self.lastRequestAt = GetTime() - BACKGROUND_INTERVAL
end

function Inspect:CancelWake()
    if self.wakeTimer then
        self.wakeTimer:Cancel()
        self.wakeTimer = nil
    end
end

function Inspect:ClearPending()
    if not self.pending then return end

    if self.timeoutTimer then
        self.timeoutTimer:Cancel()
        self.timeoutTimer = nil
    end
    self.pending = nil
    if not InspectWindowOpen() then ClearInspectPlayer() end
end

function Inspect:Reset()
    self:CancelWake()
    self:ClearPending()
    wipe(self.entries)
end

function Inspect:Forget(name)
    -- An in-flight response retains its old entry identity and cannot populate
    -- a cache invalidated by a newer spec change for the same player.
    self.entries[name] = nil
end

function Inspect:ResetAttempts(name)
    local entry = self.entries[name]
    if entry then
        entry.attempts = 0
        entry.retryAt = 0
    end
end

function Inspect:Queue(name, priority)
    local entry = self.entries[name]
    if entry then
        if priority < entry.priority then
            entry.priority = priority
            entry.retryAt = 0
        end

        return
    end

    self.sequence = self.sequence + 1
    self.entries[name] = {
        name = name,
        priority = priority,
        attempts = 0,
        sequence = self.sequence,
        retryAt = priority == self.BACKGROUND
                and GetTime() + BACKGROUND_INTERVAL
            or 0,
    }
end

function Inspect:Prune(roster)
    for name in pairs(self.entries) do
        if not roster[name] then self.entries[name] = nil end
    end
    if self.pending and not roster[self.pending.entry.name] then
        self:ClearPending()
    end
end

local function ComesBefore(a, b)
    if not b then return true end

    if a.priority ~= b.priority then return a.priority < b.priority end

    local times = addon.RoleDetection.verifiedAt
    local timeA, timeB = times[a.name] or 0, times[b.name] or 0
    if timeA ~= timeB then return timeA < timeB end

    return a.sequence < b.sequence
end

function Inspect:Finish(request, specID, roster)
    if self.pending ~= request then return end

    self:ClearPending()
    local entry = request.entry
    if self.entries[entry.name] == entry then
        if specID then
            self.entries[entry.name] = nil
            addon.RoleDetection:StoreSpec(entry.name, specID)
        else
            entry.retryAt = GetTime() + RETRY_DELAY
            addon:Debug(
                entry.name
                    .. " inspect failed ("
                    .. entry.attempts
                    .. "/"
                    .. MAX_ATTEMPTS
                    .. ")"
            )
        end
    end
    self:Wake(roster)
end

function Inspect:Wake(roster)
    self:CancelWake()
    if
        not self.enabled
        or self.pending
        or InCombatLockdown()
        or not IsInRaid()
        or not next(self.entries)
    then
        return
    end

    local now = GetTime()
    roster = roster or addon:GetRaidRoster()
    local selected, selectedUnit, selectedGUID
    local nextWake
    local inspectWindowOpen = InspectWindowOpen()

    for name, entry in pairs(self.entries) do
        local member = roster[name]
        local priority = addon.RoleDetection:GetInspectPriority(member)
        if not priority then
            self.entries[name] = nil
        elseif entry.attempts < MAX_ATTEMPTS and member.online then
            local unit = member.unitToken
            local guid = UnitGUID(unit)
            if
                not inspectWindowOpen
                and not issecretvalue(guid)
                and guid
                and CanInspect(unit)
            then
                local interval = entry.priority == self.NORMAL
                        and NORMAL_INTERVAL
                    or BACKGROUND_INTERVAL
                local due =
                    math.max(entry.retryAt, self.lastRequestAt + interval)
                if due <= now and ComesBefore(entry, selected) then
                    selected, selectedUnit, selectedGUID = entry, unit, guid
                elseif due > now then
                    nextWake = math.min(nextWake or due, due)
                end
            else
                local due = now + AVAILABILITY_DELAY
                nextWake = math.min(nextWake or due, due)
            end
        end
    end

    if selected then
        selected.attempts = selected.attempts + 1
        self.lastRequestAt = now
        local request = { entry = selected, guid = selectedGUID }
        self.pending = request
        self.timeoutTimer = C_Timer.NewTimer(INSPECT_TIMEOUT, function()
            self:Finish(request, nil)
        end)
        addon:Debug(
            "Inspecting "
                .. selected.name
                .. " ("
                .. selected.attempts
                .. "/"
                .. MAX_ATTEMPTS
                .. ")"
        )
        NotifyInspect(selectedUnit)
    elseif nextWake then
        self.wakeTimer = C_Timer.NewTimer(
            math.max(0.05, nextWake - now),
            function()
                self.wakeTimer = nil
                self:Wake()
            end
        )
    end
end

function Inspect:OnReady(guid)
    local request = self.pending
    if not request or issecretvalue(guid) or guid ~= request.guid then
        return
    end

    local roster = addon:GetRaidRoster()
    local member = roster[request.entry.name]
    local specID
    if member then
        local currentGUID = UnitGUID(member.unitToken)
        if not issecretvalue(currentGUID) and currentGUID == request.guid then
            local value =
                C_SpecializationInfo.GetInspectSpecialization(member.unitToken)
            if
                not issecretvalue(value)
                and type(value) == "number"
                and value > 0
            then
                specID = value
            end
        end
    end
    self:Finish(request, specID, roster)
end

function Inspect:Enable()
    self.enabled = true
    eventFrame:RegisterEvent("INSPECT_READY")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Inspect:Disable()
    self.enabled = false
    eventFrame:UnregisterAllEvents()
    self:Reset()
end

eventFrame:SetScript("OnEvent", function(_, event, guid)
    if event == "INSPECT_READY" then
        Inspect:OnReady(guid)
    elseif event == "PLAYER_REGEN_DISABLED" then
        Inspect:CancelWake()
    else
        Inspect:Wake()
    end
end)
