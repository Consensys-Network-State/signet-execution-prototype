require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")

-- Load agreement document from JSON file
local inputDir = "./wrapped"
local agreementDoc = TestUtils.loadInputDoc(inputDir .. "/simple.grant.wrapped.json")
local inputA = TestUtils.loadInputDoc(inputDir .. "/simple.grant.partyA-input.wrapped.json")
local inputB = TestUtils.loadInputDoc(inputDir .. "/simple.grant.partyB-input.wrapped.json")
local inputAAccept = TestUtils.loadInputDoc(inputDir .. "/simple.grant.partyA-input-accept.wrapped.json")
local inputAReject = TestUtils.loadInputDoc(inputDir .. "/simple.grant.partyA-input-reject.wrapped.json")

local dfsm = DFSM.new(agreementDoc, true)

print(DFSMUtils.formatFSMSummary(dfsm))
print(DFSMUtils.renderDFSMState(dfsm))

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Note: In the original implementation, validateVC was set to true
-- while in TestUtils.runTest it's set to false. If validation is needed,
-- the TestUtils.runTest function would need to be modified.

-- Test 1: Valid Party A data - should succeed
TestUtils.runTest(
    "Valid Party A data submission", 
    dfsm, 
    inputA,
    true,  -- expect success
    nil,
    nil,   -- we don't specify expected state for wrapped version
    DFSMUtils,
    testCounter
)

-- Test 3: Invalid input ID - should fail with unknown input error
TestUtils.runTest(
    "Invalid input ID", 
    dfsm, 
    [[{
        "credentialSubject": {
          "inputId": "invalidInput",
          "someValue": true
        }
    }]],
    false,  -- expect failure
    "Unknown input",
    nil,   -- state should not change
    DFSMUtils,
    testCounter
)

-- Test 4: Valid Party B data - should succeed
TestUtils.runTest(
    "Valid Party B data submission", 
    dfsm,
    inputB,
    true,  -- expect success
    nil,
    nil,
    DFSMUtils,
    testCounter
)

-- Test 5: Valid acceptance - should succeed
TestUtils.runTest(
    "Valid acceptance submission", 
    dfsm,
    inputAAccept,
    true,  -- expect success
    nil,
    nil,
    DFSMUtils,
    testCounter
)

-- Test 6: Rejection after acceptance - should fail because inputs conflict
TestUtils.runTest(
    "Attempting rejection after acceptance", 
    dfsm, 
    inputAReject,
    false,  -- expect failure
    "State machine is complete",
    nil,
    DFSMUtils,
    testCounter
)

-- Print test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------")