require("setup")

local TestUtils = require("test-utils")
local json = require("json")

local Handlers = require("apoc-v2-bundled")

-- Load all test input files
local agreementDoc = TestUtils.loadInputDoc("./tests/grant-with-tx/grant-with-tx.wrapped.json")
local inputA = TestUtils.loadInputDoc("./tests/grant-with-tx/grant-with-tx.grantor-input.wrapped.json")
local inputB = TestUtils.loadInputDoc("./tests/grant-with-tx/grant-with-tx.recipient-input.wrapped.json")
local inputAAccept = TestUtils.loadInputDoc("./tests/grant-with-tx/grant-with-tx.grantor-accept.wrapped.json")
local workSubmission = TestUtils.loadInputDoc("./tests/grant-with-tx/grant-with-tx.work-submission.wrapped.json")
local workAccept = TestUtils.loadInputDoc("./tests/grant-with-tx/grant-with-tx.work-accept.wrapped.json")
local inputATxProof = TestUtils.loadInputDoc("./tests/grant-with-tx/grant-with-tx.grantor-tx-proof.wrapped.json")

-- Initialize the agreement
local response = Handlers.evaluate({
    Tags = { Action = 'Init' },
    Data = agreementDoc,
    reply = function (response)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Init message processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

-- Step 1: Grantor data submission
response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputValue = json.decode(inputA)
    }),
    reply = function (response)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Grantor data processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

-- Step 2: Recipient data submission
response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputValue = json.decode(inputB)
    }),
    reply = function (response)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Recipient data processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

-- Step 3: Grantor acceptance
response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputValue = json.decode(inputAAccept)
    }),
    reply = function (response)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Grantor acceptance processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

-- Step 4: Work submission
response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputValue = json.decode(workSubmission)
    }),
    reply = function (response)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Work submission processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

-- Step 5: Work acceptance
response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputValue = json.decode(workAccept)
    }),
    reply = function (response)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Work acceptance processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

-- Step 6: Payment proof
response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputValue = json.decode(inputATxProof)
    }),
    reply = function (response)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Payment proof processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

-- Final state check
response = Handlers.evaluate({
    Tags = { Action = 'GetState' },
    Data = json.encode({}),
    reply = function (response)
      local state = response.Data.State
      local isComplete = response.Data.IsComplete
      assert(isComplete == true)
      assert(state.id == "WORK_ACCEPTED_AND_PAID")
      print(TestUtils.formatResult(true) .. " Final state check")
    end
    },
    { envKey = "envValue" }
)

print("\n---------------------------------------------")
print("✅ Happy path test completed successfully!")
print("---------------------------------------------")

