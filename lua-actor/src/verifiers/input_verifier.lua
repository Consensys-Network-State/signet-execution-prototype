local InputVerifier = {}
local TestUtils = require("test-utils")
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

-- Default verifiers
local defaultVerifiers = {
    VerifiedCredentialEIP712 = function(input, value)
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

        -- Validate fields against input definition
        for _, fieldDef in ipairs(input.data) do
            local fieldValue = nil
            
            -- Find the field value in the credential subject
            if credentialSubject.fields then
                for _, field in ipairs(credentialSubject.fields) do
                    if field.id == fieldDef.id then
                        fieldValue = field.value
                        break
                    end
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
            if expectedIssuer:match("^%${.*}$") then
                -- If issuer is a variable reference, get the value
                local varName = expectedIssuer:match("^%${(.*)}$")
                expectedIssuer = credentialSubject.fields and credentialSubject.fields[varName] or nil
            end
            
            if expectedIssuer and credentialSubject.issuer ~= expectedIssuer then
                return false, string.format("Issuer mismatch: expected %s, got %s", expectedIssuer, credentialSubject.issuer)
            end
        end

        return true
    end,
    
    EVMTransaction = function(input, value)
        -- TODO: Implement actual EVM transaction verification
        return true
    end
}

function InputVerifier.new(customVerifiers)
    local self = {
        verifiers = {}
    }

    -- Merge default verifiers with custom ones
    for k, v in pairs(defaultVerifiers) do
        self.verifiers[k] = v
    end
    if customVerifiers then
        for k, v in pairs(customVerifiers) do
            self.verifiers[k] = v
        end
    end

    setmetatable(self, { __index = InputVerifier })
    return self
end

function InputVerifier:verify(input, value)
    print("VICTOR TEST", input);

    if not input then
        return false, "Input definition is nil"
    end

    if not input.type then
        return false, "Input type is missing"
    end

    local verifier = self.verifiers[input.type]
    if not verifier then
        return false, string.format("Unsupported input type: %s", input.type)
    end

    local isValid, errorMsg = verifier(input, value)
    if not isValid then
        return false, string.format("Input validation failed: %s", errorMsg)
    end

    return true, nil
end

return {
    InputVerifier = InputVerifier,
    ValidationUtils = ValidationUtils
} 