"""Download NASA POWER daily data and write ONE compact bundled file: assets/data/nasa_power.json

Run:  python scripts/fetch_nasa_power.py            (all reference points)
      python scripts/fetch_nasa_power.py boufakrane (only some ids)

Per point:
  lat, lon            requested coordinates
  srcLat, srcLon, elev  what NASA returned (grid-cell centre and its elevation, metres)
  coverage            {param: number of missing days}  (NASA fill value -999 = missing)
  rain                {year: [366 ints, tenths of mm, -1 = missing]}   index = day-of-year - 1 (Feb 29 keeps slot 59)
  clim                per-day-of-year means of T2M, T2M_MAX, T2M_MIN, RH2M, WS2M, PS  (for the home card)
  seasons             agricultural years Oct 1 -> Sep 30, 40 of them (1984-85 ... 2023-24), each a list of days:
                      rain, tmax, tmin, rh, ws, rad  (all x10 ints, -999 = missing)
Parameters: PRECTOTCORR, T2M, T2M_MAX, T2M_MIN, RH2M, WS2M, PS, ALLSKY_SFC_SW_DWN  (community AG).
Coordinates are rounded to 2 decimals (about 1 km) before they are sent.
"""
import json
import sys
import time
import urllib.request
from datetime import date, timedelta
from pathlib import Path

# id -> (lat, lon). Saïs towns + Erfoud from the brief; regional points from the Phase 2 brief.
# Coordinates are approximate and must be verified (docs/OPEN_ITEMS.md).
POINTS = {
    "boufakrane": (33.72, -5.30), "elhajeb": (33.69, -5.37), "sebaaaioun": (33.85, -5.46),
    "aintaoujdate": (33.93, -4.77), "mhaya": (33.93, -5.43), "erfoud": (31.43, -4.23),
    "meknes": (33.89, -5.55),
    "kenitra": (34.26, -6.58), "sidislimane": (34.26, -5.93), "eljadida": (33.25, -8.50),
    "zemamra": (32.63, -8.70), "benimellal": (32.34, -6.35), "fquihbensalah": (32.50, -6.69),
    "taroudant": (30.47, -8.87), "agadir": (30.35, -9.57),
}
PARAMS = ["PRECTOTCORR", "T2M", "T2M_MAX", "T2M_MIN", "RH2M", "WS2M", "PS", "ALLSKY_SFC_SW_DWN"]
CLIM = ["T2M", "T2M_MAX", "T2M_MIN", "RH2M", "WS2M", "PS"]
SEASON_VARS = [("rain", "PRECTOTCORR"), ("tmax", "T2M_MAX"), ("tmin", "T2M_MIN"),
               ("rh", "RH2M"), ("ws", "WS2M"), ("rad", "ALLSKY_SFC_SW_DWN")]
Y0, Y1 = 1984, 2024
URL = ("https://power.larc.nasa.gov/api/temporal/daily/point?parameters={p}"
       "&community=AG&longitude={lon}&latitude={lat}&start={a}0101&end={b}1231&format=JSON")


def fetch(lat, lon):
    url = URL.format(p=",".join(PARAMS), lon=round(lon, 2), lat=round(lat, 2), a=Y0, b=Y1)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=240) as r:
                return json.load(r)
        except Exception as e:  # retry with backoff, respect the API limits
            print("  retry", attempt + 1, e, file=sys.stderr)
            time.sleep(5 * (attempt + 1))
    raise SystemExit("NASA POWER request failed")


def doy_index(d):
    leap = d.year % 4 == 0 and (d.year % 100 != 0 or d.year % 400 == 0)
    idx = d.timetuple().tm_yday - 1
    return idx + 1 if (not leap and idx >= 59) else idx


def val(par, k, key):
    v = par[k].get(key, -999)
    return None if v <= -990 else v


def build(js):
    par = js["properties"]["parameter"]
    coords = js["geometry"]["coordinates"]  # lon, lat, elevation
    rain = {y: [-1] * 366 for y in range(Y0, Y1 + 1)}
    sums = {k: [0.0] * 366 for k in CLIM}
    cnt = {k: [0] * 366 for k in CLIM}
    missing = {k: 0 for k in PARAMS}
    d = date(Y0, 1, 1)
    while d <= date(Y1, 12, 31):
        key = d.strftime("%Y%m%d")
        i = doy_index(d)
        for k in PARAMS:
            if val(par, k, key) is None:
                missing[k] += 1
        v = val(par, "PRECTOTCORR", key)
        if v is not None:
            rain[d.year][i] = round(v * 10)
        for k in CLIM:
            v = val(par, k, key)
            if v is not None:
                sums[k][i] += v
                cnt[k][i] += 1
        d += timedelta(days=1)
    clim = {k: [round(sums[k][i] / cnt[k][i], 1) if cnt[k][i] else None for i in range(366)] for k in CLIM}

    seasons = {name: [] for name, _ in SEASON_VARS}
    for y in range(Y0, Y1):  # 1984-85 ... 2023-24
        day = date(y, 10, 1)
        cols = {name: [] for name, _ in SEASON_VARS}
        while day <= date(y + 1, 9, 30):
            key = day.strftime("%Y%m%d")
            for name, k in SEASON_VARS:
                v = val(par, k, key)
                cols[name].append(-999 if v is None else round(v * 10))
            day += timedelta(days=1)
        for name, _ in SEASON_VARS:
            seasons[name].append(cols[name])
    return {"srcLon": coords[0], "srcLat": coords[1], "elev": coords[2] if len(coords) > 2 else None,
            "coverage": missing, "rain": rain, "clim": clim, "seasons": seasons}


def main():
    ids = sys.argv[1:] or list(POINTS)
    out = {"version": 2, "source": "NASA POWER daily point API, community AG", "years": [Y0, Y1],
           "fetched": date.today().isoformat(), "points": {}}
    for name in ids:
        lat, lon = POINTS[name]
        print("fetching", name, file=sys.stderr)
        b = build(fetch(lat, lon))
        b.update({"lat": lat, "lon": lon})
        out["points"][name] = b
        time.sleep(1)
    path = Path(__file__).resolve().parent.parent / "assets" / "data" / "nasa_power.json"
    path.write_text(json.dumps(out, separators=(",", ":")), encoding="utf-8")
    print("wrote", path, path.stat().st_size // 1024, "KB", file=sys.stderr)


if __name__ == "__main__":
    main()
