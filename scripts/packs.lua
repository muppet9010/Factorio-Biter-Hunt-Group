--Packs manages a biter hunt group once triggered and calls back to the Groupss supplied functions when needed.
--Group is the reoccuring collection of a group of settings. A Pack is a specific instance of a group.

local Packs = {}
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local SharedData = require("scripts/shared-data")
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")

local biterHuntGroupPreTunnelEffectTime = 10
local testing_only1PackPerGroup = false

Packs.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("Packs.PackAction_Warning", Packs.PackAction_Warning)
    EventScheduler.RegisterScheduledEventType("Packs.PackAction_GroundMovement", Packs.PackAction_GroundMovement)
    EventScheduler.RegisterScheduledEventType("Packs.PackAction_PreSpawnEffect", Packs.PackAction_PreSpawnEffect)
    EventScheduler.RegisterScheduledEventType("Packs.PackAction_SpawnBiters", Packs.PackAction_SpawnBiters)
    EventScheduler.RegisterScheduledEventType("Packs.PackAction_BitersActive", Packs.PackAction_BitersActive)
    Interfaces.RegisterInterface("Packs.CreateNextPackForGroup", Packs.CreateNextPackForGroup)
    Events.RegisterHandler(defines.events.on_player_died, "BiterHuntGroups", Packs.OnPlayerDied)
    Events.RegisterHandler(defines.events.on_player_left_game, "BiterHuntGroups", Packs.OnPlayerLeftGame)
    Events.RegisterHandler(defines.events.on_player_driving_changed_state, "BiterHuntGroups", Packs.OnPlayerDrivingChangedState)
    Interfaces.RegisterInterface("Packs.GenerateUniqueId", Packs.GenerateUniqueId)
    Interfaces.RegisterInterface("Packs.DeletePack", Packs.DeletePack)
    Interfaces.RegisterInterface("Packs.AddBiterCountToPack", Packs.AddBiterCountToPack)
    Interfaces.RegisterInterface("Packs.ResetPackTimer", Packs.ResetPackTimer)
end

Packs.CreateNextPackForGroup = function(group)
    group.lastPackId = group.lastPackId + 1
    local pack = {}
    pack.id = group.lastPackId
    pack.group = group
    group.packs[pack.id] = pack
    group.results[pack.id] = {outcome = "scheduled", targetName = nil}
    pack.state = SharedData.biterHuntGroupState.scheduled
    pack.units = {}
    pack.targetPlayerID = nil
    pack.targetEntity = nil
    pack.targetName = nil
    pack.surface = nil
    pack.groundMovementEffects = {}
    pack.hasBeenTargetedAtSpawn = false
    pack.finalResultReached = false
    pack.warningTicks = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "warningTicks")
    pack.biterQuantityFormula = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "biterQuantityFormula")
    pack.rawPackSize = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "groupSize")
    pack.processedPackSize = 0
    Packs.UpdateProcessedBiterPackSize(pack)
    pack.spawnRadius = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "groupSpawnRadius")
    pack.evolutionBonus = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "evolutionBonus")
    pack.tunnellingTicks = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "tunnellingTicks")
    pack.warningText = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "warningText")
    pack.huntingText = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "huntingText")
    pack.validTargetPlayerNameList = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "playerNameList")

    Packs.SchedulePackWarningEvent(group, pack)
end

Packs.BiterPackAllDead = function(pack)
    if pack.state ~= SharedData.biterHuntGroupState.bitersActive then
        return
    end
    local packId = pack.id
    local group = pack.group
    group.packs[packId] = nil
    local uniqueId = Packs.GenerateUniqueId(group.id, packId)
    EventScheduler.RemoveScheduledEvents("Packs.PackAction_BitersActive", uniqueId)
end

Packs.DeletePack = function(group, pack)
    local packId = pack.id
    for _, unit in pairs(pack.units) do
        unit.destroy()
    end
    for _, groundEffect in pairs(pack.groundMovementEffects) do
        groundEffect.destroy()
    end
    group.packs[packId] = nil
    local uniqueId = Packs.GenerateUniqueId(group.id, packId)
    EventScheduler.RemoveScheduledEvents("Packs.PackAction_Warning", uniqueId)
    EventScheduler.RemoveScheduledEvents("Packs.PackAction_GroundMovement", uniqueId)
    EventScheduler.RemoveScheduledEvents("Packs.PackAction_PreSpawnEffect", uniqueId)
    EventScheduler.RemoveScheduledEvents("Packs.PackAction_SpawnBiters", uniqueId)
    EventScheduler.RemoveScheduledEvents("Packs.PackAction_BitersActive", uniqueId)
