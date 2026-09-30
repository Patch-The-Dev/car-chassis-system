local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local InputPolicy = require(ReplicatedStorage.ChassisShared.InputPolicy)
local Fixture = require(ServerScriptService.Fixture)
local VehicleChassis = require(ServerScriptService.VehicleChassis)

local cases = 0
local function check(condition, message)
	cases += 1
	assert(condition, message)
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

local car = Fixture.create()
local chassis = VehicleChassis.new(car)
chassis:Start()
chassis:Start()
local runtime = car:FindFirstChild("ChassisRuntime")
check(runtime ~= nil, "runtime should be installed once")
check(not car.DriveSeat.Anchored, "drive seat should unanchor after assembly")

local counts = { SpringConstraint = 0, PrismaticConstraint = 0, HingeConstraint = 0 }
for _, instance in runtime:GetDescendants() do
	if counts[instance.ClassName] then
		counts[instance.ClassName] += 1
	end
end
check(counts.SpringConstraint == 4, "one spring per wheel")
check(counts.PrismaticConstraint == 4, "one suspension guide per wheel")
check(counts.HingeConstraint == 6, "four motors and two steering hinges")

chassis:Step(os.clock())
check(chassis.motors.FL.AngularVelocity == 0, "an empty vehicle must not drive")
check(chassis.motors.FL.MotorMaxTorque == Config.CoastTorque, "empty vehicle should only coast")

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

print(`{cases} passed, 0 failed`)
print("CAR_CHASSIS_TESTS_PASS")
