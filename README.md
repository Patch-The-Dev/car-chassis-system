# Car Chassis System

A reusable Roblox chassis for four-wheel vehicle models. The server assembles suspension, steering, and powered wheel constraints around an authored vehicle. A seated driver controls it through the normal `VehicleSeat` input. The source is organized for Rojo and Git, with no runtime packages.

## What it does

- Builds independent wheel carriers, spring suspension, front steering servos, and wheel motors from a vehicle model.
- Supports front, rear, or all-wheel drive, with an optional tuning table per controller.
- Limits drive and braking torque using assembled vehicle mass and wheel radius, caps suspension force, and reduces steering angle at speed.
- Uses Ackermann steering for different inner and outer wheel angles, with an adjustable blend for parallel steering.
- Accepts input only from the player occupying that vehicle's drive seat. The server bounds the values, limits request rate, and returns the motors to neutral when input stops.
- Supports driver-owned or server-owned physics per vehicle, with ownership cleanup on detach.
- Separates wheels from nearby body parts while retaining collision with the world; distant decorative parts add no wheel collision constraints.
- Updates only vehicles with active input in the control loop; parked vehicles are removed after neutralization.
- Handles multiple tagged vehicles, including models moved into or out of `Workspace`, and removes generated parts, constraints, and connections on detach.

The chassis does not depend on a specific car mesh, dashboard, currency system, or game framework. Vehicle art and proportions are supplied by the game using it.

## Repository layout

| Path | Responsibility |
| --- | --- |
| [`src/server/VehicleChassis.luau`](src/server/VehicleChassis.luau) | Validates and assembles one vehicle; owns driver state and cleanup. |
| [`src/server/ChassisBootstrap.server.luau`](src/server/ChassisBootstrap.server.luau) | Starts the vehicle registry. |
| [`src/server/ChassisRegistry.luau`](src/server/ChassisRegistry.luau) | Owns tagged model lifecycle and the namespaced input remote. |
| [`src/client/DriverInput.client.luau`](src/client/DriverInput.client.luau) | Relays the local `VehicleSeat` controls and handbrake input. |
| [`src/shared/ChassisConfig.luau`](src/shared/ChassisConfig.luau) | Active tuning values for drivetrain, steering, torque, and suspension. |
| [`src/shared/ConfigCopy.luau`](src/shared/ConfigCopy.luau) | Creates independent per-vehicle tuning from the defaults or a supplied table. |
| [`src/shared/ConfigTree.luau`](src/shared/ConfigTree.luau) | Recursively copies and freezes configuration, including future nested settings. |
| [`src/shared/InputPolicy.luau`](src/shared/InputPolicy.luau) | Input validation and drivetrain calculations. |
| [`src/shared/SteeringGeometry.luau`](src/shared/SteeringGeometry.luau) | Ground-speed projection, steering limits, and inner/outer wheel geometry. |
| [`tests/`](tests) | Structural checks and a two-player Studio test using the production client and server. |

## Apply it to a vehicle

Keep the source paths from [`default.project.json`](default.project.json) in your Rojo project. Author a vehicle model with this structure:

```text
VehicleModel [tag: ChassisVehicle]
├── DriveSeat                 VehicleSeat
├── Body                      Model containing the body parts
├── Wheels                    Model or Folder
│   ├── FL                    BasePart
│   ├── FR                    BasePart
│   ├── RL                    BasePart
│   └── RR                    BasePart
└── Misc                      Optional Model or Folder of body parts
```

Place the model in `Workspace`, position its parts, and apply the `ChassisVehicle` CollectionService tag. The server checks required classes, unique names, axle geometry, and tuning before changing the model. It assembles the running constraints, then unanchors the authored parts. If a required part is parented after tagging, the registry retries when that part appears. The [`vehicle contract`](docs/VEHICLE_CONTRACT.md) covers orientation, collision, authored constraints, and tuning.

The server creates `ReplicatedStorage.ChassisShared.Remotes.Input` once and validates an existing object at that path before using it. An unrelated top-level remote named `ChassisInput` has no effect on this package.

The driver uses the seat's normal throttle and steering controls. Left Shift, gamepad L1, or the contextual touch button applies the handbrake. The input script sends controls only while the local player occupies a tagged vehicle's `DriveSeat`.

## Build and check

