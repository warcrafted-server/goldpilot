#!/usr/bin/env python3
"""Genera semillas de nodos desde wowdata."""
import argparse
import datetime
import os
import sqlite3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DB = r"C:\Users\msanc\Documents\Projectes\Wow\wowdata\datos\wow.sqlite"


def abrir_db(path):
    return sqlite3.connect("file:" + os.path.abspath(path).replace("\\", "/") + "?mode=ro", uri=True)


def cargar_nodos(db):
    return sorted((str(tipo), int(objeto_id), int(item_id or 0), int(zona_id), int(puntos),
                   "obs" if origen == "juego" else "seed")
                  for tipo, objeto_id, item_id, zona_id, puntos, origen in db.execute(
                      "SELECT tipo, objeto_id, item_id, zona_id, puntos, origen FROM v_nodo_zona"))


def render_nodos(rows, fecha):
    lines = ["-- Generado: " + fecha + " | Origen: wowdata | Nodos: " + str(len(rows)),
             "local _, GP = ...", "GP.DataNodeSeeds = {"]
    lines.extend('    "%s;%d;%d;%d;%d;%s",' % row for row in rows)
    lines.append("}")
    return "\n".join(lines) + "\n"


def generar(db_path, addon_dir, fecha):
    db = abrir_db(db_path)
    try:
        return generar_desde_conexion(db, addon_dir, fecha)
    finally:
        db.close()


def generar_desde_conexion(db, addon_dir, fecha):
    nodos = cargar_nodos(db)
    generated = os.path.join(addon_dir, "Data", "Generated")
    os.makedirs(generated, exist_ok=True)
    nodes_path = os.path.join(generated, "NodeSeeds.lua")
    with open(nodes_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(render_nodos(nodos, fecha))
    print("Nodos: %d | NodeSeeds.lua: %d bytes" % (len(nodos), os.path.getsize(nodes_path)))
    return nodos


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", default=os.environ.get("WOWDATA_DB", DEFAULT_DB))
    parser.add_argument("--fecha", default=datetime.date.today().isoformat())
    args = parser.parse_args(argv)
    generar(args.db, ROOT, args.fecha)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
