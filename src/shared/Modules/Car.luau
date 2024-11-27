local Car = {}
Car.__index = Car

--variables

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
wait(1)
local CarControllerService = Knit.GetService("CarControllerService")
local VehicleVisuals = require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("VehicleVisuals"))
local GuiVisualizer = require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("GuiVisualizer"))


function Car:New(CarInstance)
	local self = setmetatable({},Car)
	self.Instance = CarInstance
	return self
end

function Car:Honk(Toggle)

	print("Honking")

	if Toggle == true then

		self.Instance.Body.PrimaryPart:WaitForChild("Honk"):Play()

	else

		self.Instance.Body.PrimaryPart:WaitForChild("Honk"):Stop()

	end

end

function Car:ToggleBacklights(Toggle)
	CarControllerService:ToggleBacklights(self.Instance,Toggle)
end

function Car:ToggleFrontlights(Toggle)
	CarControllerService:ToggleFrontlights(self.Instance,Toggle)
end

function Car:ToggleNitro(Toggle,CamShake)
	VehicleVisuals:SimulateNitro(self.Instance.Body:WaitForChild("trim_grey_light"),Toggle,CamShake)
	if Toggle == true then 
		self.Instance:WaitForChild("Effects").Nitro:Play()
	else
		self.Instance:WaitForChild("Effects").Nitro:Stop()
	end
end

function Car:AdjustNitro(Toggle,UIGradient)
	CarControllerService:AdjustNitro(self.Instance,Toggle)
	GuiVisualizer:GradientProgressBar(UIGradient,100,self.Instance:GetAttribute("Nitro"))
end

function Car:ToggleDrift(Toggle,Car)
	VehicleVisuals:SimulateDrift(self.Instance.Body.PrimaryPart,self.Instance.Body["bumper_back"],Toggle)
	CarControllerService:ToggleDrift(self.Instance,Toggle)
end

return Car