end

Packs.PackAction_Warning = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    if pack.rawPackSize == 0 then
        Packs.ResetPackTimer(pack.group, pack)
        return
    end
    pack.state = SharedData.biterHuntGroupState.warning
    Interfaces.Call("Gui.UpdateAllConnectedPlayers")
    local nextPackActionTick = tick + pack.warningTicks
    EventScheduler.ScheduleEvent(nextPackActionTick, "Packs.PackAction_GroundMovement", uniqueId, {pack = pack})
end

Packs.PackAction_GroundMovement = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    pack.state = SharedData.biterHuntGroupState.groundMovement
    if not testing_only1PackPerGroup then
        Packs.CreateNextPackForGroup(pack.group)
    end
    Packs.SelectTarget(pack)
    Packs.RecordResult("hunting", pack)
    Packs.CreateGroundMovement(pack)
    local nextPackActionTick = tick + pack.tunnellingTicks - biterHuntGroupPreTunnelEffectTime
    EventScheduler.ScheduleEvent(nextPackActionTick, "Packs.PackAction_PreSpawnEffect", uniqueId, {pack = pack})
end

Packs.PackAction_PreSpawnEffect = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    pack.state = SharedData.biterHuntGroupState.preBitersSpawnEffect
    Packs.SpawnEnemyPreEffects(pack)
    local nextPackActionTick = tick + biterHuntGroupPreTunnelEffectTime
    EventScheduler.ScheduleEvent(nextPackActionTick, "Packs.PackAction_SpawnBiters", uniqueId, {pack = pack})
end

Packs.PackAction_SpawnBiters = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    pack.state = SharedData.biterHuntGroupState.spawnBiters
    Packs.SpawnEnemies(pack)
    Packs.CommandEnemies(pack)
    local nextPackActionTick = tick + 60
    EventScheduler.ScheduleEvent(nextPackActionTick, "Packs.PackAction_BitersActive", uniqueId, {pack = pack})
end

Packs.PackAction_BitersActive = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    pack.state = SharedData.biterHuntGroupState.bitersActive
    for i, biter in pairs(pack.units) do
        if not biter.valid then
            pack.units[i] = nil
        end
    end
    if Utils.GetTableNonNilLength(pack.units) == 0 then
        Packs.RecordResult("bitersDied", pack)
        Packs.BiterPackAllDead(pack)
        Interfaces.Call("Gui.UpdateAllConnectedPlayers")
    else
        Packs.CommandEnemies(pack)
        local nextPackActionTick = tick + 60
        EventScheduler.ScheduleEvent(nextPackActionTick, "Packs.PackAction_BitersActive", uniqueId, {pack = pack})
    end
end

Packs.GenerateUniqueId = function(groupId, packId)
    return groupId .. "_" .. packId
end

Packs.ValidSurface = function(surface)
    if string.find(surface.name, "spaceship", 0, true) then
        return false
    end
    if string.find(surface.name, "Orbit", 0, true) then
        return false
    end
    return true
end

