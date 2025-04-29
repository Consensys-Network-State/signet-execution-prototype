
local crypto = require(".crypto.init")
local json = require("json")
local MockOracle = require("../mock-oracle")  -- Import the MockOracle module
local replaceVariableReferences = require("../utils/table_utils").replaceVariableReferences

-- Helper functions
-- EIP-712 specific functions
local function keccak256(input)
    return crypto.digest.keccak256(input).asHex()
end

local function removeHexPrefix(val)
    if val[1] % 2 == 1 then
        -- In Lua, we can use table.move for slicing or manually recreate the array
        local result = {}
        for i = 2, #val do
        result[i-1] = val[i]
        end
        return result
    else
        -- Create a new table without the first two elements
        local result = {}
        for i = 3, #val do
        result[i-2] = val[i]
        end
        return result
    end
end

local function rlpEncode(value)
    -- RLP encoding implementation
    -- For single bytes < 128, the byte itself is its own RLP encoding
    -- For short strings (0-55 bytes), RLP is [0x80+len(data)] + data
    -- For long strings, RLP is [0xb7+len(len(data))] + len(data) + data
    -- For lists, similar rules apply with different offset values
    
    -- Handle integers
    if type(value) == "number" then
        -- Convert to hex string without leading zeros
        local hex = string.format("%x", value)
        if #hex % 2 ~= 0 then hex = "0" .. hex end
        
        -- Convert hex to bytes (as numbers in a table)
        local bytes = {}
        for i = 1, #hex, 2 do
            local byte = tonumber(hex:sub(i, i+1), 16)
            table.insert(bytes, byte)
        end
        
        -- If value is 0, return [0x80] (empty string)
        if value == 0 then
            return {0x80}
        -- Single byte < 128, return as is
        elseif #bytes == 1 and bytes[1] < 128 then
            return bytes
        -- Short string
        elseif #bytes <= 55 then
            local result = {0x80 + #bytes}
            for i = 1, #bytes do
                table.insert(result, bytes[i])
            end
            return result
        -- Long string
        else
            local lengthBytes = {}
            local lengthHex = string.format("%x", #bytes)
            if #lengthHex % 2 ~= 0 then lengthHex = "0" .. lengthHex end
            
            for i = 1, #lengthHex, 2 do
                local byte = tonumber(lengthHex:sub(i, i+1), 16)
                table.insert(lengthBytes, byte)
            end
            
            local result = {0xb7 + #lengthBytes}
            for i = 1, #lengthBytes do
                table.insert(result, lengthBytes[i])
            end
            for i = 1, #bytes do
                table.insert(result, bytes[i])
            end
            return result
        end
    end
    
    -- Handle other types (strings, tables, etc.) would go here
    -- This implementation focuses on encoding integers which is what's needed for transaction indices
end

local function rlpDecode(rlpBytes)
    -- Handle empty input
    if #rlpBytes == 0 then
        return nil
    end
    
    local firstByte = rlpBytes[1]
    local result = {}
    local i = 1
    
    -- Case 1: Single byte < 0x80 (128) represents itself
    if firstByte < 0x80 then
        return {rlpBytes[1]} -- Return as a single-element byte array
    
    -- Case 2: Short string (0-55 bytes)
    elseif firstByte <= 0xb7 then
        local length = firstByte - 0x80
        
        -- Empty string case
        if length == 0 then
            return {} -- Return empty array
        end
        
        -- Check if we have enough bytes
        if #rlpBytes < length + 1 then
            error("Invalid RLP: not enough bytes for short string")
        end
        
        -- Extract the bytes directly
        local result = {}
        for i = 2, length + 1 do
            table.insert(result, rlpBytes[i])
        end
        
        return result
    
    -- Case 3: Long string (>55 bytes)
    elseif firstByte <= 0xbf then
        local lengthOfLength = firstByte - 0xb7
        
        -- Check if we have enough bytes for the length
        if #rlpBytes < lengthOfLength + 1 then
            error("Invalid RLP: not enough bytes for length prefix")
        end
        
        -- Extract the length bytes
        local lengthHex = ""
        for i = 2, lengthOfLength + 1 do
            lengthHex = lengthHex .. string.format("%02x", rlpBytes[i])
        end
        
        local length = tonumber(lengthHex, 16)
        
        -- Check if we have enough bytes for the value
        if #rlpBytes < lengthOfLength + 1 + length then
            error("Invalid RLP: not enough bytes for long string")
        end
        
        -- Extract the bytes directly
        local result = {}
        for i = lengthOfLength + 2, lengthOfLength + 1 + length do
            table.insert(result, rlpBytes[i])
        end
        
        return result
    
    -- Case 4: Lists
    elseif firstByte <= 0xf7 then
        -- Short list (0-55 bytes)
        local length = firstByte - 0xc0
        
        -- Empty list case
        if length == 0 then
            return {} -- Return empty array
        end
        
        -- Check if we have enough bytes
        if #rlpBytes < length + 1 then
            error("Invalid RLP: not enough bytes for short list")
        end
        
        -- Extract the list items
        local listBytes = {}
        for i = 2, length + 1 do
            table.insert(listBytes, rlpBytes[i])
        end
        
        -- Decode the list items
        local result = {}
        local offset = 1
        while offset <= #listBytes do
            -- Create a sub-array of bytes starting from the current offset
            local subBytes = {}
            for i = offset, #listBytes do
                table.insert(subBytes, listBytes[i])
            end
            
            -- Recursively decode the item
            local item = rlpDecode(subBytes)
            table.insert(result, item)
            
            -- Calculate the length of the encoded item to update the offset
            local itemLength = 0
            local itemFirstByte = listBytes[offset]
            
            if itemFirstByte < 0x80 then
                -- Single byte
                itemLength = 1
            elseif itemFirstByte <= 0xb7 then
                -- Short string
                itemLength = (itemFirstByte - 0x80) + 1
            elseif itemFirstByte <= 0xbf then
                -- Long string
                local lengthOfLength = itemFirstByte - 0xb7
                local lengthHex = ""
                for i = offset + 1, offset + lengthOfLength do
                    lengthHex = lengthHex .. string.format("%02x", listBytes[i])
                end
                local dataLength = tonumber(lengthHex, 16)
                itemLength = 1 + lengthOfLength + dataLength
            elseif itemFirstByte <= 0xf7 then
                -- Short list
                itemLength = (itemFirstByte - 0xc0) + 1
            else
                -- Long list
                local lengthOfLength = itemFirstByte - 0xf7
                local lengthHex = ""
                for i = offset + 1, offset + lengthOfLength do
                    lengthHex = lengthHex .. string.format("%02x", listBytes[i])
                end
                local dataLength = tonumber(lengthHex, 16)
                itemLength = 1 + lengthOfLength + dataLength
            end
            
            offset = offset + itemLength
        end
        
        return result
    
    elseif firstByte <= 0xff then
        -- Long list (>55 bytes)
        local lengthOfLength = firstByte - 0xf7
        
        -- Check if we have enough bytes for the length
        if #rlpBytes < lengthOfLength + 1 then
            error("Invalid RLP: not enough bytes for length prefix in long list")
        end
        
        -- Extract the length bytes
        local lengthHex = ""
        for i = 2, lengthOfLength + 1 do
            lengthHex = lengthHex .. string.format("%02x", rlpBytes[i])
        end
        
        local length = tonumber(lengthHex, 16)
        
        -- Check if we have enough bytes for the list
        if #rlpBytes < lengthOfLength + 1 + length then
            error("Invalid RLP: not enough bytes for long list")
        end
        
        -- Extract the list bytes
        local listBytes = {}
        for i = lengthOfLength + 2, lengthOfLength + 1 + length do
            table.insert(listBytes, rlpBytes[i])
        end
        
        -- Decode the list items
        local result = {}
        local offset = 1
        while offset <= #listBytes do
            -- Create a sub-array of bytes starting from the current offset
            local subBytes = {}
            for i = offset, #listBytes do
                table.insert(subBytes, listBytes[i])
            end
            
            -- Recursively decode the item
            local item = rlpDecode(subBytes)
            table.insert(result, item)
            
            -- Calculate the length of the encoded item to update the offset
            local itemLength = 0
            local itemFirstByte = listBytes[offset]
            
            if itemFirstByte < 0x80 then
                -- Single byte
                itemLength = 1
            elseif itemFirstByte <= 0xb7 then
                -- Short string
                itemLength = (itemFirstByte - 0x80) + 1
            elseif itemFirstByte <= 0xbf then
                -- Long string
                local lengthOfLength = itemFirstByte - 0xb7
                local lengthHex = ""
                for i = offset + 1, offset + lengthOfLength do
                    lengthHex = lengthHex .. string.format("%02x", listBytes[i])
                end
                local dataLength = tonumber(lengthHex, 16)
                itemLength = 1 + lengthOfLength + dataLength
            elseif itemFirstByte <= 0xf7 then
                -- Short list
                itemLength = (itemFirstByte - 0xc0) + 1
            else
                -- Long list
                local lengthOfLength = itemFirstByte - 0xf7
                local lengthHex = ""
                for i = offset + 1, offset + lengthOfLength do
                    lengthHex = lengthHex .. string.format("%02x", listBytes[i])
                end
                local dataLength = tonumber(lengthHex, 16)
                itemLength = 1 + lengthOfLength + dataLength
            end
            
            offset = offset + itemLength
        end
        
        return result
    else
        error("Invalid RLP encoding")
    end
end

local function bytesToString(bytes)
    local chars = {}
    for i = 1, #bytes do
        chars[i] = string.char(bytes[i])
    end
    return table.concat(chars)
end

local function bytesToHex(bytes)
    local hex = ""
    for i = 1, #bytes do
        -- Convert each byte to its hex representation
        -- %02x formats as 2-digit hex with leading zeros
        hex = hex .. string.format("%02x", bytes[i])
    end
    return hex
end

local function hexToBytes(hexString)
    local bytes = {}
    
    -- Remove any non-hex characters (like spaces or 0x prefix)
    hexString = hexString:gsub("[^0-9A-Fa-f]", "")
    
    -- Ensure we have an even number of hex digits
    if #hexString % 2 ~= 0 then
        hexString = "0" .. hexString
    end
    
    -- Convert each pair of hex digits to a byte
    for i = 1, #hexString, 2 do
        local byteString = hexString:sub(i, i + 1)
        local byte = tonumber(byteString, 16)
        table.insert(bytes, byte)
    end
    
    return bytes
end

local function bytesToNibbles(key)
    local nibbles = {}
    
    for i = 1, #key do
        local byte = key[i]
        -- Get the high nibble (first 4 bits)
        local highNibble = math.floor(byte / 16)
        -- Get the low nibble (last 4 bits)
        local lowNibble = byte % 16
        
        -- Store both nibbles
        local q = (i - 1) * 2 + 1
        nibbles[q] = highNibble
        nibbles[q + 1] = lowNibble
    end
    
    return nibbles
end

-- Add this helper function to compare byte arrays
local function equalsBytes(bytes1, bytes2)
    if #bytes1 ~= #bytes2 then
        return false
    end
    
    for i = 1, #bytes1 do
        if bytes1[i] ~= bytes2[i] then
            return false
        end
    end
    
    return true
end

local function isTerminator(key)
    return key[1] > 1
end

local ExtensionNode = {}
ExtensionNode.__index = ExtensionNode

-- Constructor
function ExtensionNode.new(nibbles, value)
    local self = setmetatable({}, ExtensionNode)
    self.nibbles = nibbles
    self.value = value
    return self
end

-- Method to check if an object is an instance of MyClass
function ExtensionNode.isInstance(obj)
    return type(obj) == "table" and getmetatable(obj) == ExtensionNode
end

local LeafNode = {}
LeafNode.__index = LeafNode

-- Constructor
function LeafNode.new(nibbles, value)
    local self = setmetatable({}, LeafNode)
    self.nibbles = nibbles
    self.value = value
    return self
end

-- Method to check if an object is an instance of MyClass
function LeafNode.isInstance(obj)
    return type(obj) == "table" and getmetatable(obj) == LeafNode
end

local BranchNode = {}
BranchNode.__index = BranchNode

-- Constructor
function BranchNode.new(array)
    local self = setmetatable({}, BranchNode)
    self.branches = {table.unpack(array, 1, 16)}
    self.value = array[17]
    return self
end

-- Method to check if an object is an instance of MyClass
function BranchNode.isInstance(obj)
    return type(obj) == "table" and getmetatable(obj) == BranchNode
end


Trie = {}
Trie.__index = Trie

-- Constructor function
function Trie.new(root)
    local self = setmetatable({}, Trie)
    if root ~= nil then
        self.root = root
    end
    self.db = {}
    return self
end

function Trie:updateFromProof(proof)
    local opStack = {}
  
    for i, nodeValue in ipairs(proof) do
        local key = hexToBytes(keccak256(bytesToString(nodeValue))) 
        table.insert(opStack, {key = key, value = nodeValue})
    end

    -- check if the root matches
    if opStack[1] ~= nil then
        if not equalsBytes(self.root, opStack[1].key) then
            error('The provided proof does not have the expected trie root')
        else 
            -- print('root is good')
        end
    end

    -- insert the proof into the db
    for i, op in ipairs(opStack) do
        self.db[bytesToHex(op.key)] = op.value
        -- table.insert(self.db, {key = bytesToHex(op.key), value = op.value})
    end
end

function Trie:lookupNode(node)
    -- if (isRawNode(node)) {
    --     const decoded = decodeRawNode(node)
    --     return decoded
    -- }
    local key = bytesToHex(node)
    local value = self.db[key]

    if value == nil then
        -- error('Missing node in DB')
        return;
    end

    local raw = rlpDecode(value)
    if raw == nil then
        error('Failed to decode node')
    end
    if #raw == 17 then
        return BranchNode.new(raw)
    elseif #raw == 2 then
        local nibbles = bytesToNibbles(raw[1])
        if isTerminator(nibbles) then
            return LeafNode.new(removeHexPrefix(nibbles), raw[2])
        end
        return ExtensionNode.new(removeHexPrefix(nibbles), raw[2])
    else
        error("Invalid node")
    end    
end

-- function Trie:walkTrie()
--     local node = self:lookupNode(self.root)
--     self:processNode(self.root, node, {})
-- end

function Trie:findPath(key)
    local targetKey = bytesToNibbles(key)
    local keyLen = #targetKey
    local stack = {}
    local progress = 0
    local result = nil

    -- Helper function to process nodes during trie traversal
    local function processNode(nodeRef, node, keyProgress)
        if node == nil then
            return
        end

        stack[progress + 1] = node

        if BranchNode.isInstance(node) then
            if progress == keyLen then
                -- Found exact match at branch node
                result = {
                    node = node,
                    remaining = {},
                    stack = stack
                }
            else
                -- Get branch index from target key
                local branchIndex = targetKey[progress + 1]
                local branchNode = node.branches[branchIndex + 1]

                if branchNode == nil then
                    -- No matching branch found
                    result = {
                        node = nil,
                        remaining = {},  -- Create slice of targetKey from progress
                        stack = stack
                    }
                    for i = progress + 1, keyLen do
                        table.insert(result.remaining, targetKey[i])
                    end
                else
                    progress = progress + 1
                    -- Continue walking down this branch
                    local nextNode = self:lookupNode(branchNode)
                    processNode(branchNode, nextNode, keyProgress + 1)
                end
            end

        elseif LeafNode.isInstance(node) then
            local nodeKey = node.nibbles
            local _progress = progress

            -- Check if remaining key is longer than leaf node key
            if keyLen - progress > #nodeKey then
                result = {
                    node = nil,
                    remaining = {},
                    stack = stack
                }
                -- Add remaining key to result
                for i = _progress + 1, keyLen do
                    table.insert(result.remaining, targetKey[i])
                end
                return
            end

            -- Compare each nibble
            for i = 1, #nodeKey do
                if nodeKey[i] ~= targetKey[progress + i] then
                    result = {
                        node = nil,
                        remaining = {},
                        stack = stack
                    }
                    -- Add remaining key to result
                    for j = _progress + 1, keyLen do
                        table.insert(result.remaining, targetKey[j])
                    end
                    return
                end
            end
            progress = progress + #nodeKey
            result = {
                node = node,
                remaining = {},
                stack = stack
            }

        elseif ExtensionNode.isInstance(node) then
            local nodeKey = node.nibbles
            local _progress = progress

            -- Compare extension node key with target key
            for i = 1, #nodeKey do
                if nodeKey[i] ~= targetKey[progress + i] then
                    result = {
                        node = nil,
                        remaining = {},
                        stack = stack
                    }
                    -- Add remaining key to result
                    for j = _progress + 1, keyLen do
                        table.insert(result.remaining, targetKey[j])
                    end
                    return
                end
            end
            progress = progress + #nodeKey

            -- Continue walking with the extension node's value
            local nextNode = self:lookupNode(node.value)
            processNode(node.value, nextNode, keyProgress + #nodeKey)
        end
    end

    -- Start walking from root
    local node = self:lookupNode(self.root)
    processNode(self.root, node, 0)

    -- If no result was found, return empty result
    if result == nil then
        result = {
            node = nil,
            remaining = {},
            stack = stack
        }
    end

    -- Filter out nil values from stack
    local filteredStack = {}
    for i = 1, #stack do
        if stack[i] ~= nil then
            table.insert(filteredStack, stack[i])
        end
    end
    result.stack = filteredStack

    return result
end

function Trie:get(key)
    local result =self:findPath(key)
    -- const { node, remaining } = self.findPath(key)
    local value = nil
    if result.node ~= nil and #result.remaining == 0 then
        value = result.node.value
    end
    return value
end

local function verifyMerkleProof(key, root, proof, value)
    -- 2. convert blocks transactions root to buffer
    local rootBytes = {}
    -- Remove '0x' prefix if present
    if root:sub(1, 2) == "0x" then
        root = root:sub(3)
    end
    
    -- Convert hex string to byte array
    for i = 1, #root, 2 do
        local byte = tonumber(root:sub(i, i+1), 16)
        table.insert(rootBytes, byte)
    end
    
    -- 3. verify the proof by checking the transaction root and getting the value at the transaction index
    local trie = Trie.new(rootBytes)
    trie:updateFromProof(proof)

    -- 4. compare the value to the expected value and return result
    local proofValue = trie:get(key)
    return equalsBytes(value, proofValue)
end

local function verifyProof(txHash, txIndex, txRoot, txProof, txValue, receiptRoot, receiptProof, receiptValue)
    -- 1. RLP encode transaction index
    local key = rlpEncode(tonumber(txIndex))
    return verifyMerkleProof(key, txRoot, txProof, txValue) and verifyMerkleProof(key, receiptRoot, receiptProof, receiptValue)
end

-- Export the verifier function
local function verifyEVMTransaction(input, value, variables, contracts)
    -- TODO: Implement actual EVM transaction verification
    -- Extract the transaction hash from the VC (Also verify VC?)
    -- Mock the Oracle call
    value = json.decode(value)
    local oracle = MockOracle.new()
    if not oracle:exists(value.txHash) then
        return false, {}
    end
    
    -- Retrieve the transaction data from the oracle
    local oracleResponse = oracle:retrieve(value.txHash)

    if not oracleResponse then

        return false, {}
    end

    local isValid = verifyProof(oracleResponse.TxHash, oracleResponse.TxIndex, oracleResponse.TxRoot, oracleResponse.TxProof, oracleResponse.TxEncodedValue, oracleResponse.ReceiptRoot, oracleResponse.ReceiptProof, oracleResponse.ReceiptEncodedValue)

    if not isValid then
        return false, {}
    end

    local processedRequiredInput = replaceVariableReferences(input.txMetadata, variables.variables)
    if processedRequiredInput.transactionType == "nativeTransfer" then
        if string.lower(oracleResponse.TxRaw.from) ~= string.lower(processedRequiredInput.from) 
            or string.lower(oracleResponse.TxRaw.to) ~= string.lower(processedRequiredInput.to) 
            or oracleResponse.TxRaw.value ~= processedRequiredInput.value
            or oracleResponse.TxRaw.chainId ~= processedRequiredInput.chainId then
            return false
        end
        return true, {}
    elseif processedRequiredInput.transactionType == "contractCall" then
        local contract = contracts.contracts[processedRequiredInput.contractReference]
        local decodedTx = contract:decode(oracleResponse.TxRaw.input)
        if (decodedTx.function_name ~= processedRequiredInput.method) then
            return false
        end

        for i, param in ipairs(decodedTx.parameters) do
            if (param.value ~= processedRequiredInput.params[i]) then
                return false
            end
        end
        return true
    else
    end

    return true, {}
end

-- Return the verifier function
return verifyEVMTransaction
