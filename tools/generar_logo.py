#!/usr/bin/env python3
"""Genera docs/img/logo.png (512x512, para el proyecto de CurseForge) sin dependencias externas."""
import math
import os
import struct
import zlib

SIZE = 512
SCALE = SIZE / 64
SAMPLES = 2


def colour(px, py):
    """Mismo diseño que tools/generar_icono.py, en coordenadas del icono de 64 px."""
    dx, dy = px - 31.5, py - 31.5
    radius = math.hypot(dx, dy)
    if radius > 29:
        return (0, 0, 0, 0)
    result = (28, 116, 205, 255) if radius > 26 else (15, 74, 153, 255)
    if radius <= 22:
        result = (12, 49, 106, 255)
    ax, ay = (dx + dy) / math.sqrt(2), (dy - dx) / math.sqrt(2)
    if 2 <= ax <= 22 and abs(ay) <= max(1, (22 - ax) * 0.42):
        result = (255, 226, 102, 255)
    if 10 <= ax <= 22 and abs(ay) <= (22 - ax) * 0.9:
        result = (255, 246, 190, 255)
    if radius > 24:
        result = (255, 205, 62, 255)
    return result


def pixel(x, y):
    total, count = [0, 0, 0, 0], SAMPLES * SAMPLES
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            r, g, b, a = colour((x + (sx + 0.5) / SAMPLES) / SCALE - 0.5, (y + (sy + 0.5) / SAMPLES) / SCALE - 0.5)
            total[0] += r * a; total[1] += g * a; total[2] += b * a; total[3] += a
    alpha = total[3] / count
    if total[3] == 0:
        return (0, 0, 0, 0)
    return (round(total[0] / total[3]), round(total[1] / total[3]), round(total[2] / total[3]), round(alpha))


def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def main():
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)
        for x in range(SIZE):
            rows.extend(pixel(x, y))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
    target = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "img", "logo.png")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "wb") as f:
        f.write(png)
    print("Generado docs/img/logo.png")


if __name__ == "__main__":
    main()
