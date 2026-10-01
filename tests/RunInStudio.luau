local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local ConfigCopy = require(ReplicatedStorage.ChassisShared.ConfigCopy)
local ConfigTree = require(ReplicatedStorage.ChassisShared.ConfigTree)
local InputPolicy = require(ReplicatedStorage.ChassisShared.InputPolicy)
local SteeringGeometry = require(ReplicatedStorage.ChassisShared.SteeringGeometry)
local Fixture = require(ServerScriptService.Fixture)
local VehicleChassis = require(ServerScriptService.VehicleChassis)
local ChassisRegistry = require(ServerScriptService.ChassisRegistry)

local cases = 0
local function check(condition, message)
	cases += 1
	assert(condition, message)
end

local tuned = ConfigCopy.copy()
tuned.Suspension.Front.Stiffness = 25000
check(Config.Suspension.Front.Stiffness == 17000, "vehicle tuning must not mutate default suspension")
check(tuned.Suspension.Front ~= Config.Suspension.Front, "front suspension has an independent table")
check(tuned.Suspension.Rear ~= Config.Suspension.Rear, "rear suspension has an independent table")
check(not pcall(function()
	Config.Suspension.Front.Stiffness = 1
end), "default suspension is frozen at every level")
tuned.Tires.Friction = 0.4
check(Config.Tires.Friction == 1, "tire tuning is independent from defaults")
local future = { Level = { Deep = { Value = 7 } } }
local futureCopy = ConfigTree.copy(future)
futureCopy.Level.Deep.Value = 9
check(future.Level.Deep.Value == 7, "future nested settings are copied without schema-specific logic")
ConfigTree.freeze(futureCopy)
check(table.isfrozen(futureCopy.Level.Deep), "future nested settings are frozen recursively")
local cyclic = {}
cyclic.Self = cyclic
local cyclicCopy = ConfigTree.copy(cyclic)
check(cyclicCopy ~= cyclic and cyclicCopy.Self == cyclicCopy, "recursive copy preserves cycles within the copy")
ConfigTree.freeze(cyclicCopy)
check(table.isfrozen(cyclicCopy), "recursive freeze handles cycles")
check(Config.RemoteRateLimit < 1 / 60, "abuse gate allows vehicles configured for 60 Hz")
check(
	SteeringGeometry.forwardSpeed(Vector3.new(0, 200, 0), Vector3.new(0, 0, -1)) == 0,
	"falling does not reduce steering"
)
check(
	SteeringGeometry.forwardSpeed(Vector3.new(200, 0, 0), Vector3.new(0, 0, -1)) == 0,
	"sideways sliding does not reduce steering"
)
check(
	SteeringGeometry.forwardSpeed(Vector3.new(0, 200, -30), Vector3.new(0, 0.5, -1)) == 30,
	"ground projection ignores vertical motion on a pitched vehicle"
)
local left, right = SteeringGeometry.angles(1, 0, 6, 6, 35, 80, 1)
check(
	left < 0 and right < left and math.abs(right) <= 35.000001,
	"right turn uses a sharper inner wheel within the limit"
)
local mirrorLeft, mirrorRight = SteeringGeometry.angles(-1, 0, 6, 6, 35, 80, 1)
check(
	math.abs(mirrorLeft + right) < 0.000001 and math.abs(mirrorRight + left) < 0.000001,
	"left and right turns mirror"
)
local parallelLeft, parallelRight = SteeringGeometry.angles(0.5, 0, 6, 6, 35, 80, 0)
check(parallelLeft == -17.5 and parallelRight == -17.5, "parallel steering remains available")
local zeroLeft, zeroRight = SteeringGeometry.angles(1, 0, 6, 6, 0, 80, 1)
check(zeroLeft == 0 and zeroRight == 0, "zero steering angle avoids division by zero")

local function eventually(predicate, message)
	local deadline = os.clock() + 3
	repeat
		if predicate() then
			check(true, message)
			return
		end
		task.wait()
	until os.clock() >= deadline
	check(false, message)
end

local throttle, steer, brake = InputPolicy.sanitize(2, -2, true)
check(throttle == 1 and steer == -1 and brake == true, "inputs should clamp to seat range")
check(InputPolicy.sanitize(0 / 0, 0, false) == nil, "NaN input should be rejected")
check(InputPolicy.sanitize(math.huge, 0, false) == nil, "infinite input should be rejected")
check(InputPolicy.sanitize(0, 0, "false") == nil, "non-boolean brake should be rejected")
check(InputPolicy.isDriven("FL", "FWD") and not InputPolicy.isDriven("RL", "FWD"), "front drive selection")
check(InputPolicy.isDriven("RL", "RWD") and not InputPolicy.isDriven("FL", "RWD"), "rear drive selection")
check(InputPolicy.targetAngularVelocity(1, 2, 100, 20) == -50, "forward wheel speed")
check(InputPolicy.targetAngularVelocity(-1, 2, 100, 20) == 10, "reverse wheel speed")

