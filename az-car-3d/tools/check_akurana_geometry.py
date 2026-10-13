"""Independent acceptance checks against attributed source and shipped triangles."""
import json
from pathlib import Path
import numpy as np
from shapely.geometry import LineString, Polygon, Point, box
from shapely.ops import unary_union
from shapely.strtree import STRtree

ROOT = Path(__file__).resolve().parents[1]


def check():
    data = json.loads((ROOT / "data/akurana/world.json").read_text())
    extent = box(-640,-640,640,640)
    roads = data["roads"]
    lines = [LineString(r["path"]) for r in roads]
    pavement = unary_union([line.buffer(r["width"]*.5, join_style="round")
                           for line,r in zip(lines,roads)]).intersection(extent)
    reserved = unary_union([line.buffer(r["width"]*.5+r["shoulder"]+r["setback"],join_style="round")
                            for line,r in zip(lines,roads)])
    assert pavement.is_valid, "Invalid junction union"
    building_polys = [Polygon(b["footprint"],b["holes"]) for b in data["buildings"]]
    assert all(p.is_valid and not p.intersects(reserved) for p in building_polys), "Building-road conflict"
    tree = STRtree(building_polys)
    for i, poly in enumerate(building_polys):
        assert all(j==i or poly.intersection(building_polys[j]).area<.001 for j in tree.query(poly)), "Building-building overlap"
    triangles = []
    for tile in data["tiles"]:
        coords = tile["road"]
        assert len(coords)%3==0
        for i in range(0,len(coords),3):
            triangle = Polygon([p[:2] for p in coords[i:i+3]])
            assert triangle.is_valid and triangle.area>1e-8
            triangles.append(triangle)
    mesh = unary_union(triangles)
    assert pavement.difference(mesh.buffer(.0002)).area<.1, "Road mesh has gaps"
    assert mesh.difference(pavement.buffer(.0002)).area<.1, "Road mesh outside its clearance reservation"
    assert abs(sum(p.area for p in triangles)-mesh.area)<1., "Overlapping road triangles"
    for line in lines:
        assert line.difference(mesh.buffer(.001)).length<.001, "Disconnected centerline coverage"
    # Disconnected mapped driveways are reported, never joined by invented roads.
    components = len(getattr(pavement,"geoms",[pavement]))
    for x,z,*_ in data["plants"]:
        assert not reserved.buffer(1.9).contains(Point(x,z)), "Vegetation in safety corridor"
    field = np.array(data["height_field"]).reshape(data["height_grid_size"],-1)
    assert np.isfinite(field).all(), "Invalid terrain values"
    report = {"footprints_checked":len(building_polys),"road_triangles_checked":len(triangles),
              "mapped_road_components":components,"clearance_conflicts":0,
              "mesh_gap_area_m2":pavement.difference(mesh.buffer(.0002)).area,
              "mesh_overlap_area_m2":sum(p.area for p in triangles)-mesh.area,
              "elevation_limit":"Fallback DSM and inferred grading; no surveyed elevation acceptance"}
    out = ROOT / "build"
    out.mkdir(exist_ok=True)
    (out / "geographic-validation.json").write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))


if __name__=="__main__": check()
