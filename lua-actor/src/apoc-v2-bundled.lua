-- Module definitions
local __modules = {}
local __loaded = {}

-- Begin module: src/variables/variable_manager.lua
__modules["src/variables/variable_manager"] = function()
  if __loaded["src/variables/variable_manager"] then return __loaded["src/variables/variable_manager"] end
  local module = {}
  __loaded["src/variables/variable_manager"] = module

local VariableManager = {}

function VariableManager.new(variables)
    local self = {
        variables = {}
    }

    -- Handle both array and object formats
    if type(variables) == "table" then
        if #variables > 0 then
            -- Array format
            for _, var in ipairs(variables) do
                self.variables[var.id] = {
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
                            if self.validation.required and (newValue == nil or newValue == "") then
                                error(string.format("Variable %s is required", self.name))
                            end

                            if self.validation.minLength and type(newValue) == "string" and #newValue < self.validation.minLength then
                                error(string.format("Variable %s must be at least %d characters", self.name, self.validation.minLength))
                            end

                            if self.validation.pattern and type(newValue) == "string" then
                                local pattern = self.validation.pattern:gsub("\\/", "/")
                                if not string.match(newValue, pattern) then
                                    error(string.format("Variable %s: %s", self.name, self.validation.message or "Invalid format"))
                                end
                            end

                            if self.validation.min and type(newValue) == "number" and newValue < self.validation.min then
                                error(string.format("Variable %s must be at least %s", self.name, tostring(self.validation.min)))
                            end
                        end
                        self.value = newValue
                    end
                }
            end
        else
            -- Object format
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
                            if self.validation.required and (newValue == nil or newValue == "") then
                                error(string.format("Variable %s is required", self.name))
                            end

                            if self.validation.minLength and type(newValue) == "string" and #newValue < self.validation.minLength then
                                error(string.format("Variable %s must be at least %d characters", self.name, self.validation.minLength))
                            end

                            if self.validation.pattern and type(newValue) == "string" then
                                local pattern = self.validation.pattern:gsub("\\/", "/")
                                if not string.match(newValue, pattern) then
                                    error(string.format("Variable %s: %s", self.name, self.validation.message or "Invalid format"))
                                end
                            end

                            if self.validation.min and type(newValue) == "number" and newValue < self.validation.min then
                                error(string.format("Variable %s must be at least %s", self.name, tostring(self.validation.min)))
                            end
                        end
                        self.value = newValue
                    end
                }
            end
        end
    end

    setmetatable(self, { __index = VariableManager })
    return self
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

  module = VariableManager
  return module
end
-- End module: src/variables/variable_manager.lua

-- Begin module: src/test-utils.lua
__modules["src/test-utils"] = function()
  if __loaded["src/test-utils"] then return __loaded["src/test-utils"] end
  local module = {}
  __loaded["src/test-utils"] = module

-- Utility functions for testing Lua AO Actors

-- Print a table recursively with nice formatting
local function printTable(t, indent)
  indent = indent or ""
  for k, v in pairs(t) do
    if type(v) == "table" then
      print(indent .. tostring(k) .. " = {")
      printTable(v, indent .. "  ")
      print(indent .. "}")
    else
      print(indent .. tostring(k) .. " = " .. tostring(v))
    end
  end
end

-- Compare two tables recursively by value
local function tablesEqual(t1, t2)
  -- If either isn't a table, compare directly
  if type(t1) ~= "table" or type(t2) ~= "table" then
    return t1 == t2
  end
  
  -- Check if all keys in t1 exist with same value in t2
  for k, v in pairs(t1) do
    if not tablesEqual(v, t2[k]) then
      return false
    end
  end
  
  -- Check if all keys in t2 exist in t1 (to catch extra keys in t2)
  for k in pairs(t2) do
    if t1[k] == nil then
      return false
    end
  end
  
  return true
end

-- Format boolean test results with colored output
local function formatResult(bool)
  if bool then
    return '\x1b[6;30;42m'..'SUCCESS'..'\x1b[0m'
  else
    return '\x1b[0;30;41m'..'FAILURE'..'\x1b[0m'
  end
end

-- Export the utility functions
return {
  printTable = printTable,
  tablesEqual = tablesEqual,
  formatResult = formatResult
}

end
-- End module: src/test-utils.lua

-- Begin module: src/verifiers/input_verifier.lua
__modules["src/verifiers/input_verifier"] = function()
  if __loaded["src/verifiers/input_verifier"] then return __loaded["src/verifiers/input_verifier"] end
  local module = {}
  __loaded["src/verifiers/input_verifier"] = module

