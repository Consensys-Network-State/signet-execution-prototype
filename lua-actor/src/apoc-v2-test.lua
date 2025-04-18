require("setup")

local TestUtils = require("test-utils")
local tablesEqual = TestUtils.tablesEqual
local printTable = TestUtils.printTable
local printResult = TestUtils.formatResult
local DFSMUtils = require("utils.dfsm_utils")
local json = require("json")

local Handlers = require("apoc-v2")

-- Load agreement document from JSON file
local function loadAgreementDoc()
    local file = io.open("./test-data/simple-grant/simple.grant.json", "r")
    if not file then
        error("Could not open agreement document file")
    end
    local content = file:read("*all")
    file:close()
    return content
end

local agreementDoc = loadAgreementDoc()

-- Evaluate a message
local response = Handlers.evaluate({
    Tags = { Action = 'Init' },
    Data = json.encode({
        document = agreementDoc,
        initialValues = { partyAEthAddress = "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4" }
    }),
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
        inputValue = [[
            {
                "type": "VerifiedCredentialEIP712",
                "issuer": "${partyAEthAddress}",
                "credentialSubject": {
                    "id": "partyAData",
                    "type": "signedFields",
                    "values": {
                        "partyAName": "Damian"
                    }
                }
            }
        ]]
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
        inputValue = [[
            {
                "type": "VerifiedCredentialEIP712",
                "issuer": "${partyAEthAddress}",
                "credentialSubject": {
                    "id": "partyAData",
                    "type": "signedFields",
                    "values": {
                        "partyAName": "Damian"
                    }
                }
            }
        ]]
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
        inputValue = [[
            {
                "type": "VerifiedCredentialEIP712",
                "issuer": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",
                "credentialSubject": {
                    "id": "partyBData",
                    "type": "signedFields",
                    "values": {
                        "partyBName": "Leif",
                        "partyBEthAddress": "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"
                    }
                }
            }
        ]]
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
        inputValue = [[
            {
                "type": "VerifiedCredentialEIP712",
                "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
                "credentialSubject": {
                    "id": "accepted",
                    "type": "signedFields",
                    "values": {
                        "partyAAcceptance": "ACCEPTED"
                    }
                }
            }
        ]]
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
        inputValue = [[
            {
                "type": "VerifiedCredentialEIP712",
                "issuer": "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
                "credentialSubject": {
                    "id": "rejected",
                    "type": "signedFields",
                    "values": {
                        "partyARejection": "REJECTED"
                    }
                }
            }
        ]]
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
      assert(state == "ACCEPTED")
    end
    },
    { envKey = "envValue" }
)

