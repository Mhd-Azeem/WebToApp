# Validation — Colombo vertical slice

Engine: Godot 4.5.1 stable official f62fdbde1, Linux x86_64.

- Full editor/import: PASS; no script parse errors or missing resources.
- Transmission checks: PASS. Clutch-required shifts, all five gears, reverse,
  invalid gears, moving-direction guards, neutral, P/R/N/D brake interlocks,
  force signs, clutch disconnection, stall and clutch-assisted restart.
- Scene/physics checks: PASS. Four raycast wheels; initial driver-left lane;
  approximately 40.18m powered travel over 240 physics ticks; road support;
  solid obstacle prevents drive-through.
- Native touch injection: PASS. Gas + clutch + steer held concurrently;
  releasing steer leaves gas pressed. Headless tests inject viewport-local
  coordinates because the headless window is 64×64; phone touch remains untested.
- Render: chase and cockpit captures inspected at 1280×720 through Xvfb and
  Mesa llvmpipe software OpenGL. No rendering/script errors with Dummy audio.
  VSync unavailable warning is expected for this software-rendered environment.
  This does not certify phone GPU performance (software capture around 13–17 FPS).
- Workflow YAML parse: PASS. CI runs on the game branch only, imports, runs
  gameplay tests, exports APK, verifies signing and uploads logs/artifact.
- Local Android debug export: PASS. arm64 only; package com.azeem.azcar3d.colombo;
  version 0.2.0-colombo; min SDK 24, target/compile SDK 35 (Android 15).
  Matching 4.5.1 Android template, Java 17, Android build-tools 35.0.1.
  APK v2 and v3 signatures verify with one debug signer.
- Preservation: original tracked WebToApp files, prototype and three existing
  workflow files compared against e40c749cff2615f0d267520c7df660a099fd4774:
  unchanged. Added only az-car-3d/** and the new workflow.

Resolved export issues: prebuilt template SDK overrides must be blank; template
itself supplies min 24 / target 35. Enable ETC2/ASTC imports for Android.
The exporter emits an adb-daemon connection warning in this container; export
and independent APK signature checks succeed. No Android device is attached.

## Outstanding validation / limitations

No Android installation, Nubia V70 Max frame-time/thermal/memory profiling,
physical multi-touch, safe-area/cutout check or GPU-driver stability test yet.
No production release signing, Play release, engine sound, AI traffic,
complete intercity roads, missions or vehicle economy in this new vertical slice.
The previous prototype remains available with its prior systems.

Art remains modest: original modular textured buildings, tapered low-detail
sedan, simple palms and hills. No GTA V-equivalent visual or physics claim.
Kandy/Galle are inspirations/backdrop/expansion routes, not full city recreations.