local InputVerifier = {}
local TestUtils = __modules["src/test-utils"]()
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
} end
-- End module: src/verifiers/input_verifier.lua

-- Begin module: src/utils/table_utils.lua
__modules["src/utils/table_utils"] = function()
  if __loaded["src/utils/table_utils"] then return __loaded["src/utils/table_utils"] end
  local module = {}
  __loaded["src/utils/table_utils"] = module

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
} end
-- End module: src/utils/table_utils.lua

-- Begin module: src/dfsm.lua
__modules["src/dfsm"] = function()
  if __loaded["src/dfsm"] then return __loaded["src/dfsm"] end
  local module = {}
  __loaded["src/dfsm"] = module

-- DFSM (Deterministic Finite State Machine) implementation
local VariableManager = __modules["src/variables/variable_manager"]()
local InputVerifier = __modules["src/verifiers/input_verifier"]()
local TableUtils = __modules["src/utils/table_utils"]()
local json = require("json")

-- Input verifier handlers
local inputVerifiers = {
    -- Verifies EIP712 signed credentials
    VerifiedCredentialEIP712 = function(input, value)
        -- TODO: Implement actual EIP712 verification
        return true
    end,
    
    -- Verifies EVM transactions
    EVMTransaction = function(input, value)
        -- TODO: Implement actual EVM transaction verification
        return true
    end
}

-- Helper function to process VC wrapper
local function processVCWrapper(vc, expectedIssuer, validateVC)
    -- validate by default
    validateVC = validateVC == nil and true or validateVC
    local vcJson = json.decode(vc)
    if validateVC then
        local issuer = vcJson.credentialSubject.issuer
        if expectedIssuer then
            assert(issuer == expectedIssuer, "Issuer mismatch")
        end
        -- Vlad-Todo: add VC validation here
        return vcJson.credentialSubject
    else
        return vcJson.credentialSubject or vcJson
    end
end

-- Helper function to validate input values against schema
local function validateInputValues(inputDef, values)
    if not inputDef.data then
        return true, nil
    end

    for _, field in ipairs(inputDef.data) do
        local value = values[field.id]
        
        -- Check required fields
        if field.validation and field.validation.required and not value then
            return false, string.format("Missing required field: %s", field.id)
        end

        -- Skip validation if value is nil and not required
        if not value then
            goto continue
        end

        -- Validate pattern if specified
        if field.validation and field.validation.pattern then
            local pattern = field.validation.pattern
            if not string.match(value, pattern) then
                return false, string.format("Field %s does not match pattern: %s", field.id, pattern)
            end
        end

        -- Validate type
        if field.type == "string" and type(value) ~= "string" then
            return false, string.format("Field %s must be a string", field.id)
        elseif field.type == "address" and not string.match(value, "^0x[a-fA-F0-9]{40}$") then
            return false, string.format("Field %s must be a valid Ethereum address", field.id)
        end

        ::continue::
    end

    return true, nil
end

-- Helper function to check if a transition's conditions are met
local function areTransitionConditionsMet(transition, inputDef, inputValue, variables)
    for _, condition in ipairs(transition.conditions) do
        if condition.type == "isValid" then
            for _, requiredInput in ipairs(condition.inputs) do
                if requiredInput == inputDef.id then
                    return true
                end
            end
        end
    end
    return #transition.conditions == 0
end

-- Helper function to check if a state has outgoing transitions
local function hasOutgoingTransitions(state, transitions)
    for _, t in ipairs(transitions) do
        if t.from == state then
            return true
        end
    end
    return false
end

-- DFSM class definition
local DFSM = {}

