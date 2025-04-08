-- Format DFSM summary
local function formatFSMSummary(dfsm)
    -- Format variables
    local variablesStr = {}
    local variables = dfsm:getVariables()
    for id, var in pairs(variables) do
        table.insert(variablesStr, string.format("- %s: %s", var.name, tostring(var.value)))
    end

    local summary = {
        "\nDoc Summary:\n",
        string.format("Input Variables:\n%s", table.concat(variablesStr, "\n")),
        "\nDFSM Summary:\n",
        string.format("- States: %d", #dfsm.states),
        string.format("- Transitions: %d", #dfsm.transitions),
        string.format("- Inputs: %d", #dfsm.inputs),
        string.format("- Current State: %s", dfsm.currentState),
        string.format("- Complete: %s", dfsm.isComplete and "Yes" or "No")
    }

    return table.concat(summary, "\n")
end

-- Format DFSM state
local function formatFSMState(dfsm)
    local summary = {
        "\nDFSM State:\n",
        string.format("- Current State: %s", dfsm.currentState),
        string.format("- Complete: %s", dfsm.isComplete and "Yes" or "No")
    }

    return table.concat(summary, "\n")
end

-- Render DFSM state machine visualization
local function renderDFSMState(dfsm)
    local states = dfsm.states
    local currentState = dfsm.currentState
    local transitions = dfsm.transitions

    -- ANSI color codes
    local GREEN = "\27[32m"
    local BLUE = "\27[34m"
    local RESET = "\27[0m"

    -- Create a map of states to their transitions
    local stateTransitions = {}
    for _, transition in ipairs(transitions) do
        if not stateTransitions[transition.from] then
            stateTransitions[transition.from] = {}
        end
        table.insert(stateTransitions[transition.from], transition.to)
    end

    -- Calculate the longest state name for padding
    local maxLength = 0
    for _, state in ipairs(states) do
        maxLength = math.max(maxLength, #state)
    end

    -- Print header
    print("\nDFSM State Machine Visualization:")
    print(string.rep("=", maxLength * 2 + 15))

    -- Track which states have been visited to avoid cycles
    local visitedStates = {}

    -- Function to print a state and its transitions recursively
    local function printStateAndTransitions(state, prefix, isLast)
        if visitedStates[state] then
            return
        end
        visitedStates[state] = true

        -- Create the state line with proper prefix
        local stateStr = string.format("%-" .. maxLength .. "s", state)
        local isCurrent = state == currentState

        -- Add current state indicator and color
        if isCurrent then
            stateStr = GREEN .. stateStr .. " (current)" .. RESET
        end

        -- Print the state with proper prefix
        print(prefix .. stateStr)

        -- Get transitions for this state
        local transitions = stateTransitions[state]
        if transitions then
            -- Sort transitions for consistent display
            table.sort(transitions)

            -- Print each transition
            for i, toState in ipairs(transitions) do
                local isLastTransition = i == #transitions
                local nextPrefix = prefix .. (isLastTransition and "    " or "│   ")
                local arrow = isLastTransition and "└───" or "├───"

                -- Print transition line
                print(prefix .. arrow .. " " .. BLUE .. "→" .. RESET)

                -- Recursively print the target state
                printStateAndTransitions(toState, nextPrefix, isLastTransition)
            end
        end
    end

    -- Start printing from the initial state
    printStateAndTransitions(states[1], "", true)

    print(string.rep("=", maxLength * 2 + 15))

    -- Print legend
    -- print("\nLegend:")
    -- print(GREEN .. "Green" .. RESET .. " - Current State")
    -- print(BLUE .. "Blue" .. RESET .. " - Transition Direction")
end

return {
    formatFSMSummary = formatFSMSummary,
    formatFSMState = formatFSMState,
    renderDFSMState = renderDFSMState
}