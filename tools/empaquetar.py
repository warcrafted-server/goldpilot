#!/usr/bin/env python3
"""Empaqueta GoldPilot para instalarlo en WoW (dist/GoldPilot-X.Y.Z.zip con la carpeta GoldPilot/)."""
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL = os.path.join(ROOT, "Data", "Local")
# Lo mismo que deja el empaquetador de CurseForge según .pkgmeta.
ADDON_DIRS = ("Core", "Data", "Engine", "Locales", "Media", "State", "Store", "UI")
ADDON_FILES = ("GoldPilot.toc", "LICENSE", "README.md", "CHANGELOG.md")


def main():
    version = open(os.path.join(ROOT, "VERSION"), encoding="utf-8").read().strip()
    toc = open(os.path.join(ROOT, "GoldPilot.toc"), encoding="utf-8").read()
    if re.search(r"^## Version:\s*(.+)$", toc, re.M).group(1).strip() != version:
        print("VERSION no coincide con el TOC", file=sys.stderr)
        return 1
    dist = os.path.join(ROOT, "dist")
    os.makedirs(dist, exist_ok=True)
    target = os.path.join(dist, "GoldPilot-" + version + ".zip")
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in ADDON_FILES:
            archive.write(os.path.join(ROOT, name), "GoldPilot/" + name)
        for top in ADDON_DIRS:
            for base, dirs, files in os.walk(os.path.join(ROOT, top)):
                dirs[:] = sorted(d for d in dirs if os.path.join(base, d) != LOCAL)
                for name in sorted(files):
                    path = os.path.join(base, name)
                    archive.write(path, "GoldPilot/" + os.path.relpath(path, ROOT).replace("\\", "/"))
    print("Creado " + os.path.relpath(target, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
