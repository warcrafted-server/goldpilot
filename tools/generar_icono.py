#!/usr/bin/env python3
"""Genera Media/Icon.tga (64x64) a partir de docs/img/logo.png.

Herramienta de desarrollo: necesita Pillow. Ejecuta antes generar_logo.py si cambia el logo.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "docs", "img", "logo.png")
TARGET = os.path.join(ROOT, "Media", "Icon.tga")

image = Image.open(SOURCE).convert("RGBA").resize((64, 64), Image.LANCZOS)
os.makedirs(os.path.dirname(TARGET), exist_ok=True)
image.save(TARGET, format="TGA")
