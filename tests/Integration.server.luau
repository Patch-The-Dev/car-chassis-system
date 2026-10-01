local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local StudioTestService = game:GetService("StudioTestService")

if StudioTestService:GetTestArgs() ~= "CarChassisIntegration" then
	return
end

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local Fixture = require(script.Parent.Fixture)
local ChassisRegistry = require(script.Parent.ChassisRegistry)

local checks = 0
local registry = ChassisRegistry.new()
local car, floor, status, statusConnection
local replies = {}

local function check(condition, message)
	checks += 1
	assert(condition, message)
end

local function awaitCondition(predicate, message, seconds)
	local deadline = os.clock() + (seconds or 5)
	repeat
		if predicate() then
			return
		end
		task.wait()
	until os.clock() >= deadline
	error(message)
end

local success, failure = pcall(function()
	floor = Instance.new("Part")
	floor.Name = "IntegrationGround"
	floor.Size = Vector3.new(1000, 1, 1000)
	floor.Anchored = true
	floor.Parent = workspace
	car = Fixture.create()
	car.Name = "IntegrationVehicle"
	local seat = car.DriveSeat
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	registry:Start()
	CollectionService:AddTag(car, Config.Tag)
	awaitCondition(function()
		return registry:Get(car) ~= nil
	end, "vehicle did not attach")
	local chassis = registry:Get(car)
	status = Instance.new("RemoteEvent")
	status.Name = "ChassisIntegrationStatus"
	status.Parent = ReplicatedStorage
	statusConnection = status.OnServerEvent:Connect(function(player, phase, detail)
		replies[player] = { phase = phase, detail = detail }
	end)
	awaitCondition(function()
		return #Players:GetPlayers() > 0
	end, "test player did not join", 20)
	local player = Players:GetPlayers()[1]
	awaitCondition(function()
		return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	end, "test character did not load", 20)
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	awaitCondition(function()
		return replies[player] and replies[player].phase == "ready"
	end, "integration client did not load", 20)
	check(seat.Parent == car, `vehicle disappeared before seating at {seat.Position}`)
	local function phase(name)
		replies[player] = nil
		status:FireClient(player, name, car)
		awaitCondition(function()
			return replies[player] and replies[player].phase == name
		end, `client did not acknowledge {name}`)
		check(replies[player].detail == true, `client failed {name}`)
	end

	phase("unseated")
	task.wait(0.15)
	check(chassis.lastInput == 0, "unseated player input was accepted")
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
	awaitCondition(function()
		return chassis.driver == player and seat.Occupant == humanoid
	end, "driver was not authenticated from the seat")
	check(seat:GetNetworkOwner() == player, "driver did not receive physics ownership")
	phase("forward")
	awaitCondition(function()
		return chassis.throttle == 1 and chassis.lastInput > 0
	end, "production client input did not reach the server")
	check(chassis.handbrake == false, "unexpected brake during forward input")
	task.wait(0.5)
	local startPosition = seat.Position
	local startForward = seat.CFrame.LookVector
	task.wait(2)
	local forwardTravel = (seat.Position - startPosition):Dot(startForward)
	check(forwardTravel > 5, `vehicle failed to travel forward: {forwardTravel} studs`)
	check(seat.CFrame.UpVector:Dot(Vector3.yAxis) > 0.7, "vehicle became unstable under forward input")
	phase("steer")
	awaitCondition(function()
		return chassis.steer == 1
	end, "steering input did not reach the server")
	local beforeTurn = seat.CFrame.LookVector
	task.wait(1.5)
	check(beforeTurn:Dot(seat.CFrame.LookVector) < 0.98, "steering did not change vehicle heading")
	check(seat.CFrame.UpVector:Dot(Vector3.yAxis) > 0.7, "vehicle became unstable while turning")
	phase("reverse")
	awaitCondition(function()
		return chassis.throttle == -1 and chassis.steer == 0
	end, "reverse input did not reach the server")
	task.wait(2)
	local reverseStart = seat.Position
	local reverseForward = seat.CFrame.LookVector
	task.wait(2)
	local reverseTravel = (seat.Position - reverseStart):Dot(reverseForward)
	check(reverseTravel < -5, `vehicle failed to reverse: {reverseTravel} studs`)
	check(seat.CFrame.UpVector:Dot(Vector3.yAxis) > 0.7, "vehicle became unstable in reverse")
	phase("neutral")
	humanoid.Sit = false
	character:PivotTo(seat.CFrame * CFrame.new(0, 10, 15))
	awaitCondition(function()
		return seat.Occupant == nil and chassis.driver == nil
	end, "leaving the seat did not release the driver")
	check(chassis.motors.FL.AngularVelocity == 0, "leaving the seat did not neutralize the motors")
	phase("unbound")
	phase("unseated")
	task.wait(0.15)
	check(chassis.lastInput == 0, "former driver input was accepted after leaving the seat")
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
	awaitCondition(function()
		return chassis.driver == player
	end, "driver did not reattach")
	CollectionService:RemoveTag(car, Config.Tag)
	awaitCondition(function()
		return registry:Get(car) == nil
	end, "untagging did not detach the chassis")
	check(seat:GetNetworkOwnershipAuto(), "teardown did not restore automatic physics ownership")
	check(car:FindFirstChild("ChassisRuntime") == nil, "teardown left generated runtime objects")
end)

if statusConnection then
	statusConnection:Disconnect()
end
registry:Stop()
for _, instance in { car, floor, status } do
	if instance then
		instance:Destroy()
	end
end

if success then
	print(`{checks} integration checks passed`)
	print("CAR_CHASSIS_INTEGRATION_PASS")
else
	warn(`CAR_CHASSIS_INTEGRATION_FAILURE: {failure}`)
end
StudioTestService:EndTest({ passed = checks, error = if success then nil else tostring(failure) })
