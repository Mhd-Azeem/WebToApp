"""Image sanity gate complements actual human/agent inspection, never replaces it."""
from pathlib import Path
import hashlib
import json
import struct
root = Path(__file__).resolve().parents[1] / "build/visual"
names = ["camera-0.png","camera-1.png","camera-2.png","settings.png",
         "neighborhood-0.png","neighborhood-1.png","neighborhood-2.png"]
report = {}
for name in names:
    image = (root / name).read_bytes()
    assert image[:8] == b'\x89PNG\r\n\x1a\n' and len(image)>20000, f"Missing/empty screenshot {name}"
    width,height=struct.unpack(">II",image[16:24])
    assert width>=640 and height>=360, f"Invalid viewport for {name}"
    report[name]={"dimensions":[width,height],"bytes":len(image),"sha256":hashlib.sha256(image).hexdigest()}
assert len({r["sha256"] for r in report.values()}) == len(names), "All screenshots identical"
(root / "screenshots.json").write_text(json.dumps(report,indent=2))
print("VISUAL CAPTURE PASS: seven distinct in-game inspection images; appearance still requires inspection")
