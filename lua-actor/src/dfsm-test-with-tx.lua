require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")

local agreementDoc = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.json")
local oracleDataDoc = TestUtils.loadInputDoc("./test-data/grant-with-tx/proof-data.json")
-- full info on a couple of canned transactions
local fullTxData = oracleDataDoc

local expectVc = false
local dfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
}
]]))

print(DFSMUtils.formatFSMSummary(dfsm))
print(DFSMUtils.renderDFSMState(dfsm))

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Test 1: Valid variables provider data - should succeed and transition to CUSTOMER_SIGNING
TestUtils.runTest(
    "Valid variables provider data submission", 
    dfsm, 
    "variablesProvider", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "variablesProvider",
            "type": "signedFields",
            "values": {
                "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",
                "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
                "grantAmount": 100,
                "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
            }
        }
    }]],
    true,  -- expect success
    nil,
    "CUSTOMER_SIGNING",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 2: Valid customer variables and signature - should succeed and transition to COUNTERSIGNING
TestUtils.runTest(
    "Valid customer variables and signature", 
    dfsm, 
    "customerVariables", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "customerVariables",
            "type": "signedFields",
            "values": {
                "partyAName": "Damian"
            }
        }
    }]],
    true,  -- expect success
    nil,
    "CUSTOMER_SIGNING", -- State doesn't change until both inputs are provided
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Valid customer signature", 
    dfsm, 
    "customerSignature", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "customerSignature",
            "type": "signedFields",
            "values": {
                "customerAgreement": "SIGNED"
            }
        }
    }]],
    true,  -- expect success
    nil,
    "COUNTERSIGNING",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 3: Valid provider signature - should succeed and transition to ACTIVE
TestUtils.runTest(
    "Valid provider signature", 
    dfsm, 
    "providerSignature", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
        },
        "credentialSubject": {
            "id": "providerSignature",
            "type": "signedFields",
            "values": {
                "partyBName": "Leif",
                "providerAgreement": "SIGNED"
            }
        }
    }]],
    true,  -- expect success
    nil,
    "ACTIVE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 4: Valid work submission - should succeed and transition to WORK_REVIEW
TestUtils.runTest(
    "Valid work submission", 
    dfsm, 
    "submissionVC", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
        },
        "credentialSubject": {
            "id": "submissionVC",
            "type": "signedFields",
            "values": {
                "workSubmission": "SUBMITTED",
                "submissionDetails": "Completed the initial phase of the project."
            }
        }
    }]],
    true,  -- expect success
    nil,
    "WORK_REVIEW",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 5: Valid feedback - should succeed and transition to RESUBMIT
TestUtils.runTest(
    "Valid feedback submission", 
    dfsm, 
    "feedbackVC", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "feedbackVC",
            "type": "signedFields",
            "values": {
                "feedback": "REVISIONS_REQUESTED",
                "feedbackDetails": "Please update section 3 with more details."
            }
        }
    }]],
    true,  -- expect success
    nil,
    "RESUBMIT",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 6: Valid resubmission - should succeed and transition back to WORK_REVIEW
TestUtils.runTest(
    "Valid work resubmission", 
    dfsm, 
    "submissionVC", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
        },
        "credentialSubject": {
            "id": "submissionVC",
            "type": "signedFields",
            "values": {
                "workSubmission": "SUBMITTED",
                "submissionDetails": "Updated with requested changes to section 3."
            }
        }
    }]],
    true,  -- expect success
    nil,
    "WORK_REVIEW",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 7: Payment transaction - should succeed and transition to ACCEPTED_PAID
TestUtils.runTest(
    "Payment transaction", 
    dfsm, 
    "paymentTx", 
    fullTxData,
    true,  -- expect success
    nil,
    "ACCEPTED_PAID",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 8: Rejection case - testing from an alternative starting point
local rejectionDfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
}
]]))

-- Run tests to bring to CUSTOMER_SIGNING state
TestUtils.runTest(
    "Valid variables provider data (for rejection test)", 
    rejectionDfsm, 
    "variablesProvider", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "variablesProvider",
            "type": "signedFields",
            "values": {
                "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",
                "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
                "grantAmount": 100,
                "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
            }
        }
    }]],
    true,  -- expect success
    nil,
    "CUSTOMER_SIGNING",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Now test customer rejection
