local Gui = {}
local GUIUtil = require("utility/gui-util")
local SharedData = require("scripts/shared-data")
local Interfaces = require("utility/interfaces")
--local Utils = require("utility/utils")
--local Logging = require("utility/logging")

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
    local mainFrameElement = Gui.GetModFrame(player)
    local huntingFlowElement = Gui.GetHuntingFlow(mainFrameElement)
    local flowSpacer = Gui.GetFlowSpacer(mainFrameElement)
    local incommingFlowElement = Gui.GetIncommingFlow(mainFrameElement)
    huntingFlowElement.clear()
    incommingFlowElement.clear()

    for _, group in pairs(global.groups) do
        for _, pack in pairs(group.packs) do
            local uniqueId = Interfaces.Call("Packs.GenerateUniqueId", group.id, pack.id)
            if pack.targetName ~= nil and not pack.finalResultReached then
                local packElementName = "target" .. uniqueId
                local packFrame = GUIUtil.AddElement({parent = huntingFlowElement, name = packElementName, type = "frame", style = "muppet_frame"})
                local huntingString = string.gsub(string.gsub(pack.huntingText, "__1__", pack.targetName), "__2__", pack.surface.name)
                GUIUtil.AddElement({parent = packFrame, name = packElementName, type = "label", caption = huntingString, style = "muppet_large_bold_text"})
                mainFrameElement.visible = true
                huntingFlowElement.visible = true
            end
            if pack.state == SharedData.biterHuntGroupState.warning then
                local packElementName = "warning" .. uniqueId
                local packFrame = GUIUtil.AddElement({parent = incommingFlowElement, name = packElementName, type = "frame", style = "muppet_frame"})
                local warningString = pack.warningText
                GUIUtil.AddElement({parent = packFrame, name = packElementName, type = "label", caption = warningString, style = "biter_hunt_group_biterwarning_text"})
                mainFrameElement.visible = true
                incommingFlowElement.visible = true
            end
        end
    end
    if huntingFlowElement.visible and incommingFlowElement.visible then
        flowSpacer.visible = true
    end
end

Gui.UpdateAllConnectedPlayers = function()
    for _, player in pairs(game.connected_players) do
        Gui.UpdatePlayer(player.index)
    end
end

Gui.GetModFrame = function(player)
    local frameElement = GUIUtil.GetOrAddElement({parent = player.gui.left, name = "main", type = "frame", direction = "vertical", style = "muppet_margin_padded_light_frame"}, "biterhuntgroup")
    frameElement.visible = false
    return frameElement
end

Gui.GetHuntingFlow = function(mainFrame)
    local flowElement = GUIUtil.GetOrAddElement({parent = mainFrame, name = "hunting", type = "flow", direction = "vertical", style = "muppet_vertical_flow_spaced"}, "biterhuntgroup")
    flowElement.visible = false
    return flowElement
end

Gui.GetFlowSpacer = function(mainFrame)
    local flowElement = GUIUtil.GetOrAddElement({parent = mainFrame, name = "spacer", type = "flow", direction = "vertical", style = "muppet_vertical_flow"}, "biterhuntgroup")
    flowElement.visible = false
    return flowElement
end

Gui.GetIncommingFlow = function(mainFrame)
    local flowElement = GUIUtil.GetOrAddElement({parent = mainFrame, name = "incomming", type = "flow", direction = "vertical", style = "muppet_vertical_flow_spaced"}, "biterhuntgroup")
    flowElement.visible = false
    return flowElement
end

return Gui
