--!strict

local InputPolicy = {}

local function finiteUnit(value: unknown): number?
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return nil
	end
	return math.clamp(value, -1, 1)
end

function InputPolicy.sanitize(throttle: unknown, steer: unknown, brake: unknown): (number?, number?, boolean?)
	local safeThrottle = finiteUnit(throttle)
	local safeSteer = finiteUnit(steer)
	if safeThrottle == nil or safeSteer == nil or typeof(brake) ~= "boolean" then
		return nil, nil, nil
	end
	return safeThrottle, safeSteer, brake
end

function InputPolicy.isDriven(wheelName: string, drivetrain: string): boolean
	local front = wheelName == "FL" or wheelName == "FR"
	return drivetrain == "AWD" or (drivetrain == "FWD" and front) or (drivetrain == "RWD" and not front)
end

function InputPolicy.targetAngularVelocity(
	throttle: number,
	radius: number,
	forwardSpeed: number,
	reverseSpeed: number
): number
	local speed = if throttle >= 0 then forwardSpeed else reverseSpeed
	return -throttle * speed / math.max(radius, 0.1)
end

return InputPolicy
