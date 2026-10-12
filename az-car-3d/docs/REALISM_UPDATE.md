# AZ Car 3D v0.7 cockpit preview

Baseline: 47b568126ed0e6afa1cedd2b19a34ce87ebc4327, feature/az-car-3d.
Only az-car-3d and its two platform workflows are changed.

## Implemented
- Original tapered dashboard mesh, 370 mm three-spoke steering assembly, column, stalks, vents, screen, trim, doors, pillars and pedals.
- Left-hand driver: vehicle forward is +Z, driver at local +X. Camera coordinates face -Z.
- Steering mounting tilt is independent from assembly rotation. Horn target follows its actual projected 3D hub.
- Mouse/touch ownership for horn and light/wiper stalks. Tap wipers cycles OFF/intermittent/LOW/HIGH; drag vertically selects speed. Completed sweeps park when switched off.
- Light stalk toggles actual spotlights. Drag sideways for indicators; drag upward over 75 logical pixels for high beams. Physical red console button toggles hazards. Q/Z select signals, X hazards, B high beams on Windows.
- Dashboard SubViewport displays smooth analog 0–240 km/h and 0–8000 RPM needles, digital speed/gear, transmission mode, fuel, engine/parking/headlight/beam/indicator states.
- Fuel is a simple consumption estimate, not a calibrated fuel economy simulation.
- Both side mirrors have horizontally flipped rearward cameras; layers exclude all cockpit surfaces and include the player's exterior. 192x112 at 10 Hz performance mode; 384x224 at 30 Hz high quality. Hidden cockpit stops mirror rendering.
- Gas begins at 25%, upward drag reaches 100% over 96 logical pixels, downward drag clamps to 25%, release/cancellation is immediate zero. Brake/clutch retain analog pressure and independent ownership.
- Native desktop controls and always-accessible transmission/settings buttons; existing drivetrain retained.
- Original sedan/hatchback/SUV/van/bus body profiles, shared merged material surfaces, following distance and slowing/traffic-phase decisions at route corners.
- Urban lane divisions, bus shelters, parking lines and traffic signal artwork supplement the existing Colombo network.
- Dedicated filtered/compressed vehicle audio bus preserves RPM/load layering and lifecycle sounds.
- Desktop high quality defaults to shadows off; shadows are optional due to their large cost in this existing map.
- Independent Godot 4.5.1 Android and Windows CI validation/builds, exact filenames, signature/archive checks and source-linked separate versioned prereleases. Existing Android debug signing cache is retained.

## Verification
Local Godot 4.5.1 import passed. Full legacy drivetrain/vehicle suite passed before the final traffic/audio additions; re-run required after changes.
Dedicated cockpit tests passed, including projected horn ownership, lights, four wiper modes/parking, mirror budgets/culling and throttle range/release.
Actual Radeon/OpenGL cockpit screenshots were inspected and wheel, gauge and mirror proportions corrected iteratively. Reference inspired the layout; it is not an exact visual match.
All graphics remain stylized original geometry. No external car models or recordings were redistributed.

## Limits
No physical Android test device. Phone frame rate, touch ergonomics and audio listening quality remain unverified.
Traffic follows the existing outer road loop; full junction routing and pedestrian AI are unfinished. City signal artwork currently represents north/south phases.
Climate and infotainment are visual trim, not simulated systems. Interior mirror is currently a housing. Wipers have no rain or windshield water shader.
Cockpit remains procedurally modeled and does not yet meet commercial detailed-asset quality. No claim of photorealism.
The existing tests report an ObjectDB cleanup warning; gameplay assertions pass. CI and release verification must be recorded independently.
