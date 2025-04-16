local json = require("json")
local crypto = require("crypto")

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
    validateField = function(field, value)
        if not field.validation then
            return true
        end

        -- Check required field
        if field.validation.required and (value == nil or value == "") then
            return false, string.format("Field %s is required", field.name or field.id)
        end

        -- Skip validation if value is nil and not required
        if not value then
            return true
        end

        -- Validate type
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

        -- Optional: Check min length for strings
        if field.validation.minLength and type(value) == "string" and #value < field.validation.minLength then
            return false, string.format("Field %s must be at least %d characters", field.name or field.id, field.validation.minLength)
        end

        -- Optional: Check pattern for strings
        if field.validation.pattern and type(value) == "string" then
            local pattern = field.validation.pattern:gsub("\\/", "/")
            if not string.match(value, pattern) then
                return false, string.format("Field %s: %s", field.name or field.id, field.validation.message or "Invalid format")
            end
        end

        -- Optional: Check min value for numbers
        if field.validation.min and type(value) == "number" and value < field.validation.min then
            return false, string.format("Field %s must be at least %s", field.name or field.id, tostring(field.validation.min))
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

function EIP712Verifier:verify(input, value, variables)
    -- Parse the input value
    local vcJson
    if type(value) == "string" then
        vcJson = json.decode(value)
    else
        vcJson = value
    end

    -- Validate credential subject structure
    if not vcJson.credentialSubject then
        return false, "Missing credentialSubject in input"
    end

    local credentialSubject = vcJson.credentialSubject
    if not credentialSubject.values then
        return false, "Missing values in credentialSubject"
    end

    -- Validate fields against input definition
    for fieldId, fieldDef in pairs(input.data) do
        local fieldValue = credentialSubject.values[fieldId]
        
        -- If the value is a string, try to resolve it as a variable
        if type(fieldValue) == "string" and variables then
            local resolvedValue = variables:tryResolveExactStringAsVariableObject(fieldValue)
            if resolvedValue then
                fieldValue = resolvedValue
            end
        end

        -- Validate the field using shared validation
        local isValid, errorMsg = ValidationUtils.validateField(fieldDef, fieldValue)
        if not isValid then
            return false, errorMsg
        end
    end

    -- Validate issuer if specified
    if input.issuer then
        local expectedIssuer = input.issuer
        if variables then
            local resolvedIssuer = variables:tryResolveExactStringAsVariableObject(expectedIssuer)
            if resolvedIssuer then
                expectedIssuer = resolvedIssuer
            end
        end
        
        if expectedIssuer and vcJson.issuer ~= expectedIssuer then
            return false, string.format("Issuer mismatch: expected %s, got %s", expectedIssuer, vcJson.issuer)
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
local function verify(input, value, variables)
    if not input then
        return false, "Input definition is nil"
    end

    local verifier, error = getVerifier(input.type)
    if not verifier then
        return false, error
    end

    return verifier:verify(input, value, variables)
end

return {
    verify = verify,
    ValidationUtils = ValidationUtils,
} 