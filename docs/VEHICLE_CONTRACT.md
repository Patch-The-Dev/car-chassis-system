# Vehicle contract

The chassis attaches to a `Model` tagged `ChassisVehicle`. It expects a direct child `VehicleSeat` named `DriveSeat`, a direct child `Body` model, and a direct child `Wheels` model or folder with `FL`, `FR`, `RL`, and `RR` BaseParts. Each of these names must be unique within its parent. `Misc` is an optional, uniquely named model or folder; its BasePart descendants are welded to the drive seat along with `Body`. Duplicate names are rejected before model assembly.

## Geometry

- Position the four wheels around the vehicle before tagging it. `FL` and `FR` are the front axle; `RL` and `RR` are the rear axle.
- The drive seat's `LookVector` is forward, `RightVector` is the axle direction, and `UpVector` is the suspension travel direction. Orient the seat consistently with the vehicle body.
- Front and rear axle centers must be separated along the seat's forward axis, and the front wheels must be separated along its right axis. These measurements define wheelbase and track width for steering geometry.
- Give each wheel a round collision shape. The chassis installs local `NoCollisionConstraint`s for wheel and body pairs close enough to contact during suspension travel, regardless of the body's initial `CanCollide` value. Distant decorative parts add no wheel constraints; tires continue to collide with the environment. The motor hinge axis follows the seat's right vector, so authored wheel visuals should align with that axle.
- The wheel radius used for the target angular speed is half of the smaller `Y` or `Z` dimension. Use a true wheel diameter for these dimensions when authoring a cylindrical wheel.
- Author body and wheel parts anchored for placement. Initialization unanchors them after creating the joints. Untagging restores their original anchor and wheel physical-property settings.
- Avoid pre-existing welds between the wheels and body. Such welds bypass the suspension and motors. The chassis creates body welds, wheel carriers, steering pivots, and all active constraints.

## Runtime lifecycle

`ChassisRegistry` watches the CollectionService tag and model ancestry. It creates one `VehicleChassis` controller per tagged model in `Workspace`. A tagged model stored elsewhere attaches when moved into `Workspace`; moving it out or removing its tag tears it down. If a required part is missing, the registry retries when a required direct child or wheel is added. Call `registry:Retry(model)` after an in-place correction such as renaming a part. A valid model gets a `ChassisRuntime` folder holding generated carrier parts and constraints; attachments live on their corresponding parts. Teardown also returns network ownership to automatic while the assembly is intact.

The client samples the seat after Roblox's input update and sends throttle and steer at up to 20 Hz while seated, with Left Shift, gamepad L1, or a contextual touch button as handbrake. A single sender handles seat transitions, tag replication, and character replacement. The server checks the current occupant, rejects malformed input, and caps values to the seat range. Each controller uses its own `InputRateLimit` (30 Hz by default). The separate place-wide `RemoteRateLimit` gates traffic per player before model lookup (120 Hz by default), so a vehicle tuned for 60 Hz is not capped at the default controller rate. Custom senders remain subject to both limits. Input expires after 0.35 seconds by default. A new driver starts with neutral controls.

The input remote lives at `ReplicatedStorage.ChassisShared.Remotes.Input`. Startup reuses a remote at that path and fails clearly if the existing object has the wrong class or duplicate name.

## Tuning

[`ChassisConfig.luau`](../src/shared/ChassisConfig.luau) contains only values used by the implementation:

| Setting | Effect |
| --- | --- |
| `Drivetrain` | Selects `FWD`, `RWD`, or `AWD`. |
| `NetworkOwnership` | `Driver` assigns the seated player and returns to automatic ownership on exit. `Server` explicitly retains server ownership throughout the running lifecycle. Both restore automatic ownership on detach. |
| `InputRateLimit`, `InputTimeout` | Per-vehicle minimum accepted input interval and control expiry. |
| `RemoteRateLimit` | Place-wide minimum remote interval per player, read from the default config by the registry. Per-vehicle overrides do not change this abuse protection. |
| `MaxForwardSpeed`, `MaxReverseSpeed` | Convert seat throttle to wheel angular velocity using wheel radius. |
| `MaxAcceleration`, `MaxDeceleration` | Cap powered and braking wheel torque using assembled mass and wheel radius. Values are in studs per second squared. Mass is measured at initialization and whenever the occupant changes. |
| `MaxLateralAcceleration` | Reduce steering angle as speed rises, using wheelbase and a bicycle-model turn-radius estimate. This bounds the requested angle, not the actual measured lateral acceleration. |
| `DriveTorque`, `CoastTorque`, `BrakeTorque` | Limit wheel motor force under power, coasting, and handbrake. Undriven wheels free roll outside braking; the handbrake targets zero wheel speed. |
| `SteerAngle`, `SteerAngularSpeed`, `SteerTorque` | Set the front steering servo target and response. |
| `AckermannRatio` | Blend parallel steering (`0`) with measured inner/outer wheel geometry (`1`). Both wheels stay within `SteerAngle` and the speed-based angle limit. |
| `WheelDensity` | Set the wheel physical density while the chassis runs. |
| `Tires` | Set `Friction` (0 to 2), `Elasticity` (0 to 1), and their weights (0 to 100). Lower friction weighting lets the contact surface contribute more to effective grip. |
| `Suspension.Front`, `Suspension.Rear` | Set spring stiffness, damping, finite `MaxForce`, rest length, and travel limits per axle. Tune force and stiffness to the supported load; unlimited spring force can destabilize lightweight assemblies. |

Changing the `ChassisConfig` module affects the default tuning of tagged vehicles in that place. The defaults and controller snapshots are frozen at every table level. `ConfigCopy.copy()` returns an independent mutable table for authoring overrides. Retune a running vehicle by detaching it and creating a new controller; mutating a caller's tuning table has no effect on the existing controller.

Configuration copying and freezing traverse nested tables recursively, so new groups of settings remain isolated without adding special cases to `ConfigCopy`.

## Steering and tire behavior

Steering projects velocity onto the seat's horizontal forward direction, excluding vertical and lateral movement from the speed-based limit. The front wheels follow different radii during a turn. `AckermannRatio` controls the geometry blend; at `1`, the inner wheel turns more sharply than the outer wheel. The radius is constrained so neither wheel exceeds the configured angle. A right steering input produces a negative angle about the upward-pointing hinge axis.

Tire settings become each wheel's `CustomPhysicalProperties` during assembly and are restored during teardown. Defaults retain the existing high-grip behavior. Tune `FrictionWeight` alongside `Friction` when road materials should have more influence on grip. Wheel motors use target speed and bounded torque; the chassis provides no gearbox or tire slip-force model.

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
        tune.Tires.Friction = 0.8
        tune.Tires.FrictionWeight = 10
        return tune
    end
    return nil -- Use the defaults for other vehicles.
end)
registry:Start()
```

Direct integrations can instead call `VehicleChassis.new(model, tune)` followed by `controller:Start()`. They must call `Step(os.clock())` during their update loop, route authenticated input through `ApplyInput`, and call `Destroy()` on removal. Avoid managing the same model through both a registry and a direct controller.
