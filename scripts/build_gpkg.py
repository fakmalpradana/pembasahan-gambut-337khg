"""Gabung 5 shapefile Sekat Kanal BRGM PPEG -> satu GeoPackage bersih.

Jalankan dari folder LH:  python3 scripts/build_gpkg.py
"""
import glob
import os

import geopandas as gpd
import numpy as np
import pandas as pd
import pyogrio
from shapely.geometry import Point

SRC_DIR = "Sekat Kanal BRGM"
OUT = "output/sekat_kanal_brgm_ppeg_2026.gpkg"
CONTOUR_MAX = 200  # m; di atas ini jelas bukan elevasi gambut (kolom tertukar)

RENAME = {
    "Id": "id_kontur_asal", "KODE_KANAL": "kode_kanal", "KET_KANAL": "jenis_kanal",
    "Length__M": "panjang_kanal_m", "Contour": "elevasi_kontur_m",
    "NAMA_KHG": "nama_khg", "PULAU": "pulau", "PROV_2023": "provinsi",
    "KABKO_2023": "kabupaten", "KEC_2023": "kecamatan", "DESA_2023": "desa",
    "PERUSAHAAN": "perusahaan", "IZIN_USAHA": "izin_usaha", "NAMOBJ": "nama_kawasan_konservasi",
    "Fungsi": "fungsi_kawasan_kode", "Fungsi_KWS": "fungsi_kawasan",
    "PL_2022": "penutupan_lahan_2022", "SKEG_2024": "kerusakan_eg_2024",
    "FEG_250K": "fungsi_eg_250k", "FEG_PEAT_1": "fungsi_eg_ketebalan",
    "PEAT_THICK": "tebal_gambut_kelas", "TNH_GAMBUT": "tanah_gambut",
    "SK_FEG_50K": "sk_feg_50k", "KDLMN_GBT": "kedalaman_gambut_bbsdlp",
    "KMTNGN_GBT": "kematangan_gambut", "LANDFORM": "landform",
    "GMBT_BBSDL": "gambut_bbsdlp", "LAHAN_GAMB": "lahan_gambut", "BUFFER": "buffer",
    "BURN_PERIO": "frekuensi_terbakar", "CD_ATK": "terdampak_kanal",
    "PROG_DMPG_": "program_dmpg", "PROG_INTER": "prioritas_intervensi",
    "LUAS_HA": "luas_poligon_analisis_ha",
}
BA = [f"BA_{y}" for y in range(2015, 2025)]


def load(path):
    enc = open(path[:-4] + ".CPG").read().strip()
    g = gpd.read_file(path, engine="pyogrio", encoding="cp1252" if "1252" in enc else "utf-8")
    g["sumber_file"] = os.path.basename(path)
    return g


def clean(raw):
    df = raw[list(RENAME) + BA + ["sumber_file", "geometry"]].rename(columns=RENAME)
    # MultiPoint 1-bagian -> Point
    df["geometry"] = df.geometry.apply(lambda g: g.geoms[0] if g.geom_type == "MultiPoint" else g)
    obj = df.select_dtypes(["object", "string"]).columns.drop("geometry", errors="ignore")
    df[obj] = df[obj].apply(lambda s: s.str.strip()).replace({"-": None, "None": None, "": None})
    df["tebal_gambut_kelas"] = df.tebal_gambut_kelas.str.replace(",", ".")
    df["landform"] = df.landform.str.capitalize()
    years = df[BA].notna().to_numpy() * np.arange(2015, 2025)
    df["tahun_terbakar"] = [",".join(str(y) for y in r if y) or None for r in years]
    df = df.drop(columns=BA)
    df["terdampak_kanal"] = df.terdampak_kanal.eq("Area Terdampak Kanal")
    df["gambut_bbsdlp"] = df.gambut_bbsdlp.eq("Gambut 50K, BBSDLP")
    df["lahan_gambut"] = df.lahan_gambut.eq("LAHAN GAMBUT")
    df["kode_kanal"] = df.kode_kanal.astype(int)
    df["perusahaan"] = df.perusahaan.replace({"NON KONSESI/PERIZINAN": None})
    df["izin_usaha"] = df.izin_usaha.replace({"NON KONSESI": None})
    bad = df.elevasi_kontur_m > CONTOUR_MAX
    df["qc_flag"] = np.where(bad, "kontur_invalid", None)
    df.loc[bad, "elevasi_kontur_m"] = np.nan
    return gpd.GeoDataFrame(df, geometry="geometry", crs=4326)


def main():
    parts = [load(f) for f in sorted(glob.glob(f"{SRC_DIR}/*.shp"))]
    n_in = sum(map(len, parts))
    df = clean(pd.concat(parts, ignore_index=True))
    df["x"], df["y"] = df.geometry.x.round(7), df.geometry.y.round(7)
    attrs = [c for c in df.columns if c not in ("geometry", "sumber_file")]
    dup = df.duplicated(attrs)
    removed = df[dup].groupby("sumber_file").size()
    df = df[~dup].copy()
    df["n_baris_lokasi"] = df.groupby(["x", "y"]).x.transform("size").astype(int)
    df = df.drop(columns=["x", "y"]).reset_index(drop=True)
    df.insert(0, "fid_sekat", np.arange(1, len(df) + 1))

    qc = pd.DataFrame({
        "sumber_file": [p.sumber_file.iat[0] for p in parts],
        "baris_masuk": [len(p) for p in parts],
    }).set_index("sumber_file")
    qc["duplikat_identik_dibuang"] = removed.reindex(qc.index).fillna(0).astype(int)
    qc["baris_keluar"] = df.groupby("sumber_file").size().reindex(qc.index)
    qc["kontur_invalid"] = df[df.qc_flag.notna()].groupby("sumber_file").size().reindex(qc.index).fillna(0).astype(int)
    qc["titik_pertemuan_kanal"] = df[df.n_baris_lokasi > 1].groupby("sumber_file").size().reindex(qc.index).fillna(0).astype(int)
    qc = qc.reset_index()

    os.makedirs("output", exist_ok=True)
    if os.path.exists(OUT):
        os.remove(OUT)
    df.to_file(OUT, layer="sekat_kanal", driver="GPKG", engine="pyogrio")
    pyogrio.write_dataframe(qc, OUT, layer="qc_ringkasan", driver="GPKG")

    # self-check
    assert n_in == 348143, n_in
    assert len(df) == n_in - qc.duplikat_identik_dibuang.sum()
    assert not df.geometry.is_empty.any() and (df.geom_type == "Point").all()
    assert (df.elevasi_kontur_m.dropna() <= CONTOUR_MAX).all()
    assert df.tebal_gambut_kelas.dropna().str.contains(",").sum() == 0
    print(qc.to_string(index=False))
    print(f"OK -> {OUT}: {len(df)} titik")


if __name__ == "__main__":
    main()
