"""Deterministic OSM -> clipped, attributed polygons and tiled road triangles.

Requires Python 3.12+, numpy and shapely>=2.1. Network is deliberately separate:
download OSM XML from the documented bounding box and pass --osm. No GIS runs
at game startup. Optional bare-earth elevation grids can replace the fallback.
"""
import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

import numpy as np
from shapely import constrained_delaunay_triangles
from shapely.geometry import LineString, Polygon, Point, box
from shapely.ops import unary_union
from shapely.strtree import STRtree

ROOT = Path(__file__).resolve().parents[1]
CENTER = (80.6183, 7.3682)
EXTENT = box(-640, -640, 640, 640)
DEFAULT_WIDTH = {"trunk": 8.5, "primary": 7., "secondary": 6.,
                 "tertiary": 5.5, "unclassified": 4., "residential": 4.,
                 "living_street": 3.5, "service": 3., "track": 3.}
SETBACK = {"trunk": 1.5, "primary": 1.2, "secondary": 1., "tertiary": .8}


def project(lon, lat):
    # Right-handed Godot axes: east +X, up +Y, south +Z. North is -Z.
    return ((float(lon) - CENTER[0]) * 110300,
            (CENTER[1] - float(lat)) * 110700)


def polygons(g):
    if g.is_empty:
        return []
    if g.geom_type == "Polygon":
        return [g]
    if hasattr(g, "geoms"):
        return [p for child in g.geoms for p in polygons(child)]
    return []


def lines(g):
    if g.is_empty:
        return []
    if g.geom_type == "LineString":
        return [g]
    return [p for child in getattr(g, "geoms", []) for p in lines(child)]


def number(value, fallback):
    try:
        return float(str(value).split(";")[0].replace(" m", ""))
    except (ValueError, TypeError):
        return fallback


def coords(p):
    return [[round(x, 4), round(y, 4)] for x, y in list(p.coords)]


