local Handlers = require("handlers")

local json = require("json")
local Array = require(".crypto.util.array")
local crypto = require(".crypto.init")
local utils = require(".utils")

local DFSM = require("dfsm")


-- BEGIN: actor's internal state
StateMachine = StateMachine or nil
Document = Document or nil
DocumentHash = DocumentHash or nil
DocumentOwner = DocumentOwner or nil
-- END: actor's internal state

local function reply_error(msg, error)
  msg.reply(
  {
    Data = {
      success = false,
      error = error
    }
  })
  print("Error during execution: " .. error)
  -- throwing errors seems to somehow get in the way of msg.reply going through, even though it happens strictly after...
  -- error(error_msg)
end

Handlers.add(
  "Init",
  Handlers.utils.hasMatchingTag("Action", "Init"),
  function (msg)
    -- expecting msg.Data to contain a valid agreement VC
    local document = msg.Data.document
    local initialValues = msg.Data.initialValues

    if Document then
      reply_error(msg, 'Document is already initialized and cannot be overwritten')
      return
    end
    
    local dfsm = DFSM.new(document, false, initialValues)

    if not dfsm then
      reply_error(msg, 'Invalid agreement document')
      return
    end

    Document = document
    DocumentHash = crypto.digest.keccak256(document).asHex()
    StateMachine = dfsm
    -- DocumentOwner = owner_eth_address

    -- -- TODO: validate the signatories list is a valid list of eth addresses?
    -- local signatories = vc_json.credentialSubject.signatories or {}
    -- if #signatories == 0 then
    -- reply_error(msg, 'Must have at least one signatory specified')
    -- return
    -- end

    -- -- forcing lowercase on the received eth addresses to avoid comparison confusion down the road
    -- local sigs_lowercase = utils.map(function(x) return string.lower(x) end)(signatories)
    -- Signatories = sigs_lowercase

    -- -- print("Agreement VC verification result: " .. (is_valid and "VALID" or "INVALID"))

    msg.reply({ Data = { success = true } })
  end
)

Handlers.add(
  "ProcessInput",
  Handlers.utils.hasMatchingTag("Action", "ProcessInput"),
  function (msg)
    local inputId = msg.Data.inputId
    local inputValue = msg.Data.inputValue
    
    if not StateMachine then
      reply_error(msg, 'State machine not initialized')
      return
    end
    
    local isValid, errorMsg = StateMachine:processInput(inputId, inputValue, false)
    
    if not isValid then
      reply_error(msg, errorMsg or 'Failed to process input')
      return
    end
    
    msg.reply({ Data = { success = true } })
  end
)

Handlers.add(
  "GetDocument",
  Handlers.utils.hasMatchingTag("Action", "GetDocument"),
  function (msg)
    msg.reply({ Data = {
        Document = Document,
        DocumentHash = DocumentHash,
        -- DocumentOwner = DocumentOwner,
    }})
  end
)

-- Debug util to retrieve the important local state fields
Handlers.add(
  "GetState",
  Handlers.utils.hasMatchingTag("Action", "GetState"),
  function (msg)
    if not StateMachine then
      reply_error(msg, 'State machine not initialized')
      return
    end

    local state = {
      State = StateMachine:getCurrentState(),
      IsComplete = StateMachine:isComplete(),
      Variables = StateMachine:getVariables(),
      Inputs = StateMachine:getInputs(),
    }
    -- print(state)
    msg.reply({ Data = state })
  end
)

return Handlers