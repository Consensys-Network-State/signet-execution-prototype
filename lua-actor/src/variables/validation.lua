-- Shared validation module for both InputVerifier and VariableManager
local ValidationModule = {}

-- Core validation function that can be used for both variables and input fields
-- Returns success (boolean) and error message (string or nil)
function ValidationModule.validateValue(value, validation, fieldName)
    -- Skip validation if validation rules not provided
    if not validation then
        return true, nil
    end

    -- Check required field
    if validation.required and (value == nil or value == "") then
        return false, string.format("%s is required", fieldName)
    end

    -- Skip remaining validation if value is nil and not required
    if value == nil then
        return true, nil
    end

    -- Type validation is handled by the caller, as the type checks differ
    -- between variables and input fields

    -- String validations
    if type(value) == "string" then
        -- Min length
        if validation.minLength and #value < validation.minLength then
            return false, string.format("%s must be at least %d characters", fieldName, validation.minLength)
        end
        
        -- Max length
        if validation.maxLength and #value > validation.maxLength then
            return false, string.format("%s must be at most %d characters", fieldName, validation.maxLength)
        end
        
        -- Pattern
        if validation.pattern then
            local pattern = validation.pattern:gsub("\\/", "/")
            if not string.match(value, pattern) then
                return false, string.format("%s: %s", fieldName, validation.message or "Invalid format")
            end
        end
    end
    
    -- Number validations
    if type(value) == "number" then
        -- Min value
        if validation.min and value < validation.min then
            return false, string.format("%s must be at least %s", fieldName, tostring(validation.min))
        end
        
        -- Max value
        if validation.max and value > validation.max then
            return false, string.format("%s must be at most %s", fieldName, tostring(validation.max))
        end
    end
    
    return true, nil
end

return ValidationModule 