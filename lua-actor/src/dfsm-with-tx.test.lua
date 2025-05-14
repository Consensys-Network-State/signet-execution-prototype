require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")
local crypto = require(".crypto.init")
local base64 = require(".base64")

local agreementDoc = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.json")
local agreementHash = crypto.digest.keccak256(agreementDoc).asHex()

local oracleDataDoc = TestUtils.loadInputDoc("./test-data/grant-with-tx/proof-data.json")
-- full info on a couple of canned transactions
local fullTxData = oracleDataDoc

local expectVc = false
local dfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065"
}
]]))

print(DFSMUtils.formatFSMSummary(dfsm))
print(DFSMUtils.renderDFSMState(dfsm))

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Valid Grantor data - should succeed and transition to AWAITING_RECIPIENT_SIGNATURE
TestUtils.runTest(
    "Valid Grantor data submission", 
    dfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
        "credentialSubject": {
            "inputId": "grantorData",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "grantorName": "Damian",
                "scope": "Development of Web3 tooling",
                "termDuration": "6 months",
                "effectiveDate": "2024-03-20T12:00:00Z"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "AWAITING_RECIPIENT_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Valid Recipient data - should succeed and transition to AWAITING_GRANTOR_SIGNATURE
TestUtils.runTest(
    "Valid Recipient data submission", 
    dfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",
        "credentialSubject": {
            "inputId": "recipientSigning",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "recipientName": "Leif",
                "recipientSignature": "0xsignature"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "AWAITING_GRANTOR_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Valid Grantor signature - should succeed and transition to AWAITING_WORK_SUBMISSION
TestUtils.runTest(
    "Valid Grantor signature submission", 
    dfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
        "credentialSubject": {
            "inputId": "grantorSigning",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "grantorSignature": "0xgrantorsignature"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "AWAITING_WORK_SUBMISSION",
    DFSMUtils,
    testCounter,
    expectVc
)

print(string.format([[{
    "type": "VerifiedCredentialEIP712",
    "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "credentialSubject": {
        "inputId": "workTokenSentTx",
        "documentHash": "%s",
        "values": {
            "workTokenSentTx": {
                "proof": "%s"
            }
        }
    }
}]], agreementHash, fullTxData))

-- Tokens sent - should succeed and transition to WORK_ACCEPTED_AND_PAID
local fullTxDataB64 = base64.encode(fullTxData)

TestUtils.runTest(
    "Tokens sent", 
    dfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
        "credentialSubject": {
            "inputId": "workTokenSentTx",
            "documentHash": "%s",
            "values": {
                "workTokenSentTx": {
                    "value": "0x15cdc2d5157685faaca3da6928fe412608747e76a7daee0800d5c79c2b76a0cd",
                    "proof": "%s"
                }
            }
        }
    }]], agreementHash, fullTxDataB64),
    true,  -- expect success
    nil,
    "WORK_ACCEPTED_AND_PAID",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Rejection case - testing from an alternative starting point
local rejectionDfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
}
]]))

-- Run tests to bring to AWAITING_GRANTOR_SIGNATURE state
TestUtils.runTest(
    "Valid Grantor data submission (for rejection test)", 
    rejectionDfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
        "credentialSubject": {
            "inputId": "grantorData",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "grantorName": "Damian",
                "scope": "Development of Web3 tooling",
                "termDuration": "6 months",
                "effectiveDate": "2024-03-20T12:00:00Z"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "AWAITING_RECIPIENT_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Valid Recipient data submission (for rejection test)", 
    rejectionDfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",
        "credentialSubject": {
            "inputId": "recipientSigning",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "recipientName": "Leif",
                "recipientSignature": "0xsignature"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "AWAITING_GRANTOR_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Now test rejection
TestUtils.runTest(
    "Grantor rejects the agreement", 
    rejectionDfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
        "credentialSubject": {
            "inputId": "grantorRejection",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "grantorRejectionReason": "Terms do not meet our requirements"
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
