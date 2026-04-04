local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local STATE_IDLE = 0
local STATE_PLANNING = 1
local STATE_EXECUTING = 2

local DEBOUNCE_INTERVAL = 0.5

addon.assignState = STATE_IDLE
addon.debounceTimer = nil
addon.moveQueue = {}
addon.moveIndex = 0

--------------------------------------------------------------------------------
-- State builders
--------------------------------------------------------------------------------

-- Build current raid state: name -> { raidIndex, currentGroup, currentPosition }
local function BuildRaidState()
    local state = {}
    local groupCounts = {}
    for g = 1, 8 do
        groupCounts[g] = 0
    end

    local count = GetNumGroupMembers()
    for i = 1, count do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name then
            groupCounts[subgroup] = groupCounts[subgroup] + 1
            local normalized = addon:NormalizeName(name)
            state[normalized] = {
                raidIndex = i,
                currentGroup = subgroup,
                currentPosition = groupCounts[subgroup],
                name = name,
                normalizedName = normalized,
            }
        end
    end

    return state, groupCounts
end

-- Build desired state from grid: name -> { desiredGroup, desiredPosition }
-- Skips template slots (only includes actual player names)
local function BuildDesiredState()
    local desired = {}
    local seen = {}

    for i = 1, 40 do
        if addon:IsSlotPlayer(i) then
            local text = addon:GetSlotText(i)
            local normalized = addon:NormalizeName(text)
            if not seen[normalized] then
                seen[normalized] = true
                local group = math.ceil(i / 5)
                local pos = ((i - 1) % 5) + 1
                desired[normalized] = {
                    desiredGroup = group,
                    desiredPosition = pos,
                }
            end
        end
    end

    return desired
end

--------------------------------------------------------------------------------
-- Template resolution — match raid members to template slots before Apply
--------------------------------------------------------------------------------

function addon:ResolveTemplates()
    local roster = self:GetRaidRoster()

    -- Build set of names already explicitly assigned to player slots
    local namedPlayers = {}
    for i = 1, 40 do
        if self:IsSlotPlayer(i) then
            namedPlayers[self:GetSlotText(i)] = true
        end
    end

    -- Build pool of available players (in raid but not in a named slot)
    local available = {}
    for name, member in pairs(roster) do
        if not namedPlayers[name] then
            table.insert(available, member)
        end
    end

    -- Separate template slots into class-specific and generic (ANY)
    local classTemplates = {}
    local genericTemplates = {}
    for i = 1, 40 do
        if self:IsSlotTemplate(i) then
            local template = self:GetSlotTemplate(i)
            local entry = { index = i, template = template }
            if template.class == "ANY" then
                table.insert(genericTemplates, entry)
            else
                table.insert(classTemplates, entry)
            end
        end
    end

    if #classTemplates == 0 and #genericTemplates == 0 then

        return
    end

    -- Pass 1: Match class+role templates (highest priority)
    for _, ts in ipairs(classTemplates) do
        local bestIdx = nil
        for i, member in ipairs(available) do
            local combatRole = self:GetCombatRole(member)
            if member.class == ts.template.class and combatRole == ts.template.role then
                bestIdx = i

                break
            end
        end

        if bestIdx then
            self:SetSlotText(ts.index, available[bestIdx].normalizedName)
            table.remove(available, bestIdx)
        end
        -- Unmatched class templates remain in place
    end

    -- Pass 2: Match generic role-only templates with remaining available players
    for _, ts in ipairs(genericTemplates) do
        local bestIdx = nil
        for i, member in ipairs(available) do
            local combatRole = self:GetCombatRole(member)
            if combatRole == ts.template.role then
                bestIdx = i

                break
            end
        end

        if bestIdx then
            self:SetSlotText(ts.index, available[bestIdx].normalizedName)
            table.remove(available, bestIdx)
        end
        -- Unmatched generic templates remain in place
    end

    self:RefreshAllSlots()
    self:RefreshUnassigned()
end

function addon:HasTemplateSlots()
    for i = 1, 40 do
        if self:IsSlotTemplate(i) then

            return true
        end
    end

    return false
end

-- Check if any raid member is in combat
local function AnyoneInCombat()
    local count = GetNumGroupMembers()
    local combatants = {}

    for i = 1, count do
        local unit = "raid" .. i
        if UnitAffectingCombat(unit) then
            local name = GetRaidRosterInfo(i)
            table.insert(combatants, name or ("raid" .. i))
        end
    end

    return #combatants > 0, combatants
end

--------------------------------------------------------------------------------
-- Move planning — compute the minimum sequence of API calls up front
--------------------------------------------------------------------------------

