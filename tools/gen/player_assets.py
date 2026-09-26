"""Estagiário: personagem do Kenney Tiny Dungeon (CC0) dividido em camadas (corpo, rosto, cabelo, capa) em assets/gen/player/."""
from common import *

OUT_LINE = C["out"]


def _ellipse(img, cx, cy, rx, ry, c):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                put(img, x, y, c)


DUNGEON = os.path.join(ROOT, "assets", "kenney_tiny_dungeon", "Tilemap", "tilemap_packed.png")


def _tile():
    """Personagem base do Kenney Tiny Dungeon (CC0): garoto de túnica cinza (col 1, linha 7)."""
    return Image.open(DUNGEON).convert("RGBA").crop((16, 112, 32, 128))


def body():
    """Corpo (linhas 10-15 do tile): 16x6."""
    return _tile().crop((0, 10, 16, 16))


def hair():
    """Topete/contorno (linhas 1-4): 16x4, pivô na base."""
    return _tile().crop((0, 1, 16, 5))


def head_frames():
    """Rosto (linhas 5-9) em 4 frames 16x5: neutro, olhos cerrados, sorriso, sussurro (mão na boca)."""
    face = _tile().crop((0, 5, 16, 10))
    dark = C["out2"]
    skin = (247, 194, 130, 255)
    skin_d = (225, 154, 101, 255)
    red = (118, 59, 54, 255)
    outline = (63, 38, 49, 255)
    sheet = new(64, 5)
    for f in range(4):
        h = face.copy()
        if f == 1:  # olhos cerrados: só a linha de baixo + sobrancelha baixa
            for x in (6, 10):
                put(h, x, 2, skin)
            put(h, 5, 1, red)
            put(h, 11, 1, red)
        elif f == 2:  # sorriso
            for x in (7, 8, 9):
                put(h, x, 4, red)
            put(h, 6, 3, red)
            put(h, 10, 3, red)
            put(h, 5, 3, skin_d)
            put(h, 11, 3, skin_d)
        elif f == 3:  # mão na boca
            rect(h, 8, 3, 5, 2, outline)
            rect(h, 9, 3, 3, 2, skin)
            put(h, 10, 3, skin_d)
            put(h, 12, 3, outline)
        sheet.paste(h, (f * 16, 0))
    return sheet


def cloak_tail():
    """Capa que pende atrás do corpo: 14x9 (pivô no topo), paleta do Kenney."""
    img = new(14, 9)
    outline, dark, mid, light = (63, 38, 49, 255), (118, 59, 54, 255), (189, 108, 74, 255), (225, 154, 101, 255)
    for y in range(9):
        w = 12 + (y >= 6)
        x0 = (14 - w) // 2
        for x in range(x0, x0 + w):
            put(img, x, y, mid if y < 7 else dark)
        put(img, x0, y, outline)
        put(img, x0 + w - 1, y, outline)
    hline(img, 1, 12, 0, outline)
    hline(img, 2, 11, 1, light)
    for x in range(1, 13, 3):  # barra irregular
        put(img, x, 8, outline)
        put(img, x + 1, 8, dark)
    return img


def sweat():
    img = new(3, 5)
    put(img, 1, 0, C["water_l"])
    rect(img, 0, 1, 3, 2, C["water_l"])
    put(img, 1, 3, C["water"])
    put(img, 1, 4, C["water_d"])
    put(img, 0, 2, C["white"])
    return img


def emotes():
    """3 frames 16x14: ??? / ! / estrela de alegria."""
    sheet = new(48, 14)
    q = new(16, 14)
    _bubble(q)
    for i, x0 in enumerate((2, 6, 10)):
        put(q, x0 + 1, 2, C["out2"])
        hline(q, x0, x0 + 2, 3, C["out2"])
        put(q, x0 + 2, 4, C["out2"])
        put(q, x0 + 1, 5, C["out2"])
        put(q, x0 + 1, 7, C["out2"])
    sheet.paste(q, (0, 0))
    e = new(16, 14)
    _bubble(e, C["red_l"])
    rect(e, 7, 2, 2, 5, C["white"])
    rect(e, 7, 8, 2, 2, C["white"])
    sheet.paste(e, (16, 0))
    j = new(16, 14)
    _bubble(j, C["yellow_l"])
    for dx, dy in [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1), (-2, 0), (2, 0), (0, -2), (0, 2)]:
        put(j, 8 + dx, 6 + dy, C["gold_d"])
    sheet.paste(j, (32, 0))
    return sheet


def _bubble(img, fill=None):
    fill = fill or C["white"]
    rect(img, 1, 0, 14, 10, OUT_LINE)
    rect(img, 2, 1, 12, 8, fill)
    put(img, 7, 10, OUT_LINE)
    put(img, 8, 10, OUT_LINE)
    put(img, 8, 11, OUT_LINE)
    put(img, 8, 10, fill)


def generate():
    save(body(), "player/body.png")
    save(cloak_tail(), "player/cloak_tail.png")
    save(head_frames(), "player/head.png")
    save(hair(), "player/hair.png")
    save(sweat(), "player/sweat.png")
    save(emotes(), "player/emotes.png")
    return {}


if __name__ == "__main__":
    generate()