local invalid = Fixture.create()
invalid.Wheels.FR:Destroy()
check(not pcall(function()
	VehicleChassis.new(invalid)
end), "missing wheel should fail before changing the model")
check(invalid:FindFirstChild("ChassisRuntime") == nil, "invalid model should remain untouched")
invalid:Destroy()

for _, reversed in { "Axles", "FrontWheels" } do
	local reversedVehicle = Fixture.create()
	if reversed == "Axles" then
		reversedVehicle.DriveSeat.CFrame *= CFrame.Angles(0, math.pi, 0)
	else
		local leftFrame = reversedVehicle.Wheels.FL.CFrame
		reversedVehicle.Wheels.FL.CFrame = reversedVehicle.Wheels.FR.CFrame
		reversedVehicle.Wheels.FR.CFrame = leftFrame
	end
	check(not pcall(function()
		VehicleChassis.new(reversedVehicle)
	end), `reversed {reversed} geometry is rejected`)
	reversedVehicle:Destroy()
end

for _, path in { "DriveSeat", "Body", "Wheels", "FL", "FR", "RL", "RR", "Misc" } do
	local duplicateVehicle = Fixture.create()
	local parent = if string.len(path) == 2 then duplicateVehicle.Wheels else duplicateVehicle
	local original = parent:FindFirstChild(path)
	local duplicate = if original then original:Clone() else Instance.new("Folder")
	duplicate.Name = path
	duplicate.Parent = parent
	if path == "Misc" then
		duplicate:Clone().Parent = parent
	end
	local okay, message = pcall(function()
		VehicleChassis.new(duplicateVehicle)
	end)
	check(
		not okay and string.find(tostring(message), "multiple children", 1, true) ~= nil,
		`duplicate {path} is rejected clearly`
	)
	check(
		duplicateVehicle:FindFirstChild("ChassisRuntime") == nil and duplicateVehicle.DriveSeat.Anchored,
		"duplicate validation does not mutate the model"
	)
	duplicateVehicle:Destroy()
end

local invalidTuning = ConfigCopy.copy()
invalidTuning.DriveTorque = -1
local untouched = Fixture.create()
check(not pcall(function()
	VehicleChassis.new(untouched, invalidTuning)
end), "invalid tuning is rejected before assembly")
check(untouched:FindFirstChild("ChassisRuntime") == nil, "invalid tuning leaves the model untouched")
untouched:Destroy()

local tireConfig = ConfigCopy.copy()
tireConfig.Tires.Friction = 0.4
tireConfig.Tires.FrictionWeight = 10
local tireCar = Fixture.create()
local tireController = VehicleChassis.new(tireCar, tireConfig)
tireController:Start()
check(math.abs(tireCar.Wheels.FL.CustomPhysicalProperties.Friction - 0.4) < 0.000001, "tire friction reaches the wheel")
check(tireCar.Wheels.FL.CustomPhysicalProperties.FrictionWeight == 10, "tire surface weighting is configurable")
check(table.isfrozen(tireController.config.Tires), "controller tire settings are frozen")
tireController:Destroy()
check(tireCar.Wheels.FL.CustomPhysicalProperties == nil, "custom tire settings are restored on teardown")
tireCar:Destroy()
for _, value in { -1, 3, math.huge, 0 / 0 } do
	local invalidTires = ConfigCopy.copy()
	invalidTires.Tires.Friction = value
	local rejected = Fixture.create()
	check(not pcall(function()
		VehicleChassis.new(rejected, invalidTires)
	end), "invalid tire friction is rejected before Roblox clamps it")
	rejected:Destroy()
end

local car = Fixture.create()
local wheelArch = Instance.new("Part")
wheelArch.Name = "WheelArch"
wheelArch.Size = Vector3.new(1, 1, 1)
wheelArch.CFrame = car.Wheels.FL.CFrame
wheelArch.CanCollide = false
wheelArch.Anchored = true
wheelArch.Parent = car.Body
local chassis = VehicleChassis.new(car)
chassis:Start()
chassis:Start()
local runtime = car:FindFirstChild("ChassisRuntime")
check(runtime ~= nil, "runtime should be installed once")
check(not car.DriveSeat.Anchored, "drive seat should unanchor after assembly")

