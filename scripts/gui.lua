local Gui = {}
local GUIUtil = require("utility/gui-util")
local Constants = require("constants")
local SharedData = require("scripts/shared-data")
local Interfaces = require("utility/interfaces")
--local Utils = require("utility/utils")
--local Logging = require("utility/logging")

local function GetModFrame(player)
    local frameElement = GUIUtil.GetOrAddElement({parent = player.gui.left, name = "main", type = "frame", direction = "vertical", style = "muppet_margin_frame"}, "biterhuntgroup")
    frameElement.visible = false
    return frameElement
end

local function GetHuntingFrame(mainFrame)
    local frameElement = GUIUtil.GetOrAddElement({parent = mainFrame, name = "hunting", type = "frame", direction = "vertical", style = "muppet_margin_frame"}, "biterhuntgroup")
    frameElement.visible = false
    return frameElement
end

local function GetIncommingFrame(mainFrame)
    local frameElement = GUIUtil.GetOrAddElement({parent = mainFrame, name = "incomming", type = "frame", direction = "vertical", style = "muppet_margin_frame"}, "biterhuntgroup")
    frameElement.visible = false
    return frameElement
end

Gui.OnLoad = function()
    Interfaces.RegisterInterface("Gui.RecreateAll", Gui.RecreateAll)
    Interfaces.RegisterInterface("Gui.RecreatePlayer", Gui.RecreatePlayer)
    Interfaces.RegisterInterface("Gui.UpdateAllConnectedPlayers", Gui.UpdateAllConnectedPlayers)
end

Gui.CreatePlayer = function(player)
    Gui.UpdatePlayer(player.index)
end

Gui.DestroyPlayer = function(player)
    GUIUtil.DestroyPlayersReferenceStorage(player.index, "biterhuntgroup")
end

Gui.RecreatePlayer = function(player)
    Gui.DestroyPlayer(player)
    Gui.CreatePlayer(player)
end

Gui.RecreateAll = function()
    for _, player in pairs(game.players) do
        Gui.RecreatePlayer(player)
    end
end

Gui.UpdatePlayer = function(playerIndex)
    local player = game.get_player(playerIndex)
    local mainFrameElement = GetModFrame(player)
    local huntingFrameElement = GetHuntingFrame(mainFrameElement)
    local incommingFrameElement = GetIncommingFrame(mainFrameElement)
    huntingFrameElement.clear()
    incommingFrameElement.clear()

    for groupId = 1, global.groupsCount do
        local group = global.groups[groupId]
        for _, pack in pairs(group.packs) do
            local uniqueId = Interfaces.Call("Controller.GenerateUniqueId", group.id, pack.id)
            if pack.targetName ~= nil then
                local huntingString = string.gsub(string.gsub(pack.huntingText, "__1__", pack.targetName), "__2__", pack.surface.name)
                GUIUtil.AddElement({parent = huntingFrameElement, name = "target" .. uniqueId, type = "label", caption = huntingString, style = "muppet_bold_text"})
                mainFrameElement.visible = true
                huntingFrameElement.visible = true
            end
            if pack.state == SharedData.biterHuntGroupState.warning then
                local warningString = pack.warningText
                GUIUtil.AddElement({parent = incommingFrameElement, name = "warning" .. uniqueId, type = "label", caption = warningString, style = Constants.ModName .. "_biterwarning_text"})
                mainFrameElement.visible = true
                incommingFrameElement.visible = true
            end
        end
    end
end

Gui.UpdateAllConnectedPlayers = function()
    for _, player in pairs(game.connected_players) do
        Gui.UpdatePlayer(player.index)
    end
end

return Gui
