"""Props animados, fauna, itens carregáveis e UI (balão de fala, anel de seleção)."""
from common import (C, T, new, put, get, rect, hline, vline, disc, ellipse, ktile, save, outline, rng, hstrip, grid,
                    from_ascii, recolor, rgb, math, mix)

META = {}


def reg(name, img, frames=1, origin=None, fps=0.0, vframes=1):
    save(img, f"props/{name}.png")
    fw = img.width // frames
    fh = img.height // vframes
    META[f"props/{name}"] = {"hframes": frames, "vframes": vframes, "origin": origin or [fw // 2, fh - 1], "fps": fps}


GREY = lambda v: (v, v, v, 255)


# ------------------------------------------------------------------ fogo / fumaça
def flame(w=8, h=12, n=6, seed=1):
    r = rng(seed)
    frames = []
    for f in range(n):
        img = new(w, h)
        cx = w / 2 - 0.5
        sway = math.sin(f / n * math.tau) * 0.8
        for y in range(h):
            t = y / (h - 1)
            hw = (w / 2 - 0.5) * (math.sin(t * math.pi * 0.9) ** 0.8) * (0.85 + 0.15 * math.sin(f * 1.7 + y))
            x_c = cx + sway * (1 - t)
            for x in range(w):
                d = abs(x - x_c)
                if d <= hw:
                    inner = d < hw * 0.45 and t > 0.35
                    c = C["flame_l"] if inner else (C["flame"] if d < hw * 0.8 else C["flame_d"])
                    put(img, x, y, c)
        if r.random() < 0.7:
            put(img, int(cx + r.choice((-2, 2))), r.randrange(0, 3), C["flame"])
        frames.append(img)
    return hstrip(frames)


def smoke(n=8):
    frames = []
    puffs = [(0.0, 0), (0.33, 1), (0.66, -1)]
    for f in range(n):
        img = new(14, 30)
        for (ph, side) in puffs:
            t = (f / n + ph) % 1.0
            y = 28 - t * 26
            x = 7 + side * t * 3 + math.sin(t * 6) * 1.5
            rad = 1.5 + t * 3
            a = int(200 * (1 - t))
            disc(img, x, y, rad, (200, 200, 210, a))
            disc(img, x - 0.7, y - 0.7, rad * 0.55, (235, 235, 240, a))
        frames.append(img)
    return hstrip(frames)


def torch_post():
    img = new(8, 22)
    rect(img, 3, 6, 2, 16, C["wood"])
    vline(img, 4, 6, 21, C["wood_d"])
    rect(img, 1, 3, 6, 4, C["stone_d"])
    hline(img, 1, 6, 3, C["stone"])
    outline(img)
    return img


def wall_torch():
    img = new(8, 10)
    rect(img, 3, 3, 2, 6, C["wood"])
    rect(img, 2, 2, 4, 2, C["stone_d"])
    hline(img, 1, 6, 8, C["stone_d"])
    outline(img)
    return img


# ------------------------------------------------------------------ praça
def fountain():
    """Base de pedra (estática) + água da bacia e jatos (tons de cinza, tingidos no jogo)."""
    W, H = 44, 40
    base = new(W, H)
    cx, cy = W / 2, 29
    ellipse(base, cx, cy + 1, 21, 9, C["stone_d"])
    ellipse(base, cx, cy, 21, 8.5, C["stone"])
    ellipse(base, cx, cy - 1, 20, 7.5, C["stone_l"])
    ellipse(base, cx, cy - 1, 17, 5.8, (0, 0, 0, 0))
    # face frontal da bacia
    for x in range(int(cx - 21), int(cx + 21)):
        for y in range(int(cy), int(cy + 7)):
            dx = (x + 0.5 - cx) / 21
            if dx * dx + ((y + 0.5 - cy) / 8.5) ** 2 > 1 and y - cy < 6 and abs(dx) < 1 and dx * dx + ((y + 0.5 - cy - 5) / 8.5) ** 2 <= 1:
                put(base, x, y, C["stone"] if dx < 0.4 else C["stone_d"])
    # pilar central com prato
    rect(base, int(cx) - 2, 12, 4, 17, C["stone_l"])
    vline(base, int(cx) + 1, 12, 28, C["stone"])
    ellipse(base, cx, 12, 7, 2.5, C["stone"])
    ellipse(base, cx, 11.5, 6, 1.8, C["stone_l"])
    ellipse(base, cx, 11.5, 4, 1.1, (0, 0, 0, 0))
    rect(base, int(cx) - 1, 5, 2, 6, C["stone_l"])
    disc(base, cx, 5, 2, C["stone_l"])
    outline(base)
    pool = new(W, H)
    ellipse(pool, cx, cy - 1, 17.5, 6.2, GREY(200))
    ellipse(pool, cx, cy - 1.5, 13, 4, GREY(185))
    spray_frames, pool_frames = [], []
    n = 6
    for f in range(n):
        p = pool.copy()
        for k in range(5):
            a = (k / 5 + f / n) * math.tau
            x = cx + math.cos(a) * 12
            y = cy - 1 + math.sin(a) * 4
            hline(p, int(x) - 1, int(x) + 1, int(y), GREY(250))
        ellipse(p, cx, 11.5, 4, 1.1, GREY(215))
        pool_frames.append(p)
        s = new(W, H)
        for k in range(8):
            t = ((k / 8) + f / n) % 1.0
            for side in (-1, 1):
                x = cx + side * (1 + t * 10)
                y = 6 + (-(t * 2 - 0.6) ** 2 + 0.36) * -14 + t * 12
                put(s, x, y, GREY(245))
                put(s, x, y + 1, GREY(210))
        for k in range(3):
            t = ((k / 3) + f / n) % 1.0
            put(s, cx - 0.5, 4 - t * 3, GREY(255))
        spray_frames.append(s)
    return base, hstrip(pool_frames), hstrip(spray_frames), n


def well():
    frames = []
    for f in range(4):
        img = new(22, 30)
        ellipse(img, 11, 22, 9, 4, C["stone"])
        ellipse(img, 11, 21, 9, 3.5, C["stone_l"])
        ellipse(img, 11, 21, 6.5, 2.2, C["water_dd"])
        rect(img, 2, 22, 18, 6, C["stone"])
        for x in range(2, 20, 4):
            vline(img, x, 22, 27, C["stone_d"])
        hline(img, 2, 19, 25, C["stone_d"])
        ellipse(img, 11, 27, 9, 1.5, C["stone_d"])
        for x in (3, 18):
            rect(img, x, 7, 2, 15, C["wood"])
            vline(img, x + 1, 7, 21, C["wood_d"])
        for y in range(1, 8):
            hw = 3 + y * 1.5
            hline(img, int(11 - hw), int(11 + hw), y, C["red"] if y % 2 else C["red_l"])
        hline(img, 0, 22, 8, C["red_d"])
        vline(img, 11, 8, 12 + f % 2, C["cream"])
        by = 13 + (0, 1, 2, 1)[f]
        rect(img, 9, by, 5, 4, C["wood"])
        hline(img, 9, 13, by, C["stone_d"])
        outline(img)
        frames.append(img)
    return hstrip(frames)


def notice_board():
    frames = []
    for f in range(2):
        img = new(24, 26)
        for x in (4, 18):
            rect(img, x, 10, 2, 16, C["wood"])
            vline(img, x + 1, 10, 25, C["wood_d"])
        rect(img, 1, 2, 22, 13, C["wood"])
        rect(img, 2, 3, 20, 11, C["wood_l"])
        hline(img, 0, 23, 1, C["wood_d"])
        papers = [(3, 4, 6, 7), (10, 4, 5, 8), (16, 5, 5, 6)]
        for i, (x, y, w, h) in enumerate(papers):
            rect(img, x, y, w, h, C["cream"] if i != 1 else C["white"])
            for yy in range(y + 2, y + h - 1, 2):
                hline(img, x + 1, x + w - 2, yy, C["stone"])
            put(img, x + w // 2, y, C["red"])
            if f == 1 and i == 2:
                put(img, x + w - 1, y + h - 1, (0, 0, 0, 0))
                put(img, x + w, y + h, C["cream"])
        put(img, 12, 11, C["red"])
        put(img, 13, 11, C["red_d"])
        outline(img)
        frames.append(img)
    return hstrip(frames)


def stall():
    frames = []
    for f in range(3):
        img = new(40, 34)
        for x in (3, 35):
            rect(img, x, 8, 2, 26, C["wood"])
            vline(img, x + 1, 8, 33, C["wood_d"])
        rect(img, 2, 20, 36, 12, C["wood"])
        for y in range(22, 32, 3):
            hline(img, 3, 36, y, C["wood_d"])
        rect(img, 2, 18, 36, 3, C["wood_l"])
        # mercadorias
        for i, x in enumerate(range(5, 16, 3)):
            disc(img, x, 16.5, 1.6, C["red"])
            put(img, x - 1, 16, C["red_l"])
        ellipse(img, 21, 16.5, 3.5, 1.8, C["orange"])
        hline(img, 19, 23, 16, C["yellow"])
        rect(img, 27, 13, 8, 5, C["blue"])
        hline(img, 27, 34, 15, C["blue_l"])
        # toldo listrado ondulando
        for x in range(0, 40):
            c = C["red"] if (x // 5) % 2 == 0 else C["white"]
            for y in range(2, 9):
                put(img, x, y, c)
            wave = (x // 5 + f) % 3
            if wave == 0:
                put(img, x, 9, c)
        hline(img, 0, 39, 1, C["red_d"])
        outline(img)
        frames.append(img)
    return hstrip(frames)


def table():
    img = new(34, 16)
    rect(img, 1, 3, 32, 6, C["wood_l"])
    rect(img, 1, 3, 32, 2, C["cream"])
    for x in range(1, 33, 4):
        put(img, x, 4, C["red"])
    rect(img, 1, 9, 32, 2, C["wood"])
    for x in (3, 29):
        rect(img, x, 11, 2, 5, C["wood_d"])
    outline(img)
    return img


def oven():
    base = new(24, 22)
    ellipse(base, 12, 12, 11, 10, C["stone"])
    ellipse(base, 10, 9, 7, 6, C["stone_l"])
    rect(base, 1, 12, 22, 10, C["stone"])
    for y in range(13, 22, 3):
        hline(base, 1, 22, y, C["stone_d"])
    for y in range(12, 20):
        for x in range(7, 17):
            if y < 14 and (x + 0.5 - 12) ** 2 + (y - 14) ** 2 * 3 > 25:
                continue
            put(base, x, y, C["out2"])
    outline(base)
    return base


def anvil():
    img = new(18, 12)
    rows = [
        "..................",
        ".OOOOOOOOOOOOO....",
        "OggGGGGGGGGGgO....",
        ".OgggggggggggOO...",
        "..OOOgggggOOO.....",
        "....OgggggO.......",
        "....OgggggO.......",
        "...OggggggggO.....",
        "..OddddddddddO....",
        "..OOOOOOOOOOOO....",
    ]
    return from_ascii(rows, {"O": C["out"], "g": C["stone_d"], "G": C["stone"], "d": C["stone_dd"]}, 18)


def furnace():
    base = new(28, 34)
    rect(base, 2, 10, 24, 24, C["stone_d"])
    for y in range(12, 34, 4):
        off = 0 if (y // 4) % 2 else 3
        for x in range(2 + off, 26, 6):
            vline(base, x, y, y + 3, C["stone_dd"])
        hline(base, 2, 25, y, C["stone_dd"])
    rect(base, 9, 0, 10, 11, C["stone"])
    hline(base, 9, 18, 3, C["stone_d"])
    hline(base, 9, 18, 7, C["stone_d"])
    for y in range(18, 30):
        for x in range(7, 21):
            if y < 21 and (x + 0.5 - 14) ** 2 + (y - 21) ** 2 * 2 > 49:
                continue
            put(base, x, y, C["out2"])
    outline(base)
    return base


def altar():
    img = new(30, 18)
    rect(img, 3, 6, 24, 12, C["stone_l"])
    vline(img, 26, 6, 17, C["stone"])
    rect(img, 1, 4, 28, 3, C["stone_l"])
    hline(img, 1, 28, 6, C["stone"])
    rect(img, 8, 7, 14, 9, C["purple"])
    hline(img, 8, 21, 7, C["gold"])
    rect(img, 13, 10, 4, 4, C["gold"])
    for x in (5, 24):
        rect(img, x, 0, 2, 4, C["cream"])
    outline(img)
    return img


def banner(n=4):
    frames = []
    for f in range(n):
        img = new(12, 24)
        hline(img, 0, 11, 0, C["wood_d"])
        for y in range(1, 22):
            sway = int(round(math.sin((f / n) * math.tau + y * 0.25) * (y / 22) * 1.2))
            for x in range(1, 11):
                c = C["purple"] if 2 < x < 9 else C["purple_d"]
                if x in (1, 10):
                    c = C["gold"]
                put(img, x + sway, y, c)
            if 7 <= y <= 12:
                for x in range(4, 8):
                    put(img, x + sway, y, C["gold"])
        tip = int(round(math.sin((f / n) * math.tau + 5) * 1.2))
        for x in range(1, 11):
            dy = abs(x - 5.5)
            put(img, x + tip, 22 + (0 if dy > 3 else 1), C["purple_d"])
        outline(img)
        frames.append(img)
    return hstrip(frames)


def flag(main, dark, emblem, n=4):
    frames = []
    for f in range(n):
        img = new(20, 12)
        for x in range(0, 18):
            wave = math.sin((f / n) * math.tau - x * 0.45) * (x / 18) * 1.6
            for y in range(1, 10):
                c = main if (y + int(wave)) % 9 > 1 else dark
                if emblem and 5 <= x <= 9 and 3 <= y <= 6:
                    c = emblem
                put(img, x + 1, int(round(y + wave)), c)
        outline(img)
        frames.append(img)
    return hstrip(frames)


def flagpole():
    img = new(4, 40)
    vline(img, 1, 3, 39, C["wood_d"])
    vline(img, 2, 3, 39, C["wood"])
    disc(img, 2, 2, 1.6, C["gold"])
    outline(img)
    return img


# ------------------------------------------------------------------ fauna / flora pequena
def lily(n=4):
    frames = []
    for f in range(n):
        img = new(14, 9)
        dy = (0, 0, 1, 0)[f]
        ellipse(img, 7, 5 + dy, 6, 3, C["leaf"])
        ellipse(img, 6, 4.5 + dy, 3.5, 1.6, C["leaf_h"])
        put(img, 9, 5 + dy, (0, 0, 0, 0))
        put(img, 10, 5 + dy, (0, 0, 0, 0))
        disc(img, 8, 3 + dy, 1.6, C["pink"])
        put(img, 8, 3 + dy, C["white"])
        outline(img, C["leaf_dd"])
        frames.append(img)
    return hstrip(frames)


def fish():
    frames = []
    for f in range(2):
        img = new(10, 6)
        ellipse(img, 4, 3, 3.5, 1.8, C["orange"])
        put(img, 2, 2, C["yellow"])
        put(img, 1, 2, C["black"])
        tx = 8
        put(img, tx, 1 + f, C["orange"])
        put(img, tx, 4 - f, C["orange"])
        put(img, tx + 1, 0 + f * 2, C["flame_d"])
        put(img, tx - 1, 3, C["orange"])
        frames.append(img)
    dead = new(10, 6)
    ellipse(dead, 4, 3, 3.5, 1.8, C["grey_l"])
    hline(dead, 2, 6, 2, C["white"])
    put(dead, 1, 2, C["black"])
    put(dead, 2, 1, C["black"])
    put(dead, 8, 2, C["grey"])
    put(dead, 8, 4, C["grey"])
    frames.append(dead)
    return hstrip(frames)


def butterflies():
    rows = []
    for col, dark in (("yellow", "orange"), ("white", "stone"), ("pink", "purple_l"), ("blue_l", "blue")):
        fr = []
        for f in range(3):
            img = new(9, 7)
            span = (4, 2, 1)[f]
            for side in (-1, 1):
                for y in range(1, 6):
                    wlen = span if y < 4 else max(1, span - 1)
                    for k in range(1, wlen + 1):
                        put(img, 4 + side * k, y, C[col] if k < wlen else C[dark])
            vline(img, 4, 2, 5, C["out"])
            put(img, 3, 1, C["out"])
            put(img, 5, 1, C["out"])
            fr.append(img)
        rows.append(fr)
    return grid(rows)


def leaves():
    rows = []
    for col in ("leaf", "orange", "yellow", "pink"):
        fr = []
        for f in range(4):
            img = new(6, 6)
            shapes = [[(1, 2), (2, 2), (3, 2), (4, 3), (2, 3), (3, 3)], [(2, 1), (2, 2), (3, 2), (3, 3), (3, 4), (2, 3)],
                      [(1, 3), (2, 3), (3, 3), (4, 2), (2, 2), (3, 2)], [(3, 1), (3, 2), (2, 2), (2, 3), (2, 4), (3, 3)]]
            for (x, y) in shapes[f]:
                put(img, x, y, C[col])
            put(img, shapes[f][0][0], shapes[f][0][1], C["leaf_d"] if col == "leaf" else C["red_d"] if col != "pink" else C["purple_l"])
            fr.append(img)
        rows.append(fr)
    return grid(rows)


def chicken():
    """Linhas: branca, marrom. Colunas: parada, bicando 1, bicando 2, andando."""
    rows = []
    for body, shade in (("white", "grey_l"), ("brown_l", "brown")):
        fr = []
        for pose in range(4):
            img = new(12, 11)
            hy = (2, 4, 6, 2)[pose]
            hx = (3, 3, 2, 3)[pose]
            ellipse(img, 7, 6, 4, 3, C[body])
            ellipse(img, 8, 7, 2.5, 1.5, C[shade])
            put(img, 11, 4, C[body])
            put(img, 11, 3, C[shade])
            disc(img, hx, hy + 0.5, 1.8, C[body])
            put(img, hx - 1, hy - 1, C["red"])
            put(img, hx, hy - 1, C["red"])
            put(img, hx - 2, hy + 1, C["yellow"])
            put(img, hx - 1, hy, C["black"])
            lx = (0, 0, 0, 1)[pose]
            vline(img, 6 - lx, 9, 10, C["orange"])
            vline(img, 8 + lx, 9, 10, C["orange"])
            outline(img)
            fr.append(img)
        rows.append(fr)
    return grid(rows)


def barrel():
    img = new(14, 16)
    ellipse(img, 7, 3, 6, 2, C["wood_l"])
    rect(img, 1, 3, 12, 11, C["wood"])
    ellipse(img, 7, 14, 6, 1.5, C["wood"])
    for x in (4, 9):
        vline(img, x, 4, 14, C["wood_d"])
    for y in (5, 11):
        hline(img, 1, 12, y, C["stone_d"])
    ellipse(img, 7, 3, 4.5, 1.2, C["water_d"])
    outline(img)
    return img


def crate():
    img = new(14, 14)
    rect(img, 1, 1, 12, 12, C["wood_l"])
    rect(img, 3, 3, 8, 8, C["wood"])
    for i in range(8):
        put(img, 3 + i, 3 + i, C["wood_l"])
    hline(img, 1, 12, 12, C["wood_d"])
    vline(img, 12, 1, 12, C["wood_d"])
    outline(img)
    return img


def haystack():
    img = new(22, 16)
    ellipse(img, 11, 10, 10, 6, C["yellow"])
    ellipse(img, 9, 8, 6, 4, C["yellow_l"])
    for x in range(3, 20, 3):
        vline(img, x, 8, 14, C["orange"])
    outline(img)
    return img


def fence_h(n):
    img = new(16 * n, 16)
    for i in range(n):
        t = 80 if i == 0 else (82 if i == n - 1 else 81)
        img.alpha_composite(ktile(t), (i * 16, 0))
    return img


def fence_v(n):
    img = new(16, 16 * n)
    for i in range(n):
        t = 47 if i == 0 else (71 if i == n - 1 else 59)
        img.alpha_composite(ktile(t), (0, i * 16))
    return img


# ------------------------------------------------------------------ itens carregáveis (16x16)
ITEM_ROWS = {
    "apple": ["......OO........", ".....OtO.OO.....", "....OOtOOLLO....", "...ORRRtRRLO....", "..ORRRRRRRRRO...",
              "..ORWRRRRRRRO...", "..ORWRRRRRRdO...", "..ORRRRRRRRdO...", "...ORRRRRRdO....", "....OdRRddO.....",
              ".....OOOOO......"],
    "bread": ["................", ".....OOOOOO.....", "...OOyYYyYYOO...", "..OyYyyYYyyYyO..", ".OyYYYYYYYYYYyO.",
              ".OyyyyyyyyyyyyO.", ".OooooooooooooO.", "..OOOOOOOOOOOO.."],
    "gold_key": ["................", "...OOOO.........", "..OYYYYO........", "..OYOOYOOOOOOOO.", "..OYOOYYYYYYYYYO",
                 "..OYYYYOOOOYOYO.", "...OOOO....O.O.."],
    "royal_ring": ["................", "......OOO.......", ".....ODPDO......", "......OYO.......", "....OOYOYOO.....",
                   "...OYO...OYO....", "...OY.....YO....", "...OYO...OyO....", "....OYYYYyO.....", ".....OOOOO......"],
    "sealed_letter": ["................", ".OOOOOOOOOOOOOO.", ".OWWWWWWWWWWWWO.", ".OwWWWWWWWWWWwO.", ".OWwWWWWWWWWwWO.",
                      ".OWWwWWRRWWwWWO.", ".OWWWwRRRRwWWWO.", ".OWWWWRRRRWWWWO.", ".OWWWWWRRWWWWWO.", ".OOOOOOOOOOOOOO."],
    "royal_coin": ["................", ".....OOOOO......", "....OYYYYYO.....", "...OYYOYOYYO....", "...OYYYYYYyO....",
                   "...OYYOOOYyO....", "...OYYYYYyyO....", "....OyyyyyO.....", ".....OOOOO......"],
    "fake_coin": ["................", ".....OOOOO......", "....OGGGGGO.....", "...OGGOGOGGO....", "...OGGGGGGgO....",
                  "...OGGOOOGgO....", "...OGGGGGggO....", "....OgggggO.....", ".....OOOOO......"],
    "rusty_sword": ["..............OO", ".............ORO", "............ORrO", "...........ORrO.", "..........ORrO..",
                    ".........ORrO...", "..OO....ORrO....", "..OYO..ORrO.....", "...OYOORrO......", "....OYYrO.......",
                    "....OwYYO.......", "...OwO.OYO......", "..OwO...OO......", ".OOO............"],
    "king_dagger": ["................", "...........OO...", "..........OGO...", ".........OGgO...", "........OGgO....",
                    ".......OGgO.....", "....OO.OgO......", "....OYOYOO......", ".....OYRYO......", "....OYYOYO......",
                    "...OpO..OO......", "..OpO...........", "..OO............"],
    "poison_vial": ["................", "......OOOO......", "......OwwO......", ".......OO.......", "......OWWO......",
                    ".....OWVVWO.....", "....OVVVVVVO....", "...OVVvVVVVVO...", "...OVvVVkkVVO...", "...OVVVkVVkVO...",
                    "...OVVVVkkVVO...", "....OVVVVVVO....", ".....OOOOOO....."],
    "blue_hat": ["................", ".....OOOOOO.....", "....OLLLLLLO....", "...OLbbbbbbLO...", "..ObbbbbbbbbbO..",
                 "..ObbbbbbbbbbO..", "..OddddddddddO..", "...OOOOOOOOOO..."],
    "flour": ["................", "......O..O......", ".....OcOOcO.....", "......OccO......", ".....OWWWWO.....",
              "....OWWWWWWO....", "...OWWWWWWWWO...", "...OWwFFFFwWO...", "...OWWFWWWWWO...", "...OWWFFFWWWO...",
              "...OWWFWWWWwO...", "...OwWWWWWWwO...", "....OOOOOOOO...."],
    "rites_book": ["................", "..OOOOOOOOOOO...", "..OPPPPPPPPPOW..", "..OPPPPYPPPPOW..", "..OPPPYYYPPPOW..",
                   "..OPPPPYPPPPOW..", "..OPPPPYPPPPOW..", "..OPPPPPPPPPOW..", "..OpppppppppOW..", "..OOOOOOOOOOOO.."],
    "relic": ["................", ".......OO.......", "......OYYO......", ".....OYWYYO.....", "......OYYO.......",
              "...OOOOYYOOOO...", "...OYYYYYYYYO...", "....OYYDDYYO....", ".....OYYYYO.....", "......OYYO......",
              "......OYYO......", ".....OYYYYO.....", "....OyyyyyyO....", "....OOOOOOOO...."],
    "hammer": ["................", "...OOOOOOO......", "..OGGGGGGGO.....", "..OGgggggGO.....", "..OOOOwOOOO.....",
               "......OwO.......", "......OwO.......", "......OwO.......", "......OwO.......", "......OwO.......",
               "......OwO.......", "......OOO......."],
}
ITEM_PAL = {"O": C["out"], "R": C["red"], "d": C["red_d"], "W": C["white"], "w": C["wood"], "t": C["wood_d"],
            "L": C["leaf"], "y": C["orange"], "Y": C["gold"], "o": C["wood_d"], "D": C["water"], "P": C["purple"],
            "p": C["purple_d"], "G": C["stone_l"], "g": C["stone"], "r": (150, 90, 60, 255), "V": C["leaf_h"],
            "v": C["leaf_hh"], "k": C["leaf_dd"], "L_": C["blue_l"], "b": C["blue"], "c": C["wood_d"], "F": C["stone_d"]}


def items():
    frames, names = [], []
    for name, rows in ITEM_ROWS.items():
        pal = dict(ITEM_PAL)
        if name == "blue_hat":
            pal["L"] = C["blue_l"]
            pal["d"] = C["blue_d"]
        if name == "sealed_letter":
            pal["w"] = C["stone_l"]
        if name == "king_dagger":
            pal["O"] = C["out"]
        if name == "flour":
            pal["w"] = C["cream"]
        img = new(16, 16)
        body = from_ascii(rows, pal, 16)
        img.alpha_composite(body, (0, 16 - body.height - 1))
        frames.append(img)
        names.append(name)
    frames.append(frames[names.index("apple")])
    names.append("poison_apple")
    return hstrip(frames), names


# ------------------------------------------------------------------ UI
def bubble():
    img = new(12, 12)
    rect(img, 1, 1, 10, 10, C["white"])
    hline(img, 2, 9, 0, C["out"])
    hline(img, 2, 9, 11, C["out"])
    vline(img, 0, 2, 9, C["out"])
    vline(img, 11, 2, 9, C["out"])
    for (x, y) in ((1, 1), (10, 1), (1, 10), (10, 10)):
        put(img, x, y, C["out"])
    hline(img, 2, 9, 10, C["stone_l"])
    vline(img, 10, 2, 9, C["stone_l"])
    return img


def bubble_tail():
    return from_ascii(["OWWWWO", ".OWWO.", "..OO..", "......"], {"O": C["out"], "W": C["white"]}, 6)


def select_ring():
    frames = []
    for f in range(4):
        img = new(20, 10)
        for k in range(24):
            a = k / 24 * math.tau
            x = 10 + math.cos(a) * 9
            y = 5 + math.sin(a) * 4
            if (k + f) % 4 < 2:
                put(img, x, y, C["yellow_l"])
            else:
                put(img, x, y, C["gold_d"])
        frames.append(img)
    return hstrip(frames)


def emote_icons():
    """! ? zz raiva coração suor -> 6 colunas 12x12."""
    icons = [
        ["....OO....", "...OWWO...", "...OWWO...", "...OWWO...", "...OWWO...", "....OO....", "...OWWO...", "....OO...."],
        ["..OOOOO...", ".OWWWWWO..", ".OWOO.OWO.", "....OWWO..", "...OWWO...", "....OO....", "...OWWO...", "....OO...."],
        ["..OO...O..", ".OWO..OWO.", "OWWWWOWWWO", "OWWWWWWWWO", ".OWWWWWWO.", "..OWWWWO..", "...OWWO...", "....OO...."],
        ["O..O..O...", ".O.O.O....", "..OOO.....", "OOO.OOO...", "..OOO.....", ".O.O.O....", "O..O..O...", ".........."],
        ["...OO.....", "..OWWO....", ".OWWWWO...", ".OWWWWO...", "..OWWO....", "...OO.....", "..........", ".........."],
        ["OOOOOO....", "...OO.....", "..OO......", "OOOOOO....", "..........", "...OOOO...", "....OO....", "...OOOO..."],
    ]
    pals = [
        {"O": C["out"], "W": C["red"]},
        {"O": C["out"], "W": C["blue_l"]},
        {"O": C["out"], "W": C["pink"]},
        {"O": C["red"]},
        {"O": C["out"], "W": C["water_l"]},
        {"O": C["blue_d"]},
    ]
    frames = []
    for rows, pal in zip(icons, pals):
        img = new(12, 12)
        img.alpha_composite(from_ascii(rows, pal, 10), (1, 2))
        frames.append(img)
    return hstrip(frames)


def glow():
    img = new(64, 64)
    for y in range(64):
        for x in range(64):
            d = math.hypot(x + 0.5 - 32, y + 0.5 - 32) / 32
            if d < 1:
                a = int(255 * (1 - d) ** 1.8)
                img.putpixel((x, y), (255, 255, 255, a))
    return img


def firefly():
    frames = []
    for a in (255, 200, 120, 60, 120, 200):
        img = new(7, 7)
        disc(img, 3.5, 3.5, 3.2, (254, 231, 97, a // 5))
        disc(img, 3.5, 3.5, 2.0, (254, 231, 97, a // 2))
        put(img, 3, 3, (255, 255, 200, a))
        frames.append(img)
    return hstrip(frames)


def build_all():
    save(glow(), "props/glow.png")
    reg("firefly", firefly(), 6, [3, 3], 6.0)
    reg("flame", flame(), 6, [4, 11], 10.0)
    reg("flame_small", flame(5, 7, 6, 2), 6, [2, 6], 12.0)
    reg("smoke", smoke(), 8, [7, 29], 5.0)
    reg("torch_post", torch_post(), 1, [4, 21])
    reg("wall_torch", wall_torch(), 1, [4, 9])
    base, pool, spray, n = fountain()
    reg("fountain_base", base, 1, [22, 38])
    reg("fountain_pool", pool, n, [22, 38], 6.0)
    reg("fountain_spray", spray, n, [22, 38], 8.0)
    reg("well", well(), 4, [11, 29], 2.0)
    reg("notice_board", notice_board(), 2, [12, 25], 1.5)
    reg("stall", stall(), 3, [20, 33], 3.0)
    reg("table", table(), 1, [17, 15])
    reg("oven", oven(), 1, [12, 21])
    reg("anvil", anvil(), 1, [8, 9])
    reg("furnace", furnace(), 1, [14, 33])
    reg("altar", altar(), 1, [15, 17])
    reg("banner", banner(), 4, [6, 0], 4.0)
    reg("flag_royal", flag(C["purple"], C["purple_d"], C["gold"]), 4, [0, 0], 6.0)
    reg("flag_rebel", flag(C["leaf"], C["leaf_d"], C["white"]), 4, [0, 0], 6.0)
    reg("flagpole", flagpole(), 1, [2, 39])
    reg("lily", lily(), 4, [7, 6], 1.5)
    reg("fish", fish(), 3, [4, 3], 5.0)
    reg("butterfly", butterflies(), 3, [4, 3], 10.0, 4)
    reg("leaf", leaves(), 4, [3, 3], 6.0, 4)
    reg("chicken", chicken(), 4, [7, 10], 0.0, 2)
    reg("barrel", barrel(), 1, [7, 15])
    reg("crate", crate(), 1, [7, 13])
    reg("haystack", haystack(), 1, [11, 15])
    reg("beehive", ktile(94), 1, [8, 15])
    reg("log", ktile(106), 1, [8, 13])
    reg("bucket", ktile(104), 1, [8, 15])
    reg("target", ktile(95), 1, [8, 15])
    reg("signpost", ktile(83), 1, [8, 15])
    reg("fence_h3", fence_h(3), 1, [0, 12])
    reg("fence_h4", fence_h(4), 1, [0, 12])
    reg("fence_v4", fence_v(4), 1, [8, 63])
    strip, names = items()
    save(strip, "props/items.png")
    META["props/items"] = {"hframes": len(names), "vframes": 1, "origin": [8, 13], "fps": 0, "names": names}
    reg("bubble", bubble(), 1, [0, 0])
    reg("bubble_tail", bubble_tail(), 1, [3, 0])
    reg("select_ring", select_ring(), 4, [10, 5], 8.0)
    reg("emotes", emote_icons(), 6, [6, 11], 0)
    return META


if __name__ == "__main__":
    import os
    from PIL import Image
    build_all()
    d = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gen", "props")
    names = ["flame", "smoke", "fountain_base", "fountain_pool", "fountain_spray", "well", "notice_board", "stall", "table",
             "oven", "anvil", "furnace", "altar", "banner", "flag_royal", "flag_rebel", "lily", "fish", "butterfly", "leaf",
             "chicken", "barrel", "crate", "haystack", "items", "emotes", "select_ring"]
    imgs = [Image.open(os.path.join(d, n + ".png")) for n in names]
    cols = 3
    cw = max(i.width for i in imgs) * 3 + 8
    rh = []
    rows = [imgs[i:i + cols] for i in range(0, len(imgs), cols)]
    H = sum(max(i.height for i in r) * 3 + 8 for r in rows)
    prev = Image.new("RGBA", (min(cw * cols, 2400), H), (132, 198, 105, 255))
    y = 0
    for r in rows:
        x = 0
        for i in r:
            prev.alpha_composite(i.resize((i.width * 3, i.height * 3), Image.NEAREST), (x, y))
            x += min(i.width * 3 + 8, 800)
        y += max(i.height for i in r) * 3 + 8
    prev.save(os.path.join(os.path.dirname(__file__), "_preview_props.png"))
    print("ok")
