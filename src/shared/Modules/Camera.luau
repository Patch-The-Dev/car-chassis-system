local Camera = {} -- takes care of all camera effects
Camera.__index = Camera

--variables
local RS = game:GetService("ReplicatedStorage")
local RUNS = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Assets = RS:WaitForChild("Assets")
local Trove = require(RS:WaitForChild("Packages"):WaitForChild("Trove"))

function Camera:New()
	local self = setmetatable({},Camera)
	self.trove = Trove.new()
	return self
end

function Camera:StartSpeedlines()

	local Speedlines = Assets:WaitForChild("Speedlines"):Clone()
	Speedlines.Parent = game.Players.LocalPlayer.Character	

	local Connection = RUNS.RenderStepped:Connect(function(deltaTime)

				local cameraCFrame = Workspace.CurrentCamera.CFrame
				local cameraPosition = cameraCFrame.Position
				local cameraLookVector = cameraCFrame.LookVector
		
				local offsetPosition = cameraPosition + (cameraLookVector * 10)
		
				Speedlines.CFrame = CFrame.new(offsetPosition, cameraPosition)
	end)


end

function Camera:DestroySpeedlines()
	game.Players.LocalPlayer.Character:FindFirstChild("Speedlines"):Destroy()
end


return Camera