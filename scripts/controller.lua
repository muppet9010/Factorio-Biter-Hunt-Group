--Controller manages a biter hunt group once triggered and calls back to the managers supplied functions when needed.
--Group is the reoccuring collection of a group of settings. A Pack is a specific instance of a group.

local Controller = {}
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Constants = require("constants")
local SharedData = require("scripts/shared-data")
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")

local biterHuntGroupPreTunnelEffectTime = 10
local testing_only1PackPerGroup = false

Controller.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("Controller.PackAction_Warning", Controller.PackAction_Warning)
    EventScheduler.RegisterScheduledEventType("Controller.PackAction_GroundMovement", Controller.PackAction_GroundMovement)
    EventScheduler.RegisterScheduledEventType("Controller.PackAction_PreSpawnEffect", Controller.PackAction_PreSpawnEffect)
    EventScheduler.RegisterScheduledEventType("Controller.PackAction_SpawnBiters", Controller.PackAction_SpawnBiters)
    EventScheduler.RegisterScheduledEventType("Controller.PackAction_BitersActive", Controller.PackAction_BitersActive)
    Interfaces.RegisterInterface("Controller.CreatePack", Controller.CreatePack)
    Events.RegisterHandler(defines.events.on_player_died, "BiterHuntGroupManager", Controller.OnPlayerDied)
    Events.RegisterHandler(defines.events.on_player_left_game, "BiterHuntGroupManager", Controller.OnPlayerLeftGame)
    Events.RegisterHandler(defines.events.on_player_driving_changed_state, "BiterHuntGroupManager", Controller.OnPlayerDrivingChangedState)
    Interfaces.RegisterInterface("Controller.GenerateUniqueId", Controller.GenerateUniqueId)
end

Controller.CreatePack = function(group)
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
    pack.groundMovementEffects = nil
    pack.hasBeenTargetedAtSpawn = false
    pack.finalResultReached = false
    pack.warningTicks = Interfaces.Call("Manager.GetGlobalSettingForId", group.id, "warningTicks")
    pack.packSize = Interfaces.Call("Manager.GetGlobalSettingForId", group.id, "groupSize")
    pack.spawnRadius = Interfaces.Call("Manager.GetGlobalSettingForId", group.id, "groupSpawnRadius")
    pack.evolutionBonus = Interfaces.Call("Manager.GetGlobalSettingForId", group.id, "evolutionBonus")
    pack.tunnellingTicks = Interfaces.Call("Manager.GetGlobalSettingForId", group.id, "tunnellingTicks")
    pack.warningText = Interfaces.Call("Manager.GetGlobalSettingForId", group.id, "warningText")
    pack.huntingText = Interfaces.Call("Manager.GetGlobalSettingForId", group.id, "huntingText")
    return pack
end

Controller.RemoveActiveBitersPack = function(pack)
    if pack.state ~= SharedData.biterHuntGroupState.bitersActive then
        return
    end
    local packId = pack.id
    local group = pack.group
    group.packs[packId] = nil
    Interfaces.Call("Gui.UpdateAllConnectedPlayers")
    local uniqueId = Controller.GenerateUniqueId(group.id, packId)
    EventScheduler.RemoveScheduledEvents("Controller.PackAction_BitersActive", uniqueId)
end

Controller.PackAction_Warning = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    pack.state = SharedData.biterHuntGroupState.warning
    Interfaces.Call("Gui.UpdateAllConnectedPlayers")
    local nextPackActionTick = tick + pack.warningTicks
    EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.PackAction_GroundMovement", uniqueId, {pack = pack})
end

Controller.PackAction_GroundMovement = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    local group = pack.group
    pack.state = SharedData.biterHuntGroupState.groundMovement
    if not testing_only1PackPerGroup then
        Interfaces.Call("Manager.ScheduleNextPackForGroup", group)
    end
    Controller.SelectTarget(pack)
    Controller.RecordResult("hunting", pack)
    Controller.CreateGroundMovement(pack)
    local nextPackActionTick = tick + pack.tunnellingTicks - biterHuntGroupPreTunnelEffectTime
    EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.PackAction_PreSpawnEffect", uniqueId, {pack = pack})
end

