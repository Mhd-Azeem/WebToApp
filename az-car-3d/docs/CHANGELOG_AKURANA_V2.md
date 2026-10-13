# AZ Car 3D — Akurana Realism Upgrade

Building rectangles and forced wide roads could overlap and block driving.
The rebuild recovers full OSM footprints and tagged road geometry, rejects
conflicts without relocating mapped buildings, and constructs a unioned road
surface with continuous intersection triangles and tapered shoulders.

Other changes:

- Correct east/up/south coordinate transformation for roads, terrain and
  structures; left-hand travel-lane spawn and right-hand driver position.
- Tiled terrain/roads/collision, building LOD batches, instanced vegetation,
  compressed mipmapped textures, true local culling origins and offline bake.
- Supported foundations, pitched/flat roof treatments, windows and frames,
  doors/shutters, inferred shop panels and lane-safe utility poles.
- Licensed PBR asphalt/ground maps and sparse CC0 periwinkle vegetation.
- Low/Medium/High/Ultra plus saved individual graphics budgets; guarded
  Forward+ effects and separate Android defaults. Staggered cockpit mirrors.
- Terrain-aware sustained-fall recovery, preserved off-road driving, cockpit,
  transmission, clutch, suspension, camera, audio and controls.
- Independent geometry acceptance, 872 collider probes, mapped narrow-street
  and hill driving, rendered instance checks and seven in-game captures.
- Independent APK signing and Windows EXE/PCK/archive/startup verification.

Known limitations: the inherited reduced DSM still has 53.33 m sample spacing
and one-metre quantization. Grading, untagged heights and scenery details are
inferred; the scene is not photogrammetry or survey-grade reconstruction.
Courtyards, grade-separated roads and extreme-slope sites are omitted.
Source road components are not joined with invented streets. Detailed drainage,
walls, guardrails, shelters, wiring and mapped traffic AI remain future work.

Observed local Compatibility performance on AMD Radeon(TM) Graphics was about
26 FPS at Low and 24 FPS at Medium in a short stationary cockpit test. This is
one machine and one scene, not a guaranteed frame rate. Android real-device
performance and the complete photorealistic brief are not certified. The APK
uses the existing persistent debug key, not Play Store production signing.
