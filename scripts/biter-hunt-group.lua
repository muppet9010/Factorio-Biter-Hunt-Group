local BiterHuntGroup = {}
local GUIUtil = require("utility/gui-util")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Commands = require("utility/commands")
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Constants = require("constants")

local biterHuntGroupPreTunnelEffectTime = 10
local biterHuntGroupState = {start = "start", groundMovement = "groundMovement", preBitersActiveEffect = "preBitersActiveEffect", bitersActive = "bitersActive"}
local testing = true

BiterHuntGroup.CreateGlobals = function()
    global.BiterHuntGroup = global.BiterHuntGroup or {}
    global.BiterHuntGroup.Units = global.BiterHuntGroup.Units or {}
    global.BiterHuntGroup.Results = global.BiterHuntGroup.Results or {}
    global.BiterHuntGroup.id = global.BiterHuntGroup.id or 0
    global.BiterHuntGroup.unitsTargetedAtSpawn = global.BiterHuntGroup.unitsTargetedAtSpawn or nil

    global.Settings = global.Settings or {}
    global.Settings.groupFrequencyRangeLowTicks = global.Settings.groupFrequencyRangeLowTicks or 0
    global.Settings.groupFrequencyRangeHighTicks = global.Settings.groupFrequencyRangeHighTicks or 0
    global.Settings.groupSize = global.Settings.groupSize or 0
    global.Settings.evolutionBonus = global.Settings.evolutionBonus or 0
    global.Settings.groupSpawnRadius = global.Settings.groupSpawnRadius or 0
    global.Settings.tunnellingTicks = global.Settings.tunnellingTicks or 0
    global.Settings.warningTicks = global.Settings.warningTicks or 0
end

BiterHuntGroup.OnLoad = function()
    Commands.Register("biters_attack_now", {"api-description.biter_hunt_group-biters_attack_now"}, BiterHuntGroup.MakeBitersAttackNow, true)
    Events.RegisterHandler(defines.events.on_player_joined_game, "BiterHuntGroup", BiterHuntGroup.OnPlayerJoinedGame)
    Events.RegisterHandler(defines.events.on_player_died, "BiterHuntGroup", BiterHuntGroup.OnPlayerDied)
    EventScheduler.RegisterScheduledEventType("BiterHuntGroup.On10Ticks", BiterHuntGroup.On10Ticks)
    Events.RegisterHandler(defines.events.on_player_left_game, "BiterHuntGroup", BiterHuntGroup.OnPlayerLeftGame)
    Commands.Register("biters_write_out_hunt_group_results", {"api-description.biter_hunt_group-biters_write_out_hunt_group_results"}, BiterHuntGroup.WriteOutHuntGroupResults, false)
    Events.RegisterHandler(defines.events.on_player_driving_changed_state, "BiterHuntGroup", BiterHuntGroup.OnPlayerDrivingChangedState)
end

BiterHuntGroup.OnStartup = function()
    BiterHuntGroup.OnRuntimeModSettingChanged(nil)
    if global.BiterHuntGroup.nextGroupTick == nil then
        global.BiterHuntGroup.nextGroupTick = game.tick
        BiterHuntGroup.ScheduleNextBiterHuntGroup()
    end
    BiterHuntGroup.UpdateNextGroupTickWarning()
    BiterHuntGroup.GuiRecreateAll()
    if not EventScheduler.IsEventScheduled("BiterHuntGroup.On10Ticks", nil, nil) then
        EventScheduler.ScheduleEvent(game.tick + 10, "BiterHuntGroup.On10Ticks", nil, nil)
    end
end

