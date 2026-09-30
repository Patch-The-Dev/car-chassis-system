--!strict

-- Only settings used by this implementation live here. Vehicle geometry
-- remains in the authored vehicle model.
return table.freeze({
	Tag = "ChassisVehicle",
	InputTimeout = 0.35,
	InputRateLimit = 1 / 30,
	Drivetrain = "AWD", -- "FWD", "RWD", or "AWD"
	MaxForwardSpeed = 110, -- studs per second
	MaxReverseSpeed = 30,
	DriveTorque = 12000,
	CoastTorque = 250,
	BrakeTorque = 4000,
	SteerAngle = 35, -- degrees
	SteerAngularSpeed = 5,
	SteerTorque = 50000,
	WheelDensity = 0.1,
	Suspension = {
		Front = { Stiffness = 17000, Damping = 401, Length = 1.9, Compression = 0.05, Extension = 0.3 },
		Rear = { Stiffness = 14000, Damping = 401, Length = 2, Compression = 0.1, Extension = 0.3 },
	},
})
