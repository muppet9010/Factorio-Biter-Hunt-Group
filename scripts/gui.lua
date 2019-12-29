local Gui = {}
local GUIUtil = require("utility/gui-util")
local Constants = require("constants")

Gui.GuiCreate = function(player)
    Gui.GuiUpdateAllConnected(player.index)
end

Gui.GuiDestroy = function(player)
    GUIUtil.DestroyPlayersReferenceStorage(player.index, "biterhuntgroup")
end

Gui.GuiRecreate = function(player)
    Gui.GuiDestroy(player)
    Gui.GuiCreate(player)
end

Gui.GuiRecreateAll = function()
    for _, player in pairs(game.players) do
        Gui.GuiRecreate(player)
    end
end

Gui.GuiUpdateAllConnected = function(specificPlayerIndex)
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
            Gui.GuiUpdatePlayerWithData(player, warningLocalisedString, targetLocalisedString)
        end
    end
end

Gui.GetModGuiFrame = function(player)
    local frameElement = GUIUtil.GetElementFromPlayersReferenceStorage(player.index, "biterhuntgroup", "main", "frame")
    if frameElement == nil then
        frameElement = GUIUtil.AddElement({parent = player.gui.left, name = "main", type = "frame", direction = "vertical", style = "muppet_margin_frame"}, "biterhuntgroup")
    end
    return frameElement
end

Gui.GuiUpdatePlayerWithData = function(player, warningLocalisedString, targetLocalisedString)
    local playerIndex = player.index
    local childElementPresent = false

    GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "biterhuntgroup", "warning", "label")
    if warningLocalisedString ~= nil then
        local frameElement = Gui.GetModGuiFrame(player)
        GUIUtil.AddElement({parent = frameElement, name = "warning", type = "label", caption = warningLocalisedString, style = Constants.ModName .. "_biterwarning_text"}, "biterhuntgroup")
        childElementPresent = true
    end

    GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "biterhuntgroup", "target", "label")
    if targetLocalisedString ~= nil then
        local frameElement = Gui.GetModGuiFrame(player)
        GUIUtil.AddElement({parent = frameElement, name = "target", type = "label", caption = targetLocalisedString, style = "muppet_bold_text"}, "biterhuntgroup")
        childElementPresent = true
    end

    if not childElementPresent then
        GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "biterhuntgroup", "main", "frame")
    end
end
