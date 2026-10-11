# AZ Car 3D — isolated Godot prototype

Independent Godot 4.3 Android game in `games/AZ-Car-3D`. Existing WebToApp builder files are untouched.

## Prototype scope
- Driveable low-poly starter sedan and procedural test city
- Manual 1–5, neutral, reverse, clutch-controlled selection; automatic P/R/N/D selection
- Touch buttons and desktop keyboard inputs
- Mission checkpoints, cash rewards, starter garage, car purchase, engine upgrade and local JSON save
- Separate Android debug APK workflow

## Important limitations
This is a **first playable vertical slice**, not a production-ready realistic simulator. Physics are simplified kinematic motion, not tire-force/suspension simulation. No actual clutch stalling, collisions, traffic AI, fuel, photorealistic assets, world streaming, or complete garage UI yet. The second car currently changes ownership/name, not the vehicle model. Android export requires Godot Android SDK configuration and should be verified by CI.

## Controls
Desktop: W throttle, S brake, A/D steer, hold C clutch, 1–5/R/N gears, M toggle transmission, G garage, B purchase sport coupe, U engine upgrade, F save.
Touch: LEFT/RIGHT, GAS/BRAKE, CLUTCH, GEAR +/- and garage/economy buttons.

## Next development milestones
1. Fix and verify Android CI build, then test touch input on device.
2. Replace kinematic movement with physically grounded vehicle chassis, wheels, clutch, torque curves, traction, brake bias and suspension.
3. Add roads and streamed map chunks, road collisions, traffic lights, traffic AI, and mission routing.
4. Create garage/shop and upgrade UI with persistence and 3D vehicle variants.
5. Optimize scene streaming, draw calls, memory and LOD for entry-level Android hardware.
