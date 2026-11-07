# Regional presets from the MeshCore map

`meshcore_freq_survey.py` reads the public MeshCore map (map.meshcore.io), where
node owners report their radio settings, and finds areas whose nodes mostly use
a setting that differs from the usual one for the wider region (for example
Phoenix on 908.205 / 62.5 / SF9). Python 3 standard library only.

Refresh the list (keeps hand-made entries, and keeps the `updated` date of map
areas whose settings didn't change so nobody gets a needless notification):

```bash
python3 tools/regional_presets/meshcore_freq_survey.py --refresh --geocode \
  --merge-into assets/regional_presets.json \
  --export-presets assets/regional_presets.json
```

Then copy the file to `regional_presets.json` in notoryx-core-independent-releases (the
live list) and check the diff before pushing. Area names come from
OpenStreetMap Nominatim (`--geocode`, 1 request a second, cached in `cache/`).

Without `--export-presets` the script surveys an area instead: `--region`,
`--bbox` or `--near LAT,LON --radius KM` write CSVs, GeoJSON and a map to `out/`.