-- Initialize a new DFSM instance from a JSON definition
function DFSM.new(doc, debug, initial)
    local self = {
        state = nil,
        inputs = {},
        inputMap = {},
        transitions = {},
        variables = nil,
        received = {},
        complete = false,
        debug = debug or false,
        inputVerifier = InputVerifier.InputVerifier.new(inputVerifiers)
    }

    -- Parse agreement document
    local agreement = json.decode(doc)

    -- Initialize variables
    self.variables = VariableManager.new(agreement.variables)

    -- Set initial values if provided
    if initial then
        for id, value in pairs(initial) do
            self.variables:setVariable(id, value)
        end
    end

    -- Validate and set initial state
    if not agreement.execution or not agreement.execution.states or #agreement.execution.states == 0 then
        error("Agreement document must have at least one state")
    end

    -- Create valid states lookup
    local states = {}
    for _, state in ipairs(agreement.execution.states) do
        states[state] = true
    end

    -- Set initial state (first state in the list)
    self.state = agreement.execution.states[1]

    -- Process inputs
    if agreement.execution.inputs then
        if type(agreement.execution.inputs) == "table" then
            if #agreement.execution.inputs > 0 then
                -- Array format
                for _, input in ipairs(agreement.execution.inputs) do
                    if not input.id then
                        error("Input must have an id")
                    end
                    self.inputs[input.id] = input
                    self.inputMap[input.id] = input
                end
            else
                -- Object format
                for id, input in pairs(agreement.execution.inputs) do
                    input.id = id -- Ensure id is set from the key
                    self.inputs[id] = input
                    self.inputMap[id] = input
                end
            end
        end
    end

    -- Process transitions
    if agreement.execution.transitions then
        for _, transition in ipairs(agreement.execution.transitions) do
            if not states[transition.from] then
                error(string.format("Invalid 'from' state in transition: %s", transition.from))
            end
            if not states[transition.to] then
                error(string.format("Invalid 'to' state in transition: %s", transition.to))
            end
            table.insert(self.transitions, transition)
        end
    end

    setmetatable(self, { __index = DFSM })
    return self
end

-- Validate the state machine definition
function DFSM:validate()
    -- Check that we have at least one state
    if #self.states == 0 then
        error("DFSM must have at least one state")
    end

    -- Check that all states referenced in transitions exist
    local validStates = {}
    for _, state in ipairs(self.states) do
        validStates[state] = true
    end

    for _, transition in ipairs(self.transitions) do
        if not validStates[transition.from] then
            error(string.format("Invalid 'from' state in transition: %s", transition.from))
        end
        if not validStates[transition.to] then
            error(string.format("Invalid 'to' state in transition: %s", transition.to))
        end
    end

    -- Check that all inputs referenced in conditions exist
    local validInputs = {}
    for _, input in ipairs(self.inputs) do
        validInputs[input.id] = true
    end

    for _, transition in ipairs(self.transitions) do
        for _, condition in ipairs(transition.conditions) do
            if condition.type == "isValid" then
                for _, inputId in ipairs(condition.inputs) do
                    if not validInputs[inputId] then
                        error(string.format("Invalid input referenced in condition: %s", inputId))
                    end
                end
            end
        end
    end

    -- Validate input schemas
    for _, input in ipairs(self.inputs) do
        if not input.type then
            error(string.format("Input %s missing type", input.id))
        end
        if not input.schema then
            error(string.format("Input %s missing schema", input.id))
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

    -- Get input definition from map
    local inputDef = self.inputMap[inputId]
    if not inputDef then
        return false, string.format("Unknown input: %s", inputId)
    end

    -- Assume all inputs are VC-wrapped
    local vc = processVCWrapper(inputValue, inputDef.issuer, validateVC);

    -- Verify input type and schema
    local isValid, errorMsg = self.inputVerifier:verify(inputDef, inputValue)
    if not isValid then
        return false, errorMsg
    end

    -- Validate input values against schema
    local values = vc.values or {}
    isValid, errorMsg = validateInputValues(inputDef, values)
    if not isValid then
        return false, errorMsg
    end

    -- Process transitions from current state
    for _, transition in ipairs(self.transitions) do
        if transition.from == self.state then
            if areTransitionConditionsMet(transition, inputDef, inputValue, self.variables) then
                -- Store the input and update state
                self.received[inputId] = inputValue
                self.state = transition.to
                
                -- Check if we've reached a terminal state
                if not hasOutgoingTransitions(self.state, self.transitions) then
                    self.complete = true
                end
                return true, "Transition successful"
            end
        end
    end

    return false, "No valid transition found"
end

-- Get the current state
function DFSM:getCurrentState()
    return self.state
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
    return self.inputMap[inputId]
end

-- Get all inputs
function DFSM:getInputs()
    return self.inputs
end

-- Export the DFSM module
return {
    new = DFSM.new,
}


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
    local document = msg.Data.document
    local initialValues = msg.Data.initialValues

    if Document then
      reply_error(msg, 'Document is already initialized and cannot be overwritten')
      return
    end
    
    local dfsm = DFSM.new(document, false, initialValues)

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
    local inputId = msg.Data.inputId
    local inputValue = msg.Data.inputValue
    
    if not StateMachine then
      reply_error(msg, 'State machine not initialized')
      return
    end
    
    local isValid, errorMsg = StateMachine:processInput(inputId, inputValue, false)
    
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