BiterHuntGroup.OnRuntimeModSettingChanged = function(event)
    if event == nil or event.setting == "group_frequency_range_low_minutes" then
        global.Settings.groupFrequencyRangeLowTicks = tonumber(settings.global["group_frequency_range_low_minutes"].value) * 60 * 60
    end
    if event == nil or event.setting == "group_frequency_range_high_minutes" then
        global.Settings.groupFrequencyRangeHighTicks = tonumber(settings.global["group_frequency_range_high_minutes"].value) * 60 * 60
    end
    if event == nil or event.setting == "group_size" then
        global.Settings.groupSize = tonumber(settings.global["group_size"].value)
    end
    if event == nil or event.setting == "group_evolution_bonus_percent" then
        local value = tonumber(settings.global["group_evolution_bonus_percent"].value)
        if value > 0 then
            global.Settings.evolutionBonus = value / 100
        else
            global.Settings.evolutionBonus = 0
        end
    end
    if event == nil or event.setting == "group_spawn_radius_from_target" then
        global.Settings.groupSpawnRadius = tonumber(settings.global["group_spawn_radius_from_target"].value)
    end
    if event == nil or event.setting == "group_tunnelling_time_seconds" then
        local value = tonumber(settings.global["group_tunnelling_time_seconds"].value)
        if value > 0 then
            global.Settings.tunnellingTicks = value * 60
        else
            global.Settings.tunnellingTicks = 0
        end
    end
    if event == nil or event.setting == "group_incomming_warning_seconds" then
        local value = tonumber(settings.global["group_incomming_warning_seconds"].value)
        if value > 0 then
            global.Settings.warningTicks = value * 60
        else
            global.Settings.warningTicks = 0
        end
    end

    if testing then
        global.Settings.groupFrequencyRangeLowTicks = 600
        global.Settings.groupFrequencyRangeHighTicks = 600
        global.Settings.warningTicks = 120
        global.Settings.tunnellingTicks = 120
        global.Settings.groupSize = 2
        global.Settings.groupSpawnRadius = 5
    end
end

BiterHuntGroup.OnPlayerJoinedGame = function(event)
    local player = game.get_player(event.player_index)
    BiterHuntGroup.GuiRecreate(player)
end

BiterHuntGroup.ScheduleNextBiterHuntGroup = function()
    global.BiterHuntGroup.nextGroupTick = global.BiterHuntGroup.nextGroupTick + math.random(global.Settings.groupFrequencyRangeLowTicks, global.Settings.groupFrequencyRangeHighTicks)
    BiterHuntGroup.UpdateNextGroupTickWarning()
end

BiterHuntGroup.UpdateNextGroupTickWarning = function()
    global.BiterHuntGroup.nextGroupTickWarning = global.BiterHuntGroup.nextGroupTick - global.Settings.warningTicks
end

BiterHuntGroup.MakeBitersAttackNow = function()
    global.BiterHuntGroup.nextGroupTick = game.tick + global.Settings.warningTicks
    BiterHuntGroup.UpdateNextGroupTickWarning()
end

BiterHuntGroup.ValidSurface = function(surface)
    if string.find(surface.name, "spaceship", 0, true) then
        return false
    end
    if string.find(surface.name, "Orbit", 0, true) then
        return false
    end
    return true
end

BiterHuntGroup.SelectTarget = function()
    local players = game.connected_players
    local validPlayers = {}
    for _, player in pairs(players) do
        if (player.vehicle ~= nil or player.character ~= nil) and BiterHuntGroup.ValidSurface(player.surface) then
            table.insert(validPlayers, player)
        end
    end
    if #validPlayers >= 1 then
        local target = validPlayers[math.random(1, #validPlayers)]
        global.BiterHuntGroup.targetPlayerID = target.index
        if target.vehicle ~= nil then
            global.BiterHuntGroup.TargetEntity = target.vehicle
        else
            global.BiterHuntGroup.TargetEntity = target.character
        end
        global.BiterHuntGroup.targetName = target.name
        global.BiterHuntGroup.Surface = target.surface
    else
        global.BiterHuntGroup.targetPlayerID = nil
        global.BiterHuntGroup.TargetEntity = nil
        global.BiterHuntGroup.targetName = "at Spawn"
        global.BiterHuntGroup.Surface = game.surfaces[1]
    end
    BiterHuntGroup.GuiUpdateAllConnected()
end

BiterHuntGroup.GuiCreate = function(player)
    BiterHuntGroup.GuiUpdateAllConnected(player.index)
end

BiterHuntGroup.GuiDestroy = function(player)
    GUIUtil.DestroyPlayersReferenceStorage(player.index, "biterhuntgroup")
end

BiterHuntGroup.GuiRecreate = function(player)
    BiterHuntGroup.GuiDestroy(player)
    BiterHuntGroup.GuiCreate(player)
end

BiterHuntGroup.GuiRecreateAll = function()
    for _, player in pairs(game.players) do
        BiterHuntGroup.GuiRecreate(player)
    end
end

BiterHuntGroup.GuiUpdateAllConnected = function(specificPlayerIndex)
    local warningLocalisedString
    if global.BiterHuntGroup.showIncomingGroupWarning ~= nil then
        warningLocalisedString = {"gui-caption.biter_hunt_group-warning-label"}
    end
    local targetLocalisedString
    if global.BiterHuntGroup.targetName ~= nil and global.BiterHuntGroup.Surface ~= nil then
        targetLocalisedString = {"gui-caption.biter_hunt_group-target-label", global.BiterHuntGroup.targetName, global.BiterHuntGroup.Surface.name}
    end
    for _, player in pairs(game.connected_players) do
        if specificPlayerIndex == nil or (specificPlayerIndex ~= nil and specificPlayerIndex == player.index) then
            BiterHuntGroup.GuiUpdatePlayerWithData(player, warningLocalisedString, targetLocalisedString)
        end
    end
end

BiterHuntGroup.GetModGuiFrame = function(player)
    local frameElement = GUIUtil.GetElementFromPlayersReferenceStorage(player.index, "biterhuntgroup", "main", "frame")
    if frameElement == nil then
        frameElement = GUIUtil.AddElement({parent = player.gui.left, name = "main", type = "frame", direction = "vertical", style = "muppet_margin_frame"}, "biterhuntgroup")
    end
    return frameElement
end

BiterHuntGroup.GuiUpdatePlayerWithData = function(player, warningLocalisedString, targetLocalisedString)
    local playerIndex = player.index
    local childElementPresent = false

    GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "biterhuntgroup", "warning", "label")
    if warningLocalisedString ~= nil then
        local frameElement = BiterHuntGroup.GetModGuiFrame(player)
        GUIUtil.AddElement({parent = frameElement, name = "warning", type = "label", caption = warningLocalisedString, style = Constants.ModName .. "_biterwarning_text"}, "biterhuntgroup")
        childElementPresent = true
    end

    GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "biterhuntgroup", "target", "label")
    if targetLocalisedString ~= nil then
        local frameElement = BiterHuntGroup.GetModGuiFrame(player)
        GUIUtil.AddElement({parent = frameElement, name = "target", type = "label", caption = targetLocalisedString, style = "muppet_bold_text"}, "biterhuntgroup")
        childElementPresent = true
    end

    if not childElementPresent then
        GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "biterhuntgroup", "main", "frame")
    end
