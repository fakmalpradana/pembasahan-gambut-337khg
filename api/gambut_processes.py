"""OGC API - Processes untuk Pembasahan Gambut (plugin pygeoapi).

Proses baca (publik): ringkasan-dashboard, validasi-khg, saran-lokasi-pompa
Proses tulis (wajib login di proxy): ajukan-review, putuskan-review, refresh-statistik
"""
import json
import os
from functools import cache

from sqlalchemy import create_engine, text

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError


@cache
def engine(role):
    pw = os.environ['PW_OGC_WRITER' if role == 'ogc_writer' else 'PW_OGC_READER']
    return create_engine(
        f"postgresql+psycopg2://{role}:{pw}@{os.environ['PG_HOST']}:{os.environ.get('PG_PORT', '5432')}"
        f"/{os.environ['PG_DB']}", pool_pre_ping=True, pool_size=2)


def query(sql, params, role='ogc_reader', write=False):
    """sql boleh berupa list statement; hasil diambil dari statement terakhir (1 transaksi)."""
    stmts = sql if isinstance(sql, list) else [sql]
    with engine(role).begin() if write else engine(role).connect() as con:
        for s in stmts[:-1]:
            con.execute(text(s), params)
        return [dict(r._mapping) for r in con.execute(text(stmts[-1]), params)]


def meta(pid, title, desc, inputs, output, example):
    return {
        'version': '1.0.0', 'id': pid, 'title': {'id': title, 'en': title},
        'description': {'id': desc, 'en': desc},
        'jobControlOptions': ['sync-execute'], 'keywords': ['gambut', 'KHG'],
        'inputs': {k: {'title': k, 'description': d, 'schema': s, 'minOccurs': 1 if req else 0,
                       'maxOccurs': 1} for k, (d, s, req) in inputs.items()},
        'outputs': {'hasil': {'title': 'hasil', 'description': output,
                              'schema': {'type': 'object', 'contentMediaType': 'application/json'}}},
        'example': {'inputs': example}, 'links': [],
    }


INT = {'type': 'integer'}
NUM = {'type': 'number'}


def khg_id(data):
    if data.get('khg_id') is None:
        raise ProcessorExecuteError('khg_id wajib diisi')
    return int(data['khg_id'])


def _status(rows):
    if not rows:
        raise ProcessorExecuteError('KHG tidak ditemukan')
    return json.loads(json.dumps(rows[0], default=str))


class _Base(BaseProcessor):
    META = None

    def __init__(self, processor_def):
        super().__init__(processor_def, self.META)

    def execute(self, data, outputs=None):
        return 'application/json', {'id': 'hasil', 'value': self.run(data)}


class RingkasanDashboard(_Base):
    META = meta('ringkasan-dashboard', 'Ringkasan Dashboard Nasional',
                'KPI kartu Dashboard Nasional dan distribusi status alur kerja KHG.',
                {}, 'Satu objek KPI', {})

    def run(self, data):
        return _status(query('SELECT * FROM alur.v_dashboard', {}))


class ValidasiKHG(_Base):
    META = meta('validasi-khg', 'Validasi otomatis KHG',
                'Menjalankan aturan validasi (pompa dekat sumber air, di luar konsesi, kanal berstatus, '
                'kapasitas pompa, geometri valid) pada versi terakhir KHG.',
                {'khg_id': ('ID KHG (lihat koleksi khg)', INT, True),
                 'maks_jarak_air_m': ('Jarak maksimum pompa ke sumber air (m), default 500', NUM, False)},
                'Daftar hasil cek', {'khg_id': 1})

    def run(self, data):
        return query("""SELECT v.cek, v.tingkat, v.lolos, v.pesan
                          FROM alur.v_khg_status s, alur.validasi_khg(s.versi_id, :jarak) v
                         WHERE s.khg_id = :khg""",
                     {'khg': khg_id(data), 'jarak': data.get('maks_jarak_air_m', 500)})


