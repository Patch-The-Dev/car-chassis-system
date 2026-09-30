--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local InputPolicy = require(ReplicatedStorage.ChassisShared.InputPolicy)

local WHEEL_NAMES = { "FL", "FR", "RL", "RR" }

type State = {
	config: typeof(Config),
	model: Model,
	seat: VehicleSeat,
	body: Model,
	wheels: { [string]: BasePart },
	created: { Instance },
	anchors: { [BasePart]: boolean },
	wheelProperties: { { part: BasePart, properties: PhysicalProperties? } },
	motors: { [string]: HingeConstraint },
	wheelRadius: { [string]: number },
	driven: { [string]: boolean },
	steering: { [string]: HingeConstraint },
	occupantConnection: RBXScriptConnection?,
	driver: Player?,
	throttle: number,
	steer: number,
	handbrake: boolean,
	lastInput: number,
	started: boolean,
	inputDirty: boolean,
	lastAppliedActive: boolean,
}

local VehicleChassis = {}
VehicleChassis.__index = VehicleChassis
export type Chassis = typeof(setmetatable({} :: State, VehicleChassis))

local function expectPart(parent: Instance, name: string): BasePart
	local child = parent:FindFirstChild(name)
	if not child or not child:IsA("BasePart") then
		error(`{parent:GetFullName()} requires a BasePart named {name}`)
	end
	return child
end

local function track(self: Chassis, instance: Instance): ()
	table.insert(self.created, instance)
end

local function attachment(self: Chassis, part: BasePart, name: string, worldFrame: CFrame): Attachment
	local result = Instance.new("Attachment")
	result.Name = name
	result.Parent = part
	result.WorldCFrame = worldFrame
	track(self, result)
	return result
end

local function frameAt(position: Vector3, axis: Vector3, secondaryAxis: Vector3): CFrame
	return CFrame.fromMatrix(position, axis, secondaryAxis)
end

local function makeCarrier(self: Chassis, name: string, wheel: BasePart, parent: Instance): Part
	local carrier = Instance.new("Part")
	carrier.Name = name
	carrier.Size = Vector3.new(0.4, 0.4, 0.4)
	carrier.CFrame = wheel.CFrame
	carrier.Anchored = true
	carrier.Massless = true
	carrier.CanCollide = false
	carrier.CanTouch = false
	carrier.CanQuery = false
	carrier.Transparency = 1
	carrier.Parent = parent
	track(self, carrier)
	return carrier
end

local function requireFinite(name: string, value: unknown, minimum: number): ()
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge or value < minimum then
		error(`ChassisConfig.{name} must be a finite number at least {minimum}`)
	end
end

local function validateSuspension(axle: string, suspension: typeof(Config.Suspension.Front)): ()
	requireFinite(`Suspension.{axle}.Stiffness`, suspension.Stiffness, 0)
	requireFinite(`Suspension.{axle}.Damping`, suspension.Damping, 0)
	requireFinite(`Suspension.{axle}.Length`, suspension.Length, 0.000001)
	requireFinite(`Suspension.{axle}.Compression`, suspension.Compression, 0)
	requireFinite(`Suspension.{axle}.Extension`, suspension.Extension, 0)
	if suspension.Compression > suspension.Length then
		error(`ChassisConfig.Suspension.{axle}.Compression exceeds Length`)
	end
end

local function validateConfig(config: typeof(Config)): ()
	if config.Drivetrain ~= "AWD" and config.Drivetrain ~= "FWD" and config.Drivetrain ~= "RWD" then
		error("ChassisConfig.Drivetrain must be AWD, FWD, or RWD")
	end
	requireFinite("InputTimeout", config.InputTimeout, 0.000001)
	requireFinite("InputRateLimit", config.InputRateLimit, 0.000001)
	requireFinite("MaxForwardSpeed", config.MaxForwardSpeed, 0)
	requireFinite("MaxReverseSpeed", config.MaxReverseSpeed, 0)
	requireFinite("DriveTorque", config.DriveTorque, 0)
	requireFinite("CoastTorque", config.CoastTorque, 0)
	requireFinite("BrakeTorque", config.BrakeTorque, 0)
	requireFinite("SteerAngle", config.SteerAngle, 0)
	requireFinite("SteerAngularSpeed", config.SteerAngularSpeed, 0)
	requireFinite("SteerTorque", config.SteerTorque, 0)
	requireFinite("WheelDensity", config.WheelDensity, 0.000001)
	if config.InputRateLimit >= config.InputTimeout then
		error("ChassisConfig.InputRateLimit must be shorter than InputTimeout")
	end
	validateSuspension("Front", config.Suspension.Front)
	validateSuspension("Rear", config.Suspension.Rear)
