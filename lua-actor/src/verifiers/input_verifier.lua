local json = require("json")
local crypto = require("crypto")
local VcValidator = require("vc-validator")
local FieldValidator = require("variables.validation")
local verifyEVMTransactionInputVerifier = require("verifiers.evm_transaction_input_verifier")

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
local ValidationUtils = {}

-- Helper function for address equality
ValidationUtils.ethAddressEqual = function (address1, address2)
    return string.lower(address1) == string.lower(address2)
end

-- Variable validation function
ValidationUtils.validateVariable = function(varDef, value)
    if varDef == nil then
        return false, "Variable definition is missing"
    end

    -- Validate type first (specific to InputVerifier)
    if varDef.type == "string" and type(value) ~= "string" then
        return false, string.format("Variable %s must be a string", varDef.name or varDef.id)
    elseif varDef.type == "address" then
        -- Basic format validation
        if not string.match(value, ETHEREUM_ADDRESS_REGEX) then
            return false, string.format("Variable %s must be a valid Ethereum address format", varDef.name or varDef.id)
        end
        
        -- Checksum validation
        if not validateEthAddressChecksum(value) then
            return false, string.format("Variable %s must be a valid Ethereum address with correct checksum", varDef.name or varDef.id)
        end
        
        print("Address validation passed")
    elseif varDef.type == "number" and type(value) ~= "number" then
        return false, string.format("Variable %s must be a number", varDef.name or varDef.id)
    end

    -- Use shared validation for common validations, if validation is defined
    if varDef.validation then
        local varName = varDef.name or varDef.id
        local isValid, errorMsg = FieldValidator.validateValue(value, varDef.validation, varName)
        if not isValid then
        return false, errorMsg
        end
    end

    return true
end

-- Process variable definitions from input data and resolve variables
ValidationUtils.processVariableDefinitions = function(varDefs, variables)
    local processedDefs = {}
    for varId, varDef in pairs(varDefs) do
        -- If the value is a string, try to resolve it as a variable
        local processedDef = varDef
        if type(varDef) == "string" and variables then
            local resolvedValue = variables:tryResolveExactStringAsVariableObject(varDef)
            if resolvedValue then
                processedDef = resolvedValue
            end
        end
        processedDefs[varId] = processedDef
    end
    return processedDefs
end

-- Validate values against processed variable definitions
ValidationUtils.validateVariableValues = function(varDefs, values)
    for varId, varDef in pairs(varDefs) do
        local varValue = values[varId]
        
        -- Check if the variable exists in values
        if varValue == nil then
            return false, string.format("Required variable '%s' is missing", varId)
        end
        
        -- Validate the variable using shared validation
        local isValid, errorMsg = ValidationUtils.validateVariable(varDef, varValue)
        if not isValid then
            return false, errorMsg
        end
    end
    return true
end

-- Process variable definitions and validate values in one step
ValidationUtils.processAndValidateVariables = function(varDefs, values, variables)
    -- Step 1: Process variable definitions
    local processedDefs = ValidationUtils.processVariableDefinitions(varDefs, variables)
    
    -- Step 2: Validate values against variable definitions
    return ValidationUtils.validateVariableValues(processedDefs, values)
end

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

function EIP712Verifier:verify(input, value, dfsm, validate)
    local variables, documentHash = dfsm.variables, dfsm.documentHash
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

    -- check that the input VC is targetting the right agreement
    local function normalizeHex(hex)
        if type(hex) ~= "string" then return hex end
        return hex:lower():gsub("^0x", "")
    end
    if normalizeHex(vcJson.credentialSubject.documentHash) ~= normalizeHex(documentHash) then
        return false, "Input VC is targeting the wrong agreement"
    end

    -- Validate variable values against variable definitions
    local isValid, errorMsg = ValidationUtils.processAndValidateVariables(input.data, credentialSubject.values, variables)
    if not isValid then
        return false, errorMsg
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

function EVMTransactionVerifier:verify(input, value, dfsm, expectVc)
  -- TODO: since we expect the Tx proof to be supplied as a VC, first validate this input as a VC
  local tableVale = value
  if type(value) == "string" then
    tableVale = json.decode(value);
  end
  return verifyEVMTransactionInputVerifier(input, tableVale, dfsm.variables, dfsm.contracts, expectVc)
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
local function verify(input, value, dfsm, validate)
    if not input then
        return false, "Input definition is nil"
    end

    local verifier, error = getVerifier(input.type)
    if not verifier then
        return false, error
    end

    return verifier:verify(input, value, dfsm, validate)
end

return {
    verify = verify,
    ValidationUtils = ValidationUtils,
} 