-- Simulate the raid state as a table we can mutate during planning
-- sim[name] = group number
-- simGroups[group] = { [position] = name, ... }
local function BuildSimulation(raidState)
    local sim = {}
    local simGroups = {}

    for g = 1, 8 do
        simGroups[g] = {}
    end

    for normalized, info in pairs(raidState) do
        sim[normalized] = info.currentGroup
        local g = info.currentGroup
        simGroups[g][info.currentPosition] = normalized
    end

    return sim, simGroups
end

-- Count members in a simulated group
local function SimGroupCount(simGroups, group)
    local count = 0
    for _ in pairs(simGroups[group]) do
        count = count + 1
    end

    return count
end

-- Remove a name from its simulated group
local function SimRemoveFromGroup(simGroups, group, name)
    for pos, n in pairs(simGroups[group]) do
        if n == name then
            simGroups[group][pos] = nil

            return pos
        end
    end

    return nil
end

-- Add a name to a simulated group at the next open position
local function SimAddToGroup(simGroups, group, name)
    for pos = 1, 5 do
        if not simGroups[group][pos] then
            simGroups[group][pos] = name

            return pos
        end
    end

    return nil
end

-- Swap two names between groups in simulation
local function SimSwap(sim, simGroups, nameA, nameB)
    local groupA = sim[nameA]
    local groupB = sim[nameB]
    local posA = SimRemoveFromGroup(simGroups, groupA, nameA)
    local posB = SimRemoveFromGroup(simGroups, groupB, nameB)
    simGroups[groupA][posA] = nameB
    simGroups[groupB][posB] = nameA
    sim[nameA] = groupB
    sim[nameB] = groupA
end

-- Move a name to a new group in simulation (target must have room)
local function SimMove(sim, simGroups, name, targetGroup)
    local oldGroup = sim[name]
    SimRemoveFromGroup(simGroups, oldGroup, name)
    SimAddToGroup(simGroups, targetGroup, name)
    sim[name] = targetGroup
end

