# AZ Car 3D — Colombo driving district

Standalone **Godot 4.5.1** project. Open this folder's `project.godot`, then run.
All original WebToApp code, APK workflows and the earlier `games/AZ-Car-3D`
prototype are preserved. Develop only on `feature/az-car-3d`.

## Play

Landscape controls use original vector symbols. The clutch pedal is above the
left/right steering arrows; brake and throttle pedals are on the right. The fixed
round H gate is above the brake. Hold the clutch until the HUD shows at least 85%,
then drag its small knob: top row **1 / 3 / 5**, bottom row **2 / 4 / R**.
The middle horizontal channel is neutral. Pull the knob through neutral before
changing columns. Release it to snap into the actual selected gear. Rejected
shifts flash red and keep the knob synchronized with the gearbox.

Gas, brake, steering, clutch and the gear lever track independent touch fingers.
Releasing clutch mid-drag cancels further lever movement. Pedals support analog pressure: hold and slide down to reduce input. Apply gas while gently releasing clutch; release at idle in
gear can stall. Hold clutch and tap the power symbol to restart. Reverse is blocked
while moving. The H-with-circular-arrow symbol toggles MT/AT while stopped.
Automatic mode replaces the H gate with P/R/N/D selectors; hold brake while stopped
to select P/R/D. N disconnects drive and P applies wheel brakes. Camera symbol
switches cockpit/chase, circular arrow resets the car, sliders toggle quality,
and folded-map symbol displays region information. The upper HUD is now 14px.

Vehicle art is an original unbranded performance coupe with a lower roof, sloped
glass, split grille, alloy spokes, rear diffuser, spoiler and exhaust tips. It is
inspired by sport-coupe proportions, not an official BMW/Lamborghini model or a
photoreal licensed replica. The reference gear illustration is not redistributed;
only the standard gear arrangement is reproduced with original vector drawing.

Keyboard: W gas, S brake, A/D steer, C clutch, 1–5 gears, R reverse, N neutral,
M transmission, E engine start/stop, Space handbrake, V chase/cockpit/hood. In automatic mode,
hold S and use P/R/F for P/R/D. RESET recovers an overturned/stuck vehicle.

The connected district includes intersections, crossings and buildings with
physical collision. Keep left and yield at junctions. Optional colored AI traffic is available in Settings.
The folded-map control displays implemented and planned areas. See `docs/MAP.md`.

## Android build

Workflow: `.github/workflows/az-car-3d-colombo.yml`. Push game changes to the game
branch or manually run that workflow **on feature/az-car-3d**. Download the
`AZ-Car-3D-Colombo-debug` Actions artifact. It contains the debug APK and logs.
Package: `com.azeem.azcar3d.colombo`, arm64, min SDK 24, target SDK 35 (Android 15).
Separate ID prevents overwriting the earlier prototype or WebToApp application.
No network permission, accounts or backend. This is a debug APK, not a signed
production release. CI retains a cached preview signing key for updates. A production distribution
still needs a dedicated release signing key.

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

v0.6 adds a shared physical engine/clutch/gearbox model, torque converter and
kickdown, analog pedals, handbrake, RPM-synchronized layered audio and analog
instruments in both hood and cockpit. See [drivetrain documentation](docs/DRIVETRAIN_SIMULATION.md)
for controls, configuration, measured validation and simulation limits.

Driving update: open the gear icon for saved traffic and performance settings. Traffic is off by default. Reverse shows a rear-camera inset. Gear limits are 40 / 60 / 80 / 120 / 220 km/h. See docs/DRIVING_UPDATE.md. Every successful branch build refreshes the az-car-3d-latest GitHub release APK.

v0.5 adds more sensitive steering, the player coupe in eight traffic colors,
rolling terrain, hills, trees, shrubs, rocks, city parks, beach and sea. See
docs/LANDSCAPE_UPDATE.md for the generated scenery and mobile rendering limits.

