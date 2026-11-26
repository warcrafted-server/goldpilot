#!/usr/bin/env python3
"""Genera docs/RELEASE_NOTES.md con todas las versiones desde el último tag publicado.

Uso: python tools/notas_release.py [versión] [--salida RUTA]
Sin versión se usa la de VERSION. Junta docs/notas/*.md de las versiones
posteriores al tag vA.B.C más alto anterior a la indicada, hasta ella, de la
más nueva a la más vieja, por idioma.
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOTAS = "docs/notas"
IDIOMAS = ("English", "Español")
TITULO = re.compile(r"# (\d+\.\d+\.\d+) \((\d{4}-\d{2}-\d{2})\)\s*$")
TAG = re.compile(r"v(\d+\.\d+\.\d+)\s*$")


def tupla(version):
    return tuple(int(parte) for parte in version.split("."))


def leer_nota(version):
    """Devuelve (fecha, {idioma: líneas}) de docs/notas/<versión>.md."""
    ruta = os.path.join(ROOT, NOTAS, version + ".md")
    if not os.path.isfile(ruta):
        raise ValueError(f"falta {NOTAS}/{version}.md")
    with open(ruta, encoding="utf-8") as f:
        lineas = f.read().splitlines()
    titulo = TITULO.match(lineas[0]) if lineas else None
    if not titulo or titulo.group(1) != version:
        raise ValueError(f"{NOTAS}/{version}.md no empieza por «# {version} (AAAA-MM-DD)»")
    secciones = {}
    actual = None
    for linea in lineas[1:]:
        if linea.startswith("## "):
            actual = linea[3:].strip()
            secciones[actual] = []
        elif actual is not None:
            secciones[actual].append(linea)
    for idioma in IDIOMAS:
        if idioma not in secciones:
            raise ValueError(f"{NOTAS}/{version}.md no tiene la sección «## {idioma}»")
        while secciones[idioma] and not secciones[idioma][0].strip():
            secciones[idioma].pop(0)
        while secciones[idioma] and not secciones[idioma][-1].strip():
            secciones[idioma].pop()
    return titulo.group(2), secciones


def version_anterior(version):
    """Tag vA.B.C más alto estrictamente menor que la versión, o None."""
    salida = subprocess.run(["git", "tag", "--list", "v*"], cwd=ROOT,
                            capture_output=True, text=True)
    if salida.returncode != 0:
        raise ValueError("no se pudieron leer los tags de git")
    anteriores = []
    for linea in salida.stdout.splitlines():
        encontrado = TAG.match(linea)
        if encontrado:
            anteriores.append(encontrado.group(1))
    anteriores = [v for v in anteriores if tupla(v) < tupla(version)]
    return max(anteriores, key=tupla) if anteriores else None


def versiones_incluidas(version):
    anterior = version_anterior(version)
    limite = tupla(anterior) if anterior else None
    incluidas = []
    for nombre in os.listdir(os.path.join(ROOT, NOTAS)):
        if not nombre.endswith(".md"):
            continue
        candidata = nombre[:-3]
        if not re.fullmatch(r"\d+\.\d+\.\d+", candidata):
            continue
        if tupla(candidata) > tupla(version):
            continue
        if limite is not None and tupla(candidata) <= limite:
            continue
        incluidas.append(candidata)
    return sorted(incluidas, key=tupla, reverse=True)


def render(versiones):
    bloques = []
    for idioma in IDIOMAS:
        bloques.append(f"# {idioma}")
        for version, fecha, secciones in versiones:
            bloques.append(f"## {version} ({fecha})\n\n" + "\n".join(secciones[idioma]))
    return "\n\n".join(bloques) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Genera las notas de versión para CurseForge.")
    parser.add_argument("version", nargs="?", help="versión a publicar (por defecto, la de VERSION)")
    parser.add_argument("--salida", default=os.path.join(ROOT, "docs", "RELEASE_NOTES.md"),
                        help="archivo de salida (por defecto, docs/RELEASE_NOTES.md)")
    args = parser.parse_args(argv)
    version = args.version
    if version is None:
        with open(os.path.join(ROOT, "VERSION"), encoding="utf-8") as f:
            version = f.read().strip()
    try:
        leer_nota(version)
        versiones = []
        for incluida in versiones_incluidas(version):
            fecha, secciones = leer_nota(incluida)
            versiones.append((incluida, fecha, secciones))
    except (ValueError, OSError) as error:
        print("ERROR: " + str(error), file=sys.stderr)
        return 1
    salida = args.salida if os.path.isabs(args.salida) else os.path.join(os.getcwd(), args.salida)
    with open(salida, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(versiones))
    return 0


if __name__ == "__main__":
    sys.exit(main())
