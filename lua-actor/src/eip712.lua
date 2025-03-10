local crypto = require(".crypto.init")
local Array = require(".crypto.util.array")

-- Forward declarations for functions with circular dependencies
local encodeParameter
local isDynamicType
local encodeField
local encodeData
local hashStruct

local function padLeft(str, length, char)
    char = char or '0'
    local padding = string.rep(char, length - #str)
    return padding .. str
end

local function padRight(str, length, char)
    char = char or '0'
    local padding = string.rep(char, length - #str)
    return str .. padding
end

-- Basic type encoders
local function encodeUint256(value)
    local hex = string.format("%x", value)
    return padLeft(hex, 64)
end

local function encodeAddress(value)
    value = string.gsub(value, "^0x", "")
    return padLeft(value, 64)
end

local function encodeBool(value)
    return encodeUint256(value and 1 or 0)
end

local function encodeBytes(value)
  local length = encodeUint256(#value)
  local paddedData = value .. string.rep(string.char(0), (32 - (#value % 32)) % 32)
  return length .. paddedData
end

local function encodeFixedBytes(value, size)
    if #value > size * 2 then -- hex string expected, 2 hex chars per byte
        error(string.format("Value too long for bytes%d: got %d bytes", size, #value))
    end
    return value .. string.rep(string.char(0), size - #value)
end

local function encodeString(value)
    local bytes = string.char(string.byte(value, 1, -1))
    return encodeBytes(bytes)
end

local function encodeArray(baseType, array, size)
    local result = ""
    if #size == 0 then
        result = encodeUint256(#array)
    end
    
    for _, value in ipairs(array) do
        result = result .. encodeParameter(baseType, value)
    end
    
    return result
end

function isDynamicType(typ)
    -- Check for basic dynamic types
    if typ == "string" or typ == "bytes" then
        return true
    end
    
    -- Check for fixed-size bytes (bytes1 to bytes32)
    local bytesMatch = string.match(typ, "^bytes(%d+)$")
    if bytesMatch then
        local size = tonumber(bytesMatch)
        if size then
            return false  -- Fixed-size bytes are static
        end
        error("Invalid bytes size: " .. bytesMatch)
    end
    
    -- Check for arrays - pattern needs to handle the full type including numbers
    local baseType, size = string.match(typ, "^([%a%d]+)%[(%d*)%]$")
    if baseType then
        -- Dynamic if it's an unbounded array or contains dynamic types
        return #size == 0 or isDynamicType(baseType)
    end
    
    return false
end


-- Parameter encoding
function encodeParameter(typ, value)
    if typ == "uint256" then
        return encodeUint256(value)
    elseif typ == "address" then
        return encodeAddress(value)
    elseif typ == "bool" then
        return encodeBool(value)
    elseif typ == "string" then
        return encodeString(value)
    elseif typ == "bytes" then
        return encodeBytes(value)
    end
    
    -- Handle fixed-size bytes
    local bytesMatch = string.match(typ, "^bytes(%d+)$")
    if bytesMatch then
        local size = tonumber(bytesMatch)
        if size then
            return encodeFixedBytes(value, size)
        end
    end

    local baseType, size = string.match(typ, "^([%a%d]+)%[(%d*)%]$")
    if baseType then
        return encodeArray(baseType, value, size)
    end
    
    error("Unsupported type: " .. typ)
end

-- ABI encoding
local function abiEncode(types, values)
    local headLength = 0
    local heads = {}
    local tails = {}
    local dynamicCount = 0
    
    for i, typ in ipairs(types) do
        local value = values[i]
        
        if isDynamicType(typ) then
            table.insert(heads, "")
            dynamicCount = dynamicCount + 1
        else
            local encoded = encodeParameter(typ, value)
            table.insert(heads, encoded)
        end
        
        headLength = headLength + 32
    end
    
    local currentDynamicPointer = headLength
    for i, typ in ipairs(types) do
        if isDynamicType(typ) then
            local value = values[i]
            local encoded = encodeParameter(typ, value)
            
            heads[i] = encodeUint256(currentDynamicPointer)
            table.insert(tails, encoded)
            
            currentDynamicPointer = currentDynamicPointer + #encoded
        end
    end
    
    return table.concat(heads) .. table.concat(tails)
end

-- EIP-712 specific functions
local function keccak256(input)
    return crypto.digest.keccak256(input).asHex()
end

local function findTypeDependencies(typeName, types, deps)
    deps = deps or {}
    
    if not deps[typeName] then
        deps[typeName] = true
        
        for _, field in ipairs(types[typeName]) do
            local match = string.match(field.type, "^([A-Z][A-Za-z0-9]*)$")
            if match then
                findTypeDependencies(match, types, deps)
            end
        end
    end
    
    local result = {}
    for dep in pairs(deps) do
        table.insert(result, dep)
    end
    return result
end

local function encodeParameters(type)
    local params = {}
    for _, param in ipairs(type) do
        table.insert(params, param.type .. " " .. param.name)
    end
    return table.concat(params, ",")
end

local function encodeType(typeName, types)
    local deps = findTypeDependencies(typeName, types)
    local index
    for i, v in ipairs(deps) do
        if v == typeName then
            index = i
            break
        end
    end
    table.remove(deps, index)
    table.sort(deps)
    table.insert(deps, 1, typeName)
    
    local encodedTypes = ""
    for _, dep in ipairs(deps) do
        local type = types[dep]
        encodedTypes = encodedTypes .. dep .. "(" .. encodeParameters(type) .. ")"
    end
    
    return encodedTypes
end

local function typeHash(typeName, types)
    return keccak256(encodeType(typeName, types))
end

function encodeField(type, value, types)
    if types[type] then
        -- value is of a nested type
        return {
            type = "bytes32",
            value = hashStruct(type, value, types)
        }
    end
    -- Handle arrays
    local baseType = string.match(type, "^([%a%d]+)%[(%d*)%]$")
    if baseType then
        local types = {}
        local values = {}
        
        -- Process each array item through encodeField to handle type conversion
        for _, item in ipairs(value or {}) do
            local itemEncoded = encodeField(baseType, item, types)
            -- For values already encoded as bytes32, use them directly
            if itemEncoded.type == "bytes32" then
                table.insert(types, itemEncoded.type)
                table.insert(values, itemEncoded.value)
            else
                -- For other types, encode and hash them
                table.insert(types, 'bytes32')
                local itemAbiEncoded = abiEncode({itemEncoded.type}, {itemEncoded.value})
                local itemAbiEncodeBytes = Array.fromHex(itemAbiEncoded)
                local itemEncodedBunaryStr = Array.toString(itemAbiEncodeBytes)
                table.insert(values, keccak256(itemEncodedBunaryStr))
            end
        end
        
        -- Array values are already bytes32, just encode them as an array and hash
        local apiEncoded = abiEncode(types, values)
        local abiEncodeBytes = Array.fromHex(apiEncoded)
        local apiEncodedBunaryStr = Array.toString(abiEncodeBytes)
        return {
            type = "bytes32",
            value = keccak256(apiEncodedBunaryStr)
        }
    end
    
    -- Handle structs
    if string.match(type, "^[A-Z]") then
        return {
            type = "bytes32",
            value = keccak256(encodeData(type, value, types))
        }
    end

    -- Handle strings by hashing them to bytes32
    if type == "string" then
        return {
            type = "bytes32",
            value = keccak256(value or "")
        }
    end

    -- Handle basic types
    return {
        type = type,
        value = value
    }
end

local function getDefaultValue(typ)
    -- Handle basic types
    if typ == "uint256" or typ == "int256" then
        return 0
    elseif typ == "address" then
        return "0x0000000000000000000000000000000000000000"
    elseif typ == "bool" then
        return false
    elseif typ == "string" then
        return ""
    elseif typ == "bytes" then
        return ""
    end
    
    -- Handle fixed-size bytes
    local bytesMatch = string.match(typ, "^bytes(%d+)$")
    if bytesMatch then
        local n = tonumber(bytesMatch)
        if n then
            local size = math.floor(n)
            return string.rep("\0", size)
        end
        error("Invalid bytes size: " .. bytesMatch)
    end
    
    -- Handle arrays
    local baseType = string.match(typ, "^([%a%d]+)%[")
    if baseType then
        return {}
    end
    
    -- Handle structs (starting with uppercase)
    if string.match(typ, "^[A-Z]") then
        return {}
    end
    
    error("Unsupported type for default value: " .. typ)
end

function encodeData(typeName, data, types)
    local encTypes = {}
    local encValues = {}
    
    table.insert(encTypes, "bytes32")
    table.insert(encValues, typeHash(typeName, types))
    
    for _, field in ipairs(types[typeName]) do
        local value = data[field.name]
        if value == nil then
            value = getDefaultValue(field.type)
        end
        local encoded = encodeField(field.type, value, types)
        table.insert(encTypes, encoded.type)
        table.insert(encValues, encoded.value)
    end
    
    local abiEncodedData = abiEncode(encTypes, encValues)
    return abiEncodedData
end

function hashStruct(primaryType, data, types)
    local encodedData = encodeData(primaryType, data, types)
    local bytes = Array.fromHex(encodedData)
    local binary_string = Array.toString(bytes)
    return keccak256(binary_string)
end

local function getSigningInput(domainSeparator, structHash)
    local fullInputHexString = '1901' .. domainSeparator .. structHash
    local fullInputBytes = Array.fromHex(fullInputHexString)
    local fullInputBinaryStr = Array.toString(fullInputBytes)
    return keccak256(fullInputBinaryStr)
end

local function createDomainSeparator(domain)
    local domainData = {
        name = domain.name,
        version = domain.version,
        chainId = domain.chainId,
        -- verifyingContract = domain.verifyingContract
    }
    
    return hashStruct("EIP712Domain", domainData, {
        EIP712Domain = {
            {name = "name", type = "string"},
            {name = "version", type = "string"},
            {name = "chainId", type = "uint256"},
            -- {name = "verifyingContract", type = "address"}
        }
    })
end

return {
    createDomainSeparator = createDomainSeparator,
    hashStruct = hashStruct,
    getSigningInput = getSigningInput,
    encodeType = encodeType,
    typeHash = typeHash,
    abiEncode = abiEncode
}