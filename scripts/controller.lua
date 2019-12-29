--Controller manages a biter hunt group once triggered and calls back to the managers supplied functions when needed.
--Group is the reoccuring collection of a group of settings. A Pack is a specific instance of a group.

local Controller = {}
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Constants = require("constants")
local SharedData = require("scripts/shared-data")
local Gui = require("scripts/gui")
local Interfaces = require("utility/interfaces")

local biterHuntGroupPreTunnelEffectTime = 10

Controller.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("Controller.ActionPack", Controller.ActionPack)
    Interfaces.RegisterInterface("Controller.CreatePack", Controller.CreatePack)
end

Controller.CreatePack = function(groupId)
    local group = global.Groups[groupId]
    group.lastPackId = group.lastPackId + 1

    local pack = {}
    pack.group = group
    pack.id = group.lastPackId
    pack.state = SharedData.BiterHuntGroupState.waiting
    pack.Units = pack.Units
    pack.currentlyTargetedAtSpawn = nil
    pack.targetPlayerID = nil
    pack.TargetEntity = nil
    pack.targetName = nil
    pack.Surface = nil
    pack.GroundMovementEffects = nil

    group.Packs[pack.id] = pack
end

Controller.ActionPack = function(event)
    local tick, groupId, data = event.tick, event.instanceId, event.data
    local group, packId = global.Groups[groupId], data.packId
    local pack = group.Packs[packId]
    local state = pack.state
    if state == SharedData.BiterHuntGroupState.waiting then
        pack.state = SharedData.BiterHuntGroupState.warning
        Gui.GuiUpdateAllConnected()
        local nextPackActionTick = tick + Interfaces.Call("Manager.GetGlobalSettingForId", groupId, "group_incomming_warning_seconds")
        EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.ActionPack", groupId, {groupId = groupId, packId = packId})
        return
    elseif state == SharedData.BiterHuntGroupState.warning then
        pack.state = SharedData.BiterHuntGroupState.groundMovement
        if group.Results[pack.id] ~= nil and group.Results[pack.id].playerWin == nil then
            game.print("[img=entity.medium-biter]      [img=entity.character]" .. pack.targetName .. " draw")
        end
        Controller.ClearGlobals(pack)
        Interfaces.Call("Manager.ScheduleNextPackForGroup", groupId)
        Controller.SelectTarget(pack)
        local biterTargetPos = Controller.GetPositionForTarget(pack)
        game.print("[img=entity.medium-biter][img=entity.medium-biter][img=entity.medium-biter]" .. " hunting " .. pack.targetName .. " at [gps=" .. math.floor(biterTargetPos.x) .. "," .. math.floor(biterTargetPos.y) .. "]")
        group.Results[packId] = {playerWin = nil, targetName = pack.targetName}
        Controller.CreateGroundMovement(pack)
        local nextPackActionTick = tick + global.Settings.tunnellingTicks - biterHuntGroupPreTunnelEffectTime
        EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.ActionPack", groupId, {groupId = groupId, packId = packId})
    elseif state == SharedData.BiterHuntGroupState.groundMovement then
        pack.state = SharedData.BiterHuntGroupState.preBitersSpawnEffect
        Controller.SpawnEnemyPreEffects(pack)
        local nextPackActionTick = tick + biterHuntGroupPreTunnelEffectTime
        EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.ActionPack", groupId, {groupId = groupId, packId = packId})
    elseif state == SharedData.BiterHuntGroupState.preBitersSpawnEffect then
        pack.state = SharedData.BiterHuntGroupState.bitersActive
        Controller.EnsureValidateTarget(pack)
        Controller.SpawnEnemies(group, pack)
        Controller.CommandEnemies(group, pack)
    elseif state == SharedData.BiterHuntGroupState.bitersActive then
        for i, biter in pairs(pack.Units) do
            if not biter.valid then
                pack.Units[i] = nil
            end
        end
        if Utils.GetTableNonNilLength(pack.Units) == 0 then
            --TODO: remove pack from array as all finished with at the end of this
            if group.Results[packId].playerWin == nil then
                group.Results[packId].playerWin = true
                game.print("[img=entity.medium-biter-corpse]      [img=entity.character]" .. pack.targetName .. " won")
            end
            Controller.ClearGlobals(pack)
        else
            Controller.CommandEnemies(group, pack)
        end
    end
end

Controller.ClearGlobals = function(pack)
    pack.targetPlayerID = nil
    pack.TargetEntity = nil
    pack.targetName = nil
    pack.unitsTargetedAtSpawn = nil
    Gui.GuiUpdateAllConnected()
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
            pack.TargetEntity = target.vehicle
        else
            pack.TargetEntity = target.character
        end
        pack.targetName = target.name
        pack.Surface = target.surface
    else
        pack.targetPlayerID = nil
        pack.TargetEntity = nil
        pack.targetName = "at Spawn"
        pack.Surface = game.surfaces[1]
    end
    Gui.GuiUpdateAllConnected()
