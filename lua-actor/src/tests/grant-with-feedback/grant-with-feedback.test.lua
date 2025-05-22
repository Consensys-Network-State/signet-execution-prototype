require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")
local crypto = require(".crypto.init")
local base64 = require(".base64")

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Helper function to run test suite with given configuration
local function runTestSuite(params)
    local inputDir = params.inputDir
    local expectVc = params.expectVc
    local loadInput = params.loadInput

    -- Load agreement document and input files
    local agreementDoc = TestUtils.loadInputDoc(inputDir .. "/grant-with-feedback" .. (expectVc and ".wrapped" or "") .. ".json")
    
    -- Load all test inputs
    local inputs = {}
    local inputFiles = {
        grantor_input = "input-grantor",
        recipient_input = "input-recipient",
        grantor_accept = "input-grantor-accept",
        grantor_reject = "input-grantor-reject",
        work_submission = "input-work-submission",
        work_submission_2 = "input-work-submission-2",
        work_accept = "input-work-accept",
        work_reject = "input-work-reject",
        agreement_reject = "input-agreement-reject"
    }
    
    for key, file in pairs(inputFiles) do
        local path = inputDir .. "/" .. file .. (expectVc and ".wrapped" or "") .. ".json"
        inputs[key] = loadInput(path)
    end

    -- For wrapped tests, we also need the transaction proof
    if expectVc then
        inputs["tx-proof"] = TestUtils.loadInputDoc(inputDir .. "/input-tx-proof.wrapped.json")
    end

    -- Extract agreement hash
    local agreementHash
    if expectVc then
        local decodedAgreement = json.decode(agreementDoc)
        local agreementBase64 = decodedAgreement.credentialSubject.agreement
        agreementHash = crypto.digest.keccak256(agreementBase64).asHex()
    else
        agreementHash = crypto.digest.keccak256(agreementDoc).asHex()
    end

    -- Initialize DFSM
    local dfsm
    if expectVc then
        dfsm = DFSM.new(agreementDoc, expectVc)
    else
        dfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065"
}
]]))
    end

    print(DFSMUtils.formatFSMSummary(dfsm))
    print(DFSMUtils.renderDFSMState(dfsm))

    -- Helper function to format test input
    local function formatTestInput(input, inputId, type, values)
        if expectVc then
            return input
        else
            return string.format([[{
                "type": "VerifiedCredentialEIP712",
                "issuer": "%s",
                "credentialSubject": {
                    "inputId": "%s",
                    "type": "%s",
                    "documentHash": "%s",
                    "values": %s
                }
            }]], 
            "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
            inputId,
            type,
            agreementHash,
            json.encode(values))
        end
    end

    -- Run all test cases
    -- 1. Initial Grantor data submission
    TestUtils.runTest(
        "Valid Grantor data submission",
        dfsm,
        formatTestInput(inputs["grantor_input"], "grantorData", "grantorData", inputs["grantor_input"].values),
        true,
        nil,
        "AWAITING_RECIPIENT_SIGNATURE",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- 2. Recipient data submission
    TestUtils.runTest(
        "Valid Recipient data submission",
        dfsm,
        formatTestInput(inputs["recipient_input"], "recipientSigning", "recipientSigning", inputs["recipient_input"].values),
        true,
        nil,
        "AWAITING_GRANTOR_SIGNATURE",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- 3. Grantor acceptance
    TestUtils.runTest(
        "Valid Grantor acceptance submission",
        dfsm,
        formatTestInput(inputs["grantor_accept"], "grantorSigning", "grantorSigning", inputs["grantor_accept"].values),
        true,
        nil,
        "AWAITING_WORK_SUBMISSION",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- 4. Initial Work submission
    TestUtils.runTest(
        "Initial Work Submission",
        dfsm,
        formatTestInput(inputs["work_submission"], "workSubmission", "workSubmission", inputs["work_submission"].values),
        true,
        nil,
        "WORK_IN_REVIEW",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- 5. Work rejection
    TestUtils.runTest(
        "Work Rejection",
        dfsm,
        formatTestInput(inputs["work_reject"], "workRejected", "workRejected", inputs["work_reject"].values),
        true,
        nil,
        "AWAITING_WORK_SUBMISSION",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- 6. Second Work submission
    TestUtils.runTest(
        "Second Work Submission",
        dfsm,
        formatTestInput(inputs["work_submission_2"], "workSubmission", "workSubmission", inputs["work_submission_2"].values),
        true,
        nil,
        "WORK_IN_REVIEW",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- 7. Work acceptance
    TestUtils.runTest(
        "Work Accepted",
        dfsm,
        formatTestInput(inputs["work_accept"], "workAccepted", "workAccepted", inputs["work_accept"].values),
        true,
        nil,
        "AWAITING_PAYMENT",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- 8. Payment proof
    if expectVc then
        TestUtils.runTest(
            "Payment Proof",
            dfsm,
            inputs["tx-proof"],
            true,
            nil,
            "WORK_ACCEPTED_AND_PAID",
            DFSMUtils,
            testCounter,
            expectVc
        )
    else
        -- For unwrapped tests, simulate payment with transaction data
        local fullTxData = TestUtils.loadInputDoc("proof-data.json")
        local fullTxDataB64 = base64.encode(fullTxData)
        TestUtils.runTest(
            "Payment sent",
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
            true,
            nil,
            "WORK_ACCEPTED_AND_PAID",
            DFSMUtils,
            testCounter,
            expectVc
        )
    end

    -- Create new instance for agreement rejection flow
    local rejectDfsm = DFSM.new(agreementDoc, expectVc, expectVc and nil or json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065"
}
]]))

    -- Agreement rejection flow
    TestUtils.runTest(
        "Initial Grantor data (for agreement rejection)",
        rejectDfsm,
        formatTestInput(inputs["grantor_input"], "grantorData", "grantorData", inputs["grantor_input"].values),
        true,
        nil,
        "AWAITING_RECIPIENT_SIGNATURE",
        DFSMUtils,
        testCounter,
        expectVc
    )

    TestUtils.runTest(
        "Recipient data (for agreement rejection)",
        rejectDfsm,
        formatTestInput(inputs["recipient_input"], "recipientSigning", "recipientSigning", inputs["recipient_input"].values),
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
        formatTestInput(inputs["agreement_reject"], "grantorRejection", "grantorRejection", inputs["agreement_reject"].values),
        true,
        nil,
        "REJECTED",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- Invalid input test
    TestUtils.runTest(
        "Invalid input ID",
        rejectDfsm,
        [[{
            "credentialSubject": {
                "inputId": "invalidInput"
            },
            "someValue": true
        }]],
        false,
        "State machine is complete",
        "REJECTED",
        DFSMUtils,
        testCounter,
        expectVc
    )
end

-- Run unwrapped test suite
print("\n=== Running Unwrapped Test Suite ===")
runTestSuite({
    inputDir = "./unwrapped",
    expectVc = false,
    loadInput = function(path) return json.decode(TestUtils.loadInputDoc(path)) end
})

-- Run wrapped test suite
print("\n=== Running Wrapped Test Suite ===")
runTestSuite({
    inputDir = "./wrapped",
    expectVc = true,
    loadInput = function(path) return json.decode(TestUtils.loadInputDoc(path)) end
})

-- Print final test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------")
