local Camera = {} -- takes care of all camera effects
Camera.__index = Camera

--variables
local RS = game:GetService("ReplicatedStorage")
local RUNS = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Assets = RS:WaitForChild("Assets")
local Trove = require(script.Parent.Parent:WaitForChild("Libs"):WaitForChild("Trove"))

function Camera:New()
	local self = setmetatable({},Camera)
	self._Trove = Trove.new()
	return self
end

function Camera:StartSpeedlines()

	local Speedlines = Assets:WaitForChild("Speedlines"):Clone()
	Speedlines.Parent = game.Players.LocalPlayer.Character	

	local Connection = RUNS.RenderStepped:Connect(function(deltaTime)

				local cameraCFrame = Workspace.CurrentCamera.CFrame
				local cameraPosition = cameraCFrame.Position
				local cameraLookVector = cameraCFrame.LookVector
		
				local offsetPosition = cameraPosition + (cameraLookVector * 5)
		
				Speedlines.CFrame = CFrame.new(offsetPosition, cameraPosition)
	end)

	self._Trove:Add(Speedlines)
	self._Trove:Add(Connection)

end

function Camera:Destroy()
	self._Trove:Destroy()
end


return Camera