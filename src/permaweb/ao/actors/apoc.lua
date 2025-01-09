local json = require("json")
-- local base64 = require(".base64")
local Array = require(".crypto.util.array")
local crypto = require(".crypto.init")

Document = Document or nil
DocumentOwner = DocumentOwner or nil
Signatories = Signatories or nil
Signatures = Signatures or {}
IsComplete = IsComplete or false

State = {
  Document = Document,
  DocumentOwner = DocumentOwner,
  Signatories = Signatories,
  Signatures = Signatures,
  IsComplete = IsComplete,
}

-- Helper functions for base64url decoding
local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64_decode(data)
  data = string.gsub(data, '[^'..alphabet..'=]', '')
  local res = (data:gsub('.', function(x)
    if (x == '=') then return '' end
    local r,f='',(alphabet:find(x)-1)
    for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
    return r;
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    if (#x ~= 8) then return '' end
    local c=0
    for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
    return string.char(c)
  end))

  return res
end

local function base64_url_decode(data)
  -- the contents in JWTs are base64 encoded, but also makde URL safe. This means substituting
  -- chars like + and / with - and _ respectively. We need to undo this before decoding the data.
  data = data:gsub("-", "+")
  data = data:gsub("_", "/")
  -- TODO: for some reason, there's an issue with using AO's base64 lib at runtime... opting to use a simpler implementation instead
  -- local res = base64.decode(data)
  -- return res
  return base64_decode(data)
end

-- Parse JWT into header, payload, and signature
local function parse_jwt(jwt)
  local header_b64, payload_b64, signature_b64 = jwt:match("([^%.]+)%.([^%.]+)%.([^%.]+)")
  if not header_b64 or not payload_b64 or not signature_b64 then
      return nil, "Invalid JWT format"
  end
  local header = base64_url_decode(header_b64)
  local payload = base64_url_decode(payload_b64)
  local signature = base64_url_decode(signature_b64)
  return header, payload, signature, header_b64 .. "." .. payload_b64
end

local function decode_signature(signature)
  local bytes = Array.fromString(signature)
-- Ensure the signature is 64 bytes long (32 bytes for r, 32 bytes for s)
  if #bytes ~= 64 then
      error("Invalid signature length: expected 64 bytes")
  end

 local sig_hex = Array.toHex(bytes)
 return sig_hex
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

local function get_authority(payload)
  -- TODO: handle other authority formats? Eg. public keys
  local issuer = payload.iss;
  local pub_key_hex = nil
  if (issuer) then
    -- TODO: parse out the pub key
    local parts = string_split(issuer, ':')
    if (parts[1] == 'did' and parts[2] == 'ethr') then
      if #parts == 3 then
        -- mainnet ethr did
        pub_key_hex = parts[3]
      elseif #parts == 4 then
        -- a non-mainnet chain is specified
        pub_key_hex = parts[4]
      end
    end
  end
  if pub_key_hex  then
    if string.sub(pub_key_hex, 1, 2) == '0x' then
      pub_key_hex = string.sub(pub_key_hex, 3, -1)
    end
  end
  return pub_key_hex
end

local function jwt_validate(jwt)
  local header, payload, signature, signing_input = parse_jwt(jwt)

  if not header or not payload or not signature then
      return false, "Failed to parse JWT"
  end

  local json_header = json.decode(header)
  if (json_header.alg ~= "ES256K") then
    error('Only support ES256K signatures')
  end
  local json_payload = json.decode(payload)
  -- TODO: don't assume the authority is always a compressed pub key?
  local pub_key_hex = get_authority(json_payload)
  if (not pub_key_hex) then
    error('Failed to get the public key from JWT payload')
  end
  local signature_hex = decode_signature(signature)
  local success = verify_signature(signing_input, signature_hex, pub_key_hex)
  return success, json_payload, pub_key_hex
end

local function to_eth_address(pubkey)
  local pubkey_binary_str = base64_decode(pubkey)
  -- assumes pubkey is a binary string (not hex)
  local keccak_hash = crypto.digest.keccak256(pubkey_binary_str).asHex()
  return '0x'..string.sub(keccak_hash, -40, -1); -- last 40 hex chars, aka 20 bytes
end

local function init(document)
  -- TODO: validate an actual VC document, not just the JWT proof
  local is_valid, json_payload, pub_key_hex = jwt_validate(document)

  if is_valid then
    Document = document
    DocumentOwner = to_eth_address(pub_key_hex) -- no need to explicitly pass in owner?
    Signatories = json_payload.vc.credentialSubject.signatories -- should already be in the form of eth addresses?
  end

  return is_valid
end


Handlers.add(
  "Initialize",
  Handlers.utils.hasMatchingTag("Action", "Initialize"),
  function (msg)
    local data = msg.Data
    local is_valid = init(data)

    print("JWT Verification Result: " .. (is_valid and "VALID" or "INVALID"))

    ao.send({ Target = msg.From, Action = "Create-Result", Data = { is_valid = is_valid }})
  end
)

Handlers.add(
  "Sign",
  Handlers.utils.hasMatchingTag("Action", "Sign"),
  function (msg)
    local data = msg.Data
    -- validate the signature VC
    local is_valid, json_payload, pub_key_hex = jwt_validate(msg.Data)
    
    if is_valid then
      -- TODO: validate that the VC signer is one of the signatories
      -- TODO: validate that the VC payload contains a hash of the agreement document
      local signer_eth_address = to_eth_address(pub_key_hex)
      Signatures[signer_eth_address] = data

      -- TODO: check if this is the last signatory required for the agreement to be considered completed
    end
    print("Signature Verification Result: " .. (is_valid and "VALID" or "INVALID"))

    ao.send({ Target = msg.From, Action = "Create-Result", Data = { is_valid = is_valid }})
  end
)

-- Debug util to retrieve the important local state fields
Handlers.add(
  "GetState",
  Handlers.utils.hasMatchingTag("Action", "GetState"),
  function (msg)
    ao.send({ Target = msg.From, Action = "Create-Result", Data = State })
  end
)