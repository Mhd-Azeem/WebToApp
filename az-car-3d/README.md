# AZ Car 3D — Colombo driving district

Standalone **Godot 4.5.1** project. Open this folder's `project.godot`, then run.
All original WebToApp code, APK workflows and the earlier `games/AZ-Car-3D`
prototype are preserved. Develop only on `feature/az-car-3d`.

## Play

Landscape Android controls support concurrent steering, gas, brake and clutch
with native multi-touch buttons. Manual: hold clutch, select 1–5 / N / R, apply gas
and release clutch. Pedal engagement ramps over ~0.33 seconds. A clutch released
at idle in gear can stall: hold clutch and press START. Stop before selecting
reverse or changing MT/AT. Automatic: hold brake while stopped to select P/R/D;
N disconnects drive; P applies wheel brakes. Five internal automatic ratios use
speed thresholds with hysteresis. MT/AT button changes transmission at rest.

Keyboard: W gas, S brake, A/D steer, C clutch, 1–5 gears, R reverse, N neutral,
M transmission, E restart, V chase/right-hand-drive cockpit. In automatic mode,
hold S and use P/R/F for P/R/D. RESET recovers an overturned/stuck vehicle.

The connected district includes intersections, crossings and buildings with
physical collision. Keep left and yield at junctions. No AI traffic yet.
REGIONS displays the implemented and planned areas. See `docs/MAP.md`.

## Android build

Workflow: `.github/workflows/az-car-3d-colombo.yml`. Push game changes to the game
branch or manually run that workflow **on feature/az-car-3d**. Download the
`AZ-Car-3D-Colombo-debug` Actions artifact. It contains the debug APK and logs.
Package: `com.azeem.azcar3d.colombo`, arm64, min SDK 24, target SDK 35 (Android 15).
Separate ID prevents overwriting the earlier prototype or WebToApp application.
No network permission, accounts or backend. This is a debug APK, not a signed
production release. CI debug signing may change across runs, requiring uninstall
before updating; install a persistent release signing key before distribution.

Local export requires Java 17, Android SDK tools, build-tools 35.0.1, platform 35,
Godot Android templates matching 4.5.1, and a debug keystore. Configure SDK/JDK
paths in Godot editor settings. Then:

```sh
python3 tools/validate.py godot
godot --headless --path . --script res://tests/run.gd
mkdir -p build
godot --headless --path . --export-debug Android build/AZ-Car-3D-Colombo-debug.apk
```

## Performance and limits

Default LOW: compatibility renderer, 30 FPS cap, shadows disabled, 512px road and
facade textures, mipmaps, shared materials, MultiMesh static batches, 260m camera
range, 60Hz physics. HIGH enables a sun shadow and a 60 FPS cap. Focus loss releases
pedals and pauses simulation. Geometry has simple collisions and no dynamic lights.

Nubia V70 Max / Android 15 are **targets**, not performance certifications. Test
multi-touch, aspect ratio/safe areas, thermal throttling, driver stability, memory,
collision and sustained frame times on that phone. Touch controls use a 1280×720
stretched canvas; extra-wide screens and cutouts require device validation.

Godot VehicleBody3D is a simplified raycast vehicle model. Gearing, clutch,
engine stall, RPM and selector guards are implemented, but this is not a validated
real-car simulation: no differential, tire temperature, gearbox damage, adaptive
shifts or torque converter simulation. Handling needs device/user tuning.
No claim of GTA V fidelity. Current scenery is a textured modular vertical slice;
see `docs/VALIDATION.md` for actual checks and outstanding work.
