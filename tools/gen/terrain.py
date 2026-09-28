"""Chão do mapa (640x480 nativo) + lago animado (margem estática, água em tons de cinza tingida no Godot, brilhos)."""
from common import C, T, new, put, get, rect, hline, vline, ktile, save, recolor, rgb, rng, math, ellipse, disc, outline, hstrip
import layout as L

NW, NH = 640, 480


def _grass_tiles():
    base = [ktile(0), ktile(1), ktile(2)]
    dark = {rgb("grass"): (116, 184, 96), rgb("grass_l"): C["grass"][:3], rgb("grass_d"): (84, 150, 76)}
    return base, [recolor(t, dark) for t in base]


def _inner_corner_map():
    """Descobre em qual canto cada tile 39..42 tem o 'dente' de grama."""
    out = {}
    for i in (39, 40, 41, 42):
        t = ktile(i)
        best, bc = None, -1
        for name, (x0, y0) in {"nw": (0, 0), "ne": (8, 0), "sw": (0, 8), "se": (8, 8)}.items():
            n = sum(1 for y in range(y0, y0 + 8) for x in range(x0, x0 + 8) if t.getpixel((x, y))[:3] in (rgb("grass"), rgb("grass_d"), rgb("grass_l")))
            if n > bc:
                best, bc = name, n
        out[best] = i
    return out


def cobble_tile(seed):
    """Paralelepípedos grandes (8x8), vistos de cima — achatado, sem bisel 3D
    (o bisel forte fazia o chão parecer parede; agora é só uma linha fina de
    argamassa entre as lajotas, com leve variação de tom)."""
    t = new(T, T, C["stone"])
    r = rng(seed)
    for (sx, sy) in ((0, 0), (8, 0), (0, 8), (8, 8)):
        base = C["stone_l"] if r.random() < 0.55 else C["stone"]
        rect(t, sx, sy, 8, 8, base)
        # linha de argamassa fina (só uma, sem realce duplo) embaixo e à direita
        hline(t, sx, sx + 7, sy + 7, C["stone_d"])
        vline(t, sx + 7, sy, sy + 7, C["stone_d"])
        k = r.random()
        if k < 0.16:
            put(t, sx + r.randrange(2, 6), sy + r.randrange(2, 6), C["stone_d"])
        elif k < 0.24:
            put(t, sx + 6, sy + 6, C["grass_d"])
            put(t, sx + 7, sy + 6, C["grass"])
    return t


def _forest_dark(x, y):
    # ruído multi-frequência para bordas irregulares (nada de linhas retas)
    n = (9 * math.sin(x * 0.11) + 8 * math.sin(y * 0.13 + x * 0.04)
         + 4 * math.sin(x * 0.37 + y * 0.29) + 3 * math.sin(y * 0.47 - x * 0.19)
         + 2 * math.sin((x + y) * 0.53))
    # cinturão de floresta cobrindo toda a moldura do mapa
    return (x < 90 + n or x > 550 + n or y < 60 + n or y > 400 + n
            # blocos internos originais mantidos para a região do castelo/vila
            or (x < 235 + n and y < 170 + n) or (x > 420 + n and y < 170 - n))