Controller.PackAction_PreSpawnEffect = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    pack.state = SharedData.biterHuntGroupState.preBitersSpawnEffect
    Controller.SpawnEnemyPreEffects(pack)
    local nextPackActionTick = tick + biterHuntGroupPreTunnelEffectTime
    EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.PackAction_SpawnBiters", uniqueId, {pack = pack})
end

Controller.PackAction_SpawnBiters = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    pack.state = SharedData.biterHuntGroupState.spawnBiters
    Controller.SpawnEnemies(pack)
    Controller.CommandEnemies(pack)
    local nextPackActionTick = tick + 60
    EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.PackAction_BitersActive", uniqueId, {pack = pack})
end

Controller.PackAction_BitersActive = function(event)
    local tick, uniqueId, pack = event.tick, event.instanceId, event.data.pack
    pack.state = SharedData.biterHuntGroupState.bitersActive
    for i, biter in pairs(pack.units) do
        if not biter.valid then
            pack.units[i] = nil
        end
    end
    if #pack.units == 0 then
        Controller.RecordResult("bitersDied", pack)
        Controller.RemoveActiveBitersPack(pack)
    else
        Controller.CommandEnemies(pack)
        local nextPackActionTick = tick + 60
        EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.PackAction_BitersActive", uniqueId, {pack = pack})
    end
end

Controller.GenerateUniqueId = function(groupId, packId)
    return groupId .. "_" .. packId
end

Controller.ValidSurface = function(surface)
    if string.find(surface.name, "spaceship", 0, true) then
        return false
    end
    if string.find(surface.name, "Orbit", 0, true) then
        return false
    end
    return true
end

Controller.SelectTarget = function(pack)
    local players = game.connected_players
    local validPlayers = {}
    for _, player in pairs(players) do
        if (player.vehicle ~= nil or player.character ~= nil) and Controller.ValidSurface(player.surface) then
            table.insert(validPlayers, player)
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
        Controller.SetSpawnAsTarget(pack)
        pack.surface = game.surfaces[1]
    end
    Interfaces.Call("Gui.UpdateAllConnectedPlayers")
end

Controller.SetSpawnAsTarget = function(pack)
    pack.targetPlayerID = nil
    pack.targetEntity = nil
    pack.targetName = "at Spawn"
end

Controller.GetPositionForTarget = function(pack)
    local surface = pack.surface
    local targetEntity = pack.targetEntity
    if targetEntity ~= nil then
        return targetEntity.position
    else
        return game.forces["player"].get_spawn_position(surface)
    end
end

Controller.CreateGroundMovement = function(pack)
    Controller._CreateGroundMovement(pack)
