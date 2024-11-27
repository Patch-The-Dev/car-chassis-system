local VehicleVisuals = {}

--variables
local ProximityPromptService = game:GetService("ProximityPromptService")
local TS = game:GetService("TweenService")
local CameraShaker = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Libs"):WaitForChild("CameraShaker"))


function VehicleVisuals:AdjustGear(Gear,BackBumper,Amount,MaxSpeed,CamShake,ExhaustSound,Trim)

	local GearThresholds = {
		[1] = {MinSpeed = 0, Max = MaxSpeed/6},
		[2] = {MinSpeed = MaxSpeed/6, Max = MaxSpeed/3},
		[3] = {MinSpeed = MaxSpeed/3, Max = MaxSpeed/2},
		[4] = {MinSpeed = MaxSpeed/2, Max = MaxSpeed*3/4},
		[5] = {MinSpeed = MaxSpeed*3/4, Max = MaxSpeed}
	}

	for i, Threshold in ipairs(GearThresholds) do
		if Amount >= Threshold.MinSpeed and Amount < Threshold.Max then
			if tonumber(Gear.Text) ~= tonumber(i) then
				Gear.Text = i
				local Vehicle = BackBumper.Parent.Parent
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