local verifyEVMTransactionInputVerifier = require("verifiers.EVMTransactionInputVerifier")

local InputVerifier = {}

-- Default verifiers
local defaultVerifiers = {
    VerifiedCredentialEIP712 = function(input, value)
        -- TODO: Implement actual EIP712 verification
        return true
    end,
    
    EVMTransaction = verifyEVMTransactionInputVerifier
}

function InputVerifier.new(customVerifiers)
    local self = {
        verifiers = {}
    }

    -- Merge default verifiers with custom ones
    for k, v in pairs(defaultVerifiers) do
        self.verifiers[k] = v
    end
    if customVerifiers then
        for k, v in pairs(customVerifiers) do
            self.verifiers[k] = v
        end
    end

    setmetatable(self, { __index = InputVerifier })
    return self
end

function InputVerifier:verify(inputType, input, value)
    local verifier = self.verifiers[inputType]
    if not verifier then
        return false, string.format("Unsupported input type: %s", inputType), nil
    end

    local isValid, errorMsg, augmentedValue = verifier(input, value)
    if not isValid then
        return false, string.format("Input validation failed: %s", errorMsg), nil
    end

    return true, nil, augmentedValue
end

return InputVerifier 