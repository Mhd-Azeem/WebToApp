# v0.5 landscape and steering

Steering engagement rises from 1.8 to 3.4 radians/second and the low-speed
maximum angle from 0.50 to 0.62 radians. Centering is faster too. The quadratic
speed damping remains, with a slightly reduced coefficient for a more responsive
feel at road speeds. Keyboard and touch use the same steering path.

Player and traffic now share coupe_visual.gd, including the sculpted body,
glass, grille, LED lights, spoiler, exhausts and alloy wheels. Eight traffic
cars use eight different paint colors. Their static visual meshes are merged
by material to bound draw calls. Traffic retains lightweight collision-aware
movement rather than running eight extra vehicle suspension solvers. Player
wheels retain the existing VehicleWheel3D physics and wheel artwork.
The merged traffic geometry is built once and cached as a packed template;
other colors reuse that geometry and override only the body paint.

The landscape covers the long-road district with seeded rolling grass terrain,
eastern hills, a sandy coastal strip and sea. Terrain tiles have mesh collision;
road and building reservations remain level. Trees appear on city sidewalks,
in small parks with paths and benches, and beside country roads. Trunks have
collision. Three overlapping crown lobes vary the silhouettes. Rural shrubs
and small decorative rocks add ground cover. Vegetation is grouped into spatial
MultiMeshes with shared low-detail geometry and distance culling. Depth haze
softens the far clipping edge. Everything added is original procedural art.

The visual style remains a procedural stylized game world, with no downloaded
real-world city map or photorealism claim. Physical Android frame-rate and
touch sensitivity testing remain device checks.

Checks retain native multitouch, shifter, transmission, road and barrier
collision, traffic toggle and reverse camera coverage. New checks verify
traffic uses the shared coupe with eight paint colors and merged geometry,
terrain collision and scene coverage, and a steering response within 100 ms
with prompt centering. The powered fifth-gear check still requires over
200 km/h. Screenshot checks cover urban trees, colored coupes and countryside.
