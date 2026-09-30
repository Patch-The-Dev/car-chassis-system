# Vehicle contract

The chassis attaches to a `Model` tagged `ChassisVehicle`. It expects a direct child `VehicleSeat` named `DriveSeat`, a direct child `Body` model, and a direct child `Wheels` model or folder with `FL`, `FR`, `RL`, and `RR` BaseParts. `Misc` is optional; its BasePart descendants are welded to the drive seat along with `Body`.

## Geometry

- Position the four wheels around the vehicle before tagging it. `FL` and `FR` are the front axle; `RL` and `RR` are the rear axle.
- The drive seat's `LookVector` is forward, `RightVector` is the axle direction, and `UpVector` is the suspension travel direction. Orient the seat consistently with the vehicle body.
- Give each wheel a round collision shape and enough clearance from the body. The motor hinge axis follows the seat's right vector, so authored wheel visuals should align with that axle.
- The wheel radius used for the target angular speed is half of the smaller `Y` or `Z` dimension. Use a true wheel diameter for these dimensions when authoring a cylindrical wheel.
- Author body and wheel parts anchored for placement. Initialization unanchors them after creating the joints. Untagging restores their original anchor and wheel physical-property settings.
- Avoid pre-existing welds between the wheels and body. Such welds bypass the suspension and motors. The chassis creates body welds, wheel carriers, steering pivots, and all active constraints.

## Runtime lifecycle

`ChassisBootstrap` watches the CollectionService tag. It creates one `VehicleChassis` controller per model and calls `Start` once. An invalid model fails without partial assembly. A valid model gets a `ChassisRuntime` folder holding generated carrier parts and constraints; attachments live on their corresponding parts. Removing the tag or model tears down the controller and generated instances.

The client sends the local seat's throttle and steer values at 20 Hz while seated, with Left Shift or gamepad L1 as handbrake. The server checks the current occupant, rejects malformed input, caps values to the seat range, and limits accepted packets to 30 Hz. Input expires after 0.35 seconds. A new driver starts with neutral controls.

## Tuning

[`ChassisConfig.luau`](../src/shared/ChassisConfig.luau) contains only values used by the implementation:

| Setting | Effect |
| --- | --- |
| `Drivetrain` | Selects `FWD`, `RWD`, or `AWD`. |
| `MaxForwardSpeed`, `MaxReverseSpeed` | Convert seat throttle to wheel angular velocity using wheel radius. |
| `DriveTorque`, `CoastTorque`, `BrakeTorque` | Limit wheel motor force under power, coasting, and handbrake. |
| `SteerAngle`, `SteerAngularSpeed`, `SteerTorque` | Set the front steering servo target and response. |
| `WheelDensity` | Set the wheel physical density while the chassis runs. |
| `Suspension.Front`, `Suspension.Rear` | Set spring stiffness, damping, rest length, and travel limits per axle. |

Changing the `ChassisConfig` module affects every tagged vehicle in that place. For game-specific handling variants, load a vehicle-specific config when constructing each `VehicleChassis` controller.
