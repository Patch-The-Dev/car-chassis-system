--!strict

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.ChassisShared.ChassisConfig)
local remote =
	ReplicatedStorage:WaitForChild("ChassisShared"):WaitForChild("Remotes"):WaitForChild("Input") :: RemoteEvent
local player = Players.LocalPlayer
local BRAKE_ACTION = "CarChassisHandbrake"

local seatedConnection: RBXScriptConnection?
local drivingHumanoid: Humanoid?
local drivingSeat: VehicleSeat?
local drivingModel: Model?
local lastSent = 0
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

local function stopDriving()
	drivingHumanoid = nil
	drivingSeat = nil
	drivingModel = nil
	unbindBrake()
end

local function beginDriving(humanoid: Humanoid, seat: BasePart?)
	stopDriving()
	if not seat or not seat:IsA("VehicleSeat") or seat.Name ~= "DriveSeat" then
		return
	end
	local model = seat.Parent
	if not model or not model:IsA("Model") or not CollectionService:HasTag(model, Config.Tag) then
		return
	end
	drivingHumanoid = humanoid
	drivingSeat = seat
	drivingModel = model
	lastSent = 0
	bindBrake()
end

local function bindCharacter(character: Model)
	stopDriving()
	local previousConnection = seatedConnection
	if previousConnection then
		previousConnection:Disconnect()
	end
	seatedConnection = nil
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if player.Character ~= character then
		return
	end
	seatedConnection = humanoid.Seated:Connect(function(active, seat)
		if active then
			beginDriving(humanoid, seat)
		else
			stopDriving()
		end
	end)
	if humanoid.SeatPart then
		beginDriving(humanoid, humanoid.SeatPart)
	end
end

-- Sample after Roblox's input controls update the seat for the current frame.
-- One sender avoids overlapping driving loops during seating transitions.
RunService:BindToRenderStep("CarChassisInput", Enum.RenderPriority.Input.Value + 2, function()
	local humanoid, seat, model = drivingHumanoid, drivingSeat, drivingModel
	if not humanoid or not seat or not model then
		return
	end
	if humanoid.SeatPart ~= seat or not CollectionService:HasTag(model, Config.Tag) then
		stopDriving()
		return
	end
	local now = os.clock()
	if now - lastSent < 1 / 20 then
		return
	end
	lastSent = now
	local brake = next(heldBrakeInputs) ~= nil
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL1)
	remote:FireServer(model, seat.ThrottleFloat, seat.SteerFloat, brake)
end)

player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function()
	stopDriving()
	if seatedConnection then
		seatedConnection:Disconnect()
		seatedConnection = nil
	end
end)
CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(function(instance)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.SeatPart and humanoid.SeatPart.Parent == instance then
		beginDriving(humanoid, humanoid.SeatPart)
	end
end)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(function(instance)
	if drivingModel == instance then
		stopDriving()
	end
end)
UserInputService.WindowFocusReleased:Connect(function()
	table.clear(heldBrakeInputs)
end)
if player.Character then
	bindCharacter(player.Character)
end
