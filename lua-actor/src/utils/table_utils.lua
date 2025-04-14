-- Table utility functions

-- Helper function to perform deep comparison of two values
local function deepCompare(a, b)
    -- Handle nil cases
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end
    -- Handle different types
    if type(a) ~= type(b) then return false end
    -- Handle non-table types
    if type(a) ~= "table" then
        return a == b
    end
    -- Handle arrays (tables with numeric keys)
    if #a > 0 or #b > 0 then
        if #a ~= #b then return false end
        for i = 1, #a do
            if not deepCompare(a[i], b[i]) then
                return false
            end
        end
        return true
    end
    -- Handle objects (tables with string keys)
    local aKeys = {}
    local bKeys = {}
    -- Collect keys
    for k in pairs(a) do
        aKeys[k] = true
    end
    for k in pairs(b) do
        bKeys[k] = true
    end
    -- Check if they have the same keys
    for k in pairs(aKeys) do
        if not bKeys[k] then return false end
    end
    for k in pairs(bKeys) do
        if not aKeys[k] then return false end
    end
    -- Compare values for each key
    for k in pairs(a) do
        if not deepCompare(a[k], b[k]) then
            return false
        end
    end

    return true
end

-- Helper function to replace variable references with their values
local function replaceVariableReferences(obj, variablesTable)
    if type(obj) ~= "table" then
        if type(obj) == "string" then
            -- Look for ${variableName} pattern
            return obj:gsub("%${([^}]+)}", function(varName)
                local var = variablesTable[varName]
                if var then
                    return tostring(var:get())
                end
                return "${" .. varName .. "}" -- Keep original if variable not found
            end)
        end
        return obj
    end
    -- Handle arrays
    if #obj > 0 then
        local result = {}
        for i, v in ipairs(obj) do
            result[i] = replaceVariableReferences(v, variablesTable)
        end
        return result
    end
    -- Handle objects
    local result = {}
    for k, v in pairs(obj) do
        result[k] = replaceVariableReferences(v, variablesTable)
    end
    return result
end

-- Helper function to print a table in a readable format
local function printTable(t, indent, visited)
    indent = indent or 0
    visited = visited or {}
    
    -- Handle non-table values
    if type(t) ~= "table" then
        print(string.rep("  ", indent) .. tostring(t))
        return
    end
    
    -- Handle already visited tables to prevent infinite recursion
    if visited[t] then
        print(string.rep("  ", indent) .. "[circular reference]")
        return
    end
    visited[t] = true
    
    -- Handle empty table
    if next(t) == nil then
        print(string.rep("  ", indent) .. "{}")
        return
    end
    
    -- Handle arrays (tables with numeric keys)
    if #t > 0 then
        print(string.rep("  ", indent) .. "[")
        for i, v in ipairs(t) do
            print(string.rep("  ", indent + 1) .. tostring(i) .. ":")
            printTable(v, indent + 2, visited)
        end
        print(string.rep("  ", indent) .. "]")
        return
    end
    
    -- Handle objects (tables with string keys)
    print(string.rep("  ", indent) .. "{")
    for k, v in pairs(t) do
        print(string.rep("  ", indent + 1) .. tostring(k) .. ":")
        printTable(v, indent + 2, visited)
    end
    print(string.rep("  ", indent) .. "}")
end

return {
    deepCompare = deepCompare,
    replaceVariableReferences = replaceVariableReferences,
    printTable = printTable
} 