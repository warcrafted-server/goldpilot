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
    def test_genera_items_y_semillas(self):
        db = sqlite3.connect(":memory:")
        db.executescript("""
                CREATE TABLE ItemSparse (ID INTEGER, SellPrice INTEGER, Stackable INTEGER, Bonding INTEGER);
                CREATE TABLE Item (ID INTEGER, ClassID INTEGER, SubclassID INTEGER);
                CREATE TABLE v_nodo_zona (tipo TEXT, objeto_id INTEGER, item_id INTEGER,
                    zona_id INTEGER, puntos INTEGER, origen TEXT);
                INSERT INTO ItemSparse VALUES (1, 10, 20, 1);
                INSERT INTO Item VALUES (1, 0, 0);
                INSERT INTO ItemSparse VALUES (2, 0, 1, 0);
                INSERT INTO Item VALUES (2, 12, 0);
                INSERT INTO ItemSparse VALUES (3, 45, 5, 2);
                INSERT INTO Item VALUES (3, 7, 6);
                INSERT INTO v_nodo_zona VALUES ('hierba', 100, 3, 12, 4, 'forever');
                INSERT INTO v_nodo_zona VALUES ('mineral', 101, NULL, 12, 2, 'juego');
        """)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        addon_dir = tmp.name
        items, nodes = generar_desde_conexion(db, addon_dir, "2026-11-23")
        db.close()
        self.assertEqual(items, [(3, 45, 5, 2, 7, 6)])
        self.assertEqual(nodes, [("hierba", 100, 3, 12, 4, "seed"),
                                 ("mineral", 101, 0, 12, 2, "obs")])
        with open(os.path.join(addon_dir, "Data", "Generated", "Items.lua"), encoding="utf-8") as f:
            item_lua = f.read()
        with open(os.path.join(addon_dir, "Data", "Generated", "NodeSeeds.lua"), encoding="utf-8") as f:
            node_lua = f.read()
        self.assertIn('[3] = "45;5;2;7;6"', item_lua)
        self.assertIn('"hierba;100;3;12;4;seed"', node_lua)
        self.assertIn('"mineral;101;0;12;2;obs"', node_lua)


if __name__ == "__main__":
    unittest.main()
