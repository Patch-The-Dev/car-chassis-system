# Car Chassis System

A reusable Roblox chassis for four-wheel vehicle models. The server assembles suspension, steering, and powered wheel constraints around an authored vehicle. A seated driver controls it through the normal `VehicleSeat` input. The source is organized for Rojo and Git, with no runtime packages.

## What it does

- Builds independent wheel carriers, spring suspension, front steering servos, and wheel motors from a vehicle model.
- Supports front, rear, or all-wheel drive, with an optional tuning table per controller.
- Accepts input only from the player occupying that vehicle's drive seat. The server bounds the values, limits request rate, and returns the motors to neutral when input stops.
- Assigns physics network ownership to the driver while seated and restores automatic ownership when the seat is vacated.
- Separates each wheel from collidable body parts while retaining collision with the world.
- Handles multiple tagged vehicles, including models moved into or out of `Workspace`, and removes generated parts, constraints, and connections on detach.

The chassis does not depend on a specific car mesh, dashboard, currency system, or game framework. Vehicle art and proportions are supplied by the game using it.

## Repository layout

| Path | Responsibility |
| --- | --- |
| [`src/server/VehicleChassis.luau`](src/server/VehicleChassis.luau) | Validates and assembles one vehicle; owns driver state and cleanup. |
| [`src/server/ChassisBootstrap.server.luau`](src/server/ChassisBootstrap.server.luau) | Watches tagged models, routes driver input, and updates active chassis. |
| [`src/server/ChassisRegistry.luau`](src/server/ChassisRegistry.luau) | Owns tagged model lifecycle and the namespaced input remote. |
| [`src/client/DriverInput.client.luau`](src/client/DriverInput.client.luau) | Relays the local `VehicleSeat` controls and handbrake input. |
| [`src/shared/ChassisConfig.luau`](src/shared/ChassisConfig.luau) | Active tuning values for drivetrain, steering, torque, and suspension. |
| [`src/shared/InputPolicy.luau`](src/shared/InputPolicy.luau) | Input validation and drivetrain calculations. |
| [`tests/`](tests) | An isolated Studio assembly and teardown check. |

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

Place the model in `Workspace`, position its parts, and apply the `ChassisVehicle` CollectionService tag. The server validates all four wheels before changing the model, assembles the running constraints, then unanchors the authored parts. The drive seat and four wheel names are required. The [`vehicle contract`](docs/VEHICLE_CONTRACT.md) covers orientation, collision, authored constraints, and tuning.

The server creates `ReplicatedStorage.ChassisShared.Remotes.Input` once and validates an existing object at that path before using it. An unrelated top-level remote named `ChassisInput` has no effect on this package.

The driver uses the seat's normal throttle and steering controls. Left Shift or gamepad L1 applies the handbrake. The input script sends controls only while the local player occupies a tagged vehicle's `DriveSeat`.

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

On Windows, `./tests/RunStudioTests.ps1` builds an isolated test place and runs the chassis checks in Roblox Studio. They cover model rejection, construction, three drivetrain modes, handbraking, stale input, wheel collision separation, tag and ancestry transitions, multiple vehicles, and teardown. [GitHub Actions](.github/workflows/ci.yml) checks formatting, lint, all runtime source with Luau analysis, and both Rojo builds. Studio runtime tests run locally; GitHub Actions does not execute them.

## Design boundaries

The server owns model assembly and accepts input only from the current seat occupant. A driver receives network ownership for responsive vehicle physics. Roblox clients with physics ownership can manipulate that simulation, so a game that awards money or competitive results from vehicle movement must validate those results separately on the server. This package intentionally contains no reward or persistence logic.

Suspension, torque, and steering values in `ChassisConfig` are starting values. `VehicleChassis.new(model, config)` also accepts a vehicle-specific tuning table when controllers are constructed directly. Tune those values against the mass, wheel size, and intended handling of each vehicle. Non-driven wheels receive no motor torque unless the handbrake is engaged. The handbrake targets zero angular speed on all four wheels, even when throttle is held. No transmission or cosmetic interface is required for the chassis to operate.

**PatchTheDev:** [Website and portfolio](https://www.patchthedev.com)
