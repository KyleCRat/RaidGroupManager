local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local function CanDisbandRaid()
    if not IsInRaid() then
        addon:Print("Cannot disband: you are not in a raid.")

        return false
    end

    if not UnitIsGroupLeader("player") then
        addon:Print("You must be the raid leader to disband the raid.")

        return false
    end

    if addon:IsInviteFlowActive() then
        addon:Print("Cannot disband while an invite is active.")

        return false
    end

    local _, instanceType = IsInInstance()
    if instanceType == "pvp"
        or instanceType == "arena"
        or HasLFGRestrictions()
        or C_PartyInfo.ChallengeModeRestrictionsActive()
    then
        addon:Print("Cannot disband: raid member removal is restricted here.")

        return false
    end

    return true
end

function addon:DisbandRaid()
    if not CanDisbandRaid() then
        return
    end

    for index = 40, 1, -1 do
        local unit = "raid" .. index
        local name = GetRaidRosterInfo(index)
        if name and not UnitIsUnit(unit, "player") then
            C_PartyInfo.UninviteUnit(name, nil, true)
        end
    end
end

StaticPopupDialogs["RGM_DISBAND_RAID"] = {
    text = "Disband the raid and remove all other members?",
    button1 = "Disband",
    button2 = CANCEL,
    OnAccept = function()
        addon:DisbandRaid()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function addon:PromptDisbandRaid()
    if not CanDisbandRaid() then
        return
    end

    StaticPopup_Show("RGM_DISBAND_RAID")
end
