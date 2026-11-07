"""Turn the line-work Digos SVG into the app's barangay GeoJSON.

`tools/digos_city_source.svg` draws the city as ~255 open border polylines
(M/L only) with no fills and no names. This script:

1. parses the polylines and snaps their endpoints into a shared node graph,
2. traces every face of the planar graph (the barangay interiors),
3. matches each face to a barangay name by nearest reference centroid taken
   from the GADM-derived shapes this asset replaces, and
4. writes `assets/maps/digos_barangays.geojson` in [lng, lat] so the in-app
   projection, hit-testing and scale bar keep working.

Usage (from the repository root):
    python tools/svg_to_barangays.py
"""

import json
import math
import os
import re
import sys

SVG = os.path.join("tools", "digos_city_source.svg")
OUT = os.path.join("assets", "maps", "digos_barangays.geojson")

# Reference centroids (lat, lng), computed from the GADM shapes this file
# replaced. Used only to name the traced faces, never as geometry.
REFERENCE = {
    "Aplaya": (6.744722, 125.373956),
    "Balabag": (6.824013, 125.268075),
    "Binaton": (6.814200, 125.339333),
    "Cogon": (6.756936, 125.381879),
    "Colorado": (6.756415, 125.317390),
    "Dawis": (6.736267, 125.361600),
    "Dulangan": (6.852918, 125.308994),
    "Goma": (6.824625, 125.292656),
    "Igpit": (6.737633, 125.313722),
    "Kapatagan": (6.904483, 125.279325),
    "Kiagot": (6.783800, 125.360743),
    "Lungag": (6.802700, 125.269367),
    "Mahayahay": (6.795817, 125.288375),
    "Matti": (6.767810, 125.302850),
    "Ruparan": (6.791580, 125.340850),
    "San Agustin": (6.784463, 125.320163),
    "San Jose": (6.738122, 125.344967),
    "San Miguel": (6.743243, 125.332157),
    "San Roque": (6.782667, 125.281217),
    "Sinawilan": (6.771855, 125.373191),
    "Soong": (6.794750, 125.356717),
    "Tiguman": (6.755475, 125.330337),
    "Tres De Mayo": (6.770133, 125.333711),
    "Zone 1": (6.773186, 125.351957),
    "Zone 2": (6.761900, 125.353214),
    "Zone 3": (6.751963, 125.354350),
}

# Geographic extent of the drawing, from the GADM shapes. The SVG aspect
# ratio matches this box (382x648 vs 0.589), so a bbox-to-bbox affine mapping
# is exact enough for a choropleth.
GEO = {
    "min_lng": 125.2500,
    "max_lng": 125.3913,
    "min_lat": 6.7264,
    "max_lat": 6.9662,
}

SNAP = 0.5          # SVG units; endpoints of neighbouring lines join here
MIN_AREA = 2.0      # drop degenerate faces (square SVG units)
MAX_MATCH_DEG = 0.030  # ~3.3 km; a fallback centroid further than this is unnamed

POINT_RE = re.compile(r"-?\d+(?:\.\d+)?")


def parse_polylines(text):
    polylines = []
    for data in re.findall(r'\bd="([^"]*)"', text):
        points = []
        for command, rest in re.findall(r"([ML])\s*([^ML]*)", data):
            numbers = [float(n) for n in POINT_RE.findall(rest)]
            for i in range(0, len(numbers) - 1, 2):
                points.append((numbers[i], numbers[i + 1]))
        if len(points) >= 2:
            polylines.append(points)
    return polylines


def snap(point):
    return (
        round(point[0] / SNAP) * SNAP,
        round(point[1] / SNAP) * SNAP,
    )


def build_graph(polylines):
    graph = {}
    for line in polylines:
        nodes = [snap(p) for p in line]
        for a, b in zip(nodes, nodes[1:]):
            if a == b:
                continue
            graph.setdefault(a, set()).add(b)
            graph.setdefault(b, set()).add(a)
    return graph


def trace_faces(graph):
    """Trace every face of the planar graph via half-edge traversal."""
    ordered = {}
    for node, neighbours in graph.items():
        ordered[node] = sorted(
            neighbours,
            key=lambda n: math.atan2(n[1] - node[1], n[0] - node[0]),
        )

    visited = set()
    faces = []

    for start in graph:
        for first in graph[start]:
            if (start, first) in visited:
                continue
            face = []
            u, v = start, first
            while (u, v) not in visited:
                visited.add((u, v))
                face.append(u)
                neighbours = ordered[v]
                index = neighbours.index(u)
                # Next half-edge is the neighbour immediately clockwise from u.
                u, v = v, neighbours[(index - 1) % len(neighbours)]
                if len(face) > 20000:
                    face = []
                    break
            if face and (u, v) == (start, first) or face:
                faces.append(face)
    return faces


def signed_area(points):
    area = 0.0
    for (x1, y1), (x2, y2) in zip(points, points[1:] + points[:1]):
        area += x1 * y2 - x2 * y1
    return area / 2.0


def centroid(points):
    x = sum(p[0] for p in points) / len(points)
    y = sum(p[1] for p in points) / len(points)
    return x, y


def point_in_polygon(point, ring):
    x, y = point
    inside = False
    for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]):
        if (y1 > y) != (y2 > y):
            if x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
                inside = not inside
    return inside


