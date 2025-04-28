require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")

-- Load agreement document from JSON file
local function loadAgreementDoc()
    local file = io.open("./test-data/simple-grant/simple.grant.json", "r")
    if not file then
        error("Could not open agreement document file")
    end
    local content = file:read("*all")
    file:close()
    return content
end

local agreementDoc = loadAgreementDoc()

local dfsm = DFSM.new(agreementDoc, false, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
}
]]))

print(DFSMUtils.formatFSMSummary(dfsm))

print(DFSMUtils.renderDFSMState(dfsm))

-- Helper function to process input and display results
local function processInputAndDisplay(dfsm, inputId, inputValue)
    print("\nProcessing input:", inputId)
    
    -- Set validateVC to false for testing
    local success, result = dfsm:processInput(inputId, inputValue, false)
    
    if success then
        print("✅ Success:", result)
    else
        print("❌ Error:", result)
    end
    
    print(DFSMUtils.renderDFSMState(dfsm))
end
-- Party A data
processInputAndDisplay(dfsm, "partyAData", [[
{
    "type": "VerifiedCredentialEIP712",
    "issuer": {
        "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
    },
    "credentialSubject": {
        "id": "partyAData",
        "type": "signedFields",
        "values": {
            "partyAName": "Damian",
            "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
        }
    }
}]])

-- Test duplicate input handling
processInputAndDisplay(dfsm, "partyAData", [[
{
    "type": "VerifiedCredentialEIP712",
    "issuer": {
        "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
    },
    "credentialSubject": {
        "id": "partyAData",
        "type": "signedFields",
        "values": {
            "partyAName": "Damian",
            "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
        }
    }
}]])

-- Test invalid input handling
processInputAndDisplay(dfsm, "invalidInput", [[{
    "someValue": true
}]])

-- Party B data
processInputAndDisplay(dfsm, "partyBData", [[
{
    "type": "VerifiedCredentialEIP712",
    "issuer": {
        "id": "did:pkh:eip155:1:0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
    },
    "credentialSubject": {
        "id": "partyBData",
        "type": "signedFields",
        "values": {
            "partyBName": "Leif"
        }
    }
}]])

-- Party A accepts
processInputAndDisplay(dfsm, "accepted", [[
{
    "type": "VerifiedCredentialEIP712",
    "issuer": {
        "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
    },
    "credentialSubject": {
        "id": "accepted",
        "type": "signedFields",
        "values": {
            "partyAAcceptance": "ACCEPTED"
        }
    }
}]])

-- Party A rejects
processInputAndDisplay(dfsm, "rejected", [[
{
    "type": "VerifiedCredentialEIP712",
    "issuer": {
        "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
    },
    "credentialSubject": {
        "id": "rejected",
        "type": "signedFields",
        "values": {
            "partyARejection": "REJECTED"
        }
    }
}]])

-- print(DFSMUtils.formatFSMSummary(dfsm))