# v0.4 driving update

Settings (gear icon next to the horn) provides saved traffic and performance
toggles. Traffic is off by default. On enables eight simple vehicles following
the connected left-side outer road loop, slowing for obstacles and the player.
Off hides vehicles, removes their collision layer and stops their physics work.
Traffic has no pathfinding, wheel solver, dynamic lights or individual audio.
This is basic loop traffic, not an intersection priority or city traffic simulator.

Performance mode keeps 30 FPS, disables MSAA and sun shadows, and reduces the
main camera far plane to 190 m. High quality restores 60 FPS, 2x MSAA, shadows
and 260 m. Engine harmonics use a precomputed wavetable. Existing spatial
batching is retained. Rear-camera rendering shares the world, runs at 320x180
and at most 15 FPS, and is disabled outside reverse. Device-specific frame
rates must be checked on physical Android hardware.

Gear speed limits are 40, 60, 80, 120 and 220 km/h. Fifth can drive beyond
200 km/h. Ratios match these speeds at approximately 6500 RPM; automatic
upshifts occur slightly below each limit and retain downshift hysteresis.
The limiter removes drive force rather than snapping velocity; gravity and
coasting may temporarily exceed the limit. Reverse is limited to 25 km/h.
The former 162 km/h global cutoff is removed. Added torque makes the taller
gears usable. The speed dial now reads to 240 km/h.

Steering has a faster neutral return and reduced steering angle at speed.
Lower centre of mass, increased wheel grip, reduced roll influence, grounded
lateral stabilization and bounded aerodynamic downforce improve stability.
Brakes are stronger. Clutch press is faster and release remains progressive.
Continuous collision detection reduces tunnelling at high speed. Settings
releases driving controls and holds the brake while open.

Reverse in either MT R or AT R shows a second display above the shifter,
with a rear-facing camera and distance guides. The main camera mode and HUD
remain unchanged. Guides are visual references, not distance sensors.

Regression checks cover gearing drive/cutoff, fifth above 200, existing native
multitouch/H-pattern behavior, road and obstacle collision, traffic motion and
disable, reverse display in both modes, and settings input gating. Screenshot
checks cover the reverse inset and settings layout.
