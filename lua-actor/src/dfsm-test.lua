require("setup")

local TestUtils = require("test-utils")
local tablesEqual = TestUtils.tablesEqual
local printTable = TestUtils.printTable
local printResult = TestUtils.formatResult
local json = require("json")
-- this imports the DFSM processor code
local DFSM = require("dfsm")

-- Format DFSM summary
local function formatFSMSummary(dfsm)
  -- Format variables
  local variablesStr = {}
  local variables = dfsm:getVariables()
  for id, var in pairs(variables) do
    table.insert(variablesStr, string.format("- %s: %s", var.name, tostring(var.value)))
  end

  local summary = {
    "\nDoc Summary:\n",
    string.format("Input Variables:\n%s", table.concat(variablesStr, "\n")),
    "\nDFSM Summary:\n",
    string.format("- States: %d", #dfsm.states),
    string.format("- Transitions: %d", #dfsm.transitions),
    string.format("- Inputs: %d", #dfsm.inputs),
    string.format("- Current State: %s", dfsm.currentState),
    string.format("- Complete: %s", dfsm.isComplete and "Yes" or "No")
  }

  return table.concat(summary, "\n")
end

-- Format DFSM state
local function formatFSMState(dfsm)
  local summary = {
    "\nDFSM State:\n",
    string.format("- Current State: %s", dfsm.currentState),
    string.format("- Complete: %s", dfsm.isComplete and "Yes" or "No")
  }

  return table.concat(summary, "\n")
end

-- Load agreement document from JSON file
local function loadAgreementDoc()
    local file = io.open("../externals/agreements-protocol/templates/grant-agreement.md.dfsm.json", "r")
    if not file then
        error("Could not open agreement document file")
    end
    local content = file:read("*all")
    file:close()
    return content
end

local agreementDoc = loadAgreementDoc()
local dfsm = DFSM.new(json.decode(agreementDoc))

print(formatFSMSummary(dfsm))

dfsm:processInput("grantRecipientSignature", json.decode([[{
    "isGrantRecipientApproved": true
}]]))

print(formatFSMState(dfsm))

assert(true == true)