end

function VehicleChassis.new(model: Model, config: typeof(Config)?): Chassis
	local tune = config or Config
	validateConfig(tune)
	local seat = model:FindFirstChild("DriveSeat")
	if not seat or not seat:IsA("VehicleSeat") then
		error(`{model:GetFullName()} requires a VehicleSeat named DriveSeat`)
	end
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("Model") then
		error(`{model:GetFullName()} requires a Model named Body`)
	end
	local wheelsContainer = model:FindFirstChild("Wheels")
	if not wheelsContainer or not (wheelsContainer:IsA("Model") or wheelsContainer:IsA("Folder")) then
		error(`{model:GetFullName()} requires a Model or Folder named Wheels`)
	end
	local misc = model:FindFirstChild("Misc")
	if misc and not (misc:IsA("Model") or misc:IsA("Folder")) then
		error(`{model:GetFullName()} requires Misc to be a Model or Folder`)
	end

	local wheels: { [string]: BasePart } = {}
	for _, name in WHEEL_NAMES do
		wheels[name] = expectPart(wheelsContainer, name)
	end
	return setmetatable(
		{
			config = tune,
			model = model,
			seat = seat,
			body = body,
			wheels = wheels,
			created = {},
			anchors = {},
			wheelProperties = {},
			motors = {},
			wheelRadius = {},
			driven = {},
			steering = {},
			occupantConnection = nil,
			driver = nil,
			throttle = 0,
			steer = 0,
			handbrake = false,
			lastInput = 0,
			started = false,
			inputDirty = true,
			lastAppliedActive = false,
		} :: State,
		VehicleChassis
	)
end

function VehicleChassis._rememberAnchor(self: Chassis, part: BasePart): ()
	if self.anchors[part] == nil then
		self.anchors[part] = part.Anchored
	end
end

function VehicleChassis._weldBody(self: Chassis, container: Instance): ()
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			self:_rememberAnchor(descendant)
			local weld = Instance.new("WeldConstraint")
			weld.Name = "ChassisBodyWeld"
			weld.Part0 = self.seat
			weld.Part1 = descendant
			weld.Parent = descendant
			track(self, weld)
		end
	end
end

