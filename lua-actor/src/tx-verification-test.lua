require("setup")

local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")

-- this imports the DFSM processor code
local DFSM = require("dfsm")
-- Import test utilities
local TestUtils = require("test-utils")

-- TODO: update this test file if we care to have something verifying a Tx with a token transfer

-- Load agreement document from JSON file
local function loadAgreementDoc()
    local file = io.open("./test-data/tx-grant/tx-grant.json", "r")
    if not file then
        error("Could not open agreement document file")
    end
    local content = file:read("*all")
    file:close()
    return content
end

local agreementDoc = loadAgreementDoc()

local dfsm = DFSM.new(agreementDoc, false, json.decode([[
    {
        "grantRecipientAddress": "0xb800B70D15BC235C81D483D19E91e69a91328B98",
        "grantAmount": 68395011620287000,
        "tokenAllocatorAddress": "0xB47855e843c4F9D54408372DA4CA79D20542d168"
    }
]]))

print(DFSMUtils.formatFSMSummary(dfsm))
print(DFSMUtils.renderDFSMState(dfsm))

-- Test counter for tracking results
local testCounter = { count = 0 }

-- Test 1: Valid Party A data - should succeed and transition to PENDING_PARTY_B_SIGNATURE
TestUtils.runTest(
    "Funds sent", 
    dfsm, 
    "fundsSentTx", 
    [[{
        "txHash": "0x9445f933860ef6d65fdaf419fcf8b0749f415c7cd0f82f8b420b10a776c5373e"
    }]],
    true,  -- expect success
    nil,
    "AWAITING_TOKENS",
    DFSMUtils,
    testCounter
)

TestUtils.runTest(
    "Tokens sent", 
    dfsm, 
    "workTokenSentTx", 
    [[{
        "txHash": "0x1cdc44857dd967f99d4644151340b5a083f77e660c60121a7dc63b8b75047f5e"
    }]],
    true,  -- expect success
    nil,
    "APPROVED",
    DFSMUtils,
    testCounter
)

-- Print test summary
print("\n---------------------------------------------")
print("✅ ALL TESTS PASSED: " .. testCounter.count .. " tests completed successfully!")
print("No tests failed (execution would have stopped at first failure)")
print("---------------------------------------------")