#!/usr/bin/env python3
"""Genera docs/img/logo.png (512x512, proyecto de CurseForge): moneda de oro con rosa de los vientos.

Herramienta de desarrollo: necesita Pillow (`pip install pillow`); no forma parte del addon.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = 512
S = 4                      # sobremuestreo para bordes suaves
N = OUT * S
C = N / 2


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def radial(size, stops):
    """Degradado radial centrado; stops = [(radio 0..1, color RGBA), ...]."""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    c = size / 2
    for y in range(size):
        for x in range(size):
            r = min(1.0, math.hypot(x - c + 0.5, y - c + 0.5) / c)
            for i in range(len(stops) - 1):
                if stops[i][0] <= r <= stops[i + 1][0]:
                    t = (r - stops[i][0]) / max(1e-9, stops[i + 1][0] - stops[i][0])
                    px[x, y] = lerp(stops[i][1], stops[i + 1][1], t)
                    break
    return img


def disc_mask(radius):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).ellipse((C - radius, C - radius, C + radius, C + radius), fill=255)
    return m


def linear(size, top, bottom):
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        d.line((0, y, size, y), fill=lerp(top, bottom, y / size))
    return img


def star(points, outer, inner, rotation=-90):
    out = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rotation + i * 180 / points)
        out.append((C + r * math.cos(a), C + r * math.sin(a)))
    return out


def facets(draw, pts, light, dark):
    """Cada punta de la estrella con una mitad clara y otra oscura (efecto facetado)."""
    n = len(pts)
    for i in range(0, n, 2):
        tip, left, right = pts[i], pts[i - 1], pts[(i + 1) % n]
        draw.polygon([tip, left, (C, C)], fill=light)
        draw.polygon([tip, right, (C, C)], fill=dark)


def main():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    # Sombra suave bajo la moneda
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((C - 0.47 * N, C - 0.455 * N + 0.02 * N, C + 0.47 * N, C + 0.485 * N), fill=(0, 0, 0, 120))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(0.018 * N)))

    # Canto y cara de la moneda (oro con degradado)
    R = 0.46 * N
    gold = linear(N, (255, 232, 140, 255), (176, 112, 20, 255))
    img.paste(gold, (0, 0), disc_mask(R))
    d = ImageDraw.Draw(img)
    # Cordoncillo del canto
    for i in range(72):
        a = math.radians(i * 5)
        r1, r2 = R * 0.955, R * 0.995
        d.line((C + r1 * math.cos(a), C + r1 * math.sin(a), C + r2 * math.cos(a), C + r2 * math.sin(a)),
               fill=(140, 86, 14, 255), width=max(2, S))
    # Aro hundido
    ring = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse((C - R * 0.93, C - R * 0.93, C + R * 0.93, C + R * 0.93), outline=(120, 74, 10, 255), width=int(0.012 * N))
    img.alpha_composite(ring)
    inner_gold = linear(N, (200, 132, 28, 255), (255, 226, 130, 255))
    img.paste(inner_gold, (0, 0), disc_mask(R * 0.915))

    # Disco azul noche con brillo
    r_blue = R * 0.80
    blue = radial(N, [(0.0, (46, 104, 196, 255)), (0.55, (24, 62, 138, 255)), (1.0, (10, 26, 70, 255))])
    img.paste(blue, (0, 0), disc_mask(r_blue))
    rim = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(rim).ellipse((C - r_blue, C - r_blue, C + r_blue, C + r_blue), outline=(255, 214, 110, 255), width=int(0.01 * N))
    img.alpha_composite(rim)

    # Marcas de la brújula
    d = ImageDraw.Draw(img)
    for i in range(32):
        a = math.radians(i * 360 / 32 - 90)
        long = i % 4 == 0
        r1, r2 = r_blue * (0.86 if long else 0.91), r_blue * 0.97
        d.line((C + r1 * math.cos(a), C + r1 * math.sin(a), C + r2 * math.cos(a), C + r2 * math.sin(a)),
               fill=(255, 214, 110, 255) if long else (150, 176, 230, 255), width=int((0.008 if long else 0.004) * N))

    # Rosa de los vientos: estrella secundaria (diagonales) y principal (N, E, S, O)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    facets(ld, star(4, r_blue * 0.66, r_blue * 0.20, rotation=-45), (120, 150, 215, 255), (70, 96, 160, 255))
    facets(ld, star(4, r_blue * 0.84, r_blue * 0.17, rotation=-90), (255, 236, 150, 255), (205, 140, 30, 255))
    img.alpha_composite(layer)

    # Núcleo: pequeña moneda central
    d = ImageDraw.Draw(img)
    cr = r_blue * 0.13
    core = linear(N, (255, 240, 170, 255), (190, 120, 24, 255))
    img.paste(core, (0, 0), disc_mask(cr))
    d.ellipse((C - cr, C - cr, C + cr, C + cr), outline=(110, 66, 8, 255), width=int(0.006 * N))

    # Brillo especular en el canto superior izquierdo
    gloss = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).pieslice((C - R * 0.99, C - R * 0.99, C + R * 0.99, C + R * 0.99), 200, 265, fill=(255, 255, 255, 60))
    gloss = gloss.filter(ImageFilter.GaussianBlur(0.006 * N))
    mask = disc_mask(R * 0.985)
    clipped = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    clipped.paste(gloss, (0, 0), mask)
    img.alpha_composite(clipped)

    target = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "img", "logo.png")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    img.resize((OUT, OUT), Image.LANCZOS).save(target)
    print("Generado docs/img/logo.png")


if __name__ == "__main__":
    main()
