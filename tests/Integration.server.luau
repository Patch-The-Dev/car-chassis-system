local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local StudioTestService = game:GetService("StudioTestService")

local arguments = StudioTestService:GetTestArgs()
if typeof(arguments) ~= "table" or arguments.suite ~= "CarChassisIntegration" then
	return
end

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local ConfigCopy = require(ReplicatedStorage.ChassisShared.ConfigCopy)
local Fixture = require(script.Parent.Fixture)
local ChassisRegistry = require(script.Parent.ChassisRegistry)

local checks = 0
local registry = ChassisRegistry.new(function(model)
	if model:GetAttribute("ServerOwned") then
		local tune = ConfigCopy.copy()
		tune.NetworkOwnership = "Server"
		tune.InputRateLimit = 1 / 60
		return tune
	end
	return nil
end)
local car, serverCar, floor, status, statusConnection
local replies = {}

local function check(condition, message)
	checks += 1
	assert(condition, message)
end

local function awaitCondition(predicate, message, seconds)
	local deadline = os.clock() + (seconds or 10)
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
		return #Players:GetPlayers() >= 2
	end, "test players did not join", 45)
	local player = Players:GetPlayers()[1]
	awaitCondition(function()
		return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	end, "test character did not load", 20)
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	awaitCondition(function()
		return replies[player] and replies[player].phase == "ready"
	end, "integration client did not load", 45)
	check(seat.Parent == car, `vehicle disappeared before seating at {seat.Position}`)
	local function phase(name, vehicle)
		print(`CHASSIS_TEST_PHASE:{checks}:{name}`)
		replies[player] = nil
		status:FireClient(player, name, vehicle or car)
		awaitCondition(function()
			return replies[player] and replies[player].phase == name
		end, `client did not acknowledge {name} after check {checks}`)
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
	awaitCondition(function()
		return (seat.Position - startPosition):Dot(startForward) > 5
	end, "vehicle did not travel forward", 10)
	local forwardTravel = (seat.Position - startPosition):Dot(startForward)
	check(forwardTravel > 5, `vehicle failed to travel forward: {forwardTravel} studs`)
	check(seat.CFrame.UpVector:Dot(Vector3.yAxis) > 0.7, "vehicle became unstable under forward input")
	local intruder
	for _, candidate in Players:GetPlayers() do
		if candidate ~= player then
			intruder = candidate
			break
		end
	end
	awaitCondition(function()
		return replies[intruder] and replies[intruder].phase == "ready"
	end, "second client did not load", 30)
	check(not chassis:ApplyInput(intruder, 1, 1, true, os.clock()), "another player controlled the occupied vehicle")
	status:FireClient(intruder, "unseated", car)
	awaitCondition(function()
		return registry.lastRemoteInput[intruder] ~= nil
	end, "second client's attack did not reach the real input remote")
	check(chassis.steer == 0 and not chassis.handbrake, "another player's remote changed the driver's controls")
	check(seat:GetNetworkOwner() == player, "another player's input changed physics ownership")
	phase("steer")
	awaitCondition(function()
		return chassis.steer == 1
	end, "steering input did not reach the server")
	local beforeTurn = seat.CFrame.LookVector
	local beforeRight = seat.CFrame.RightVector
	awaitCondition(function()
		return beforeTurn:Dot(seat.CFrame.LookVector) < 0.98
	end, "steering did not change heading", 10)
	check(beforeTurn:Dot(seat.CFrame.LookVector) < 0.98, "steering did not change vehicle heading")
	check(beforeRight:Dot(seat.CFrame.LookVector) > 0.05, "right steering input did not turn right")
	check(seat.CFrame.UpVector:Dot(Vector3.yAxis) > 0.7, "vehicle became unstable while turning")
	phase("reverse")
	awaitCondition(function()
		return chassis.throttle == -1 and chassis.steer == 0
	end, "reverse input did not reach the server")
	awaitCondition(function()
		return seat.AssemblyLinearVelocity:Dot(seat.CFrame.LookVector) < -2
	end, "vehicle did not change into reverse", 10)
	local reverseStart = seat.Position
	local reverseForward = seat.CFrame.LookVector
	awaitCondition(function()
		return (seat.Position - reverseStart):Dot(reverseForward) < -5
	end, "vehicle did not travel backward", 10)
	local reverseTravel = (seat.Position - reverseStart):Dot(reverseForward)
	check(reverseTravel < -5, `vehicle failed to reverse: {reverseTravel} studs`)
	check(seat.CFrame.UpVector:Dot(Vector3.yAxis) > 0.7, "vehicle became unstable in reverse")
	phase("neutral")
	phase("leave")
	awaitCondition(function()
		return seat.Occupant == nil
	end, "client did not leave the seat")
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

	-- Run the same production client against a server-simulated vehicle.
	serverCar = Fixture.create()
	serverCar:PivotTo(serverCar:GetPivot() + Vector3.new(150, 0, 0))
	serverCar:SetAttribute("ServerOwned", true)
	for _, part in serverCar:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	CollectionService:AddTag(serverCar, Config.Tag)
	awaitCondition(function()
		return registry:Get(serverCar) ~= nil
	end, "server-owned vehicle did not attach")
	local serverChassis = registry:Get(serverCar)
	local serverSeat = serverCar.DriveSeat
	check(
		serverSeat:GetNetworkOwner() == nil and not serverSeat:GetNetworkOwnershipAuto(),
		"parked server vehicle must remain server-owned"
	)
	phase("leave")
	awaitCondition(function()
		return seat.Occupant == nil
	end, "old seat did not release the driver before handoff")
	character:PivotTo(serverSeat.CFrame * CFrame.new(0, 3, 0))
	serverSeat:Sit(humanoid)
	awaitCondition(function()
		return serverChassis.driver == player
	end, "server-owned driver was not authenticated")
	check(serverSeat:GetNetworkOwner() == nil, "server-owned mode assigned physics to the driver")
	for _, wheel in serverChassis.wheels do
		check(wheel:GetNetworkOwner() == nil, "server-owned mode must include every wheel")
	end
	-- Deterministic gate checks use the real seated player and a controlled server clock.
	local rateTime = os.clock() + 1
	check(
		registry:_receiveInput(player, serverCar, 0, 0, false, rateTime),
		"first authenticated rate probe was rejected"
	)
	check(
		registry:_receiveInput(player, serverCar, 0, 0.25, false, rateTime + 0.02),
		"registry capped a 60 Hz vehicle at the default 30 Hz"
	)
	check(
		not registry:_receiveInput(player, serverCar, 0, 0.5, false, rateTime + 0.021),
		"abuse gate accepted a flood packet"
	)
	check(serverChassis.steer == 0.25, "flooded controls altered the last accepted input")
	serverChassis:_driverChanged()
	registry.lastRemoteInput[player] = nil
	phase("forward", serverCar)
	awaitCondition(function()
		return serverChassis.throttle == 1
	end, "server-owned vehicle did not receive client controls")
	local serverStart = serverSeat.Position
	local serverForward = serverSeat.CFrame.LookVector
	awaitCondition(function()
		return (serverSeat.Position - serverStart):Dot(serverForward) > 5
	end, "server-owned vehicle did not travel forward", 10)
	check((serverSeat.Position - serverStart):Dot(serverForward) > 5, "server-owned vehicle did not drive forward")
	check(serverSeat.CFrame.UpVector:Dot(Vector3.yAxis) > 0.7, "server-owned vehicle became unstable")
	phase("neutral", serverCar)
	CollectionService:RemoveTag(serverCar, Config.Tag)
	awaitCondition(function()
		return registry:Get(serverCar) == nil
	end, "server-owned vehicle did not detach")
	check(serverSeat:GetNetworkOwnershipAuto(), "server-owned teardown did not restore automatic ownership")
end)

if statusConnection then
	statusConnection:Disconnect()
end
registry:Stop()
for _, instance in { car, serverCar, floor, status } do
	if instance then
		instance:Destroy()
	end
end

if success then
	print(`{checks} integration checks passed`)
	print("CAR_CHASSIS_INTEGRATION_PASS")
	print(`CAR_CHASSIS_RESULT:{arguments.runId}:PASS:{checks}`)
else
	warn(`CAR_CHASSIS_INTEGRATION_FAILURE: {failure}`)
	warn(`CAR_CHASSIS_RESULT:{arguments.runId}:FAIL:{failure}`)
end
StudioTestService:EndTest({ passed = checks, error = if success then nil else tostring(failure) })
