require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")
local crypto = require(".crypto.init")

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Helper function to run test suite with given configuration
local function runTestSuite(params)
    local inputDir = params.inputDir
    local expectVc = params.expectVc
    local loadInput = params.loadInput
    local isWrapped = params.isWrapped

    -- Load agreement document and unwrapped input files
    local agreementDoc = TestUtils.loadInputDoc(inputDir .. "/mou" .. (isWrapped and ".wrapped" or "") .. ".json")
    local unwrappedA = loadInput(inputDir .. "/input-partyA" .. (isWrapped and ".wrapped" or "") .. ".json")
    local unwrappedB = loadInput(inputDir .. "/input-partyB" .. (isWrapped and ".wrapped" or "") .. ".json")
    local unwrappedAccept = loadInput(inputDir .. "/input-partyA-accept" .. (isWrapped and ".wrapped" or "") .. ".json")
    local unwrappedReject = loadInput(inputDir .. "/input-partyA-reject" .. (isWrapped and ".wrapped" or "") .. ".json")

    local agreementHash = crypto.digest.keccak256(agreementDoc).asHex()

    -- Initialize DFSM (for unwrapped tests, pass party eth addresses)
    local dfsm
    if isWrapped then
        dfsm = DFSM.new(agreementDoc, expectVc)
    else
        dfsm = DFSM.new(agreementDoc, expectVc, json.decode([[
{
    "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
}
]]))
    end

    print(DFSMUtils.formatFSMSummary(dfsm))
    print(DFSMUtils.renderDFSMState(dfsm))

    -- Helper function to format test input (for unwrapped tests)
    local function formatTestInput(input, inputId, type, values)
        if isWrapped then
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

    -- Valid Party A data – should succeed and transition to PENDING_PARTY_B_SIGNATURE
    TestUtils.runTest(
        "Valid Party A data submission", 
        dfsm, 
        formatTestInput(unwrappedA, unwrappedA.inputId, unwrappedA.type, unwrappedA.values),
        true,  -- expect success
        nil,
        "PENDING_PARTY_B_SIGNATURE",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- Invalid input ID – should fail with unknown input error
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
        testCounter,
        expectVc
    )

    -- Valid Party B data – should succeed and transition to PENDING_ACCEPTANCE
    TestUtils.runTest(
        "Valid Party B data submission", 
        dfsm, 
        formatTestInput(unwrappedB, unwrappedB.inputId, unwrappedB.type, unwrappedB.values),
        true,  -- expect success
        nil,
        "PENDING_ACCEPTANCE",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- Valid acceptance – should succeed and transition to ACCEPTED
    TestUtils.runTest(
        "Valid acceptance submission", 
        dfsm, 
        formatTestInput(unwrappedAccept, unwrappedAccept.inputId, unwrappedAccept.type, unwrappedAccept.values),
        true,  -- expect success
        nil,
        "ACCEPTED",
        DFSMUtils,
        testCounter,
        expectVc
    )

    -- Rejection after completion – should fail because state machine is complete
    TestUtils.runTest(
        "Rejection after completion", 
        dfsm, 
        formatTestInput(unwrappedReject, unwrappedReject.inputId, unwrappedReject.type, unwrappedReject.values),
        false,  -- expect failure
        "State machine is complete",
        "ACCEPTED",  -- state should not change
        DFSMUtils,
        testCounter,
        expectVc
    )
end

-- Run wrapped test suite (using raw loadInputDoc for wrapped inputs)
print("\n=== Running Wrapped Test Suite ===")
runTestSuite({
    inputDir = "./wrapped",
    expectVc = true,
    loadInput = function(path) return TestUtils.loadInputDoc(path) end,
    isWrapped = true
})

-- Print final test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------") 