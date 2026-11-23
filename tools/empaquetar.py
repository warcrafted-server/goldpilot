#!/usr/bin/env python3
"""Empaqueta GoldPilot para instalarlo en WoW."""
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "GoldPilot")

def main():
    version = open(os.path.join(ROOT, "VERSION"), encoding="utf-8").read().strip()
    toc = open(os.path.join(ADDON, "GoldPilot.toc"), encoding="utf-8").read()
    if re.search(r"^## Version:\s*(.+)$", toc, re.M).group(1).strip() != version:
        print("VERSION no coincide con el TOC", file=sys.stderr)
        return 1
    dist = os.path.join(ROOT, "dist")
    os.makedirs(dist, exist_ok=True)
    target = os.path.join(dist, "GoldPilot-" + version + ".zip")
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for base, dirs, files in os.walk(ADDON):
            dirs.sort()
            for name in sorted(files):
                path = os.path.join(base, name)
                archive.write(path, os.path.relpath(path, ROOT).replace("\\", "/"))
    print("Creado " + os.path.relpath(target, ROOT))
    return 0

if __name__ == "__main__":
    sys.exit(main())
