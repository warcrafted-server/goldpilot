#!/usr/bin/env python3
"""Pruebas del generador de notas: versiones desde el último tag y validación."""
import contextlib
import io
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from tools import notas_release


def escribir_nota(raiz, version):
    notas = os.path.join(raiz, "docs", "notas")
    os.makedirs(notas, exist_ok=True)
    with open(os.path.join(notas, version + ".md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(f"# {version} (2026-01-01)\n\n"
                f"## English\n\n- Note {version}.\n\n"
                f"## Español\n\n- Nota {version}.\n")


class NotasReleaseTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.raiz = tmp.name
        self.anterior = notas_release.ROOT
        notas_release.ROOT = self.raiz
        self.addCleanup(setattr, notas_release, "ROOT", self.anterior)
        self.assertEqual(subprocess.run(["git", "init", "-q"], cwd=self.raiz,
                                        capture_output=True).returncode, 0)

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.raiz, capture_output=True, text=True)

    def etiquetar(self, version):
        self.git("-c", "user.name=Pruebas", "-c", "user.email=pruebas@example.com",
                 "commit", "--allow-empty", "-m", "inicio")
        self.assertEqual(self.git("tag", "v" + version).returncode, 0)

    def generar(self, version):
        salida = os.path.join(self.raiz, "salida.md")
        codigo = notas_release.main([version, "--salida", salida])
        texto = None
        if os.path.isfile(salida):
            with open(salida, encoding="utf-8") as f:
                texto = f.read()
        return codigo, texto

    def test_desde_el_ultimo_tag(self):
        for version in ("0.1.0", "0.1.1", "0.1.2"):
            escribir_nota(self.raiz, version)
        self.etiquetar("0.1.0")
        codigo, texto = self.generar("0.1.2")
        self.assertEqual(codigo, 0)
        for seccion in texto.split("# Español"):
            self.assertIn("## 0.1.2 (2026-01-01)", seccion)
            self.assertIn("## 0.1.1 (2026-01-01)", seccion)
            self.assertNotIn("## 0.1.0", seccion)
            self.assertLess(seccion.index("## 0.1.2"), seccion.index("## 0.1.1"))

    def test_sin_tags_incluye_todas(self):
        for version in ("0.1.0", "0.1.1", "0.1.2"):
            escribir_nota(self.raiz, version)
        codigo, texto = self.generar("0.1.2")
        self.assertEqual(codigo, 0)
        for seccion in texto.split("# Español"):
            self.assertIn("## 0.1.0 (2026-01-01)", seccion)
            self.assertIn("## 0.1.1 (2026-01-01)", seccion)
            self.assertIn("## 0.1.2 (2026-01-01)", seccion)

    def test_falta_la_nota_pedida(self):
        escribir_nota(self.raiz, "0.1.0")
        with contextlib.redirect_stderr(io.StringIO()):
            codigo, texto = self.generar("0.1.1")
        self.assertEqual(codigo, 1)
        self.assertIsNone(texto)


if __name__ == "__main__":
    unittest.main()
