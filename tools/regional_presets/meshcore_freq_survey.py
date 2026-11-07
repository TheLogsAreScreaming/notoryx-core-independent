#!/usr/bin/env python3
"""MeshCore frequency survey: which radio settings are used where.

Pulls the public MeshCore map node list (map.meshcore.io) and the community
preset list (the same one the MeshCore app shows), groups nodes into grid
cells, and writes CSVs showing the dominant radio setting per area.

Settings are compared on frequency / bandwidth / spreading factor only:
coding rate does not have to match (receivers read it from each packet).

The map data is self-reported by node owners at upload time, so treat the
output as "published", not "confirmed on air".

Python 3.9+, standard library only.
"""
from __future__ import annotations

import argparse
import collections
import csv
import datetime as dt
import json
import math
import os
import ssl
import sys
import time
import urllib.request

NODES_URL = "https://map.meshcore.io/api/v1/nodes"
PRESETS_URL = "https://api.meshcore.nz/api/v1/config"
USER_AGENT = "meshcore-freq-survey/1.0"
HERE = os.path.dirname(os.path.abspath(__file__))
NODE_TYPES = {1: "Client", 2: "Repeater", 3: "Room Server", 4: "Sensor"}

REGIONS = {  # name: (min_lat, min_lon, max_lat, max_lon)
    "world": (-90, -180, 90, 180),
    "us": (24.0, -125.0, 50.0, -66.0),
    "canada": (41.5, -141.0, 70.0, -52.0),
    "europe": (34.0, -25.0, 72.0, 45.0),
    "uk": (49.5, -8.7, 61.0, 2.0),
    "australia": (-44.0, 112.0, -10.0, 154.0),
    "nz": (-47.5, 166.0, -34.0, 179.0),
}


# ---------------------------------------------------------------- download

def _ssl_context():
    """python.org builds on macOS ship without CA certificates until
    'Install Certificates.command' is run; fall back to the system store."""
    ctx = ssl.create_default_context()
    if not ctx.get_ca_certs():
        for cafile in ("/etc/ssl/cert.pem", "/usr/local/etc/openssl/cert.pem"):
            if os.path.exists(cafile):
                ctx.load_verify_locations(cafile)
                break
    return ctx


SSL_CONTEXT = _ssl_context()


def urlopen(url, timeout=120):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    return urllib.request.urlopen(req, timeout=timeout, context=SSL_CONTEXT)


def fetch(url: str, path: str, max_age_h: float, refresh: bool) -> str:
    """Download url to path unless a fresh enough copy exists."""
    if not refresh and os.path.exists(path):
        age_h = (time.time() - os.path.getmtime(path)) / 3600
        if age_h < max_age_h:
            return path
    print(f"Downloading {url} ...", file=sys.stderr)
    tmp = path + ".part"
    with urlopen(url) as r, open(tmp, "wb") as f:
        while chunk := r.read(1 << 20):
            f.write(chunk)
    os.replace(tmp, path)
    return path


# ---------------------------------------------------------------- helpers

def parse_ts(s):
    if not s:
        return None
    try:
        return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None


def fmt_num(x) -> str:
    """910.5250 -> '910.525', 62.5 -> '62.5', 250.0 -> '250'."""
    try:
        return f"{float(x):.4f}".rstrip("0").rstrip(".")
    except (TypeError, ValueError):
        return str(x)


def setting_key(p: dict) -> tuple[str, str, str] | None:
    if not p or p.get("freq") is None or p.get("bw") is None or p.get("sf") is None:
        return None
    return (fmt_num(p["freq"]), fmt_num(p["bw"]), str(int(p["sf"])))


def setting_label(k) -> str:
    return f"{k[0]} MHz / BW{k[1]} / SF{k[2]}"


def haversine_km(lat1, lon1, lat2, lon2) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def load_presets(path: str) -> dict:
    """Map (freq, bw, sf) -> list of preset titles."""
    try:
        with open(path) as f:
            entries = json.load(f)["config"]["suggested_radio_settings"]["entries"]
    except (OSError, KeyError, ValueError) as e:
        print(f"warning: could not read presets ({e}); preset names left blank", file=sys.stderr)
        return {}
    out = collections.defaultdict(list)
    for e in entries:
        k = setting_key({"freq": e.get("frequency"), "bw": e.get("bandwidth"),
                         "sf": e.get("spreading_factor")})
        if k:
            out[k].append(e.get("title", "?"))
    return out