-- Plan the minimum set of moves using cycle decomposition.
--
-- The key insight: model "who is in whose seat" as a permutation and
-- decompose it into cycles. A cycle of length k costs k-1 swaps.
-- Additionally, when a target group has empty space we can use the
-- cheaper SetRaidSubgroup (1 move, no displacement).
--
-- Returns an ordered list of moves:
--   { type = "swap", nameA = ..., nameB = ... }
--   { type = "set",  name  = ..., targetGroup = ... }
local function PlanMoves(raidState, desired)
    local sim, simGroups = BuildSimulation(raidState)
    local moves = {}

    -- Phase 1: Group assignment via cycle decomposition
    --
    -- Build a mapping of "for each group slot, who currently sits there
    -- that wants to go somewhere else, and who wants to come in?"
    -- We model this as a directed graph: edges from currentGroup -> desiredGroup
    -- and find cycles in that graph via the players themselves.

    -- First, collect all players who need to change groups
    local wrongGroup = {} -- name -> { from = currentGroup, to = desiredGroup }
    for name, info in pairs(desired) do
        if sim[name] and sim[name] ~= info.desiredGroup then
            wrongGroup[name] = { from = sim[name], to = info.desiredGroup }
        end
    end

    -- Build a lookup: group -> list of names wanting to leave that group
    local wantToLeave = {} -- group -> { names wanting to leave }
    for g = 1, 8 do
        wantToLeave[g] = {}
    end

    for name, info in pairs(wrongGroup) do
        table.insert(wantToLeave[info.from], name)
    end

    -- Find beneficial swaps: player A in group X wants group Y,
    -- player B in group Y wants group X -> 1 swap handles both.
    -- More generally, find cycles in the permutation.
    local resolved = {}

    -- Pass 1: Find direct 2-cycles (mutual swaps) — most efficient
    for nameA, infoA in pairs(wrongGroup) do
        if not resolved[nameA] then
            for _, nameB in ipairs(wantToLeave[infoA.to]) do
                if not resolved[nameB] and wrongGroup[nameB] then
                    local infoB = wrongGroup[nameB]
                    if infoB.to == infoA.from then
                        -- Skip if either is raid leader (raidIndex 1)
                        local stateA = raidState[nameA]
                        local stateB = raidState[nameB]
                        if stateA.raidIndex ~= 1 and stateB.raidIndex ~= 1 then
                            table.insert(moves, { type = "swap", nameA = nameA, nameB = nameB })
                            SimSwap(sim, simGroups, nameA, nameB)
                            resolved[nameA] = true
                            resolved[nameB] = true

                            break
                        end
                    end
                end
            end
        end
    end

    -- Pass 2: Find longer cycles via chain-following
    -- For a cycle A->B->C->A of length 3, we need 2 swaps:
    --   swap(A, B) then swap(A, C)  — A walks along the chain
    for startName, startInfo in pairs(wrongGroup) do
        if not resolved[startName] then
            -- Follow the chain: find someone in startInfo.to who wants out
            local chain = { startName }
            local visited = { [startName] = true }
            local current = startName

            while true do
                local currentTarget = wrongGroup[current] and wrongGroup[current].to
                if not currentTarget then
                    break
                end

                -- Find an unresolved player in currentTarget who wants to leave
                local nextPlayer = nil
                for _, candidate in ipairs(wantToLeave[currentTarget]) do
                    if not resolved[candidate] and not visited[candidate] then
                        nextPlayer = candidate

                        break
                    end
                end

                if not nextPlayer then
                    break
                end

                table.insert(chain, nextPlayer)
                visited[nextPlayer] = true

                -- Does this player want to go back to the start? (cycle closed)
                local nextTarget = wrongGroup[nextPlayer] and wrongGroup[nextPlayer].to
                if nextTarget == wrongGroup[startName].from then
                    -- Cycle found! Resolve with len-1 swaps
                    -- Swap chain[1] with each subsequent member
                    local anchor = chain[1]
                    for j = 2, #chain do
                        local partner = chain[j]
                        local stateAnchor = raidState[anchor]
                        local statePartner = raidState[partner]
                        if stateAnchor.raidIndex ~= 1 and statePartner.raidIndex ~= 1 then
                            table.insert(moves, { type = "swap", nameA = anchor, nameB = partner })
                            SimSwap(sim, simGroups, anchor, partner)
                        end
                    end

                    for _, name in ipairs(chain) do
                        resolved[name] = true
                    end

                    break
                end

                current = nextPlayer
            end
        end
    end

    -- Pass 3: Remaining players who still need to move (no cycle partner found)
    -- Use SetRaidSubgroup if target group has room, otherwise swap with someone
    -- in the target group who doesn't belong there.
    -- Sort by desired position so players entering a group land in position order,
    -- which can avoid needing Phase 2 for those groups.
    local remaining = {}
    for name in pairs(wrongGroup) do
        if not resolved[name] then
            table.insert(remaining, name)
        end
    end

    table.sort(remaining, function(a, b)
        local da = desired[a]
        local db = desired[b]
        if da.desiredGroup ~= db.desiredGroup then
            return da.desiredGroup < db.desiredGroup
        end

        return da.desiredPosition < db.desiredPosition
    end)

    for _, name in ipairs(remaining) do
        if sim[name] ~= desired[name].desiredGroup then
            local targetGroup = desired[name].desiredGroup

            if SimGroupCount(simGroups, targetGroup) < 5 then
                table.insert(moves, { type = "set", name = name, targetGroup = targetGroup })
                SimMove(sim, simGroups, name, targetGroup)
            else
                -- Find someone in target group who doesn't belong there
                local evictee = nil
                for pos = 1, 5 do
                    local occupant = simGroups[targetGroup][pos]
                    if occupant then
                        local occupantDesired = desired[occupant]
                        local occupantBelongs = occupantDesired and occupantDesired.desiredGroup == targetGroup
                        if not occupantBelongs and raidState[occupant] and raidState[occupant].raidIndex ~= 1 then
                            evictee = occupant

                            break
                        end
                    end
                end

                if evictee and raidState[name] and raidState[name].raidIndex ~= 1 then
                    table.insert(moves, { type = "swap", nameA = name, nameB = evictee })
                    SimSwap(sim, simGroups, name, evictee)
                else
                    addon:Print("Warning: Cannot move " .. name .. " to group " .. targetGroup)
                end
            end
        end
    end

    -- Phase 2: Within-group position ordering via bridge swaps
    -- Rebuild simulation positions after all group moves
    -- For each group, check if positions match desired positions.
    -- Use 3-swap bridge maneuver only where needed.

    -- Rebuild clean position tracking from the simulated group state
    for name, info in pairs(desired) do
        if sim[name] == info.desiredGroup then
            -- Find current simulated position
            local currentPos = nil
            for pos, occupant in pairs(simGroups[info.desiredGroup]) do
                if occupant == name then
                    currentPos = pos

                    break
                end
            end

            if currentPos and currentPos ~= info.desiredPosition then
                -- Find who occupies the desired position
                local occupant = simGroups[info.desiredGroup][info.desiredPosition]
                if not occupant then
                    -- Position is empty, no swap needed — but WoW doesn't let
                    -- us pick a position with SetRaidSubgroup, so we can't fix this
                    -- without the bridge maneuver anyway.
                elseif raidState[name] and raidState[name].raidIndex ~= 1
                       and raidState[occupant] and raidState[occupant].raidIndex ~= 1 then
                    -- Find a bridge player in a different group
                    local bridgeName = nil
                    for bName, bGroup in pairs(sim) do
                        if bGroup ~= info.desiredGroup and raidState[bName] and raidState[bName].raidIndex ~= 1 then
                            bridgeName = bName

                            break
                        end
                    end

                    if bridgeName then
                        -- 3-swap bridge maneuver:
                        -- 1. swap(player, bridge) — player leaves group
                        -- 2. swap(bridge, occupant) — bridge takes occupant's spot
                        -- 3. swap(player, bridge) — player returns to occupant's old spot
                        table.insert(moves, { type = "swap", nameA = name, nameB = bridgeName })
                        table.insert(moves, { type = "swap", nameA = bridgeName, nameB = occupant })
                        table.insert(moves, { type = "swap", nameA = name, nameB = bridgeName })

                        -- Update simulation
                        SimSwap(sim, simGroups, name, bridgeName)
                        SimSwap(sim, simGroups, bridgeName, occupant)
                        SimSwap(sim, simGroups, name, bridgeName)
                    end
                end
            end
        end
    end

    return moves
