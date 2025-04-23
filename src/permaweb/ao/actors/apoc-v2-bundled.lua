-- Module definitions
local __modules = {}
local __loaded = {}

-- Begin module: src/eip712.lua
__modules["src/eip712"] = function()
  if __loaded["src/eip712"] then return __loaded["src/eip712"] end
local crypto = require(".crypto.init")
local Array = require(".crypto.util.array")

-- A pure Lua implementation of the EIP-712 encoding logic. Used in actor logic to validate VCs using 

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

local function encodeArray(baseType, array, size, types)
    local result = ""
    if #size == 0 then
        result = encodeUint256(#array)
    end
    
    -- For arrays of structs, we need to hash each item first
    if types and types[baseType] then
        for _, value in ipairs(array) do
            local hash = hashStruct(baseType, value, types)
            result = result .. encodeParameter("bytes32", hash, types)
        end
    else
        -- For primitive arrays, encode directly
        for _, value in ipairs(array) do
            result = result .. encodeParameter(baseType, value, types)
        end
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
function encodeParameter(typ, value, types)
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
        return encodeArray(baseType, value, size, types)
    end
    
    error("Unsupported type: " .. typ)
end

-- ABI encoding
local function abiEncode(types, values, eip712types)
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
            local encoded = encodeParameter(typ, value, eip712types)
            table.insert(heads, encoded)
        end
        
        headLength = headLength + 32
    end
    
    local currentDynamicPointer = headLength
    for i, typ in ipairs(types) do
        if isDynamicType(typ) then
            local value = values[i]
            local encoded = encodeParameter(typ, value, eip712types)
            
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

local function findTypeDependenciesWorker(typeName, types, deps)
    deps = deps or {}
    
    if not deps[typeName] then
        deps[typeName] = true
        
        for _, field in ipairs(types[typeName]) do
            -- Match both struct types and arrays of struct types with a single pattern
            -- e.g., 'CredentialSubject' or 'Fields[]'
            local match = string.match(field.type, "^([A-Z][A-Za-z0-9]*)%[?%]?$")
            if match then
                findTypeDependenciesWorker(match, types, deps)
            end
        end
    end
    
    return deps
end

local function findTypeDependencies(typeName, types)
    -- First discover all dependencies
    local deps = findTypeDependenciesWorker(typeName, types)
    
    -- Then convert to array format
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
        local arrayTypes = {}
        local arrayValues = {}
        
        -- Check if baseType is a struct type
        if types[baseType] then
            -- For arrays of structs, hash each struct individually
            for _, item in ipairs(value or {}) do
                local structHash = hashStruct(baseType, item, types)
                table.insert(arrayTypes, "bytes32")
                table.insert(arrayValues, structHash)
            end
        else
            -- For primitive arrays, process each item
            for _, item in ipairs(value or {}) do
                local itemEncoded = encodeField(baseType, item, types)
                if itemEncoded.type == "bytes32" then
                    table.insert(arrayTypes, itemEncoded.type)
                    table.insert(arrayValues, itemEncoded.value)
                else
                    table.insert(arrayTypes, 'bytes32')
                    local itemAbiEncoded = abiEncode({itemEncoded.type}, {itemEncoded.value})
                    local itemAbiEncodeBytes = Array.fromHex(itemAbiEncoded)
                    local itemEncodedBunaryStr = Array.toString(itemAbiEncodeBytes)
                    table.insert(arrayValues, keccak256(itemEncodedBunaryStr))
                end
            end
        end
        
        -- Array values are already bytes32, just encode them as an array and hash
        local apiEncoded = abiEncode(arrayTypes, arrayValues)
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
    
    -- First, add the type hash
    table.insert(encTypes, "bytes32")
    table.insert(encValues, typeHash(typeName, types))
    
    -- Process fields in the exact order they appear in types
    for _, field in ipairs(types[typeName]) do
        local value = data[field.name]
        if value == nil then
            value = getDefaultValue(field.type)
        end
        local encoded = encodeField(field.type, value, types)
        table.insert(encTypes, encoded.type)
        table.insert(encValues, encoded.value)
    end
    
    -- Encode the data
    local abiEncodedData = abiEncode(encTypes, encValues, types)
    return abiEncodedData
end

function hashStruct(primaryType, data, types)
    -- First encode the data
    local encodedData = encodeData(primaryType, data, types)
    
    -- Convert hex to binary string
    local bytes = Array.fromHex(encodedData)
    local binary_string = Array.toString(bytes)
    
    -- Hash the binary string
    return keccak256(binary_string)
end

local function getSigningInput(domainSeparator, structHash)
    -- Combine domain separator and struct hash with EIP-712 prefix
    local fullInputHexString = '1901' .. domainSeparator .. structHash
    
    -- Convert hex to binary string
    local fullInputBytes = Array.fromHex(fullInputHexString)
    local fullInputBinaryStr = Array.toString(fullInputBytes)
    
    -- Hash the binary string
    return keccak256(fullInputBinaryStr)
end

local function createDomainSeparator(domain, types)
    if not types or not types.EIP712Domain then
        -- Create domain type with fields in the standard order
        local domainType = {
            {name = "name", type = "string"},
            {name = "version", type = "string"},
            {name = "chainId", type = "uint256"}
        }
        
        -- Create domain data with fields in the same order
        local domainData = {
            name = domain.name,
            version = domain.version,
            chainId = domain.chainId
        }
        
        -- Create types object with only EIP712Domain
        local types = {
            EIP712Domain = domainType
        }
        
        return hashStruct("EIP712Domain", domainData, types)
    end

    return hashStruct("EIP712Domain", domain, types)
end


  __loaded["src/eip712"] = {
    createDomainSeparator = createDomainSeparator,
    hashStruct = hashStruct,
    getSigningInput = getSigningInput,
    encodeType = encodeType,
    typeHash = typeHash,
    abiEncode = abiEncode
}
  return __loaded["src/eip712"]
end
-- End module: src/eip712.lua

-- Begin module: src/vc-validator.lua
__modules["src/vc-validator"] = function()
  if __loaded["src/vc-validator"] then return __loaded["src/vc-validator"] end
-- Explicitly importing secp256k1 and exposing recover_public_key, which is a global var in our custom AO module.

local recover_public_key = recover_public_key

local json = require("json")
local Array = require(".crypto.util.array")
local crypto = require(".crypto.init")

local eip712 = __modules["src/eip712"]()

local function strip_hex_prefix(hex_str)
  if hex_str:sub(1, 2) == "0x" then
    return hex_str:sub(3)
  end
  return hex_str
end

local function pubkey_to_eth_address(pubkey_hex)
  if #pubkey_hex ~= 130 or pubkey_hex:sub(1, 2) ~= '04' then
    error('toEthereumAddress: Expecting an uncompressed public key')
  end
  local pubkey_hex_clean = pubkey_hex:sub(3) -- dropping the leading '04' indicating an uncompressed public key format
  local pubkey_binary_bytes = Array.fromHex(pubkey_hex_clean)
  local pubkey_binary_str = Array.toString(pubkey_binary_bytes)
  local keccak_hash = crypto.digest.keccak256(pubkey_binary_str).asHex()
  return '0x'..string.sub(keccak_hash, -40, -1); -- last 40 hex chars, aka 20 bytes
end

local function decode_signature(signature)
  local sanitized_sig = strip_hex_prefix(signature)

  if #sanitized_sig ~= 130 then
    error("Invalid signature length: expected 130 hex chars (65 bytes)")
  end

  return sanitized_sig
end

local function string_split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function get_authority(issuer)
  local eth_address = nil
  if (issuer) then
    local parts = string_split(issuer, ':')
    -- eg. 'did:pkh:eip155:1:0x1e8564A52fc67A68fEe78Fc6422F19c07cFae198'
    if (parts[1] == 'did' and parts[2] == 'pkh' and parts[3] == 'eip155' and parts[4] == '1') then
      eth_address = parts[5]
    else
      error('Only supporting did:pkh issuers')
    end
    return string.lower(eth_address or '')
  end
  error('No issuer found')
end

local function vc_validate(vc)
  local vc_json = json.decode(vc)
  local owner_eth_address = get_authority(vc_json.issuer.id)
  local proof = vc_json.proof
  local proofValue = nil
  local signature_hex = nil
  if proof.type == 'EthereumEip712Signature2021' then
    proofValue = proof.proofValue
    signature_hex = decode_signature(proofValue)
  else
    error('Only supporting EthereumEip712Signature2021 proof type')
  end

  local eip712data = vc_json.proof.eip712
  local domain = eip712data.domain
  local types = eip712data.types
  local primaryType = eip712data.primaryType
  local domainSeparator = eip712.createDomainSeparator(domain)

  local message = Array.copy(vc_json)
  local proof_copy = Array.copy(vc_json.proof)
  proof_copy.proofValue = nil
  proof_copy.eip712 = nil
  proof_copy.eip712Domain = nil
  message.proof = proof_copy

  local structHash = eip712.hashStruct(primaryType, message, types)
  local signingInput = eip712.getSigningInput(domainSeparator, structHash)
  print('Signing Input:', signingInput)

  -- Recover public key and verify
  local pubkey_hex = recover_public_key(signature_hex, signingInput)
  local eth_address = pubkey_to_eth_address(pubkey_hex)
  local success = eth_address == owner_eth_address

  print('Recovered ETH Address:', eth_address)
  print('Validation Result:', success)
  print('===================')

  return success, vc_json, owner_eth_address
end


  __loaded["src/vc-validator"] = {
  validate = vc_validate,
}
  return __loaded["src/vc-validator"]
end
-- End module: src/vc-validator.lua

-- Begin module: src/variables/validation.lua
__modules["src/variables/validation"] = function()
  if __loaded["src/variables/validation"] then return __loaded["src/variables/validation"] end
-- Shared validation module for both InputVerifier and VariableManager
local ValidationModule = {}

-- Core validation function that can be used for both variables and input fields
-- Returns success (boolean) and error message (string or nil)
function ValidationModule.validateValue(value, validation, fieldName)
    -- Skip validation if validation rules not provided
    if not validation then
        return true, nil
    end

    -- Check required field
    if validation.required and (value == nil or value == "") then
        return false, string.format("%s is required", fieldName)
    end

    -- Skip remaining validation if value is nil and not required
    if value == nil then
        return true, nil
    end

    -- Type validation is handled by the caller, as the type checks differ
    -- between variables and input fields

    -- String validations
    if type(value) == "string" then
        -- Min length
        if validation.minLength and #value < validation.minLength then
            return false, string.format("%s must be at least %d characters", fieldName, validation.minLength)
        end
        
        -- Max length
        if validation.maxLength and #value > validation.maxLength then
            return false, string.format("%s must be at most %d characters", fieldName, validation.maxLength)
        end
        
        -- Pattern
        if validation.pattern then
            local pattern = validation.pattern:gsub("\\/", "/")
            if not string.match(value, pattern) then
                return false, string.format("%s: %s", fieldName, validation.message or "Invalid format")
            end
        end
    end
    
    -- Number validations
    if type(value) == "number" then
        -- Min value
        if validation.min and value < validation.min then
            return false, string.format("%s must be at least %s", fieldName, tostring(validation.min))
        end
        
        -- Max value
        if validation.max and value > validation.max then
            return false, string.format("%s must be at most %s", fieldName, tostring(validation.max))
        end
    end
    
    return true, nil
end


  __loaded["src/variables/validation"] = ValidationModule
  return __loaded["src/variables/validation"]
end
-- End module: src/variables/validation.lua

-- Begin module: src/variables/variable_manager.lua
__modules["src/variables/variable_manager"] = function()
  if __loaded["src/variables/variable_manager"] then return __loaded["src/variables/variable_manager"] end
local VcValidator = __modules["src/vc-validator"]()
local ValidationModule = __modules["src/variables/validation"]()
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


  __loaded["src/variables/variable_manager"] = VariableManager
  return __loaded["src/variables/variable_manager"]
end
-- End module: src/variables/variable_manager.lua

-- Begin module: src/verifiers/input_verifier.lua
__modules["src/verifiers/input_verifier"] = function()
  if __loaded["src/verifiers/input_verifier"] then return __loaded["src/verifiers/input_verifier"] end
local json = require("json")
local crypto = require(".crypto")
local VcValidator = __modules["src/vc-validator"]()
local FieldValidator = __modules["src/variables/validation"]()

local ETHEREUM_ADDRESS_REGEX = "^0x(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)$"

-- Helper function to validate Ethereum address checksum
local function validateEthAddressChecksum(address)
    -- Remove 0x prefix and convert to lowercase
    local addr = string.lower(string.sub(address, 3))
    
    -- Calculate keccak256 hash of the lowercase address
    local hash = crypto.digest.keccak256(addr).asHex()
    
    -- Check each character
    for i = 1, #addr do
        local c = string.sub(addr, i, i)
        local h = string.sub(hash, i, i)
        local hnum = tonumber(h, 16)
        
        -- If the hash digit is 8 or higher, the address character should be uppercase
        if hnum >= 8 then
            if string.sub(address, i + 2, i + 2) ~= string.upper(c) then
                return false
            end
        else
            if string.sub(address, i + 2, i + 2) ~= c then
                return false
            end
        end
    end
    
    return true
end

-- Shared validation module
local ValidationUtils = {
    ethAddressEqual = function (address1, address2)
            return string.lower(address1) == string.lower(address2)
        end,
    validateField = function(field, value)
        if not field.validation then
            return false, "Field validation is missing"
        end

        -- Validate type first (specific to InputVerifier)
        if field.type == "string" and type(value) ~= "string" then
            return false, string.format("Field %s must be a string", field.name or field.id)
        elseif field.type == "address" then
            print("--Address Validation Debug--")
            print("Value type:", type(value))
            print("Value:", value)
            print("Value length:", #value)
            
            -- Basic format validation
            if not string.match(value, ETHEREUM_ADDRESS_REGEX) then
                return false, string.format("Field %s must be a valid Ethereum address format", field.name or field.id)
            end
            
            -- Checksum validation
            if not validateEthAddressChecksum(value) then
                return false, string.format("Field %s must be a valid Ethereum address with correct checksum", field.name or field.id)
            end
            
            print("Address validation passed")
        elseif field.type == "number" and type(value) ~= "number" then
            return false, string.format("Field %s must be a number", field.name or field.id)
        end

        -- Use shared validation for common validations
        local fieldName = field.name or field.id
        local isValid, errorMsg = FieldValidator.validateValue(value, field.validation, fieldName)
        
        if not isValid then
            return false, errorMsg
        end

        return true
    end
}

-- Base Verifier class
local BaseVerifier = {}
BaseVerifier.__index = BaseVerifier

function BaseVerifier:new()
    local self = setmetatable({}, BaseVerifier)
    return self
end

-- EIP712 Verifier implementation
local EIP712Verifier = BaseVerifier:new()
EIP712Verifier.__index = EIP712Verifier

function EIP712Verifier:new()
    local self = setmetatable({}, EIP712Verifier)
    return self
end

function EIP712Verifier:verify(input, value, variables, validate)
    local vcJson, credentialSubject, issuerAddress
    
    -- Default to not validating if not explicitly set
    validate = validate == true
    
    if type(value) == "string" then
        if validate then
            -- Use cryptographic validation in production
            local success, parsedVcJson, recoveredIssuerAddress = VcValidator.validate(value)
            if not success then
                return false, "Invalid VC"
            end
            vcJson = parsedVcJson
            issuerAddress = recoveredIssuerAddress
        else
            -- Parse the JSON without cryptographic validation (for tests)
            vcJson = json.decode(value)
        end
    else
        -- Already parsed object
        vcJson = value
    end
    
    credentialSubject = vcJson.credentialSubject
    
    -- If we didn't do cryptographic validation, extract issuer address from the format
    if not validate and vcJson.issuer and vcJson.issuer.id then
        local id = vcJson.issuer.id
        local parts = {}
        for part in string.gmatch(id or "", "[^:]+") do
            table.insert(parts, part)
        end
        
        if #parts >= 5 and parts[1] == "did" and parts[2] == "pkh" then
            issuerAddress = parts[5]
        end
    end
    
    -- Validate credential subject structure
    if not credentialSubject then
        return false, "Missing credentialSubject in input"
    end

    if not credentialSubject.values then
        return false, "Missing values in credentialSubject"
    end

    -- Validate fields against input definition
    for fieldId, fieldDef in pairs(input.data) do
        local fieldValue = credentialSubject.values[fieldId]
        
        -- If the value is a string, try to resolve it as a variable
        if type(fieldDef) == "string" and variables then
            local resolvedValue = variables:tryResolveExactStringAsVariableObject(fieldDef)
            if resolvedValue then
                fieldDef = resolvedValue
            end
        end

        -- Validate the field using shared validation
        local isValid, errorMsg = ValidationUtils.validateField(fieldDef, fieldValue)
        if not isValid then
            return false, errorMsg
        end
    end

    -- Validate issuer if specified
    if input.issuer and issuerAddress then
        local expectedIssuer = input.issuer
        if variables then
            -- Try to resolve if it's a variable reference
            local resolvedIssuer = variables:tryResolveExactStringAsVariableObject(expectedIssuer)
            if resolvedIssuer then
                expectedIssuer = resolvedIssuer
            end
        end
        
        if expectedIssuer and not ValidationUtils.ethAddressEqual(expectedIssuer, issuerAddress) then
            local errorMsg = string.format("Issuer mismatch: expected ${%s.value}, got %s", input.issuer, issuerAddress)
            return false, errorMsg
        end
    end

    return true, credentialSubject.values
end

-- EVM Transaction Verifier implementation
local EVMTransactionVerifier = BaseVerifier:new()
EVMTransactionVerifier.__index = EVMTransactionVerifier

function EVMTransactionVerifier:new()
    local self = setmetatable({}, EVMTransactionVerifier)
    return self
end

function EVMTransactionVerifier:verify(input, value, variables)
    -- TODO: Implement actual EVM transaction verification
    return true
end

-- Factory function to get the appropriate verifier
local function getVerifier(inputType)
    if not inputType then
        return nil, "Input type is missing"
    end

    local verifiers = {
        VerifiedCredentialEIP712 = EIP712Verifier:new(),
        EVMTransaction = EVMTransactionVerifier:new()
    }

    local verifier = verifiers[inputType]
    if not verifier then
        return nil, string.format("Unsupported input type: %s", inputType)
    end

    return verifier
end

-- Main verification function
local function verify(input, value, variables, validate)
    if not input then
        return false, "Input definition is nil"
    end

    local verifier, error = getVerifier(input.type)
    if not verifier then
        return false, error
    end

    return verifier:verify(input, value, variables, validate)
end


  __loaded["src/verifiers/input_verifier"] = {
    verify = verify,
    ValidationUtils = ValidationUtils,
}
  return __loaded["src/verifiers/input_verifier"]
end
-- End module: src/verifiers/input_verifier.lua

-- Begin module: src/dfsm.lua
__modules["src/dfsm"] = function()
  if __loaded["src/dfsm"] then return __loaded["src/dfsm"] end
-- DFSM (Deterministic Finite State Machine) implementation
local VariableManager = __modules["src/variables/variable_manager"]()
local InputVerifier = __modules["src/verifiers/input_verifier"]()
local json = require("json")
local VcValidator = __modules["src/vc-validator"]()
local base64 = require(".base64")

local ValidationUtils = InputVerifier.ValidationUtils

-- DFSM class definition
local DFSM = {}

-- Helper function to check if a transition's conditions are met
function DFSM:areTransitionConditionsMet(transition, inputId)
    for _, condition in ipairs(transition.conditions) do
        if condition.type == "isValid" then
            if condition.input == inputId then
                return true
            end
        end
    end
    return #transition.conditions == 0
end

-- Helper function to check if a state has outgoing transitions
function DFSM:hasOutgoingTransitions(stateId)
    for _, t in ipairs(self.transitions) do
        if t.from == stateId then
            return true
        end
    end
    return false
end

-- Initialize a new DFSM instance from a JSON definition
function DFSM.new(doc, expectVCWrapper)
    local self = {
        currentState = nil, -- Will store the entire state object
        inputs = {},
        transitions = {},
        variables = nil,
        received = {},
        complete = false,
        states = {}, -- Store state information (name, description)
    }

    -- Allow skipping VC wrapper processing if not needed for testing
    local agreement = nil
    local initialValues = nil
    if expectVCWrapper then
        -- The agreement template VC is expected to base64 encode the agreement contents
        -- to simplify EIP-712 encoding.
        local credentialSubject = DFSM:processVCWrapper(doc, nil, true)
        agreement = json.decode(base64.decode(credentialSubject.agreement))
        initialValues = credentialSubject.params
    else
        local credentialSubject = json.decode(doc)
        agreement = credentialSubject.agreement
        initialValues = credentialSubject.params
    end

    -- Initialize variables
    self.variables = VariableManager.new(agreement.variables)

    -- Set initial values if provided
    if initialValues then
        for id, value in pairs(initialValues) do
            if self.variables:isVariable(id) then
                self.variables:setVariable(id, value)
            else
                error(string.format("Attempted to set undeclared variable: %s", id))
            end
        end
    end

    -- Validate and set initial state
    if not agreement.execution or not agreement.execution.states then
        error("Agreement document must have states defined")
    end
    
    -- Process states - only support object format
    if type(agreement.execution.states) ~= "table" then
        error("States must be defined as an object")
    end
    
    -- It's an object format with state objects
    local initialStateId = nil
    for stateId, stateObj in pairs(agreement.execution.states) do
        self.states[stateId] = {
            id = stateId, -- Include the ID in the state object for reference
            name = stateObj.name or stateId,
            description = stateObj.description or "",
            isInitial = stateObj.isInitial or false
        }
        
        -- Track initial state
        if stateObj.isInitial then
            if initialStateId then
                error("Multiple initial states found: " .. initialStateId .. " and " .. stateId)
            end
            initialStateId = stateId
        end
    end
    
    if not next(self.states) then
        error("Agreement document must have at least one state")
    end

    -- Set initial state
    if not initialStateId then
        error("No initial state (isInitial=true) found in state definitions")
    end
    self.currentState = self.states[initialStateId]

    -- Process inputs (assuming object structure)
    if agreement.execution.inputs then
        if type(agreement.execution.inputs) ~= "table" then
            error("Inputs must be an object with input IDs as keys")
        end
        for id, input in pairs(agreement.execution.inputs) do
            self.inputs[id] = input
        end
    end

    -- Process transitions
    if agreement.execution.transitions then
        for _, transition in ipairs(agreement.execution.transitions) do
            if not self.states[transition.from] then
                error(string.format("Invalid 'from' state in transition: %s", transition.from))
            end
            if not self.states[transition.to] then
                error(string.format("Invalid 'to' state in transition: %s", transition.to))
            end
            table.insert(self.transitions, transition)
        end
    end

    setmetatable(self, { __index = DFSM })
    return self
end

-- process VC wrapper
function DFSM:processVCWrapper(vc, expectedIssuer, validateVC)
    -- validate by default
    validateVC = validateVC == nil or validateVC
    if validateVC then
        local success, vcJson, ownerAddress = VcValidator.validate(vc)
        assert(success, "Invalid VC");

        if expectedIssuer then
            if not ValidationUtils.ethAddressEqual(ownerAddress, expectedIssuer) then
                local errorMsg = string.format("Issuer mismatch: expected ${variables.partyAEthAddress.value}, got %s", ownerAddress)
                error(errorMsg)
            end
        end
        return vcJson.credentialSubject
    else
        local vcJson = json.decode(vc)
        return vcJson.credentialSubject or vcJson
    end
end

-- Validate the state machine definition
function DFSM:validate()
    -- Check that we have at least one state
    if not next(self.states) then
        error("DFSM must have at least one state")
    end

    -- Find initial state
    local initialStateId = nil
    for stateId, stateInfo in pairs(self.states) do
        if stateInfo.isInitial then
            if initialStateId then
                error(string.format("Multiple initial states found: %s and %s", initialStateId, stateId))
            end
            initialStateId = stateId
        end
    end
    
    if not initialStateId then
        error("No initial state (isInitial=true) found in state definitions")
    end

    -- Check that all states referenced in transitions exist
    for _, transition in ipairs(self.transitions) do
        if not self.states[transition.from] then
            error(string.format("Invalid 'from' state in transition: %s", transition.from))
        end
        if not self.states[transition.to] then
            error(string.format("Invalid 'to' state in transition: %s", transition.to))
        end
    end

    -- Check that all inputs referenced in conditions exist
    local validInputs = {}
    for inputId, _ in pairs(self.inputs) do
        validInputs[inputId] = true
    end

    for _, transition in ipairs(self.transitions) do
        for _, condition in ipairs(transition.conditions) do
            if condition.type == "isValid" then
                if condition.input and not validInputs[condition.input] then
                    error(string.format("Invalid input referenced in condition: %s", condition.input))
                end
                if condition.inputs then
                    for _, inputId in ipairs(condition.inputs) do
                        if not validInputs[inputId] then
                            error(string.format("Invalid input referenced in condition: %s", inputId))
                        end
                    end
                end
            end
        end
    end

    -- Validate input schemas
    for inputId, input in pairs(self.inputs) do
        if not input.type then
            error(string.format("Input %s missing type", inputId))
        end
        if not input.schema then
            error(string.format("Input %s missing schema", inputId))
        end
    end
end

-- Process an input and attempt to transition states
function DFSM:processInput(inputId, inputValue, validateVC)
    if self.complete then
        return false, "State machine is complete"
    end

    -- Check if input has already been processed
    if self.received[inputId] then
        return false, string.format("Input %s has already been processed", inputId)
    end

    -- Get input definition
    local inputDef = self.inputs[inputId]
    if not inputDef then
        return false, string.format("Unknown input: %s", inputId)
    end

    -- For tests, we set validateVC=false to bypass cryptographic validation
    -- For production, validateVC should be true to ensure proper signature validation
    
    -- Verify input type and schema
    local isValid, result = InputVerifier.verify(inputDef, inputValue, self.variables, validateVC)
    if not isValid then
        return false, result
    end

    -- Update variables with the verified values
    if type(result) == "table" then
        for id, value in pairs(result) do
            if self.variables:isVariable(id) then
                self.variables:setVariable(id, value)
            end
        end
    end

    -- Process transitions from current state
    for _, transition in ipairs(self.transitions) do
        if transition.from == self.currentState.id then
            -- Note, because we previously validated the input, we can just check if the inputId is in the transition.conditions.inputs
            if self:areTransitionConditionsMet(transition, inputId) then
                -- Store the input and update state
                self.received[inputId] = inputValue
                self.currentState = self.states[transition.to]
                
                -- Check if we've reached a terminal state
                if not self:hasOutgoingTransitions(self.currentState.id) then
                    self.complete = true
                end
                return true, "Transition successful"
            end
        end
    end

    return false, "No valid transition found"
end

-- validate input values against schema
function DFSM:validateInputValues(inputDef, values)
    if not inputDef.data then
        return true, nil
    end

    -- Handle object data structure
    if type(inputDef.data) == "table" then
        for fieldId, field in pairs(inputDef.data) do
            -- If field is a variable reference (like in partyAData/partyBData)
            if type(field) ~= "table" then
                local isValid, errorMsg = self:validateField({id = fieldId}, field)
                if not isValid then
                    return false, errorMsg
                end
            else
                -- If field is a field definition (like in accepted/rejected)
                local isValid, errorMsg = self:validateField(field, values[fieldId])
                if not isValid then
                    return false, errorMsg
                end
            end
        end
    else
        error("Input data must be an object")
    end

    return true, nil
end

-- Get the current state ID
function DFSM:getCurrentStateId()
    return self.currentState.id
end

-- Get the current state object
function DFSM:getCurrentState()
    return self.currentState
end

-- Get details for a specific state
function DFSM:getStateDetails(stateId)
    return self.states[stateId]
end

-- Get all states
function DFSM:getAllStates()
    return self.states
end

-- Check if the state machine is complete
function DFSM:isComplete()
    return self.complete
end

-- Get all received inputs
function DFSM:getReceivedInputs()
    return self.received
end

-- Get a variable value
function DFSM:getVariable(name)
    return self.variables:getVariable(name)
end

-- Set a variable value
function DFSM:setVariable(name, value)
    self.variables:setVariable(name, value)
end

-- Get all variables
function DFSM:getVariables()
    return self.variables:getAllVariables()
end

-- Get input definition by ID
function DFSM:getInput(inputId)
    return self.inputs[inputId]
end

-- Get all inputs
function DFSM:getInputs()
    return self.inputs
end

-- Export the DFSM module

  __loaded["src/dfsm"] = {
    new = DFSM.new,
}
  return __loaded["src/dfsm"]
end
-- End module: src/dfsm.lua

-- Custom require function
local function __require(moduleName)
  return __modules[moduleName]()
end

-- Main actor file: src/apoc-v2.lua


local json = require("json")
local Array = require(".crypto.util.array")
local crypto = require(".crypto.init")
local utils = require(".utils")

local DFSM = __modules["src/dfsm"]()


-- BEGIN: actor's internal state
StateMachine = StateMachine or nil
Document = Document or nil
DocumentHash = DocumentHash or nil
DocumentOwner = DocumentOwner or nil
-- END: actor's internal state

local function reply_error(msg, error)
  msg.reply(
  {
    Data = {
      success = false,
      error = error
    }
  })
  print("Error during execution: " .. error)
  -- throwing errors seems to somehow get in the way of msg.reply going through, even though it happens strictly after...
  -- error(error_msg)
end

Handlers.add(
  "Init",
  Handlers.utils.hasMatchingTag("Action", "Init"),
  function (msg)
    -- expecting msg.Data to contain a valid agreement VC
    local document = msg.Data

    if Document then
      reply_error(msg, 'Document is already initialized and cannot be overwritten')
      return
    end
    
    local dfsm = DFSM.new(document, true)

    if not dfsm then
      reply_error(msg, 'Invalid agreement document')
      return
    end

    Document = document
    DocumentHash = crypto.digest.keccak256(document).asHex()
    StateMachine = dfsm
    -- DocumentOwner = owner_eth_address

    -- -- TODO: validate the signatories list is a valid list of eth addresses?
    -- local signatories = vc_json.credentialSubject.signatories or {}
    -- if #signatories == 0 then
    -- reply_error(msg, 'Must have at least one signatory specified')
    -- return
    -- end

    -- -- forcing lowercase on the received eth addresses to avoid comparison confusion down the road
    -- local sigs_lowercase = utils.map(function(x) return string.lower(x) end)(signatories)
    -- Signatories = sigs_lowercase

    -- -- print("Agreement VC verification result: " .. (is_valid and "VALID" or "INVALID"))

    msg.reply({ Data = { success = true } })
  end
)

Handlers.add(
  "ProcessInput",
  Handlers.utils.hasMatchingTag("Action", "ProcessInput"),
  function (msg)
    local Data = json.decode(msg.Data)

    local inputId = Data.inputId
    local inputValue = Data.inputValue
    
    if not StateMachine then
      reply_error(msg, 'State machine not initialized')
      return
    end
    
    local isValid, errorMsg = StateMachine:processInput(inputId, inputValue, true)
    
    if not isValid then
      reply_error(msg, errorMsg or 'Failed to process input')
      return
    end
    
    msg.reply({ Data = { success = true } })
  end
)

Handlers.add(
  "GetDocument",
  Handlers.utils.hasMatchingTag("Action", "GetDocument"),
  function (msg)
    msg.reply({ Data = {
        Document = Document,
        DocumentHash = DocumentHash,
        -- DocumentOwner = DocumentOwner,
    }})
  end
)

-- Debug util to retrieve the important local state fields
Handlers.add(
  "GetState",
  Handlers.utils.hasMatchingTag("Action", "GetState"),
  function (msg)
    if not StateMachine then
      reply_error(msg, 'State machine not initialized')
      return
    end

    local state = {
      State = StateMachine:getCurrentState(),
      IsComplete = StateMachine:isComplete(),
      Variables = StateMachine:getVariables(),
      Inputs = StateMachine:getInputs(),
    }
    -- print(state)
    msg.reply({ Data = state })
  end
)

return Handlers