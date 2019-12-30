--Manager controls the triggering of biter hunt group creations and recieves any commands and external events
--Group is the reoccuring collection of a group of settings. A Pack is a specific instance of a group.
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Commands = require("utility/commands")
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Gui = require("scripts/gui")
local Settings = require("utility/settings-manager")
local SharedData = require("scripts/shared-data")
local Interfaces = require("utility/interfaces")
local Manager = {}
local testing = true

local function CreateGlobalGroup(groupId)
    global.groups[groupId] = global.groups[groupId] or {}
    local group = global.groups[groupId]
    group.id = group.id or groupId
    group.results = group.results or {}
    group.packs = group.packs or {}
    group.lastPackId = group.lastPackId or 0
    return group
end

Manager.CreateGlobals = function()
    global.groupsCount = global.groupsCount or 0
    global.groups = global.groups or {}
end

Manager.OnLoad = function()
    Commands.Register("biters_attack_now", {"api-description.biter_hunt_group-biters_attack_now"}, Manager.MakeBitersAttackNowCommand, true)
    Events.RegisterHandler(defines.events.on_player_joined_game, "BiterHuntGroupManager", Manager.OnPlayerJoinedGame)
    Commands.Register("biters_write_out_hunt_group_results", {"api-description.biter_hunt_group-biters_write_out_hunt_group_results"}, Manager.WriteOutHuntGroupResults, false)
    Interfaces.RegisterInterface("Manager.GetGlobalSettingForId", Manager.GetGlobalSettingForId)
    Interfaces.RegisterInterface("Manager.ScheduleNextPackForGroup", Manager.ScheduleNextPackForGroup)
end

Manager.OnStartup = function()
    for groupId = 1, global.groupsCount do
        local group = CreateGlobalGroup(groupId)
        if #group.packs == 0 then
            Manager.ScheduleNextPackForGroup(group)
        end
    end
    Gui.GuiRecreateAll()
end

Manager.GetGlobalSettingForId = function(groupId, settingName)
    local groupContainer, settingsContainerName = global.groups, "settings"
    return Settings.GetSettingValueForId(groupContainer, groupId, settingsContainerName, settingName)
end

--[[
    Setting Names: groupFrequencyRangeLowTicks, groupFrequencyRangeHighTicks, groupSize, evolutionBonus, groupSpawnRadius, tunnellingTicks, warningTicks
]]
Manager.OnRuntimeModSettingChanged = function(event)
    --TODO if settings change mid game we need to add/remove scheduled group events
    local groupContainer, settingsContainerName = global.groups, "settings"

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
        global.groups[0].settings.groupFrequencyRangeLowTicks = 60 * 5
        global.groups[0].settings.groupFrequencyRangeHighTicks = 60 * 5
        global.groups[0].settings.warningTicks = 120
        global.groups[0].settings.tunnellingTicks = 120
        global.groups[0].settings.groupSize = 2
        global.groups[0].settings.groupSpawnRadius = 5
        global.groups[1] = nil
        global.groups[2] = nil
    end

    for groupId, group in pairs(groupContainer) do
        if Utils.GetTableLength(group[settingsContainerName]) == 0 then
            Logging.LogPrint("TODO: removed group '" .. groupId .. "' as no settings - TIDY STUFF UP")
            table.remove(groupContainer, groupId)
        end
    end

    --Logging.LogPrint(Utils.TableContentsToJSON(global.groups, "global.groups"))
    global.groupsCount = math.max(Utils.GetMaxKey(global.groups), 1)
end

Manager.OnPlayerJoinedGame = function(event)
    local player = game.get_player(event.player_index)
    Gui.GuiRecreate(player)
end

Manager.ScheduleNextPackForGroup = function(group)
    local nextPackActionTick = game.tick + math.random(Manager.GetGlobalSettingForId(group.id, "groupFrequencyRangeLowTicks"), Manager.GetGlobalSettingForId(group.id, "groupFrequencyRangeHighTicks"))
    local pack = Interfaces.Call("Controller.CreatePack", group)
    local uniqueId = group.id .. "_" .. pack.id
    EventScheduler.ScheduleEvent(nextPackActionTick, "Controller.PackAction_Warning", uniqueId, {pack = pack})
end

Manager.MakeBiterGroupPackAttackNow = function(group)
    local pack = group.packs[group.lastPackId]
    --Should never happen with current mod functionality. If we create one we need to avoid it creating its own cycle.
    --[[if pack.state ~= SharedData.biterHuntGroupState.waiting then
        Logging.LogPrint("adding new pack")
        pack = Interfaces.Call("Controller.CreatePack", group)
    end]]
    local uniqueId = group.id .. "_" .. pack.id
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
        if groupId > global.groupsCount then
            Logging.LogPrint("biters_attack_now command called with non existent high numerical ID")
            return
        end
        local group = global.groups[groupId]
        Manager.MakeBiterGroupPackAttackNow(group)
    else
        for groupId = 1, global.groupsCount do
            local group = global.groups[groupId]
            Manager.MakeBiterGroupPackAttackNow(group)
        end
    end
end

Manager.WriteOutHuntGroupResults = function(commandData)
    local results = {}
    for id = 1, global.groupsCount do
        results[id] = global.groups[id].results
    end
    game.write_file("Biter Hunt Group Results.txt", Utils.TableContentsToJSON(results), false, commandData.player_index)
end

return Manager
