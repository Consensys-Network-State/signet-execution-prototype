require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")
local crypto = require(".crypto.init")

local agreementDoc = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.wrapped.json")
local inputA = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.partyA-input.wrapped.json")
local inputB = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.partyB-input.wrapped.json")
local inputAAccept = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.partyA-input-accept.wrapped.json")
local inputATxProof = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.partyA-tx-proof.wrapped.json")

-- Extract the agreement hash from the wrapped agreement document
local decodedAgreement = json.decode(agreementDoc)
local agreementBase64 = decodedAgreement.credentialSubject.agreement
-- Convert to string for hashing if needed
local agreementHash = crypto.digest.keccak256(agreementBase64).asHex()

local expectVc = true
local dfsm = DFSM.new(agreementDoc, expectVc)

print(DFSMUtils.formatFSMSummary(dfsm))
print(DFSMUtils.renderDFSMState(dfsm))

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Test 1: Valid Party A data - should succeed and transition to AWAITING_RECIPIENT_SIGNATURE
TestUtils.runTest(
    "Valid Party A data submission", 
    dfsm,
    inputA,
    true,  -- expect success
    nil,
    "AWAITING_RECIPIENT_SIGNATURE", -- specify expected state for clarity
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 2: Valid Party B data - should succeed and transition to AWAITING_GRANTOR_SIGNATURE
TestUtils.runTest(
    "Valid Party B data submission",
    dfsm,
    inputB,
    true,  -- expect success
    nil,
    "AWAITING_GRANTOR_SIGNATURE",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 3: Valid acceptance - should succeed and transition to AWAITING_WORK_SUBMISSION
TestUtils.runTest(
    "Valid acceptance submission", 
    dfsm,
    inputAAccept,
    true,  -- expect success
    nil,
    "AWAITING_WORK_SUBMISSION",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 4: Tokens sent - should succeed and transition to WORK_ACCEPTED_AND_PAID
TestUtils.runTest(
    "Tokens sent", 
    dfsm,
    inputATxProof,
    true,  -- expect success
    nil,
    "WORK_ACCEPTED_AND_PAID",
    DFSMUtils,
    testCounter,
    expectVc
)

-- Test 5: Rejection case - testing from an alternative starting point
-- local rejectionDfsm = DFSM.new(agreementDoc, false, json.decode([[
-- {
--     "partyAEthAddress": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
--     "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
--     "grantAmount": 100,
--     "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
-- }
-- ]]))

-- -- Run tests to bring to PENDING_ACCEPTANCE state
-- TestUtils.runTest(
--     "Valid Party A data submission (for rejection test)", 
--     rejectionDfsm, 
--     "partyAData", 
--     [[{
--         "type": "VerifiedCredentialEIP712",
--         "issuer": {
--             "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
--         },
--         "credentialSubject": {
--             "id": "partyAData",
--             "type": "signedFields",
--             "values": {
--                 "partyAName": "Damian",
--                 "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
--             }
--         }
--     }]],
--     true,  -- expect success
--     nil,
--     "PENDING_PARTY_B_SIGNATURE",
--     DFSMUtils,
--     testCounter
-- )

-- TestUtils.runTest(
--     "Valid Party B data submission (for rejection test)", 
--     rejectionDfsm, 
--     "partyBData", 
--     [[{
--         "type": "VerifiedCredentialEIP712",
--         "issuer": {
--             "id": "did:pkh:eip155:1:0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
--         },
--         "credentialSubject": {
--             "id": "partyBData",
--             "type": "signedFields",
--             "values": {
--                 "partyBName": "Leif"
--             }
--         }
--     }]],
--     true,  -- expect success
--     nil,
--     "PENDING_ACCEPTANCE",
--     DFSMUtils,
--     testCounter
-- )

-- -- Now test rejection
-- TestUtils.runTest(
--     "Party A rejects the agreement", 
--     rejectionDfsm, 
--     "rejected", 
--     [[{
--         "type": "VerifiedCredentialEIP712",
--         "issuer": {
--             "id": "did:pkh:eip155:1:0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
--         },
--         "credentialSubject": {
--             "id": "rejected",
--             "type": "signedFields",
--             "values": {
--                 "partyARejection": "REJECTED"
--             }
--         }
--     }]],
--     true,  -- expect success
--     nil,
--     "REJECTED",
--     DFSMUtils,
--     testCounter
-- )

-- -- Test 7: Invalid input - should fail with error
-- TestUtils.runTest(
--     "Invalid input ID", 
--     rejectionDfsm,
--     "invalidInput", 
--     [[{
--         "someValue": true
--     }]],
--     false,  -- expect failure
--     "State machine is complete",
--     "REJECTED", -- state should not change
--     DFSMUtils,
--     testCounter
-- )

-- Print test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------")