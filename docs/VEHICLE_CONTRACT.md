# Vehicle contract

The chassis attaches to a `Model` tagged `ChassisVehicle`. It expects a direct child `VehicleSeat` named `DriveSeat`, a direct child `Body` model, and a direct child `Wheels` model or folder with `FL`, `FR`, `RL`, and `RR` BaseParts. `Misc` is an optional model or folder; its BasePart descendants are welded to the drive seat along with `Body`.

## Geometry

- Position the four wheels around the vehicle before tagging it. `FL` and `FR` are the front axle; `RL` and `RR` are the rear axle.
- The drive seat's `LookVector` is forward, `RightVector` is the axle direction, and `UpVector` is the suspension travel direction. Orient the seat consistently with the vehicle body.
- Give each wheel a round collision shape. The chassis installs local `NoCollisionConstraint`s for wheel and body pairs close enough to contact during suspension travel, regardless of the body's initial `CanCollide` value. Distant decorative parts add no wheel constraints; tires continue to collide with the environment. The motor hinge axis follows the seat's right vector, so authored wheel visuals should align with that axle.
- The wheel radius used for the target angular speed is half of the smaller `Y` or `Z` dimension. Use a true wheel diameter for these dimensions when authoring a cylindrical wheel.
- Author body and wheel parts anchored for placement. Initialization unanchors them after creating the joints. Untagging restores their original anchor and wheel physical-property settings.
- Avoid pre-existing welds between the wheels and body. Such welds bypass the suspension and motors. The chassis creates body welds, wheel carriers, steering pivots, and all active constraints.

## Runtime lifecycle

`ChassisRegistry` watches the CollectionService tag and model ancestry. It creates one `VehicleChassis` controller per tagged model in `Workspace`. A tagged model stored elsewhere attaches when moved into `Workspace`; moving it out or removing its tag tears it down. If a required part is missing, the registry retries when a required direct child or wheel is added. Call `registry:Retry(model)` after an in-place correction such as renaming a part. A valid model gets a `ChassisRuntime` folder holding generated carrier parts and constraints; attachments live on their corresponding parts. Teardown also returns network ownership to automatic while the assembly is intact.

The client sends the local seat's throttle and steer values at 20 Hz while seated, with Left Shift, gamepad L1, or a contextual touch button as handbrake. The server checks the current occupant, rejects malformed input, caps values to the seat range, and limits accepted packets to 30 Hz. The registry also gates incoming packets per player before looking up the vehicle. Input expires after 0.35 seconds. A new driver starts with neutral controls.

The input remote lives at `ReplicatedStorage.ChassisShared.Remotes.Input`. Startup reuses a remote at that path and fails clearly if the existing object has the wrong class or duplicate name.

## Tuning

[`ChassisConfig.luau`](../src/shared/ChassisConfig.luau) contains only values used by the implementation:

| Setting | Effect |
| --- | --- |
| `Drivetrain` | Selects `FWD`, `RWD`, or `AWD`. |
| `MaxForwardSpeed`, `MaxReverseSpeed` | Convert seat throttle to wheel angular velocity using wheel radius. |
| `MaxAcceleration`, `MaxDeceleration` | Cap powered and braking wheel torque using assembled mass and wheel radius. Values are in studs per second squared. Mass is measured at initialization and whenever the occupant changes. |
| `MaxLateralAcceleration` | Reduce steering angle as speed rises, using wheelbase and a bicycle-model turn-radius estimate. This bounds the requested angle, not the actual measured lateral acceleration. |
| `DriveTorque`, `CoastTorque`, `BrakeTorque` | Limit wheel motor force under power, coasting, and handbrake. Undriven wheels free roll outside braking; the handbrake targets zero wheel speed. |
| `SteerAngle`, `SteerAngularSpeed`, `SteerTorque` | Set the front steering servo target and response. |
| `WheelDensity` | Set the wheel physical density while the chassis runs. |
| `Suspension.Front`, `Suspension.Rear` | Set spring stiffness, damping, finite `MaxForce`, rest length, and travel limits per axle. Tune force and stiffness to the supported load; unlimited spring force can destabilize lightweight assemblies. |

Changing the `ChassisConfig` module affects the default tuning of tagged vehicles in that place. The defaults and controller snapshots are frozen at every table level. `ConfigCopy.copy()` returns an independent mutable table for authoring overrides. Retune a running vehicle by detaching it and creating a new controller; mutating a caller's tuning table has no effect on the existing controller.

## Per-vehicle configuration

For tagged vehicles, replace the registry construction in `ChassisBootstrap.server.luau` with a resolver. Keep one registry per place. Resolve tuning synchronously from server-owned configuration; do not accept tuning from the client.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigCopy = require(ReplicatedStorage.ChassisShared.ConfigCopy)
local ChassisRegistry = require(script.Parent.ChassisRegistry)

local registry = ChassisRegistry.new(function(model)
    if model:GetAttribute("VehicleClass") == "RearDrive" then
        local tune = ConfigCopy.copy()
        tune.Drivetrain = "RWD"
        tune.MaxAcceleration = 30
        tune.Suspension.Front.Stiffness = 15000
        return tune
    end
    return nil -- Use the defaults for other vehicles.
end)
registry:Start()
```

Direct integrations can instead call `VehicleChassis.new(model, tune)` followed by `controller:Start()`. They must call `Step(os.clock())` during their update loop, route authenticated input through `ApplyInput`, and call `Destroy()` on removal. Avoid managing the same model through both a registry and a direct controller.
