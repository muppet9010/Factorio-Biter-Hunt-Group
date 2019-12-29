--Controller manages a biter hunt group once triggered and calls back to the managers supplied functions when needed.

local Controller = {}
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Constants = require("constants")

local biterHuntGroupPreTunnelEffectTime = 10
local biterHuntGroupState = {start = "start", groundMovement = "groundMovement", preBitersActiveEffect = "preBitersActiveEffect", bitersActive = "bitersActive"}

Controller.On10Ticks = function(event)
    local tick = event.tick
    EventScheduler.ScheduleEvent(tick + 10, "BiterHuntGroup.On10Ticks", nil, nil)
    if tick >= global.BiterHuntGroup.nextGroupTickWarning and not global.BiterHuntGroup.showIncomingGroupWarning then
        global.BiterHuntGroup.showIncomingGroupWarning = true
        BiterHuntGroup.GuiUpdateAllConnected()
    elseif tick >= global.BiterHuntGroup.nextGroupTick then
        global.BiterHuntGroup.showIncomingGroupWarning = nil
        if global.BiterHuntGroup.Results[global.BiterHuntGroup.id] ~= nil and global.BiterHuntGroup.Results[global.BiterHuntGroup.id].playerWin == nil then
            game.print("[img=entity.medium-biter]      [img=entity.character]" .. global.BiterHuntGroup.targetName .. " draw")
        end
        BiterHuntGroup.ClearGlobals()
        BiterHuntGroup.ScheduleNextBiterHuntGroup()
        global.BiterHuntGroup.state = biterHuntGroupState.groundMovement
        global.BiterHuntGroup.stateChangeTick = tick + global.Settings.tunnellingTicks - biterHuntGroupPreTunnelEffectTime
        BiterHuntGroup.SelectTarget()
        local biterTargetPos = BiterHuntGroup.GetPositionForTarget()
        game.print("[img=entity.medium-biter][img=entity.medium-biter][img=entity.medium-biter]" .. " hunting " .. global.BiterHuntGroup.targetName .. " at [gps=" .. math.floor(biterTargetPos.x) .. "," .. math.floor(biterTargetPos.y) .. "]")
        global.BiterHuntGroup.id = global.BiterHuntGroup.id + 1
        global.BiterHuntGroup.Results[global.BiterHuntGroup.id] = {playerWin = nil, targetName = global.BiterHuntGroup.targetName}
        BiterHuntGroup.CreateGroundMovement()
    elseif global.BiterHuntGroup.state == biterHuntGroupState.groundMovement then
        if tick < (global.BiterHuntGroup.stateChangeTick) then
            BiterHuntGroup.EnsureValidateTarget()
        else
            global.BiterHuntGroup.state = biterHuntGroupState.preBitersActiveEffect
            global.BiterHuntGroup.stateChangeTick = tick + biterHuntGroupPreTunnelEffectTime
            BiterHuntGroup.EnsureValidateTarget()
            BiterHuntGroup.SpawnEnemyPreEffects()
        end
    elseif global.BiterHuntGroup.state == biterHuntGroupState.preBitersActiveEffect then
        if tick < (global.BiterHuntGroup.stateChangeTick) then
            BiterHuntGroup.EnsureValidateTarget()
        else
            global.BiterHuntGroup.state = biterHuntGroupState.bitersActive
            global.BiterHuntGroup.stateChangeTick = nil
            BiterHuntGroup.EnsureValidateTarget()
            BiterHuntGroup.SpawnEnemies()
            BiterHuntGroup.CommandEnemies()
        end
    elseif global.BiterHuntGroup.state == biterHuntGroupState.bitersActive then
        for i, biter in pairs(global.BiterHuntGroup.Units) do
            if not biter.valid then
                global.BiterHuntGroup.Units[i] = nil
            end
        end
        if Utils.GetTableNonNilLength(global.BiterHuntGroup.Units) == 0 then
            if global.BiterHuntGroup.Results[global.BiterHuntGroup.id].playerWin == nil then
                global.BiterHuntGroup.Results[global.BiterHuntGroup.id].playerWin = true
                game.print("[img=entity.medium-biter-corpse]      [img=entity.character]" .. global.BiterHuntGroup.targetName .. " won")
            end
            BiterHuntGroup.ClearGlobals()
        else
            BiterHuntGroup.CommandEnemies()
        end
    end
end

BiterHuntGroup.ClearGlobals = function()
    global.BiterHuntGroup.state = nil
    global.BiterHuntGroup.targetPlayerID = nil
    global.BiterHuntGroup.TargetEntity = nil
    global.BiterHuntGroup.targetName = nil
    global.BiterHuntGroup.unitsTargetedAtSpawn = nil
    BiterHuntGroup.GuiUpdateAllConnected()
end

BiterHuntGroup.GetPositionForTarget = function()
    local surface = global.BiterHuntGroup.Surface
    local targetEntity = global.BiterHuntGroup.TargetEntity
    if targetEntity ~= nil and targetEntity.valid then
        return targetEntity.position
    else
        return game.forces["player"].get_spawn_position(surface)
    end
