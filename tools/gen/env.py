"""Vegetação: árvores grandes com balanço (4 frames), pinheiros, arbustos, tufos de grama, juncos, flores, plantação."""
from common import C, new, put, get, disc, ellipse, rect, vline, hline, outline, hstrip, save, recolor, rgb, rng, math

GREEN = ["leaf_dd", "leaf_d", "leaf", "leaf_h", "leaf_hh"]
AUTUMN = {rgb("leaf_dd"): C["red_d"][:3], rgb("leaf_d"): C["flame_d"][:3], rgb("leaf"): C["orange"][:3],
          rgb("leaf_h"): C["yellow"][:3], rgb("leaf_hh"): C["yellow_l"][:3]}
DARKGREEN = {rgb("leaf_dd"): (25, 60, 50), rgb("leaf_d"): C["leaf_dd"][:3], rgb("leaf"): C["leaf_d"][:3],
             rgb("leaf_h"): C["leaf"][:3], rgb("leaf_hh"): C["leaf_h"][:3]}
PINK = {rgb("leaf_dd"): C["purple"][:3], rgb("leaf_d"): C["purple_l"][:3], rgb("leaf"): C["pink"][:3],
        rgb("leaf_h"): (255, 170, 190), rgb("leaf_hh"): (255, 215, 225)}


def shade_blob(img, cx, cy, r, pal=GREEN, rim=True):
    """Pinta um 'tufo' de folhas com luz vinda de cima-esquerda."""
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            light = -(dx * 0.62 + dy * 0.78) / r
            if rim and d > r - 1.3 and light < 0.15:
                k = 0
            elif light > 0.62:
                k = 4
            elif light > 0.2:
                k = 3
            elif light > -0.3:
                k = 2
            else:
                k = 1
            put(img, x, y, C[pal[k]])


def leaf_texture(img, seed, pal=GREEN):
    """Pequenos pontos de folha (textura) dentro da copa."""
    r = rng(seed)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            if r.random() < 0.07:
                if p[:3] == rgb(pal[2]):
                    px[x, y] = C[pal[3]]
                elif p[:3] == rgb(pal[3]):
                    px[x, y] = C[pal[2]]
            if r.random() < 0.035 and p[:3] == rgb(pal[2]) and get(img, x, y + 1)[:3] == rgb(pal[2]):
                px[x, y + 1] = C[pal[1]]


