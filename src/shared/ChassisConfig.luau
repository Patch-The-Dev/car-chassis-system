--!strict

-- Only settings used by this implementation live here. Vehicle geometry
-- remains in the authored vehicle model.
local ConfigTree = require(script.Parent.ConfigTree)
return ConfigTree.freeze({
	Tag = "ChassisVehicle",
	InputTimeout = 0.35,
	InputRateLimit = 1 / 30,
	RemoteRateLimit = 1 / 120, -- Place-wide abuse gate, independent of vehicle tuning.
	NetworkOwnership = "Driver", -- "Server" keeps the running mechanism on the server.
	Drivetrain = "AWD", -- "FWD", "RWD", or "AWD"
	MaxForwardSpeed = 110, -- studs per second
	MaxReverseSpeed = 30,
	MaxAcceleration = 40, -- studs per second squared
	MaxDeceleration = 60,
	MaxLateralAcceleration = 80,
	DriveTorque = 12000,
	CoastTorque = 250,
	BrakeTorque = 4000,
	SteerAngle = 35, -- degrees
	SteerAngularSpeed = 5,
	SteerTorque = 50000,
	AckermannRatio = 1, -- 0 = parallel steering; 1 = geometric inner/outer wheel angles.
	WheelDensity = 0.1,
	Tires = {
		Friction = 1,
		Elasticity = 0,
		FrictionWeight = 100,
		ElasticityWeight = 100,
	},
	Suspension = {
		Front = {
			Stiffness = 17000,
			Damping = 401,
			MaxForce = 4000,
			Length = 1.9,
			Compression = 0.05,
			Extension = 0.3,
		},
		Rear = {
			Stiffness = 14000,
			Damping = 401,
			MaxForce = 4000,
			Length = 2,
			Compression = 0.1,
			Extension = 0.3,
		},
	},
})
