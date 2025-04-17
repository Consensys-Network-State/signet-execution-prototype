require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")

-- Load agreement document from JSON file
local function loadInputDoc(path)
    local file = io.open(path, "r")
    if not file then
        error("Could not open input document file: " .. path)
    end
    local content = file:read("*all")
    file:close()
    return content
end

local agreementDoc = loadInputDoc("./test-data/simple-grant/simple.grant.wrapped.json")
local inputA = loadInputDoc("./test-data/simple-grant/simple.grant.partyA-input.wrapped.json")
local inputB = loadInputDoc("./test-data/simple-grant/simple.grant.partyB-input.wrapped.json")
local inputAAccept = loadInputDoc("./test-data/simple-grant/simple.grant.partyA-input-accept.wrapped.json")
local inputAReject = loadInputDoc("./test-data/simple-grant/simple.grant.partyA-input-reject.wrapped.json")


-- Initialize DFSM with required initial values
local initialValues = {
    partyAEthAddress = "0xB49e45Affd4963374e72f850B6Cae84939e58F78"
}

local dfsm = DFSM.new(agreementDoc, initialValues, true)

print(DFSMUtils.formatFSMSummary(dfsm))

print(DFSMUtils.renderDFSMState(dfsm))

-- Helper function to process input and display results
local function processInputAndDisplay(dfsm, inputId, inputValue)
    print("\nProcessing input:", inputId)
    
    -- Set validateVC to false for testing
    local success, result = dfsm:processInput(inputId, inputValue, true)
    
    if success then
        print("✅ Success:", result)
    else
        print("❌ Error:", result)
    end
    
    print(DFSMUtils.renderDFSMState(dfsm))
end
-- Party A data
processInputAndDisplay(dfsm, "partyAData", inputA)

-- Test duplicate input handling
processInputAndDisplay(dfsm, "partyAData", inputA)

-- Test invalid input handling
-- TODO: come up with a better invalid input sample
processInputAndDisplay(dfsm, "invalidInput", [[{
    "someValue": true
}]])

-- Party B data
processInputAndDisplay(dfsm, "partyBData", inputB)

-- Party A accepts
processInputAndDisplay(dfsm, "accepted", inputAAccept)

-- Party A rejects
processInputAndDisplay(dfsm, "rejected", inputAReject)

-- print(DFSMUtils.formatFSMSummary(dfsm))