# Akurana rebuild audit

Baseline: `1f48b3eeded46e0926a19b4883549a3c2fb6d152`, Godot 4.5.1.

## Diagnosis

- `akurana_world.gd` retains building centers and axis-aligned bounding rectangles only. It has no clearance rejection. Foundations expand those rectangles by 0.25 m, increasing conflict risk.
- Every road is widened to 6.8 m even when the reduced source says 4 m. Tags, OSM IDs, lanes, one-way flags, bridge/layer information and exact coordinates were discarded. Miter strips overlap at intersections, markings continue across junctions, and miter interpolation does not guarantee a valid polygon at sharp reversals.
- Terrain has 25 by 25 byte samples, 53.3 m apart with one-metre quantization. Subdivision improves tessellation but adds no elevation information. Copernicus DSM includes canopy/roof elevations and is not a road survey or bare-earth DTM.
- The single terrain mesh has 165,888 triangles and one large concave collider. Roads and shoulders likewise have world-sized render bounds. This inhibits useful frustum culling and causes startup allocation spikes.
- Road cross sections follow raw terrain height, including unrealistic lateral slope. Pavement sits 0.13 m above ground; shoulders are another overlapping collision sheet.
- `car.gd` resets below fixed Y=-5, independently of map-specific sustained recovery. `akurana_main.gd` otherwise allows off-road driving and aligns cockpit orientation to chassis slope. It raises the driver camera to ground+3.4 m, separating the virtual driver from the vehicle.
- The shared cockpit retains its lowered dashboard, steering animation, three mirrors, analog/digital cluster, four wiper modes, horn and lights. Drivetrain and engine audio are separate reusable modules and must remain unchanged.
- Settings expose two quality levels and limited scale/shadow controls. Renderer is Compatibility for both platforms. Three cockpit viewports plus reverse camera can multiply rendering cost.
- Existing Android and Windows CI passed at the baseline, including import, drivetrain, cockpit, spawn, ground physics, APK signing and exported EXE startup. Existing tests do not prove geographic clearance, valid road polygons, junction marking exclusion or visual quality.

## Milestones and acceptance

1. Recover attributed OSM geometry and tags; deterministic preprocessing; full-footprint road/shoulder/setback rejection; polygon union junctions; validate geometry independently.
2. Chunked indexed render meshes and collision; slope-aware ground; footprint buildings, inferred facade/roof details, batched vegetation and lane-safe roadside details. Preserve original Colombo scene and drivetrain.
3. Persistent graphics presets and individual budgets with renderer capability guards. Renderer changes require restart; effects and budgets can change live.
4. Godot import and existing regression suite, new geographic/physics checks, rendered in-game captures and visual inspection; separate Android/Windows builds from the same revision.
5. Publish a new versioned release only after both builds and functional/visual acceptance pass. Do not overwrite historical releases.

## Source and acceptance limitations

Original HOT GeoJSON, Copernicus GeoTIFF and referenced recordings are absent from the checkout. Fresh OSM can recover footprints and tags but cannot supply surveyed elevations. Any grade reconciliation, unspecified widths/heights, vegetation or facade treatments must be labeled inferred. Higher-resolution terrain must be accepted from a licensed source rather than invented from interpolation. No real-device performance claim can be made without testing that device.
