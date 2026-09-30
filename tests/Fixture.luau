--!strict

local Fixture = {}

function Fixture.create(): Model
	local car = Instance.new("Model")
	car.Name = "TestVehicle"

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriveSeat"
	seat.CFrame = CFrame.new(0, 5, 0)
	seat.Anchored = true
	seat.Parent = car

	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = car
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.CFrame = CFrame.new(0, 4.5, 0)
	shell.Anchored = true
	shell.Parent = body

	local wheels = Instance.new("Model")
	wheels.Name = "Wheels"
	wheels.Parent = car
	for name, position in
		{
			FL = Vector3.new(-3, 2.5, -3),
			FR = Vector3.new(3, 2.5, -3),
			RL = Vector3.new(-3, 2.5, 3),
			RR = Vector3.new(3, 2.5, 3),
		}
	do
		local wheel = Instance.new("Part")
		wheel.Name = name
		wheel.Shape = Enum.PartType.Ball
		wheel.Size = Vector3.new(2, 2, 2)
		wheel.CFrame = CFrame.new(position)
		wheel.Anchored = true
		wheel.Parent = wheels
	end

	car.Parent = workspace
	return car
end

return Fixture
