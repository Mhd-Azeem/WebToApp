# AZ Car 3D — Akurana environment rebuild

This upgrades the existing playable Akurana scene. Colombo, the shared car,
drivetrain, controls, audio and cockpit remain available.

## Geometry and source data

- Fresh OpenStreetMap snapshot, downloaded 2026-10-13 using bbox
  `80.6124,7.3624,80.6242,7.3740`. Snapshot SHA-256:
  `f6cd0a58c5a91bd2325be6fd520778574856446756adacc67bfc30eb360c7283`.
- One consistent projection: X east, Z south (north is -Z), center 80.6183 E / 7.3682 N;
  historical preview scales 110300 / 110700 m per degree. This preserves
  metric scale, corrects the preview's reflected north axis, and is explicitly
  not a survey coordinate system. The inherited DEM grid is reflected through
  the same transform, so roads, buildings and elevation remain aligned.
- 107 clipped road features with OSM IDs, tags, original widths where tagged,
  inferred category/lanes-based widths otherwise, and one-way conventions.
  Left-hand lane spawning. Narrow local roads are not widened to highways.
- 1,594 retained full building outlines. Full road/shoulder/category-setback
  masks reject conflicts in place. No mapped building is randomly moved.
  Separate records explain omissions. Invalid outlines, grade-separated roads,
  courtyard extrusion and excessively steep building sites are omitted.
- Road polygon union supplies irregular junctions with no stacked asphalt.
  Triangles are split on the same cell diagonal as the terrain collision.
  Painted lines avoid junctions and narrow/one-way centerline misuse.
- 64 m terrain/road tiles and collision tiles; 128 m building batches and
  vegetation MultiMeshes. Decorative building LODs; fixed terrain boundary
  topology avoids cracks. Physics remains independent of visual culling.
- Foundations check outline samples and interior grid points. Roofs, framed
  windows, doors/shutters, inferred shop panels and utility poles add detail.

## Elevation and art limitations

The original GeoTIFF is unavailable. Terrain retains the existing reduced
Copernicus GLO-30 **DSM**: 25 × 25 values spaced 53.33 m, quantized to one metre,
with a 440 m offset. A 4 m derived mesh adds geometric continuity, not real
elevation detail. Crossfall/crown and the 12 m earthwork blend are **inferred**.
Longitudinal grades are still approximate DSM grades. Bridges/tunnels need
separate verified decks and are not silently flattened into ground roads.

Mapped footprints determine placement; untagged heights, roof forms, facades,
vegetation and utility poles are inferred. These are not replicas of named
real buildings or a mapped inventory of vegetation. Land-cover blending is
slope/material based, not a surveyed land-cover classification.

The environment is a procedural reconstruction with PBR surface assets, not
photogrammetry or a guarantee of photorealism. No GTA-level claim is made.
Detailed guardrails, drainage, boundary walls, bus shelters, traffic AI and
accurate utility wiring remain limitations. Fifteen disconnected source road
components are reported rather than joined with invented streets.

## Graphics and controls

Settings save Low/Medium/High/Ultra presets and individual resolution, texture,
vegetation, draw-distance, AA, shadows, mirror, effect and frame-limit choices.
Default: Low on Android; Medium on desktop. Unsupported screen-space and
volumetric effects are disabled by renderer capability. Low uses 256 px ground
and asphalt textures, reduced vegetation and mirrors, and no sun shadows.

Windows starts in Compatibility for broad hardware support. Use the included
`Launch-Forward-Plus.cmd` for Forward+ on a capable Vulkan GPU, or
`Launch-Compatibility.cmd` to recover to Compatibility. Renderer changes need
a new process. Graphics budgets and supported effects change live.

Android uses Compatibility. It does not inherit desktop screen-space effects.
The APK remains debug signed with the existing persistent preview key; it is
not a Play Store production-signing release. No physical Android phone was
available for performance testing. FPS limits are ceilings, not guarantees.

Existing manual/automatic transmission, clutch, braking, handbrake, engine,
horn, steering animation, wipers, headlights, mirrors and cameras are retained.
The lowered dashboard remains. Driver/hood orientation follows chassis pitch
and roll; recovery requires a sustained fall below local terrain or manual
reset, rather than leaving a road. All original Colombo scenarios must pass.

## Rebuilding and inspecting

1. Install Python with numpy/shapely >=2.1, plus Godot 4.5.1 and matching templates.
2. Decompress `tools/source/akurana-osm.xml.gz` to an intermediate folder.
3. Run `python tools/preprocess_akurana.py --osm path/to/snapshot.xml`.
4. Import with `godot --headless --editor --import --quit`.
5. Bake with an active renderer:
   `godot --rendering-method gl_compatibility --script res://tools/bake_akurana.gd -- --bake-world`.
   On Linux CI use `xvfb-run -a`. The dummy headless renderer cannot serialize
   MultiMesh buffers correctly; the bake deliberately refuses that mode.
6. Run `tools/check_akurana_geometry.py`, existing game tests and new
   `akurana_geometry.gd`, `akurana_hill_driving.gd`, and active-renderer
   `akurana_instances.gd`. Render `akurana_render.gd` and inspect seven images.

In-game inspection covers cockpit road visibility, roofs/foundations on
slopes, winding roads, intersections, shoulders, near-road buildings, mirrors,
and settings. PNG sanity checks catch missing/identical captures but do not
prove visual quality. Device testing and higher-quality geographic elevation
remain necessary before calling the full photorealistic brief satisfied.

Heavy GIS and mesh/LOD preparation happens offline. Runtime loads the compact
map attributes and baked scene, rather than repeating polygon processing.
