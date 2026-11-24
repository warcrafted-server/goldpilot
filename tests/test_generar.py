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


if __name__ == "__main__":
    unittest.main()
