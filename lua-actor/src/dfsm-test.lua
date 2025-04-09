require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")

-- Load agreement document from JSON file
local function loadAgreementDoc()
    local file = io.open("./test-data/simple-Grant/grant-agreement.md.dfsm.json", "r")
    if not file then
        error("Could not open agreement document file")
    end
    local content = file:read("*all")
    file:close()
    return content
end

local agreementDoc = loadAgreementDoc()
local dfsm = DFSM.new(agreementDoc, false)

print(DFSMUtils.formatFSMSummary(dfsm))

print(DFSMUtils.renderDFSMState(dfsm))

-- Helper function to process input and display results
local function processInputAndDisplay(dfsm, inputId, inputValue)
    print("\nProcessing input:", inputId)
    
    local success, result = dfsm:processInput(inputId, inputValue, false)
    
    if success then
        print("✅ Success:", result)
    else
        print("❌ Error:", result)
    end
    
    print(DFSMUtils.renderDFSMState(dfsm))
end

-- Test the state machine transitions
processInputAndDisplay(dfsm, "partyAData", [[
{
    "issuer": "",
    "credentialSubject": {
        "id": "partyAData",
        "type": "signedFields",
        "fields": [
            {
                "id": "partyAName",
                "value": "Damian"
            },
            {
                "id": "partyAEthAddress",
                "value": "0x1234567890123456789012345678901234567890"
            }
        ]
    }
}]])

-- Test duplicate input handling
processInputAndDisplay(dfsm, "partyAData", [[
{
    "issuer": "",
    "credentialSubject": {
        "id": "partyAData",
        "type": "signedFields",
        "fields": [
            {
                "id": "partyAName",
                "value": "Damian"
            },
            {
                "id": "partyAEthAddress",
                "value": "0x1234567890123456789012345678901234567890"
            }
        ]
    }
}]])

-- Test invalid input handling
processInputAndDisplay(dfsm, "invalidInput", [[{
    "someValue": true
}]])

-- Invalid work approval signature
processInputAndDisplay(dfsm, "partyBData", [[
{
    "issuer": "",
    "credentialSubject": {
        "id": "partyBData",
        "type": "signedFields",
        "fields": [
            {
                "id": "partyBName",
                "value": "Leif"
            },
            {
                "id": "partyBEthAddress",
                "value": "0x2234567890123456789012345678901234567890"
            }
        ]
    }
}]])

print(DFSMUtils.formatFSMSummary(dfsm))

-- assert(true == true)