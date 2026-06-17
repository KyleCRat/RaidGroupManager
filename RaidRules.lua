local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local SLOTS_PER_GROUP = 5
local DEFAULT_ACTIVE_SUBGROUPS = 8

local DIFFICULTY_ACTIVE_SUBGROUPS = {
    [1]   = 1, -- Party Normal
    [2]   = 1, -- Party Heroic
    [8]   = 1, -- Party Mythic
    [14]  = 6, -- Raid Normal (up to 30-player)
    [15]  = 6, -- Raid Heroic (up to 30-player)
    [16]  = 4, -- Raid Mythic (20-player)
    [17]  = 6, -- LFR
    [33]  = 6, -- Timewalking Raid
    [151] = 6, -- Timewalking LFR
    [233] = 5, -- Raid Mythic Flexible (15-25-player)
}

function addon:GetActiveRaidSubgroupCount()
    local _, _, difficultyID = GetInstanceInfo()

    return DIFFICULTY_ACTIVE_SUBGROUPS[difficultyID] or DEFAULT_ACTIVE_SUBGROUPS
end

function addon:GetActiveRaidGroups()
    local groups = {}
    for group = 1, self:GetActiveRaidSubgroupCount() do
        groups[#groups + 1] = group
    end

    return groups
end

function addon:GetGroupSlotCapacity(groups)
    return #groups * SLOTS_PER_GROUP
end

function addon:ForEachGroupSlot(groups, callback)
    for _, group in ipairs(groups) do
        for position = 1, SLOTS_PER_GROUP do
            local slotIndex = (group - 1) * SLOTS_PER_GROUP + position
            callback(slotIndex, group, position)
        end
    end
end
