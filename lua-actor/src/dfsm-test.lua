require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")

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

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Helper function to run a test case
local function runTest(description, dfsm, inputId, inputValue, expectedSuccess, expectedErrorContains, expectedState)
    print("\n---------------------------------------------")
    print("TEST: " .. description)
    print("Processing input: " .. inputId)
    
    local initialState = dfsm.currentState and dfsm.currentState.id or "nil"
    
    -- Set validateVC to false for testing
    local success, result = dfsm:processInput(inputId, inputValue, false)
    
    -- Use built-in assert for success/failure expectation
    assert(success == expectedSuccess, 
        "Expected " .. (expectedSuccess and "success" or "failure") .. 
        " for " .. inputId .. ", got: " .. tostring(success))
    TestUtils.logTest("State machine " .. (expectedSuccess and "successfully processed" or "correctly rejected") .. " input", testCounter)
    
    -- If we expect an error, check that the error message contains expected text
    if not expectedSuccess and expectedErrorContains then
        assert(result:find(expectedErrorContains, 1, true) ~= nil, 
            "Error message should contain '" .. expectedErrorContains .. "', got: " .. result)
        TestUtils.logTest("Error message contains expected text: " .. expectedErrorContains, testCounter)
    end
    
    -- Check expected state transition if provided
    if expectedState then
        assert(dfsm.currentState and dfsm.currentState.id == expectedState, 
            "Expected state " .. expectedState .. ", got " .. (dfsm.currentState and dfsm.currentState.id or "nil"))
        TestUtils.logTest("State machine transitioned to expected state: " .. expectedState, testCounter)
    end
    
    print(DFSMUtils.renderDFSMState(dfsm))
end

-- Test 1: Valid Party A data - should succeed and transition to PENDING_PARTY_B_SIGNATURE
runTest(
    "Valid Party A data submission", 
    dfsm, 
    "partyAData", 
    [[{
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
    }]],
    true,  -- expect success
    nil,
    "PENDING_PARTY_B_SIGNATURE"
)

-- Test 2: Duplicate Party A data submission - should fail with already processed error
runTest(
    "Duplicate Party A data submission", 
    dfsm, 
    "partyAData", 
    [[{
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
    }]],
    false,  -- expect failure
    "has already been processed",
    "PENDING_PARTY_B_SIGNATURE"  -- state should not change
)

-- Test 3: Invalid input ID - should fail with unknown input error
runTest(
    "Invalid input ID", 
    dfsm, 
    "invalidInput", 
    [[{
        "someValue": true
    }]],
    false,  -- expect failure
    "Unknown input",
    "PENDING_PARTY_B_SIGNATURE"  -- state should not change
)

-- Test 4: Valid Party B data - should succeed and transition to PENDING_ACCEPTANCE
runTest(
    "Valid Party B data submission", 
    dfsm, 
    "partyBData", 
    [[{
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
    }]],
    true,  -- expect success
    nil,
    "PENDING_ACCEPTANCE"
)

-- Test 5: Valid acceptance - should succeed and transition to ACCEPTED
runTest(
    "Valid acceptance submission", 
    dfsm, 
    "accepted", 
    [[{
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
    }]],
    true,  -- expect success
    nil,
    "ACCEPTED"
)

-- Test 6: Rejection after completion - should fail because state machine is complete
runTest(
    "Attempting rejection after completion", 
    dfsm, 
    "rejected", 
    [[{
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
    }]],
    false,  -- expect failure
    "State machine is complete",
    "ACCEPTED"  -- state should not change
)

-- Print test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------")