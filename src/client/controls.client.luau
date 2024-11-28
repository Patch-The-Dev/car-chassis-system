--Listen to player input 
local UIS = game:GetService("UserInputService")
local CarModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Car"))
local Car = game.Workspace:WaitForChild("Car") -- temporary until later changed
local Vehicle = CarModule:New(Car)
local CameraShaker = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Libs"):WaitForChild("CameraShaker"))
local VehicleVisuals = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Components"):WaitForChild("VehicleVisuals"))

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local plrgui = plr:WaitForChild("PlayerGui")
local CarGui = plrgui:WaitForChild("Car")
local CarControlBase = CarGui:WaitForChild("CarControlBase")
local NitroGradient = CarGui:WaitForChild("Speedometer"):WaitForChild("Boost"):WaitForChild("BoostBar"):WaitForChild("UIGradient")

-- Create the CameraShaker instance
local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
	workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * shakeCFrame
end)

local LightToggle = false
local NitroOn = false
local Nitrodb = false
local lastNitroTime = 0

UIS.InputBegan:Connect(function(Input,Processed)

    --print(workspace.CurrentCamera.CFrame)

	--if Processed then return end

	if Car:WaitForChild("Chassis").VehicleSeat.Occupant == nil then return end

	if Input.KeyCode == Enum.KeyCode.H then -- Horn
		Vehicle:Honk(true)
        CarControlBase.HornButton.UIGradient.Enabled = true
	end

	if Input.KeyCode == Enum.KeyCode.G then -- Light
        LightToggle = not LightToggle
		Vehicle:ToggleFrontlights(LightToggle)
        CarControlBase.HeadlightButton.UIGradient.Enabled = LightToggle
	end

	if Input.KeyCode == Enum.KeyCode.S then -- Backlights
		Vehicle:ToggleBacklights(true)
	end

	if Input.KeyCode == Enum.KeyCode.LeftShift then -- Nitro
        if not NitroOn and Car:GetAttribute("Nitro") > 2 then
            Vehicle:ToggleNitro(true, camShake)
            CarControlBase.BoostButton.UIGradient.Enabled = true
            NitroOn = true
            Nitrodb = true
        end
	end

	
	if Input.KeyCode == Enum.KeyCode.Space then -- Brake/Drift
		Vehicle:ToggleDrift(true,Car)
        CarControlBase.HandbrakeButton.UIGradient.Enabled = true
	end


end)

UIS.InputEnded:Connect(function(Input,Processed)

	if Car:WaitForChild("Chassis").VehicleSeat.Occupant == nil then return end

	--if Processed then return end

	if Input.KeyCode == Enum.KeyCode.H then -- Horn
		Vehicle:Honk(false)
        CarControlBase.HornButton.UIGradient.Enabled = false
	end

	if Input.KeyCode == Enum.KeyCode.S then -- Backlights
		Vehicle:ToggleBacklights(false)
	end
	
	if Input.KeyCode == Enum.KeyCode.LeftShift then -- Nitro
		Vehicle:ToggleNitro(false, camShake)
		Vehicle:AdjustNitro(false, NitroGradient,true)
		CarControlBase.BoostButton.UIGradient.Enabled = false
		NitroOn = false
		lastNitroTime = tick() -- Record the time Nitro was deactivated
	end

    if Input.KeyCode ==  Enum.KeyCode.W and math.random(1,3) == 1 then -- Exhaust Pop
        VehicleVisuals:ExhaustPop(Vehicle.Instance.Body["trim_grey_light"],Vehicle.Instance.Effects.Exhaust)
    end

	if Input.KeyCode == Enum.KeyCode.Space then -- Brake/Drift
		Vehicle:ToggleDrift(false,Car)
        CarControlBase.HandbrakeButton.UIGradient.Enabled = false
	end

end)


-- Handles Nitro updates

-- cooldown logic
task.spawn(function()
    while true do
        if not NitroOn and Nitrodb and tick() - lastNitroTime >= 8 then
            Nitrodb = false -- Cooldown resets after 8 seconds
        end
        task.wait(0.05)
    end
end)

while true do
    if NitroOn then
        if Car:GetAttribute("Nitro") > 0 then
            spawn(function()
                Vehicle:AdjustNitro(true, NitroGradient,false)
            end)
        else
            -- Force disable Nitro when it reaches 0
            Vehicle:ToggleNitro(false, camShake)
            Vehicle:AdjustNitro(false, NitroGradient,false)
            CarControlBase.BoostButton.UIGradient.Enabled = false
            NitroOn = false
            Nitrodb = true
            lastNitroTime = tick() -- Start cooldown
        end
    elseif not Nitrodb then
        Vehicle:AdjustNitro(false, NitroGradient, false)
    end
    task.wait(0.03)
end

--end)
