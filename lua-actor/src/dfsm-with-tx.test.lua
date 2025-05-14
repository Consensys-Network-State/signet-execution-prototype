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

-- Work Submission - should succeed and transition to WORK_IN_REVIEW
TestUtils.runTest(
    "Work Submission", 
    dfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065",
        "credentialSubject": {
            "inputId": "workSubmission",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "submissionHash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
                "submissionUrl": "https://ipfs.io/ipfs/QmZ4tDuvesekSs4qM5ZBKpXiZGun7S2CYtEZRB3DYXkjGx"
            }
        }
    }]], agreementHash),
    true,  -- expect success
    nil,
    "WORK_IN_REVIEW",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Create a new instance to test the acceptance flow
local acceptDfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065"
}
]]))

-- Bring the state to WORK_IN_REVIEW (repeating previous steps)
TestUtils.runTest(
    "Valid Grantor data submission (for accept flow)", 
    acceptDfsm, 
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
    true,
    nil,
    "AWAITING_RECIPIENT_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Valid Recipient data submission (for accept flow)", 
    acceptDfsm, 
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
    true,
    nil,
    "AWAITING_GRANTOR_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Valid Grantor signature submission (for accept flow)", 
    acceptDfsm, 
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
    true,
    nil,
    "AWAITING_WORK_SUBMISSION",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Work Submission (for accept flow)", 
    acceptDfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065",
        "credentialSubject": {
            "inputId": "workSubmission",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "submissionHash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
                "submissionUrl": "https://ipfs.io/ipfs/QmZ4tDuvesekSs4qM5ZBKpXiZGun7S2CYtEZRB3DYXkjGx"
            }
        }
    }]], agreementHash),
    true,
    nil,
    "WORK_IN_REVIEW",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Work Accepted - should succeed and transition to AWAITING_PAYMENT
TestUtils.runTest(
    "Work Accepted", 
    acceptDfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
        "credentialSubject": {
            "inputId": "workAccepted",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "acceptanceComments": "Great job, the work meets all requirements!"
            }
        }
    }]], agreementHash),
    true,
    nil,
    "AWAITING_PAYMENT",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Payment sent - should succeed and transition to WORK_ACCEPTED_AND_PAID
local txData = json.decode(oracleDataDoc)
-- Update the document hash to match current test
txData.credentialSubject.documentHash = agreementHash

TestUtils.runTest(
    "Payment sent", 
    acceptDfsm, 
    json.encode(txData),
    true,
    nil,
    "WORK_ACCEPTED_AND_PAID",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Create new instance to test resubmission flow
local resubmitDfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065"
}
]]))

-- Bring the state to WORK_IN_REVIEW (same steps as before, compacted for brevity)
TestUtils.runTest("Initial setup for resubmit flow (grantor data)", resubmitDfsm, 
    string.format([[{"type":"VerifiedCredentialEIP712","issuer":"0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","credentialSubject":{"inputId":"grantorData","type":"signedFields","documentHash":"%s","values":{"grantorName":"Damian","scope":"Development of Web3 tooling","termDuration":"6 months","effectiveDate":"2024-03-20T12:00:00Z"}}}]], agreementHash),
    true, nil, "AWAITING_RECIPIENT_SIGNATURE", DFSMUtils, testCounter, expectVc)

TestUtils.runTest("Initial setup for resubmit flow (recipient signing)", resubmitDfsm, 
    string.format([[{"type":"VerifiedCredentialEIP712","issuer":"0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","credentialSubject":{"inputId":"recipientSigning","type":"signedFields","documentHash":"%s","values":{"recipientName":"Leif","recipientSignature":"0xsignature"}}}]], agreementHash),
    true, nil, "AWAITING_GRANTOR_SIGNATURE", DFSMUtils, testCounter, expectVc)

TestUtils.runTest("Initial setup for resubmit flow (grantor signing)", resubmitDfsm, 
    string.format([[{"type":"VerifiedCredentialEIP712","issuer":"0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","credentialSubject":{"inputId":"grantorSigning","type":"signedFields","documentHash":"%s","values":{"grantorSignature":"0xgrantorsignature"}}}]], agreementHash),
    true, nil, "AWAITING_WORK_SUBMISSION", DFSMUtils, testCounter, expectVc)

