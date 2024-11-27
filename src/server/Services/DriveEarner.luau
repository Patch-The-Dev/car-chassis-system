local LocalizationService = game:GetService("LocalizationService")
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local ProfileManager = require(game:GetService("ServerScriptService"):WaitForChild("ProfileService"):WaitForChild("ProfileManager"))

-- Create the service:
local DriveEarnerService = Knit.CreateService {
	Name = "DriveEarnerService",
	Client = {}
}

function DriveEarnerService.Client:AddCash(Player,UI) 
	local Profile = ProfileManager.Profiles[Player]
	if Profile then
		Profile.Data.Cash += 1
		UI.Text = "+$" .. Profile.Data.Cash
		print(Profile.Data.Cash)
	end
end

function DriveEarnerService.Client:CashAmount(Player)
	local Profile = ProfileManager.Profiles[Player]
	if Profile then
		return Profile.Data.Cash
	end
end

return DriveEarnerService