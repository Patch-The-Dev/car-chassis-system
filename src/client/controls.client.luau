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

-- Create the CameraShaker instance
local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
	workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * shakeCFrame
end)

local LightToggle = false

UIS.InputBegan:Connect(function(Input,Processed)

    print(workspace.CurrentCamera.CFrame)

	--if Processed then return end

	if Input.KeyCode == Enum.KeyCode.H then
		Vehicle:Honk(true)
        CarControlBase.HornButton.UIGradient.Enabled = true
	end

	if Input.KeyCode == Enum.KeyCode.G then
        LightToggle = not LightToggle
		Vehicle:ToggleFrontlights(LightToggle)
        CarControlBase.HeadlightButton.UIGradient.Enabled = LightToggle
	end

	if Input.KeyCode == Enum.KeyCode.S then
		Vehicle:ToggleBacklights(true)
	end

	if Input.KeyCode == Enum.KeyCode.LeftShift then
		Vehicle:ToggleNitro(true,camShake)
        CarControlBase.BoostButton.UIGradient.Enabled = true
	end


end)

UIS.InputEnded:Connect(function(Input,Processed)

	--if Processed then return end

	if Input.KeyCode == Enum.KeyCode.H then
		Vehicle:Honk(false)
        CarControlBase.HornButton.UIGradient.Enabled = false
	end

	if Input.KeyCode == Enum.KeyCode.S then
		Vehicle:ToggleBacklights(false)
	end
	
	if Input.KeyCode == Enum.KeyCode.LeftShift then
		Vehicle:ToggleNitro(false,camShake)
        CarControlBase.BoostButton.UIGradient.Enabled = false
	end

    if Input.KeyCode ==  Enum.KeyCode.W then
        VehicleVisuals:ExhaustPop(Vehicle.Instance.Body["trim_grey_light"],Vehicle.Instance.Effects.Exhaust)
    end


end)