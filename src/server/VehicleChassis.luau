--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local InputPolicy = require(ReplicatedStorage.ChassisShared.InputPolicy)

local WHEEL_NAMES = { "FL", "FR", "RL", "RR" }

type State = {
	model: Model,
	seat: VehicleSeat,
	body: Model,
	wheels: { [string]: BasePart },
	created: { Instance },
	anchors: { [BasePart]: boolean },
	wheelProperties: { { part: BasePart, properties: PhysicalProperties? } },
	motors: { [string]: HingeConstraint },
	steering: { [string]: HingeConstraint },
	occupantConnection: RBXScriptConnection?,
	driver: Player?,
	throttle: number,
	steer: number,
	handbrake: boolean,
	lastInput: number,
	started: boolean,
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

function VehicleChassis.new(model: Model): Chassis
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

	local wheels: { [string]: BasePart } = {}
	for _, name in WHEEL_NAMES do
		wheels[name] = expectPart(wheelsContainer, name)
	end
	if Config.Drivetrain ~= "AWD" and Config.Drivetrain ~= "FWD" and Config.Drivetrain ~= "RWD" then
		error("ChassisConfig.Drivetrain must be AWD, FWD, or RWD")
	end

	return setmetatable(
		{
			model = model,
			seat = seat,
			body = body,
			wheels = wheels,
			created = {},
			anchors = {},
			wheelProperties = {},
			motors = {},
			steering = {},
			occupantConnection = nil,
			driver = nil,
			throttle = 0,
			steer = 0,
			handbrake = false,
			lastInput = 0,
			started = false,
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
	local suspension = if front then Config.Suspension.Front else Config.Suspension.Rear
	local up = self.seat.CFrame.UpVector
	local forward = self.seat.CFrame.LookVector
	local right = self.seat.CFrame.RightVector
	local center = wheel.Position
	local verticalFrame = frameAt(center, up, forward)
	local axleFrame = frameAt(center, right, up)

	self:_rememberAnchor(wheel)
	table.insert(self.wheelProperties, { part = wheel, properties = wheel.CustomPhysicalProperties })
	wheel.CustomPhysicalProperties = PhysicalProperties.new(Config.WheelDensity, 1, 0, 100, 100)

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
		steering.AngularSpeed = Config.SteerAngularSpeed
		steering.ServoMaxTorque = Config.SteerTorque
		steering.LimitsEnabled = true
		steering.LowerAngle = -Config.SteerAngle
		steering.UpperAngle = Config.SteerAngle
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
	if now - self.lastInput < Config.InputRateLimit then
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
	return true
end

function VehicleChassis.Step(self: Chassis, now: number): ()
	if not self.started then
		return
	end
	local active = self.driver ~= nil and now - self.lastInput <= Config.InputTimeout
	local throttle = if active then self.throttle else 0
	local steer = if active then self.steer else 0
	local handbrake = active and self.handbrake

	local drivenCount = if Config.Drivetrain == "AWD" then 4 else 2
	for name, motor in self.motors do
		local driven = InputPolicy.isDriven(name, Config.Drivetrain)
		local wheel = self.wheels[name]
		local radius = math.min(wheel.Size.Y, wheel.Size.Z) / 2
		motor.AngularVelocity = if driven
			then InputPolicy.targetAngularVelocity(throttle, radius, Config.MaxForwardSpeed, Config.MaxReverseSpeed)
			else 0
		motor.MotorMaxTorque = if handbrake
			then Config.BrakeTorque / 4
			else if driven and throttle ~= 0 then Config.DriveTorque / drivenCount else Config.CoastTorque
	end
	for _, hinge in self.steering do
		hinge.TargetAngle = -steer * Config.SteerAngle
	end
end

function VehicleChassis.Destroy(self: Chassis): ()
	local connection = self.occupantConnection
	if connection then
		connection:Disconnect()
	end
	self.occupantConnection = nil
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
	table.clear(self.steering)
end

return VehicleChassis
