local ContractManager = {}

local crypto = require(".crypto.init")
local json = require("json") -- You'll need a JSON library for Lua

-- Utility function to convert hex to bytes
local function hex_to_bytes(hex)
    hex = hex:gsub("^0x", "") -- Remove 0x prefix if present
    local bytes = {}
    for i = 1, #hex, 2 do
        local byte_str = hex:sub(i, i + 1)
        table.insert(bytes, tonumber(byte_str, 16))
    end
    return bytes
end

-- Utility function to convert bytes to hex
local function bytes_to_hex(bytes)
    local hex = ""
    for i, byte in ipairs(bytes) do
        hex = hex .. string.format("%02x", byte)
    end
    return "0x" .. hex
end

-- Utility function to extract a slice from bytes array
local function slice_bytes(bytes, start, length)
    local result = {}
    for i = start, start + length - 1 do
        table.insert(result, bytes[i])
    end
    return result
end

-- Utility function to convert bytes to integer
local function bytes_to_int(bytes)
    local result = 0
    for i, byte in ipairs(bytes) do
        result = result * 256 + byte
    end
    return result
end

-- Utility function to convert bytes to address (20 bytes)
local function bytes_to_address(bytes)
    return bytes_to_hex(bytes):sub(1, 42) -- 0x + 40 hex chars
end

-- Helper functions
-- EIP-712 specific functions
local function keccak256(input)
    return crypto.digest.keccak256(input).asHex()
end

-- Function to get function signature from function name and parameter types
local function get_function_signature(name, param_types)
    local signature = name .. "("
    for i, param_type in ipairs(param_types) do
        if i > 1 then signature = signature .. "," end
        signature = signature .. param_type
    end
    signature = signature .. ")"

    local hash = keccak256(signature)
    return string.sub(hash, 1, 8) -- First 4 bytes (8 hex chars + 0x)
end

-- Function to find matching function in ABI by signature
local function find_function_by_signature(abi, signature)
    for _, item in ipairs(abi) do
        if item.type == "function" then
            local param_types = {}
            for _, input in ipairs(item.inputs or {}) do
                table.insert(param_types, input.type)
            end
            local func_signature = get_function_signature(item.name, param_types)

            if func_signature == string.sub(signature, 3) then
                return item
            end
        end
    end
    return nil
end

-- Main function to decode transaction data
function decode_transaction_data(tx_data, abi_json)
    local abi = json.decode(abi_json)
    
    -- Remove 0x prefix if present
    tx_data = tx_data:gsub("^0x", "")
    
    -- If data is empty, it's a simple Ether transfer
    if #tx_data == 0 then
        return {
            function_name = "transfer",
            function_signature = "",
            parameters = {}
        }
    end
    
    -- Extract function signature (first 4 bytes)
    local signature = "0x" .. tx_data:sub(1, 8)
    local data_bytes = hex_to_bytes(tx_data)

    
    -- Find the matching function in the ABI
    local function_def = find_function_by_signature(abi, signature)
    if not function_def then
        return {
            function_name = "unknown",
            function_signature = signature,
            parameters = {}
        }
    end
    
    -- Decode parameters based on the function definition
    local parameters = {}
    local offset = 5 -- Start after the function signature (4 bytes)
    
    for i, input in ipairs(function_def.inputs or {}) do
        local param_value
        
        if input.type == "uint256" or input.type:match("^uint%d+$") then
            -- Decode uint256 (32 bytes)
            local value_bytes = slice_bytes(data_bytes, offset, 32)
            param_value = bytes_to_int(value_bytes)
            offset = offset + 32
        elseif input.type == "address" then
            -- Decode address (20 bytes, but padded to 32 bytes in calldata)
            local value_bytes = slice_bytes(data_bytes, offset + 12, 20) -- Skip 12 bytes of padding
            param_value = bytes_to_address(value_bytes)
            offset = offset + 32
        elseif input.type == "bool" then
            -- Decode boolean (1 byte, but padded to 32 bytes in calldata)
            local value_bytes = slice_bytes(data_bytes, offset, 32)
            param_value = bytes_to_int(value_bytes) ~= 0
            offset = offset + 32
        elseif input.type == "string" or input.type == "bytes" then
            -- Dynamic types have their offset at the current position
            local offset_bytes = slice_bytes(data_bytes, offset, 32)
            local data_offset = bytes_to_int(offset_bytes) * 2 + 9 -- Convert to bytes position in hex string (8 chars for func sig + 1 for 0x)
            
            -- Get length of string/bytes
            local length_bytes_pos = math.floor(data_offset / 2) + 1
            local length_bytes = slice_bytes(data_bytes, length_bytes_pos, 32)
            local length = bytes_to_int(length_bytes)
            
            -- Get actual string/bytes data
            local data_start = length_bytes_pos + 32
            local data_end = data_start + length - 1
            local value_bytes = slice_bytes(data_bytes, data_start, length)
            
            if input.type == "string" then
                -- Convert bytes to string
                local str = ""
                for _, b in ipairs(value_bytes) do
                    str = str .. string.char(b)
                end
                param_value = str
            else
                param_value = bytes_to_hex(value_bytes)
            end
            
            offset = offset + 32
        else
            -- For other types or complex types, return the raw bytes
            local value_bytes = slice_bytes(data_bytes, offset, 32)
            param_value = bytes_to_hex(value_bytes)
            offset = offset + 32
        end
        
        -- Add parameter to results
        table.insert(parameters, {
            name = input.name,
            type = input.type,
            value = param_value
        })
    end
    
    return {
        function_name = function_def.name,
        function_signature = signature,
        parameters = parameters
    }
end


function ContractManager.new(contracts)
    local self = {
        contracts = {}
    }

    for id, contract in pairs(contracts) do
        self.contracts[id] = {
            id = id,
            description = contract.description,
            address = contract.address,
            abi = contract.abi,
            get = function(self)
                return self.value
            end,
            setAddress = function(self, address)
                self.address = address
            end,
            decode = function(self, txInput)
                return decode_transaction_data(txInput, self.abi)
            end
        }
    end

    setmetatable(self, { __index = ContractManager })
    return self
end

function ContractManager:getContract(id)
    local contract = self.contracts[id]
    if not contract then
        error(string.format("Contract not found: %s", id))
    end
    return contract:get()
end

function ContractManager:setContractAddress(id, address)
    local contract = self.contracts[id]
    if not contract then
        error(string.format("Contract not found: %s", id))
    end
    contract:setAddress(address)
end

function ContractManager:getAllContracts()
    local result = {}
    for name, contract in pairs(self.contracts) do
        result[name] = {
            value = contract:get(),
        }
    end
    return result
end

return ContractManager 