end

BiterHuntGroup.CreateGroundMovement = function()
    BiterHuntGroup._CreateGroundMovement()
end
BiterHuntGroup._CreateGroundMovement = function(distance, attempts)
    local debug = false
    local biterPositions = {}
    local groupSize = global.Settings.groupSize
    local angleRad = math.rad(360 / groupSize)
    local surface = global.BiterHuntGroup.Surface
    local centerPosition = BiterHuntGroup.GetPositionForTarget()
    distance = distance or global.Settings.groupSpawnRadius
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
            BiterHuntGroup._CreateGroundMovement(distance, attempts)
            return
        end
    end

    global.BiterHuntGroup.GroundMovementEffects = {}
    for _, position in pairs(biterPositions) do
        BiterHuntGroup.SpawnGroundMovementEffect(surface, position)
    end

    local maxAttempts = (groupSize - #biterPositions) * 5
    local currentAttempts = 0
    Logging.Log("maxAttempts: " .. maxAttempts, debug)
    while #biterPositions < groupSize do
        local positionToTry = biterPositions[math.random(1, #biterPositions)]
        local foundPosition = surface.find_non_colliding_position(Constants.ModName .. "-biter_ground_movement", positionToTry, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
            BiterHuntGroup.SpawnGroundMovementEffect(surface, foundPosition)
        end
        currentAttempts = currentAttempts + 1
        if currentAttempts > maxAttempts then
            Logging.Log("currentAttempts > maxAttempts", debug)
            break
        end
    end
    Logging.Log("final #biterPositions: " .. #biterPositions, debug)
end

BiterHuntGroup.SpawnGroundMovementEffect = function(surface, position)
    local effect = surface.create_entity {name = Constants.ModName .. "-biter_ground_movement", position = position}
    if effect == nil then
        Logging.LogPrint("failed to make effect at: " .. Logging.PositionToString(position))
    else
        effect.destructible = false
        table.insert(global.BiterHuntGroup.GroundMovementEffects, effect)
    end
end

BiterHuntGroup.SpawnEnemyPreEffects = function()
    local surface = global.BiterHuntGroup.Surface
    for _, groundEffect in pairs(global.BiterHuntGroup.GroundMovementEffects) do
        if not groundEffect.valid then
            Logging.LogPrint("ground effect has been removed by something, no SpawnEnemiePreEffects can be made")
        else
            local position = groundEffect.position
            surface.create_entity {name = Constants.ModName .. "-biter_ground_rise_effect", position = position}
        end
    end
end

BiterHuntGroup.SpawnEnemies = function()
    local surface = global.BiterHuntGroup.Surface
    local biterForce = game.forces["enemy"]
    local spawnerTypes = {"biter-spawner", "spitter-spawner"}
    local evolution = Utils.RoundNumberToDecimalPlaces(biterForce.evolution_factor + global.Settings.evolutionBonus, 3)
    global.BiterHuntGroup.Units = {}
    for _, groundEffect in pairs(global.BiterHuntGroup.GroundMovementEffects) do
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
                table.insert(global.BiterHuntGroup.Units, unit)
                unit.ai_settings.allow_destroy_when_commands_fail = false
                unit.ai_settings.allow_try_return_to_spawner = false
            end
        end
    end
end

BiterHuntGroup.CommandEnemies = function()
    local debug = false
    local targetEntity = global.BiterHuntGroup.TargetEntity
    if targetEntity ~= nil and not targetEntity.valid then
        BiterHuntGroup.TargetBitersAtSpawnFromError()
        Logging.LogPrint("ERROR - Biter target entity is invalid from command enemies - REPORT AS ERROR")
        return
    end
    local attackCommand
    if targetEntity ~= nil then
        Logging.Log("CommandEnemies - targetEntity not nil - targetEntity: " .. targetEntity.name, debug)
        global.BiterHuntGroup.unitsTargetedAtSpawn = false
        attackCommand = {type = defines.command.attack, target = targetEntity, distraction = defines.distraction.none}
    else
        Logging.Log("CommandEnemies - targetEntity is nil - target spawn", debug)
        if global.BiterHuntGroup.unitsTargetedAtSpawn then
            return
        end
        global.BiterHuntGroup.unitsTargetedAtSpawn = true
        attackCommand = {type = defines.command.attack_area, destination = BiterHuntGroup.GetPositionForTarget(), radius = 20, distraction = defines.distraction.by_anything}
    end
    for i, unit in pairs(global.BiterHuntGroup.Units) do
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

BiterHuntGroup.TargetBitersAtSpawn = function()
    global.BiterHuntGroup.TargetEntity = nil
    BiterHuntGroup.CommandEnemies()
    BiterHuntGroup.ClearGlobals()
end

BiterHuntGroup.TargetBitersAtSpawnFromError = function()
    if global.BiterHuntGroup.Results[global.BiterHuntGroup.id].playerWin == nil then
        global.BiterHuntGroup.Results[global.BiterHuntGroup.id].playerWin = true
    end
    BiterHuntGroup.TargetBitersAtSpawn()
end

return Controller
