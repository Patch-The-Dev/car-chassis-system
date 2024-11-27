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

UIS.InputBegan:Connect(function(Input,Processed)

    --print(workspace.CurrentCamera.CFrame)

	--if Processed then return end

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
		Vehicle:ToggleNitro(true,camShake)
        CarControlBase.BoostButton.UIGradient.Enabled = true
		NitroOn = true
	end

	
	if Input.KeyCode == Enum.KeyCode.Space then -- Brake/Drift
		Vehicle:ToggleDrift(true,Car)
        CarControlBase.HandbrakeButton.UIGradient.Enabled = true
	end


end)

UIS.InputEnded:Connect(function(Input,Processed)

	--if Processed then return end

	if Input.KeyCode == Enum.KeyCode.H then -- Horn
		Vehicle:Honk(false)
        CarControlBase.HornButton.UIGradient.Enabled = false
	end

	if Input.KeyCode == Enum.KeyCode.S then -- Backlights
		Vehicle:ToggleBacklights(false)
	end
	
	if Input.KeyCode == Enum.KeyCode.LeftShift then -- Nitro
		Vehicle:ToggleNitro(false,camShake)
		Vehicle:AdjustNitro(false,NitroGradient)
        CarControlBase.BoostButton.UIGradient.Enabled = false
		NitroOn = false
		Nitrodb = true
		Wait(3)
		Nitrodb = false
	end

    if Input.KeyCode ==  Enum.KeyCode.W then -- Exhaust Pop
        VehicleVisuals:ExhaustPop(Vehicle.Instance.Body["trim_grey_light"],Vehicle.Instance.Effects.Exhaust)
    end

	if Input.KeyCode == Enum.KeyCode.Space then -- Brake/Drift
		Vehicle:ToggleDrift(false,Car)
        CarControlBase.HandbrakeButton.UIGradient.Enabled = false
	end

end)


-- Handles Nitro updates
while true do
	if NitroOn == true then
		Wait(0.015)
		if Car:GetAttribute("Nitro") > 0 then
			Vehicle:AdjustNitro(true,NitroGradient)
		else
			Vehicle:ToggleNitro(false,camShake)
		end
	else
		if Nitrodb == false then
			Vehicle:AdjustNitro(false,NitroGradient)
			Wait(0.015)
		end
	end
	Wait(0.01)
end

--end)

