require("setup")

local TestUtils = require("test-utils")
local json = require("json")

local Handlers = require("apoc-v2-bundled")

local agreementDoc = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.wrapped.json")
local inputA = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.partyA-input.wrapped.json")
local inputB = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.partyB-input.wrapped.json")
local inputAAccept = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.partyA-input-accept.wrapped.json")
local inputATxProof = TestUtils.loadInputDoc("./test-data/grant-with-tx/grant-with-tx.partyA-tx-proof.wrapped.json")

-- Evaluate a message
local response = Handlers.evaluate({
    Tags = { Action = 'Init' },
    Data = agreementDoc,
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Init message processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "partyAData",
        inputValue = json.decode(inputA)
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Party A Data processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "partyAData",
        inputValue = json.decode(inputA)
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      -- print("Party A Data duplicate processing:", success)
      print(TestUtils.formatResult(not success) .. " Party A Data duplicate processing")
      assert(success == false)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "invalidInput",
        inputValue = {
            someValue = true
        }
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print(TestUtils.formatResult(not success) .. " Invalid input processing")
      assert(success == false)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "partyBData",
        inputValue = json.decode(inputB)
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Party B Data processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)


response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "accepted",
        inputValue = json.decode(inputAAccept)
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      -- print("Accept signature processing:", success)
      print(TestUtils.formatResult(success) .. " Accept signature processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "workTokenSentTx",
        inputValue = json.decode(inputATxProof)
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print(TestUtils.formatResult(success) .. " Work token sent tx processing")
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'GetState' },
    Data = json.encode({}),
    reply = function (response)
      -- printTable(response.Data)
      local state = response.Data.State
      local isComplete = response.Data.IsComplete
      assert(isComplete == true)
      assert(state.id == "PAYMENT_CONFIRMED")
      print(TestUtils.formatResult(true) .. " Final state check")
    end
    },
    { envKey = "envValue" }
)

