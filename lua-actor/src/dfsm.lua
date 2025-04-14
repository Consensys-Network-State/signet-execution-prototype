-- DFSM (Deterministic Finite State Machine) implementation
local VariableManager = require("variables.variable_manager")
local InputVerifier = require("verifiers.input_verifier")
local TableUtils = require("utils.table_utils")
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
                end
            else
                -- Object format
                for id, input in pairs(agreement.execution.inputs) do
                    input.id = id -- Ensure id is set from the key
                    self.inputs[id] = input
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

    -- Get input definition
    local inputDef = self.inputs[inputId]
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
    return self.inputs[inputId]
end

-- Get all inputs
function DFSM:getInputs()
    return self.inputs
end

-- Export the DFSM module
return {
    new = DFSM.new,
}


