--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local VehicleChassis = require(script.Parent.VehicleChassis)

type ConfigResolver = (Model) -> typeof(Config)?
type State = {
	configResolver: ConfigResolver?,
	active: { [Model]: VehicleChassis.Chassis },
	stepping: { [Model]: VehicleChassis.Chassis },
	watchers: { [Model]: { RBXScriptConnection } },
	retryWatchers: { [Model]: RBXScriptConnection },
	attaching: { [Model]: boolean },
	lastRemoteInput: { [Player]: number },
	connections: { RBXScriptConnection },
	started: boolean,
}

local ChassisRegistry = {}
ChassisRegistry.__index = ChassisRegistry
export type Registry = typeof(setmetatable({} :: State, ChassisRegistry))

local function getOrCreate(parent: Instance, name: string, className: string): Instance
	local found: Instance? = nil
	for _, child in parent:GetChildren() do
		if child.Name == name then
			if found then
				error(`{parent:GetFullName()} has multiple children named {name}`)
			end
			found = child
		end
	end
	if found then
		if found.ClassName ~= className then
			error(`{found:GetFullName()} must be a {className}`)
		end
		return found
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

function ChassisRegistry.new(configResolver: ConfigResolver?): Registry
	return setmetatable(
		{
			configResolver = configResolver,
			active = {},
			stepping = {},
			watchers = {},
			retryWatchers = {},
			attaching = {},
			lastRemoteInput = {},
			connections = {},
			started = false,
		} :: State,
		ChassisRegistry
	)
end

function ChassisRegistry.Get(self: Registry, model: Model): VehicleChassis.Chassis?
	return self.active[model]
end

function ChassisRegistry._detach(self: Registry, model: Model): ()
	self.stepping[model] = nil
	local chassis = self.active[model]
	if chassis then
		self.active[model] = nil
		chassis:Destroy()
	end
end

function ChassisRegistry._clearRetry(self: Registry, model: Model): ()
	local connection = self.retryWatchers[model]
	if connection then
		connection:Disconnect()
		self.retryWatchers[model] = nil
	end
end

function ChassisRegistry._reconcile(self: Registry, model: Model): ()
	if not self.started or not CollectionService:HasTag(model, Config.Tag) or not model:IsDescendantOf(workspace) then
		self:_clearRetry(model)
		self:_detach(model)
		return
	end
	if self.active[model] or self.attaching[model] then
		return
	end
	self.attaching[model] = true
	local success, result = pcall(function()
		local resolve = self.configResolver
		local tuning = if resolve then resolve(model) else nil
		local chassis = VehicleChassis.new(model, tuning)
		chassis:Start()
		return chassis
	end)
	self.attaching[model] = nil
	if not self.started or not CollectionService:HasTag(model, Config.Tag) or not model:IsDescendantOf(workspace) then
		if success then
			result:Destroy()
		end
		self:_clearRetry(model)
		return
	end
	if success then
		self:_clearRetry(model)
		self.active[model] = result
	else
		if not self.retryWatchers[model] then
			self.retryWatchers[model] = model.DescendantAdded:Connect(function(descendant)
				local wheels = model:FindFirstChild("Wheels")
				if
					descendant.Name == "DriveSeat"
					or descendant.Name == "Body"
					or descendant == wheels
					or (wheels ~= nil and descendant.Parent == wheels and descendant:IsA("BasePart"))
				then
					self:_reconcile(model)
				end
			end)
		end
		warn(`[Car Chassis] Could not initialize {model:GetFullName()}: {result}`)
	end
end

function ChassisRegistry.Retry(self: Registry, model: Model): ()
	self:_reconcile(model)
end

function ChassisRegistry._watch(self: Registry, instance: Instance): ()
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	if not self.watchers[model] then
		self.watchers[model] = {
			model.AncestryChanged:Connect(function()
				self:_reconcile(model)
			end),
			model.Destroying:Connect(function()
				self:_forget(model)
			end),
		}
	end
	self:_reconcile(model)
end

function ChassisRegistry._forget(self: Registry, model: Model): ()
	self:_clearRetry(model)
	self:_detach(model)
	local watchers = self.watchers[model]
	if watchers then
		for _, watcher in watchers do
			watcher:Disconnect()
		end
		self.watchers[model] = nil
	end
end

function ChassisRegistry._unwatch(self: Registry, instance: Instance): ()
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	if not CollectionService:HasTag(model, Config.Tag) then
		self:_forget(model)
	else
		self:_detach(model)
	end
end

function ChassisRegistry._receiveInput(
	self: Registry,
	player: Player,
	model: unknown,
	throttle: unknown,
	steer: unknown,
	brake: unknown,
	now: number
): boolean
	local lastInput = self.lastRemoteInput[player]
	if lastInput and now - lastInput < Config.RemoteRateLimit then
		return false
	end
	self.lastRemoteInput[player] = now
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return false
	end
	local chassis = self.active[model]
	if chassis and chassis:ApplyInput(player, throttle, steer, brake, now) then
		self.stepping[model] = chassis
		return true
	end
	return false
end

function ChassisRegistry._step(self: Registry, now: number): number
	debug.profilebegin("CarChassis.ControlStep")
	local processed = 0
	for model, chassis in self.stepping do
		chassis:Step(now)
		processed += 1
		if not chassis.lastAppliedActive then
			self.stepping[model] = nil
		end
	end
	debug.profileend()
	return processed
end

function ChassisRegistry.Start(self: Registry): ()
	if self.started then
		return
	end
	if
		Config.RemoteRateLimit <= 0
		or Config.RemoteRateLimit ~= Config.RemoteRateLimit
		or Config.RemoteRateLimit == math.huge
	then
		error("ChassisConfig.RemoteRateLimit must be finite and positive")
	end
	local shared = ReplicatedStorage:WaitForChild("ChassisShared")
	local remotes = getOrCreate(shared, "Remotes", "Folder")
	local remote = getOrCreate(remotes, "Input", "RemoteEvent") :: RemoteEvent
	self.started = true
	table.insert(
		self.connections,
		CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(function(instance)
			self:_watch(instance)
		end)
	)
	table.insert(
		self.connections,
		CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(function(instance)
			self:_unwatch(instance)
		end)
	)
	for _, instance in CollectionService:GetTagged(Config.Tag) do
		self:_watch(instance)
	end
	table.insert(
		self.connections,
		Players.PlayerRemoving:Connect(function(player)
			self.lastRemoteInput[player] = nil
		end)
	)
	table.insert(
		self.connections,
		remote.OnServerEvent:Connect(function(player, model, throttle, steer, brake)
			self:_receiveInput(player, model, throttle, steer, brake, os.clock())
		end)
	)
	table.insert(
		self.connections,
		RunService.Heartbeat:Connect(function()
			self:_step(os.clock())
		end)
	)
end

function ChassisRegistry.Stop(self: Registry): ()
	self.started = false
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	local models = {}
	for model in self.active do
		table.insert(models, model)
	end
	for _, model in models do
		self:_detach(model)
	end
	local watchedModels = {}
	for model in self.watchers do
		table.insert(watchedModels, model)
	end
	for _, model in watchedModels do
		self:_forget(model)
	end
	table.clear(self.lastRemoteInput)
	table.clear(self.stepping)
end

return ChassisRegistry
