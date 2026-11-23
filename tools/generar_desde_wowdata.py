#!/usr/bin/env python3
"""Genera datos compactos de objetos y nodos desde wowdata."""
import argparse
import datetime
import os
import sqlite3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DB = r"C:\Users\msanc\Documents\Projectes\wowdata\datos\wow.sqlite"
MAX_ITEMS_BYTES = 1024 * 1024


def abrir_db(path):
    return sqlite3.connect("file:" + os.path.abspath(path).replace("\\", "/") + "?mode=ro", uri=True)


def cargar_items(db, limitar=False):
    sql = """SELECT s.ID, COALESCE(s.SellPrice, 0), COALESCE(s.Stackable, 1),
                    s.Bonding, COALESCE(i.ClassID, 0), COALESCE(i.SubclassID, 0)
               FROM ItemSparse s JOIN Item i ON i.ID = s.ID
              WHERE s.Bonding IN (0, 2, 3) AND i.ClassID != 12"""
    if limitar:
        sql += " AND i.ClassID IN (0, 5, 7, 9)"
    return sorted(db.execute(sql).fetchall())


def cargar_nodos(db):
    return sorted((str(tipo), int(objeto_id), int(item_id or 0), int(zona_id), int(puntos),
                   "obs" if origen == "juego" else "seed")
                  for tipo, objeto_id, item_id, zona_id, puntos, origen in db.execute(
                      "SELECT tipo, objeto_id, item_id, zona_id, puntos, origen FROM v_nodo_zona"))


def render_items(rows, fecha, limitado=False):
    nota = "; limitado a ClassID 0, 5, 7 y 9 por tamaño" if limitado else ""
    lines = ["-- Generado: " + fecha + " | Origen: wowdata | Objetos: " + str(len(rows)) + nota,
             "local _, GP = ...", "GP.DataItems = {"]
    lines.extend("    [%d] = \"%d;%d;%d;%d;%d\"," % tuple(row) for row in rows)
    lines.append("}")
    return "\n".join(lines) + "\n"


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
    items = cargar_items(db)
    content = render_items(items, fecha)
    limitado = len(content.encode("utf-8")) > MAX_ITEMS_BYTES
    if limitado:
        items = cargar_items(db, limitar=True)
        content = render_items(items, fecha, limitado=True)
    nodos = cargar_nodos(db)
    generated = os.path.join(addon_dir, "Data", "Generated")
    os.makedirs(generated, exist_ok=True)
    items_path = os.path.join(generated, "Items.lua")
    nodes_path = os.path.join(generated, "NodeSeeds.lua")
    with open(items_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    with open(nodes_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(render_nodos(nodos, fecha))
    print("Objetos: %d | Nodos: %d | Items.lua: %d bytes | NodeSeeds.lua: %d bytes" %
          (len(items), len(nodos), os.path.getsize(items_path), os.path.getsize(nodes_path)))
    return items, nodos


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", default=os.environ.get("WOWDATA_DB", DEFAULT_DB))
    parser.add_argument("--fecha", default=datetime.date.today().isoformat())
    args = parser.parse_args(argv)
    generar(args.db, os.path.join(ROOT, "GoldPilot"), args.fecha)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
