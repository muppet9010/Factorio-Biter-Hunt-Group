--Manager controls the triggering of biter hunt group creations and recieves any commands and external events
--Group is the reoccuring collection of a group of settings. A Pack is a specific instance of a group.
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Commands = require("utility/commands")
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Settings = require("utility/settings-manager")
local Interfaces = require("utility/interfaces")
local Manager = {}

local testing_singleGroup = false
local testing_doubleGroup = false

Manager.CreateGlobals = function()
    global.groups = global.groups or {}
    global.defaultSettings = global.defaultSettings or {}
end

Manager.OnLoad = function()
    Commands.Register("biters_attack_now", {"api-description.biter_hunt_group-biters_attack_now"}, Manager.MakeBitersAttackNowCommand, true)
    Events.RegisterHandler(defines.events.on_player_joined_game, "BiterHuntGroupManager", Manager.OnPlayerJoinedGame)
    Commands.Register("biters_write_out_hunt_group_results", {"api-description.biter_hunt_group-biters_write_out_hunt_group_results"}, Manager.WriteOutHuntGroupResults, false)
    Interfaces.RegisterInterface("Manager.GetGlobalSettingForId", Manager.GetGlobalSettingForId)
    Interfaces.RegisterInterface("Manager.ScheduleNextPackForGroup", Manager.ScheduleNextPackForGroup)
end

Manager.OnStartup = function()
    Interfaces.Call("Gui.RecreateAll")
    Manager.UpdateGroupsFromSettings()
end

Manager.GetGlobalSettingForId = function(groupId, settingName)
    local groupContainer, settingsContainerName, defaultSettingsContainer = global.groups, "settings", global.defaultSettings
    return Settings.GetSettingValueForId(groupContainer, groupId, settingsContainerName, settingName, defaultSettingsContainer)
end

Manager.HandleSettingWithArrayOfValues = function(settingType, settingName, expectedValueType, defaultValue, globalSettingName, valueHandlingFunction)
    local globalGroupsContainer, globalSettingContainerName, defaultSettingsContainer = global.groups, "settings", global.defaultSettings
    Settings.HandleSettingWithArrayOfValues(settingType, settingName, expectedValueType, defaultSettingsContainer, defaultValue, globalGroupsContainer, globalSettingContainerName, globalSettingName, valueHandlingFunction)
end

--[[
    Setting Names: groupFrequencyRangeLowTicks, groupFrequencyRangeHighTicks, groupSize, evolutionBonus, groupSpawnRadius, tunnellingTicks, warningTicks
]]
Manager.OnRuntimeModSettingChanged = function(event)
    if event == nil or event.setting == "biter_hunt_group-group_frequency_range_low_minutes" then
        Manager.HandleSettingWithArrayOfValues(
            "global",
            "biter_hunt_group-group_frequency_range_low_minutes",
            "number",
            20,
            "groupFrequencyRangeLowTicks",
            function(value)
                if value ~= nil and value > 0 then
                    value = value * 60 * 60
                end
                return value
            end
        )
    end
    if event == nil or event.setting == "biter_hunt_group-group_frequency_range_high_minutes" then
        Manager.HandleSettingWithArrayOfValues(
            "global",
            "biter_hunt_group-group_frequency_range_high_minutes",
            "number",
            45,
            "groupFrequencyRangeHighTicks",
            function(value)
                if value ~= nil and value > 0 then
                    value = value * 60 * 60
                end
                return value
            end
        )
    end
    if event == nil or event.setting == "biter_hunt_group-group_size" then
        Manager.HandleSettingWithArrayOfValues("global", "biter_hunt_group-group_size", "number", 80, "groupSize")
    end
    if event == nil or event.setting == "biter_hunt_group-group_evolution_bonus_percent" then
        Manager.HandleSettingWithArrayOfValues(
            "global",
            "biter_hunt_group-group_evolution_bonus_percent",
            "number",
            10,
            "evolutionBonus",
            function(value)
                if value ~= nil and value > 0 then
                    value = value / 100
                end
                return value
            end
        )
    end
    if event == nil or event.setting == "biter_hunt_group-group_spawn_radius_from_target" then
        Manager.HandleSettingWithArrayOfValues("global", "biter_hunt_group-group_spawn_radius_from_target", "number", 100, "groupSpawnRadius")
    end
    if event == nil or event.setting == "biter_hunt_group-group_tunnelling_time_seconds" then
        Manager.HandleSettingWithArrayOfValues(
            "global",
            "biter_hunt_group-group_tunnelling_time_seconds",
            "number",
            3,
            "tunnellingTicks",
            function(value)
                if value ~= nil and value > 0 then
                    value = value * 60
                end
                return value
            end
        )
    end
    if event == nil or event.setting == "biter_hunt_group-group_incomming_warning_seconds" then
        Manager.HandleSettingWithArrayOfValues(
            "global",
            "biter_hunt_group-group_incomming_warning_seconds",
            "number",
            10,
            "warningTicks",
            function(value)
                if value ~= nil and value > 0 then
                    value = value * 60
                end
                return value
            end
        )
    end
    if event == nil or event.setting == "biter_hunt_group-group_warning_text" then
        Manager.HandleSettingWithArrayOfValues("global", "biter_hunt_group-group_warning_text", "string", "Incomming Tunneling Biter Pack", "warningText")
    end
    if event == nil or event.setting == "biter_hunt_group-group_hunting_text" then
        Manager.HandleSettingWithArrayOfValues("global", "biter_hunt_group-group_hunting_text", "string", "Pack currently hunting __1__ on __2__", "huntingText")
    end

    if testing_singleGroup then
        global.defaultSettings.groupFrequencyRangeLowTicks = 60 * 10
        global.defaultSettings.groupFrequencyRangeHighTicks = 60 * 10
        global.defaultSettings.warningTicks = 120
        global.defaultSettings.tunnellingTicks = 120
        global.defaultSettings.groupSize = 2
        global.defaultSettings.groupSpawnRadius = 5
        Settings.CreateGlobalGroupSettingsContainer(global.groups, 1, "settings")
        global.groups[1].settings.testing = true
    end
    if testing_doubleGroup then
        global.defaultSettings.groupFrequencyRangeLowTicks = 60 * 8
        global.defaultSettings.groupFrequencyRangeHighTicks = 60 * 12
        global.defaultSettings.warningTicks = 120
        global.defaultSettings.tunnellingTicks = 120
        global.defaultSettings.groupSize = 2
        global.defaultSettings.groupSpawnRadius = 5
        Settings.CreateGlobalGroupSettingsContainer(global.groups, 1, "settings")
        global.groups[1].settings.testing = true
        Settings.CreateGlobalGroupSettingsContainer(global.groups, 2, "settings")
        global.groups[2].settings.testing = true
    end

    if event ~= nil then
        --Setting changed mid game, so apply group changes
        Manager.UpdateGroupsFromSettings()
    end
