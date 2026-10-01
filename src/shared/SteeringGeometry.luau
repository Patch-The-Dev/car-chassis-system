--!strict

local SteeringGeometry = {}

function SteeringGeometry.forwardSpeed(velocity: Vector3, forward: Vector3): number
	local horizontal = Vector3.new(forward.X, 0, forward.Z)
	if horizontal.Magnitude < 0.000001 then
		return 0
	end
	return math.abs(velocity:Dot(horizontal.Unit))
end

function SteeringGeometry.angles(
	input: number,
	speed: number,
	wheelbase: number,
	trackWidth: number,
	maxAngle: number,
	maxLateralAcceleration: number,
	ackermannRatio: number
): (number, number)
	local limit =
		math.min(maxAngle, math.deg(math.atan(maxLateralAcceleration * wheelbase / math.max(speed * speed, 1))))
	local center = math.abs(input) * limit
	if center < 0.000001 then
		return 0, 0
	end
	local halfTrack = trackWidth / 2
	-- Clamp the turn radius so even the inside wheel stays within the hinge limit.
	local radius = math.max(wheelbase / math.tan(math.rad(center)), halfTrack + wheelbase / math.tan(math.rad(limit)))
	local inner = math.deg(math.atan(wheelbase / (radius - halfTrack)))
	local outer = math.deg(math.atan(wheelbase / (radius + halfTrack)))
	inner = center + (inner - center) * ackermannRatio
	outer = center + (outer - center) * ackermannRatio
	-- The suspension's hinge axis points up: a right turn uses negative angles.
	if input > 0 then
		return -outer, -inner
	end
	return inner, outer
end

return SteeringGeometry
