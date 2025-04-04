local Comparison = {}

function Comparison.deepCompare(a, b)
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
            if not Comparison.deepCompare(a[i], b[i]) then
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
        if not Comparison.deepCompare(a[k], b[k]) then
            return false
        end
    end

    return true
end

return Comparison 