end

Manager.UpdateGroupsFromSettings = function()
    local groupsMaxCount = math.max(Utils.GetMaxKey(global.groups), 1)
    for groupId = 1, groupsMaxCount do
        local group = Manager.CreateAndPopulateGlobalGroupAsNeeded(groupId)
        if Utils.GetTableNonNilLength(group.packs) == 0 then
            Manager.ScheduleNextPackForGroup(group)
        end
    end
    for groupId, group in pairs(global.groups) do
        if groupId > 1 and Utils.GetTableNonNilLength(group.settings) == 0 then
            Manager.RemoveGroup(group)
        end
    end
    Interfaces.Call("Gui.UpdateAllConnectedPlayers")
end

Manager.CreateAndPopulateGlobalGroupAsNeeded = function(groupId)
    global.groups[groupId] = global.groups[groupId] or {}
    local group = global.groups[groupId]
    group.id = group.id or groupId
    group.results = group.results or {}
    group.packs = group.packs or {}
    group.lastPackId = group.lastPackId or 0
    group.settings = group.settings or {}
    return group
end

Manager.RemoveGroup = function(group)
    local groupId = group.id
    for _, pack in pairs(group.packs) do
        Interfaces.Call("Controller.DeletePack", group, pack)
    end
    global.groups[groupId] = nil
    Interfaces.Call("Gui.UpdateAllConnectedPlayers")
end

Manager.OnPlayerJoinedGame = function(event)
    local player = game.get_player(event.player_index)
    Interfaces.Call("Gui.RecreatePlayer", player)
end

Manager.ScheduleNextPackForGroup = function(group)
    local nextPackActionTick = game.tick + math.random(Manager.GetGlobalSettingForId(group.id, "groupFrequencyRangeLowTicks"), Manager.GetGlobalSettingForId(group.id, "groupFrequencyRangeHighTicks"))
    local pack = Interfaces.Call("Controller.CreatePack", group)
    local uniqueId = Interfaces.Call("Controller.GenerateUniqueId", group.id, pack.id)
    EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.PackAction_Warning", uniqueId, {pack = pack})
end

Manager.MakeBiterGroupPackAttackNow = function(group)
    local pack = group.packs[group.lastPackId]
    --Should never happen with current mod functionality. If we create a pack for a group with no random spawn time via command we need to avoid it creating its own cycle.
    --[[if pack.state ~= SharedData.biterHuntGroupState.scheduled then
        Logging.LogPrint("adding new pack")
        pack = Interfaces.Call("Controller.CreatePack", group)
    end]]
    local uniqueId = Interfaces.Call("Controller.GenerateUniqueId", group.id, pack.id)
    EventScheduler.RemoveScheduledEvents("Controller.PackAction_Warning", uniqueId)
    EventScheduler.ScheduleEvent(game.tick, "Controller.PackAction_Warning", uniqueId, {pack = pack})
end

Manager.MakeBitersAttackNowCommand = function(command)
    local args = Commands.GetArgumentsFromCommand(command.parameter)
    if #args > 0 then
        local groupId_string = args[1]
        local groupId = tonumber(groupId_string)
        if groupId == nil then
            Logging.LogPrint("biters_attack_now command called with non numerical ID")
            return
        end
        groupId = Utils.RoundNumberToDecimalPlaces(groupId, 0)
        if groupId <= 0 then
            Logging.LogPrint("biters_attack_now command called with non existent low numerical ID")
            return
        end
        if groupId > #global.groups then
            Logging.LogPrint("biters_attack_now command called with non existent high numerical ID")
            return
        end
        local group = global.groups[groupId]
        Manager.MakeBiterGroupPackAttackNow(group)
    else
        for _, group in pairs(global.groups) do
            Manager.MakeBiterGroupPackAttackNow(group)
        end
    end
end

Manager.WriteOutHuntGroupResults = function(commandData)
    local results = {}
    for groupId, group in pairs(global.groups) do
        results[groupId] = group.results
    end
    game.write_file("Biter Hunt Group Results.txt", Utils.TableContentsToJSON(results), false, commandData.player_index)
end

return Manager
