"""Construções: casas (tiles Kenney + detalhes), padaria, ferraria, templo e castelo."""
from common import (C, T, new, put, get, rect, hline, vline, disc, ellipse, ktile, save, outline, rng, hstrip,
                    from_ascii, recolor, rgb, math)
import layout as L

ROOF = {"grey": ((48, 49, 50), (60, 61, 62), 63), "red": ((52, 53, 54), (64, 65, 66), 67)}
WALL = {"wood": {"win": 84, "plain": 73, "door": 86}, "stone": {"win": 88, "plain": 77, "door": 90}}


def _fill_holes(img, c):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3] == 0:
                px[x, y] = c


def chimney(img, x, y, stone=False):
    body = C["stone"] if stone else C["red"]
    dark = C["stone_d"] if stone else C["red_d"]
    rect(img, x, y, 6, 9, body)
    for yy in range(y + 2, y + 9, 3):
        hline(img, x, x + 5, yy, dark)
    rect(img, x - 1, y - 2, 8, 3, C["stone_l"])
    hline(img, x - 1, x + 6, y, C["stone"])
    rect(img, x + 1, y - 2, 4, 1, C["out"])
    for yy in range(y - 3, y + 10):
        put(img, x - 2, yy, C["out"]) if y - 2 <= yy < y + 1 else None
    vline(img, x - 1, y + 1, y + 8, C["out"])
    vline(img, x + 6, y + 1, y + 8, C["out"])
    hline(img, x - 2, x + 7, y - 3, C["out"])
    vline(img, x - 2, y - 3, y, C["out"])
    vline(img, x + 7, y - 3, y, C["out"])


def flowerbox(img, x, y, seed):
    r = rng(seed)
    rect(img, x, y, 12, 3, C["wood"])
    hline(img, x, x + 11, y + 2, C["wood_d"])
    hline(img, x - 1, x + 12, y + 3, C["out"])
    vline(img, x - 1, y, y + 2, C["out"])
    vline(img, x + 12, y, y + 2, C["out"])
    for i in range(6):
        fx = x + 1 + i * 2
        put(img, fx, y - 1, C["leaf"])
        put(img, fx, y - 2, C[r.choice(["red", "yellow", "purple_l", "white", "pink"])])
        put(img, fx + 1, y - 1, C["leaf_d"])


def sign(img, x, y, icon):
    """Placa pendurada 12x10 com ícone."""
    hline(img, x - 1, x + 12, y - 2, C["out"])
    hline(img, x, x + 11, y - 1, C["wood_d"])
    vline(img, x + 2, y - 1, y, C["out"])
    vline(img, x + 9, y - 1, y, C["out"])
    rect(img, x, y + 1, 12, 9, C["wood_l"])
    rect(img, x + 1, y + 2, 10, 7, C["cream"])
    for xx in range(x, x + 12):
        put(img, xx, y + 1, C["out"])
        put(img, xx, y + 10, C["out"])
    vline(img, x - 1, y + 1, y + 10, C["out"])
    vline(img, x + 12, y + 1, y + 10, C["out"])
    for (dx, dy), c in icon.items():
        put(img, x + 1 + dx, y + 2 + dy, c)


BREAD_ICON = from_ascii(["..........", "...oooo...", "..oyyyyo..", ".oyYyYyyo.", ".oyyyyyyo.", "..oooooo..",
                         ".........."], {"o": C["out"], "y": C["orange"], "Y": C["yellow"]})
ANVIL_ICON = from_ascii(["..........", ".ooooooo..", "oggggggo..", ".ogggo....", "..ogo.....", ".ooooo....",
                         ".........."], {"o": C["out"], "g": C["stone_d"]})


def _icon_dict(img):
    return {(x, y): img.getpixel((x, y)) for y in range(img.height) for x in range(img.width) if img.getpixel((x, y))[3]}


