#!/usr/bin/env python3
"""Comprobaciones antes de etiquetar una versión: VERSION, TOC, CHANGELOG, notas y pruebas.

Uso: python tools/comprobar_release.py
No crea tags ni sube nada; solo informa y devuelve 1 si algo falla.
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as f:
        return f.read()


def main():
    errors = []
    version = read("VERSION").strip()
    toc = re.search(r"^## Version:\s*(.+)$", read("GoldPilot.toc"), re.M).group(1).strip()
    if toc != version:
        errors.append(f"TOC ({toc}) distinto de VERSION ({version})")
    first = re.search(r"^## \[(\d+\.\d+\.\d+)\]", read("CHANGELOG.md"), re.M)
    if not first or first.group(1) != version:
        errors.append(f"la primera entrada del CHANGELOG ({first.group(1) if first else 'ninguna'}) no es {version}")
    nota = os.path.join(ROOT, "docs", "notas", version + ".md")
    if not os.path.isfile(nota):
        errors.append(f"falta docs/notas/{version}.md")
    else:
        texto = read("docs", "notas", version + ".md")
        for idioma in ("## English", "## Español"):
            if idioma not in texto:
                errors.append(f"docs/notas/{version}.md no tiene la sección {idioma}")
    with tempfile.TemporaryDirectory() as tmp:
        generadas = subprocess.run(
            [sys.executable, os.path.join(ROOT, "tools", "notas_release.py"), version,
             "--salida", os.path.join(tmp, "RELEASE_NOTES.md")],
            cwd=ROOT, capture_output=True, text=True)
        if generadas.returncode != 0:
            errors.append("falla la generación de las notas de versión: " + generadas.stderr.strip())
    if "X-Curse-Project-ID" not in read("GoldPilot.toc"):
        errors.append("falta ## X-Curse-Project-ID en el TOC (sin él CurseForge no recibe el paquete)")
    status = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    if status:
        errors.append("hay cambios sin confirmar en git")
    if subprocess.run([sys.executable, os.path.join(ROOT, "tests", "run.py")], cwd=ROOT).returncode != 0:
        errors.append("fallan las pruebas")
    for error in errors:
        print("ERROR: " + error, file=sys.stderr)
    if not errors:
        print(f"Todo listo para v{version}. El tag y el push los haces tú (o con tu aprobación): git tag v{version}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
