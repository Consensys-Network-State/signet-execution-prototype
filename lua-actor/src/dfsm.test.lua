require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")
local crypto = require(".crypto.init")

local agreementDoc = TestUtils.loadInputDoc("./test-data/simple-grant/simple.grant.json")
local agreementHash = crypto.digest.keccak256(agreementDoc).asHex()

local dfsm = DFSM.new(agreementDoc, false, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",
}
]]))

print(DFSMUtils.formatFSMSummary(dfsm))
print(DFSMUtils.renderDFSMState(dfsm))

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Valid Party A data - should succeed and transition to PENDING_PARTY_B_SIGNATURE
TestUtils.runTest(
    "Valid Party A data submission", 
    dfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "inputId": "partyAData",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "partyAName": "Damian",
                "termDuration": "1 year",
                "effectiveDate": "2025-05-20",
                "scope": "Sample scope"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "PENDING_PARTY_B_SIGNATURE",
    DFSMUtils,
    testCounter
)

-- Invalid input ID - should fail with unknown input error
TestUtils.runTest(
    "Invalid input ID", 
    dfsm, 
    string.format([[{
        "credentialSubject": {
            "inputId": "invalidInput",
            "documentHash": "%s"
        },
        "someValue": true
    }]], agreementHash),
    false,  -- expect failure
    "Unknown input",
    "PENDING_PARTY_B_SIGNATURE",  -- state should not change
    DFSMUtils,
    testCounter
)

-- Valid Party B data - should succeed and transition to PENDING_ACCEPTANCE
TestUtils.runTest(
    "Valid Party B data submission", 
    dfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
        },
        "credentialSubject": {
            "inputId": "partyBData",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "partyBName": "Leif",
                "partyBSignature": "Leif's signature"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "PENDING_ACCEPTANCE",
    DFSMUtils,
    testCounter
)

-- Valid acceptance - should succeed and transition to ACCEPTED
TestUtils.runTest(
    "Valid acceptance submission", 
    dfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "inputId": "accepted",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "partyAAcceptance": "ACCEPTED",
                "partyASignature": "Damian's signature"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "ACCEPTED",
    DFSMUtils,
    testCounter
)

-- Rejection after completion - should fail because state machine is complete
TestUtils.runTest(
    "Attempting rejection after completion", 
    dfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "inputId": "rejected",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "partyARejection": "REJECTED"
            }
        }
    }]], agreementHash),
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