#!/usr/bin/env python3
r"""Genera GoldPilotDev.toc en la raíz del repo a partir de GoldPilot/GoldPilot.toc.

La carpeta del juego `AddOns\GoldPilotDev` es un junction a la raíz del repo; este TOC
carga los archivos de `GoldPilot\` para convivir con la copia publicada (`AddOns\GoldPilot`).
Solo una de las dos debe estar activa a la vez: comparten SavedVariables.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "GoldPilot", "GoldPilot.toc")
LOCAL = os.path.join(ROOT, "GoldPilot", "Data", "Local", "NodeSpots.lua")


def main():
    out = []
    with open(SRC, encoding="utf-8") as f:
        for line in f.read().splitlines():
            if line.startswith("## Title:"):
                line = "## Title: GoldPilot Forever (dev)"
            elif line.startswith("## Version:"):
                line = line.rstrip() + "-dev"
            elif line.strip() and not line.startswith("#"):
                source = line.strip().replace("\\", "/")
                out.append("GoldPilot\\" + line.strip().replace("/", "\\"))
                if source == "Data/Generated/NodeSeeds.lua" and os.path.exists(LOCAL):
                    out.append("GoldPilot\\Data\\Local\\NodeSpots.lua")
                continue
            out.append(line)
    with open(os.path.join(ROOT, "GoldPilotDev.toc"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("Generado GoldPilotDev.toc")


if __name__ == "__main__":
    main()
