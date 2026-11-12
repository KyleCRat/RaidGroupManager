local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

local MIN_MOVE_INTERVAL = 0.05
local SAFETY_TIMEOUT = 2.0

-- Apply includes bench groups regardless of the instance's active group limit.
local APPLY_GROUPS = { 1, 2, 3, 4, 5, 6, 7, 8 }

local ProcessApplyState
local activeRun
local lastMoveAt

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

    for i = 1, 40 do
        local name, rank, subgroup = GetRaidRosterInfo(i)
        if name then
            groupCounts[subgroup] = groupCounts[subgroup] + 1
            local normalized = addon:NormalizeName(name)
            state[normalized] = {
                raidIndex = i,
                rank = rank,
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

    addon:ForEachGroupSlot(APPLY_GROUPS, function(slotIndex, group, pos)
        if addon:IsSlotPlayer(slotIndex) then
            local text = addon:GetSlotText(slotIndex)
            local normalized = addon:NormalizeName(text)
            if not seen[normalized] then
                seen[normalized] = true
                desired[normalized] = {
                    desiredGroup = group,
                    desiredPosition = pos,
                }
            end
        end
    end)

    return desired
end

local function BuildRosterSnapshot(raidState)
    local snapshot = {
        count = 0,
        members = {},
    }

    for name, member in pairs(raidState) do
        snapshot.members[name] = true
        snapshot.count = snapshot.count + 1
        if member.rank == 2 then snapshot.leader = name end
    end

    return snapshot
end

local function GetRosterChangeReason(snapshot, raidState)
    local current = BuildRosterSnapshot(raidState)
    local missingName = nil
    local addedName = nil

    for name in pairs(snapshot.members) do
        if not current.members[name] then
            missingName = name

            break
        end
    end

    for name in pairs(current.members) do
        if not snapshot.members[name] then
            addedName = name

            break
        end
    end

    if missingName and addedName then
        return "raid roster changed ("
            .. missingName
            .. " left, "
            .. addedName
            .. " joined)"
    end

    if missingName then return missingName .. " left the raid" end

    if addedName then return addedName .. " joined the raid" end

    if current.count ~= snapshot.count then return "raid size changed" end

    if current.leader ~= snapshot.leader then
        return "raid leadership changed"
    end

    return nil
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
        if not namedPlayers[name] then table.insert(available, member) end
    end

    -- Separate template slots into class-specific and generic (ANY)
    local classTemplates = {}
    local genericTemplates = {}
    self:ForEachGroupSlot(APPLY_GROUPS, function(slotIndex)
        if self:IsSlotTemplate(slotIndex) then
            local template = self:GetSlotTemplate(slotIndex)
            local entry = { index = slotIndex, template = template }
            if template.class == "ANY" then
                table.insert(genericTemplates, entry)
            else
                table.insert(classTemplates, entry)
            end
        end
    end)

    if #classTemplates == 0 and #genericTemplates == 0 then return end

    -- Pass 1: Match class+role templates (highest priority)
    for _, ts in ipairs(classTemplates) do
        local bestIdx = nil
        for i, member in ipairs(available) do
            local combatRole = self:GetCombatRole(member)
            if
                member.class == ts.template.class
                and combatRole == ts.template.role
            then
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

    -- Pass 2: Match generic role-only templates with class-balanced distribution.
    -- When a role's templates span two groups, use class-pairing so that
    -- duplicate classes are split across groups (e.g. 2 DKs → one per side).
    local ROLE_ORDER = { "TANK", "MELEE", "RANGED", "HEALER" }

    local roleTemplates = {}
    for _, ts in ipairs(genericTemplates) do
        local role = ts.template.role
        if not roleTemplates[role] then roleTemplates[role] = {} end
        table.insert(roleTemplates[role], ts)
    end

    for _, role in ipairs(ROLE_ORDER) do
        local templates = roleTemplates[role]
        if templates then
            -- Collect matching available players for this role
            local matching = {}
            for i = #available, 1, -1 do
                if self:GetCombatRole(available[i]) == role then
                    table.insert(matching, available[i])
                    table.remove(available, i)
                end
            end

            -- Group template slots by raid group
            local groupSlots = {}
            local groupOrder = {}
            for _, ts in ipairs(templates) do
                local g = math.ceil(ts.index / 5)
                if not groupSlots[g] then
                    groupSlots[g] = {}
                    table.insert(groupOrder, g)
                end
                table.insert(groupSlots[g], ts)
            end
            table.sort(groupOrder)

            if #groupOrder == 2 and #matching > 0 then
                -- Two groups: class-paired split within template capacities
                table.sort(matching, function(a, b)
                    return a.normalizedName < b.normalizedName
                end)

                local names = {}
                for _, m in ipairs(matching) do
                    table.insert(names, m.normalizedName)
                end

                local sideA, sideB = self:ClassPairSplit(names, roster)

                local slotsA = groupSlots[groupOrder[1]]
                local slotsB = groupSlots[groupOrder[2]]
                self:RebalanceSplitForCapacity(sideA, sideB, #slotsA, #slotsB)

                for i, ts in ipairs(slotsA) do
                    if i <= #sideA then self:SetSlotText(ts.index, sideA[i]) end
                end

                for i, ts in ipairs(slotsB) do
                    if i <= #sideB then self:SetSlotText(ts.index, sideB[i]) end
                end
            elseif #matching > 0 then
                -- Single group or 3+: sequential assignment
                table.sort(matching, function(a, b)
                    return a.normalizedName < b.normalizedName
                end)

                for i, ts in ipairs(templates) do
                    if i <= #matching then
                        self:SetSlotText(ts.index, matching[i].normalizedName)
                    end
                end
            end
        end
    end
end

function addon:HasTemplateSlots()
    local found = false
    self:ForEachGroupSlot(APPLY_GROUPS, function(slotIndex)
        if not found and self:IsSlotTemplate(slotIndex) then found = true end
    end)

    return found
end

-- Check if any raid member is in combat
local function AnyoneInCombat()
    local combatants = {}

    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) and UnitAffectingCombat(unit) then
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
-- The second return is true when required ordering has no staging group.
-- The third return explains a plan that cannot be completed safely.
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
                            table.insert(moves, {
                                type = "swap",
                                nameA = nameA,
                                nameB = nameB,
                                phase = "P1",
                                reason = "mutual swap g"
                                    .. infoA.from
                                    .. "<->g"
                                    .. infoA.to,
                            })
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
    for startName in pairs(wrongGroup) do
        if not resolved[startName] then
            -- Follow the chain: find someone in the target group who wants out
            local chain = { startName }
            local visited = { [startName] = true }
            local current = startName

            while true do
                local currentTarget = wrongGroup[current]
                    and wrongGroup[current].to
                if not currentTarget then break end

                -- Find an unresolved player in currentTarget who wants to leave
                local nextPlayer = nil
                for _, candidate in ipairs(wantToLeave[currentTarget]) do
                    if not resolved[candidate] and not visited[candidate] then
                        nextPlayer = candidate

                        break
                    end
                end

                if not nextPlayer then break end

                table.insert(chain, nextPlayer)
                visited[nextPlayer] = true

                -- Does this player want to go back to the start? (cycle closed)
                local nextTarget = wrongGroup[nextPlayer]
                    and wrongGroup[nextPlayer].to
                if nextTarget == wrongGroup[startName].from then
                    -- Cycle found! Resolve with len-1 swaps.
                    -- Swap anchor with chain members in REVERSE order:
                    -- the anchor walks backward through the cycle so each
                    -- partner lands in the correct seat.
                    local anchor = chain[1]
                    local chainHasLeader = false
                    for _, name in ipairs(chain) do
                        if
                            raidState[name]
                            and raidState[name].raidIndex == 1
                        then
                            chainHasLeader = true

                            break
                        end
                    end

                    if chainHasLeader then
                        -- Can't use SwapRaidSubgroup with the raid leader.
                        -- Resolve via SetRaidSubgroup: move leader to staging,
                        -- cascade remaining members through the freed slot,
                        -- then move leader to their target.
                        local leaderName, leaderFrom, leaderTo
                        for _, name in ipairs(chain) do
                            if
                                raidState[name]
                                and raidState[name].raidIndex == 1
                            then
                                leaderName = name
                                leaderFrom = wrongGroup[name].from
                                leaderTo = wrongGroup[name].to

                                break
                            end
                        end

                        local staging = nil
                        for g = 8, 1, -1 do
                            if SimGroupCount(simGroups, g) < 5 then
                                staging = g

                                break
                            end
                        end

                        if staging then
                            table.insert(moves, {
                                type = "set",
                                name = leaderName,
                                targetGroup = staging,
                                phase = "P1",
                                reason = "stage leader for cycle",
                            })
                            SimMove(sim, simGroups, leaderName, staging)

                            -- Build lookup: which players want each group (multiple players
                            -- can target the same group when the chain revisits a group)
                            local wantsGroup = {}
                            for _, name in ipairs(chain) do
                                if name ~= leaderName then
                                    local target = wrongGroup[name].to
                                    if not wantsGroup[target] then
                                        wantsGroup[target] = {}
                                    end

                                    table.insert(wantsGroup[target], name)
                                end
                            end

                            -- Follow the freed-slot cascade: leader freed leaderFrom,
                            -- move whoever wants that group, their departure frees another, etc.
                            local freeGroup = leaderFrom
                            for _ = 1, #chain - 1 do
                                local movers = wantsGroup[freeGroup]
                                if not movers or #movers == 0 then break end

                                local mover = table.remove(movers, 1)
                                local moverFrom = sim[mover]
                                table.insert(moves, {
                                    type = "set",
                                    name = mover,
                                    targetGroup = freeGroup,
                                    phase = "P1",
                                    reason = "cycle cascade to g" .. freeGroup,
                                })
                                SimMove(sim, simGroups, mover, freeGroup)
                                freeGroup = moverFrom
                            end

                            table.insert(moves, {
                                type = "set",
                                name = leaderName,
                                targetGroup = leaderTo,
                                phase = "P1",
                                reason = "move raid leader to target",
                            })
                            SimMove(sim, simGroups, leaderName, leaderTo)

                            for _, name in ipairs(chain) do
                                resolved[name] = true
                            end
                        end
                    else
                        for j = #chain, 2, -1 do
                            local partner = chain[j]
                            table.insert(moves, {
                                type = "swap",
                                nameA = anchor,
                                nameB = partner,
                                phase = "P1",
                                reason = "cycle chain step " .. (j - 1),
                            })
                            SimSwap(sim, simGroups, anchor, partner)
                        end

                        for _, name in ipairs(chain) do
                            resolved[name] = true
                        end
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
        if not resolved[name] then table.insert(remaining, name) end
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
                table.insert(moves, {
                    type = "set",
                    name = name,
                    targetGroup = targetGroup,
                    phase = "P1",
                    reason = "move to target (room available)",
                })
                SimMove(sim, simGroups, name, targetGroup)
            else
                -- Find someone in target group who doesn't belong there
                local evictee = nil
                for pos = 1, 5 do
                    local occupant = simGroups[targetGroup][pos]
                    if occupant then
                        local occupantDesired = desired[occupant]
                        local occupantBelongs = occupantDesired
                            and occupantDesired.desiredGroup == targetGroup
                        if
                            not occupantBelongs
                            and raidState[occupant]
                            and raidState[occupant].raidIndex ~= 1
                        then
                            evictee = occupant

                            break
                        end
                    end
                end

                if
                    evictee
                    and raidState[name]
                    and raidState[name].raidIndex ~= 1
                then
                    table.insert(moves, {
                        type = "swap",
                        nameA = name,
                        nameB = evictee,
                        phase = "P1",
                        reason = "evict "
                            .. evictee
                            .. " from g"
                            .. targetGroup,
                    })
                    SimSwap(sim, simGroups, name, evictee)
                elseif
                    evictee
                    and raidState[name]
                    and raidState[name].raidIndex == 1
                then
                    -- Raid leader can't use SwapRaidSubgroup — move evictee out first, then leader in.
                    -- The leader's old group may be full (leader is still there), so send the
                    -- evictee to a staging group first, move the leader, then place the evictee.
                    local leaderOldGroup = sim[name]
                    local evicteeTarget = desired[evictee]
                            and desired[evictee].desiredGroup
                        or leaderOldGroup

                    if SimGroupCount(simGroups, evicteeTarget) < 5 then
                        -- Evictee's destination has room — move directly
                        table.insert(moves, {
                            type = "set",
                            name = evictee,
                            targetGroup = evicteeTarget,
                            phase = "P1",
                            reason = "evict "
                                .. evictee
                                .. " from g"
                                .. targetGroup
                                .. " for leader",
                        })
                        SimMove(sim, simGroups, evictee, evicteeTarget)
                    else
                        -- Find a staging group with room
                        local staging = nil
                        for g = 8, 1, -1 do
                            if
                                SimGroupCount(simGroups, g) < 5
                                and g ~= targetGroup
                            then
                                staging = g

                                break
                            end
                        end

                        if staging then
                            table.insert(moves, {
                                type = "set",
                                name = evictee,
                                targetGroup = staging,
                                phase = "P1",
                                reason = "stage "
                                    .. evictee
                                    .. " from g"
                                    .. targetGroup
                                    .. " for leader",
                            })
                            SimMove(sim, simGroups, evictee, staging)
                        else
                            return nil,
                                false,
                                "no temporary space is available to move "
                                    .. evictee
                                    .. " out of group "
                                    .. targetGroup
                        end
                    end

                    table.insert(moves, {
                        type = "set",
                        name = name,
                        targetGroup = targetGroup,
                        phase = "P1",
                        reason = "move raid leader to target",
                    })
                    SimMove(sim, simGroups, name, targetGroup)
                else
                    return nil,
                        false,
                        "cannot make room for "
                            .. name
                            .. " in group "
                            .. targetGroup
                end
            end
        end
    end

    -- Phase 2: Within-group position ordering via evacuate-and-refill.
    -- Position within a group is determined by insertion order, so the only
    -- way to reorder is to pull players out and re-add them in the desired
    -- sequence using SetRaidSubgroup.

    -- Find a staging group (one with no desired members)
    local usedGroups = {}
    for _, info in pairs(desired) do
        usedGroups[info.desiredGroup] = true
    end

    local stagingGroup = nil
    for g = 8, 1, -1 do
        if not usedGroups[g] and SimGroupCount(simGroups, g) == 0 then
            stagingGroup = g

            break
        end
    end

    -- No empty unused group — clear the best candidate by moving its occupants out
    if not stagingGroup then
        local bestGroup, bestCount = nil, 6
        for g = 8, 1, -1 do
            if not usedGroups[g] then
                local c = SimGroupCount(simGroups, g)
                if c < bestCount then
                    bestGroup = g
                    bestCount = c
                end
            end
        end

        if bestGroup then
            -- Find another unused group to absorb the displaced members
            local overflow = nil
            for g = 8, 1, -1 do
                if
                    not usedGroups[g]
                    and g ~= bestGroup
                    and SimGroupCount(simGroups, g) + bestCount <= 5
                then
                    overflow = g

                    break
                end
            end

            if overflow then
                local toMove = {}
                for pos = 1, 5 do
                    if simGroups[bestGroup][pos] then
                        table.insert(toMove, simGroups[bestGroup][pos])
                    end
                end

                for _, name in ipairs(toMove) do
                    table.insert(moves, {
                        type = "set",
                        name = name,
                        targetGroup = overflow,
                        phase = "P2",
                        reason = "clear staging g"
                            .. bestGroup
                            .. " -> g"
                            .. overflow,
                    })
                    SimMove(sim, simGroups, name, overflow)
                end

                stagingGroup = bestGroup
            end
        end
    end

    for g = 1, 8 do
        if usedGroups[g] then
            -- Build desired order for this group: position -> name
            local desiredOrder = {}
            local memberCount = 0
            for name, info in pairs(desired) do
                if info.desiredGroup == g and sim[name] == g then
                    desiredOrder[info.desiredPosition] = name
                    memberCount = memberCount + 1
                end
            end

            if memberCount > 0 then
                -- Build current order from simulation
                local currentOrder = {}
                for pos = 1, 5 do
                    currentOrder[pos] = simGroups[g][pos]
                end

                -- Check if reordering is needed
                local needsReorder = false
                for pos = 1, 5 do
                    if
                        desiredOrder[pos]
                        and currentOrder[pos] ~= desiredOrder[pos]
                    then
                        needsReorder = true

                        break
                    end
                end

                if needsReorder then
                    -- Find the raid leader in this group — they're pinned
                    -- at position 1 (raidIndex 1 is always sorted first).
                    local leaderName = nil
                    for pos = 1, 5 do
                        local name = currentOrder[pos]
                        if
                            name
                            and raidState[name]
                            and raidState[name].raidIndex == 1
                        then
                            leaderName = name

                            break
                        end
                    end

                    -- Build desired order list, with the raid leader pinned
                    -- at position 1 and everyone else in desired order after.
                    local desiredList = {}
                    if leaderName then table.insert(desiredList, leaderName) end

                    for pos = 1, 5 do
                        if
                            desiredOrder[pos]
                            and desiredOrder[pos] ~= leaderName
                        then
                            table.insert(desiredList, desiredOrder[pos])
                        end
                    end

                    -- Build set of desired members so we don't touch extras
                    local desiredSet = {}
                    for _, name in ipairs(desiredList) do
                        desiredSet[name] = true
                    end

                    -- Re-check if reordering is still needed after pinning leader
                    local currentList = {}
                    for pos = 1, 5 do
                        if
                            currentOrder[pos] and desiredSet[currentOrder[pos]]
                        then
                            table.insert(currentList, currentOrder[pos])
                        end
                    end

                    local stillNeeded = false
                    for i = 1, #desiredList do
                        if desiredList[i] ~= currentList[i] then
                            stillNeeded = true

                            break
                        end
                    end

                    if stillNeeded and not stagingGroup then
                        return moves, true
                    end

                    if stillNeeded then
                        -- Full evacuation required — players retain internal
                        -- index ordering unless the group is completely emptied
                        -- before refilling.

                        -- Evacuate ALL desired members (skip extras not on grid)
                        for _, name in ipairs(currentList) do
                            table.insert(moves, {
                                type = "set",
                                name = name,
                                targetGroup = stagingGroup,
                                phase = "P2",
                                reason = "evacuate g"
                                    .. g
                                    .. " to staging g"
                                    .. stagingGroup,
                            })
                            SimMove(sim, simGroups, name, stagingGroup)
                        end

                        -- Refill in desired position order
                        for i, name in ipairs(desiredList) do
                            table.insert(moves, {
                                type = "set",
                                name = name,
                                targetGroup = g,
                                phase = "P2",
                                reason = "refill g"
                                    .. g
                                    .. " pos "
                                    .. i
                                    .. "/"
                                    .. #desiredList,
                            })
                            SimMove(sim, simGroups, name, g)
                        end
                    end
                end
            end
        end
    end

    return moves, false
end

--------------------------------------------------------------------------------
-- Validation and execution
--------------------------------------------------------------------------------

local function GetLayoutMismatch(raidState, desired, checkOrder)
    local orderedNames = {}
    for name, target in pairs(desired) do
        local member = raidState[name]
        if member then
            if member.currentGroup ~= target.desiredGroup then
                return name
                    .. " is in group "
                    .. member.currentGroup
                    .. ", expected group "
                    .. target.desiredGroup
            end
            local group = target.desiredGroup
            orderedNames[group] = orderedNames[group] or {}
            orderedNames[group][target.desiredPosition] = name
        end
    end

    -- Empty slots and members not on the board do not impose absolute positions.
    if checkOrder then
        for group = 1, 8 do
            local names = orderedNames[group]
            if names then
                local previousPosition = 0
                local previousName
                for position = 1, 5 do
                    local name = names[position]
                    if name then
                        local actualPosition = raidState[name].currentPosition
                        if actualPosition <= previousPosition then
                            return "group "
                                .. group
                                .. " has "
                                .. name
                                .. " before "
                                .. previousName
                                .. ", but the layout expects the reverse"
                        end
                        previousPosition = actualPosition
                        previousName = name
                    end
                end
            end
        end
    end

    return nil
end

-- Check the entire group's capacity sequence before sending any requests.
-- Only group membership is simulated here; live positions are checked at the end.
local function PrepareMoveQueue(raidState, desired, moves)
    local sim, simGroups = BuildSimulation(raidState)
    local checked = {}
    for _, move in ipairs(moves) do
        if move.type == "set" then
            local fromGroup = sim[move.name]
            if not fromGroup or not simGroups[move.targetGroup] then
                return nil, "a planned move has an unavailable member or group"
            end
            if fromGroup ~= move.targetGroup then
                if SimGroupCount(simGroups, move.targetGroup) >= 5 then
                    return nil,
                        "group "
                            .. move.targetGroup
                            .. " would be full when moving "
                            .. move.name
                end
                move.fromGroup = fromGroup
                checked[#checked + 1] = move
                SimMove(sim, simGroups, move.name, move.targetGroup)
            end
        elseif move.type == "swap" then
            local memberA, memberB =
                raidState[move.nameA], raidState[move.nameB]
            if not memberA or not memberB then
                return nil, "a planned swap has an unavailable member"
            end
            if memberA.raidIndex == 1 or memberB.raidIndex == 1 then
                return nil, "a planned swap involves the raid leader"
            end
            if sim[move.nameA] == sim[move.nameB] then
                return nil,
                    "a planned swap involves two members of the same group"
            end
            move.fromGroupA, move.fromGroupB = sim[move.nameA], sim[move.nameB]
            checked[#checked + 1] = move
            SimSwap(sim, simGroups, move.nameA, move.nameB)
        else
            return nil, "the move plan contains an unknown operation"
        end
    end

    for name, target in pairs(desired) do
        if sim[name] and sim[name] ~= target.desiredGroup then
            return nil,
                "the move plan cannot place "
                    .. name
                    .. " in group "
                    .. target.desiredGroup
        end
    end

    return checked
end

local function HasRaidPermission()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function CancelPendingTimers(pending)
    if not pending then return end

    if pending.verifyTimer then
        pending.verifyTimer:Cancel()
        pending.verifyTimer = nil
    end
    if pending.timeoutTimer then
        pending.timeoutTimer:Cancel()
        pending.timeoutTimer = nil
    end
end

local function AbortApply(run, reason)
    if activeRun ~= run then return end

    addon:Print(
        "Apply stopped: "
            .. reason
            .. ". ("
            .. run.completed
            .. "/"
            .. #run.moves
            .. " moves confirmed.)"
    )
    addon:StopApply()
end

local function GetRunMismatch(run, raidState, pending)
    if not IsInRaid() then return "you are no longer in a raid" end

    if not HasRaidPermission() then return "raid permission was lost" end

    local reason = GetRosterChangeReason(run.snapshot, raidState)
    if reason then return reason end

    local inCombat, combatants = AnyoneInCombat()
    if inCombat then
        return "players are in combat: " .. table.concat(combatants, ", ")
    end

    for name, expectedGroup in pairs(run.expectedGroups) do
        local actualGroup = raidState[name].currentGroup
        local targetGroup = pending and pending.targets[name]
        if actualGroup ~= expectedGroup and actualGroup ~= targetGroup then
            return name .. " unexpectedly moved to group " .. actualGroup
        end
    end

    return nil
end

local function ExecuteNextMove(run, raidState, groupCounts)
    if activeRun ~= run or run.pending then return end

    local move = run.moves[run.index]
    if not move then
        local mismatch =
            GetLayoutMismatch(raidState, run.desired, not run.orderingSkipped)
        if mismatch then
            AbortApply(run, mismatch)

            return
        end

        local message = run.orderingSkipped
                and "Group changes confirmed; player ordering was skipped."
            or "Group assignment complete."
        addon:Print(message .. " (" .. run.completed .. " moves confirmed.)")
        addon:StopApply()

        return
    end

    local remaining = lastMoveAt
            and (lastMoveAt + MIN_MOVE_INTERVAL - GetTime())
        or 0
    if remaining > 0 then
        if not run.pacingTimer then
            run.pacingTimer = C_Timer.NewTimer(remaining, function()
                run.pacingTimer = nil
                -- Re-read the roster after waiting; this snapshot is now stale.
                ProcessApplyState(run)
            end)
        end

        return
    end

    local targets = {}
    local description
    if move.type == "set" then
        if raidState[move.name].currentGroup ~= move.fromGroup then
            AbortApply(run, "the source group changed for " .. move.name)

            return
        end
        if groupCounts[move.targetGroup] >= 5 then
            AbortApply(run, "group " .. move.targetGroup .. " is full")

            return
        end
        targets[move.name] = move.targetGroup
        description = move.name
            .. " group "
            .. move.fromGroup
            .. " -> "
            .. move.targetGroup
    else
        local memberA, memberB = raidState[move.nameA], raidState[move.nameB]
        if memberA.raidIndex == 1 or memberB.raidIndex == 1 then
            AbortApply(run, "the next swap involves the raid leader")

            return
        end
        if
            memberA.currentGroup ~= move.fromGroupA
            or memberB.currentGroup ~= move.fromGroupB
        then
            AbortApply(run, "the source groups changed for the next swap")

            return
        end
        targets[move.nameA], targets[move.nameB] =
            move.fromGroupB, move.fromGroupA
        description = move.nameA
            .. " (g"
            .. move.fromGroupA
            .. ") <-> "
            .. move.nameB
            .. " (g"
            .. move.fromGroupB
            .. ")"
    end

    local pending = { targets = targets }
    run.pending = pending
    pending.timeoutTimer = C_Timer.NewTimer(SAFETY_TIMEOUT, function()
        ProcessApplyState(run, pending, true)
    end)
    addon:Debug(
        "["
            .. run.index
            .. "/"
            .. #run.moves
            .. "] "
            .. move.phase
            .. ": "
            .. description
            .. " ("
            .. move.reason
            .. ")"
    )

    -- Resolve indices from this live snapshot, never from the original plan.
    lastMoveAt = GetTime()
    if move.type == "set" then
        SetRaidSubgroup(raidState[move.name].raidIndex, move.targetGroup)
    else
        SwapRaidSubgroup(
            raidState[move.nameA].raidIndex,
            raidState[move.nameB].raidIndex
        )
    end
end

ProcessApplyState = function(run, pending, timedOut)
    if activeRun ~= run or run.pending ~= pending then return end

    local raidState, groupCounts = BuildRaidState()
    local reason = GetRunMismatch(run, raidState, pending)
    if reason then
        AbortApply(run, reason)

        return
    end

    if pending then
        local mismatches = {}
        for name, targetGroup in pairs(pending.targets) do
            local actualGroup = raidState[name].currentGroup
            if actualGroup ~= targetGroup then
                mismatches[#mismatches + 1] = name
                    .. " is in group "
                    .. actualGroup
                    .. ", expected group "
                    .. targetGroup
            end
        end

        if #mismatches > 0 then
            if timedOut then
                AbortApply(
                    run,
                    "move "
                        .. run.index
                        .. " timed out: "
                        .. table.concat(mismatches, "; ")
                )
            end

            return
        end

        CancelPendingTimers(pending)
        for name, targetGroup in pairs(pending.targets) do
            run.expectedGroups[name] = targetGroup
        end
        addon:Debug("[" .. run.index .. "/" .. #run.moves .. "] confirmed")
        run.pending = nil
        run.completed = run.completed + 1
        run.index = run.index + 1
    end

    -- No yield: confirmation and dispatch share this freshly checked snapshot.
    ExecuteNextMove(run, raidState, groupCounts)
end

local function OnAssignmentRosterUpdate()
    local run = activeRun
    if not run or not run.pending then return end

    local pending = run.pending
    if pending.verifyTimer then return end

    -- Coalesce an event burst to the next frame, without a fixed per-move delay.
    pending.verifyTimer = C_Timer.NewTimer(0, function()
        pending.verifyTimer = nil
        ProcessApplyState(run, pending, false)
    end)
end

function addon:StartApply()
    if activeRun then
        self:Print("A layout is already being applied.")

        return
    end

    if not IsInRaid() then
        self:Print("Not in a raid group.")

        return
    end

    if not HasRaidPermission() then
        self:Print("You must be the raid leader or have assist to apply.")

        return
    end

    local inCombat, combatants = AnyoneInCombat()
    if inCombat then
        local names = table.concat(combatants, ", ")
        self:Print("Cannot apply: players in combat — " .. names)

        return
    end

    local boardChanged = false

    -- Resolve any template slots to real players before planning
    if self:HasTemplateSlots() then
        self:ResolveTemplates()
        boardChanged = true
    end

    if self:EnsureRaidLeaderSlotOne(true) then boardChanged = true end

    if boardChanged then
        self:RefreshAllSlots()
        self:RefreshUnassigned()
        self:TryAutoSave()
    end

    -- Plan all moves up front
    local raidState = BuildRaidState()
    local desired = BuildDesiredState()
    local moves, orderingSkipped, planningError = PlanMoves(raidState, desired)
    if not planningError then
        moves, planningError = PrepareMoveQueue(raidState, desired, moves)
    end
    if planningError then
        self:Print("Cannot apply layout: " .. planningError .. ".")

        return
    end

    if orderingSkipped then
        self:Print(
            "Cannot reorder players within groups: no free group is available for temporary moves."
        )
    end

    if #moves == 0 then
        local mismatch =
            GetLayoutMismatch(raidState, desired, not orderingSkipped)
        if mismatch then
            self:Print("Cannot apply layout: " .. mismatch .. ".")
        elseif not orderingSkipped then
            self:Print("Groups already match the layout.")
        end

        return
    end

    self:Print("Applying layout: " .. #moves .. " moves planned.")
    local expectedGroups = {}
    for name, member in pairs(raidState) do
        expectedGroups[name] = member.currentGroup
    end
    local run = {
        moves = moves,
        index = 1,
        completed = 0,
        snapshot = BuildRosterSnapshot(raidState),
        desired = desired,
        expectedGroups = expectedGroups,
        orderingSkipped = orderingSkipped,
    }
    activeRun = run

    if self.applyButton then
        self.applyButton:Disable()
        self.applyButton.label:SetTextColor(0.5, 0.5, 0.5)
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", OnAssignmentRosterUpdate)

    -- Execute the first move immediately
    ProcessApplyState(run)
end

function addon:StopApply()
    local run = activeRun
    if not run then return end

    activeRun = nil
    CancelPendingTimers(run.pending)
    run.pending = nil
    if run.pacingTimer then
        run.pacingTimer:Cancel()
        run.pacingTimer = nil
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")

    if self.applyButton then
        self.applyButton:Enable()
        self.applyButton.label:SetTextColor(1, 1, 1)
    end
end