function VehicleChassis._buildWheel(self: Chassis, name: string, runtime: Folder): ()
	local wheel = self.wheels[name]
	local front = name == "FL" or name == "FR"
	local config = self.config
	local suspension = if front then config.Suspension.Front else config.Suspension.Rear
	local up = self.seat.CFrame.UpVector
	local forward = self.seat.CFrame.LookVector
	local right = self.seat.CFrame.RightVector
	local center = wheel.Position
	local verticalFrame = frameAt(center, up, forward)
	local axleFrame = frameAt(center, right, up)

	self:_rememberAnchor(wheel)
	table.insert(self.wheelProperties, { part = wheel, properties = wheel.CustomPhysicalProperties })
	wheel.CustomPhysicalProperties = PhysicalProperties.new(config.WheelDensity, 1, 0, 100, 100)
	self.wheelRadius[name] = math.min(wheel.Size.Y, wheel.Size.Z) / 2
	self.driven[name] = InputPolicy.isDriven(name, config.Drivetrain)

	local carrier = makeCarrier(self, `{name}Carrier`, wheel, runtime)
	local slide = Instance.new("PrismaticConstraint")
	slide.Name = `{name}Travel`
	slide.Attachment0 = attachment(self, self.seat, `{name}Frame`, verticalFrame)
	slide.Attachment1 = attachment(self, carrier, `{name}Slide`, verticalFrame)
	slide.LimitsEnabled = true
	slide.LowerLimit = -suspension.Extension
	slide.UpperLimit = suspension.Compression
	slide.Parent = runtime
	track(self, slide)

	local spring = Instance.new("SpringConstraint")
	spring.Name = `{name}Spring`
	spring.Attachment0 = attachment(self, self.seat, `{name}SpringFrame`, verticalFrame + up * suspension.Length)
	spring.Attachment1 = attachment(self, carrier, `{name}SpringCarrier`, verticalFrame)
	spring.FreeLength = suspension.Length
	spring.Stiffness = suspension.Stiffness
	spring.Damping = suspension.Damping
	spring.LimitsEnabled = true
	spring.MinLength = suspension.Length - suspension.Compression
	spring.MaxLength = suspension.Length + suspension.Extension
	spring.Parent = runtime
	track(self, spring)

	local motorBase: BasePart = carrier
	if front then
		local pivot = makeCarrier(self, `{name}SteeringPivot`, wheel, runtime)
		local steering = Instance.new("HingeConstraint")
		steering.Name = `{name}Steering`
		steering.Attachment0 = attachment(self, carrier, `{name}SteeringBase`, verticalFrame)
		steering.Attachment1 = attachment(self, pivot, `{name}SteeringHub`, verticalFrame)
		steering.ActuatorType = Enum.ActuatorType.Servo
		steering.AngularSpeed = config.SteerAngularSpeed
		steering.ServoMaxTorque = config.SteerTorque
		steering.LimitsEnabled = true
		steering.LowerAngle = -config.SteerAngle
		steering.UpperAngle = config.SteerAngle
		steering.Parent = runtime
		track(self, steering)
		self.steering[name] = steering
		motorBase = pivot
	end

	local motor = Instance.new("HingeConstraint")
	motor.Name = `{name}Drive`
	motor.Attachment0 = attachment(self, motorBase, `{name}Axle`, axleFrame)
	motor.Attachment1 = attachment(self, wheel, `{name}WheelAxle`, axleFrame)
	motor.ActuatorType = Enum.ActuatorType.Motor
	motor.MotorMaxTorque = 0
	motor.AngularVelocity = 0
	motor.Parent = runtime
	track(self, motor)
	self.motors[name] = motor
end

function VehicleChassis._separateWheelsFromBody(self: Chassis, runtime: Folder): ()
	local bodyParts: { BasePart } = { self.seat }
	local function collect(container: Instance?)
		if not container then
			return
		end
		for _, descendant in container:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.CanCollide then
				table.insert(bodyParts, descendant)
			end
		end
	end
	collect(self.body)
	collect(self.model:FindFirstChild("Misc"))
	for _, wheel in self.wheels do
		for _, bodyPart in bodyParts do
			local separation = Instance.new("NoCollisionConstraint")
			separation.Name = "WheelBodySeparation"
			separation.Part0 = wheel
			separation.Part1 = bodyPart
			separation.Parent = runtime
			track(self, separation)
		end
	end
end

function VehicleChassis._setNetworkOwner(self: Chassis, player: Player?): ()
	for _, descendant in self.model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			local success, failure = pcall(function()
				if descendant:CanSetNetworkOwnership() then
					if player then
						descendant:SetNetworkOwner(player)
					else
						descendant:SetNetworkOwnershipAuto()
					end
				end
			end)
			if not success then
				warn(`[Car Chassis] Network ownership for {descendant:GetFullName()} failed: {failure}`)
			end
		end
	end
end

function VehicleChassis._driverChanged(self: Chassis): ()
	local occupant = self.seat.Occupant
	local character = if occupant then occupant.Parent else nil
	self.driver = if character then Players:GetPlayerFromCharacter(character) else nil
	self.throttle = 0
	self.steer = 0
	self.handbrake = false
	self.lastInput = 0
	self.inputDirty = true
	self:Step(os.clock())
	self:_setNetworkOwner(self.driver)
end