def preprocess(osm, output):
    tree = ET.parse(osm).getroot()
    nodes = {n.get("id"): project(n.get("lon"), n.get("lat")) for n in tree.findall("node")}
    roads, building_sources, omitted = [], [], []
    for way in tree.findall("way"):
        tags = {t.get("k"): t.get("v") for t in way.findall("tag")}
        path = [nodes[n.get("ref")] for n in way.findall("nd") if n.get("ref") in nodes]
        if len(path) < 2:
            continue
        category = tags.get("highway")
        if category in DEFAULT_WIDTH and tags.get("area") != "yes":
            # Bridges/tunnels need separate decks. Never flatten them into ground.
            if tags.get("bridge", "no") != "no" or tags.get("tunnel", "no") != "no" or tags.get("layer", "0") != "0":
                omitted.append({"id": way.get("id"), "reason": "grade-separated-road-requires-deck"})
                continue
            oneway = tags.get("oneway", "yes" if tags.get("junction")=="roundabout" else "no")
            width = number(tags.get("width"), DEFAULT_WIDTH[category])
            if "width" not in tags and "lanes" in tags:
                width = max(2.7, number(tags["lanes"], 1) * 2.8)
            width = min(14., max(2.5, width))
            for line in lines(LineString(path).intersection(EXTENT)):
                if line.length < 1:
                    continue
                roads.append({"id": way.get("id"), "category": category,
                              "width": width, "width_inferred": "width" not in tags,
                              "oneway": oneway, "lanes": tags.get("lanes"),
                              "name": tags.get("name", ""), "surface": tags.get("surface", "unknown"),
                              "setback": SETBACK.get(category, .5),
                              "shoulder": .75 if width >= 5.5 else .35,
                              "path": coords(line), "tags": tags})
        if "building" in tags and len(path) >= 4 and path[0] == path[-1]:
            poly = Polygon(path)
            # Do not silently repair self-intersecting footprints or erase holes.
            if not poly.is_valid:
                omitted.append({"id": way.get("id"), "reason": "invalid-footprint"})
            elif EXTENT.covers(poly) and poly.area > 8:
                building_sources.append((way.get("id"), poly, tags))
    centerlines = [LineString(r["path"]) for r in roads]
    road_shapes = [line.buffer(r["width"] / 2, cap_style="round", join_style="round")
                   for line, r in zip(centerlines, roads)]
    shoulder_shapes = [line.buffer(r["width"] / 2 + r["shoulder"], join_style="round")
                       for line, r in zip(centerlines, roads)]
    reserved_shapes = [line.buffer(r["width"] / 2 + r["shoulder"] + r["setback"], join_style="round")
                       for line, r in zip(centerlines, roads)]
    pavement = unary_union(road_shapes).intersection(EXTENT)
    shoulder = unary_union(shoulder_shapes).intersection(EXTENT).difference(pavement)
    reserved = unary_union(reserved_shapes)
    road_tree = STRtree(centerlines)
    buildings, occupied = [], []
    for identity, poly, tags in sorted(building_sources, key=lambda x: int(x[0])):
        # Full footprint, including the foundation: never move a mapped object.
        if poly.intersects(reserved):
            omitted.append({"id": identity, "reason": "road-shoulder-setback-conflict"})
            continue
        if any(poly.intersects(p) for p in occupied):
            omitted.append({"id": identity, "reason": "overlapping-mapped-building"})
            continue
        floor_count = min(5., max(1., number(tags.get("building:levels"), 2.)))
        height = min(25., max(3., number(tags.get("height"), floor_count * 3.0)))
        nearest_line = centerlines[road_tree.nearest(poly.centroid)]
        outline = list(poly.exterior.coords)[:-1]
        frontage = min(range(len(outline)), key=lambda i: Point((np.array(outline[i])+np.array(outline[(i+1)%len(outline)]))*.5).distance(nearest_line))
        buildings.append({"id": identity, "footprint": coords(poly.exterior)[:-1],
                          "holes": [coords(ring)[:-1] for ring in poly.interiors],
                          "height": height, "height_inferred": "height" not in tags,
                          "levels": floor_count, "tags": tags,
                          "frontage":frontage, "shopfront_inferred":poly.distance(nearest_line)<25 and int(identity)%4==0})
        occupied.append(poly)

    # Preserve the actual DSM values, document that interpolation adds no detail.
    preview = json.loads((ROOT / "data/akurana/preview.json").read_text())
    dem = list(base64.b64decode(preview["grid"]))
    coarse = np.array(dem).reshape(25,25)
    def sample_dem(x, z):
        z = -z  # The inherited grid's rows originally ran northward.
        u, v = np.clip((x+640)/1280*24,0,24), np.clip((z+640)/1280*24,0,24)
        ix, iz = min(int(u),23), min(int(v),23)
        a = coarse[iz,ix]*(1-u+ix)+coarse[iz,ix+1]*(u-ix)
        b = coarse[iz+1,ix]*(1-u+ix)+coarse[iz+1,ix+1]*(u-ix)
        return float(a*(1-v+iz)+b*(v-iz))
    # Reconcile lateral road slope into an inferred earthwork corridor. Keep
    # longitudinal source grade; this is expressly not a surveyed road profile.
    field = []
    for z in range(-640,641,4):
        for x in range(-640,641,4):
            point = Point(x,z)
            index = road_tree.nearest(point)
            line, road = centerlines[index], roads[index]
            distance = line.distance(point)
            h = sample_dem(x,z)
            width = road["width"]*.5
            if distance < width+12:
                closest = line.interpolate(line.project(point))
                center_h = sample_dem(closest.x,closest.y)
                weight = 1. if distance<=width else max(0.,1.-(distance-width)/12.)
                weight = weight*weight*(3-2*weight)
                # 2% crown is inferred and does not imply mapped banking.
                h = h*(1-weight)+(center_h-distance*.02)*weight
            field.append(round(h,4))

    # Mask center markings within junction envelopes. Real node IDs remain in
    # the XML snapshot; geometric overlap catches intersections split by ways.
    junctions = []
    for i, line in enumerate(centerlines):
        for j in road_tree.query(line.buffer(.05)):
            if j <= i:
                continue
            overlap = line.intersection(centerlines[j])
            if overlap.is_empty:
                continue
            points = [overlap] if overlap.geom_type == "Point" else list(getattr(overlap, "geoms", []))
            for point in points:
                if point.geom_type == "Point":
                    junctions.append(point.buffer(max(roads[i]["width"], roads[j]["width"]) * .8 + 1.))
    junction_mask = unary_union(junctions)
    markings = []
    for road, line in zip(roads, centerlines):
        # No centerline on a narrow road or a tagged one-way street.
        if road["width"] >= 5.5 and road["oneway"] in ("no", "false", "0"):
            for distance in np.arange(0, line.length, 10.):
                dash = LineString([line.interpolate(distance), line.interpolate(min(line.length, distance + 4.))])
                markings.extend(polygons(dash.buffer(.065, cap_style="flat").difference(junction_mask)))
        if road["width"]>=6.5:
            for side in ("left","right"):
                edge = line.parallel_offset(road["width"]*.5-.18,side,join_style="round")
                markings.extend(polygons(edge.buffer(.05,cap_style="flat").difference(junction_mask)))
    markings = unary_union(markings).intersection(pavement)

    # Intersect with 8m grid before triangulating: triangles cannot bridge terrain
    # features. Union before tessellation eliminates asphalt overlap/z fighting.
    tiles = {}
    for name, geometry in [("road", pavement), ("shoulder", shoulder), ("marking", markings)]:
        for x in range(-640, 640, 4):
            for z in range(-640, 640, 4):
                cell = box(x, z, x + 4, z + 4)
                if not geometry.intersects(cell):
                    continue
                clipped = geometry.intersection(cell)
                key = f"{(x+640)//64}:{(z+640)//64}"
                tile = tiles.setdefault(key, {"origin": [((x+640)//64)*64-640, ((z+640)//64)*64-640],
                                              "road": [], "shoulder": [], "marking": []})
                # Split on the identical terrain-cell diagonal. Every road
                # triangle then lies on one terrain plane plus its clearance.
                halves = [Polygon([(x,z),(x,z+4),(x+4,z)]),
                          Polygon([(x+4,z),(x,z+4),(x+4,z+4)])]
                pieces = [p for half in halves for p in polygons(clipped.intersection(half))]
                for poly in pieces:
                    if poly.area < .00001:
                        continue
                    for triangle in constrained_delaunay_triangles(poly).geoms:
                        if triangle.area < .000001:
                            continue
                        vertices = coords(triangle.exterior)[:3]
                        if name == "shoulder":
                            for vertex in vertices:
                                # The shoulder meets pavement exactly, then
                                # tapers into ground without a raised kerb.
                                distance = pavement.distance(Point(vertex))
                                nearest = road_tree.nearest(Point(vertex))
                                vertex.append(round(.13*max(0.,1-distance/roads[nearest]["shoulder"]),4))
                        tile[name].extend(vertices)

    # Deterministic procedural scenery lives outside all mapped footprints and
    # road reservations. Never call it mapped vegetation or a real shop facade.
    rng = np.random.default_rng(27419)
    forbidden = unary_union([reserved.buffer(7.), *[p.buffer(6.) for p in occupied]])
    plants = []
    for _ in range(5500):
        x, z = rng.uniform(-635, 635, 2)
        if not forbidden.contains(Point(x, z)):
            plants.append([round(x, 3), round(z, 3), int(rng.integers(0, 4)), round(float(rng.uniform(.75, 1.4)), 3)])
    poles = []
    pole_forbidden = unary_union([reserved.buffer(.2), *[p.buffer(.4) for p in occupied]])
    for road, line in zip(roads,centerlines):
        if road["width"]<5.5: continue
        for distance in np.arange(15.,line.length,45.):
            p = line.interpolate(distance)
            ahead = line.interpolate(min(line.length,distance+.5))
            behind = line.interpolate(max(0.,distance-.5))
            tangent = np.array(ahead.coords[0])-np.array(behind.coords[0])
            tangent /= max(.001,np.linalg.norm(tangent))
            offset = np.array([-tangent[1],tangent[0]])*(road["width"]*.5+road["shoulder"]+road["setback"]+2.6)
            position = Point(np.array(p.coords[0])+offset)
            if EXTENT.covers(position) and not pole_forbidden.intersects(position.buffer(.3)):
                poles.append([round(position.x,3),round(position.y,3)])
    result = {"schema": 2, "center": list(CENTER), "extent": [-640,-640,640,640],
              "projection": {"x_m_per_degree":110300,"z_m_per_degree":-110700,"z_positive":"south"},
              "source": {"osm_sha256": hashlib.sha256(Path(osm).read_bytes()).hexdigest(),
                         "osm_attribution":"© OpenStreetMap contributors, ODbL 1.0",
                         "dem":"Copernicus GLO-30 DSM reduced fallback: 25x25, 53.33m spacing, 1m quantization, offset 440m; not survey-grade"},
              "dem": dem, "height_field":field, "height_grid_size":321, "height_step":4,
              "elevation_adjustment":"Inferred 2% road crown and 12m earthwork blend; longitudinal grades from fallback DSM, not surveyed",
              "roads": roads, "buildings": buildings, "tiles": list(tiles.values()),
              "plants": plants, "poles_inferred":poles, "omitted": omitted}
    output.write_text(json.dumps(result, separators=(",", ":")), encoding="utf-8")
    runtime = {k:v for k,v in result.items() if k not in ("tiles","plants","poles_inferred","omitted")}
    (output.parent / "world-runtime.json").write_text(json.dumps(runtime,separators=(",",":")),encoding="utf-8")
    report = {"roads":len(roads),"buildings":len(buildings),"road_tiles":len(tiles),
              "omitted":len(omitted),"plants_inferred":len(plants),
              "pavement_area_m2":round(pavement.area,3),
              "building_clearance_conflicts":sum(Polygon(b["footprint"]).intersects(reserved) for b in buildings),
              "source_sha256": result["source"]["osm_sha256"]}
    (output.parent / "geometry-report.json").write_text(json.dumps(report, indent=2))
    assert report["building_clearance_conflicts"] == 0
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--osm", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "data/akurana/world.json")
    args = parser.parse_args()
    preprocess(args.osm, args.output)

