"""Utilitários compartilhados do gerador de pixel art."""
import math
import os
import random

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
KENNEY = os.path.join(ROOT, "assets", "kenney_tiny_town", "Tilemap", "tilemap_packed.png")
OUT = os.path.join(ROOT, "assets", "gen")
T = 16


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# paleta base = cores extraídas dos tiles da Kenney + tons extras no mesmo espírito
C = {k: hexc(v) for k, v in {
    "out": "3f2631", "out2": "262b44", "black": "181425",
    "grass": "84c669", "grass_l": "8bd87d", "grass_d": "65a556",
    "leaf_hh": "a8e87a", "leaf_h": "84c669", "leaf": "479f4a", "leaf_d": "2f7a45", "leaf_dd": "265c42",
    "dirt": "eaa56c", "dirt_d": "bd6c4a", "wood": "bd6c4a", "wood_d": "763b36", "wood_l": "eaa56c",
    "stone_l": "c0cbdc", "stone": "8b9bb4", "stone_d": "5a6988", "stone_dd": "3a4466",
    "red": "c34b35", "red_l": "f28462", "red_d": "8a2a2a", "peach": "fcbc8f",
    "orange": "e38628", "yellow": "fdbe53", "yellow_l": "fee761", "white": "ffffff", "cream": "ead4aa",
    "water_dd": "124e89", "water_d": "1b6fb0", "water": "0099db", "water_l": "2ce8f5",
    "purple_d": "3e2146", "purple": "68386c", "purple_l": "b55088", "pink": "f6757a",
    "gold_d": "a8641c", "gold": "e8b43c", "gold_l": "fee761",
    "skin": "f0c29a", "skin_d": "c98d6a", "skin2": "c28569", "skin2_d": "8f5a44",
    "teal": "2b8a8c", "teal_d": "1d5c63", "teal_l": "4fb8a8",
    "blue": "3b6ec4", "blue_d": "27468a", "blue_l": "6aa3e8",
    "brown": "8a5234", "brown_d": "5c3522", "brown_l": "b87a4f",
    "grey": "9aa0a8", "grey_d": "5e636b", "grey_l": "d4d8de",
    "flame": "ff9b30", "flame_l": "ffe36b", "flame_d": "e0461e",
}.items()}

_sheet = None


def ktile(i):
    global _sheet
    if _sheet is None:
        _sheet = Image.open(KENNEY).convert("RGBA")
    x, y = i % 12, i // 12
    return _sheet.crop((x * T, y * T, x * T + T, y * T + T))


def new(w, h, fill=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), fill)


def save(img, name):
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    return path


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height and c is not None:
        img.putpixel((int(x), int(y)), c)


def get(img, x, y):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((int(x), int(y)))
    return (0, 0, 0, 0)


def rect(img, x, y, w, h, c):
    for yy in range(int(y), int(y + h)):
        for xx in range(int(x), int(x + w)):
            put(img, xx, yy, c)


def hline(img, x0, x1, y, c):
    for x in range(int(x0), int(x1) + 1):
        put(img, x, y, c)


def vline(img, x, y0, y1, c):
    for y in range(int(y0), int(y1) + 1):
        put(img, x, y, c)


def disc(img, cx, cy, r, c):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                put(img, x, y, c)


def ellipse(img, cx, cy, rx, ry, c):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                put(img, x, y, c)


def paste(dst, src, x, y):
    dst.alpha_composite(src, (int(x), int(y)))


def outline(img, c=None, diag=False):
    """Contorna pixels opacos com a cor de contorno (só em vizinhos transparentes)."""
    c = c or C["out"]
    src = img.copy()
    w, h = img.size
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diag:
        nb += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] != 0:
                continue
            for dx, dy in nb:
                if get(src, x + dx, y + dy)[3] > 0:
                    img.putpixel((x, y), c)
                    break
    return img


def from_ascii(rows, pal, w=None):
    w = w or max(len(r) for r in rows)
    img = new(w, len(rows))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal and pal[ch] is not None:
                img.putpixel((x, y), pal[ch])
    return img


def hstrip(frames):
    w = sum(f.width for f in frames)
    h = max(f.height for f in frames)
    out = new(w, h)
    x = 0
    for f in frames:
        out.alpha_composite(f, (x, 0))
        x += f.width
    return out


def grid(rows):
    """rows: lista de listas de frames (mesmo tamanho) -> spritesheet."""
    fw, fh = rows[0][0].size
    out = new(fw * max(len(r) for r in rows), fh * len(rows))
    for j, r in enumerate(rows):
        for i, f in enumerate(r):
            out.alpha_composite(f, (i * fw, j * fh))
    return out


def recolor(img, mapping):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[:3] in mapping:
                px[x, y] = mapping[p[:3]] + (p[3],)
    return out


def rgb(name):
    return C[name][:3]


def shift_rows(img, y0, y1, dx):
    """Desloca horizontalmente as linhas [y0, y1) em dx pixels (usado no balanço das árvores)."""
    out = img.copy()
    rect(out, 0, y0, img.width, y1 - y0, (0, 0, 0, 0))
    band = img.crop((0, y0, img.width, y1))
    out.alpha_composite(band, (dx, y0)) if dx >= 0 else out.alpha_composite(band.crop((-dx, 0, band.width, band.height)), (0, y0))
    return out


def rng(seed):
    return random.Random(seed)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(3)) + (255,)


__all__ = [n for n in dir() if not n.startswith("_")] + ["math"]
