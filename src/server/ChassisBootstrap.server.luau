--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local VehicleChassis = require(script.Parent.VehicleChassis)

local remote = Instance.new("RemoteEvent")
remote.Name = "ChassisInput"
remote.Parent = ReplicatedStorage

local active = {} :: { [Model]: VehicleChassis.Chassis }

local function attach(instance: Instance)
	if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) or active[instance] then
		return
	end
	local success, result = pcall(function()
		local chassis = VehicleChassis.new(instance)
		chassis:Start()
		return chassis
	end)
	if success then
		active[instance] = result
	else
		warn(`[Car Chassis] Could not initialize {instance:GetFullName()}: {result}`)
	end
end

local function detach(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local chassis = active[instance]
	if chassis then
		active[instance] = nil
		chassis:Destroy()
	end
end

CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(attach)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(detach)
for _, instance in CollectionService:GetTagged(Config.Tag) do
	attach(instance)
end

remote.OnServerEvent:Connect(function(player: Player, model: unknown, throttle: unknown, steer: unknown, brake: unknown)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	local chassis = active[model]
	if chassis then
		chassis:ApplyInput(player, throttle, steer, brake, os.clock())
	end
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for model, chassis in active do
		if model.Parent then
			chassis:Step(now)
		else
			detach(model)
		end
	end
end)