function VehicleChassis.Start(self: Chassis): ()
	if self.started then
		return
	end
	if self.model:FindFirstChild("ChassisRuntime") then
		error(`{self.model:GetFullName()} already has a ChassisRuntime folder`)
	end

	local success, failure = pcall(function()
		local runtime = Instance.new("Folder")
		runtime.Name = "ChassisRuntime"
		runtime.Parent = self.model
		track(self, runtime)
		self:_rememberAnchor(self.seat)
		self:_weldBody(self.body)
		local misc = self.model:FindFirstChild("Misc")
		if misc then
			self:_weldBody(misc)
		end
		for _, name in WHEEL_NAMES do
			self:_buildWheel(name, runtime)
		end
		self:_separateWheelsFromBody(runtime)
		for part in self.anchors do
			part.Anchored = false
		end
		for _, descendant in runtime:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
			end
		end
	end)
	if not success then
		self:Destroy()
		error(failure)
	end

	self.started = true
	self.occupantConnection = self.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		self:_driverChanged()
	end)
	self:_driverChanged()
end

function VehicleChassis.ApplyInput(
	self: Chassis,
	player: Player,
	throttle: unknown,
	steer: unknown,
	brake: unknown,
	now: number
): boolean
	if not self.started or self.driver == nil or self.driver.UserId ~= player.UserId then
		return false
	end
	local occupant = self.seat.Occupant
	local seatedPlayer = if occupant then Players:GetPlayerFromCharacter(occupant.Parent) else nil
	if seatedPlayer == nil or seatedPlayer.UserId ~= player.UserId then
		return false
	end
	if now - self.lastInput < self.config.InputRateLimit then
		return false
	end
	local safeThrottle, safeSteer, safeBrake = InputPolicy.sanitize(throttle, steer, brake)
	if safeThrottle == nil or safeSteer == nil or safeBrake == nil then
		return false
	end
	self.throttle = safeThrottle
	self.steer = safeSteer
	self.handbrake = safeBrake
	self.lastInput = now
	self.inputDirty = true
	return true
end

function VehicleChassis.Step(self: Chassis, now: number): ()
	if not self.started then
		return
	end
	local config = self.config
	local active = self.driver ~= nil and self.lastInput > 0 and now - self.lastInput <= config.InputTimeout
	if not self.inputDirty and active == self.lastAppliedActive then
		return
	end
	self.inputDirty = false
	self.lastAppliedActive = active
	local throttle = if active then self.throttle else 0
	local steer = if active then self.steer else 0
	local handbrake = active and self.handbrake

	local drivenCount = if config.Drivetrain == "AWD" then 4 else 2
	for name, motor in self.motors do
		local driven = self.driven[name]
		local target = if driven and not handbrake
			then InputPolicy.targetAngularVelocity(
				throttle,
				self.wheelRadius[name],
				config.MaxForwardSpeed,
				config.MaxReverseSpeed
			)
			else 0
		local torque = if handbrake
			then config.BrakeTorque / 4
			else if not driven
				then 0
				else if throttle ~= 0 then config.DriveTorque / drivenCount else config.CoastTorque
		if motor.AngularVelocity ~= target then
			motor.AngularVelocity = target
		end
		if motor.MotorMaxTorque ~= torque then
			motor.MotorMaxTorque = torque
		end
	end
	for _, hinge in self.steering do
		local target = -steer * config.SteerAngle
		if hinge.TargetAngle ~= target then
			hinge.TargetAngle = target
		end
	end
end

function VehicleChassis.Destroy(self: Chassis): ()
	local connection = self.occupantConnection
	if connection then
		connection:Disconnect()
	end
	self.occupantConnection = nil
	if self.started then
		self:_setNetworkOwner(nil)
	end
	self.driver = nil
	self.started = false
	for _, motor in self.motors do
		motor.AngularVelocity = 0
		motor.MotorMaxTorque = 0
	end
	for index = #self.created, 1, -1 do
		self.created[index]:Destroy()
	end
	table.clear(self.created)
	for _, record in self.wheelProperties do
		-- Roblox accepts nil here to restore material defaults; the pinned API
		-- definitions incorrectly declare this writable property as non-optional.
		if record.part.Parent then
			record.part.CustomPhysicalProperties = record.properties :: PhysicalProperties
		end
	end
	for part, anchored in self.anchors do
		if part.Parent then
			part.Anchored = anchored
		end
	end
	table.clear(self.wheelProperties)
	table.clear(self.anchors)
	table.clear(self.motors)
	table.clear(self.wheelRadius)
	table.clear(self.driven)
	table.clear(self.steering)
	self.inputDirty = true
	self.lastAppliedActive = false
end

return VehicleChassis
