-- EIP-712 type definitions for contract calls

local EIP712Types = {
    -- Primary type for contract calls
    ContractCall = {
        name = "ContractCall",
        type = "object",
        properties = {
            -- The contract address being called
            contract = {
                name = "contract",
                type = "address"
            },
            -- The function selector (first 4 bytes of keccak256 hash of function signature)
            functionSelector = {
                name = "functionSelector",
                type = "bytes4"
            },
            -- The encoded function parameters
            parameters = {
                name = "parameters",
                type = "bytes"
            },
            -- The value to send with the call (in wei)
            value = {
                name = "value",
                type = "uint256"
            },
            -- The gas limit for the call
            gasLimit = {
                name = "gasLimit",
                type = "uint256"
            },
            -- The nonce to prevent replay attacks
            nonce = {
                name = "nonce",
                type = "uint256"
            },
            -- The chain ID where the contract is deployed
            chainId = {
                name = "chainId",
                type = "uint256"
            }
        }
    },
    -- Domain separator type
    EIP712Domain = {
        name = "EIP712Domain",
        type = "object",
        properties = {
            name = {
                name = "name",
                type = "string"
            },
            version = {
                name = "version",
                type = "string"
            },
            chainId = {
                name = "chainId",
                type = "uint256"
            },
            verifyingContract = {
                name = "verifyingContract",
                type = "address"
            }
        }
    }
}

-- Helper function to get the type hash for a contract call
local function getContractCallTypeHash()
    return "0x" .. string.format("%x", 
        -- This is a placeholder for the actual keccak256 hash
        -- In a real implementation, this would be computed from the type definition
        0xdeadbeef
    )
end

-- Helper function to get the domain separator hash
local function getDomainSeparator(domain)
    return "0x" .. string.format("%x",
        -- This is a placeholder for the actual keccak256 hash
        -- In a real implementation, this would be computed from the domain parameters
        0xcafebabe
    )
end

return {
    types = EIP712Types,
    getContractCallTypeHash = getContractCallTypeHash,
    getDomainSeparator = getDomainSeparator
} 