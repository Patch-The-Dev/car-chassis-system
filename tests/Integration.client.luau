local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local player = Players.LocalPlayer
local status = ReplicatedStorage:WaitForChild("ChassisIntegrationStatus")
local remote = ReplicatedStorage:WaitForChild("ChassisShared"):WaitForChild("Remotes"):WaitForChild("Input")
local phase = "neutral"
local car

RunService:BindToRenderStep("ChassisIntegrationControls", Enum.RenderPriority.Input.Value + 1, function()
	if not car then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = car:FindFirstChild("DriveSeat")
	if humanoid and seat and humanoid.SeatPart == seat then
		seat.ThrottleFloat = if phase == "forward"
			then 1
			else if phase == "steer" then 0.5 else if phase == "reverse" then -1 else 0
		seat.SteerFloat = if phase == "steer" then 1 else 0
	end
end)

status.OnClientEvent:Connect(function(nextPhase, vehicle)
	car = vehicle
	phase = nextPhase
	local okay = true
	if phase == "unseated" then
		remote:FireServer(car, 1, 1, true)
	elseif phase == "leave" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
	elseif phase == "forward" then
		local deadline = os.clock() + 5
		local function driving()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			return humanoid
				and humanoid.SeatPart == car:FindFirstChild("DriveSeat")
				and next(ContextActionService:GetBoundActionInfo("CarChassisHandbrake")) ~= nil
		end
		repeat
			if driving() then
				break
			end
			task.wait()
		until os.clock() >= deadline
		okay = driving() == true
	elseif phase == "unbound" then
		local deadline = os.clock() + 3
		repeat
			if next(ContextActionService:GetBoundActionInfo("CarChassisHandbrake")) == nil then
				break
			end
			task.wait()
		until os.clock() >= deadline
		okay = next(ContextActionService:GetBoundActionInfo("CarChassisHandbrake")) == nil
	end
	status:FireServer(nextPhase, okay)
end)

status:FireServer("ready", true)
