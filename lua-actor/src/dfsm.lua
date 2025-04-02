-- DFSM (Deterministic Finite State Machine) implementation
local DFSM = {}

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
function DFSM.new(definition)
    -- Handle both direct data and nested execution.data structure
    local data = definition.execution and definition.execution.data or definition
    local variables = definition.variables or {}

    -- Create a variables table with getters and setters
    local variablesTable = {}
    for _, var in ipairs(variables) do
        variablesTable[var.id] = {
            value = var.value,
            type = var.type,
            name = var.name,
            description = var.description,
            validation = var.validation,
            -- Getter
            get = function(self)
                return self.value
            end,
            -- Setter with validation
            set = function(self, newValue)
                if self.validation then
                    -- Check required
                    if self.validation.required and (newValue == nil or newValue == "") then
                        error(string.format("Variable %s is required", self.name))
                    end

                    -- Check min length for strings
                    if self.validation.minLength and type(newValue) == "string" and #newValue < self.validation.minLength then
                        error(string.format("Variable %s must be at least %d characters", self.name, self.validation.minLength))
                    end

                    -- Check pattern for strings
                    if self.validation.pattern and type(newValue) == "string" then
                        local pattern = self.validation.pattern:gsub("\\/", "/")
                        if not string.match(newValue, pattern) then
                            error(string.format("Variable %s: %s", self.name, self.validation.message or "Invalid format"))
                        end
                    end

                    -- Check min value for numbers
                    if self.validation.min and type(newValue) == "number" and newValue < self.validation.min then
                        error(string.format("Variable %s must be at least %s", self.name, tostring(self.validation.min)))
                    end
                end
                self.value = newValue
            end
        }
    end

    local self = {
        states = data.states or {},
        inputs = data.inputs or {},
        transitions = data.transitions or {},
        currentState = data.states[1], -- Start with first state
        receivedInputs = {},
        isComplete = false,
        variables = variablesTable
    }

    -- Set up metatable first
    setmetatable(self, { __index = DFSM })

    -- Now we can validate since self has access to DFSM methods
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

        -- Validate input type
        if not inputVerifiers[input.type] then
            error(string.format("Unsupported input type: %s", input.type))
        end
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

    -- Verify input using appropriate handler
    local verifier = inputVerifiers[inputDef.type]
    if not verifier then
        return false, string.format("Unsupported input type: %s", inputDef.type)
    end

    -- Verify input validity (not specific contents)
    local isValid, errorMsg = verifier(inputDef, inputValue)
    if not isValid then
        return false, string.format("Input validation failed: %s", errorMsg)
    end

    -- Check all transitions from current state
    for _, transition in ipairs(self.transitions) do
        if transition.from == self.currentState then
            -- Check if all conditions for this transition are met
            local canTransition = true
            for _, condition in ipairs(transition.conditions) do
                if condition.type == "isValid" then
                    -- Check if all required inputs are present and match the specified values
                    for _, requiredInput in ipairs(condition.inputs) do
                        -- Replace variable references in the required input value
                        local processedRequiredInput = replaceVariableReferences(inputDef.value, self.variables)

                        -- Compare the processed required input with the received input's data
                        if not deepCompare(processedRequiredInput, inputValue) then
                            canTransition = false
                            break
                        end
                    end

                end
                if not canTransition then
                    break
                end
            end

            -- If all conditions are met, perform the transition
            if canTransition then
                -- Store the input only if transition is successful
                self.receivedInputs[inputId] = inputValue
                
                self.currentState = transition.to
                -- Check if we've reached a terminal state (no outgoing transitions)
                local hasOutgoingTransitions = false
                for _, t in ipairs(self.transitions) do
                    if t.from == self.currentState then
                        hasOutgoingTransitions = true
                        break
                    end
                end
                if not hasOutgoingTransitions then
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
    local var = self.variables[name]
    if not var then
        error(string.format("Variable not found: %s", name))
    end
    return var:get()
end

-- Set a variable value
function DFSM:setVariable(name, value)
    local var = self.variables[name]
    if not var then
        error(string.format("Variable not found: %s", name))
    end
    var:set(value)
end

-- Get all variables
function DFSM:getVariables()
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

-- Export the DFSM module
return {
    new = DFSM.new,
}