end

--------------------------------------------------------------------------------
-- Execution — walk through the pre-planned move queue one step at a time
--------------------------------------------------------------------------------

-- Resolve a player name to their current raidIndex (re-scanned each step
-- because indices shift after every roster change)
local function FindRaidIndex(name)
    local count = GetNumGroupMembers()
    for i = 1, count do
        local rosterName = GetRaidRosterInfo(i)
        if rosterName then
            local normalized = addon:NormalizeName(rosterName)
            if normalized == name then
                return i
            end
        end
    end

    return nil
end

local function ExecuteNextMove()
    if addon.assignState ~= STATE_EXECUTING then
        return
    end

    -- Combat check
    local inCombat, combatants = AnyoneInCombat()
    if inCombat then
        local names = table.concat(combatants, ", ")
        addon:Print("Aborting: players in combat — " .. names)
        addon:StopApply()

        return
    end

    addon.moveIndex = addon.moveIndex + 1
    local move = addon.moveQueue[addon.moveIndex]

    if not move then
        addon:Print("Group assignment complete. (" .. (addon.moveIndex - 1) .. " moves)")
        addon:StopApply()

        return
    end

    if move.type == "set" then
        local idx = FindRaidIndex(move.name)
        if idx then
            SetRaidSubgroup(idx, move.targetGroup)
        else
            addon:Print("Skipping " .. move.name .. " (left raid)")
        end

        return
    end

    if move.type == "swap" then
        local idxA = FindRaidIndex(move.nameA)
        local idxB = FindRaidIndex(move.nameB)
        if idxA and idxB then
            -- Raid leader guard (should be handled in planning, but double-check)
            if idxA == 1 or idxB == 1 then
                addon:Print("Skipping swap involving raid leader")
            else
                SwapRaidSubgroup(idxA, idxB)
            end
        else
            addon:Print("Skipping swap: player left raid")
        end
    end
end

--------------------------------------------------------------------------------
-- Event wiring
--------------------------------------------------------------------------------

local function OnAssignmentRosterUpdate()
    if addon.assignState ~= STATE_EXECUTING then
        return
    end

    if addon.debounceTimer then
        addon.debounceTimer:Cancel()
        addon.debounceTimer = nil
    end

    addon.debounceTimer = C_Timer.NewTimer(DEBOUNCE_INTERVAL, function()
        addon.debounceTimer = nil
        ExecuteNextMove()
    end)
end

function addon:StartApply()
    if not IsInRaid() then
        self:Print("Not in a raid group.")

        return
    end

    local inCombat, combatants = AnyoneInCombat()
    if inCombat then
        local names = table.concat(combatants, ", ")
        self:Print("Cannot apply: players in combat — " .. names)

        return
    end

    -- Resolve any template slots to real players before planning
    if self:HasTemplateSlots() then
        self:ResolveTemplates()
    end

    -- Plan all moves up front
    local raidState = BuildRaidState()
    local desired = BuildDesiredState()
    local moves = PlanMoves(raidState, desired)

    if #moves == 0 then
        self:Print("Groups already match the layout.")

        return
    end

    self:Print("Applying layout: " .. #moves .. " moves planned.")
    self.moveQueue = moves
    self.moveIndex = 0
    self.assignState = STATE_EXECUTING

    if self.applyButton then
        self.applyButton:Disable()
        self.applyButton.label:SetTextColor(0.5, 0.5, 0.5)
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        OnAssignmentRosterUpdate()
    end)

    -- Execute the first move immediately
    ExecuteNextMove()
end

function addon:StopApply()
    self.assignState = STATE_IDLE
    self.moveQueue = {}
    self.moveIndex = 0

    if self.debounceTimer then
        self.debounceTimer:Cancel()
        self.debounceTimer = nil
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")

    if self.applyButton then
        self.applyButton:Enable()
        self.applyButton.label:SetTextColor(1, 1, 1)
    end
end
