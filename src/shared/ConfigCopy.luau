--!strict

local Config = require(script.Parent.ChassisConfig)
local ConfigTree = require(script.Parent.ConfigTree)

local ConfigCopy = {}

function ConfigCopy.copy(source: typeof(Config)?): typeof(Config)
	return ConfigTree.copy(source or Config)
end

return ConfigCopy
