local Settings = {}
local Utils = require("utility/utils")
local Logging = require("utility/logging")

--Strips any % characters from a number value to avoid silly user entry issues.
local function ValueToType(value, expectedType)
    if expectedType == nil or expectedType == "" then
        Logging.LogPrint("Settings.ValueToType() called with blank/no type")
        return
    elseif expectedType == "string" then
        return tostring(value)
    elseif expectedType == "number" then
        value = string.gsub(value, "%%", "")
        return tonumber(value)
    elseif expectedType == "boolean" then
        return Utils.ToBoolean(value)
    elseif expectedType == "table" then
        return value
    else
        Logging.LogPrint("Settings.ValueToType() called with invalid type: '" .. expectedType .. "'")
        return
    end
end

Settings.CreateGlobalGroupSettingsContainer = function(globalGroupsContainer, id, globalSettingContainerName)
    globalGroupsContainer[id] = globalGroupsContainer[id] or {}
    globalGroupsContainer[id][globalSettingContainerName] = globalGroupsContainer[id][globalSettingContainerName] or {}
    return globalGroupsContainer[id][globalSettingContainerName]
end

--[[
    If only 1 value is passed it sets ID 0 as that value. If array is recieved then each ID abvoe 0 uses the array value and ID 0 is set as the defaultValue.
    Passes value to callback function "valueHandlingFunction" to be processed uniquely for each setting. If this is ommitted then the value is just straight assigned without any processing.
    Clears all old instances of the setting from all groups in the groups container before updating. Only way to remove old stale data.
]]
Settings.HandleSettingWithArrayOfValues = function(settingType, settingName, expectedValueType, defaultSettingsContainer, defaultValue, globalGroupsContainer, globalSettingContainerName, globalSettingName, valueHandlingFunction)
    for _, group in pairs(globalGroupsContainer) do
        group[globalSettingContainerName][globalSettingName] = nil
    end
    valueHandlingFunction = valueHandlingFunction or function(value)
            return value
        end
    local values = settings[settingType][settingName].value
    local tableOfValues = game.json_to_table(values)
    if tableOfValues ~= nil and type(tableOfValues) == "table" then
        for id, value in pairs(tableOfValues) do
            local thisGlobalSettingContainer = Settings.CreateGlobalGroupSettingsContainer(globalGroupsContainer, id, globalSettingContainerName)
            local typedValue = ValueToType(value, expectedValueType)
            if typedValue ~= nil then
                thisGlobalSettingContainer[globalSettingName] = valueHandlingFunction(typedValue)
            else
                thisGlobalSettingContainer[globalSettingName] = valueHandlingFunction(defaultValue)
                Logging.LogPrint("Setting '[" .. settingType .. "][" .. settingName .. "]' for entry number '" .. id .. "' has an invalid value type. Expected a '" .. expectedValueType .. "' but got the value '" .. value .. "', so using default value of '" .. defaultValue .. "'")
            end
        end
        defaultSettingsContainer[globalSettingName] = valueHandlingFunction(defaultValue)
    else
        local typedValue = ValueToType(values, expectedValueType)
        if typedValue ~= nil then
            defaultSettingsContainer[globalSettingName] = valueHandlingFunction(typedValue)
        else
            defaultSettingsContainer[globalSettingName] = valueHandlingFunction(defaultValue)
            Logging.LogPrint("Setting '[" .. settingType .. "][" .. settingName .. "]' isn't a valid Lua table and has an invalid value type for a single value. Expected a single or table of '" .. expectedValueType .. "' but got the value '" .. values .. "', so using default value of '" .. defaultValue .. "'")
        end
    end
end

Settings.GetSettingValueForId = function(globalGroupsContainer, id, globalSettingContainerName, settingName, defaultSettingsContainer)
    local thisGroup = globalGroupsContainer[id]
    if thisGroup ~= nil and thisGroup[globalSettingContainerName] ~= nil and thisGroup[globalSettingContainerName][settingName] ~= nil then
        return thisGroup[globalSettingContainerName][settingName]
    end
    if defaultSettingsContainer ~= nil and defaultSettingsContainer[settingName] ~= nil then
        return defaultSettingsContainer[settingName]
    end
    error("Trying to get mod setting '" .. settingName .. "' that doesn't exist")
end

return Settings