local counts = { SpringConstraint = 0, PrismaticConstraint = 0, HingeConstraint = 0, NoCollisionConstraint = 0 }
for _, instance in runtime:GetDescendants() do
	if counts[instance.ClassName] then
		counts[instance.ClassName] += 1
	end
end
check(counts.SpringConstraint == 4, "one spring per wheel")
check(runtime.FLSpring.MaxForce == Config.Suspension.Front.MaxForce, "front spring force is bounded")
check(runtime.RLSpring.MaxForce == Config.Suspension.Rear.MaxForce, "rear spring force is bounded")
check(counts.PrismaticConstraint == 4, "one suspension guide per wheel")
check(counts.HingeConstraint == 6, "four motors and two steering hinges")
check(counts.NoCollisionConstraint == 1, "only nearby wheel and body pairs need separation")
wheelArch.CanCollide = true
local separation = runtime:FindFirstChild("WheelBodySeparation")
check(
	separation ~= nil and separation.Part0 == car.Wheels.FL and separation.Part1 == wheelArch,
	"collision separation remains valid when a nearby panel becomes collidable"
)

chassis:Step(os.clock())
check(chassis.motors.FL.AngularVelocity == 0, "an empty vehicle must not drive")
check(chassis.motors.FL.MotorMaxTorque <= Config.CoastTorque, "empty vehicle must stay within its coast limit")

chassis:Destroy()
check(car:FindFirstChild("ChassisRuntime") == nil, "runtime should be removed on teardown")
check(car.DriveSeat.Anchored, "authored anchor state should be restored")
check(car.Wheels.FL.CustomPhysicalProperties == nil, "wheel material defaults should be restored")
check(car.Wheels.FL:FindFirstChild("FLWheelAxle") == nil, "wheel attachments should be removed")
chassis:Destroy()
chassis:Start()
check(car:FindFirstChild("ChassisRuntime") ~= nil, "a detached chassis should start again cleanly")
chassis:Destroy()
car:Destroy()

local function checkDriveMode(drivetrain)
	local tuning = ConfigCopy.copy()
	tuning.Drivetrain = drivetrain
	tuning.AckermannRatio = 0 -- Parallel output has an exact low-speed target.
	local vehicle = Fixture.create()
	local controller = VehicleChassis.new(vehicle, tuning)
	local originalTorque = controller.config.DriveTorque
	tuning.DriveTorque = 1
	check(controller.config.DriveTorque == originalTorque, "controller snapshots its tuning")
	tuning.Suspension.Front.Stiffness = 999
	check(
		controller.config.Suspension.Front.Stiffness == Config.Suspension.Front.Stiffness,
		"controller snapshots nested suspension tuning"
	)
	controller:Start()
	check(table.isfrozen(controller.config.Suspension.Front), "controller tuning is immutable")
	controller.mass = 1 -- Known mass makes the force limits deterministic in this output test.
	controller.driver = {} -- Drive output is tested independently of the seat authentication path.
	controller.throttle = 1
	controller.steer = 0.5
	controller.handbrake = false
	controller.lastInput = 100
	controller.inputDirty = true
	controller:Step(100.05)
	for name, motor in controller.motors do
		local driven = InputPolicy.isDriven(name, drivetrain)
		check(
			motor.MotorMaxTorque == (if driven then (if drivetrain == "AWD" then 10 else 20) else 0),
			`{drivetrain} torque on {name}`
		)
		check((motor.AngularVelocity ~= 0) == driven, `{drivetrain} wheel speed on {name}`)
	end
	check(controller.steering.FL.TargetAngle == -tuning.SteerAngle * 0.5, "steering follows input")
	vehicle.DriveSeat.AssemblyLinearVelocity = Vector3.new(0, 0, 100)
	controller.inputDirty = true
	controller:Step(100.06)
	check(
		controller.steering.FL.TargetAngle < 0 and controller.steering.FL.TargetAngle > -tuning.SteerAngle * 0.5,
		"steering angle decreases at speed without reversing direction"
	)
	vehicle.DriveSeat.AssemblyLinearVelocity = Vector3.zero
	controller.handbrake = true
	controller.inputDirty = true
	controller:Step(100.1)
	for _, motor in controller.motors do
		check(motor.AngularVelocity == 0, "handbrake overrides throttle")
		check(motor.MotorMaxTorque == 15, "handbrake respects the deceleration limit")
	end
	controller:Step(101)
	check(controller.steering.FL.TargetAngle == 0, "stale steering returns to center")
	check(controller.motors.FL.AngularVelocity == 0, "stale input returns to neutral")
	controller:Destroy()
	vehicle:Destroy()