class SaranLokasiPompa(_Base):
    META = meta('saran-lokasi-pompa', 'Saran lokasi pompa',
                'Kandidat lokasi pompa di sepanjang kanal aktif, disaring jarak ke sungai, tebal gambut, '
                'dan buffer konsesi; diberi skor kesesuaian 0-1.',
                {'khg_id': ('ID KHG', INT, True),
                 'maks_jarak_m': ('Maks. jarak ke sumber air (m), default 500', NUM, False),
                 'min_tebal_m': ('Min. tebal gambut (m), default 3', NUM, False),
                 'buffer_konsesi_m': ('Buffer konsesi (m), default 100', NUM, False),
                 'jumlah': ('Jumlah saran, default 3', INT, False)},
                'GeoJSON FeatureCollection kandidat', {'khg_id': 1, 'maks_jarak_m': 500})

    def run(self, data):
        rows = query("""SELECT peringkat, skor, skor_sumber_air, skor_kanal, skor_gambut, skor_terbakar,
                               jarak_sungai_m, sungai_id, kanal_id, tebal_gambut_m, jarak_konsesi_m,
                               ST_AsGeoJSON(geom)::json AS geometry
                          FROM peta.saran_lokasi_pompa(:khg, :jarak, :tebal, :buffer, 100, :n)""",
                     {'khg': khg_id(data), 'jarak': data.get('maks_jarak_m', 500),
                      'tebal': data.get('min_tebal_m', 3), 'buffer': data.get('buffer_konsesi_m', 100),
                      'n': data.get('jumlah', 3)})
        feats = [{'type': 'Feature', 'geometry': r.pop('geometry'),
                  'properties': {k: float(v) if v is not None and k != 'peringkat' else v
                                 for k, v in r.items()}} for r in rows]
        return {'type': 'FeatureCollection', 'features': feats}


class AjukanReview(_Base):
    META = meta('ajukan-review', 'Ajukan KHG ke review',
                'Mengubah versi draft/revisi KHG menjadi review dan menyimpan snapshot validasi. Wajib login.',
                {'khg_id': ('ID KHG', INT, True)}, 'Status versi', {'khg_id': 1})

    def run(self, data):
        return _status(query(["SELECT alur.ajukan_review(versi_id) FROM alur.v_khg_status WHERE khg_id = :khg",
                              "SELECT * FROM alur.v_khg_status WHERE khg_id = :khg"],
                             {'khg': khg_id(data)}, role='ogc_writer', write=True))


class PutuskanReview(_Base):
    META = meta('putuskan-review', 'Putuskan review KHG',
                'Reviewer menyetujui (approved) atau meminta revisi (revisi) versi yang sedang direview. Wajib login.',
                {'khg_id': ('ID KHG', INT, True),
                 'keputusan': ("'approved' atau 'revisi'", {'type': 'string', 'enum': ['approved', 'revisi']}, True),
                 'catatan': ('Catatan reviewer', {'type': 'string'}, False)},
                'Status versi', {'khg_id': 1, 'keputusan': 'approved', 'catatan': 'Lokasi sesuai.'})

    def run(self, data):
        return _status(query(["SELECT alur.putuskan(versi_id, :k, :c) FROM alur.v_khg_status WHERE khg_id = :khg",
                              "SELECT * FROM alur.v_khg_status WHERE khg_id = :khg"],
                             {'khg': khg_id(data), 'k': data.get('keputusan'), 'c': data.get('catatan')},
                             role='ogc_writer', write=True))


class RefreshStatistik(_Base):
    META = meta('refresh-statistik', 'Refresh statistik KHG',
                'Menghitung ulang api.khg_statistik (hotspot 30 hari, km kanal, jumlah sekat). Wajib login.',
                {}, 'Waktu refresh', {})

    def run(self, data):
        return _status(query("SELECT api.refresh_statistik() AS waktu", {}, role='ogc_writer', write=True))
