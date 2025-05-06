require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")
local crypto = require(".crypto.init")

local agreementDoc = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.json")
local agreementHash = crypto.digest.keccak256(agreementDoc).asHex()
local oracleDataDoc = TestUtils.loadInputDoc("./test-data/grant-with-tx/proof-data.json")
-- full info on a couple of canned transactions
local fullTxData = oracleDataDoc

local expectVc = false
local dfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
    "grantAmount": 100,
    "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
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
                "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "PENDING_PARTY_B_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
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
                "partyBName": "Leif"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "PENDING_ACCEPTANCE",
    DFSMUtils,
    testCounter,
    expectVc
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
                "partyAAcceptance": "ACCEPTED"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "ACCEPTED_PENDING_PAYMENT",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Tokens sent - should succeed and transition to PAYMENT_CONFIRMED
TestUtils.runTest(
    "Tokens sent", 
    dfsm, 
    fullTxData,
    true,  -- expect success
    nil,
    "PAYMENT_CONFIRMED",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Rejection case - testing from an alternative starting point
local rejectionDfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
    "grantAmount": 100,
    "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
}
]]))

-- Run tests to bring to PENDING_ACCEPTANCE state
TestUtils.runTest(
    "Valid Party A data submission (for rejection test)", 
    rejectionDfsm, 
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
                "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "PENDING_PARTY_B_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Valid Party B data submission (for rejection test)", 
    rejectionDfsm, 
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
                "partyBName": "Leif"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "PENDING_ACCEPTANCE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Now test rejection
TestUtils.runTest(
    "Party A rejects the agreement", 
    rejectionDfsm, 
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
    true,  -- expect success
    nil,
    "REJECTED",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Invalid input - should fail with error
TestUtils.runTest(
    "Invalid input ID", 
    rejectionDfsm,
    [[{
        "credentialSubject": {
            "inputId": "invalidInput"
        },
        "someValue": true
    }]],
    false,  -- expect failure
    "State machine is complete",
    "REJECTED", -- state should not change
    DFSMUtils,
    testCounter,
    expectVc
)

-- Print test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------")
