#!/usr/bin/env python3
"""Genera la semilla local de nodos desde wowdata (solo para pruebas locales)."""
import argparse
import datetime
import math
import os

try:
    from tools.generar_desde_wowdata import DEFAULT_DB, abrir_db
except ImportError:
    from generar_desde_wowdata import DEFAULT_DB, abrir_db

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXT_SQL = """
    SELECT s.object_id, m.tipo, m.habilidad_min, a.ui_map_id, s.x, s.y
    FROM ext_object_spawns s
    JOIN man_nodo m ON m.objeto_id = s.object_id
    JOIN ext_area_to_uimap a ON a.area_id = s.zone_id
    WHERE s.x > 0 AND s.y > 0 AND a.ui_map_id > 0
"""
OBS_SQL = """
    SELECT p.entry_id, m.tipo, m.habilidad_min, p.map_id, p.x, p.y
    FROM obs_wdc_nodo_pos p
    JOIN man_nodo m ON m.objeto_id = p.entry_id
"""


def entero(value, escala):
    return int(math.floor(float(value) * escala + 0.5))


def hay_tabla(db, nombre):
    row = db.execute("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
                     (nombre,)).fetchone()
    return row is not None


def cargar_semilla(db, mapas=None):
    datos = {}

    def anadir(map_id, objeto, tipo, habilidad, x, y):
        if tipo not in ("herb", "ore") or x is None or y is None:
            return
        map_id, objeto = int(map_id), int(objeto)
        if mapas and map_id not in mapas:
            return
        entry = datos.setdefault(map_id, {}).get(objeto)
        if entry is None:
            entry = {"kind": tipo, "skill": None if habilidad is None else int(habilidad),
                     "points": set()}
            datos[map_id][objeto] = entry
        entry["points"].add((x, y))

    for objeto, tipo, habilidad, map_id, x, y in db.execute(EXT_SQL):
        anadir(map_id, objeto, tipo, habilidad, entero(x, 100), entero(y, 100))
    if hay_tabla(db, "obs_wdc_nodo_pos"):
        for objeto, tipo, habilidad, map_id, x, y in db.execute(OBS_SQL):
            anadir(map_id, objeto, tipo, habilidad, entero(x, 10000), entero(y, 10000))
    return datos


def render_semilla(semilla, fecha):
    puntos = sum(len(entry["points"]) for objetos in semilla.values()
                 for entry in objetos.values())
    lines = ["-- Semilla local de wowdata: no redistribuir",
             "-- Generado: %s | Origen: wowdata local | Puntos: %d" % (fecha, puntos),
             "local _, addon = ...", "addon.DataNodeSpots = {"]
    for map_id in sorted(semilla):
        lines.append("    [%d] = {" % map_id)
        for objeto in sorted(semilla[map_id]):
            entry = semilla[map_id][objeto]
            campos = ['kind = "%s"' % entry["kind"]]
            if entry["skill"] is not None:
                campos.append("skill = %d" % entry["skill"])
            campos.append('p = "%s"' % ";".join("%d,%d" % punto
                                                for punto in sorted(entry["points"])))
            lines.append("        [%d] = { %s }," % (objeto, ", ".join(campos)))
        lines.append("    },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def generar(db_path, addon_dir, fecha, mapas=None):
    db = abrir_db(db_path)
    try:
        semilla = cargar_semilla(db, mapas)
    finally:
        db.close()
    target = os.path.join(addon_dir, "Data", "Local")
    os.makedirs(target, exist_ok=True)
    path = os.path.join(target, "NodeSpots.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(render_semilla(semilla, fecha))
    print("Mapas: %d | NodeSpots.lua: %d bytes" % (len(semilla), os.path.getsize(path)))
    return semilla


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", default=os.environ.get("WOWDATA_DB", DEFAULT_DB))
    parser.add_argument("--fecha", default=datetime.date.today().isoformat())
    parser.add_argument("--mapa", type=int, action="append", dest="mapas",
                        help="uiMapID a incluir (repetible); sin la opción, todos")
    args = parser.parse_args(argv)
    generar(args.db, os.path.join(ROOT, "GoldPilot"), args.fecha, args.mapas)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
