"""Gera todos os assets e o map.json consumido pelo Godot (scripts/world.gd)."""
import json
import os

import buildings
import chars
import env
import intro_assets
import layout as L
import props
import terrain
import player_assets
import revolt_assets
import conclusion_chars
import ui_assets
from common import OUT, rng, math



def main():
    meta = {}
    chars.build_all()
    meta.update(env.build_all())
    meta.update(terrain.build_all())
    meta.update(buildings.build_all())
    meta.update(props.build_all())
    meta.update(ui_assets.generate())
    meta.update(player_assets.generate())
    meta.update(intro_assets.generate())
    meta.update(revolt_assets.generate())
    conclusion_chars.build_all()
    for cid in chars.CHARS:
        meta[f"chars/{cid}"] = {"hframes": 4, "vframes": 3, "origin": [8, 23]}
    meta["chars/shadow"] = {"hframes": 1, "origin": [7, 2]}

    placed = []          # objetos y-ordenados (árvores, casas, props)
    decor = []           # decoração rente ao chão (tufos, flores, pedras)
    anchors = {"smoke": [], "flames": [], "banners": [], "flags": [], "lilies": [], "fish": [],
               "chickens": []}

    def add(sprite, x, y, **kw):
        d = {"s": sprite, "p": [round(x), round(y)]}
        d.update(kw)
        placed.append(d)

    # ---------------- construções
    blocked_rects = []
    for bid, kind, x0, y0 in L.BUILDINGS:
        w, h, _door = L.BTYPES[kind]
        bottom = y0 + h * 32
        add(f"buildings/{kind}", x0, bottom, id=bid)
        blocked_rects.append((x0 - 22, y0 - 40, x0 + w * 32 + 22, bottom + 26))
        m = meta[f"buildings/{kind}"]
        if m.get("chimney"):
            cx, cy = m["chimney"]
            img_h = m["origin"][1]
            anchors["smoke"].append([x0 + cx * 2, bottom - (img_h - cy) * 2])
    cx0, cy0, cw, ch = L.CASTLE
    blocked_rects.append((cx0 - 30, 0, cx0 + cw + 30, cy0 + ch + 40))
    fx, fy, fw, fh = L.FARM
    blocked_rects.append((fx - 20, fy - 30, fx + fw + 30, fy + fh + 20))

    # ---------------- castelo (âncoras)
    castle = {"pos": [cx0, cy0], "gate": [640, 224], "throne": [640, 80],
              "banners": [[536, 6], [576, 6], [704, 6], [744, 6]],
              "wall_torches": [[600, 24], [680, 24], [470, 190], [810, 190]],
              "flags": [[480, 138], [800, 138]]}

    # ---------------- praça e locais
    loc = L.LOCATIONS
    add("props/fountain_base", 640, 422, layers=["props/fountain_pool", "props/fountain_base", "props/fountain_spray"])
    add("props/well", 548, 406)
    add("props/notice_board", 732, 372)
    add("props/stall", 716, 470)
    add("props/torch_post", 584, 344)
    anchors["flames"].append({"p": [584, 306], "base": 344, "kind": "torch"})
    add("props/torch_post", 696, 344)
    anchors["flames"].append({"p": [696, 306], "base": 344, "kind": "torch"})
    add("props/crate", 752, 486)
    add("props/barrel", 770, 470)
    add("props/signpost", 694, 540)
    # padaria
    add("props/table", 304, 462)
    add("props/oven", 196, 440)
    anchors["flames"].append({"p": [196, 428], "base": 441, "kind": "oven", "small": True})
    add("props/barrel", 392, 430)
    add("props/crate", 212, 468)
    # ferraria
    add("props/anvil", 930, 452)
    add("props/furnace", 870, 440)
    anchors["flames"].append({"p": [870, 428], "base": 441, "kind": "forge"})
    add("props/barrel", 1062, 432)
    add("props/crate", 1070, 458)
    add("props/log", 848, 470)
    # templo
    add("props/altar", 224, 746)
    anchors["flames"].append({"p": [205, 714], "base": 747, "kind": "candle", "small": True})
    anchors["flames"].append({"p": [243, 714], "base": 747, "kind": "candle", "small": True})
    add("props/beehive", 330, 700)
    # pátio do castelo
    add("props/target", 824, 280)
    add("props/haystack", 846, 300)
    add("props/barrel", 440, 262)
    add("props/crate", 460, 276)
    # fazenda
    for r in range(3):
        for c in range(4):
            add("env/crops", fx + c * 32 + 16, fy + r * 32 + 30, phase=(c * 0.37 + r * 0.61) % 1)
    add("props/fence_h4", fx, fy - 4)
    add("props/fence_h4", fx, fy + fh + 18)
    add("props/haystack", fx + fw + 24, fy + 40)
    add("props/bucket", fx + fw + 20, fy + 80)
    for i in range(6):
        anchors["chickens"].append([fx + 30 + (i % 3) * 36, fy - 40 - (i // 3) * 26])

    # ---------------- lago: nenúfares, peixes, juncos
    lx, ly, lrx, lry = L.LAKE
    r = rng(77)
    for i in range(7):
        a = r.uniform(0, math.tau)
        k = r.uniform(0.45, 0.85)
        anchors["lilies"].append([lx + math.cos(a) * lrx * k, ly + math.sin(a) * lry * k, r.random()])
    for i in range(9):
        anchors["fish"].append({"c": [lx + r.uniform(-90, 90), ly + r.uniform(-35, 35)], "r": r.uniform(20, 55),
                                "s": r.uniform(0.25, 0.7), "p": r.uniform(0, math.tau)})
    for i in range(16):
        a = r.uniform(0, math.tau)
        if -2.3 < a - math.pi * 1.5 < 2.3 and math.sin(a) < -0.2 and abs(math.cos(a)) < 0.4:
            continue
        x = lx + math.cos(a) * (lrx + 6)
        y = ly + math.sin(a) * (lry + 4)
        add("env/reeds", x, y + 6, phase=r.random())

    # ---------------- espalhamento de árvores
    def blocked(x, y, margin=0):
        c, rr = int(x // 32), int(y // 32)
        for dc in (-1, 0, 1):
            for dr in (-1, 0, 1):
                cell = (int((x + dc * (14 + margin)) // 32), int((y + dr * (10 + margin)) // 32))
                if cell in L.ROAD or cell in L.PLAZA or cell in L.STEPS:
                    return True
        for (a, b, cc, d) in blocked_rects:
            if a - margin < x < cc + margin and b - margin < y < d + margin:
                return True
        if ((x - lx) / (lrx + 34 + margin)) ** 2 + ((y - ly) / (lry + 30 + margin)) ** 2 < 1:
            return True
        for p in loc.values():
            if math.hypot(x - p[0], y - p[1]) < 46 + margin:
                return True
        for p in placed:
            if p["s"].startswith("props/") and math.hypot(x - p["p"][0], y - p["p"][1]) < 36 + margin:
                return True
        return False

    trees = []
    rt = rng(2026)
    for _ in range(9000):
        x, y = rt.uniform(10, 1270), rt.uniform(40, 955)
        forest = terrain._forest_dark(x / 2, y / 2)
        if not forest and rt.random() > 0.06:
            continue
        if blocked(x, y, 6):
            continue
        min_d = 40 if forest else 70
        if any(math.hypot(x - tx, (y - ty) * 1.3) < min_d for tx, ty, _ in trees):
            continue
        roll = rt.random()
        if forest:
            kind = ("env/tree_pine" if roll < 0.2 else "env/tree_pine_dark" if roll < 0.34 else
                    "env/tree_oak_dark" if roll < 0.58 else "env/tree_oak" if roll < 0.8 else
                    "env/tree_huge_dark" if roll < 0.88 else "env/tree_huge" if roll < 0.94 else "env/tree_oak_autumn")
        else:
            kind = ("env/tree_oak" if roll < 0.35 else "env/tree_apple" if roll < 0.55 else
                    "env/tree_blossom" if roll < 0.72 else "env/tree_oak_autumn" if roll < 0.86 else "env/tree_pine")
        trees.append((x, y, kind))
    for x, y, kind in trees:
        add(kind, x, y, phase=rt.random(), flip=rt.random() < 0.5)

    # arbustos, cogumelos, pedras grandes
    for _ in range(140):
        x, y = rt.uniform(10, 1270), rt.uniform(60, 955)
        if blocked(x, y, 0) or any(math.hypot(x - tx, y - ty) < 30 for tx, ty, _ in trees):
            continue
        roll = rt.random()
        k = ("env/bush" if roll < 0.45 else "env/bush_berry" if roll < 0.62 else "env/bush_flower" if roll < 0.78 else
             "env/rock_big" if roll < 0.9 else "env/mushroom")
        add(k, x, y, flip=rt.random() < 0.5)

    # decoração rente ao chão
    for _ in range(900):
        x, y = rt.uniform(4, 1276), rt.uniform(8, 956)
        cell = (int(x // 32), int(y // 32))
        if cell in L.ROAD or cell in L.PLAZA or cell in L.STEPS:
            continue
        if ((x - lx) / (lrx + 14)) ** 2 + ((y - ly) / (lry + 12)) ** 2 < 1:
            continue
        if any(a < x < c and b + 40 < y < d - 20 for (a, b, c, d) in blocked_rects[:len(L.BUILDINGS)]):
            continue
        if cx0 - 4 < x < cx0 + cw + 4 and y < cy0 + ch + 6:
            continue
        if fx < x < fx + fw and fy < y < fy + fh:
            continue
        roll = rt.random()
        if roll < 0.55:
            decor.append({"s": "env/tuft", "p": [round(x), round(y)], "phase": rt.random()})
        elif roll < 0.9:
            decor.append({"s": "env/flowers", "p": [round(x), round(y)], "phase": rt.random(), "row": rt.randrange(5)})
        else:
            decor.append({"s": "env/rock_small", "p": [round(x), round(y)]})

    world = {
        "meta": meta,
        "placed": placed,
        "decor": decor,
        "anchors": anchors,
        "castle": castle,
        "lake": {"center": [lx, ly], "rx": lrx, "ry": lry, "pos": meta["terrain/lake"]["pos"]},
        "locations": {k: list(v) for k, v in L.LOCATIONS.items()},
        "villagers": {k: list(v) for k, v in L.VILLAGERS.items()},
        "farm": list(L.FARM),
    }
    path = os.path.join(OUT, "map.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(world, f, ensure_ascii=False)
    print("placed", len(placed), "decor", len(decor), "trees", len(trees))


if __name__ == "__main__":
    main()