TestUtils.runTest("Initial setup for resubmit flow (work submission)", resubmitDfsm, 
    string.format([[{"type":"VerifiedCredentialEIP712","issuer":"0xBe32388C134a952cdBCc5673E93d46FfD8b85065","credentialSubject":{"inputId":"workSubmission","type":"signedFields","documentHash":"%s","values":{"submissionHash":"0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef","submissionUrl":"https://ipfs.io/ipfs/QmZ4tDuvesekSs4qM5ZBKpXiZGun7S2CYtEZRB3DYXkjGx"}}}]], agreementHash),
    true, nil, "WORK_IN_REVIEW", DFSMUtils, testCounter, expectVc)

-- Work Resubmission Requested - should succeed and transition back to AWAITING_WORK_SUBMISSION
TestUtils.runTest(
    "Work Resubmission Requested", 
    resubmitDfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
        "credentialSubject": {
            "inputId": "workResubmissionRequested",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "resubmissionReason": "The work is missing some required elements",
                "resubmissionInstructions": "Please add section 3.2 covering security considerations"
            }
        }
    }]], agreementHash),
    true,
    nil,
    "AWAITING_WORK_SUBMISSION",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Create new instance to test rejection flow
local rejectDfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065"
}
]]))

-- Bring the state to WORK_IN_REVIEW (same steps as before, compacted for brevity)
TestUtils.runTest("Initial setup for reject flow", rejectDfsm, 
    string.format([[{"type":"VerifiedCredentialEIP712","issuer":"0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","credentialSubject":{"inputId":"grantorData","type":"signedFields","documentHash":"%s","values":{"grantorName":"Damian","scope":"Development of Web3 tooling","termDuration":"6 months","effectiveDate":"2024-03-20T12:00:00Z"}}}]], agreementHash),
    true, nil, "AWAITING_RECIPIENT_SIGNATURE", DFSMUtils, testCounter, expectVc)

TestUtils.runTest("Continuing setup for reject flow", rejectDfsm, 
    string.format([[{"type":"VerifiedCredentialEIP712","issuer":"0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","credentialSubject":{"inputId":"recipientSigning","type":"signedFields","documentHash":"%s","values":{"recipientName":"Leif","recipientSignature":"0xsignature"}}}]], agreementHash),
    true, nil, "AWAITING_GRANTOR_SIGNATURE", DFSMUtils, testCounter, expectVc)

TestUtils.runTest("Continuing setup for reject flow", rejectDfsm, 
    string.format([[{"type":"VerifiedCredentialEIP712","issuer":"0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","credentialSubject":{"inputId":"grantorSigning","type":"signedFields","documentHash":"%s","values":{"grantorSignature":"0xgrantorsignature"}}}]], agreementHash),
    true, nil, "AWAITING_WORK_SUBMISSION", DFSMUtils, testCounter, expectVc)

TestUtils.runTest("Continuing setup for reject flow", rejectDfsm, 
    string.format([[{"type":"VerifiedCredentialEIP712","issuer":"0xBe32388C134a952cdBCc5673E93d46FfD8b85065","credentialSubject":{"inputId":"workSubmission","type":"signedFields","documentHash":"%s","values":{"submissionHash":"0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef","submissionUrl":"https://ipfs.io/ipfs/QmZ4tDuvesekSs4qM5ZBKpXiZGun7S2CYtEZRB3DYXkjGx"}}}]], agreementHash),
    true, nil, "WORK_IN_REVIEW", DFSMUtils, testCounter, expectVc)

-- Work Rejected - should succeed and transition to REJECTED
TestUtils.runTest(
    "Work Rejected", 
    rejectDfsm, 
    string.format([[{
        "type": "VerifiedCredentialEIP712",
        "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
        "credentialSubject": {
            "inputId": "workRejected",
            "type": "signedFields",
            "documentHash": "%s",
            "values": {
                "rejectionReason": "The work does not meet our standards and is too far off from the requirements to be salvaged"
            }
        }
    }]], agreementHash),
    true,
    nil,
    "REJECTED",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Rejection case for agreement - testing from an alternative starting point
local agreementRejectionDfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
}
]]))

-- Run tests to bring to AWAITING_GRANTOR_SIGNATURE state
TestUtils.runTest(
    "Valid Grantor data submission (for agreement rejection test)", 
    agreementRejectionDfsm, 
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
    "Valid Recipient data submission (for agreement rejection test)", 
    agreementRejectionDfsm, 
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

-- Now test agreement rejection
TestUtils.runTest(
    "Grantor rejects the agreement", 
    agreementRejectionDfsm, 
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
    agreementRejectionDfsm,
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
