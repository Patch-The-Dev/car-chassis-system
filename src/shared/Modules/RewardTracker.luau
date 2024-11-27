local RewardTracker = {}
RewardTracker.__index = RewardTracker

--variables
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
wait(1)
local DriveEarnerService = Knit.GetService("DriveEarnerService")

-- Constructor (tracks reward for drifting, crashing and speeding)
function RewardTracker:New(vehicle, player)
    local self = setmetatable({}, RewardTracker)
    self.Vehicle = vehicle
    self.Player = player
    self.UI = player:WaitForChild("PlayerGui"):WaitForChild("Car"):WaitForChild("DriveToEarnBase")
    print("Running")
    return self
end

-- Handle speed-based earnings
function RewardTracker:AddCash()
    DriveEarnerService:AddCash(self.UI:WaitForChild("Currency"))
end

function RewardTracker:ToggleDriveToEarn(Toggle)
    self.UI.Visible = Toggle 
end



function RewardTracker:EnableEarnType(Type)
    local EarningUI = self.UI:FindFirstChild(Type)
    if EarningUI then
        for i,v in self.UI:GetChildren() do
            if v.Name ~= EarningUI.Name and v.Name ~= "Currency" then
                v.Visible = false
            else
                v.Visible = true
            end
        end
    end
end

-- Finalize rewards
function RewardTracker:finalizeRewards()

end

return RewardTracker
