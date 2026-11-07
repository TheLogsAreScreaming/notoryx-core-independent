"""Turns MeshCore map nodes into a regional_presets.json for the NOTORYX apps.

An "area" is a group of neighbouring grid cells where most nodes use the same
radio setting, and that setting is not the usual one for the wider region
(e.g. Phoenix on 908.205 / 62.5 / SF9 inside a US that mostly runs 910.525).
Areas on the usual setting are left out: the app's standard presets cover them.

File format: version 2 of the apps' regional presets document. Differences
from version 1: `pathHashBytes` may be missing (the map doesn't report it, so
the app should leave the radio's path hash alone), and areas carry `source`,
`nodes`, `sharePct`. Version 1 apps ignore a version 2 file and keep the list
they have, so publishing this can't push them a path-hash change.
"""
from __future__ import annotations

import collections
import datetime as dt
import json
import math
import os
import re
import sys
import time
import urllib.parse

from meshcore_freq_survey import haversine_km, setting_key, urlopen

# Wide regions, each with its own "usual" setting. First match wins.
BASELINE_REGIONS = [
    ("north-america", (14.0, -170.0, 72.0, -50.0)),
    ("south-america", (-56.0, -92.0, 14.0, -30.0)),
    ("europe", (34.0, -32.0, 72.0, 45.0)),
    ("new-zealand", (-48.0, 165.0, -33.0, 180.0)),
    ("australia", (-45.0, 110.0, -9.0, 160.0)),
    ("asia", (-11.0, 45.0, 60.0, 150.0)),
    ("africa", (-36.0, -20.0, 34.0, 52.0)),
]
VALID_BW = {7.8, 10.4, 15.6, 20.8, 31.25, 41.7, 62.5, 125.0, 250.0, 500.0}
ABOUT = ("Radio settings used by local MeshCore meshes. Areas with source 'map' are "
         "worked out from the public MeshCore map (map.meshcore.io), where node owners "
         "report their settings; they are not confirmed on air. Hand-made areas have no "
         "source. To add or correct an area, open a pull request and give a source in "
         "the notes.")


def _region_of(lat, lon):
    for name, (a, b, c, d) in BASELINE_REGIONS:
        if a <= lat <= c and b <= lon <= d:
            return name
    return None


def _official_path_hash(presets_path):
    """(freq, bw, sf) -> path hash bytes from the official presets, when all
    official presets with those settings agree on one."""
    try:
        with open(presets_path) as f:
            entries = json.load(f)["config"]["suggested_radio_settings"]["entries"]
    except (OSError, KeyError, ValueError):
        return {}
    seen = collections.defaultdict(set)
    for e in entries:
        k = setting_key({"freq": e.get("frequency"), "bw": e.get("bandwidth"),
                         "sf": e.get("spreading_factor")})
        if k:
            seen[k].add((e.get("network_settings") or {}).get("path_hash_size"))
    return {k: next(iter(v)) for k, v in seen.items() if len(v) == 1 and None not in v}


class _Geocoder:
    """Reverse geocoding through Nominatim, cached on disk."""

    def __init__(self, cache_dir):
        self.path = os.path.join(cache_dir, "geocode.json")
        try:
            with open(self.path) as f:
                self.cache = json.load(f)
        except (OSError, ValueError):
            self.cache = {}
        self.last = 0.0

    def name(self, lat, lon):
        key = f"{lat:.2f},{lon:.2f}"
        if key in self.cache:
            return self.cache[key]
        wait = 1.1 - (time.time() - self.last)
        if wait > 0:
            time.sleep(wait)
        q = urllib.parse.urlencode({"format": "jsonv2", "lat": f"{lat:.3f}",
                                    "lon": f"{lon:.3f}", "zoom": 10,
                                    "accept-language": "en"})
        name = None
        try:
            with urlopen("https://nominatim.openstreetmap.org/reverse?" + q, timeout=20) as r:
                a = json.load(r).get("address", {})
            place = (a.get("city") or a.get("town") or a.get("village")
                     or a.get("municipality") or a.get("county"))
            region = a.get("state") or a.get("region") or a.get("country")
            name = ", ".join(x for x in (place, region) if x) or None
        except Exception as e:  # network trouble: fall back to coordinates
            print(f"  geocode failed for {key}: {e}", file=sys.stderr)
        self.last = time.time()
        if name:
            self.cache[key] = name
            with open(self.path, "w") as f:
                json.dump(self.cache, f, indent=0, sort_keys=True)
        return name


def _same_setting(r, freq, bw, sf):
    try:
        return (abs(float(r["frequencyMHz"]) - freq) < 0.0005
                and float(r["bandwidthKHz"]) == bw and int(r["spreadingFactor"]) == sf)
    except (KeyError, TypeError, ValueError):
        return False


