local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")
local ClassSpecRoles = addon.ClassSpecRoles

local LONG_ABSENCE_SECONDS = 5 * 60
local SPEC_CHANGE_DELAY = 0.5

local RoleDetection = {}
addon.RoleDetection = RoleDetection
-- Apply temporarily replaces Core's AceEvent roster handler.
local eventFrame = CreateFrame("Frame")

local function IsPlayerUnit(unit)
    if not unit then return false end

    local isPlayer = UnitIsUnit(unit, "player")

    return not issecretvalue(isPlayer) and isPlayer
end

local function GetKnownRole(member)
    if member.role == "TANK" or member.role == "HEALER" then
        return member.role
    end

    return ClassSpecRoles:GetCombatRoleForClass(member.class, member.role)
end

local function GetPlayerSpecID()
    local index = C_SpecializationInfo.GetSpecialization()
    if index then return C_SpecializationInfo.GetSpecializationInfo(index) end

    return nil
end

local function GetHeuristicRole(member)
    local unit = member.unitToken
    if
        member.role ~= "DAMAGER"
        or not unit
        or not member.online
        or not UnitExists(unit)
    then
        return nil
    end

    -- Hunters use Agility for both melee and ranged specs.
    if
        member.class ~= "DRUID"
        and member.class ~= "SHAMAN"
        and member.class ~= "DEMONHUNTER"
    then
        return nil
    end

    local _, agility = UnitStat(unit, 2)
    local _, intellect = UnitStat(unit, 4)
    if
        issecretvalue(agility)
        or issecretvalue(intellect)
        or type(agility) ~= "number"
        or type(intellect) ~= "number"
        or agility <= 0
        or intellect <= 0
    then
        return nil
    end

    if agility > intellect then return "MELEE" end

    if intellect > agility then return "RANGED" end

    return nil
end

local function ResolveRole(member, name)
    local knownRole = member and GetKnownRole(member)
    if knownRole then return knownRole end

    local normalized =
        addon:NormalizeName(member and member.normalizedName or name)
    local specID = RoleDetection.cache[normalized]
    if member and IsPlayerUnit(member.unitToken) then
        specID = GetPlayerSpecID()
    end

    local specRole = ClassSpecRoles:GetCombatRoleForSpecID(specID)
    if specRole then return specRole end

    local heuristicRole = member and GetHeuristicRole(member)
    if heuristicRole then return heuristicRole end

    local imported = addon:GetImportedRosterEntry(normalized)
    if imported and imported.role then return imported.role end

    local class = member and member.class or (imported and imported.class)

    return ClassSpecRoles:GetDefaultCombatRole(class)
end

-- Roster records are short-lived snapshots, so memoization lasts only one pass.
function addon:GetCombatRole(member, name)
    if member and member.combatRole then return member.combatRole end

    local role = ResolveRole(member, name)
    if member then member.combatRole = role end

    return role
end

function RoleDetection:Initialize()
    self.cache = addon.db.profile.specCache
    self.verifiedAt = addon.db.profile.specCacheTimes
    self.context = addon.db.profile.specCacheContext
    self.dirty = {}
    self.roster = {}
    self.specChangeTimers = {}
    self.changedNames = {}
    self.ready = false

    -- Keep the existing name -> spec ID saved data; metadata is additive.
    for name, specID in pairs(self.cache) do
        if type(specID) ~= "number" or specID <= 0 then
            self.cache[name] = nil
            self.verifiedAt[name] = nil
        end
    end

    addon.Inspect:Initialize()
end

function RoleDetection:GetInspectPriority(member)
    if not member or GetKnownRole(member) then return nil end

    if IsPlayerUnit(member.unitToken) then return nil end

    local name = member.normalizedName
    if self.specChangeTimers[name] then return nil end

    if not self.cache[name] then return addon.Inspect.NORMAL end

    return self.dirty[name]
end

function RoleDetection:QueueDisplayRefresh(name)
    if name then
        self.changedNames[name] = true
    else
        self.refreshAll = true
    end
    if self.displayTimer then return end

    self.displayTimer = C_Timer.NewTimer(0, function()
        self.displayTimer = nil
        if addon.mainFrame and addon.mainFrame:IsShown() then
            local roster = addon:GetGroupDisplayRoster()
            if self.refreshAll then
                addon:RefreshAllSlots(roster)
            else
                for i = 1, 40 do
                    local nameInSlot = addon:NormalizeName(addon:GetSlotText(i))
                    if self.changedNames[nameInSlot] then
                        addon:RefreshSlot(i, roster)
                    end
                end
            end
            addon:RefreshUnassignedRaidRoles(roster)
        end
        self.refreshAll = false
        wipe(self.changedNames)
    end)
end

function RoleDetection:StoreSpec(name, specID)
    local changed = self.cache[name] ~= specID
    self.cache[name] = specID
    self.verifiedAt[name] = GetServerTime()
    self.dirty[name] = nil
    addon:Debug(name .. " spec cached: " .. specID)
    if changed then self:QueueDisplayRefresh(name) end
end

