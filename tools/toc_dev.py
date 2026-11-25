#!/usr/bin/env python3
r"""Genera GoldPilotDev.toc en la raíz del repo a partir de GoldPilot.toc.

La carpeta del juego `AddOns\GoldPilotDev` es un junction a la raíz del repo; este TOC
carga los mismos archivos para convivir con la copia publicada (`AddOns\GoldPilot`).
Solo una de las dos debe estar activa a la vez: comparten SavedVariables.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "GoldPilot.toc")
# Datos de wowdata solo para pruebas locales (no se publican); se cargan antes que Store/.
LOCAL = ("NodeSeeds.lua", "NodeSpots.lua")


def main():
    out = []
    inserted = False
    with open(SRC, encoding="utf-8") as f:
        for line in f.read().splitlines():
            if line.startswith("## Title:"):
                line = "## Title: GoldPilot Forever (dev)"
            elif line.startswith("## Version:"):
                line = line.rstrip() + "-dev"
            elif line.startswith("## IconTexture:"):
                line = line.replace("AddOns/GoldPilot/", "AddOns/GoldPilotDev/")
            elif line.strip() and not line.startswith("#"):
                source = line.strip().replace("\\", "/")
                if source.startswith("Store/") and not inserted:
                    inserted = True
                    for name in LOCAL:
                        if os.path.exists(os.path.join(ROOT, "Data", "Local", name)):
                            out.append("Data\\Local\\" + name)
                out.append(source.replace("/", "\\"))
                continue
            out.append(line)
    with open(os.path.join(ROOT, "GoldPilotDev.toc"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("Generado GoldPilotDev.toc")


if __name__ == "__main__":
    main()
