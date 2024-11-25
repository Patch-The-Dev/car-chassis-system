-- this script goes over game effects 

--Variables
local RUNS = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local CameraModule = require(RS:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Camera"))

local MyCam = CameraModule:New()
local Car = game.Workspace:WaitForChild("Car") -- temporary until later changed
local Seat = Car:WaitForChild("Chassis"):WaitForChild("VehicleSeat")

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local plrgui = plr:WaitForChild("PlayerGui")
local CarGui = plrgui:WaitForChild("Car")

Seat.Changed:Connect(function(property) -- checks if the player is in the car seat
    if property == "Occupant" then
        if Seat.Occupant then
            CameraModule:StartSpeedlines() -- starts speedlines
            CarGui.Enabled = true
        else
            CameraModule:DestroySpeedlines() --stops speedlines
            CarGui.Enabled = false
        end
    end
end)