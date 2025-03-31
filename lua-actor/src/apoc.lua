-- require("setup")

-- Need to explicitly require to have this in scope. In AO env, it's a global.
local Handlers = require("handlers")
-- Also explicitly importing secp256k1 and exposing recover_public_key, which is a global var in our custom AO module.
local secp256k1 = require("secp256k1")
local recover_public_key = secp256k1.recover_public_key

-- ==================================
-- ====== BEGIN Our Actor Code ======
-- ==================================

local json = require("json")
local Array = require(".crypto.util.array")
local crypto = require(".crypto.init")
local utils = require(".utils")

-- ==============================
-- ====== BEGIN eip712.lua ======
-- ==============================

-- Forward declarations for functions with circular dependencies
local encodeParameter
local isDynamicType
local encodeField
local encodeData
local hashStruct

local function padLeft(str, length, char)
    char = char or '0'
    local padding = string.rep(char, length - #str)
    return padding .. str
end

-- Basic type encoders
local function encodeUint256(value)
    local hex = string.format("%x", value)
    return padLeft(hex, 64)
end

local function encodeAddress(value)
    value = string.gsub(value, "^0x", "")
    return padLeft(value, 64)
end

local function encodeBool(value)
    return encodeUint256(value and 1 or 0)
end

local function encodeBytes(value)
  local length = encodeUint256(#value)
  local paddedData = value .. string.rep(string.char(0), (32 - (#value % 32)) % 32)
  return length .. paddedData
end

local function encodeFixedBytes(value, size)
    if #value > size * 2 then -- hex string expected, 2 hex chars per byte
        error(string.format("Value too long for bytes%d: got %d bytes", size, #value))
    end
    return value .. string.rep(string.char(0), size - #value)
end

local function encodeString(value)
    local bytes = string.char(string.byte(value, 1, -1))
    return encodeBytes(bytes)
end

local function encodeArray(baseType, array, size)
    local result = ""
    if #size == 0 then
        result = encodeUint256(#array)
    end
    
    for _, value in ipairs(array) do
        result = result .. encodeParameter(baseType, value)
    end
    
    return result
end

function isDynamicType(typ)
    -- Check for basic dynamic types
    if typ == "string" or typ == "bytes" then
        return true
    end
    
    -- Check for fixed-size bytes (bytes1 to bytes32)
    local bytesMatch = string.match(typ, "^bytes(%d+)$")
    if bytesMatch then
        local size = tonumber(bytesMatch)
        if size then
            return false  -- Fixed-size bytes are static
        end
        error("Invalid bytes size: " .. bytesMatch)
    end
    
    -- Check for arrays - pattern needs to handle the full type including numbers
    local baseType, size = string.match(typ, "^([%a%d]+)%[(%d*)%]$")
    if baseType then
        -- Dynamic if it's an unbounded array or contains dynamic types
        return #size == 0 or isDynamicType(baseType)
    end
    
    return false
end

-- Parameter encoding
function encodeParameter(typ, value)
    if typ == "uint256" then
        return encodeUint256(value)
    elseif typ == "address" then
        return encodeAddress(value)
    elseif typ == "bool" then
        return encodeBool(value)
    elseif typ == "string" then
        return encodeString(value)
    elseif typ == "bytes" then
        return encodeBytes(value)
    end
    
    -- Handle fixed-size bytes
    local bytesMatch = string.match(typ, "^bytes(%d+)$")
    if bytesMatch then
        local size = tonumber(bytesMatch)
        if size then
            return encodeFixedBytes(value, size)
        end
    end

    local baseType, size = string.match(typ, "^([%a%d]+)%[(%d*)%]$")
    if baseType then
        return encodeArray(baseType, value, size)
    end
    
    error("Unsupported type: " .. typ)
end

-- ABI encoding
local function abiEncode(types, values)
    local headLength = 0
    local heads = {}
    local tails = {}
    local dynamicCount = 0
    
    for i, typ in ipairs(types) do
        local value = values[i]
        
        if isDynamicType(typ) then
            table.insert(heads, "")
            dynamicCount = dynamicCount + 1
        else
            local encoded = encodeParameter(typ, value)
            table.insert(heads, encoded)
        end
        
        headLength = headLength + 32
    end
    
    local currentDynamicPointer = headLength
    for i, typ in ipairs(types) do
        if isDynamicType(typ) then
            local value = values[i]
            local encoded = encodeParameter(typ, value)
            
            heads[i] = encodeUint256(currentDynamicPointer)
            table.insert(tails, encoded)
            
            currentDynamicPointer = currentDynamicPointer + #encoded
        end
    end
    
    return table.concat(heads) .. table.concat(tails)
end

-- EIP-712 specific functions
local function keccak256(input)
    return crypto.digest.keccak256(input).asHex()
end

local function findTypeDependencies(typeName, types, deps)
    deps = deps or {}
    
    if not deps[typeName] then
        deps[typeName] = true
        
        for _, field in ipairs(types[typeName]) do
            local match = string.match(field.type, "^([A-Z][A-Za-z0-9]*)$")
            if match then
                findTypeDependencies(match, types, deps)
            end
        end
    end
    
    local result = {}
    for dep in pairs(deps) do
        table.insert(result, dep)
    end
    return result
end

local function encodeParameters(type)
    local params = {}
    for _, param in ipairs(type) do
        table.insert(params, param.type .. " " .. param.name)
    end
    return table.concat(params, ",")
end

local function encodeType(typeName, types)
    local deps = findTypeDependencies(typeName, types)
    local index
    for i, v in ipairs(deps) do
        if v == typeName then
            index = i
            break
        end
    end
    table.remove(deps, index)
    table.sort(deps)
    table.insert(deps, 1, typeName)
    
    local encodedTypes = ""
    for _, dep in ipairs(deps) do
        local type = types[dep]
        encodedTypes = encodedTypes .. dep .. "(" .. encodeParameters(type) .. ")"
    end
    
    return encodedTypes
end

local function typeHash(typeName, types)
    return keccak256(encodeType(typeName, types))
end

function encodeField(type, value, types)
    if types[type] then
        -- value is of a nested type
        return {
            type = "bytes32",
            value = hashStruct(type, value, types)
        }
    end
    -- Handle arrays
    local baseType = string.match(type, "^([%a%d]+)%[(%d*)%]$")
    if baseType then
        local types = {}
        local values = {}
        
        -- Process each array item through encodeField to handle type conversion
        for _, item in ipairs(value or {}) do
            local itemEncoded = encodeField(baseType, item, types)
            -- For values already encoded as bytes32, use them directly
            if itemEncoded.type == "bytes32" then
                table.insert(types, itemEncoded.type)
                table.insert(values, itemEncoded.value)
            else
                -- For other types, encode and hash them
                table.insert(types, 'bytes32')
                local itemAbiEncoded = abiEncode({itemEncoded.type}, {itemEncoded.value})
                local itemAbiEncodeBytes = Array.fromHex(itemAbiEncoded)
                local itemEncodedBunaryStr = Array.toString(itemAbiEncodeBytes)
                table.insert(values, keccak256(itemEncodedBunaryStr))
            end
        end
        
        -- Array values are already bytes32, just encode them as an array and hash
        local apiEncoded = abiEncode(types, values)
        local abiEncodeBytes = Array.fromHex(apiEncoded)
        local apiEncodedBunaryStr = Array.toString(abiEncodeBytes)
        return {
            type = "bytes32",
            value = keccak256(apiEncodedBunaryStr)
        }
    end
    
    -- Handle structs
    if string.match(type, "^[A-Z]") then
        return {
            type = "bytes32",
            value = keccak256(encodeData(type, value, types))
        }
    end

    -- Handle strings by hashing them to bytes32
    if type == "string" then
        return {
            type = "bytes32",
            value = keccak256(value or "")
        }
    end

    -- Handle basic types
    return {
        type = type,
        value = value
    }
end

local function getDefaultValue(typ)
    -- Handle basic types
    if typ == "uint256" or typ == "int256" then
        return 0
    elseif typ == "address" then
        return "0x0000000000000000000000000000000000000000"
    elseif typ == "bool" then
        return false
    elseif typ == "string" then
        return ""
    elseif typ == "bytes" then
        return ""
    end
    
    -- Handle fixed-size bytes
    local bytesMatch = string.match(typ, "^bytes(%d+)$")
    if bytesMatch then
        local n = tonumber(bytesMatch)
        if n then
            local size = math.floor(n)
            return string.rep("\0", size)
        end
        error("Invalid bytes size: " .. bytesMatch)
    end
    
    -- Handle arrays
    local baseType = string.match(typ, "^([%a%d]+)%[")
    if baseType then
        return {}
    end
    
    -- Handle structs (starting with uppercase)
    if string.match(typ, "^[A-Z]") then
        return {}
    end
    
    error("Unsupported type for default value: " .. typ)
end

function encodeData(typeName, data, types)
    local encTypes = {}
    local encValues = {}
    
    table.insert(encTypes, "bytes32")
    table.insert(encValues, typeHash(typeName, types))
    
    for _, field in ipairs(types[typeName]) do
        local value = data[field.name]
        if value == nil then
            value = getDefaultValue(field.type)
        end
        local encoded = encodeField(field.type, value, types)
        table.insert(encTypes, encoded.type)
        table.insert(encValues, encoded.value)
    end
    
    local abiEncodedData = abiEncode(encTypes, encValues)
    return abiEncodedData
end

function hashStruct(primaryType, data, types)
    local encodedData = encodeData(primaryType, data, types)
    local bytes = Array.fromHex(encodedData)
    local binary_string = Array.toString(bytes)
    return keccak256(binary_string)
end

local function getSigningInput(domainSeparator, structHash)
    local fullInputHexString = '1901' .. domainSeparator .. structHash
    local fullInputBytes = Array.fromHex(fullInputHexString)
    local fullInputBinaryStr = Array.toString(fullInputBytes)
    return keccak256(fullInputBinaryStr)
end

local function createDomainSeparator(domain)
    local domainData = {
        name = domain.name,
        version = domain.version,
        chainId = domain.chainId,
        -- verifyingContract = domain.verifyingContract
    }
    
    return hashStruct("EIP712Domain", domainData, {
        EIP712Domain = {
            {name = "name", type = "string"},
            {name = "version", type = "string"},
            {name = "chainId", type = "uint256"},
            -- {name = "verifyingContract", type = "address"}
        }
    })
end

local eip712 = { -- pretend export and import statements all in one line
    createDomainSeparator = createDomainSeparator,
    hashStruct = hashStruct,
    getSigningInput = getSigningInput,
    encodeType = encodeType,
    typeHash = typeHash,
    abiEncode = abiEncode
}

-- ==============================
-- ======= END eip712.lua =======
-- ==============================

-- ==============================
-- ====== BEGIN es256k.lua ======
-- ==============================

local function strip_hex_prefix(hex_str)
  if hex_str:sub(1, 2) == "0x" then
    return hex_str:sub(3)
  end
  return hex_str
end

local function pubkey_to_eth_address(pubkey_hex)
  if #pubkey_hex ~= 130 or pubkey_hex:sub(1, 2) ~= '04' then
    error('toEthereumAddress: Expecting an uncompressed public key')
  end
  local pubkey_hex_clean = pubkey_hex:sub(3) -- dropping the leading '04' indicating an uncompressed public key format
  local pubkey_binary_bytes = Array.fromHex(pubkey_hex_clean)
  local pubkey_binary_str = Array.toString(pubkey_binary_bytes)
  local keccak_hash = crypto.digest.keccak256(pubkey_binary_str).asHex()
  return '0x'..string.sub(keccak_hash, -40, -1); -- last 40 hex chars, aka 20 bytes
end

local function decode_signature(signature)
  local sanitized_sig = strip_hex_prefix(signature)

  if #sanitized_sig ~= 130 then
    error("Invalid signature length: expected 130 hex chars (65 bytes)")
  end

  return sanitized_sig
end

local function string_split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function get_authority(issuer)
  local eth_address = nil
  if (issuer) then
    local parts = string_split(issuer, ':')
    -- eg. 'did:pkh:eip155:1:0x1e8564A52fc67A68fEe78Fc6422F19c07cFae198'
    if (parts[1] == 'did' and parts[2] == 'pkh' and parts[3] == 'eip155' and parts[4] == '1') then
      eth_address = parts[5]
    else
      error('Only supporting did:pkh issuers')
    end
    return string.lower(eth_address or '')
  end
  error('No issuer found')
end

local function vc_validate(vc)
  local vc_json = json.decode(vc)
  local owner_eth_address = get_authority(vc_json.issuer.id)
  local proof = vc_json.proof
  local proofValue = nil
  local signature_hex = nil
  if proof.type == 'EthereumEip712Signature2021' then
    proofValue = proof.proofValue
    signature_hex = decode_signature(proofValue)
  else
    error('Only supporting EthereumEip712Signature2021 proof type')
  end

  local eip712data = vc_json.proof.eip712
  local domain = eip712data.domain
  local types = eip712data.types
  local primaryType = eip712data.primaryType
  local domainSeparator = eip712.createDomainSeparator(domain)

  local message = Array.copy(vc_json)
  local proof_copy = Array.copy(vc_json.proof)
  proof_copy.proofValue = nil
  proof_copy.eip712 = nil
  proof_copy.eip712Domain = nil
  message.proof = proof_copy

  local structHash = eip712.hashStruct(primaryType, message, types)
  local signingInput = eip712.getSigningInput(domainSeparator, structHash)
  -- given a 65-byte signature (containing an extra recovery byte), and only the ethereum address of the signer, we verify the signature
  -- by pefrorming the recovery of the public key from the signature, then derriving from it the owner ethereum address,
  -- and finally matching that address against the expected owner address.
  -- print('signingInput: "'..signingInput..'", signature_hex: "'..signature_hex..'"')
  local pubkey_hex = recover_public_key(signature_hex, signingInput) -- using the global function provided by our custom wasm module
  local eth_address = pubkey_to_eth_address(pubkey_hex)
  local success = eth_address == owner_eth_address

  return success, vc_json, owner_eth_address
end

-- ==============================
-- ======= END es256k.lua =======
-- ==============================

-- BEGIN: actor's internal state
Document = Document or nil
DocumentHash = DocumentHash or nil
DocumentOwner = DocumentOwner or nil
Signatories = Signatories or {}
Signatures = Signatures or {}
IsComplete = IsComplete or false
-- END: actor's internal state

local function all_signatories_signed(signatories, signatures)
  for _, value in ipairs(signatories) do
      if not signatures[value] then
          return false
      end
  end
  return true
end

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
    local document = msg.Data

    if Document then
      reply_error(msg, 'Document is already initialized and cannot be overwritten')
      return
    end
    
    local is_valid, vc_json, owner_eth_address = vc_validate(document)

    if is_valid then
      Document = document
      DocumentHash = crypto.digest.keccak256(document).asHex()
      DocumentOwner = owner_eth_address

      -- TODO: validate the signatories list is a valid list of eth addresses?
      local signatories = vc_json.credentialSubject.signatories or {}
      if #signatories == 0 then
        reply_error(msg, 'Must have at least one signatory specified')
        return
      end

      -- forcing lowercase on the received eth addresses to avoid comparison confusion down the road
      local sigs_lowercase = utils.map(function(x) return string.lower(x) end)(signatories)
      Signatories = sigs_lowercase
    end

    -- print("Agreement VC verification result: " .. (is_valid and "VALID" or "INVALID"))

    msg.reply({ Data = { success = is_valid } })
  end
)

Handlers.add(
  "Sign",
  Handlers.utils.hasMatchingTag("Action", "Sign"),
  function (msg)
    if IsComplete then
      reply_error(msg, 'The agreement has completed signing.')
      return
    end
    -- expecting msg.Data to contain a valid Areement Signature VC
    local signature_vc = msg.Data
    local is_valid, vc_json, owner_eth_address = vc_validate(signature_vc)
    
    if is_valid then
      -- validate that the VC comes from one of the expected signatories
      if utils.includes(owner_eth_address)(Signatories) then
        local sig_document_hash = strip_hex_prefix(vc_json.credentialSubject.documentHash or '')
        if sig_document_hash ~= DocumentHash then
          reply_error(msg, "Signature VC does not contain a matching documentHash: '" .. DocumentHash .. "'")
          return
        end
        Signatures[owner_eth_address] = signature_vc
      else
        reply_error(msg, "Signature VC from unexpected signatory: '" .. owner_eth_address .. "'")
        return
      end

      if all_signatories_signed(Signatories, Signatures) then
        IsComplete = true
      end
    end
    -- print("Signature VC verification result: " .. (is_valid and "VALID" or "INVALID"))

    msg.reply({ Data = { success = is_valid } })
  end
)

-- Debug util to retrieve the important local state fields
Handlers.add(
  "GetState",
  Handlers.utils.hasMatchingTag("Action", "GetState"),
  function (msg)
    local state = {
      Document = Document,
      DocumentHash = DocumentHash,
      DocumentOwner = DocumentOwner,
      Signatories = Signatories,
      Signatures = Signatures,
      IsComplete = IsComplete,
    }
    -- print(state)
    msg.reply({ Data = state })
  end
)

return Handlers