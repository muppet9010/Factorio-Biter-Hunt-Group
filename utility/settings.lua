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

local function HandleValueToType(id, value, expectedValueType, defaultValue, valueHandlingFunction)
    local typedValue = ValueToType(value, expectedValueType)
    if typedValue ~= nil then
        valueHandlingFunction(id, typedValue)
        return true
    else
        valueHandlingFunction(id, defaultValue)
        return false
    end
end

--[[
    If only 1 value is passed it sets ID 0 as that value. If array is recieved then each ID abvoe 0 uses the array value and ID 0 is set as the defaultValue.
    Passes ID and value to callback function "valueHandlingFunction" to be processed uniquely for each setting.
]]
Settings.HandleSettingWithArrayOfValues = function(settingType, settingName, expectedValueType, defaultValue, valueHandlingFunction)
    local values = settings[settingType][settingName].value
    local tableOfValues = game.json_to_table(values)
    if tableOfValues ~= nil and type(tableOfValues) == "table" then
        for id, value in pairs(tableOfValues) do
            if not HandleValueToType(id, value, expectedValueType, defaultValue, valueHandlingFunction) then
                Logging.LogPrint("Setting '[" .. settingType .. "][" .. settingName .. "]' for entry number '" .. id .. "' has an invalid value type. Expected a '" .. expectedValueType .. "' but got the value '" .. value .. "', so using default value of '" .. defaultValue .. "'")
            end
        end
        valueHandlingFunction(0, defaultValue)
    else
        if not HandleValueToType(0, values, expectedValueType, defaultValue, valueHandlingFunction) then
            Logging.LogPrint("Setting '[" .. settingType .. "][" .. settingName .. "]' isn't a valid Lua table and has an invalid value type for a single value. Expected a single or table of '" .. expectedValueType .. "' but got the value '" .. values .. "', so using default value of '" .. defaultValue .. "'")
        end
    end
end

return Settings
