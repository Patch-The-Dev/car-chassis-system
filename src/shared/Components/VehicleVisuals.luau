local VehicleVisuals = {}

--variables
local ProximityPromptService = game:GetService("ProximityPromptService")
local TS = game:GetService("TweenService")
local currentRotation = 0 -- Tracks the needle's current rotation
local tween -- Holds the current tween

local CameraShaker = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Libs"):WaitForChild("CameraShaker"))

function VehicleVisuals:AdjustGear(Gear,BackBumper,Amount,MaxSpeed,CamShake,Needle)

	local GearThresholds = {
		[1] = {MinSpeed = 0, Max = MaxSpeed/4},
		[2] = {MinSpeed = MaxSpeed/4, Max = MaxSpeed/3},
		[3] = {MinSpeed = MaxSpeed/3, Max = MaxSpeed/2},
		[4] = {MinSpeed = MaxSpeed/2, Max = MaxSpeed*3/4},
		[5] = {MinSpeed = MaxSpeed*3/4, Max = MaxSpeed}
	}
	local Vehicle = BackBumper.Parent.Parent

	--shifts gear accordingly

	for i, Threshold in ipairs(GearThresholds) do
		if Amount >= Threshold.MinSpeed and Amount < Threshold.Max then
			if tonumber(Gear.Text) ~= tonumber(i) then
				Gear.Text = i
				Vehicle:SetAttribute("Gear",i)
				print(i)
				if i > 3 then
					VehicleVisuals:SimulateSpeed(BackBumper,true,CamShake)

					if i > 4 then
						VehicleVisuals:ToggleSpeedlines(true)
					end

				else
					VehicleVisuals:SimulateSpeed(BackBumper,false,CamShake)
					VehicleVisuals:ToggleSpeedlines(false)
				end

			end
		end
	end

	--Updates speedometer UI
	--Needle.Rotation = (Amount/(GearThresholds[Vehicle:GetAttribute("Gear")].Max)*1.25)*90     -- - 140 -- gets RPM rotation depending on max speed
	VehicleVisuals:updateNeedleRotation(Amount,MaxSpeed, Vehicle:GetAttribute("Gear"), Needle, GearThresholds)

end

function VehicleVisuals:updateNeedleRotation(amount, maxSpeed, gear, Needle, GearThresholds)
    -- Calculate target rotation
    local gearData = GearThresholds[gear]
    if not gearData then return end

    local targetRotation = ((amount / gearData.Max))*240 - 120 
    targetRotation = math.clamp(targetRotation, -140, 130) -- Clamp to valid range (adjust as needed)

    -- Cancel existing tween if it's still running
    if tween then
        tween:Cancel()
    end

    -- Create a new tween for smooth rotation
    local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out) -- Adjust duration/ease
    tween = TS:Create(
        Needle, -- The needle object
        tweenInfo,
        {Rotation = targetRotation}
    )

    -- Start the tween
    tween:Play()

    -- Update the current rotation to the target
    currentRotation = targetRotation
end

function VehicleVisuals:SimulateSpeed(BackBumper,Toggle,CamShake) -- checks the vehicle's back bumper that's gonna have all of the particle effects that beautifies going fast

	if Toggle == true then

		CamShake:Start()
		CamShake:ShakeSustain(CameraShaker.Presets.RoughDriving)

	else

		CamShake:StopSustained(1) -- Stops sustained shake with a fade-out time of 1 second

	end
end

function VehicleVisuals:ExhaustPop(Trim,ExhaustSound)

	ExhaustSound:Play()

	for i,v in Trim:GetDescendants() do
		if v.Name == "GearChange" then
			v:Emit(5)
		end
	end

end

function VehicleVisuals:SimulateNitro(Trim, Toggle, CamShake)

	for i,v in Trim:GetDescendants() do
		if v.Name == "NitroExhaust" then
			v.Enabled = Toggle
		end
	end
	
	if Toggle == true then
		CamShake:Start()
		CamShake:ShakeSustain(CameraShaker.Presets.Bump)
		VehicleVisuals:ToggleSpeedlines(true)
	else
		CamShake:StopSustained(1)
		VehicleVisuals:ToggleSpeedlines(false)
	end

end

function VehicleVisuals:SimulateDrift(Trim,Bumper,Toggle)
	local DriftSFX = Trim:WaitForChild("Drift")
	local LeftTireSmoke =  Bumper:WaitForChild("DriftAttLeft"):WaitForChild("Smoke Particle")
	local RightTireSmoke =  Bumper:WaitForChild("DriftAttRight"):WaitForChild("Smoke Particle")

	if Toggle == true then
		DriftSFX:Play()
		LeftTireSmoke.Enabled = true
		RightTireSmoke.Enabled = true

		for i,v in Bumper:GetChildren() do
			if v:IsA("Trail") then
				v.Enabled = true
			end
		end

	else
		DriftSFX:Stop()
		LeftTireSmoke.Enabled = false
		RightTireSmoke.Enabled = false

		for i,v in Bumper:GetChildren() do
			if v:IsA("Trail") then
				v.Enabled = false
			end
		end

	end

end

function VehicleVisuals:ToggleSpeedlines(Toggle)
	local Char = game.Players.LocalPlayer.Character
	local Speedlines = Char:FindFirstChild("Speedlines")
	if Speedlines then
		Speedlines.ParticleEmitter.Enabled = Toggle
	end
end

function VehicleVisuals:AdjustFOV(Mph,MaxSpeed)

	local Amount = 0

	if Mph >= MaxSpeed/4 then Amount = 7.5 end
	if Mph >= MaxSpeed/2 then Amount = 15 end
	if Mph >= MaxSpeed*3/4 then Amount = 22.5 end

	local Cam = game.Workspace.CurrentCamera
	local TC = TS:Create(Cam,TweenInfo.new(0.2,Enum.EasingStyle.Linear,Enum.EasingDirection.In),{FieldOfView = 70 + Amount})
	TC:Play()

end


return VehicleVisuals