def main():
    text = open(SVG, encoding="utf-8").read()
    polylines = parse_polylines(text)
    graph = build_graph(polylines)
    print(f"polylines={len(polylines)} nodes={len(graph)}")

    xs = [p[0] for line in polylines for p in line]
    ys = [p[1] for line in polylines for p in line]
    svg_box = (min(xs), min(ys), max(xs), max(ys))
    print(f"svg bbox={tuple(round(v, 2) for v in svg_box)}")

    faces = trace_faces(graph)
    interior = []
    for face in faces:
        if len(set(face)) < 4:
            continue
        points = face + [face[0]]
        area = signed_area(points)
        if abs(area) < MIN_AREA:
            continue
        interior.append((area, points))

    # Orientation: interior faces traced one way, the outer face the other.
    positives = [f for f in interior if f[0] > 0]
    negatives = [f for f in interior if f[0] < 0]
    print(f"faces={len(interior)} positive={len(positives)} negative={len(negatives)}")
    kept = positives if len(positives) >= len(negatives) else negatives
    kept.sort(key=lambda f: -abs(f[0]))

    # The largest face is the city outline; if it is much bigger than the
    # runner-up, drop it.
    if len(kept) > 26 and abs(kept[0][0]) > 4 * abs(kept[1][0]):
        dropped = kept.pop(0)
        print(f"dropped outer face area={abs(dropped[0]):.0f}")

    def to_geo(point):
        x0, y0, x1, y1 = svg_box
        lng = GEO["min_lng"] + (point[0] - x0) / (x1 - x0) * (
            GEO["max_lng"] - GEO["min_lng"]
        )
        lat = GEO["max_lat"] - (point[1] - y0) / (y1 - y0) * (
            GEO["max_lat"] - GEO["min_lat"]
        )
        return (round(lng, 6), round(lat, 6))

    # Reference points back in SVG space for containment tests.
    x0, y0, x1, y1 = svg_box

    def to_svg(lat, lng):
        x = x0 + (lng - GEO["min_lng"]) / (
            GEO["max_lng"] - GEO["min_lng"]
        ) * (x1 - x0)
        y = y0 + (GEO["max_lat"] - lat) / (
            GEO["max_lat"] - GEO["min_lat"]
        ) * (y1 - y0)
        return (x, y)

    ref_svg = {name: to_svg(lat, lng) for name, (lat, lng) in REFERENCE.items()}
    face_areas = [abs(area) for area, _ in kept]
    face_points = [points for _, points in kept]

    # A barangay is the LARGEST face that contains its reference point.
    # Proximity alone is not enough: the SVG draws shared borders as double
    # lines, and a thin sliver between them can sit closer to a centroid.
    assigned_face = {}
    assigned_name = {}
    used = set()
    for name in sorted(REFERENCE):
        point = ref_svg[name]
        containing = [
            index
            for index, points in enumerate(face_points)
            if index not in used and point_in_polygon(point, points)
        ]
        if not containing:
            continue
        best = max(containing, key=lambda index: face_areas[index])
        assigned_face[best] = name
        assigned_name[name] = best
        used.add(best)

    # Rare fallback: nearest unused face centroid, within ~3 km.
    degrees_to_units = (x1 - x0) / (GEO["max_lng"] - GEO["min_lng"])
    for name in sorted(set(REFERENCE) - set(assigned_name)):
        point = ref_svg[name]
        best, best_distance = None, float("inf")
        for index, points in enumerate(face_points):
            if index in used:
                continue
            cx, cy = centroid(points)
            distance = math.hypot(cx - point[0], cy - point[1])
            if distance < best_distance:
                best, best_distance = index, distance
        if best is not None and best_distance <= MAX_MATCH_DEG * degrees_to_units:
            assigned_face[best] = name
            assigned_name[name] = best
            used.add(best)

    missing = sorted(set(REFERENCE) - set(assigned_name))
    print(
        f"matched={len(assigned_face)} missing={missing} "
        f"unused_faces={len(kept) - len(assigned_face)}"
    )

    grouped = {}
    for index, name in assigned_face.items():
        points = kept[index][1]
        # Guard against degenerate rings; a polygon needs three distinct
        # vertices plus the closing point.
        if len({(round(p[0], 3), round(p[1], 3)) for p in points}) < 3:
            continue
        ring = [to_geo(p) for p in points]
        if len({(c[0], c[1]) for c in ring}) < 3:
            continue
        grouped.setdefault(name, []).append(ring)

    features = []
    for name in sorted(grouped):
        rings = grouped[name]
        # GeoJSON nesting: Polygon = [ring]; MultiPolygon = [[ring], ...].
        if len(rings) == 1:
            geometry = {"type": "Polygon", "coordinates": [rings[0]]}
        else:
            geometry = {
                "type": "MultiPolygon",
                "coordinates": [[ring] for ring in rings],
            }
        features.append(
            {
                "type": "Feature",
                "properties": {"NAME_3": name},
                "geometry": geometry,
            }
        )

    if missing:
        print("ERROR: unmatched barangays:", missing, file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(
            {
                "type": "FeatureCollection",
                "name": "digos_barangays",
                "source": "tools/digos_city_source.svg",
                "features": features,
            },
            handle,
            ensure_ascii=False,
            separators=(",", ":"),
        )
    print(f"Wrote {len(features)} barangays to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
