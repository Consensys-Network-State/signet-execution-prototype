require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")
local crypto = require(".crypto.init")

-- Load all test input files
local agreementDoc = TestUtils.loadInputDoc("grant-with-tx.wrapped.json")
local grantorInput = TestUtils.loadInputDoc("grant-with-tx.grantor-input.wrapped.json")
local recipientInput = TestUtils.loadInputDoc("grant-with-tx.recipient-input.wrapped.json")
local grantorAccept = TestUtils.loadInputDoc("grant-with-tx.grantor-accept.wrapped.json")
local grantorReject = TestUtils.loadInputDoc("grant-with-tx.grantor-reject.wrapped.json")
local workSubmission = TestUtils.loadInputDoc("grant-with-tx.work-submission.wrapped.json")
local workAccept = TestUtils.loadInputDoc("grant-with-tx.work-accept.wrapped.json")
local workReject = TestUtils.loadInputDoc("grant-with-tx.work-reject.wrapped.json")
local agreementReject = TestUtils.loadInputDoc("grant-with-tx.agreement-reject.wrapped.json")
local txProof = TestUtils.loadInputDoc("grant-with-tx.grantor-tx-proof.wrapped.json")

-- Extract the agreement hash from the wrapped agreement document
local decodedAgreement = json.decode(agreementDoc)
local agreementBase64 = decodedAgreement.credentialSubject.agreement
local agreementHash = crypto.digest.keccak256(agreementBase64).asHex()

local expectVc = true
-- Initialize DFSM with variables from the wrapped agreement
local dfsm = DFSM.new(agreementDoc, expectVc)

print(DFSMUtils.formatFSMSummary(dfsm))
print(DFSMUtils.renderDFSMState(dfsm))

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Test 1: Valid Grantor data - should succeed and transition to AWAITING_RECIPIENT_SIGNATURE
TestUtils.runTest(
    "Valid Grantor data submission", 
    dfsm,
    grantorInput,
    true,  -- expect success
    nil,
    "AWAITING_RECIPIENT_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 2: Valid Recipient data - should succeed and transition to AWAITING_GRANTOR_SIGNATURE
TestUtils.runTest(
    "Valid Recipient data submission",
    dfsm,
    recipientInput,
    true,  -- expect success
    nil,
    "AWAITING_GRANTOR_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 3: Valid Grantor acceptance - should succeed and transition to AWAITING_WORK_SUBMISSION
TestUtils.runTest(
    "Valid Grantor acceptance submission", 
    dfsm,
    grantorAccept,
    true,  -- expect success
    nil,
    "AWAITING_WORK_SUBMISSION",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 4: Work Submission - should succeed and transition to WORK_IN_REVIEW
TestUtils.runTest(
    "Work Submission",
    dfsm,
    workSubmission,
    true,  -- expect success
    nil,
    "WORK_IN_REVIEW",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 5: Work Acceptance - should succeed and transition to AWAITING_PAYMENT
TestUtils.runTest(
    "Work Acceptance",
    dfsm,
    workAccept,
    true,  -- expect success
    nil,
    "AWAITING_PAYMENT",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 6: Payment Proof - should succeed and transition to WORK_ACCEPTED_AND_PAID
TestUtils.runTest(
    "Payment Proof",
    dfsm,
    txProof,
    true,  -- expect success
    nil,
    "WORK_ACCEPTED_AND_PAID",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Create new instance for rejection flow
local rejectDfsm = DFSM.new(agreementDoc, expectVc)

-- Test 7: Agreement Rejection Flow
TestUtils.runTest(
    "Initial Grantor data (for rejection test)",
    rejectDfsm,
    grantorInput,
    true,
    nil,
    "AWAITING_RECIPIENT_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Add recipient signature step before rejection
TestUtils.runTest(
    "Recipient signature (for rejection test)",
    rejectDfsm,
    recipientInput,
    true,
    nil,
    "AWAITING_GRANTOR_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Agreement Rejection",
    rejectDfsm,
    agreementReject,
    true,
    nil,
    "REJECTED",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Create new instance for work rejection flow
local workRejectDfsm = DFSM.new(agreementDoc, expectVc)

-- Test 8: Work Rejection Flow
TestUtils.runTest(
    "Initial Grantor data (for work rejection test)",
    workRejectDfsm,
    grantorInput,
    true,
    nil,
    "AWAITING_RECIPIENT_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Recipient data (for work rejection test)",
    workRejectDfsm,
    recipientInput,
    true,
    nil,
    "AWAITING_GRANTOR_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Grantor acceptance (for work rejection test)",
    workRejectDfsm,
    grantorAccept,
    true,
    nil,
    "AWAITING_WORK_SUBMISSION",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Work submission (for work rejection test)",
    workRejectDfsm,
    workSubmission,
    true,
    nil,
    "WORK_IN_REVIEW",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Work Rejection",
    workRejectDfsm,
    workReject,
    true,
    nil,
    "REJECTED",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Create new instance for grantor rejection flow
local grantorRejectDfsm = DFSM.new(agreementDoc, expectVc)

-- Test 9: Grantor Rejection Flow
TestUtils.runTest(
    "Initial Grantor data (for grantor rejection test)",
    grantorRejectDfsm,
    grantorInput,
    true,
    nil,
    "AWAITING_RECIPIENT_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Recipient data (for grantor rejection test)",
    grantorRejectDfsm,
    recipientInput,
    true,
    nil,
    "AWAITING_GRANTOR_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

TestUtils.runTest(
    "Grantor Rejection",
    grantorRejectDfsm,
    grantorReject,
    true,
    nil,
    "REJECTED",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 10: Invalid input - should fail with error
TestUtils.runTest(
    "Invalid input ID", 
    grantorRejectDfsm,
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