def awning(img, x, y, w):
    for i in range(w):
        c = C["red"] if (i // 3) % 2 == 0 else C["white"]
        for yy in range(y, y + 4):
            put(img, x + i, yy, c)
        if i % 3 == 1:
            put(img, x + i, y + 4, c)
    hline(img, x - 1, x + w, y - 1, C["out"])
    for i in range(w):
        yy = y + 5 if i % 3 == 1 else y + 4
        put(img, x + i, yy, C["out"])
    vline(img, x - 1, y, y + 4, C["out"])
    vline(img, x + w, y, y + 4, C["out"])


def house(roof, wall, w, rows, door, seed, chimney_at=None, boxes=True, stone_chim=False):
    top, bot, gable = ROOF[roof]
    tiles = WALL[wall]
    img = new(w * T, rows * T + 12)
    oy = 12
    for i in range(w):
        t = top[0] if i == 0 else (top[2] if i == w - 1 else top[1])
        img.alpha_composite(ktile(t), (i * T, oy))
        b = bot[0] if i == 0 else (bot[2] if i == w - 1 else bot[1])
        if door is not None and i == door:
            b = gable
        img.alpha_composite(ktile(b), (i * T, oy + T))
    wall_rows = rows - 2
    for r in range(wall_rows):
        last = r == wall_rows - 1
        for i in range(w):
            if last and door is not None and i == door:
                t = tiles["door"]
            elif (i == 0 or i == w - 1) or (not last and i % 2 == 1):
                t = tiles["win"]
            else:
                t = tiles["plain"]
            tile = ktile(t).copy()
            if not last:
                # linha superior sem rodapé: corta a base do tile e repete a parede
                plain = ktile(tiles["plain"])
                tile.paste(plain.crop((0, 12, 16, 16)), (0, 12))
            img.alpha_composite(tile, (i * T, oy + (2 + r) * T))
    if boxes:
        for r in range(wall_rows):
            last = r == wall_rows - 1
            for i in range(w):
                is_win = (i == 0 or i == w - 1) or (not last and i % 2 == 1)
                if is_win and not (last and door is not None and i == door):
                    flowerbox(img, i * T + 2, oy + (2 + r) * T + 13, seed + i * 7 + r)
    chim = None
    if chimney_at is not None:
        cx = chimney_at * T + 5
        chimney(img, cx, 5, stone_chim)
        chim = (cx + 3, 1)
    return img, chim


def bakery():
    img, chim = house("red", "wood", 5, 3, 2, 11, chimney_at=4, stone_chim=True)
    awning(img, 2 * T - 1, 12 + 2 * T - 3, T + 2)
    sign(img, 3 * T + 3, 12 + 2 * T + 1, _icon_dict(BREAD_ICON))
    return img, chim


def forge():
    img, chim = house("grey", "stone", 5, 3, 2, 21, chimney_at=0, stone_chim=True)
    sign(img, 3 * T + 3, 12 + 2 * T + 1, _icon_dict(ANVIL_ICON))
    # fuligem no telhado
    r = rng(3)
    for _ in range(25):
        x, y = r.randrange(0, 40), r.randrange(12, 30)
        if get(img, x, y)[3]:
            put(img, x, y, C["stone_dd"])
    return img, chim


def stained_window():
    w = new(16, 16)
    rect(w, 3, 3, 10, 11, C["stone_d"])
    glass = [C["blue"], C["red"], C["yellow"], C["leaf"], C["purple_l"]]
    for y in range(4, 13):
        for x in range(4, 12):
            if y < 6 and (x < 5 + (6 - y) or x > 10 - (6 - y)):
                continue
            put(w, x, y, glass[((x - 4) // 2 + (y - 4) // 3) % len(glass)])
    vline(w, 7, 4, 12, C["out"])
    vline(w, 8, 4, 12, C["out"])
    hline(w, 4, 11, 8, C["out"])
    outline(w)
    return w


def temple():
    tw, rows = 6, 4
    img = new(tw * T, rows * T + 40)
    oy = 40
    top, bot, _ = ROOF["grey"]
    for i in range(tw):
        img.alpha_composite(ktile(top[0] if i == 0 else top[2] if i == tw - 1 else top[1]), (i * T, oy))
        img.alpha_composite(ktile(bot[0] if i == 0 else bot[2] if i == tw - 1 else bot[1]), (i * T, oy + T))
    for r in range(2):
        for i in range(tw):
            t = 77
            if r == 0 and i in (0, tw - 1):
                t = 76 if i == 0 else 79
            if r == 1 and i in (0, tw - 1):
                t = 88
            tile = ktile(t).copy()
            if r == 0:
                tile.paste(ktile(77).crop((0, 12, 16, 16)), (0, 12))
            img.alpha_composite(tile, (i * T, oy + (2 + r) * T))
    sw = stained_window()
    for i in (1, 4):
        img.alpha_composite(sw, (i * T, oy + 2 * T - 1))
        img.alpha_composite(sw, (i * T, oy + 3 * T - 2))
    # porta dupla em arco, centralizada
    cx = tw * T // 2
    dy0 = oy + 2 * T + 8
    for y in range(dy0, oy + 4 * T):
        for x in range(cx - 10, cx + 10):
            ddx = x + 0.5 - cx
            if y < dy0 + 8 and ddx * ddx + (y - dy0 - 8) ** 2 * 1.6 > 100:
                continue
            c = C["wood"] if x < cx else C["wood_d"]
            if x in (cx - 10, cx + 9) or x == cx or x == cx - 1:
                c = C["out"]
            put(img, x, y, c)
    for x in range(cx - 11, cx + 11):
        for y in range(dy0 - 2, oy + 4 * T):
            if get(img, x, y)[:3] not in (rgb("wood"), rgb("wood_d"), rgb("out")) and (
                    get(img, x + 1, y)[:3] in (rgb("wood"), rgb("wood_d")) or get(img, x - 1, y)[:3] in (rgb("wood"), rgb("wood_d"))
                    or get(img, x, y + 1)[:3] in (rgb("wood"), rgb("wood_d"))):
                put(img, x, y, C["out"])
    put(img, cx - 3, oy + 3 * T + 6, C["gold"])
    put(img, cx + 2, oy + 3 * T + 6, C["gold"])
    # degraus
    rect(img, cx - 14, oy + 4 * T - 2, 28, 2, C["stone_l"])
    hline(img, cx - 14, cx + 13, oy + 4 * T - 1, C["stone_d"])
    # torre do sino
    bx0, bw = cx - 11, 22
    rect(img, bx0, 14, bw, oy + 12 - 14, C["stone"])
    for y in range(16, oy + 12, 4):
        off = 0 if (y // 4) % 2 == 0 else 3
        for x in range(bx0 + off, bx0 + bw, 6):
            put(img, x, y, C["stone_d"])
    vline(img, bx0 + 1, 14, oy + 11, C["stone_l"])
    vline(img, bx0 + bw - 2, 14, oy + 11, C["stone_d"])
    # abertura do sino
    for y in range(20, 34):
        for x in range(cx - 6, cx + 6):
            if y < 24 and (x + 0.5 - cx) ** 2 + (y - 24) ** 2 * 2 > 36:
                continue
            put(img, x, y, C["out2"])
    ellipse(img, cx, 29, 4, 4, C["gold"])
    rect(img, cx - 5, 30, 10, 3, C["gold"])
    put(img, cx - 2, 27, C["gold_l"])
    put(img, cx - 3, 28, C["gold_l"])
    hline(img, cx - 5, cx + 4, 33, C["gold_d"])
    put(img, cx, 34, C["gold_d"])
    vline(img, bx0 - 1, 14, oy + 11, C["out"])
    vline(img, bx0 + bw, 14, oy + 11, C["out"])
    # telhado pontudo da torre
    for y in range(0, 15):
        hw = int((y + 1) * 0.9) + 1
        for x in range(cx - hw, cx + hw):
            c = C["red"] if x < cx else C["red_d"]
            if (y + x) % 5 == 0:
                c = C["red_l"] if x < cx else C["red"]
            put(img, x, y + 1, c)
        put(img, cx - hw - 1, y + 1, C["out"])
        put(img, cx + hw, y + 1, C["out"])
    hline(img, cx - 15, cx + 14, 15, C["out"])
    hline(img, cx - 14, cx + 13, 14, C["red_d"])
    # símbolo do sol no topo
    disc(img, cx, 1.5, 2.2, C["gold"])
    put(img, cx, 1, C["gold_l"])
    return img, None


# ------------------------------------------------------------------ castelo
CW, CH = 192, 112


def _brick_fill(img, x0, y0, w, h, light=False):
    base = C["stone_l"] if light else C["stone"]
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            row = (y - y0) // 4
            c = base
            if (y - y0) % 4 == 3:
                c = C["stone_d"]
            elif (x - x0 + (4 if row % 2 else 0)) % 8 == 7:
                c = C["stone_d"]
            elif (y - y0) % 4 == 0 and not light:
                c = (156, 168, 192, 255)
            put(img, x, y, c)


def _crenels_h(img, x0, x1, y, down=False):
    """Ameias vistas de cima ao longo de uma borda horizontal."""
    for x in range(x0, x1, 5):
        rect(img, x, y, 3, 3, C["stone_l"])
        hline(img, x, x + 2, y + (2 if not down else 0), C["stone"])
        for xx in range(x - 1, x + 4):
            put(img, xx, y - 1, C["out"])
        vline(img, x - 1, y, y + 2, C["out"])
        vline(img, x + 3, y, y + 2, C["out"])


def _walkway(img, x0, y0, w, h):
    rect(img, x0, y0, w, h, C["stone_l"])
    for y in range(y0, y0 + h, 6):
        hline(img, x0, x0 + w - 1, y, C["stone"])
    rect(img, x0, y0, 1, h, C["out"])
    rect(img, x0 + w - 1, y0, 1, h, C["out"])


def _tower(img, x0, top_y, w, face_h, seed):
    """Torre redonda: face de tijolo com sombreamento + topo com ameias."""
    cx = x0 + w / 2
    top_h = 12
    face_y = top_y + top_h // 2
    for y in range(face_y, face_y + face_h):
        for x in range(x0, x0 + w):
            rel = (x + 0.5 - cx) / (w / 2)
            row = (y - face_y) // 4
            c = C["stone"]
            if rel < -0.55:
                c = C["stone_l"]
            elif rel > 0.5:
                c = C["stone_d"]
            if (y - face_y) % 4 == 3 or (x - x0 + (3 if row % 2 else 0)) % 7 == 6:
                c = C["stone_d"] if rel <= 0.5 else C["stone_dd"]
            put(img, x, y, c)
    # seteira
    rect(img, int(cx) - 1, face_y + face_h // 2 - 4, 2, 7, C["out2"])
    vline(img, x0, face_y, face_y + face_h - 1, C["out"])
    vline(img, x0 + w - 1, face_y, face_y + face_h - 1, C["out"])
    hline(img, x0, x0 + w - 1, face_y + face_h - 1, C["out"])
    # topo
    ellipse(img, cx, top_y + top_h / 2, w / 2, top_h / 2, C["stone"])
    ellipse(img, cx, top_y + top_h / 2 + 1, w / 2 - 3, top_h / 2 - 3, C["stone_l"])
    ellipse(img, cx, top_y + top_h / 2 + 1.5, w / 2 - 4, top_h / 2 - 3.5, (178, 190, 210, 255))
    for k in range(10):
        a = k / 10 * math.tau
        mx = cx + math.cos(a) * (w / 2 - 1.5)
        my = top_y + top_h / 2 + math.sin(a) * (top_h / 2 - 1)
        rect(img, int(mx) - 1, int(my) - 2, 3, 3, C["stone_l"])
        put(img, int(mx) + 1, int(my), C["stone"])


def castle():
    img = new(CW, CH)
    # piso interno (salão)
    for y in range(14, 92):
        for x in range(24, 168):
            c = C["stone_l"] if ((x // 8) + (y // 8)) % 2 == 0 else (178, 190, 210, 255)
            if x % 8 == 7 or y % 8 == 7:
                c = C["stone"]
            put(img, x, y, c)
    # tapete vermelho do trono até o portão
    for y in range(40, 96):
        for x in range(86, 106):
            c = C["red"]
            if x in (86, 105):
                c = C["out"]
            elif x in (87, 104):
                c = C["gold"]
            elif (y + x) % 9 == 0:
                c = C["red_l"]
            put(img, x, y, c)
    # estrado do trono
    rect(img, 72, 26, 48, 16, C["purple"])
    rect(img, 74, 28, 44, 12, C["purple_l"])
    for x in range(74, 118, 4):
        put(img, x, 28, C["pink"])
    hline(img, 72, 119, 41, C["purple_d"])
    rect(img, 70, 42, 52, 3, C["stone_l"])
    hline(img, 70, 121, 44, C["stone_d"])
    hline(img, 71, 120, 25, C["out"])
    vline(img, 71, 25, 44, C["out"])
    vline(img, 120, 25, 44, C["out"])
    # pilares
    for px_ in (48, 136):
        for py in (34, 62):
            rect(img, px_ - 4, py - 16, 8, 16, C["stone_l"])
            vline(img, px_ + 2, py - 16, py - 1, C["stone"])
            vline(img, px_ + 3, py - 16, py - 1, C["stone_d"])
            rect(img, px_ - 5, py - 18, 10, 3, C["stone_l"])
            rect(img, px_ - 5, py - 1, 10, 3, C["stone"])
            outline_rect(img, px_ - 6, py - 19, 12, 22)
            ellipse(img, px_, py + 3, 6, 1.5, (40, 30, 50, 60))
    # muralha de trás (face interna com tijolos)
    _brick_fill(img, 16, 0, 160, 18)
    hline(img, 16, 175, 17, C["out"])
    hline(img, 16, 175, 18, (40, 30, 50, 90))
    # cortina roxa com brasão atrás do trono
    rect(img, 84, 2, 24, 16, C["purple"])
    for x in range(84, 108, 3):
        vline(img, x, 2, 17, C["purple_d"])
    rect(img, 92, 5, 8, 8, C["gold"])
    rect(img, 94, 7, 4, 4, C["purple_l"])
    hline(img, 83, 108, 1, C["gold"])
    vline(img, 83, 1, 17, C["out"])
    vline(img, 108, 1, 17, C["out"])
    # muralhas laterais (passarela vista de cima)
    _walkway(img, 12, 8, 13, 84)
    _walkway(img, 167, 8, 13, 84)
    for y in range(12, 88, 5):
        rect(img, 12, y, 2, 3, C["stone"])
        rect(img, 178, y, 2, 3, C["stone"])
        put(img, 12, y + 3, C["out"])
        put(img, 179, y + 3, C["out"])
    # muralha da frente: passarela + face
    _walkway(img, 12, 84, 168, 9)
    hline(img, 12, 179, 84, C["out"])
    _crenels_h(img, 16, 180, 90, down=True)
    _brick_fill(img, 12, 93, 168, 19)
    hline(img, 12, 179, 111, C["out"])
    vline(img, 12, 84, 111, C["out"])
    vline(img, 179, 84, 111, C["out"])
    # abertura do portão (coberta pelo sprite do portão)
    rect(img, 80, 94, 32, 18, C["out2"])
    # torres
    _tower(img, 0, 0, 30, 30, 1)
    _tower(img, 162, 0, 30, 30, 2)
    _tower(img, 0, 62, 32, 44, 3)
    _tower(img, 160, 62, 32, 44, 4)
    # torres ladeando o portão
    _tower(img, 62, 78, 18, 28, 5)
    _tower(img, 112, 78, 18, 28, 6)
    return img


def outline_rect(img, x, y, w, h):
    hline(img, x, x + w - 1, y, C["out"])
    hline(img, x, x + w - 1, y + h - 1, C["out"])
    vline(img, x, y, y + h - 1, C["out"])
    vline(img, x + w - 1, y, y + h - 1, C["out"])


def castle_gate():
    frames = []
    for opened in (0, 1):
        img = new(32, 18)
        if opened:
            g = new(32, 16)
            g.alpha_composite(ktile(113), (0, 0))
            g.alpha_composite(ktile(114), (16, 0))
            img.alpha_composite(g, (0, 2))
        else:
            g = new(32, 16)
            g.alpha_composite(ktile(111), (0, 0))
            g.alpha_composite(ktile(112), (16, 0))
            img.alpha_composite(g, (0, 2))
        rect(img, 0, 0, 32, 2, C["stone"])
        hline(img, 0, 31, 0, C["stone_d"])
        frames.append(img)
    return hstrip(frames)


def castle_cracks(level):
    img = new(CW, CH)
    r = rng(40 + level)
    starts = [(30, 95), (150, 97), (60, 4), (130, 6), (8, 70), (184, 72), (95, 100), (40, 20), (170, 30)]
    for i in range(level * 3):
        x, y = starts[i % len(starts)]
        for _ in range(r.randrange(8, 16)):
            put(img, x, y, C["out"])
            put(img, x + 1, y, (60, 50, 60, 150))
            x += r.choice((-1, 0, 1))
            y += 1 if y < CH - 2 else 0
        if level >= 2:
            for _ in range(3):
                bx, by = x + r.randrange(-6, 6), y + r.randrange(-2, 3)
                rect(img, bx, by, 2, 2, C["stone_d"])
    return img


def throne():
    rows = [
        "......OYO.......",
        ".....OYRYO......",
        "....OOYYYOO.....",
        "...OYYYYYYYO....",
        "...OYPPPPPYO....",
        "...OYPpPPpYO....",
        "...OYPPPPPYO....",
        "...OYPpPPpYO....",
        "...OYPPPPPYO....",
        ".OOOYPPPPPYOOO..",
        ".OYYYyyyyyYYYO..",
        ".OYDOPPPPPODYO..",
        ".OYYOPPPPPOYYO..",
        ".OyYOPPPPPOYyO..",
        ".OYYYYYYYYYYYO..",
        ".OyyyyyyyyyyyO..",
        ".OYO.......OYO..",
        ".OOO.......OOO..",
    ]
    img = from_ascii(rows, {"O": C["out"], "Y": C["gold"], "y": C["gold_d"], "R": C["red"], "P": C["purple_l"],
                            "p": C["purple"], "D": C["water"]}, 16)
    return img


def build_all():
    meta = {}
    kinds = {
        "house_red_wood_4": lambda: house("red", "wood", 4, 3, 1, 1, chimney_at=3),
        "house_red_wood_3": lambda: house("red", "wood", 3, 3, 1, 2, chimney_at=2),
        "house_red_stone_4": lambda: house("red", "stone", 4, 3, 2, 3, chimney_at=0, stone_chim=True),
        "house_grey_stone_3": lambda: house("grey", "stone", 3, 3, 1, 4, chimney_at=2, stone_chim=True),
        "house_grey_wood_4x2": lambda: house("grey", "wood", 4, 4, 1, 5, chimney_at=3),
        "bakery": bakery,
        "forge": forge,
        "temple": temple,
    }
    for name, fn in kinds.items():
        img, chim = fn()
        save(img, f"buildings/{name}.png")
        meta[f"buildings/{name}"] = {"hframes": 1, "origin": [0, img.height], "chimney": list(chim) if chim else None}
    save(castle(), "buildings/castle.png")
    meta["buildings/castle"] = {"hframes": 1, "origin": [0, 0]}
    for lv in (1, 2, 3):
        save(castle_cracks(lv), f"buildings/castle_cracks_{lv}.png")
    save(castle_gate(), "buildings/castle_gate.png")
    meta["buildings/castle_gate"] = {"hframes": 2, "origin": [16, 18]}
    save(throne(), "buildings/throne.png")
    meta["buildings/throne"] = {"hframes": 1, "origin": [7, 17]}
    return meta


if __name__ == "__main__":
    import os
    from PIL import Image
    m = build_all()
    d = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gen", "buildings")
    names = ["house_red_wood_4", "house_red_wood_3", "house_red_stone_4", "house_grey_stone_3", "house_grey_wood_4x2",
             "bakery", "forge", "temple"]
    imgs = [Image.open(os.path.join(d, n + ".png")) for n in names]
    cas = Image.open(os.path.join(d, "castle.png"))
    gate = Image.open(os.path.join(d, "castle_gate.png")).crop((0, 0, 32, 18))
    thr = Image.open(os.path.join(d, "throne.png"))
    cas.alpha_composite(gate, (80, 94))
    cas.alpha_composite(thr, (88, 19))
    W = sum(i.width + 6 for i in imgs)
    prev = Image.new("RGBA", (max(W, cas.width), max(i.height for i in imgs) + cas.height + 10), (132, 198, 105, 255))
    x = 0
    for i in imgs:
        prev.alpha_composite(i, (x, 0))
        x += i.width + 6
    prev.alpha_composite(cas, (0, max(i.height for i in imgs) + 10))
    prev.resize((prev.width * 3, prev.height * 3), Image.NEAREST).save(os.path.join(os.path.dirname(__file__), "_preview_build.png"))
    print("ok")
