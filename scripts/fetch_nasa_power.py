"""Download NASA POWER daily data for the SAMA towns and write one compact
bundled file: assets/data/sais_power.json.

Run:  python scripts/fetch_nasa_power.py
Format of the output (per town):
  lat, lon, years [1984..2024],
  rain: {year: [366 values in tenths of mm, -1 = missing]}   (index = day of year - 1, Jan 1 = 0)
  clim: {T2M, T2M_MAX, T2M_MIN, RH2M, WS2M, PS: [366 values]}  (mean per day of year, null if no data)
NASA fill value -999 is treated as missing and never averaged in.
"""
import json
import sys
import urllib.request
from datetime import date, timedelta
from pathlib import Path

TOWNS = {  # approximate: verify and document (docs/OPEN_ITEMS.md)
    "boufakrane": (33.72, -5.30),
    "elhajeb": (33.69, -5.37),
    "sebaaaioun": (33.85, -5.46),
    "aintaoujdate": (33.93, -4.77),
    "mhaya": (33.93, -5.43),
    "erfoud": (31.43, -4.23),
}
PARAMS = ["PRECTOTCORR", "T2M", "T2M_MAX", "T2M_MIN", "RH2M", "WS2M", "PS"]
CLIM = ["T2M", "T2M_MAX", "T2M_MIN", "RH2M", "WS2M", "PS"]
Y0, Y1 = 1984, 2024
URL = ("https://power.larc.nasa.gov/api/temporal/daily/point?parameters={p}"
       "&community=AG&longitude={lon}&latitude={lat}&start={a}0101&end={b}1231&format=JSON")


def fetch(lat, lon):
    url = URL.format(p=",".join(PARAMS), lon=lon, lat=lat, a=Y0, b=Y1)
    with urllib.request.urlopen(url, timeout=180) as r:
        return json.load(r)["properties"]["parameter"]


def doy_index(d):
    # Feb 29 keeps its own slot (index 59); other days of non-leap years skip it
    leap = d.year % 4 == 0 and (d.year % 100 != 0 or d.year % 400 == 0)
    idx = d.timetuple().tm_yday - 1
    if not leap and idx >= 59:
        idx += 1
    return idx


def build(par):
    rain = {y: [-1] * 366 for y in range(Y0, Y1 + 1)}
    sums = {k: [0.0] * 366 for k in CLIM}
    cnt = {k: [0] * 366 for k in CLIM}
    d = date(Y0, 1, 1)
    while d <= date(Y1, 12, 31):
        key = d.strftime("%Y%m%d")
        i = doy_index(d)
        v = par["PRECTOTCORR"].get(key, -999)
        if v > -990:
            rain[d.year][i] = round(v * 10)
        for k in CLIM:
            v = par[k].get(key, -999)
            if v > -990:
                sums[k][i] += v
                cnt[k][i] += 1
        d += timedelta(days=1)
    clim = {k: [round(sums[k][i] / cnt[k][i], 1) if cnt[k][i] else None
                for i in range(366)] for k in CLIM}
    return rain, clim


def main():
    out = {"source": "NASA POWER daily point API, community AG", "years": [Y0, Y1], "towns": {}}
    for name, (lat, lon) in TOWNS.items():
        print("fetching", name, file=sys.stderr)
        rain, clim = build(fetch(lat, lon))
        out["towns"][name] = {"lat": lat, "lon": lon, "rain": rain, "clim": clim}
    path = Path(__file__).resolve().parent.parent / "assets" / "data" / "sais_power.json"
    path.write_text(json.dumps(out, separators=(",", ":")), encoding="utf-8")
    print("wrote", path, path.stat().st_size // 1024, "KB", file=sys.stderr)


if __name__ == "__main__":
    main()