end

checkDriveMode("AWD")
checkDriveMode("FWD")
checkDriveMode("RWD")

local shared = ReplicatedStorage.ChassisShared
local invalidRemotes = Instance.new("Part")
invalidRemotes.Name = "Remotes"
invalidRemotes.Parent = shared
check(not pcall(function()
	ChassisRegistry.new():Start()
end), "incorrect remote namespace class is rejected")
invalidRemotes:Destroy()

local registry = ChassisRegistry.new(function(model)
	if model:GetAttribute("TestRearDrive") then
		local tune = ConfigCopy.copy()
		tune.Drivetrain = "RWD"
		tune.Suspension.Front.Stiffness = 25000
		return tune
	end
	return nil
end)
registry:Start()
registry:Start()
local parked = {}
for index = 1, 50 do
	local model = Fixture.create()
	model:PivotTo(CFrame.new(index * 20, 5, 100))
	CollectionService:AddTag(model, Config.Tag)
	table.insert(parked, model)
end
eventually(function()
	for _, model in parked do
		if registry:Get(model) == nil then
			return false
		end
	end
	return true
end, "parked fleet attaches")
check(registry:_step(os.clock()) == 0, "parked vehicles do not run per-frame controller work")
for _, model in parked do
	model:Destroy()
end
check(shared.Remotes.Input:IsA("RemoteEvent"), "namespaced input remote is installed")
local live = Fixture.create()
CollectionService:AddTag(live, Config.Tag)
eventually(function()
	return registry:Get(live) ~= nil
end, "tagging a workspace model attaches it")
local second = Fixture.create()
second:SetAttribute("TestRearDrive", true)
CollectionService:AddTag(second, Config.Tag)
eventually(function()
	return registry:Get(second) ~= nil
end, "multiple vehicles attach independently")
check(registry:Get(second).config.Drivetrain == "RWD", "registry applies per-model drivetrain tuning")
check(registry:Get(second).config.Suspension.Front.Stiffness == 25000, "registry applies nested per-model tuning")
check(registry:Get(live).config.Suspension.Front.Stiffness == 17000, "per-model tuning does not change another vehicle")
live.Parent = ServerStorage
eventually(function()
	return registry:Get(live) == nil and live:FindFirstChild("ChassisRuntime") == nil
end, "leaving workspace detaches the chassis")
live.Parent = workspace
eventually(function()
	return registry:Get(live) ~= nil
end, "returning to workspace reattaches the chassis")
CollectionService:RemoveTag(live, Config.Tag)
eventually(function()
	return registry:Get(live) == nil
end, "removing the tag detaches the chassis")
local waiting = Fixture.create(ServerStorage)
CollectionService:AddTag(waiting, Config.Tag)
check(registry:Get(waiting) == nil, "tagged model outside workspace waits")
waiting.Parent = workspace
eventually(function()
	return registry:Get(waiting) ~= nil
end, "pretagged model attaches when moved into workspace")
local incomplete = Fixture.create()
local missingWheel = incomplete.Wheels.RR
missingWheel.Parent = nil
CollectionService:AddTag(incomplete, Config.Tag)
eventually(function()
	return registry.retryWatchers[incomplete] ~= nil
end, "incomplete tagged vehicle waits for a required part")
check(registry:Get(incomplete) == nil, "incomplete vehicle stays detached")
missingWheel.Parent = incomplete.Wheels
eventually(function()
	return registry:Get(incomplete) ~= nil and registry.retryWatchers[incomplete] == nil
end, "adding the missing wheel retries attachment")
local disposable = Fixture.create()
CollectionService:AddTag(disposable, Config.Tag)
eventually(function()
	return registry:Get(disposable) ~= nil
end, "disposable vehicle attaches")
disposable:Destroy()
eventually(function()
	return registry:Get(disposable) == nil and registry.watchers[disposable] == nil
end, "destroyed tagged model releases its watcher")
registry:Stop()
check(next(registry.stepping) == nil, "stopping the registry clears the control update set")
check(registry:Get(second) == nil and registry:Get(waiting) == nil, "registry stop detaches every vehicle")
local reusedRemote = shared.Remotes.Input
local restartedRegistry = ChassisRegistry.new()
restartedRegistry:Start()
check(shared.Remotes.Input == reusedRemote, "new registry reuses the namespaced remote")
restartedRegistry:Stop()
live:Destroy()
second:Destroy()
waiting:Destroy()
incomplete:Destroy()

print(`{cases} passed, 0 failed`)
print("CAR_CHASSIS_TESTS_PASS")
