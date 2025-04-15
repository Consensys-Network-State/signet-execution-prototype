local VariableManager = {}

function VariableManager.new(variables)
    local self = {
        variables = {}
    }

    -- Handle both array and object formats
    if type(variables) == "table" then
        if #variables > 0 then
            -- Array format
            for _, var in ipairs(variables) do
                self.variables[var.id] = {
                    value = var.value,
                    type = var.type,
                    name = var.name,
                    description = var.description,
                    validation = var.validation,
                    get = function(self)
                        return self.value
                    end,
                    set = function(self, newValue)
                        if self.validation then
                            if self.validation.required and (newValue == nil or newValue == "") then
                                error(string.format("Variable %s is required", self.name))
                            end

                            if self.validation.minLength and type(newValue) == "string" and #newValue < self.validation.minLength then
                                error(string.format("Variable %s must be at least %d characters", self.name, self.validation.minLength))
                            end

                            if self.validation.pattern and type(newValue) == "string" then
                                local pattern = self.validation.pattern:gsub("\\/", "/")
                                if not string.match(newValue, pattern) then
                                    error(string.format("Variable %s: %s", self.name, self.validation.message or "Invalid format"))
                                end
                            end

                            if self.validation.min and type(newValue) == "number" and newValue < self.validation.min then
                                error(string.format("Variable %s must be at least %s", self.name, tostring(self.validation.min)))
                            end
                        end
                        self.value = newValue
                    end
                }
            end
        else
            -- Object format
            for id, var in pairs(variables) do
                self.variables[id] = {
                    value = var.value,
                    type = var.type,
                    name = var.name,
                    description = var.description,
                    validation = var.validation,
                    get = function(self)
                        return self.value
                    end,
                    set = function(self, newValue)
                        if self.validation then
                            if self.validation.required and (newValue == nil or newValue == "") then
                                error(string.format("Variable %s is required", self.name))
                            end

                            if self.validation.minLength and type(newValue) == "string" and #newValue < self.validation.minLength then
                                error(string.format("Variable %s must be at least %d characters", self.name, self.validation.minLength))
                            end

                            if self.validation.pattern and type(newValue) == "string" then
                                local pattern = self.validation.pattern:gsub("\\/", "/")
                                if not string.match(newValue, pattern) then
                                    error(string.format("Variable %s: %s", self.name, self.validation.message or "Invalid format"))
                                end
                            end

                            if self.validation.min and type(newValue) == "number" and newValue < self.validation.min then
                                error(string.format("Variable %s must be at least %s", self.name, tostring(self.validation.min)))
                            end
                        end
                        self.value = newValue
                    end
                }
            end
        end
    end

    setmetatable(self, { __index = VariableManager })
    return self
end

function VariableManager:getVariable(name)
    local var = self.variables[name]
    if not var then
        error(string.format("Variable not found: %s", name))
    end
    return var:get()
end

function VariableManager:setVariable(name, value)
    local var = self.variables[name]
    if not var then
        error(string.format("Variable not found: %s", name))
    end
    var:set(value)
end

function VariableManager:getAllVariables()
    local result = {}
    for name, var in pairs(self.variables) do
        result[name] = {
            value = var:get(),
            type = var.type,
            name = var.name,
            description = var.description
        }
    end
    return result
end

return VariableManager 