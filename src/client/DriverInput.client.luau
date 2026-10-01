--!strict

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local remote =
	ReplicatedStorage:WaitForChild("ChassisShared"):WaitForChild("Remotes"):WaitForChild("Input") :: RemoteEvent
local player = Players.LocalPlayer
local BRAKE_ACTION = "CarChassisHandbrake"

local generation = 0
local seatedConnection: RBXScriptConnection?
local heldBrakeInputs: { [InputObject]: boolean } = {}
local brakeBound = false

local function unbindBrake()
	if brakeBound then
		ContextActionService:UnbindAction(BRAKE_ACTION)
		brakeBound = false
	end
	table.clear(heldBrakeInputs)
end

local function bindBrake()
	ContextActionService:BindAction(BRAKE_ACTION, function(_, state, input)
		if state == Enum.UserInputState.Begin then
			heldBrakeInputs[input] = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			heldBrakeInputs[input] = nil
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle(BRAKE_ACTION, "Brake")
	ContextActionService:SetPosition(BRAKE_ACTION, UDim2.new(1, -140, 1, -260))
	brakeBound = true
end

local function beginDriving(humanoid: Humanoid, seat: BasePart?)
	generation += 1
	unbindBrake()
	local currentGeneration = generation
	if not seat or not seat:IsA("VehicleSeat") or seat.Name ~= "DriveSeat" then
		return
	end
	local model = seat.Parent
	if not model or not model:IsA("Model") or not CollectionService:HasTag(model, Config.Tag) then
		return
	end
	bindBrake()

	task.spawn(function()
		while
			generation == currentGeneration
			and humanoid.SeatPart == seat
			and CollectionService:HasTag(model, Config.Tag)
		do
			local brake = next(heldBrakeInputs) ~= nil
				or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL1)
			remote:FireServer(model, seat.ThrottleFloat, seat.SteerFloat, brake)
			task.wait(1 / 20)
		end
		if generation == currentGeneration then
			unbindBrake()
		end
	end)
end

local function bindCharacter(character: Model)
	generation += 1
	unbindBrake()
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
			unbindBrake()
		end
	end)
	if humanoid.SeatPart then
		beginDriving(humanoid, humanoid.SeatPart)
	end
end

player.CharacterAdded:Connect(bindCharacter)
UserInputService.WindowFocusReleased:Connect(function()
	table.clear(heldBrakeInputs)
end)
if player.Character then
	bindCharacter(player.Character)
end