def _slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def _areas(base, grid, min_share, min_nodes):
    """Yields (setting, [nodes]) for each area that differs from its region."""
    by_region = collections.defaultdict(list)
    for n, k in base:
        r = _region_of(n["adv_lat"], n["adv_lon"])
        if r:
            by_region[r].append((n, k))

    for region, items in by_region.items():
        usual = collections.Counter(k for _, k in items).most_common(1)[0][0]
        cells = collections.defaultdict(list)
        for n, k in items:
            cells[(math.floor(n["adv_lat"] / grid), math.floor(n["adv_lon"] / grid))].append((n, k))
        dominant = {}
        for c, members in cells.items():
            top, cnt = collections.Counter(k for _, k in members).most_common(1)[0]
            if top != usual and cnt >= 3 and 100 * cnt / len(members) >= min_share:
                dominant[c] = top
        done = set()
        for start, k in dominant.items():
            if start in done:
                continue
            group, todo = [], [start]
            done.add(start)
            while todo:  # flood fill neighbouring cells on the same setting
                c = todo.pop()
                group.append(c)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nb = (c[0] + dy, c[1] + dx)
                        if nb not in done and dominant.get(nb) == k:
                            done.add(nb)
                            todo.append(nb)
            members = [m for c in group for m in cells[c]]
            on_setting = [n for n, kk in members if kk == k]
            if len(on_setting) >= min_nodes:
                yield region, usual, k, on_setting, len(members)


def export(base, presets_path, args):
    path_hash = _official_path_hash(presets_path)
    geo = _Geocoder(args.cache) if args.geocode else None
    today = dt.date.today().isoformat()

    old_regions = []
    if args.merge_into:
        with open(args.merge_into) as f:
            old_regions = json.load(f).get("regions", [])
    hand_made = [r for r in old_regions if r.get("source") != "map"]
    old_map = {r["id"]: r for r in old_regions if r.get("source") == "map"}

    out = []
    for region, usual, k, nodes, total in _areas(base, args.grid, args.min_share,
                                                  args.min_area_nodes):
        freq, bw, sf = float(k[0]), float(k[1]), int(k[2])
        if bw not in VALID_BW or not 137 <= freq <= 2500 or not 5 <= sf <= 12:
            continue
        lat = sum(n["adv_lat"] for n in nodes) / len(nodes)
        lon = sum(n["adv_lon"] for n in nodes) / len(nodes)
        if any(_same_setting(h, freq, bw, sf) and
               haversine_km(lat, lon, *h["center"]) <= max(h.get("radiusKm", 0), 50)
               for h in hand_made):
            continue  # a hand-made entry already covers this area
        dists = sorted(haversine_km(lat, lon, n["adv_lat"], n["adv_lon"]) for n in nodes)
        p90 = dists[min(len(dists) - 1, int(0.9 * len(dists)))]
        radius = round(min(300.0, max(30.0, p90 + 20)))
        crs = collections.Counter(int(n["params"]["cr"]) for n in nodes
                                  if 5 <= int(n["params"].get("cr") or 0) <= 8)
        cr = crs.most_common(1)[0][0] if crs else 5
        # name the area after its busiest spot, not its middle (which can be empty desert)
        busy = collections.Counter((round(n["adv_lat"] * 4), round(n["adv_lon"] * 4))
                                   for n in nodes).most_common(1)[0][0]
        name = ((geo.name(busy[0] / 4, busy[1] / 4) if geo else None)
                or f"Area near {lat:.1f}, {lon:.1f}")
        rid = f"map-{_slug(k[0])}-{_slug(k[1])}-sf{sf}-{round(lat)}-{round(lon)}"
        share = round(100 * len(nodes) / total)
        entry = {
            "id": rid,
            "name": name,
            "center": [round(lat, 4), round(lon, 4)],
            "radiusKm": radius,
            "frequencyMHz": freq,
            "bandwidthKHz": bw,
            "spreadingFactor": sf,
            "codingRate": cr,
        }
        if k in path_hash:
            entry["pathHashBytes"] = path_hash[k]
        prev = old_map.get(rid)
        same = prev and all(prev.get(f) == entry.get(f) for f in
                            ("frequencyMHz", "bandwidthKHz", "spreadingFactor",
                             "codingRate", "pathHashBytes"))
        entry["updated"] = prev["updated"] if same else today
        entry.update({
            "source": "map",
            "nodes": len(nodes),
            "sharePct": share,
            "notes": (f"From the MeshCore map: {len(nodes)} nodes here ({share}%) report "
                      f"these settings. Most of the wider area uses "
                      f"{usual[0]} MHz / BW{usual[1]} / SF{usual[2]}. "
                      "Check with your local group before switching."),
        })
        out.append(entry)

    out.sort(key=lambda r: -r["nodes"])
    doc = {"version": 2, "about": ABOUT, "generated": today,
           "regions": hand_made + out}
    with open(args.export_presets, "w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    print(f"\nExported {len(out)} map areas (+{len(hand_made)} hand-made) to {args.export_presets}:")
    for r in out:
        ph = f" / {r['pathHashBytes']}B" if "pathHashBytes" in r else ""
        print(f"  {r['nodes']:5}  {r['sharePct']:3}%  {r['frequencyMHz']:g} / BW{r['bandwidthKHz']:g} / "
              f"SF{r['spreadingFactor']} / CR{r['codingRate']}{ph}  r={r['radiusKm']}km  {r['name']}")
