--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local remote = ReplicatedStorage:WaitForChild("ChassisInput") :: RemoteEvent
local player = Players.LocalPlayer

local generation = 0
local seatedConnection: RBXScriptConnection?

local function beginDriving(humanoid: Humanoid, seat: BasePart?)
	generation += 1
	local currentGeneration = generation
	if not seat or not seat:IsA("VehicleSeat") or seat.Name ~= "DriveSeat" then
		return
	end
	local model = seat.Parent
	if not model or not model:IsA("Model") or not CollectionService:HasTag(model, Config.Tag) then
		return
	end

	task.spawn(function()
		while
			generation == currentGeneration
			and humanoid.SeatPart == seat
			and CollectionService:HasTag(model, Config.Tag)
		do
			local brake = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL1)
			remote:FireServer(model, seat.ThrottleFloat, seat.SteerFloat, brake)
			task.wait(1 / 20)
		end
	end)
end

local function bindCharacter(character: Model)
	generation += 1
	local previousConnection = seatedConnection
	if previousConnection then
		previousConnection:Disconnect()
	end
	seatedConnection = nil
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	seatedConnection = humanoid.Seated:Connect(function(active, seat)
		if active then
			beginDriving(humanoid, seat)
		else
			generation += 1
		end
	end)
	if humanoid.SeatPart then
		beginDriving(humanoid, humanoid.SeatPart)
	end
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	bindCharacter(player.Character)
end
