#!/usr/bin/env python3
"""Pruebas del generador con una base mínima."""
import os
import sqlite3
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from tools.generar_desde_wowdata import generar_desde_conexion
from tools.generar_semilla_local import cargar_semilla, render_semilla


class GenerarTests(unittest.TestCase):
    def test_genera_solo_semillas(self):
        db = sqlite3.connect(":memory:")
        db.executescript("""
                CREATE TABLE v_nodo_zona (tipo TEXT, objeto_id INTEGER, item_id INTEGER,
                    zona_id INTEGER, puntos INTEGER, origen TEXT);
                INSERT INTO v_nodo_zona VALUES ('hierba', 100, 3, 12, 4, 'forever');
                INSERT INTO v_nodo_zona VALUES ('mineral', 101, NULL, 12, 2, 'juego');
        """)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        addon_dir = tmp.name
        nodes = generar_desde_conexion(db, addon_dir, "2026-11-23")
        db.close()
        self.assertEqual(nodes, [("hierba", 100, 3, 12, 4, "seed"),
                                 ("mineral", 101, 0, 12, 2, "obs")])
        with open(os.path.join(addon_dir, "Data", "Generated", "NodeSeeds.lua"), encoding="utf-8") as f:
            node_lua = f.read()
        self.assertIn('"hierba;100;3;12;4;seed"', node_lua)
        self.assertIn('"mineral;101;0;12;2;obs"', node_lua)
        self.assertFalse(os.path.exists(os.path.join(addon_dir, "Data", "Generated", "Items.lua")))


class SemillaLocalTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.executescript("""
                CREATE TABLE man_nodo (objeto_id INTEGER, tipo TEXT, habilidad_min INTEGER);
                CREATE TABLE ext_object_spawns (object_id INTEGER, zone_id INTEGER, x REAL, y REAL);
                CREATE TABLE ext_area_to_uimap (area_id INTEGER, ui_map_id INTEGER);
                CREATE TABLE obs_wdc_nodo_pos (entry_id INTEGER, map_id INTEGER, x REAL, y REAL);
                INSERT INTO man_nodo VALUES (100, 'herb', 50), (101, 'ore', NULL),
                    (102, 'herb', 1), (103, 'mineral', 0);
                INSERT INTO ext_object_spawns VALUES (100, 5, 50.0, 25.0), (100, 5, 50.0, 25.0),
                    (101, 5, 12.3, 45.6), (102, 6, 10.5, 20.4), (103, 5, 0, 10);
                INSERT INTO ext_area_to_uimap VALUES (5, 12), (6, 13), (7, 0);
                INSERT INTO obs_wdc_nodo_pos VALUES (100, 12, 0.1234, 0.5),
                    (101, 12, 0.2, 0.3), (102, 13, 0.3, 0.4);
        """)

    def tearDown(self):
        self.db.close()

    def test_render_semilla_local(self):
        semilla = cargar_semilla(self.db)
        lua = render_semilla(semilla, "2026-11-24")
        self.assertTrue(lua.startswith("-- Semilla local de wowdata: no redistribuir\n"))
        self.assertIn("local _, addon = ...\naddon.DataNodeSpots = {\n", lua)
        self.assertIn('        [100] = { kind = "herb", skill = 50, p = "1234,5000;5000,2500" },',
                      lua)
        self.assertIn('        [101] = { kind = "ore", p = "1230,4560;2000,3000" },', lua)
        self.assertIn("    [13] = {", lua)
        self.assertIn('        [102] = { kind = "herb", skill = 1, p = "1050,2040;3000,4000" },',
                      lua)
        self.assertNotIn("[103]", lua)

    def test_filtra_mapas(self):
        semilla = cargar_semilla(self.db, [12])
        lua = render_semilla(semilla, "2026-11-24")
        self.assertIn("    [12] = {", lua)
        self.assertNotIn("    [13] = {", lua)

    def test_sin_tabla_observada(self):
        self.db.execute("DROP TABLE obs_wdc_nodo_pos")
        semilla = cargar_semilla(self.db)
        self.assertEqual(semilla[12][100]["points"], {(5000, 2500)})
        self.assertEqual(semilla[12][101]["points"], {(1230, 4560)})


if __name__ == "__main__":
    unittest.main()
