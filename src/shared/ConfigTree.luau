--!strict

-- Keep arbitrary nested tuning independent as the configuration schema grows.
type Dictionary = { [any]: unknown }
local ConfigTree = {}

local function copyValue(value: unknown, copies: { [Dictionary]: Dictionary }): unknown
	if typeof(value) ~= "table" then
		return value
	end
	local original = value :: Dictionary
	local existing = copies[original]
	if existing then
		return existing
	end
	local result: Dictionary = {}
	copies[original] = result
	for key, child in original do
		result[key] = copyValue(child, copies)
	end
	return result
end

local function freezeValue(value: unknown, visited: { [Dictionary]: boolean }): ()
	if typeof(value) ~= "table" then
		return
	end
	local dictionary = value :: Dictionary
	if visited[dictionary] then
		return
	end
	visited[dictionary] = true
	for _, child in dictionary do
		freezeValue(child, visited)
	end
	if not table.isfrozen(dictionary) then
		table.freeze(dictionary)
	end
end

function ConfigTree.copy<T>(value: T): T
	return copyValue(value, {}) :: T
end

function ConfigTree.freeze<T>(value: T): T
	freezeValue(value, {})
	return value
end

return ConfigTree
