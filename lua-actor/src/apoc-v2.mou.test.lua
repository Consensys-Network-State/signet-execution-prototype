require("setup")

local TestUtils = require("test-utils")
local tablesEqual = TestUtils.tablesEqual
local printTable = TestUtils.printTable
local printResult = TestUtils.formatResult
local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")

local Handlers = require("apoc-v2-bundled")

local agreementDoc = TestUtils.loadInputDoc("./tests/mou/wrapped/mou.wrapped.json")
local inputA = TestUtils.loadInputDoc("./tests/mou/wrapped/input-partyA.wrapped.json")
local inputB = TestUtils.loadInputDoc("./tests/mou/wrapped/input-partyB.wrapped.json")
local inputAAccept = TestUtils.loadInputDoc("./tests/mou/wrapped/input-partyA-accept.wrapped.json")
local inputAReject = TestUtils.loadInputDoc("./tests/mou/wrapped/input-partyA-reject.wrapped.json")


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
        inputValue = inputAAccept
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
        inputId = "rejected",
        inputValue = json.decode(inputAReject)
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print(TestUtils.formatResult(not success) .. " Accept signature duplicate processing")
      assert(success == false)
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
      assert(state.id == "ACCEPTED")
      print(TestUtils.formatResult(true) .. " Final state check")
    end
    },
    { envKey = "envValue" }
)