def ground():
    img = new(NW, NH)
    g, gd = _grass_tiles()
    inner = _inner_corner_map()
    r = rng(99)
    road = L.ROAD | L.PLAZA
    for rr in range(L.ROWS):
        for c in range(L.COLS):
            p = r.random()
            t = g[1] if p < 0.3 else g[0]
            img.alpha_composite(t, (c * T, rr * T))
    dark_map = {rgb("grass"): (116, 184, 96, 255), rgb("grass_l"): C["grass"], rgb("grass_d"): (84, 150, 76, 255)}
    px0 = img.load()
    for y in range(NH):
        for x in range(NW):
            if _forest_dark(x, y) and px0[x, y][:3] in dark_map:
                px0[x, y] = dark_map[px0[x, y][:3]]
    # tiles de terra com autotile
    for (c, rr) in L.ROAD - L.PLAZA:
        n, s, e, w = (c, rr - 1) in road, (c, rr + 1) in road, (c + 1, rr) in road, (c - 1, rr) in road
        n = n or rr == 0
        s = s or rr == L.ROWS - 1
        w = w or c == 0
        e = e or c == L.COLS - 1
        if not n and not w:
            i = 12
        elif not n and not e:
            i = 14
        elif not s and not w:
            i = 36
        elif not s and not e:
            i = 38
        elif not n:
            i = 13
        elif not s:
            i = 37
        elif not w:
            i = 24
        elif not e:
            i = 26
        else:
            i = 25
            for key, (dx, dy) in {"nw": (-1, -1), "ne": (1, -1), "sw": (-1, 1), "se": (1, 1)}.items():
                cx, cy = c + dx, rr + dy
                if 0 <= cx < L.COLS and 0 <= cy < L.ROWS and (cx, cy) not in road:
                    i = inner[key]
        img.alpha_composite(ktile(i), (c * T, rr * T))
    # pedrinhas e marcas de roda na terra
    for (c, rr) in L.ROAD - L.PLAZA:
        if r.random() < 0.25:
            x, y = c * T + r.randrange(3, 13), rr * T + r.randrange(3, 13)
            put(img, x, y, C["dirt_d"])
            put(img, x + 1, y, C["wood_l"])
    # praça de paralelepípedos
    for (c, rr) in L.PLAZA:
        img.paste(cobble_tile(c * 31 + rr * 7), (c * T, rr * T))
    for (c, rr) in L.PLAZA:
        x0, y0 = c * T, rr * T
        if (c, rr - 1) not in road:
            hline(img, x0, x0 + T - 1, y0, C["out"])
            hline(img, x0, x0 + T - 1, y0 + 1, C["stone_l"])
        if (c, rr + 1) not in road:
            hline(img, x0, x0 + T - 1, y0 + T - 1, C["out"])
        if (c - 1, rr) not in road:
            vline(img, x0, y0, y0 + T - 1, C["out"])
        if (c + 1, rr) not in road:
            vline(img, x0 + T - 1, y0, y0 + T - 1, C["out"])
    # passagens de pedra até as portas
    for (c, rr) in L.STEPS:
        img.alpha_composite(ktile(43), (c * T, rr * T))
    # terra arada da fazenda
    fx, fy, fw, fh = [v // 2 for v in L.FARM]
    rect(img, fx - 1, fy - 1, fw + 2, fh + 2, C["wood_d"])
    rect(img, fx, fy, fw, fh, C["dirt_d"])
    # detalhes extras na grama (pontinhos de variação + pequenas pedrinhas espalhadas)
    px = img.load()
    for _ in range(7200):
        x, y = r.randrange(NW), r.randrange(NH)
        if px[x, y][:3] == rgb("grass"):
            px[x, y] = C["grass_d"] if r.random() < 0.6 else C["grass_l"]
    # pedrinhas minúsculas (2 px) espalhadas por toda a grama — dá textura nas bordas
    for _ in range(520):
        x, y = r.randrange(2, NW - 2), r.randrange(2, NH - 2)
        if px[x, y][:3] not in (rgb("grass"), rgb("grass_l"), rgb("grass_d")):
            continue
        put(img, x, y, C["stone"])
        put(img, x + 1, y, C["stone_l"])
    # touceiras de grama alta em pixel único, para quebrar áreas monótonas
    for _ in range(900):
        x, y = r.randrange(1, NW - 1), r.randrange(1, NH - 1)
        if px[x, y][:3] in (rgb("grass"), rgb("grass_l"), rgb("grass_d")):
            put(img, x, y, C["leaf_d"])
            if r.random() < 0.5:
                put(img, x + 1, y, C["leaf"])
    return img


# ------------------------------------------------------------------ lago
def lake_shape():
    cx, cy, rx, ry = [v / 2 for v in L.LAKE]
    return cx, cy, rx, ry


def _lake_r(a):
    return 1.0 + 0.045 * math.sin(3 * a + 0.7) + 0.03 * math.sin(7 * a + 2.1) + 0.02 * math.sin(11 * a)


def _lake_dist(x, y, cx, cy, rx, ry):
    """<1 dentro da água; normalizado pelo contorno irregular."""
    dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
    a = math.atan2(dy, dx)
    return math.hypot(dx, dy) / _lake_r(a)


def lake_layers():
    cx, cy, rx, ry = lake_shape()
    pad = 10
    x0, y0 = int(cx - rx - pad), int(cy - ry - pad)
    w, h = int(rx * 2 + pad * 2), int(ry * 2 + pad * 2)
    lcx, lcy = cx - x0, cy - y0
    shore = new(w, h)
    water_mask = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            d = _lake_dist(x, y, lcx, lcy, rx, ry)
            if d < 1.0:
                water_mask[y][x] = True
            elif d < 1.0 + 3.5 / ry * 1.0 + 0.02:
                put(shore, x, y, C["dirt"] if d > 1.0 + 1.2 / ry else C["dirt_d"])
    # contorno externo da margem e pedrinhas
    outline(shore, C["grass_d"])
    r = rng(5)
    for _ in range(40):
        a = r.uniform(0, math.tau)
        k = 1.0 + r.uniform(0.01, 0.035)
        x = int(lcx + math.cos(a) * rx * _lake_r(a) * k)
        y = int(lcy + math.sin(a) * ry * _lake_r(a) * k)
        if get(shore, x, y)[3]:
            put(shore, x, y, C["stone"])
            put(shore, x + 1, y, C["stone_l"])

    def edge_dist(x, y):
        return 1.0 - _lake_dist(x, y, lcx, lcy, rx, ry)

    # água em tons de cinza (tingida pela cor da água no jogo)
    frames = []
    sparkle = []
    waves = [(r.uniform(0, w), r.uniform(0, h), r.choice((3, 4, 5, 6)), r.uniform(0.6, 1.4)) for _ in range(70)]
    glints = [(r.randrange(w), r.randrange(h), r.randrange(8)) for _ in range(26)]
    nf = 8
    for f in range(nf):
        img = new(w, h)
        sp = new(w, h)
        for y in range(h):
            for x in range(w):
                if not water_mask[y][x]:
                    continue
                e = edge_dist(x, y)
                if e < 0.025:
                    v = 150
                elif e < 0.09:
                    v = 222
                elif e < 0.45:
                    v = 200
                else:
                    v = 182
                img.putpixel((x, y), (v, v, v, 255))
        for (wx, wy, ln, spd) in waves:
            ox = (wx + f * spd * 2) % w
            yy = int(wy)
            phase = (f + int(wx)) % nf
            if phase in (0, 1, 2, 3, 4):
                for k in range(ln if phase not in (0, 4) else ln - 2):
                    xx = int(ox) + k
                    if 0 <= xx < w and 0 <= yy < h and water_mask[yy][xx] and edge_dist(xx, yy) > 0.06:
                        img.putpixel((xx, yy), (248, 248, 248, 255))
                        if 0 <= yy + 1 < h and water_mask[yy + 1][xx] and k > 0 and k < ln - 1:
                            img.putpixel((xx, yy + 1), (170, 170, 170, 255))
        # espuma na borda, "lambendo" a margem
        for y in range(h):
            for x in range(w):
                if water_mask[y][x]:
                    e = edge_dist(x, y)
                    if e < 0.04 and ((x // 3 + y + f) % 5 == 0):
                        sp.putpixel((x, y), (255, 255, 255, 170))
        for (gx, gy, ph) in glints:
            if water_mask[gy][gx] and edge_dist(gx, gy) > 0.1:
                k = (f + ph) % nf
                if k == 0:
                    put(sp, gx, gy, (255, 255, 255, 255))
                elif k == 1:
                    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                        put(sp, gx + dx, gy + dy, (255, 255, 255, 230))
                elif k == 2:
                    put(sp, gx, gy, (255, 255, 255, 160))
        frames.append(img)
        sparkle.append(sp)
    return (x0, y0), shore, hstrip(frames), hstrip(sparkle), nf


def build_all():
    meta = {}
    save(ground(), "terrain/ground.png")
    (x0, y0), shore, water, sparkle, nf = lake_layers()
    save(shore, "terrain/lake_shore.png")
    save(water, "terrain/lake_water.png")
    save(sparkle, "terrain/lake_sparkle.png")
    meta["terrain/lake"] = {"pos": [x0 * 2, y0 * 2], "hframes": nf, "fps": 5.0}
    return meta


if __name__ == "__main__":
    import os
    from PIL import Image
    build_all()
    d = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gen", "terrain")
    g = Image.open(os.path.join(d, "ground.png"))
    s = Image.open(os.path.join(d, "lake_shore.png"))
    wtr = Image.open(os.path.join(d, "lake_water.png"))
    sp = Image.open(os.path.join(d, "lake_sparkle.png"))
    (x0, y0), *_ = lake_layers()
    fw = s.width
    tinted = wtr.crop((0, 0, fw, s.height))
    px = tinted.load()
    for y in range(tinted.height):
        for x in range(tinted.width):
            p = px[x, y]
            if p[3]:
                v = p[0] / 255 * 1.25
                px[x, y] = (min(255, int(0.16 * v * 255)), min(255, int(0.42 * v * 255)), min(255, int(0.69 * v * 255)), 255)
    g.alpha_composite(s, (x0, y0))
    g.alpha_composite(tinted, (x0, y0))
    g.alpha_composite(sp.crop((0, 0, fw, s.height)), (x0, y0))
    g.resize((g.width * 2, g.height * 2), Image.NEAREST).save(os.path.join(os.path.dirname(__file__), "_preview_ground.png"))
    print("ok")
