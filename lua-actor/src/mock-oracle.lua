-- MockOracle: A class that simulates an oracle by storing and retrieving data
-- associated with transaction hashes
local json = require("json")

local function loadOracleData()
    local file = io.open("./mock-oracle-data.json", "r")
    if not file then
        error("Could not open agreement document file")
    end
    local content = file:read("*all")
    file:close()
    return content
end


local MockOracle = {}
MockOracle.__index = MockOracle

-- Create a new MockOracle instance
function MockOracle.new()
    local self = setmetatable({}, MockOracle)
    local data = loadOracleData()
    self.data = json.decode(data)  -- Dictionary to store transaction hash -> data mappings
    return self
end

-- Store data for a transaction hash
-- @param txHash: The transaction hash to use as a key
-- @param blobData: The data to store for this transaction
function MockOracle:store(txHash, blobData)
    self.data[txHash] = blobData
end

-- Retrieve data for a transaction hash
-- @param txHash: The transaction hash to look up
-- @return: The stored data if it exists, nil otherwise
function MockOracle:retrieve(txHash)
    return self.data[txHash]
end

-- Check if data exists for a transaction hash
-- @param txHash: The transaction hash to check
-- @return: true if data exists, false otherwise
function MockOracle:exists(txHash)
    return self.data[txHash] ~= nil
end

-- Remove data for a transaction hash
-- @param txHash: The transaction hash to remove
function MockOracle:remove(txHash)
    self.data[txHash] = nil
end

-- Get all stored transaction hashes
-- @return: An array of all transaction hashes in the oracle
function MockOracle:getAllTxHashes()
    local hashes = {}
    for hash, _ in pairs(self.data) do
        table.insert(hashes, hash)
    end
    return hashes
end

return MockOracle
