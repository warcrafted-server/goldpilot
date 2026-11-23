#!/usr/bin/env python3
"""Genera el icono TGA de GoldPilot sin dependencias externas."""
import math
import os
import struct


SIZE = 64
PIXELS = bytearray()


def blend(x, y):
    dx, dy = x - 31.5, y - 31.5
    radius = math.hypot(dx, dy)
    color = (0, 0, 0, 0)
    if radius <= 29:
        color = (28, 116, 205, 255) if radius > 26 else (15, 74, 153, 255)
        if radius <= 22:
            color = (12, 49, 106, 255)
        # A simple compass arrow pointing northeast.
        ax, ay = (dx + dy) / math.sqrt(2), (dy - dx) / math.sqrt(2)
        if 2 <= ax <= 22 and abs(ay) <= max(1, (22 - ax) * 0.42):
            color = (255, 226, 102, 255)
        if 10 <= ax <= 22 and abs(ay) <= (22 - ax) * 0.9:
            color = (255, 246, 190, 255)
        if radius > 24:
            color = (255, 205, 62, 255)
    return color


for y in range(SIZE):
    for x in range(SIZE):
        red, green, blue, alpha = blend(x, y)
        PIXELS.extend((blue, green, red, alpha))

header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
target = os.path.join(os.path.dirname(__file__), "..", "GoldPilot", "Media", "Icon.tga")
os.makedirs(os.path.dirname(target), exist_ok=True)
with open(target, "wb") as icon:
    icon.write(header)
    icon.write(PIXELS)
