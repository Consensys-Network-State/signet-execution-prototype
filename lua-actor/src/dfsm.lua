-- DFSM (Deterministic Finite State Machine) implementation
local VariableManager = require("variables.variable_manager")
local InputVerifier = require("verifiers.input_verifier")
local json = require("json")
local VcValidator = require("vc-validator")
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

-- Helper function to validate initialParams against initialValues
function DFSM:validateInitialParams(stateId, initialParams, initialValues)
    if not initialParams or type(initialParams) ~= "table" then
        return true
    end
    
    if not initialValues then
        error("Initial state " .. stateId .. " requires parameters, but no initial values provided")
    end
    
    -- Validate the variable values against variable definitions
    local isValid, errorMsg = ValidationUtils.processAndValidateVariables(initialParams, initialValues, self.variables)
    if not isValid then
        error("Invalid parameter value for state " .. stateId .. ": " .. errorMsg)
    end
    
    return true
end

-- Initialize a new DFSM instance from a JSON definition
function DFSM.new(doc, expectVCWrapper, params)
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
        agreement = json.decode(doc)
        initialValues = params
    end

    -- Initialize variables
    self.variables = VariableManager.new(agreement.variables)

    -- Set initial values if provided
    if initialValues then
        for id, value in pairs(initialValues) do
            if self.variables:isVariable(id) then
                local success, err = pcall(function() self.variables:setVariable(id, value) end)
                if not success then
                    error(string.format("Error setting variable '%s' to '%s': %s", id, tostring(value), err))
                end
            else
                error(string.format("Attempted to set undeclared variable: %s", id))
            end
        end
    end

    -- Set metatable early so methods can be called
    setmetatable(self, { __index = DFSM })

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
            isInitial = stateObj.isInitial or false,
            initialParams = stateObj.initialParams or {}
        }
        
        -- Track initial state
        if stateObj.isInitial then
            if initialStateId then
                error("Multiple initial states found: " .. initialStateId .. " and " .. stateId)
            end
            initialStateId = stateId
            
            -- Check that all required parameters are provided in initialValues
            self:validateInitialParams(stateId, stateObj.initialParams, initialValues)
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
return {
    new = DFSM.new,
}


