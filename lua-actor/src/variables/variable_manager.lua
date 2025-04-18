local VcValidator = require("vc-validator")
local ValidationModule = require("variables.validation")
local VariableManager = {}

function VariableManager.new(variables)
    local self = {
        variables = {}
    }
    
    for id, var in pairs(variables) do
        self.variables[id] = {
            value = var.value,
            type = var.type,
            name = var.name,
            description = var.description,
            validation = var.validation,
            get = function(self)
                return self.value
            end,
            set = function(self, newValue)
                if self.validation then
                    -- Use shared validation module for common validations
                    local isValid, errorMsg = ValidationModule.validateValue(newValue, self.validation, self.name)
                    if not isValid then
                        error(errorMsg)
                    end
                end
                self.value = newValue
            end
        }
    end

    setmetatable(self, { __index = VariableManager })
    return self
end

function VariableManager:isVariable(name)
    return self.variables[name] ~= nil
end

function VariableManager:getVariable(name)
    local var = self.variables[name]
    if not var then
        error(string.format("Variable not found: %s", name))
    end
    return var:get()
end

function VariableManager:setVariable(name, value)
    local var = self.variables[name]
    if not var then
        error(string.format("Variable not found: %s", name))
    end
    var:set(value)
end

function VariableManager:getAllVariables()
    local result = {}
    for name, var in pairs(self.variables) do
        result[name] = {
            value = var:get(),
            type = var.type,
            name = var.name,
            description = var.description
        }
    end
    return result
end

-- Given a string input, resolve it as a variable reference 
-- (e.g. ${variables.partyAEthAddress.value} will return the nested property value)
-- Otherwise, return nil
function VariableManager:tryResolveExactStringAsVariableObject(possibleVariableReferenceString)
    if type(possibleVariableReferenceString) ~= "string" then
        return nil
    end

    local trimmed = possibleVariableReferenceString:match("^%s*(.-)%s*$")
    
    -- Check if the string has ${variables.x} format
    local varPath = trimmed:match("^%${([^}]+)}$")
    if not varPath or not varPath:match("^variables%.") then
        return nil
    end

    -- Remove the "variables." prefix and split the remaining path
    local path = varPath:sub(10) -- Remove "variables."
    local parts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(parts, part)
    end

    if #parts == 0 then
        return nil
    end

    -- Get the base variable definition
    local varDef = self.variables[parts[1]]
    if not varDef then
        return nil
    end

    -- Start with the variable definition object itself
    local current = varDef
    
    -- Handle different property paths
    if #parts > 1 then
        -- First property access (parts[2])
        if parts[2] == "value" then
            current = current:get()
        else
            current = current[parts[2]]
        end
        
        if current == nil then
            return nil
        end
        
        -- Traverse any remaining nested properties (from index 3 onward)
        for i = 3, #parts do
            if type(current) ~= "table" then
                return nil
            end
            current = current[parts[i]]
            if current == nil then
                return nil
            end
        end
    end

    return current
end

return VariableManager 