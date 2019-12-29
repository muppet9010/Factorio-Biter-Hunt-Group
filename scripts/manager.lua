--Manager controls the triggering of biter hunt group creations and recieves any commands and external events
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Commands = require("utility/commands")
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Gui = require("scripts/gui")
local Settings = require("utility/settings-manager")
local Manager = {}
local testing = false

local function CreateGobalDataForBiterHuntGroupId(id)
    global.biterHuntGroups[id] = global.biterHuntGroups[id] or {}
    global.biterHuntGroups[id].Data = global.biterHuntGroups[id].Data or {}
    local container = global.biterHuntGroups[id]
    container.Units = container.Units or {}
    container.Results = container.Results or {}
    container.id = container.id or 0
    container.unitsTargetedAtSpawn = container.unitsTargetedAtSpawn or nil
end

Manager.CreateGlobals = function()
    global.biterHuntGroupsCount = global.biterHuntGroupsCount or 0
    global.biterHuntGroups = global.biterHuntGroups or {}
end

Manager.OnLoad = function()
    Commands.Register("biters_attack_now", {"api-description.biter_hunt_group-biters_attack_now"}, Manager.MakeBitersAttackNow, true)
    Events.RegisterHandler(defines.events.on_player_joined_game, "BiterHuntGroup", Manager.OnPlayerJoinedGame)
    Events.RegisterHandler(defines.events.on_player_died, "BiterHuntGroup", Manager.OnPlayerDied)
    Events.RegisterHandler(defines.events.on_player_left_game, "BiterHuntGroup", Manager.OnPlayerLeftGame)
    Commands.Register("biters_write_out_hunt_group_results", {"api-description.biter_hunt_group-biters_write_out_hunt_group_results"}, Manager.WriteOutHuntGroupResults, false)
    Events.RegisterHandler(defines.events.on_player_driving_changed_state, "BiterHuntGroup", Manager.OnPlayerDrivingChangedState)
end

Manager.OnStartup = function()
    if global.BiterHuntGroup.nextGroupTick == nil then
        global.BiterHuntGroup.nextGroupTick = game.tick
        BiterHuntGroup.ScheduleNextBiterHuntGroup()
    end
    Gui.GuiRecreateAll()
end

Manager.GetGlobalSettingForId = function(id, settingName)
    return global.biterHuntGroups[id].Settings[settingName] or global.biterHuntGroups[0].Settings[settingName]
end

Manager.OnRuntimeModSettingChanged = function(event)
    local groupContainer, settingsContainerName = global.biterHuntGroups, "Settings"

    if event == nil or event.setting == "group_frequency_range_low_minutes" then
        Settings.HandleSettingWithArrayOfValues(
            "global",
            "group_frequency_range_low_minutes",
            "number",
            20,
            groupContainer,
            settingsContainerName,
            "groupFrequencyRangeLowTicks",
            function(value)
                if value ~= nil and value > 0 then
                    value = value * 60 * 60
                end
                return value
            end
        )
    end
    if event == nil or event.setting == "group_frequency_range_high_minutes" then
        Settings.HandleSettingWithArrayOfValues(
            "global",
            "group_frequency_range_high_minutes",
            "number",
            45,
            groupContainer,
            settingsContainerName,
            "groupFrequencyRangeHighTicks",
            function(value)
                if value ~= nil and value > 0 then
                    value = value * 60 * 60
                end
                return value
            end
        )
    end
    if event == nil or event.setting == "group_size" then
        Settings.HandleSettingWithArrayOfValues("global", "group_size", "number", 80, groupContainer, settingsContainerName, "groupSize")
    end
    if event == nil or event.setting == "group_evolution_bonus_percent" then
        Settings.HandleSettingWithArrayOfValues(
            "global",
            "group_evolution_bonus_percent",
            "number",
            10,
            groupContainer,
            settingsContainerName,
            "evolutionBonus",
            function(value)
                if value ~= nil and value > 0 then
                    value = value / 100
                end
                return value
            end
        )
    end
    if event == nil or event.setting == "group_spawn_radius_from_target" then
        Settings.HandleSettingWithArrayOfValues("global", "group_spawn_radius_from_target", "number", 100, groupContainer, settingsContainerName, "groupSpawnRadius")
    end
    if event == nil or event.setting == "group_tunnelling_time_seconds" then
        Settings.HandleSettingWithArrayOfValues(
            "global",
            "group_tunnelling_time_seconds",
            "number",
            3,
            groupContainer,
            settingsContainerName,
            "tunnellingTicks",
            function(value)
                if value ~= nil and value > 0 then
                    value = value * 60
                end
                return value
            end
        )
    end
    if event == nil or event.setting == "group_incomming_warning_seconds" then
        Settings.HandleSettingWithArrayOfValues(
            "global",
            "group_incomming_warning_seconds",
            "number",
            10,
            groupContainer,
            settingsContainerName,
            "warningTicks",
            function(value)
                if value ~= nil and value > 0 then
                    value = value * 60
                end
                return value
            end
        )
    end

    if testing then
        global.biterHuntGroups[0].Settings.groupFrequencyRangeLowTicks = 600
        global.biterHuntGroups[0].Settings.groupFrequencyRangeHighTicks = 600
        global.biterHuntGroups[0].Settings.warningTicks = 120
        global.biterHuntGroups[0].Settings.tunnellingTicks = 120
        global.biterHuntGroups[0].Settings.groupSize = 2
        global.biterHuntGroups[0].Settings.groupSpawnRadius = 5
        global.biterHuntGroups[1] = nil
        global.biterHuntGroups[2] = nil
    end

    for id, group in pairs(groupContainer) do
        if Utils.GetTableLength(group[settingsContainerName]) == 0 then
            Logging.LogPrint("TODO: remvoed group '" .. id .. "' as no settings - TIDY STUFF UP")
            table.remove(groupContainer, id)
        end
    end

    --Logging.LogPrint(Utils.TableContentsToJSON(global.biterHuntGroups, "global.biterHuntGroups"))
    global.biterHuntGroups = Utils.GetMaxKey(global.biterHuntGroups)
end

Manager.OnPlayerJoinedGame = function(event)
    local player = game.get_player(event.player_index)
    Gui.GuiRecreate(player)
end

local BiterHuntGroup = {}
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

BiterHuntGroup.EnsureValidateTarget = function()
    local targetEntity = global.BiterHuntGroup.TargetEntity
    if targetEntity ~= nil and (not targetEntity.valid) then
        global.BiterHuntGroup.targetPlayerID = nil
        global.BiterHuntGroup.TargetEntity = nil
        global.BiterHuntGroup.targetName = "Spawn"
        BiterHuntGroup.GuiUpdateAllConnected()
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

return Manager