def preset_name(presets, k) -> str:
    return " | ".join(presets.get(k, [])) or "(no matching preset)"


# ---------------------------------------------------------------- main

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0],
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    area = ap.add_mutually_exclusive_group()
    area.add_argument("--region", choices=sorted(REGIONS), default="us",
                      help="named bounding box")
    area.add_argument("--bbox", metavar="MINLAT,MINLON,MAXLAT,MAXLON",
                      help="custom bounding box")
    area.add_argument("--near", metavar="LAT,LON",
                      help="only nodes within --radius km of this point")
    ap.add_argument("--radius", type=float, default=100, help="km, used with --near")
    ap.add_argument("--grid", type=float, default=1.0, help="grid cell size in degrees")
    ap.add_argument("--days", type=int, default=30,
                    help="only nodes updated within this many days (0 = all)")
    ap.add_argument("--types", default="all",
                    help="node types: all, or comma list of client,repeater,room,sensor")
    ap.add_argument("--min-nodes", type=int, default=5, help="skip cells with fewer nodes")
    ap.add_argument("--out", default=os.path.join(HERE, "out"), help="output folder")
    ap.add_argument("--cache", default=os.path.join(HERE, "cache"), help="download cache folder")
    ap.add_argument("--max-age", type=float, default=12, help="re-download after N hours")
    ap.add_argument("--refresh", action="store_true", help="force re-download")
    exp = ap.add_argument_group("app presets export (ignores --region/--bbox/--near)")
    exp.add_argument("--export-presets", metavar="FILE",
                     help="write a regional_presets.json for the NOTORYX apps")
    exp.add_argument("--merge-into", metavar="FILE",
                     help="existing regional_presets.json: keep its hand-made entries and the "
                          "'updated' dates of map areas whose settings haven't changed")
    exp.add_argument("--min-area-nodes", type=int, default=15,
                     help="smallest area (nodes on its setting) to export")
    exp.add_argument("--min-share", type=float, default=60,
                     help="a grid cell joins an area only if this %% of its nodes share the setting")
    exp.add_argument("--geocode", action="store_true",
                     help="name areas via OpenStreetMap Nominatim (1 request per second)")
    args = ap.parse_args(argv)

    def floats(s, count, flag):
        try:
            vals = tuple(float(x) for x in s.split(","))
        except ValueError:
            vals = ()
        if len(vals) != count:
            ap.error(f"{flag} needs {count} comma-separated numbers, got {s!r}")
        return vals
    if args.bbox:
        args.bbox_vals = floats(args.bbox, 4, "--bbox")
    if args.near:
        args.near_vals = floats(args.near, 2, "--near")

    os.makedirs(args.cache, exist_ok=True)
    os.makedirs(args.out, exist_ok=True)
    nodes_path = fetch(NODES_URL, os.path.join(args.cache, "nodes.json"), args.max_age, args.refresh)
    presets_path = fetch(PRESETS_URL, os.path.join(args.cache, "presets.json"), args.max_age, args.refresh)
    presets = load_presets(presets_path)
    with open(nodes_path) as f:
        nodes = json.load(f)

    # area filter
    near = None
    if args.near:
        near = args.near_vals
        in_area = lambda la, lo: haversine_km(near[0], near[1], la, lo) <= args.radius
        area_desc = f"within {args.radius:g} km of {near[0]},{near[1]}"
    else:
        if args.bbox:
            box = args.bbox_vals
            area_desc = f"bbox {args.bbox}"
        else:
            box = REGIONS[args.region]
            area_desc = f"region {args.region}"
        in_area = lambda la, lo: box[0] <= la <= box[2] and box[1] <= lo <= box[3]

    # type filter
    type_names = {"client": 1, "repeater": 2, "room": 3, "sensor": 4}
    if args.types == "all":
        want_types = set(NODE_TYPES)
    else:
        want_types = {type_names[t.strip().lower()] for t in args.types.split(",")}

    cutoff = None
    if args.days > 0:
        cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=args.days)

    base = []  # nodes passing the type/date filters, anywhere in the world
    for n in nodes:
        la, lo = n.get("adv_lat"), n.get("adv_lon")
        if la is None or lo is None or (la == 0 and lo == 0):
            continue
        if n.get("type") not in want_types:
            continue
        k = setting_key(n.get("params") or {})
        if not k:
            continue
        if cutoff:
            ts = parse_ts(n.get("updated_date")) or parse_ts(n.get("last_advert"))
            if not ts or ts < cutoff:
                continue
        base.append((n, k))
    kept = [(n, k) for n, k in base if in_area(n["adv_lat"], n["adv_lon"])]

    # ---- nodes.csv
    with open(os.path.join(args.out, "nodes.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["name", "type", "lat", "lon", "freq_mhz", "bw_khz", "sf", "cr",
                    "preset", "updated", "public_key"])
        for n, k in kept:
            p = n["params"]
            w.writerow([n.get("adv_name", ""), NODE_TYPES.get(n.get("type"), n.get("type")),
                        n["adv_lat"], n["adv_lon"], k[0], k[1], k[2], p.get("cr", ""),
                        preset_name(presets, k), n.get("updated_date", ""), n.get("public_key", "")])

    # ---- settings.csv (overall totals)
    totals = collections.Counter(k for _, k in kept)
    with open(os.path.join(args.out, "settings.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["freq_mhz", "bw_khz", "sf", "nodes", "share_pct", "preset"])
        for k, c in totals.most_common():
            w.writerow([*k, c, round(100 * c / len(kept), 1) if kept else 0, preset_name(presets, k)])

    # ---- areas.csv (grid cells)
    cells = collections.defaultdict(collections.Counter)
    g = args.grid
    for n, k in kept:
        cell = (math.floor(n["adv_lat"] / g) * g, math.floor(n["adv_lon"] / g) * g)
        cells[cell][k] += 1
    rows = []
    for (la, lo), ct in cells.items():
        tot = sum(ct.values())
        if tot < args.min_nodes:
            continue
        ranked = ct.most_common()
        top, tc = ranked[0]
        second = ranked[1] if len(ranked) > 1 else None
        rows.append([
            round(la + g / 2, 4), round(lo + g / 2, 4), round(la, 4), round(lo, 4),
            round(la + g, 4), round(lo + g, 4), tot,
            setting_label(top), tc, round(100 * tc / tot, 1), preset_name(presets, top),
            setting_label(second[0]) if second else "", second[1] if second else 0,
            len(ranked),
            "; ".join(f"{setting_label(k)} x{c}" for k, c in ranked),
        ])
    rows.sort(key=lambda r: (-r[0], r[1]))
    with open(os.path.join(args.out, "areas.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["center_lat", "center_lon", "min_lat", "min_lon", "max_lat", "max_lon",
                    "nodes", "top_setting", "top_nodes", "top_share_pct", "top_preset",
                    "second_setting", "second_nodes", "distinct_settings", "all_settings"])
        w.writerows(rows)

    # ---- areas.geojson (drop into geojson.io or any GIS tool)
    feats = []
    for r in rows:
        mnla, mnlo, mxla, mxlo = r[2], r[3], r[4], r[5]
        feats.append({"type": "Feature",
                      "properties": {"nodes": r[6], "top_setting": r[7], "top_share_pct": r[9],
                                     "top_preset": r[10], "all_settings": r[14]},
                      "geometry": {"type": "Polygon", "coordinates": [[
                          [mnlo, mnla], [mxlo, mnla], [mxlo, mxla], [mnlo, mxla], [mnlo, mnla]]]}})
    with open(os.path.join(args.out, "areas.geojson"), "w") as f:
        json.dump({"type": "FeatureCollection", "features": feats}, f)

    # ---- map.html (open in any browser; tiles + Leaflet load from the web)
    write_map(os.path.join(args.out, "map.html"), kept, totals, presets, area_desc)

    # ---- console summary
    print(f"\n{len(kept)} nodes {area_desc}"
          + (f", updated in last {args.days} days" if cutoff else "")
          + f", types={args.types}")
    print("\nMost used settings:")
    for k, c in totals.most_common(10):
        print(f"  {c:6}  {setting_label(k):32} {preset_name(presets, k)}")
    if totals:
        main_k = totals.most_common(1)[0][0]
        odd = [r for r in rows if r[7] != setting_label(main_k)]
        print(f"\nAreas ({g:g} deg cells, >= {args.min_nodes} nodes) not mainly on {setting_label(main_k)}:")
        for r in odd[:25]:
            print(f"  {r[0]:8.3f},{r[1]:9.3f}  {r[6]:4} nodes  {r[7]} ({r[9]}%)  {r[10]}")
        if len(odd) > 25:
            print(f"  ... {len(odd) - 25} more in areas.csv")
    print(f"\nWrote {args.out}/nodes.csv, settings.csv, areas.csv, areas.geojson, map.html")
    if args.export_presets:
        import presets_export
        presets_export.export(base, presets_path, args)
    return 0


PALETTE = ["#2563eb", "#dc2626", "#16a34a", "#d97706", "#9333ea", "#0891b2",
           "#db2777", "#65a30d", "#7c3aed", "#ea580c"]
OTHER_COLOR = "#6b7280"


def write_map(path, kept, totals, presets, area_desc):
    """Self-contained Leaflet map: one dot per node, coloured by setting."""
    top = [k for k, _ in totals.most_common(len(PALETTE))]
    color = {k: PALETTE[i] for i, k in enumerate(top)}
    legend = [{"label": setting_label(k), "preset": preset_name(presets, k),
               "count": totals[k], "color": color[k]} for k in top]
    rest = sum(c for k, c in totals.items() if k not in color)
    if rest:
        legend.append({"label": "Other settings", "preset": "", "count": rest, "color": OTHER_COLOR})
    pts = [[round(n["adv_lat"], 5), round(n["adv_lon"], 5), n.get("adv_name", ""),
            NODE_TYPES.get(n.get("type"), "?"), setting_label(k),
            n["params"].get("cr", ""), color.get(k, OTHER_COLOR),
            (n.get("updated_date") or "")[:10]] for n, k in kept]
    data = json.dumps({"points": pts, "legend": legend, "title": area_desc}).replace("</", "<\\/")
    html = MAP_TEMPLATE.replace("__DATA__", data)
    with open(path, "w") as f:
        f.write(html)


MAP_TEMPLATE = """<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>MeshCore settings map</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
 html,body,#map{height:100%;margin:0;font:13px -apple-system,system-ui,sans-serif}
 .legend{background:#fff;padding:10px 12px;border-radius:8px;box-shadow:0 1px 6px #0003;max-width:340px}
 .legend h3{margin:0 0 6px;font-size:13px}
 .legend label{display:flex;gap:8px;align-items:flex-start;margin:4px 0;cursor:pointer}
 .sw{width:12px;height:12px;border-radius:50%;flex:none;margin-top:2px}
 .pre{color:#6b7280;font-size:11px}
 .note{color:#6b7280;font-size:11px;margin-top:6px}
</style></head><body><div id="map"></div>
<script>
const D = __DATA__;
const map = L.map('map', {preferCanvas: true});
L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  {maxZoom: 18, attribution: '&copy; OpenStreetMap | data: map.meshcore.io'}).addTo(map);
const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const groups = {};
for (const [lat, lon, name, type, setting, cr, color, upd] of D.points) {
  const g = groups[color] ??= L.layerGroup().addTo(map);
  L.circleMarker([lat, lon], {radius: type === 'Repeater' ? 6 : 4, color: '#fff', weight: 1,
    fillColor: color, fillOpacity: .9})
   .bindPopup(`<b>${esc(name)}</b><br>${esc(type)}<br>${esc(setting)} / CR${esc(cr)}<br>updated ${esc(upd)}`)
   .addTo(g);
}
const fit = () => {
  map.invalidateSize();
  if (D.points.length) map.fitBounds(D.points.map(p => [p[0], p[1]]), {padding: [30, 30], maxZoom: 12});
  else map.setView([39, -98], 4);
};
fit();
window.addEventListener('load', () => setTimeout(fit, 50));
const lg = L.control({position: 'topright'});
lg.onAdd = () => {
  const d = L.DomUtil.create('div', 'legend');
  d.innerHTML = `<h3>${esc(D.points.length)} nodes, ${esc(D.title)}</h3>` + D.legend.map(l =>
    `<label><input type="checkbox" checked data-c="${l.color}"><span class="sw" style="background:${l.color}"></span>
     <span>${esc(l.label)} &middot; ${l.count}<br><span class="pre">${esc(l.preset)}</span></span></label>`).join('') +
    `<div class="note">Big dots = repeaters. Settings are owner-reported, not measured.</div>`;
  d.querySelectorAll('input').forEach(i => i.onchange = () => {
    const g = groups[i.dataset.c]; if (g) i.checked ? g.addTo(map) : map.removeLayer(g);
  });
  L.DomEvent.disableClickPropagation(d);
  return d;
};
lg.addTo(map);
</script></body></html>
"""


if __name__ == "__main__":
    sys.exit(main())
