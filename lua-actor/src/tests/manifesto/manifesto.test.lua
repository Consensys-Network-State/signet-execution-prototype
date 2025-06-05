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

-- Helper function to run unwrapped test suite
local function runUnwrappedTestSuite()
    local inputDir = "./unwrapped"

    -- Load agreement document and input files
    local agreementDoc = TestUtils.loadInputDoc(inputDir .. "/manifesto.json")
    local aliceSignature = json.decode(TestUtils.loadInputDoc(inputDir .. "/input-alice-signature.json"))
    local bobSignature = json.decode(TestUtils.loadInputDoc(inputDir .. "/input-bob-signature.json"))

    local agreementHash = crypto.digest.keccak256(agreementDoc).asHex()

    -- Initialize DFSM with controller address
    local dfsm = DFSM.new(agreementDoc, false, json.decode([[
{
    "controller": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
}
]]))

    print(DFSMUtils.formatFSMSummary(dfsm))
    print(DFSMUtils.renderDFSMState(dfsm))

    -- Helper function to format test input for unwrapped tests
    local function formatTestInput(inputId, issuerAddress, values)
        return string.format([[{
            "type": "VerifiedCredentialEIP712",
            "issuer": {
                "id": "did:pkh:eip155:1:%s"
            },
            "credentialSubject": {
                "inputId": "%s",
                "type": "signedFields",
                "documentHash": "%s",
                "values": %s
            }
        }]], 
        issuerAddress,
        inputId,
        agreementHash,
        json.encode(values))
    end

    -- Test 1: Verify initial state is INITIALIZED
    local currentStateId = dfsm.currentState and dfsm.currentState.id or "nil"
    if currentStateId ~= "INITIALIZED" then
        error("Expected initial state to be INITIALIZED, but got: " .. tostring(currentStateId))
    end
    print("✅ Initial state is INITIALIZED as expected")

    -- Test 2: Activate manifesto (INITIALIZED -> ACTIVE)
    TestUtils.runTest(
        "Activate manifesto for first time", 
        dfsm, 
        formatTestInput("activate", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", { activation = "ACTIVATE" }),
        true,  -- expect success
        nil,
        "ACTIVE",
        DFSMUtils,
        testCounter,
        false
    )

    -- Test 3: Deactivate manifesto (ACTIVE -> INACTIVE)
    TestUtils.runTest(
        "Deactivate manifesto", 
        dfsm, 
        formatTestInput("deactivate", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", { activation = "DEACTIVATE" }),
        true,  -- expect success
        nil,
        "INACTIVE",
        DFSMUtils,
        testCounter,
        false
    )

    -- Test 4: Try to deactivate again - should fail as already inactive
    TestUtils.runTest(
        "Try to deactivate when already inactive", 
        dfsm, 
        formatTestInput("deactivate", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", { activation = "DEACTIVATE" }),
        false,  -- expect failure
        "No valid transition",
        "INACTIVE",  -- state should not change
        DFSMUtils,
        testCounter,
        false
    )

    -- Test 5: Reactivate manifesto (INACTIVE -> ACTIVE)
    TestUtils.runTest(
        "Reactivate manifesto", 
        dfsm, 
        formatTestInput("activate", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", { activation = "ACTIVATE" }),
        true,  -- expect success
        nil,
        "ACTIVE",
        DFSMUtils,
        testCounter,
        false
    )

    -- Test 6: Alice signs the manifesto (ACTIVE -> ACTIVE)
    TestUtils.runTest(
        "Alice signs the manifesto", 
        dfsm, 
        formatTestInput("signManifesto", aliceSignature.values.signerAddress, aliceSignature.values),
        true,  -- expect success
        nil,
        "ACTIVE",  -- state remains ACTIVE
        DFSMUtils,
        testCounter,
        false
    )

    -- Test 7: Bob signs the manifesto (ACTIVE -> ACTIVE)
    TestUtils.runTest(
        "Bob signs the manifesto", 
        dfsm, 
        formatTestInput("signManifesto", bobSignature.values.signerAddress, bobSignature.values),
        true,  -- expect success
        nil,
        "ACTIVE",  -- state remains ACTIVE
        DFSMUtils,
        testCounter,
        false
    )

    -- Test 8: Invalid input ID – should fail with unknown input error
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
        "ACTIVE",  -- state should not change
        DFSMUtils,
        testCounter,
        false
    )

    -- Test 9: Invalid issuer (not controller) - should fail
    TestUtils.runTest(
        "Invalid issuer (not controller)", 
        dfsm, 
        formatTestInput("deactivate", "0x1234567890123456789012345678901234567890", { activation = "DEACTIVATE" }),
        false,  -- expect failure
        "Issuer mismatch",
        "ACTIVE",  -- state should not change
        DFSMUtils,
        testCounter,
        false
    )
end

-- Run unwrapped test suite
print("\n=== Running Unwrapped Test Suite ===")
runUnwrappedTestSuite()

-- TODO: Wrapped testing commented out for now
-- print("\n=== Running Wrapped Test Suite ===")
-- runWrappedTestSuite()

-- Print final test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------") 