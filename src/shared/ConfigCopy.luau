--!strict

local Config = require(script.Parent.ChassisConfig)

local ConfigCopy = {}

function ConfigCopy.copy(source: typeof(Config)?): typeof(Config)
	local original = source or Config
	local result = table.clone(original)
	result.Suspension = {
		Front = table.clone(original.Suspension.Front),
		Rear = table.clone(original.Suspension.Rear),
	}
	return result
end

return ConfigCopy
