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
    local agreementDoc = TestUtils.loadInputDoc(inputDir .. "/grant-simple" .. (expectVc and ".wrapped" or "") .. ".json")
    
    -- Load all test inputs
    local inputs = {}
    local inputFiles = {
        grantor_input = "input-grantor",
        recipient_input = "input-recipient",
        grantor_accept = "input-grantor-accept",
        grantor_reject = "input-grantor-reject",
        agreement_reject = "input-agreement-reject"
    }
    
    for key, file in pairs(inputFiles) do
        local path = inputDir .. "/" .. file .. (expectVc and ".wrapped" or "") .. ".json"
        inputs[key] = loadInput(path)
    end

    -- For wrapped tests, we also need the transaction proof
    if expectVc then
        local path = inputDir .. "/input-tx-proof.wrapped.json"
        inputs["tx-proof"] = loadInput(path)
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
    -- 1. Happy Path Tests
    print("\n=== Running Happy Path Tests ===")
    
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

    TestUtils.runTest(
        "Valid Recipient signature submission",
        dfsm,
        formatTestInput(inputs["recipient_input"], "recipientSigning", "recipientSigning", inputs["recipient_input"].values),
        true,
        nil,
        "AWAITING_GRANTOR_SIGNATURE",
        DFSMUtils,
        testCounter,
        expectVc
    )

    TestUtils.runTest(
        "Valid Grantor signature submission",
        dfsm,
        formatTestInput(inputs["grantor_accept"], "grantorSigning", "grantorSigning", inputs["grantor_accept"].values),
        true,
        nil,
        "AWAITING_PAYMENT",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- Payment validation
    if expectVc then
        TestUtils.runTest(
            "Valid Payment Proof",
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
            "Valid Payment Transaction",
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

    -- 2. Rejection Path Tests
    print("\n=== Running Rejection Path Tests ===")
    
    local rejectDfsm = DFSM.new(agreementDoc, expectVc, expectVc and nil or json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065"
}
]]))

    TestUtils.runTest(
        "Initial Grantor data (for rejection)",
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
        "Recipient signature (for rejection)",
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
        "Agreement Rejection by Grantor",
        rejectDfsm,
        formatTestInput(inputs["agreement_reject"], "grantorRejection", "grantorRejection", inputs["agreement_reject"].values),
        true,
        nil,
        "REJECTED",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- 3. Invalid Payment Tests
    print("\n=== Running Invalid Payment Tests ===")
    
    local paymentDfsm = DFSM.new(agreementDoc, expectVc, expectVc and nil or json.decode([[
{
    "grantorEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "recipientEthAddress": "0xBe32388C134a952cdBCc5673E93d46FfD8b85065"
}
]]))

    -- Bring state to AWAITING_PAYMENT
    for _, test in ipairs({
        {name = "Setup for payment (grantor)", input = "grantor_input", inputId = "grantorData", nextState = "AWAITING_RECIPIENT_SIGNATURE"},
        {name = "Setup for payment (recipient)", input = "recipient_input", inputId = "recipientSigning", nextState = "AWAITING_GRANTOR_SIGNATURE"},
        {name = "Setup for payment (grantor accept)", input = "grantor_accept", inputId = "grantorSigning", nextState = "AWAITING_PAYMENT"}
    }) do
        TestUtils.runTest(
            test.name,
            paymentDfsm,
            formatTestInput(inputs[test.input], test.inputId, test.inputId, inputs[test.input].values),
            true,
            nil,
            test.nextState,
            DFSMUtils,
            testCounter,
            expectVc
        )
    end

    -- Test invalid payment
    if expectVc then
        local invalidTxProof = json.decode(json.encode(inputs["tx-proof"])) -- Deep copy
        invalidTxProof.credentialSubject.values.workTokenSentTx.value = "0xinvalidtxhash"
        TestUtils.runTest(
            "Invalid Payment Transaction",
            paymentDfsm,
            invalidTxProof,
            false,
            "Proof provided for variable Transaction Hash is invalid",
            "AWAITING_PAYMENT",
            DFSMUtils,
            testCounter,
            expectVc
        )
    else
        -- For unwrapped tests, simulate payment with transaction data
        local fullTxData = TestUtils.loadInputDoc("proof-data.json")
        local fullTxDataB64 = base64.encode(fullTxData)
        TestUtils.runTest(
            "Invalid Payment Transaction",
            paymentDfsm,
            string.format([[{
                "type": "VerifiedCredentialEIP712",
                "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
                "credentialSubject": {
                    "inputId": "workTokenSentTx",
                    "documentHash": "%s",
                    "values": {
                        "workTokenSentTx": {
                            "value": "0xinvalidtxhash",
                            "proof": "%s"
                        }
                    }
                }
            }]], agreementHash, fullTxDataB64),
            false,
            "Proof provided for variable Transaction Hash is invalid",
            "AWAITING_PAYMENT",
            DFSMUtils,
            testCounter,
            expectVc
        )
    end
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
