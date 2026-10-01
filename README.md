# Car Chassis System

A reusable Roblox chassis for four-wheel vehicle models. The server assembles suspension, steering, and powered wheel constraints around an authored vehicle. A seated driver controls it through the normal `VehicleSeat` input. The source is organized for Rojo and Git, with no runtime packages.

## What it does

- Builds independent wheel carriers, spring suspension, front steering servos, and wheel motors from a vehicle model.
- Supports front, rear, or all-wheel drive, with an optional tuning table per controller.
- Limits drive and braking torque using assembled vehicle mass and wheel radius, caps suspension force, and reduces steering angle at speed.
- Accepts input only from the player occupying that vehicle's drive seat. The server bounds the values, limits request rate, and returns the motors to neutral when input stops.
- Assigns physics network ownership to the driver while seated and restores automatic ownership when the seat is vacated.
- Separates wheels from nearby body parts while retaining collision with the world; distant decorative parts add no wheel collision constraints.
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
| [`src/shared/ConfigCopy.luau`](src/shared/ConfigCopy.luau) | Copies per-vehicle tuning, including independent front and rear suspension tables. |
| [`src/shared/InputPolicy.luau`](src/shared/InputPolicy.luau) | Input validation and drivetrain calculations. |
| [`tests/`](tests) | Structural checks and a Studio play test using the production client and server. |

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

Place the model in `Workspace`, position its parts, and apply the `ChassisVehicle` CollectionService tag. The server validates all four wheels before changing the model, assembles the running constraints, then unanchors the authored parts. If a required part is parented after tagging, the registry retries when that part appears. The drive seat and four wheel names are required. The [`vehicle contract`](docs/VEHICLE_CONTRACT.md) covers orientation, collision, authored constraints, and tuning.

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
| Structural | Invalid models and tuning, constraint construction, all three drivetrains, handbraking, stale input, independent tuning, collision separation, missing parts, model lifecycle, multiple vehicles, and teardown. |
| Integration | An actual player sits; the production client sends seat controls; the server authenticates the occupant and assigns ownership. Checks forward movement, turning, reverse movement, upright stability, rejected input while unseated, handbrake binding cleanup, and ownership restoration on detach. |

[GitHub Actions](.github/workflows/ci.yml) checks formatting, lint, all runtime source with Luau analysis, and both Rojo builds. The Studio suites run locally; the Actions status reports source checks and builds.

## Design boundaries

The server owns model assembly and accepts input only from the current seat occupant. A driver receives network ownership for responsive vehicle physics. Roblox clients with physics ownership can manipulate that simulation, so a game that awards money or competitive results from vehicle movement must validate those results separately on the server. This package intentionally contains no reward or persistence logic.

Suspension, torque, and steering values in `ChassisConfig` are starting values. `ConfigCopy.copy()` creates independent tuning, including both suspension tables. Pass it to `VehicleChassis.new(model, config)` for direct construction, or supply a per-model resolver to `ChassisRegistry.new()` for tagged vehicles. Each controller takes an immutable snapshot. See the [tuning example](docs/VEHICLE_CONTRACT.md#per-vehicle-configuration).

Drive and braking torque are capped by vehicle mass and wheel radius as well as the configured torque ceilings. Steering angle decreases with speed to limit the requested lateral acceleration. Springs have a finite force limit. Tune these values against the vehicle's proportions, mass, wheel size, and intended handling. Undriven wheels receive no motor torque outside handbraking. The handbrake targets zero angular speed on all four wheels, including when throttle is held.

**PatchTheDev:** [Website and portfolio](https://www.patchthedev.com)