end

BiterHuntGroup.On10Ticks = function(event)
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

BiterHuntGroup.OnPlayerDied = function(event)
    local playerID = event.player_index
    if playerID == global.BiterHuntGroup.targetPlayerID and global.BiterHuntGroup.Results[global.BiterHuntGroup.id].playerWin == nil then
        global.BiterHuntGroup.Results[global.BiterHuntGroup.id].playerWin = false
        game.print("[img=entity.medium-biter]      [img=entity.character-corpse]" .. tostring(global.BiterHuntGroup.targetName) .. " lost")
        BiterHuntGroup.TargetBitersAtSpawn()
    end
end

BiterHuntGroup.OnPlayerLeftGame = function(event)
    local playerID = event.player_index
    if playerID == global.BiterHuntGroup.targetPlayerID and global.BiterHuntGroup.Results[global.BiterHuntGroup.id].playerWin == nil then
        global.BiterHuntGroup.Results[global.BiterHuntGroup.id].playerWin = false
        game.print("[img=entity.medium-biter]      [img=entity.character]" .. tostring(global.BiterHuntGroup.targetName) .. " fled like a coward")
        BiterHuntGroup.TargetBitersAtSpawn()
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

BiterHuntGroup.EnsureValidateTarget = function()
    local targetEntity = global.BiterHuntGroup.TargetEntity
    if targetEntity ~= nil and (not targetEntity.valid) then
        global.BiterHuntGroup.targetPlayerID = nil
        global.BiterHuntGroup.TargetEntity = nil
        global.BiterHuntGroup.targetName = "Spawn"
        BiterHuntGroup.GuiUpdateAllConnected()
    end
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

BiterHuntGroup.WriteOutHuntGroupResults = function(commandData)
    game.write_file("Biter Hunt Group Results.txt", Utils.TableContentsToJSON(global.BiterHuntGroup.Results), false, commandData.player_index)
end

BiterHuntGroup.OnPlayerDrivingChangedState = function(event)
    local playerId = event.player_index
    if playerId ~= global.BiterHuntGroup.targetPlayerID then
        return
    end
    local player = game.get_player(playerId)
    if player.vehicle ~= nil then
        global.BiterHuntGroup.TargetEntity = player.vehicle
    elseif player.character ~= nil then
        global.BiterHuntGroup.TargetEntity = player.character
    else
        BiterHuntGroup.TargetBitersAtSpawn()
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

return BiterHuntGroup