Packs.SelectTarget = function(pack)
    local validPlayers = {}
    if #pack.validTargetPlayerNameList == 0 then
        for _, player in pairs(game.connected_players) do
            if (player.vehicle ~= nil or player.character ~= nil) and Packs.ValidSurface(player.surface) then
                table.insert(validPlayers, player)
            end
        end
    else
        for _, playerName in pairs(pack.validTargetPlayerNameList) do
            local player = game.get_player(playerName)
            if player ~= nil and player.valid and player.connected and (player.vehicle ~= nil or player.character ~= nil) and Packs.ValidSurface(player.surface) then
                table.insert(validPlayers, player)
            end
        end
    end
    if #validPlayers >= 1 then
        local target = validPlayers[math.random(1, #validPlayers)]
        pack.targetPlayerID = target.index
        if target.vehicle ~= nil then
            pack.targetEntity = target.vehicle
        else
            pack.targetEntity = target.character
        end
        pack.targetName = target.name
        pack.surface = target.surface
    else
        Packs.SetSpawnAsTarget(pack)
        pack.surface = game.surfaces[1]
    end
    Interfaces.Call("Gui.UpdateAllConnectedPlayers")
end

Packs.SetSpawnAsTarget = function(pack)
    pack.targetPlayerID = nil
    pack.targetEntity = nil
    pack.targetName = "at Spawn"
end

Packs.GetPositionForTarget = function(pack)
    local surface = pack.surface
    local targetEntity = pack.targetEntity
    if targetEntity ~= nil then
        return targetEntity.position
    else
        return game.forces["player"].get_spawn_position(surface)
    end
end

Packs.CreateGroundMovement = function(pack)
    Packs._CreateGroundMovement(pack)
end
Packs._CreateGroundMovement = function(pack, distance, attempts)
    local debug = false
    local biterPositions = {}
    local packSize = pack.processedPackSize
    local angleRad = math.rad(360 / packSize)
    local surface = pack.surface
    local centerPosition = Packs.GetPositionForTarget(pack)
    distance = distance or pack.spawnRadius
    for i = 1, packSize do
        local x = centerPosition.x + (distance * math.cos(angleRad * i))
        local y = centerPosition.y + (distance * math.sin(angleRad * i))
        local foundPosition = surface.find_non_colliding_position("biter_hunt_group-biter_ground_movement", {x, y}, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
        end
    end
    Logging.Log("initial #biterPositions: " .. #biterPositions, debug)

    if #biterPositions < (packSize / 2) then
        distance = distance * 0.9
        attempts = attempts or 0
        attempts = attempts + 1
        Logging.Log("not enough places on attempt: " .. attempts, debug)
        if attempts > 3 then
            Logging.LogPrint("failed to find enough places to spawn enemies around " .. Logging.PositionToString(centerPosition))
            return
        else
            Packs._CreateGroundMovement(pack, distance, attempts)
            return
        end
    end

    for _, position in pairs(biterPositions) do
        Packs.SpawnGroundMovementEffect(pack, surface, position)
    end

    local maxAttempts = (packSize - #biterPositions) * 5
    local currentAttempts = 0
    Logging.Log("maxAttempts: " .. maxAttempts, debug)
    while #biterPositions < packSize do
        local positionToTry = biterPositions[math.random(1, #biterPositions)]
        local foundPosition = surface.find_non_colliding_position("biter_hunt_group-biter_ground_movement", positionToTry, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
            Packs.SpawnGroundMovementEffect(pack, surface, foundPosition)
        end
        currentAttempts = currentAttempts + 1
        if currentAttempts > maxAttempts then
            Logging.Log("currentAttempts > maxAttempts", debug)
            break
        end
    end
    Logging.Log("final #biterPositions: " .. #biterPositions, debug)
end

Packs.SpawnGroundMovementEffect = function(pack, surface, position)
    local effect = surface.create_entity {name = "biter_hunt_group-biter_ground_movement", position = position}
    if effect == nil then
        Logging.LogPrint("failed to make effect at: " .. Logging.PositionToString(position))
    else
        effect.destructible = false
        table.insert(pack.groundMovementEffects, effect)
    end
end

Packs.SpawnEnemyPreEffects = function(pack)
    local surface = pack.surface
    for _, groundEffect in pairs(pack.groundMovementEffects) do
        if not groundEffect.valid then
            Logging.LogPrint("ground effect has been removed by something, no SpawnEnemiePreEffects can be made")
        else
            local position = groundEffect.position
            surface.create_entity {name = "biter_hunt_group-biter_ground_rise_effect", position = position}
        end
    end
end

Packs.SpawnEnemies = function(pack)
    local surface = pack.surface
    local biterForce = game.forces["enemy"]
    local spawnerTypes = {"biter-spawner", "spitter-spawner"}
    local evolution = Utils.RoundNumberToDecimalPlaces(biterForce.evolution_factor + pack.evolutionBonus, 3)
    for _, groundEffect in pairs(pack.groundMovementEffects) do
        if not groundEffect.valid then
            Logging.LogPrint("ground effect has been removed by something, no biter can be made")
        else
            local position = groundEffect.position
            groundEffect.destroy()
            local spawnerType = spawnerTypes[math.random(2)]
            local enemyType = Utils.GetBiterType(global.EnemyProbabilities, spawnerType, evolution)
            local unit = surface.create_entity {name = enemyType, position = position, force = biterForce}
            if unit == nil then
                Logging.LogPrint("failed to make unit at: " .. Logging.PositionToString(position))
            else
                table.insert(pack.units, unit)
                unit.ai_settings.allow_destroy_when_commands_fail = false
                unit.ai_settings.allow_try_return_to_spawner = false
            end
        end
    end
end

Packs.CommandEnemies = function(pack)
    local debug = false
    if pack.hasBeenTargetedAtSpawn or Utils.GetTableNonNilLength(pack.units) == 0 then
        return
    end
    local targetEntity = pack.targetEntity
    if targetEntity ~= nil and not targetEntity.valid then
        Logging.LogPrint("ERROR - Biter target entity is invalid from command enemies - REPORT AS ERROR")
        Packs.TargetBitersAtSpawnFromError(pack)
        return
    end
    local attackCommand
    if targetEntity ~= nil then
        Logging.Log("CommandEnemies - targetEntity not nil - targetEntity: " .. targetEntity.name, debug)
        attackCommand = {type = defines.command.attack, target = targetEntity, distraction = defines.distraction.none}
    else
        Logging.Log("CommandEnemies - targetEntity is nil - target spawn", debug)
        pack.hasBeenTargetedAtSpawn = true
        attackCommand = {type = defines.command.attack_area, destination = Packs.GetPositionForTarget(pack), radius = 20, distraction = defines.distraction.by_anything}
    end
    for i, unit in pairs(pack.units) do
        if unit.valid then
            local applyCommand
            if not unit.has_command() then
                applyCommand = true
                Logging.Log("unit " .. i .. " has no command", debug)
            elseif unit.has_command() then
                if unit.command.type == defines.command.attack then
                    if targetEntity == nil then
                        applyCommand = true
                        Logging.Log("unit " .. i .. " attack nill target", debug)
                    elseif unit.command.target == nil then
                        applyCommand = true
                        Logging.Log("unit " .. i .. " attack no target", debug)
                    elseif not unit.command.target.valid then
                        applyCommand = true
                        Logging.Log("unit " .. i .. " attack invalid target", debug)
                    elseif unit.command.target ~= targetEntity then
                        applyCommand = true
                        Logging.Log("unit " .. i .. " attack old target entity", debug)
                    else
                        applyCommand = false
                        Logging.Log("unit " .. i .. " attack valid target", debug)
                    end
                elseif unit.command.type == defines.command.attack_area then
                    applyCommand = false
                    Logging.Log("unit " .. i .. " attack area", debug)
                else
                    applyCommand = true
                    Logging.Log("unit " .. i .. " other command", debug)
                end
            end
            if applyCommand then
                unit.set_command(attackCommand)
                Logging.LogPrint("unit " .. i .. " updated command", debug)
            end
        end
    end
end

Packs.TargetBitersAtSpawn = function(pack)
    game.print("[img=entity.medium-biter][img=entity.medium-biter][img=entity.medium-biter] rampaging towards spawn now!")
    pack.targetEntity = nil
    Packs.CommandEnemies(pack)
    Packs.BiterPackAllDead(pack)
end

Packs.TargetBitersAtSpawnFromError = function(pack)
    Packs.RecordResult("error", pack)
    Packs.TargetBitersAtSpawn(pack)
    Interfaces.Call("Gui.UpdateAllConnectedPlayers")
end

Packs.RecordResult = function(outcome, pack)
    if pack.finalResultReached then
        return
    end
    if outcome == "bitersDied" then
        game.print("[img=entity.medium-biter-corpse]      [img=entity.character]" .. pack.targetName .. " won")
        pack.finalResultReached = true
    elseif outcome == "playerDied" then
        game.print("[img=entity.medium-biter]      [img=entity.character-corpse]" .. pack.targetName .. " lost")
        pack.finalResultReached = true
    elseif outcome == "draw" then
        --not reached at present
        game.print("[img=entity.medium-biter]      [img=entity.character]" .. pack.targetName .. " draw")
        pack.finalResultReached = true
    elseif outcome == "playerLeft" then
        game.print("[img=entity.medium-biter]      [img=entity.character]" .. pack.targetName .. " fled like a coward")
        pack.finalResultReached = true
    elseif outcome == "hunting" then
        local biterTargetPos = Packs.GetPositionForTarget(pack)
        game.print("[img=entity.medium-biter][img=entity.medium-biter][img=entity.medium-biter]" .. " hunting " .. pack.targetName .. " at [gps=" .. math.floor(biterTargetPos.x) .. "," .. math.floor(biterTargetPos.y) .. "]")
    else
        Logging.LogPrint("ERROR: unrecognised result outcome: " .. outcome)
        outcome = "error"
        pack.finalResultReached = true
    end
    local result = pack.group.results[pack.id]
    result.outcome = outcome
    result.targetName = pack.targetName
end

Packs.GetPacksPlayerIdIsATargetFor = function(playerId)
    local targetPacks = {}
    for _, group in pairs(global.groups) do
        for _, pack in pairs(group.packs) do
            if pack.targetPlayerID == playerId then
                table.insert(targetPacks, pack)
            end
        end
    end
    return targetPacks
end

Packs.OnPlayerDied = function(event)
    local playerId = event.player_index
    local playerWasATarget = false
    for _, pack in pairs(Packs.GetPacksPlayerIdIsATargetFor(playerId)) do
        Packs.RecordResult("playerDied", pack)
        Packs.TargetBitersAtSpawn(pack)
        playerWasATarget = true
    end
    if playerWasATarget then
        Interfaces.Call("Gui.UpdateAllConnectedPlayers")
    end
end

Packs.OnPlayerLeftGame = function(event)
    local playerId = event.player_index
    local playerWasATarget = false
    for _, pack in pairs(Packs.GetPacksPlayerIdIsATargetFor(playerId)) do
        Packs.RecordResult("playerLeft", pack)
        Packs.TargetBitersAtSpawn(pack)
        playerWasATarget = true
    end
    if playerWasATarget then
        Interfaces.Call("Gui.UpdateAllConnectedPlayers")
    end
end

Packs.OnPlayerDrivingChangedState = function(event)
    local playerId = event.player_index
    for _, pack in pairs(Packs.GetPacksPlayerIdIsATargetFor(playerId)) do
        local player = game.get_player(playerId)
        if player.vehicle ~= nil then
            pack.TargetEntity = player.vehicle
        elseif player.character ~= nil then
            pack.TargetEntity = player.character
        else
            Logging.LogPrint("PANIC - player driving state changed and no vehicle or body!")
            Packs.TargetBitersAtSpawnFromError(pack)
        end
    end
end

Packs.AddBiterCountToPack = function(pack, count)
    pack.rawPackSize = pack.rawPackSize + count
    Packs.UpdateProcessedBiterPackSize(pack)
end

Packs.SchedulePackWarningEvent = function(group, pack)
    local packActionTick = game.tick + Packs.GetPackRandomTime(group)
    local uniqueId = Packs.GenerateUniqueId(group.id, pack.id)
    EventScheduler.ScheduleEvent(packActionTick, "Packs.PackAction_Warning", uniqueId, {pack = pack})
end

Packs.GetPackRandomTime = function(group)
    local rangeLowTick = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "groupFrequencyRangeLowTicks")
    local rangeHighTicks = Interfaces.Call("Groups.GetGlobalSettingForId", group.id, "groupFrequencyRangeHighTicks")
    return math.random(rangeLowTick, rangeHighTicks)
end

Packs.ResetPackTimer = function(group, pack)
    local uniqueId = Packs.GenerateUniqueId(group.id, pack.id)
    EventScheduler.RemoveScheduledEvents("Packs.PackAction_Warning", uniqueId)
    EventScheduler.RemoveScheduledEvents("Packs.PackAction_GroundMovement", uniqueId)
    Packs.SchedulePackWarningEvent(group, pack)
end

Packs.UpdateProcessedBiterPackSize = function(pack)
    local formula = pack.biterQuantityFormula
    if formula == nil or formula == "" then
        pack.processedPackSize = pack.rawPackSize
        return
    end
    local success, processedValue =
        pcall(
        function()
            return loadstring("local biterCount = " .. pack.rawPackSize .. "; return " .. formula)()
        end
    )
    if not success then
        Logging.LogPrint("ERROR: formula applied to biter count caused an error: '" .. processedValue .. "'")
        Logging.LogPrint("raw pack size: '" .. pack.rawPackSize .. "', formula: '" .. tostring(formula) .. "'")
        pack.processedPackSize = 0
        return
    end
    local processedValue_number = tonumber(processedValue)
    if processedValue_number ~= nil then
        pack.processedPackSize = processedValue_number
        return
    else
        Logging.LogPrint("ERROR: formula applied to biter count not a number. raw pack size: '" .. processedValue .. "', formula: '" .. tostring(formula) .. "'")
        pack.processedPackSize = 0
        return
    end
end

return Packs
