# Continuous roads, procedural sound and hood instruments

The original Fort/Pettah grid now opens onto four north/south routes out to
z = -960 and +960 metres, with cross streets at 320, 640 and 960 metres in
both directions. The three main boulevards span 1.92 km; the eastern paddy
lane rejoins the grid and outer loops. City boundary walls have openings,
sidewalks stop before intersections, and decorative hills sit off the routes.
All roads retain box collision. Extended surfaces use chunks of at most 120 m
and spatially grouped MultiMeshes, retaining collision bodies and distance
culling. Low quality remains the default with a 30 FPS cap and no sun shadows.

Camera button / V cycles chase → cockpit → hood → chase. Hood has smoothed
analog speed (km/h) and RPM needles, redline markings and a central gear
readout including N, R and automatic selector states. Existing HUD and touch
controls remain. Speaker symbol / H holds the horn.

Audio is original procedural synthesis in engine_audio.gd: ignition/cranking
envelope on scene entry and accepted START, idle combustion harmonics,
RPM-following acceleration, sustained loaded throttle and redline modulation,
throttle release/rev drop, shift dip/click, dual-tone horn, braking noise and
tire-slip squeal based on grounded wheel skid information. Keyboard and touch
use the same effective pedal inputs. A 16 kHz mono generator fills every
available frame into a 120 ms buffer, with gain/RPM smoothing and bounded
output. No downloaded audio or third-party recording licenses are required.
The sound is a stylized synthesized engine, not a recording of a branded car.

Validation uses the workflow's pinned Godot 4.5.1. Existing transmission,
multitouch, H-pattern, powered movement and barrier tests remain. Added
raycast checks verify road support at city exits and outer loops and clear
passage through former boundary walls. Camera-cycle and touch-horn checks
cover the new controls. The existing Colombo Android workflow automatically
runs validation, these tests, export and APK signature verification on push.
Physical Android performance, audio quality and interruption/resume testing
still require a device; desktop results do not establish mobile frame rates.

Only az-car-3d is changed. WebToApp, games/AZ-Car-3D, previous releases and
existing build workflows are preserved.
