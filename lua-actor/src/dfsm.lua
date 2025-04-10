-- DFSM (Deterministic Finite State Machine) implementation
local VariableManager = require("variables.variable_manager")
local InputVerifier = require("verifiers.input_verifier")
local TableUtils = require("utils.table_utils")

local DFSM = {}

-- Helper function to replace variable references with their values
local replaceVariableReferences = TableUtils.replaceVariableReferences

-- Input verifier handlers
local inputVerifiers = {
    -- Verifies EIP712 signed credentials
    VerifiedCredentialEIP712 = function(input, value)
        -- TODO: Implement actual EIP712 verification
        -- 
        return true
    end,
    
    -- Verifies EVM transactions
    EVMTransaction = function(input, value)
        -- TODO: Implement actual EVM transaction verification
        return true
    end
}

-- Initialize a new DFSM instance from a JSON definition
function DFSM.new(definition, customVerifiers)
    -- Handle both direct data and nested execution.data structure
    local data = definition.execution and definition.execution.data or definition
    local variables = definition.variables or {}

    local self = {
        states = data.states or {},
        inputs = data.inputs or {},
        transitions = data.transitions or {},
        currentState = data.states[1], -- Start with first state
        receivedInputs = {},
        isComplete = false,
        variableManager = VariableManager.new(variables),
        inputVerifier = InputVerifier.new(customVerifiers)
    }

    setmetatable(self, { __index = DFSM })
    self:validate()
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
    for inputId, input in pairs(self.inputs) do
        validInputs[inputId] = true
    end

    for _, transition in ipairs(self.transitions) do
        for _, condition in ipairs(transition.conditions) do
            for _, inputId in ipairs(condition.inputs) do
                if not validInputs[inputId] then
                    error(string.format("Invalid input referenced in condition: %s", inputId))
                end
            end
        end
    end
end

-- Helper function to check if a transition's conditions are met
local function areTransitionConditionsMet(transition, inputDef, inputValue, variables)
    if inputDef.type == "EVMTransaction" then
        -- TODO: check if the transaction actually does what it's should given the input definiton
        return true
    else
        for _, condition in ipairs(transition.conditions) do
            if condition.type == "isValid" then
                for _, requiredInput in ipairs(condition.inputs) do
                    local processedRequiredInput = replaceVariableReferences(inputDef.value, variables)
                    if not TableUtils.deepCompare(processedRequiredInput, inputValue) then
                        return false
                    end
                end
            end
        end
    end
    return true
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

-- Process an input and attempt to transition states
function DFSM:processInput(inputId, inputValue)
    if self.isComplete then
        return false, "State machine is complete"
    end

    -- Check if input has already been processed
    if self.receivedInputs[inputId] then
        return false, string.format("Input %s has already been processed", inputId)
    end

    -- Get input definition
    local inputDef = self.inputs[inputId]
    if not inputDef then
        return false, string.format("Unknown input: %s", inputId)
    end

    -- Verify input
    local isValid, errorMsg, augmentedInputValue = self.inputVerifier:verify(inputDef.type, inputDef, inputValue)
    if not isValid then
        return false, errorMsg
    end

    inputValue = augmentedInputValue or inputValue

    -- Process transitions from current state
    for _, transition in ipairs(self.transitions) do
        if transition.from == self.currentState then
            if areTransitionConditionsMet(transition, inputDef, inputValue, self.variableManager) then
                -- Store the input and update state
                self.receivedInputs[inputId] = inputValue
                self.currentState = transition.to
                
                -- Check if we've reached a terminal state
                if not hasOutgoingTransitions(self.currentState, self.transitions) then
                    self.isComplete = true
                end
                return true, "Transition successful"
            end
        end
    end

    return false, "No valid transition found"
end

-- Get the current state
function DFSM:getCurrentState()
    return self.currentState
end

-- Check if the state machine is complete
function DFSM:isComplete()
    return self.isComplete
end

-- Get all received inputs
function DFSM:getReceivedInputs()
    return self.receivedInputs
end

-- Get a variable value
function DFSM:getVariable(name)
    return self.variableManager:getVariable(name)
end

-- Set a variable value
function DFSM:setVariable(name, value)
    self.variableManager:setVariable(name, value)
end

-- Get all variables
function DFSM:getVariables()
    return self.variableManager:getAllVariables()
end

-- Export the DFSM module
return {
    new = DFSM.new,
}


