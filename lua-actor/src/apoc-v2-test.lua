require("setup")

local TestUtils = require("test-utils")
local tablesEqual = TestUtils.tablesEqual
local printTable = TestUtils.printTable
local printResult = TestUtils.formatResult
local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")

local Handlers = require("apoc-v2-bundled")

-- Load agreement document from JSON file
local function loadInputDoc(path)
    local file = io.open(path, "r")
    if not file then
        error("Could not open agreement document file")
    end
    local content = file:read("*all")
    file:close()
    return content
end

local agreementDoc = loadInputDoc("./test-data/simple-grant/simple.grant.wrapped.json")
local inputA = loadInputDoc("./test-data/simple-grant/simple.grant.partyA-input.wrapped.json")
local inputB = loadInputDoc("./test-data/simple-grant/simple.grant.partyB-input.wrapped.json")
local inputAAccept = loadInputDoc("./test-data/simple-grant/simple.grant.partyA-input-accept.wrapped.json")
local inputAReject = loadInputDoc("./test-data/simple-grant/simple.grant.partyA-input-reject.wrapped.json")


-- Evaluate a message
local response = Handlers.evaluate({
    Tags = { Action = 'Init' },
    Data = json.encode(agreementDoc),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print("Init message processing:", success)
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "partyAData",
        inputValue = inputA
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print("Party A Data processing:", success)
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "partyAData",
        inputValue = inputA
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print("Party A Data duplicate processing:", success)
      assert(success == false)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "invalidInput",
        inputValue = [[{
            "someValue": true
        }]]
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print("Invalid input processing:", success)
      assert(success == false)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "partyBData",
        inputValue = inputB
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print("Party B Data processing:", success)
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)


response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "accepted",
        inputValue = inputAAccept
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print("Accept signature processing:", success)
      assert(success == true)
    end
    },
    { envKey = "envValue" }
)

response = Handlers.evaluate({
    Tags = { Action = 'ProcessInput' },
    Data = json.encode({
        inputId = "rejected",
        inputValue = inputAReject
    }),
    reply = function (response)
      -- printTable(response.Data)
      local success = response.Data.success
      print("Accept signature processing:", success)
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
    end
    },
    { envKey = "envValue" }
)