TestUtils.runTest(
    "Customer rejects the agreement", 
    rejectionDfsm, 
    "customerRejects", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "customerRejects",
            "type": "signedFields",
            "values": {
                "rejection": "REJECTED",
                "rejectionReason": "Terms do not meet our requirements."
            }
        }
    }]],
    true,  -- expect success
    nil,
    "REJECTED",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 9: Provider rejection case
local providerRejectionDfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
}
]]))

-- Run tests to bring to COUNTERSIGNING state
TestUtils.runTest(
    "Valid variables provider data (for provider rejection)", 
    providerRejectionDfsm, 
    "variablesProvider", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "variablesProvider",
            "type": "signedFields",
            "values": {
                "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",
                "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
                "grantAmount": 100,
                "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
            }
        }
    }]],
    true,  -- expect success
    nil,
    "CUSTOMER_SIGNING",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Valid customer variables (for provider rejection)", 
    providerRejectionDfsm, 
    "customerVariables", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "customerVariables",
            "type": "signedFields",
            "values": {
                "partyAName": "Damian"
            }
        }
    }]],
    true,  -- expect success
    nil,
    "CUSTOMER_SIGNING",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Valid customer signature (for provider rejection)", 
    providerRejectionDfsm, 
    "customerSignature", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "customerSignature",
            "type": "signedFields",
            "values": {
                "customerAgreement": "SIGNED"
            }
        }
    }]],
    true,  -- expect success
    nil,
    "COUNTERSIGNING",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Now test provider rejection
TestUtils.runTest(
    "Provider rejects the agreement", 
    providerRejectionDfsm, 
    "providerRejects", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
        },
        "credentialSubject": {
            "id": "providerRejects",
            "type": "signedFields",
            "values": {
                "rejection": "REJECTED",
                "rejectionReason": "Unable to meet requested timeline."
            }
        }
    }]],
    true,  -- expect success
    nil,
    "REJECTED",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 10: Termination case
local terminationDfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
}
]]))

-- Run tests to bring to ACTIVE state
TestUtils.runTest(
    "Setup variables (for termination test)", 
    terminationDfsm, 
    "variablesProvider", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "variablesProvider",
            "type": "signedFields",
            "values": {
                "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",
                "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
                "grantAmount": 100,
                "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
            }
        }
    }]],
    true,
    nil,
    "CUSTOMER_SIGNING",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Customer variables (for termination test)", 
    terminationDfsm, 
    "customerVariables", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "customerVariables",
            "type": "signedFields",
            "values": {
                "partyAName": "Damian"
            }
        }
    }]],
    true,
    nil,
    "CUSTOMER_SIGNING",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Customer signature (for termination test)", 
    terminationDfsm, 
    "customerSignature", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "customerSignature",
            "type": "signedFields",
            "values": {
                "customerAgreement": "SIGNED"
            }
        }
    }]],
    true,
    nil,
    "COUNTERSIGNING",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Provider signature (for termination test)", 
    terminationDfsm, 
    "providerSignature", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
        },
        "credentialSubject": {
            "id": "providerSignature",
            "type": "signedFields",
            "values": {
                "partyBName": "Leif",
                "providerAgreement": "SIGNED"
            }
        }
    }]],
    true,
    nil,
    "ACTIVE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Now test termination
TestUtils.runTest(
    "Party A terminates the agreement", 
    terminationDfsm, 
    "partyATerminates", 
    [[{
        "type": "VerifiedCredentialEIP712",
        "issuer": {
            "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
        },
        "credentialSubject": {
            "id": "partyATerminates",
            "type": "signedFields",
            "values": {
                "termination": "TERMINATED",
                "terminationReason": "Project priorities have changed."
            }
        }
    }]],
    true,  -- expect success
    nil,
    "TERMINATED",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 11: Invalid input - should fail with error
TestUtils.runTest(
    "Invalid input ID", 
    terminationDfsm,
    "invalidInput", 
    [[{
        "someValue": true
    }]],
    false,  -- expect failure
    "State machine is complete",
    "TERMINATED", -- state should not change
    DFSMUtils,
    testCounter,
    expectVc
)

-- Print test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------")