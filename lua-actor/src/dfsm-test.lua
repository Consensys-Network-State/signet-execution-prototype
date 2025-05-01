require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")

local agreementDoc = TestUtils.loadInputDoc("./test-data/simple-grant/simple.grant.json")

local dfsm = DFSM.new(agreementDoc, false, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
}
]]))

print(DFSMUtils.formatFSMSummary(dfsm))
print(DFSMUtils.renderDFSMState(dfsm))

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Test 1: Valid Party A data - should succeed and transition to PENDING_PARTY_B_SIGNATURE
TestUtils.runTest(
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
    "PENDING_PARTY_B_SIGNATURE",
    DFSMUtils,
    testCounter
)

-- Test 2: Duplicate Party A data submission - should fail with already processed error
TestUtils.runTest(
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
    "PENDING_PARTY_B_SIGNATURE",  -- state should not change
    DFSMUtils,
    testCounter
)

-- Test 3: Invalid input ID - should fail with unknown input error
TestUtils.runTest(
    "Invalid input ID", 
    dfsm, 
    "invalidInput", 
    [[{
        "someValue": true
    }]],
    false,  -- expect failure
    "Unknown input",
    "PENDING_PARTY_B_SIGNATURE",  -- state should not change
    DFSMUtils,
    testCounter
)

-- Test 4: Valid Party B data - should succeed and transition to PENDING_ACCEPTANCE
TestUtils.runTest(
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
    "PENDING_ACCEPTANCE",
    DFSMUtils,
    testCounter
)

-- Test 5: Valid acceptance - should succeed and transition to ACCEPTED
TestUtils.runTest(
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
    "ACCEPTED",
    DFSMUtils,
    testCounter
)

-- Test 6: Rejection after completion - should fail because state machine is complete
TestUtils.runTest(
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
    "ACCEPTED",  -- state should not change
    DFSMUtils,
    testCounter
)

-- Print test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------")