function RoleDetection:InvalidateSpec(name)
    local hadSpec = self.cache[name] ~= nil
    self.cache[name] = nil
    self.verifiedAt[name] = nil
    self.dirty[name] = nil
    addon.Inspect:Forget(name)
    if hadSpec then self:QueueDisplayRefresh(name) end
end

function RoleDetection:Reset()
    addon.Inspect:Reset()
    for _, timer in pairs(self.specChangeTimers) do
        timer:Cancel()
    end
    wipe(self.specChangeTimers)
    wipe(self.cache)
    wipe(self.verifiedAt)
    wipe(self.dirty)
    wipe(self.roster)
    if self.enabled then self:QueueDisplayRefresh() end
end

function RoleDetection:UpdateRoster()
    if not self.enabled or not self.ready then return end

    local inRaid = IsInRaid()
    if self.inRaid ~= inRaid then
        self:Reset()
        self.inRaid = inRaid
    end
    if not inRaid then return end

    local roster = addon:GetRaidRoster()
    if not next(roster) then return end

    for name in pairs(self.cache) do
        if not roster[name] then self:InvalidateSpec(name) end
    end
    for name, timer in pairs(self.specChangeTimers) do
        if not roster[name] then
            timer:Cancel()
            self.specChangeTimers[name] = nil
        end
    end

    for name, member in pairs(roster) do
        local previous = self.roster[name]
        if previous then
            if not previous.online and member.online then
                addon.Inspect:ResetAttempts(name)
            end
            if
                (previous.role == "TANK" or previous.role == "HEALER")
                and member.role ~= previous.role
                and member.role ~= "NONE"
            then
                self:InvalidateSpec(name)
            end
        end

        local priority = self:GetInspectPriority(member)
        if priority then
            addon.Inspect:Queue(name, priority)
        else
            addon.Inspect:Forget(name)
        end
    end

    self.roster = roster
    addon.Inspect:Prune(roster)
    addon.Inspect:Wake(roster)
end

function RoleDetection:OnEnteringWorld(isInitialLogin, isReloadingUi)
    if not self.ready then
        self.ready = true
        local owner = UnitGUID("player")
        local inRaid = IsInRaid()
        if
            not inRaid
            or (self.context.owner and self.context.owner ~= owner)
            or self.context.inRaid == false
        then
            self:Reset()
        end

        local priority = addon.Inspect.BACKGROUND
        if
            isInitialLogin
            and not isReloadingUi
            and type(self.context.savedAt) == "number"
            and GetServerTime() - self.context.savedAt
                >= LONG_ABSENCE_SECONDS
        then
            priority = addon.Inspect.NORMAL
        end

        for name in pairs(self.cache) do
            self.dirty[name] = priority
        end
        self.inRaid = inRaid
        self.context.owner = owner
    end

    self:UpdateRoster()
    self:QueueDisplayRefresh()
end

function RoleDetection:SaveContext()
    self.context.owner = UnitGUID("player")
    self.context.savedAt = GetServerTime()
    self.context.inRaid = IsInRaid()
end

function RoleDetection:OnSpecChanged(unit)
    if issecretvalue(unit) or not unit then return end

    if IsPlayerUnit(unit) then
        self:UpdateRoster()
        self:QueueDisplayRefresh()

        return
    end
    if not self.ready or not IsInRaid() then return end

    local name, realm = UnitFullName(unit)
    if issecretvalue(name) or issecretvalue(realm) or not name then return end

    name = addon:NormalizeName(addon:BuildFullName(name, realm))
    if not self.roster[name] then return end

    self:InvalidateSpec(name)
    if self.specChangeTimers[name] then self.specChangeTimers[name]:Cancel() end
    self.specChangeTimers[name] = C_Timer.NewTimer(SPEC_CHANGE_DELAY, function()
        self.specChangeTimers[name] = nil
        self:UpdateRoster()
        self:QueueDisplayRefresh(name)
    end)
    self:QueueDisplayRefresh(name)
end

function RoleDetection:Enable()
    self.enabled = true
    addon.Inspect:Enable()
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LOGOUT")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("UNIT_CONNECTION")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("ROLE_CHANGED_INFORM")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    self:UpdateRoster()
end

function RoleDetection:Disable()
    self:SaveContext()
    self.enabled = false
    eventFrame:UnregisterAllEvents()
    addon.Inspect:Disable()
    for _, timer in pairs(self.specChangeTimers) do
        timer:Cancel()
    end
    wipe(self.specChangeTimers)
    if self.displayTimer then
        self.displayTimer:Cancel()
        self.displayTimer = nil
    end
    wipe(self.changedNames)
    self.refreshAll = false
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        RoleDetection:OnEnteringWorld(...)
    elseif event == "PLAYER_LOGOUT" then
        RoleDetection:SaveContext()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        RoleDetection:OnSpecChanged(...)
    else
        RoleDetection:UpdateRoster()
        if
            event == "ROLE_CHANGED_INFORM"
            or event == "PLAYER_ROLES_ASSIGNED"
        then
            RoleDetection:QueueDisplayRefresh()
        end
    end
end)
