local Gui = {}
local GUIUtil = require("utility/gui-util")
local SharedData = require("scripts/shared-data")
local Interfaces = require("utility/interfaces")
local Colors = require("utility/colors")
--local Utils = require("utility/utils")
--local Logging = require("utility/logging")

Gui.OnLoad = function()
    Interfaces.RegisterInterface("Gui.RecreateAll", Gui.RecreateAll)
    Interfaces.RegisterInterface("Gui.RecreatePlayer", Gui.RecreatePlayer)
    Interfaces.RegisterInterface("Gui.UpdateAllConnectedPlayers", Gui.UpdateAllConnectedPlayers)
end

Gui.RecreatePlayer = function(player)
    Gui.DestroyGUI(player)
    Gui.CreateGUI(player)
end

Gui.RecreateAll = function()
    for _, player in pairs(game.players) do
        Gui.RecreatePlayer(player)
    end
end

Gui.CreateGUI = function(player)
    GUIUtil.AddElement(
        {
            parent = player.gui.left,
            name = "main",
            type = "frame",
            direction = "vertical",
            style = "muppet_frame_main_marginTL_paddingBR",
            storeName = "biterhuntgroup",
            visible = false,
            styling = {right_padding = 4, bottom_padding = 4},
            children = {
                {
                    name = "hunting",
                    type = "flow",
                    direction = "vertical",
                    style = "muppet_flow_vertical_spaced",
                    storeName = "biterhuntgroup",
                    visible = false
                },
                {
                    name = "incoming",
                    type = "flow",
                    direction = "vertical",
                    style = "muppet_flow_vertical_spaced",
                    storeName = "biterhuntgroup",
                    visible = false
                }
            }
        }
    )

    Gui.UpdatePlayer(player.index)
end

Gui.DestroyGUI = function(player)
    GUIUtil.DestroyPlayersReferenceStorage(player.index, "biterhuntgroup")
end

Gui.UpdatePlayer = function(playerIndex)
    local mainFrameElement = GUIUtil.GetElementFromPlayersReferenceStorage(playerIndex, "biterhuntgroup", "main", "frame")
    local huntingFlowElement = GUIUtil.GetElementFromPlayersReferenceStorage(playerIndex, "biterhuntgroup", "hunting", "flow")
    local incomingFlowElement = GUIUtil.GetElementFromPlayersReferenceStorage(playerIndex, "biterhuntgroup", "incoming", "flow")
    huntingFlowElement.clear()
    incomingFlowElement.clear()
    local mainVisible, huntingVisible, incommingVisible = false, false, false

    for _, group in pairs(global.groups) do
        for _, pack in pairs(group.packs) do
            if pack.targetName ~= nil and not pack.finalResultReached then
                local huntingString = string.gsub(string.gsub(pack.huntingText, "__1__", pack.targetName), "__2__", pack.surface.name)
                GUIUtil.AddElement(
                    {
                        parent = huntingFlowElement,
                        type = "frame",
                        style = "muppet_frame_content_marginTL",
                        children = {
                            {type = "label", caption = huntingString, style = "muppet_label_text_large_bold_paddingSides"}
                        }
                    }
                )
                mainVisible, huntingVisible = true, true
            end
            if pack.state == SharedData.biterHuntGroupState.warning then
                GUIUtil.AddElement(
                    {
                        parent = incomingFlowElement,
                        type = "frame",
                        style = "muppet_frame_content_marginTL",
                        children = {
                            {type = "label", caption = pack.warningText, style = "muppet_label_text_large_bold_paddingSides", styling = {font_color = Colors.lightred}}
                        }
                    }
                )
                mainVisible, incommingVisible = true, true
            end
        end
    end

    if mainVisible then
        mainFrameElement.visible = true
    else
        mainFrameElement.visible = false
    end
    if huntingVisible then
        huntingFlowElement.visible = true
    else
        huntingFlowElement.visible = false
    end
    if incommingVisible then
        incomingFlowElement.visible = true
    else
        incomingFlowElement.visible = false
    end
end

Gui.UpdateAllConnectedPlayers = function()
    for _, player in pairs(game.connected_players) do
        Gui.UpdatePlayer(player.index)
    end
end

return Gui