def trunk(img, cx, top, bottom, w):
    for y in range(top, bottom + 1):
        ww = w + (2 if y >= bottom - 1 else (1 if y >= bottom - 3 else 0))
        x0 = cx - ww // 2
        for x in range(x0, x0 + ww):
            c = C["wood"]
            if x == x0:
                c = C["wood_l"]
            elif x >= x0 + ww - 2:
                c = C["wood_d"]
            put(img, x, y, c)
    for y in range(top + 2, bottom - 2, 3):
        put(img, cx - 1 + (y % 2), y, C["wood_d"])
    # sombra da copa sobre o tronco
    hline(img, cx - w // 2, cx + w // 2, top, C["out"])
    hline(img, cx - w // 2, cx + w // 2, top + 1, C["wood_d"])


def round_tree(w, h, blobs, trunk_w, trunk_top, seed, pal_map=None, fruit=None):
    frames = []
    for dx in (0, 1, 0, -1):
        canopy = new(w, h)
        for (bx, by, br) in blobs:
            shade_blob(canopy, bx, by, br)
        leaf_texture(canopy, seed)
        if fruit:
            r = rng(seed + 7)
            for _ in range(fruit[1]):
                bx, by, br = blobs[r.randrange(len(blobs))]
                fx, fy = int(bx + r.uniform(-br * 0.6, br * 0.6)), int(by + r.uniform(-br * 0.4, br * 0.6))
                if get(canopy, fx, fy)[3] and get(canopy, fx + 1, fy + 1)[3]:
                    put(canopy, fx, fy, C[fruit[0]])
                    put(canopy, fx + 1, fy, C[fruit[0]])
                    put(canopy, fx, fy + 1, C["red_d"])
                    put(canopy, fx + 1, fy + 1, C[fruit[0]])
        split = int(min(b[1] for b in blobs) + (max(b[1] for b in blobs) - min(b[1] for b in blobs)) * 0.45)
        if dx:
            top_part = canopy.crop((0, 0, w, split))
            rest = canopy.copy()
            rect(rest, 0, 0, w, split, (0, 0, 0, 0))
            shifted = new(w, h)
            shifted.alpha_composite(top_part.crop((max(0, -dx), 0, w - max(0, dx), split)), (max(0, dx), 0))
            shifted.alpha_composite(rest)
            canopy = shifted
        img = new(w, h)
        trunk(img, w // 2, trunk_top, h - 2, trunk_w)
        img.alpha_composite(canopy)
        outline(img)
        if pal_map:
            img = recolor(img, pal_map)
        frames.append(img)
    return hstrip(frames)


def pine(w, h, tiers, seed, pal_map=None):
    frames = []
    for dx in (0, 1, 0, -1):
        img = new(w, h)
        cx = w // 2
        trunk(img, cx, h - 9, h - 2, 4)
        for i, (apex, base, half) in enumerate(tiers):
            sway = dx if i == 0 else (dx if i == 1 and dx else 0) if i < 2 else 0
            for y in range(apex, base + 1):
                t = (y - apex) / max(1, base - apex)
                hw = max(1, int(round(half * t)))
                for x in range(cx - hw, cx + hw + 1):
                    rel = (x - cx) / max(1, hw)
                    if y == base or (y >= base - 1 and abs(rel) > 0.6):
                        k = "leaf_dd"
                    elif rel < -0.35:
                        k = "leaf_h" if t < 0.75 else "leaf"
                    elif rel < 0.2:
                        k = "leaf"
                    else:
                        k = "leaf_d"
                    put(img, x + sway, y, C[k])
            # bicos na base de cada camada
            for x in range(cx - half, cx + half + 1, 3):
                put(img, x + sway, base + 1, C["leaf_d"])
        r = rng(seed)
        px = img.load()
        for y in range(h):
            for x in range(w):
                if px[x, y][3] and px[x, y][:3] == rgb("leaf") and r.random() < 0.08:
                    px[x, y] = C["leaf_h"]
        outline(img)
        if pal_map:
            img = recolor(img, pal_map)
        frames.append(img)
    return hstrip(frames)


def bush(seed, berries=None):
    img = new(20, 14)
    for (bx, by, br) in [(6, 8, 5), (14, 8, 5), (10, 6, 5.5)]:
        shade_blob(img, bx, by, br)
    leaf_texture(img, seed)
    if berries:
        r = rng(seed)
        for _ in range(6):
            x, y = r.randrange(4, 16), r.randrange(4, 12)
            if get(img, x, y)[3]:
                put(img, x, y, C[berries])
    outline(img)
    return img


def tuft():
    frames = []
    for s in (0, 1, 0, -1):
        img = new(9, 7)
        for bx, hgt, col in [(2, 4, "grass_d"), (4, 6, "leaf"), (6, 5, "grass_d"), (3, 3, "leaf"), (5, 4, "grass_l")]:
            for y in range(hgt):
                off = int(round(s * (y / max(1, hgt - 1)) * (1 if hgt > 3 else 0)))
                put(img, bx + off, 6 - y, C[col])
        frames.append(img)
    return hstrip(frames)


def reeds():
    frames = []
    for s in (0, 1, 1, 0, -1, -1):
        img = new(12, 20)
        for bx, hgt in [(3, 15), (6, 18), (9, 13)]:
            for y in range(hgt):
                t = y / hgt
                off = int(round(s * t * t * 1.5))
                put(img, bx + off, 19 - y, C["leaf_d"] if y < hgt * 0.5 else C["leaf"])
            # espiga (taboa)
            tx = bx + s
            for y in range(19 - hgt, 19 - hgt + 4):
                put(img, tx, y, C["brown"])
                put(img, tx + 1, y, C["brown_d"])
        for bx in (1, 5, 8, 11):
            vline(img, bx, 15, 19, C["grass_d"])
        frames.append(img)
    return hstrip(frames)


def flowers():
    """4 frames x 4 cores: flor balançando levemente."""
    rows = []
    cols = [("red", "yellow"), ("yellow_l", "orange"), ("purple_l", "yellow_l"), ("blue_l", "white"), ("white", "yellow")]
    sheet = new(7 * 4, 8 * len(cols))
    for j, (petal, core) in enumerate(cols):
        for i, s in enumerate((0, 1, 0, -1)):
            img = new(7, 8)
            vline(img, 3, 4, 7, C["leaf_d"])
            put(img, 2, 6, C["leaf"])
            cx = 3 + s
            for dx, dy in [(0, -1), (-1, 0), (1, 0), (0, 1)]:
                put(img, cx + dx, 2 + dy, C[petal])
            put(img, cx, 2, C[core])
            sheet.alpha_composite(img, (i * 7, j * 8))
    return sheet


def crops():
    """Canteiro 16x16: terra arada com dois repolhos que balançam as folhas."""
    frames = []
    for s in (0, 1, 0, -1):
        img = new(16, 16)
        rect(img, 0, 0, 16, 16, C["dirt_d"])
        for y in (3, 11):
            hline(img, 0, 15, y, C["wood_d"])
            hline(img, 0, 15, y + 1, C["dirt"])
        for cx, cy in ((4, 6), (12, 6), (4, 14), (12, 14)):
            leaves = new(16, 16)
            disc(leaves, cx, cy - 1, 3.2, C["leaf"])
            disc(leaves, cx - 1, cy - 2, 1.8, C["leaf_h"])
            put(leaves, cx - 3 + s, cy - 4, C["leaf_h"])
            put(leaves, cx + 3 + s, cy - 4, C["leaf_h"])
            outline(leaves)
            img.alpha_composite(leaves)
        frames.append(img)
    return hstrip(frames)


def mushroom():
    img = new(10, 9)
    ellipse(img, 4.5, 3, 4, 3, C["red"])
    for x, y in [(3, 2), (6, 3), (4, 1)]:
        put(img, x, y, C["white"])
    rect(img, 3, 5, 3, 3, C["cream"])
    outline(img)
    return img


def rock(size):
    img = new(size + 2, size)
    ellipse(img, (size + 2) / 2, size / 2 + 0.5, size / 2, size / 2 - 1, C["stone"])
    ellipse(img, (size + 2) / 2 - 1, size / 2 - 0.5, size / 2 - 2, size / 2 - 2.5, C["stone_l"])
    hline(img, 2, size - 1, size - 2, C["stone_d"])
    outline(img)
    return img


def build_all():
    meta = {}

    def reg(name, img, frames=1, origin=None, fps=0):
        save(img, f"env/{name}.png")
        fw = img.width // frames
        meta[f"env/{name}"] = {"hframes": frames, "origin": origin or [fw // 2, img.height - 2], "fps": fps}

    oak_blobs = [(16, 17, 9), (9, 23, 7), (23, 23, 7), (16, 27, 8), (10, 15, 6), (22, 15, 6), (7, 29, 5), (25, 29, 5),
                 (16, 10, 7)]
    reg("tree_oak", round_tree(32, 48, oak_blobs, 6, 35, 1), 4, [16, 46], 2.5)
    reg("tree_oak_dark", round_tree(32, 48, oak_blobs, 6, 35, 2, DARKGREEN), 4, [16, 46], 2.5)
    reg("tree_oak_autumn", round_tree(32, 48, oak_blobs, 6, 35, 3, AUTUMN), 4, [16, 46], 2.5)
    reg("tree_apple", round_tree(32, 48, oak_blobs, 6, 35, 4, None, ("red", 9)), 4, [16, 46], 2.5)
    reg("tree_blossom", round_tree(32, 48, oak_blobs, 6, 35, 5, PINK), 4, [16, 46], 2.5)
    big_blobs = [(24, 20, 12), (13, 28, 10), (35, 28, 10), (24, 33, 11), (14, 17, 8), (34, 17, 8), (24, 11, 9),
                 (8, 36, 6), (40, 36, 6), (20, 40, 7), (30, 40, 7)]
    reg("tree_huge", round_tree(48, 64, big_blobs, 9, 47, 6), 4, [24, 62], 2.0)
    reg("tree_huge_dark", round_tree(48, 64, big_blobs, 9, 47, 7, DARKGREEN), 4, [24, 62], 2.0)
    pine_t = [(2, 14, 5), (9, 24, 8), (17, 34, 10), (25, 41, 11)]
    reg("tree_pine", pine(24, 50, pine_t, 8), 4, [12, 48], 2.5)
    reg("tree_pine_dark", pine(24, 50, pine_t, 9, DARKGREEN), 4, [12, 48], 2.5)
    reg("bush", bush(10), 1, [10, 13])
    reg("bush_berry", bush(11, "red"), 1, [10, 13])
    reg("bush_flower", bush(12, "pink"), 1, [10, 13])
    reg("tuft", tuft(), 4, [4, 6], 3.0)
    reg("reeds", reeds(), 6, [6, 19], 4.0)
    save(flowers(), "env/flowers.png")
    meta["env/flowers"] = {"hframes": 4, "vframes": 5, "origin": [3, 7], "fps": 2.0}
    reg("crops", crops(), 4, [8, 15], 2.0)
    reg("mushroom", mushroom(), 1, [5, 8])
    reg("rock_small", rock(7), 1, [4, 6])
    reg("rock_big", rock(12), 1, [7, 11])
    return meta


if __name__ == "__main__":
    import os
    from PIL import Image
    build_all()
    d = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gen", "env")
    names = ["tree_oak", "tree_oak_dark", "tree_oak_autumn", "tree_apple", "tree_blossom", "tree_huge", "tree_pine",
             "tree_pine_dark", "bush", "bush_berry", "bush_flower", "tuft", "reeds", "flowers", "crops", "mushroom",
             "rock_big"]
    imgs = [Image.open(os.path.join(d, n + ".png")) for n in names]
    W = max(i.width for i in imgs) * 3
    H = sum(i.height * 3 + 6 for i in imgs)
    prev = Image.new("RGBA", (W, H), (132, 198, 105, 255))
    y = 0
    for i in imgs:
        prev.alpha_composite(i.resize((i.width * 3, i.height * 3), Image.NEAREST), (0, y))
        y += i.height * 3 + 6
    prev.save(os.path.join(os.path.dirname(__file__), "_preview_env.png"))
    print("ok")
