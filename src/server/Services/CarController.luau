local LocalizationService = game:GetService("LocalizationService")
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Create the service:
local CarControllerService = Knit.CreateService {
	Name = "CarControllerService",
	Client = {}
}

function CarControllerService.Client:ToggleBacklights(Player, Car, Toggle) 
	for i,v in Car.Body:WaitForChild("bumper_back"):GetDescendants() do
		if v:IsA("PointLight") then
			v.Enabled = Toggle
		end
	end
end

function CarControllerService.Client:ToggleFrontlights(Player, Car, Toggle)
	print("Turning on lights")
	for i,v in Car.Body:WaitForChild("light_white"):GetDescendants() do
		if v:IsA("SpotLight") or v:IsA("Beam") then
			v.Enabled = Toggle
		end
	end
end

function CarControllerService.Client:AdjustNitro(Player,Car,Toggle,LSToggle)

	if Toggle == true then
		if Car:GetAttribute("Nitro") > 0 then
			Car:SetAttribute("Nitro",Car:GetAttribute("Nitro")-1)
		end
		if Car:GetAttribute("DrivingTorque") ~= Car:GetAttribute("NitroTorque") then
			Car:SetAttribute("DrivingTorque",Car:GetAttribute("NitroTorque"))
			Car:SetAttribute("MaxSteer",Car:GetAttribute("NitroSteer"))
		end
	else
		if Car:GetAttribute("Nitro") < 100 then
			if Car:GetAttribute("DrivingTorque") == Car:GetAttribute("NitroTorque") then
				Car:SetAttribute("DrivingTorque",15000)
				Car:SetAttribute("MaxSteer",15)
			end
			if LSToggle == false then
				Car:SetAttribute("Nitro",Car:GetAttribute("Nitro")+1)
			end
		end
	end

end

function CarControllerService.Client:ToggleDrift(Player, Car, Toggle)
	print("Drifting")
	if Toggle == true then
		Car:SetAttribute("BrakingTorque",4000)
		Car:SetAttribute("DrivingTorque",4000)
		Car:SetAttribute("MaxSteer",200)
		Car:SetAttribute("WheelFriction",0.25)
	else
		Car:SetAttribute("DrivingTorque",15000)
		Car:SetAttribute("MaxSteer",15)
		Car:SetAttribute("WheelFriction",3)
	end
end



return CarControllerService