Install [Rokit](https://github.com/rojo-rbx/rokit) and run the pinned tools from the repository root:

```sh
rokit install
rojo serve default.project.json
```

To build the Rojo place and run source checks:

```sh
rojo build default.project.json -o CarChassisSystem.rbxlx
stylua --check src tests
selene src tests
```

On Windows, run both Studio suites with an installed, signed-in Roblox Studio:

```powershell
./tests/RunStudioTests.ps1
# Run either suite separately:
./tests/RunStudioTests.ps1 -Suite Structural
./tests/RunStudioTests.ps1 -Suite Integration
```

The runner builds an isolated test place. Its fixture is test data and is excluded from the main project.

| Suite | Coverage |
| --- | --- |
| Structural | Missing and duplicate model parts, invalid tuning, constraint construction, all three drivetrains, handbraking, stale input, recursive tuning isolation, tire properties, Ackermann geometry, ground-speed steering, collision separation, model lifecycle, a 50-vehicle parked scheduling check, and teardown. |
| Integration | Two actual players run the production client. Checks authenticated driving, rejection of another player's controls, forward and reverse movement, right-turn direction, upright stability, vehicle handoff, driver-owned and server-owned physics, handbrake cleanup, and ownership restoration. Controlled-clock checks also verify 60 Hz vehicle acceptance and the separate flood gate with a real seated player. A 100-vehicle server-owned parked fixture records control-loop and heartbeat timings in the runtime JSON report. |

[Source checks](.github/workflows/ci.yml) run formatting, lint, all runtime source with Luau analysis, and both Rojo builds in GitHub Actions. The optional [Studio runtime workflow](.github/workflows/studio.yml) executes both suites on a dedicated Windows runner and uploads their results. It is disabled until that runner is configured and explicitly enabled. See [Studio CI setup and execution rules](docs/STUDIO_CI.md).

## Design boundaries

The server owns model assembly and accepts input only from the current seat occupant. `NetworkOwnership = "Driver"` gives the seated driver responsive local physics and returns ownership to automatic when they leave. `NetworkOwnership = "Server"` keeps the running vehicle on the server, including while parked. Both modes restore automatic ownership on detach. Choose server ownership when the vehicle's simulation must stay under server control; account for the additional server workload and input latency.

For driver-owned physics, games must validate movement-based rewards and competitive outcomes separately. The motor speed settings control normal driving and are not an anti-cheat boundary. See [Roblox's ownership guidance](https://create.roblox.com/docs/physics/network-ownership). This package contains no reward or persistence logic.

Suspension, torque, and steering values in `ChassisConfig` are starting values. `ConfigCopy.copy()` creates independent tuning, including both suspension tables. Pass it to `VehicleChassis.new(model, config)` for direct construction, or supply a per-model resolver to `ChassisRegistry.new()` for tagged vehicles. Each controller takes an immutable snapshot. See the [tuning example](docs/VEHICLE_CONTRACT.md#per-vehicle-configuration).

## Control-loop performance

The registry keeps attachment tracking separate from the vehicles scheduled for control updates. Accepted driver input wakes a vehicle. Input expiry or driver departure neutralizes it and removes it from the scheduled set. A structural test attaches 50 parked vehicles and verifies that the control loop processes none of them. Multiplayer checks verify wake-up and removal with an actual driver.

Active steering refreshes its speed-dependent angle each heartbeat, even between input packets. Constraint properties are written only when their values change. The `CarChassis.ControlStep` MicroProfiler marker isolates registry control work from Roblox physics.

The multiplayer suite also creates 100 server-owned parked vehicles, samples their server heartbeat and control-loop timing, and saves the measurements in its JSON report. These are measurements of the test fixture on the executing machine.

For a fleet capacity test, profile the target vehicle assets in Studio's server view with both parked and occupied vehicles. Compare control-loop time, physics time, network traffic, and frame time under the intended ownership mode. The 50-vehicle check proves scheduling behavior; actual capacity also depends on part count, constraint count, collision geometry, ownership, and hardware.

Drive and braking torque are capped by vehicle mass and wheel radius as well as the configured torque ceilings. Steering uses horizontal forward speed, so vertical falls and sideways slides do not reduce its angle. Ackermann geometry uses measured wheelbase and front track width while keeping both hinges within the configured limit. Tire friction, elasticity, and surface weighting are configurable, and springs have a finite force limit.

Tune these values against the vehicle's proportions, mass, wheel size, and intended handling. Undriven wheels receive no motor torque outside handbraking. The handbrake targets zero angular speed on all four wheels, including when throttle is held.

**PatchTheDev:** [Website and portfolio](https://www.patchthedev.com)
