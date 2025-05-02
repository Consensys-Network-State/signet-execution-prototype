local DFSMUtils = {}

-- Format DFSM summary
function DFSMUtils.formatFSMSummary(dfsm)
    local summary = {
        "DFSM Summary:",
        string.format("Current State: %s", dfsm.state),
        "Available States:",
    }
    
    -- Get all states from transitions
    local states = {}
    for _, transition in ipairs(dfsm.transitions) do
        states[transition.from] = true
        states[transition.to] = true
    end
    
    -- Add all unique states
    for state in pairs(states) do
        table.insert(summary, string.format("  - %s", state))
    end
    
    -- Add inputs
    table.insert(summary, "\nInputs:")
    for id, input in pairs(dfsm.inputs) do
        table.insert(summary, string.format("  - %s (%s)", id, input.type))
    end
    
    -- Add transitions
    table.insert(summary, "\nTransitions:")
    for _, transition in ipairs(dfsm.transitions) do
        table.insert(summary, string.format("  - %s -> %s", transition.from, transition.to))
    end
    
    return table.concat(summary, "\n")
end

-- Format DFSM state
function DFSMUtils.formatFSMState(dfsm)
    local summary = {
        "\nDFSM State:\n",
        string.format("- Current State: %s (%s)", dfsm.currentState.name, dfsm.currentState.id),
        string.format("- Complete: %s", dfsm.complete and "Yes" or "No")
    }

    return table.concat(summary, "\n")
end

-- Render DFSM state machine visualization
function DFSMUtils.renderDFSMState(dfsm)
    local state = {
        string.format("Current State: %s (%s)", dfsm.currentState.name, dfsm.currentState.id),
        string.format("Complete: %s", tostring(dfsm.complete)),
        "\nReceived Inputs:"
    }
    
    -- Use the map representation for consistent display
    local receivedMap = dfsm:getReceivedInputValuesMap()
    for id, _ in pairs(receivedMap) do
        table.insert(state, string.format("  - %s", id))
    end
    
    return table.concat(state, "\n")
end

return DFSMUtils