end

Controller.EnsureValidateTarget = function(pack)
    local targetEntity = pack.TargetEntity
    if targetEntity ~= nil and (not targetEntity.valid) then
        pack.targetPlayerID = nil
        pack.TargetEntity = nil
        pack.targetName = "Spawn"
        Gui.GuiUpdateAllConnected()
    end
end

Controller.GetPositionForTarget = function(pack)
    local surface = pack.Surface
    local targetEntity = pack.TargetEntity
    if targetEntity ~= nil and targetEntity.valid then
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
    local group = pack.group
    local biterPositions = {}
    local groupSize = group.groupSize
    local angleRad = math.rad(360 / groupSize)
    local surface = pack.Surface
    local centerPosition = Controller.GetPositionForTarget(pack)
    distance = distance or group.groupSpawnRadius
    for i = 1, groupSize do
        local x = centerPosition.x + (distance * math.cos(angleRad * i))
        local y = centerPosition.y + (distance * math.sin(angleRad * i))
        local foundPosition = surface.find_non_colliding_position(Constants.ModName .. "-biter_ground_movement", {x, y}, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
        end
    end
    Logging.Log("initial #biterPositions: " .. #biterPositions, debug)

    if #biterPositions < (groupSize / 2) then
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

    pack.GroundMovementEffects = {}
    for _, position in pairs(biterPositions) do
        Controller.SpawnGroundMovementEffect(pack, surface, position)
    end

    local maxAttempts = (groupSize - #biterPositions) * 5
    local currentAttempts = 0
    Logging.Log("maxAttempts: " .. maxAttempts, debug)
    while #biterPositions < groupSize do
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
        table.insert(pack.GroundMovementEffects, effect)
    end
end

Controller.SpawnEnemyPreEffects = function(pack)
    local surface = pack.Surface
    for _, groundEffect in pairs(pack.GroundMovementEffects) do
        if not groundEffect.valid then
            Logging.LogPrint("ground effect has been removed by something, no SpawnEnemiePreEffects can be made")
        else
            local position = groundEffect.position
            surface.create_entity {name = Constants.ModName .. "-biter_ground_rise_effect", position = position}
        end
    end
end

Controller.SpawnEnemies = function(group, pack)
    local surface = pack.Surface
    local biterForce = game.forces["enemy"]
    local spawnerTypes = {"biter-spawner", "spitter-spawner"}
    local evolution = Utils.RoundNumberToDecimalPlaces(biterForce.evolution_factor + group.evolutionBonus, 3)
    pack.Units = {}
    for _, groundEffect in pairs(pack.GroundMovementEffects) do
        if not groundEffect.valid then
            Logging.LogPrint("ground effect has been removed by something, no biter can be made")
        else
            local position = groundEffect.position
            groundEffect.destroy()
            local spawnerType = spawnerTypes[math.random(2)]
            local enemyType = Utils.GetBiterType(global.BiterHuntGroup.EnemyProbabilities, spawnerType, evolution)
            local unit = surface.create_entity {name = enemyType, position = position, force = biterForce}
            if unit == nil then
                Logging.LogPrint("failed to make unit at: " .. Logging.PositionToString(position))
            else
                table.insert(pack.Units, unit)
                unit.ai_settings.allow_destroy_when_commands_fail = false
                unit.ai_settings.allow_try_return_to_spawner = false
            end
        end
    end
end

--TODO: should this call check valid target?
Controller.CommandEnemies = function(group, pack)
    local debug = false
    local targetEntity = pack.TargetEntity
    if targetEntity ~= nil and not targetEntity.valid then
        Controller.TargetBitersAtSpawnFromError(group, pack)
        Logging.LogPrint("ERROR - Biter target entity is invalid from command enemies - REPORT AS ERROR")
        return
    end
    local attackCommand
    if targetEntity ~= nil then
        Logging.Log("CommandEnemies - targetEntity not nil - targetEntity: " .. targetEntity.name, debug)
        pack.unitsTargetedAtSpawn = false
        attackCommand = {type = defines.command.attack, target = targetEntity, distraction = defines.distraction.none}
    else
        Logging.Log("CommandEnemies - targetEntity is nil - target spawn", debug)
        if pack.unitsTargetedAtSpawn then
            return
        end
        pack.unitsTargetedAtSpawn = true
        attackCommand = {type = defines.command.attack_area, destination = Controller.GetPositionForTarget(pack), radius = 20, distraction = defines.distraction.by_anything}
    end
    for i, unit in pairs(pack.Units) do
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

Controller.TargetBitersAtSpawn = function(group, pack)
    pack.TargetEntity = nil
    Controller.CommandEnemies(group, pack)
    Controller.ClearGlobals(pack)
end

Controller.TargetBitersAtSpawnFromError = function(group, pack)
    if group.Results[pack.id].playerWin == nil then
        group.Results[pack.id].playerWin = true
    end
    Controller.TargetBitersAtSpawn(group, pack)
end

return Controller
