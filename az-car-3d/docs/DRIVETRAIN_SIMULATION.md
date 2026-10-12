# v0.6 integrated drivetrain

The existing game now shares a configurable engine, clutch, gearbox, wheel adapter
and audio system. The map, traffic setting, camera cycle, reverse inset and native
H-pattern controls remain integrated. No unrelated WebToApp files are changed.

## Driving

Tap a pedal for full input. While holding it, slide down up to 96 logical pixels
to reduce pressure continuously; slide up to increase it. Release for zero.
Gas, brake, clutch, steering and shifter own independent fingers. In manual mode,
hold clutch above 85% to change gears, then release gradually with throttle.
The P-in-circle button toggles the handbrake; Space does the same on keyboard.
The power button / E starts or stops the engine. Restart in neutral or with clutch
pressed; automatic restart requires P/N. Settings includes Manual / Automatic.
Change mode while stopped. Select automatic P/R/D while stopped with brake held.
Focus loss and Settings release held pedals. Analog dials appear in hood and cockpit.

## Mechanical model

`scripts/drivetrain/vehicle_configuration.gd` exports SI parameters. Defaults:
1250 kg, 0.34 m wheel radius, 800 idle / 6000 redline / 6500 maximum RPM, engine
inertia 0.22 kg*m^2, 180 Nm peak net torque and 108.86 HP peak calculated power.
The torque curve, friction, suspension, brakes, grip, ratios and audio reference
RPMs are configurable. Assign a configuration Resource to the player's car.

The default resource preserves the previously requested approximate redline
speeds 40/60/80/120/220 km/h. These are gearing outcomes, not velocity setters.
`standard_vehicle_configuration.tres` provides the requested alternative ratios
3.50/2.10/1.40/1.00/0.80, reverse -3.40 and final drive 3.90.

Engine angular speed integrates combustion, idle governor, friction, starter
torque and clutch/converter reaction with substeps of at most 1/240 second.
Throttle has response lag. Startup cranks before ignition; overload can stall it.
The limiter intermittently cuts ignition. Unsafe manual downshifts are rejected;
wheel-driven over-rev is detected separately from the combustion limiter.

Manual clutch pressure and bite point determine torque capacity. An implicit
slip solver transfers equal reaction torque between engine and input shaft.
Shifts temporarily disconnect torque; selecting a gear never assigns RPM.
Automatic mode schedules five gears using RPM, load, throttle and speed, with
kickdown, shift delay, idle creep, a power-bounded fluid converter and lockup.
P applies wheel brakes and N disconnects the engine.

The wheel adapter reads Godot wheel rotation and contact, distributes axle force
between rear wheels, estimates longitudinal load transfer and limits traction.
It models a simple open differential when a rear wheel loses contact. Brakes and
handbrake use wheel impulses, not velocity resets. Aerodynamic drag and rolling
resistance are explicit; hidden linear damping is disabled. Gravity and raycast
suspension provide road-slope response.

Godot 4.5.1's solver applies `engine_force` to each driven wheel and uses
`wheel.brake` as a contact impulse, ignoring it while drive force is nonzero.
The adapter therefore divides axle force, converts brake torque to impulse with
the physics timestep and removes wheel drive during braking. See the pinned
[Godot solver source](https://github.com/godotengine/godot/blob/4.5.1-stable/scene/3d/physics/vehicle_body_3d.cpp).

## Audio and mobile cost

Four original PCM engine layers are baked once and cached, then played by native
AudioStreamWAV players. Actual engine RPM controls smooth pitch and crossfades;
load and throttle control intensity. Starter, ignition, limiter, shift, grinding,
stall and shutdown follow simulation events. Wind, rolling, brake, skid and horn
follow their respective controls and physical telemetry. Inaudible loops stop.
No audio samples are synthesized per frame. Headroom is reserved for mixing.

## Validation

Godot 4.5.1 import and the complete `tests/run.gd` suite pass locally. CI repeats
both before Android export, signature verification and release publication.

| Check | Observed result |
|---|---|
| 60 km/h, default 2nd vs 5th, coupled | 6493.7 vs 1773.0 RPM |
| Corresponding four-cylinder audio firing reference | 216.46 vs 59.10 Hz |
| Torque/power consistency | 180 Nm / 108.86 HP peak |
| Powered physical road test | 200.01 km/h in fifth |
| Coast vs service brake from 60 km/h over 3 seconds | 16.28 vs approximately 0 m/s |
| Uphill vs flat at equal throttle, actual physical road | Higher engine load and lower speed uphill |
| Neutral/free rev, partial clutch, abrupt stall, crank restart | Pass |
| Engine braking, slopes, handbrake hill start and Park hold | Pass |
| Shift delay, safe reverse, unsafe downshift, AT kickdown/converter | Pass |
| 30/60/120 Hz engine integration and limiter | Pass |
| Independent fingers, analog pedal drag, existing H gate | Pass |
| Roads, collision, traffic, landscape, reverse inset | Pass |

Physical tests create temporary slope fixtures outside the playable district;
the playable game remains the original scene. Rendering checks cover cockpit,
hood, Settings and reverse cameras.

## Limits

This is a coherent gameplay drivetrain, not a validated engineering simulator.
Godot VehicleBody3D remains a raycast vehicle with simplified tires and wheel
rotation feedback; the adapter does not implement a full independent tire angular
momentum/Pacejka model. Open-differential and load-transfer behavior are approximations.
Generated engine audio is stylized rather than a recording of a particular car.
Optional gearbox damage and engine temperature are not implemented. Nubia V70 Max
audio quality, frame times, thermal behavior and touch ergonomics require physical
phone testing; local and CI tests do not certify them.
