"""Rebuild assets/maps/digos_barangays.geojson from GADM 4.1 data.

Source:
    https://geodata.ucdavis.edu/gadm/gadm4.1/json/gadm41_PHL_3.json.zip

GADM level 3 is the barangay level for the Philippines. This script keeps the
26 barangays whose NAME_2 is DigosCity, normalises GADM's run-together names
("SanAgustin", "Zone1", "TresdeMayo") to the canonical spellings used by
`DigosBarangays` in lib/core/repository.dart, simplifies each ring, and writes
a compact GeoJSON with a single NAME_3 property per feature.

Licence: GADM data is free for academic and other non-commercial use with
attribution, and may not be redistributed commercially. See README > Barangay
boundaries.

Usage (from the repository root):
    python tools/extract_digos_barangays.py
"""

import json
import math
import os
import re
import urllib.request
import zipfile

GADM_URL = (
    "https://geodata.ucdavis.edu/gadm/gadm4.1/json/gadm41_PHL_3.json.zip"
)
CACHE = os.path.join(os.environ.get("TEMP", "."), "gadm41_PHL_3.json.zip")
OUT = os.path.join("assets", "maps", "digos_barangays.geojson")

CANONICAL = [
    "Aplaya", "Balabag", "Binaton", "Cogon", "Colorado", "Dawis",
    "Dulangan", "Goma", "Igpit", "Kapatagan", "Kiagot", "Lungag",
    "Mahayahay", "Matti", "Ruparan", "San Agustin", "San Jose",
    "San Miguel", "San Roque", "Sinawilan", "Soong", "Tiguman",
    "Tres De Mayo", "Zone 1", "Zone 2", "Zone 3",
]

# ~12 m at this latitude; GADM's export is already generalised, so the
# tolerance mostly guards against noisy vertices.
SIMPLIFY_EPSILON = 0.00012


def normalise(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def rdp(points, epsilon):
    """Ramer-Douglas-Peucker line simplification."""
    if len(points) < 3:
        return points

    def perpendicular(point, start, end):
        if start == end:
            return math.hypot(point[0] - start[0], point[1] - start[1])
        dx, dy = end[0] - start[0], end[1] - start[1]
        t = (
            (point[0] - start[0]) * dx + (point[1] - start[1]) * dy
        ) / (dx * dx + dy * dy)
        t = max(0.0, min(1.0, t))
        return math.hypot(
            point[0] - (start[0] + t * dx),
            point[1] - (start[1] + t * dy),
        )

    dmax, index = 0.0, 0
    for i in range(1, len(points) - 1):
        distance = perpendicular(points[i], points[0], points[-1])
        if distance > dmax:
            dmax, index = distance, i
    if dmax > epsilon:
        return (
            rdp(points[: index + 1], epsilon)[:-1]
            + rdp(points[index:], epsilon)
        )
    return [points[0], points[-1]]


def clean_ring(ring):
    points = [(round(float(c[0]), 6), round(float(c[1]), 6)) for c in ring]
    if len(points) > 3 and points[0] == points[-1]:
        points = points[:-1]
    points = rdp(points, SIMPLIFY_EPSILON)
    if points[0] != points[-1]:
        points.append(points[0])
    return [[c[0], c[1]] for c in points]


def clean_polygon(polygon):
    return [clean_ring(ring) for ring in polygon]


def main():
    if not os.path.exists(CACHE):
        print("Downloading", GADM_URL)
        urllib.request.urlretrieve(GADM_URL, CACHE)

    with zipfile.ZipFile(CACHE) as archive:
        payload = json.loads(archive.read("gadm41_PHL_3.json"))

    lookup = {normalise(name): name for name in CANONICAL}
    features = []
    unmatched = []

    for feature in payload["features"]:
        props = feature["properties"]
        if props.get("NAME_2") != "DigosCity":
            continue

        canonical = lookup.get(normalise(props["NAME_3"]))
        if canonical is None:
            unmatched.append(props["NAME_3"])
            continue

        geometry = feature["geometry"]
        polygons = (
            [geometry["coordinates"]]
            if geometry["type"] == "Polygon"
            else geometry["coordinates"]
        )
        cleaned = [clean_polygon(polygon) for polygon in polygons]
        features.append(
            {
                "type": "Feature",
                "properties": {"NAME_3": canonical},
                "geometry": {
                    "type": "Polygon" if len(cleaned) == 1 else "MultiPolygon",
                    "coordinates": cleaned[0] if len(cleaned) == 1 else cleaned,
                },
            }
        )

    features.sort(key=lambda f: f["properties"]["NAME_3"])
    if len(features) != len(CANONICAL):
        raise SystemExit(
            f"Expected {len(CANONICAL)} barangays, found {len(features)}. "
            f"Unmatched names: {unmatched}"
        )

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(
            {
                "type": "FeatureCollection",
                "name": "digos_barangays",
                "features": features,
            },
            handle,
            ensure_ascii=False,
            separators=(",", ":"),
        )

    print(f"Wrote {len(features)} barangays to {OUT}")


if __name__ == "__main__":
    main()
