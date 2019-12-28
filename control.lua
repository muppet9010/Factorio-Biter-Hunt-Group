local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local BiterHuntGroup = require("scripts/biter-hunt-group")

local function CreateGlobals()
    BiterHuntGroup.CreateGlobals()
end

local function OnLoad()
    BiterHuntGroup.OnLoad()
end

local function OnStartup()
    CreateGlobals()
    OnLoad()

    BiterHuntGroup.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)

Events.RegisterEvent(defines.events.on_player_joined_game)
Events.RegisterEvent(defines.events.on_player_died)
Events.RegisterEvent(defines.events.on_player_left_game)
Events.RegisterEvent(defines.events.on_player_driving_changed_state)
EventScheduler.RegisterScheduler()
