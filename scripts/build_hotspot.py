"""Satukan hotspot bulanan Jan-Sep 2026 (2 format: FIRMS & ekspor KML SiPongi) -> satu GeoPackage.

Jalankan dari folder LH:  python3 scripts/build_hotspot.py
File .zip di folder sumber adalah salinan identik .shp, jadi diabaikan.
"""
import glob
import os
import re

import geopandas as gpd
import pandas as pd
from shapely import force_2d

SRC = "__ Data Hotspot (Januari-September, 2026)"
OUT = "output/hotspot_2026.gpkg"
KEPERCAYAAN = {"high": "tinggi", "tinggi": "tinggi", "medium": "sedang", "nominal": "sedang",
               "sedang": "sedang", "low": "rendah", "rendah": "rendah"}
TZ = {"WIB": "+07:00", "WITA": "+08:00", "WIT": "+09:00"}
SATELIT = {"NASA-NOAA20": ("NOAA20", "VIIRS"), "NASA-NOAA21": ("NOAA21", "VIIRS"),
           "NASA-SNPP": ("SNPP", "VIIRS"), "NASA-MODIS": (None, "MODIS")}


def firms(g, berkas):
    t = g.ACQ_TIME.str.zfill(4)
    waktu = pd.to_datetime(g.ACQ_DATE.dt.strftime("%Y-%m-%d") + " " + t.str[:2] + ":" + t.str[2:], utc=True)
    return pd.DataFrame({
        "waktu": waktu, "satelit": g.SATELLITE, "instrumen": g.INSTRUMENT,
        "kepercayaan": g.C_LEVEL.str.lower().map(KEPERCAYAAN), "kepercayaan_nilai": g.CONFIDENCE,
        "frp_mw": g.FRP, "brightness_k": g.BRIGHTNESS, "siang_malam": g.DAYNIGHT,
        "provinsi": None, "kabupaten": None, "kecamatan": None, "desa": None,
        "format_sumber": "firms", "berkas_sumber": berkas, "geometry": g.geometry})


def kml(g, berkas):
    kv = g.PopupInfo.apply(lambda p: {k.strip(): v.strip() for k, v in
                                      (x.split(":", 1) for x in p.split("<br>") if ":" in x)})
    kv = pd.DataFrame(kv.tolist(), index=g.index)
    m = kv.Tanggal.str.extract(r"(\d{1,2} \w{3} \d{4} \d{2}:\d{2}) (\w+)")
    assert m[1].isin(TZ.keys()).all(), m[1].unique()
    waktu = pd.to_datetime(m[0] + m[1].map(TZ), format="%d %b %Y %H:%M%z", utc=True)
    sat = kv.Sumber.map(SATELIT)
    assert sat.notna().all(), kv.Sumber[sat.isna()].unique()
    return pd.DataFrame({
        "waktu": waktu, "satelit": sat.str[0], "instrumen": sat.str[1],
        "kepercayaan": kv.Kepercayaan.str.lower().map(KEPERCAYAAN), "kepercayaan_nilai": None,
        "frp_mw": None, "brightness_k": None, "siang_malam": None,
        "provinsi": kv.get("Provinsi"), "kabupaten": kv["Kota/Kabupaten"], "kecamatan": kv.Kecamatan,
        "desa": kv.Desa, "format_sumber": "kml_sipongi", "berkas_sumber": berkas,
        "geometry": force_2d(g.geometry.values)})


def main():
    parts = []
    for f in sorted(glob.glob(f"{SRC}/*.shp")):
        g = gpd.read_file(f, engine="pyogrio")
        b = os.path.basename(f)
        parts.append((kml if "PopupInfo" in g else firms)(g, b))
    df = gpd.GeoDataFrame(pd.concat(parts, ignore_index=True), geometry="geometry", crs=4326)
    for c in ("kepercayaan_nilai", "frp_mw", "brightness_k"):   # KML tidak punya nilai ini -> tetap numerik
        df[c] = pd.to_numeric(df[c])
    df["kepercayaan_nilai"] = df.kepercayaan_nilai.astype("Int16")
    n = len(df)
    df = df.drop_duplicates(["waktu", "satelit", "instrumen", "geometry"]).reset_index(drop=True)
    os.makedirs("output", exist_ok=True)
    df.to_file(OUT, layer="hotspot", driver="GPKG", engine="pyogrio")

    assert df.waktu.notna().all() and df.kepercayaan.notna().all()
    assert (df.geom_type == "Point").all() and not df.has_z.any()
    assert df.waktu.min() >= pd.Timestamp("2025-12-31T17:00Z")
    print(df.groupby([df.waktu.dt.tz_convert("Asia/Jakarta").dt.month, "instrumen"]).size().unstack(fill_value=0))
    print(f"OK -> {OUT}: {len(df)} titik ({n - len(df)} duplikat dibuang)")


if __name__ == "__main__":
    main()
