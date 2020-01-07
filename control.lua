local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Groups = require("scripts/groups")
local Packs = require("scripts/pack")
local Gui = require("scripts/gui")

local function CreateGlobals()
    Groups.CreateGlobals()
end

local function OnLoad()
    Groups.OnLoad()
    Packs.OnLoad()
    Gui.OnLoad()
end

local function OnSettingChanged(event)
    Groups.OnRuntimeModSettingChanged(event)
end

local function OnStartup()
    CreateGlobals()
    OnSettingChanged(nil)
    OnLoad()

    Groups.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)

Events.RegisterEvent(defines.events.on_player_joined_game)
Events.RegisterEvent(defines.events.on_player_died)
Events.RegisterEvent(defines.events.on_player_left_game)
Events.RegisterEvent(defines.events.on_player_driving_changed_state)
EventScheduler.RegisterScheduler()
