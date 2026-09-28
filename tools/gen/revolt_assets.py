"""Gera assets para a cena da revolta: fogo em prédios e armas camponesas."""
import random
from common import *


def _fire_frame(w, h, seed):
    r = random.Random(seed)
    img = new(w, h)
    cols = [C["flame_l"], C["flame"], C["flame_d"], C["red"]]
    for x in range(w):
        col_h = int(h * r.uniform(0.35, 1.0))
        for yo in range(col_h):
            y = h - 1 - yo
            t = yo / max(col_h - 1, 1)
            ci = 0 if t > 0.65 else (1 if t > 0.35 else (2 if t > 0.12 else 3))
            a = int(255 * min(1.0, (1.0 - t) * 1.6))
            if r.random() < 0.18:
                a = int(a * 0.45)
            put(img, x, y, cols[ci][:3] + (a,))
    return img


def building_fire():
    return hstrip([_fire_frame(16, 24, i * 42 + 7) for i in range(4)])


def castle_fire():
    return hstrip([_fire_frame(24, 32, i * 37 + 13) for i in range(4)])


def revolt_weapons():
    # Forcado
    p = new(8, 16)
    for y in range(4, 16):
        put(p, 4, y, C["wood"])
    for x in [2, 4, 6]:
        put(p, x, 2, C["stone_l"])
        put(p, x, 3, C["stone_l"])
    for x in range(2, 7):
        put(p, x, 4, C["stone"])
    outline(p, C["out"])

    # Tocha acesa
    t = new(8, 16)
    for y in range(7, 16):
        put(t, 4, y, C["wood"])
    put(t, 3, 7, C["wood_d"])
    put(t, 5, 7, C["wood_d"])
    put(t, 4, 3, C["flame_l"])
    put(t, 3, 4, C["flame"])
    put(t, 4, 4, C["flame_l"])
    put(t, 5, 4, C["flame"])
    put(t, 3, 5, C["flame_d"])
    put(t, 4, 5, C["flame"])
    put(t, 5, 5, C["flame_d"])
    put(t, 4, 6, C["flame_d"])
    outline(t, C["out"])

    # Martelo
    h = new(8, 16)
    for y in range(6, 16):
        put(h, 4, y, C["wood"])
    rect(h, 2, 3, 5, 3, C["stone"])
    rect(h, 3, 3, 3, 3, C["stone_l"])
    outline(h, C["out"])

    # Enxada
    e = new(8, 16)
    for y in range(5, 16):
        put(e, 4, y, C["wood"])
    put(e, 3, 3, C["stone"])
    put(e, 4, 3, C["stone_l"])
    put(e, 5, 3, C["stone"])
    put(e, 2, 4, C["stone"])
    put(e, 3, 4, C["stone_l"])
    put(e, 4, 4, C["stone"])
    put(e, 5, 4, C["stone"])
    outline(e, C["out"])

    return hstrip([p, t, h, e])


def generate():
    save(building_fire(), "fx/building_fire.png")
    save(castle_fire(), "fx/castle_fire.png")
    save(revolt_weapons(), "props/revolt_weapons.png")
    return {
        "fx/building_fire": {"hframes": 4},
        "fx/castle_fire": {"hframes": 4},
        "props/revolt_weapons": {"hframes": 4},
    }


if __name__ == "__main__":
    generate()
    print("Revolt assets OK")
