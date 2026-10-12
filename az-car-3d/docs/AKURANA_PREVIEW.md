# Akurana GIS driving prototype

This feature-branch preview uses the existing Godot 4.5.1 AZ Car 3D drivetrain, cockpit and controls. On `feature/az-car-3d-akurana-map`, `project.godot` opens `res://scenes/akurana.tscn`; the Colombo scene `res://scenes/main.tscn` remains unchanged.

## Geospatial data

- Roads and mapped building footprints: user-provided HOT Export Tool GeoJSON, sourced from OpenStreetMap contributors. © OpenStreetMap contributors, licensed ODbL 1.0. See https://www.openstreetmap.org/copyright
- Terrain: user-provided OpenTopography Copernicus GLO-30 DSM GeoTIFF. Source: Copernicus DEM (GLO-30), produced from Airbus WorldDEM data and distributed under the applicable Copernicus DEM licence. Acknowledge OpenTopography as distributor where required. Check source terms before redistribution.
- Raw uploads remain external to this repository; `data/akurana/preview.json` contains reduced sampled derived data for this prototype.

## Extraction and coordinate conventions

- Center approximately 80.6183 E, 7.3682 N.
- X positive east: (longitude - 80.6183) × 110300 metres.
- Z positive north: (latitude - 7.3682) × 110700 metres.
- Prototype ground extent: X,Z each -640 to +640 metres.
- Roads: 77 filtered OSM road segments; simplified and clipped; road widths are approximations and not surveyed values.
- Buildings: 110 selected near roads. Only centers and approximate rectangular footprints retained; heights, facade types and roof shapes are synthetic.
- Heights: 25 × 25 samples extracted from Copernicus GLO-30 DSM, encoded in metres above an elevation offset of 440 m with approximately 1 m quantization and bilinearly interpolated. Local Y coordinates are not absolute MSL elevations.
- Spawn: approximate A9/Matale Road centerline near X=-113, Z=25.
- This is a local geographic approximation rather than a navigation or civil engineering dataset; the elementary projection is not survey-accurate.

## Usage

Select `scenes/akurana.tscn` to play Akurana. `scenes/main.tscn` opens the former Colombo world. This feature branch's Android package is `com.azeem.azcar3d.akurana` so it does not overwrite the Colombo APK. Workflow `.github/workflows/az-car-3d-akurana.yml` builds a debug APK artifact without creating a GitHub Release.

## Known limitations

- 30 m DSM spacing cannot reproduce detailed curbs, drainage, bridges, road crown or accurate road-grade transitions.
- Buildings are approximated modular solids; some footprints or roads may overlap. No licensed landmark models, photogrammetry or interiors yet.
- Existing grid-based Colombo traffic AI is deliberately disabled because it does not navigate mapped Akurana streets.
- All generated meshes are currently loaded at once; chunk streaming, terrain tiles and LOD are future optimization work.
- Original vehicle mechanics and HUD are reused. Cockpit mirrors, controls and camera should be regression-tested on device.
- Visual and collision behavior must be tested in Godot and on Android; passing a CI export alone is not a real-device performance certification.
- This branch is deliberately isolated from `feature/az-car-3d` and `main`.

## Validation

Run `python3 tools/validate.py godot`, `godot --headless --path . --script res://tests/run.gd` and `godot --headless --path . --script res://tests/akurana_smoke.gd` inside the project directory. CI builds the Android debug APK and uploads the APK plus logs as artifacts. Do not merge or publish to Releases until visually and physically verified.