end
Controller._CreateGroundMovement = function(pack, distance, attempts)
    local debug = false
    local biterPositions = {}
    local packSize = pack.packSize
    local angleRad = math.rad(360 / packSize)
    local surface = pack.surface
    local centerPosition = Controller.GetPositionForTarget(pack)
    distance = distance or pack.spawnRadius
    for i = 1, packSize do
        local x = centerPosition.x + (distance * math.cos(angleRad * i))
        local y = centerPosition.y + (distance * math.sin(angleRad * i))
        local foundPosition = surface.find_non_colliding_position(Constants.ModName .. "-biter_ground_movement", {x, y}, 2, 1, true)
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
            Controller._CreateGroundMovement(pack, distance, attempts)
            return
        end
    end

    pack.groundMovementEffects = {}
    for _, position in pairs(biterPositions) do
        Controller.SpawnGroundMovementEffect(pack, surface, position)
    end

    local maxAttempts = (packSize - #biterPositions) * 5
    local currentAttempts = 0
    Logging.Log("maxAttempts: " .. maxAttempts, debug)
    while #biterPositions < packSize do
        local positionToTry = biterPositions[math.random(1, #biterPositions)]
        local foundPosition = surface.find_non_colliding_position(Constants.ModName .. "-biter_ground_movement", positionToTry, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
            Controller.SpawnGroundMovementEffect(pack, surface, foundPosition)
        end
        currentAttempts = currentAttempts + 1
        if currentAttempts > maxAttempts then
            Logging.Log("currentAttempts > maxAttempts", debug)
            break
        end
    end
    Logging.Log("final #biterPositions: " .. #biterPositions, debug)
end

Controller.SpawnGroundMovementEffect = function(pack, surface, position)
    local effect = surface.create_entity {name = Constants.ModName .. "-biter_ground_movement", position = position}
    if effect == nil then
        Logging.LogPrint("failed to make effect at: " .. Logging.PositionToString(position))
    else
        effect.destructible = false
        table.insert(pack.groundMovementEffects, effect)
    end
end

Controller.SpawnEnemyPreEffects = function(pack)
    local surface = pack.surface
    for _, groundEffect in pairs(pack.groundMovementEffects) do
        if not groundEffect.valid then
            Logging.LogPrint("ground effect has been removed by something, no SpawnEnemiePreEffects can be made")
        else
            local position = groundEffect.position
            surface.create_entity {name = Constants.ModName .. "-biter_ground_rise_effect", position = position}
        end
    end
end

Controller.SpawnEnemies = function(pack)
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

Controller.CommandEnemies = function(pack)
    local debug = false
    if pack.hasBeenTargetedAtSpawn or #pack.units == 0 then
        return
    end
    local targetEntity = pack.targetEntity
    if targetEntity ~= nil and not targetEntity.valid then
        Logging.LogPrint("ERROR - Biter target entity is invalid from command enemies - REPORT AS ERROR")
        Controller.TargetBitersAtSpawnFromError(pack)
        return
    end
    local attackCommand
    if targetEntity ~= nil then
        Logging.Log("CommandEnemies - targetEntity not nil - targetEntity: " .. targetEntity.name, debug)
        attackCommand = {type = defines.command.attack, target = targetEntity, distraction = defines.distraction.none}
    else
        Logging.Log("CommandEnemies - targetEntity is nil - target spawn", debug)
        pack.hasBeenTargetedAtSpawn = true
        attackCommand = {type = defines.command.attack_area, destination = Controller.GetPositionForTarget(pack), radius = 20, distraction = defines.distraction.by_anything}
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

Controller.TargetBitersAtSpawn = function(pack)
    game.print("[img=entity.medium-biter][img=entity.medium-biter][img=entity.medium-biter] rampaging towards spawn now!")
    pack.targetEntity = nil
    Controller.CommandEnemies(pack)
    Controller.RemoveActiveBitersPack(pack)
end

Controller.TargetBitersAtSpawnFromError = function(pack)
    Controller.RecordResult("error", pack)
    Controller.TargetBitersAtSpawn(pack)
end

Controller.RecordResult = function(outcome, pack)
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
        local biterTargetPos = Controller.GetPositionForTarget(pack)
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

Controller.GetPacksPlayerIdIsATargetFor = function(playerId)
    local targetPacks = {}
    for groupId = 1, global.groupsCount do
        local group = global.groups[groupId]
        for _, pack in pairs(group.packs) do
            if pack.targetPlayerID == playerId then
                table.insert(targetPacks, pack)
            end
        end
    end
    return targetPacks
end

Controller.OnPlayerDied = function(event)
    local playerId = event.player_index
    for _, pack in pairs(Controller.GetPacksPlayerIdIsATargetFor(playerId)) do
        Controller.RecordResult("playerDied", pack)
        Controller.TargetBitersAtSpawn(pack)
    end
end

Controller.OnPlayerLeftGame = function(event)
    local playerId = event.player_index
    for _, pack in pairs(Controller.GetPacksPlayerIdIsATargetFor(playerId)) do
        Controller.RecordResult("playerLeft", pack)
        Controller.TargetBitersAtSpawn(pack)
    end
end

Controller.OnPlayerDrivingChangedState = function(event)
    local playerId = event.player_index
    for _, pack in pairs(Controller.GetPacksPlayerIdIsATargetFor(playerId)) do
        local player = game.get_player(playerId)
        if player.vehicle ~= nil then
            pack.TargetEntity = player.vehicle
        elseif player.character ~= nil then
            pack.TargetEntity = player.character
        else
            Logging.LogPrint("PANIC - player driving state changed and no vehicle or body!")
            Controller.TargetBitersAtSpawn(pack)
        end
    end
end

return Controller
