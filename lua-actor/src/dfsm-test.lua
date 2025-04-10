require("setup")

local TestUtils = require("test-utils")
local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")

-- Load agreement document from JSON file
local function loadAgreementDoc()
    local file = io.open("../externals/agreements-protocol/templates/grant-agreement.md.dfsm.json", "r")
    if not file then
        error("Could not open agreement document file")
    end
    local content = file:read("*all")
    file:close()
    return content
end

local agreementDoc = loadAgreementDoc()
local dfsm = DFSM.new(json.decode(agreementDoc))

print(DFSMUtils.formatFSMSummary(dfsm))

print(DFSMUtils.renderDFSMState(dfsm))

-- Helper function to process input and display results
local function processInputAndDisplay(dfsm, inputId, inputValue)
    print("\nProcessing input:", inputId)
    print("Input value:")
    TestUtils.printTable(inputValue)
    
    local success, result = dfsm:processInput(inputId, inputValue)
    
    if success then
        print("✅ Success:", result)
    else
        print("❌ Error:", result)
    end
    
    print(DFSMUtils.renderDFSMState(dfsm))
end

-- Test the state machine transitions
processInputAndDisplay(dfsm, "grantRecipientSignature", json.decode([[{
    "isGrantRecipientApproved": true
}]]))

-- Test duplicate input handling
processInputAndDisplay(dfsm, "grantRecipientSignature", json.decode([[{
    "isGrantRecipientApproved": true
}]]))

-- Test invalid input handling
processInputAndDisplay(dfsm, "invalidInput", json.decode([[{
    "someValue": true
}]]))

-- Invalid work approval signature
processInputAndDisplay(dfsm, "workApprovedSignature", json.decode([[{
    "isApproved": false
}]]))

-- Valid work approval signature
processInputAndDisplay(dfsm, "workApprovedSignature", json.decode([[{
    "isApproved": true
}]]))

-- Valid work approval signature
processInputAndDisplay(dfsm, "fundsSentTx", json.decode([[{
    "txHash": "0x9445f933860ef6d65fdaf419fcf8b0749f415c7cd0f82f8b420b10a776c5373e"
}]]))


print(DFSMUtils.formatFSMSummary(dfsm))

-- assert(true == true)