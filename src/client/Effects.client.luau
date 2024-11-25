-- this script goes over game effects 

--Variables
local RUNS = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local CameraModule = require(RS:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Camera"))

local MyCam = CameraModule:New()
local Car = game.Workspace:WaitForChild("Car") -- temporary until later changed
local Seat = Car:WaitForChild("Chassis"):WaitForChild("VehicleSeat")

-- Connect to the seat's Changed event
Seat.Changed:Connect(function(property)
    if property == "Occupant" then
        if Seat.Occupant then
            print("Player is now sitting on the DriverSeat!")
            CameraModule:StartSpeedlines()
        else
            print("Player has left the DriverSeat.")
            CameraModule:Destroy()
        end
    end
end)