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

function CarControllerService.Client:ToggleNitro(Player, Car, Toggle)
	
	local TorqueAmount = 1
	local SteerAmount = 1
	
	if Toggle == true then
		TorqueAmount = 2
		SteerAmount = 1/4

	else
		TorqueAmount = 1/2
		SteerAmount = 4
	end
	
	Car:SetAttribute("DrivingTorque",Car:GetAttribute("DrivingTorque")*TorqueAmount)
	Car:SetAttribute("MaxSteer",Car:GetAttribute("MaxSteer")*SteerAmount)

end


return CarControllerService