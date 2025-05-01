require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")

local agreementDoc = TestUtils.loadInputDoc("./test-data/grant-with-tx/simple.grant.json")
local oracleDataDoc = TestUtils.loadInputDoc("./mock-oracle-data.json")
-- full info on a couple of canned transactions
local txData = json.decode(oracleDataDoc)
local fullTxData1 = json.encode(txData["0x9445f933860ef6d65fdaf419fcf8b0749f415c7cd0f82f8b420b10a776c5373e"])
local fullTxData2 = json.encode(txData["0x1cdc44857dd967f99d4644151340b5a083f77e660c60121a7dc63b8b75047f5e"])

local dfsm = DFSM.new(agreementDoc, false, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
    "grantAmount": 68395011620287000,
    "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
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

-- Test 2: Valid Party B data - should succeed and transition to PENDING_ACCEPTANCE
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

-- Test 3: Valid acceptance - should succeed and transition to ACCEPTED
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

-- Test 4: Funds sent - should succeed and transition to AWAITING_PAYMENT
TestUtils.runTest(
    "Funds sent", 
    dfsm, 
    "fundsSentTx", 
    fullTxData1,
    true,  -- expect success
    nil,
    "AWAITING_PAYMENT",
    DFSMUtils,
    testCounter
)

-- Test 5: Tokens sent - should succeed and transition to PAYMENT_CONFIRMED
TestUtils.runTest(
    "Tokens sent", 
    dfsm, 
    "workTokenSentTx", 
    fullTxData2,
    true,  -- expect success
    nil,
    "PAYMENT_CONFIRMED",
    DFSMUtils,
    testCounter
)

-- Test 6: Rejection case - testing from an alternative starting point
local rejectionDfsm = DFSM.new(agreementDoc, false, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
    "grantAmount": 68395011620287000,
    "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
}
]]))

-- Run tests to bring to PENDING_ACCEPTANCE state
TestUtils.runTest(
    "Valid Party A data submission (for rejection test)", 
    rejectionDfsm, 
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

TestUtils.runTest(
    "Valid Party B data submission (for rejection test)", 
    rejectionDfsm, 
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

-- Now test rejection
TestUtils.runTest(
    "Party A rejects the agreement", 
    rejectionDfsm, 
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
    true,  -- expect success
    nil,
    "REJECTED",
    DFSMUtils,
    testCounter
)

-- Test 7: Invalid input - should fail with error
TestUtils.runTest(
    "Invalid input ID", 
    dfsm, 
    "invalidInput", 
    [[{
        "someValue": true
    }]],
    false,  -- expect failure
    "State machine is complete",
    "PAYMENT_CONFIRMED",  -- state should not change
    DFSMUtils,
    testCounter
)

-- Print test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------")