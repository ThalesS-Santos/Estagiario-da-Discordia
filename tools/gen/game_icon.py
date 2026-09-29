"""Gera o ícone do jogo (128x128) — estagiário + borboleta, pixel art."""
import os, sys, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

def gen_icon():
    S = 128
    img = new(S, S)

    # Fundo: céu noturno gradiente com moldura
    bg_top = hexc("1a1a2e")
    bg_mid = hexc("262b44")
    bg_bot = hexc("3a4466")
    frame_col = hexc("e8b43c")
    frame_dk = hexc("a8641c")
    frame_in = hexc("5a6988")

    for y in range(S):
        t = y / (S - 1)
        r = int(bg_top[0] + (bg_bot[0] - bg_top[0]) * t)
        g = int(bg_top[1] + (bg_bot[1] - bg_top[1]) * t)
        b = int(bg_top[2] + (bg_bot[2] - bg_top[2]) * t)
        for x in range(S):
            put(img, x, y, (r, g, b, 255))

    # Estrelas
    import random
    rn = random.Random(42)
    star_cols = [hexc("fee761"), hexc("ffffff"), hexc("c0cbdc")]
    for _ in range(25):
        sx = rn.randint(6, S - 7)
        sy = rn.randint(6, 50)
        put(img, sx, sy, rn.choice(star_cols))

    # Moldura dourada (borda arredondada)
    corner = 8
    for y in range(S):
        for x in range(S):
            bx = min(x, S - 1 - x)
            by = min(y, S - 1 - y)
            if bx < 3 or by < 3:
                if bx + by < corner:
                    put(img, x, y, (0, 0, 0, 0))
                elif bx < 2 or by < 2:
                    if bx + by >= corner:
                        put(img, x, y, frame_dk)
                else:
                    put(img, x, y, frame_col)
            elif bx < 5 or by < 5:
                if bx + by < corner + 2:
                    put(img, x, y, frame_dk)
                elif bx == 3 or by == 3:
                    put(img, x, y, frame_col)
                elif bx == 4 or by == 4:
                    put(img, x, y, frame_in)

    # ======== ESTAGIÁRIO (centro-esquerda, de frente) ========
    # Posição base
    ex, ey = 42, 52

    # Cabelo castanho
    hair = hexc("5c3522")
    hair_d = hexc("3f2631")
    for dx in range(-5, 6):
        put(img, ex + dx, ey, hair)
        put(img, ex + dx, ey + 1, hair)
    for dx in range(-6, 7):
        put(img, ex + dx, ey + 2, hair)
    for dx in range(-6, 7):
        put(img, ex + dx, ey + 3, hair)
    # Topete
    for dx in range(-3, 4):
        put(img, ex + dx, ey - 1, hair)
    for dx in range(-2, 3):
        put(img, ex + dx, ey - 2, hair_d)

    # Cabeça (pele)
    skin = hexc("f0c29a")
    skin_d = hexc("c98d6a")
    out_c = hexc("3f2631")
    for dy in range(4, 12):
        w = 6 if dy < 10 else (5 if dy < 11 else 4)
        for dx in range(-w, w + 1):
            put(img, ex + dx, ey + dy, skin)
        put(img, ex - w - 1, ey + dy, out_c)
        put(img, ex + w + 1, ey + dy, out_c)
    # Sombra do queixo
    for dx in range(-3, 4):
        put(img, ex + dx, ey + 10, skin_d)

    # Olhos
    eye_c = hexc("262b44")
    put(img, ex - 3, ey + 6, eye_c)
    put(img, ex - 3, ey + 7, eye_c)
    put(img, ex + 3, ey + 6, eye_c)
    put(img, ex + 3, ey + 7, eye_c)

    # Boca
    put(img, ex - 1, ey + 9, out_c)
    put(img, ex, ey + 9, out_c)
    put(img, ex + 1, ey + 9, out_c)

    # Paletó marrom
    coat = hexc("8a5234")
    coat_d = hexc("5c3522")
    shirt = hexc("c0cbdc")
    tie = hexc("c34b35")
    tie_d = hexc("8a2a2a")

    for dy in range(12, 30):
        bw = 7 + (dy - 12) // 5
        if bw > 10:
            bw = 10
        for dx in range(-bw, bw + 1):
            if abs(dx) <= 1:
                if dy < 15:
                    put(img, ex + dx, ey + dy, shirt)
                elif dx == 0:
                    put(img, ex + dx, ey + dy, tie)
                else:
                    put(img, ex + dx, ey + dy, coat)
            else:
                put(img, ex + dx, ey + dy, coat)
        # Contorno
        put(img, ex - bw - 1, ey + dy, out_c)
        put(img, ex + bw + 1, ey + dy, out_c)
        # Sombra interna
        put(img, ex - bw, ey + dy, coat_d)
        put(img, ex + bw, ey + dy, coat_d)

    # Gravata nó
    put(img, ex, ey + 12, tie)
    put(img, ex, ey + 13, tie_d)
    put(img, ex, ey + 14, tie)

    # Calça escura
    pants = hexc("3a4466")
    pants_d = hexc("262b44")
    for dy in range(30, 40):
        pw = 8
        for dx in range(-pw, pw + 1):
            if abs(dx) <= 1:
                put(img, ex + dx, ey + dy, pants_d)
            else:
                put(img, ex + dx, ey + dy, pants)
        put(img, ex - pw - 1, ey + dy, out_c)
        put(img, ex + pw + 1, ey + dy, out_c)

    # Sapatos
    shoe = hexc("3f2631")
    for dx in range(-8, -2):
        put(img, ex + dx, ey + 40, shoe)
        put(img, ex + dx, ey + 41, shoe)
    for dx in range(3, 9):
        put(img, ex + dx, ey + 40, shoe)
        put(img, ex + dx, ey + 41, shoe)

    # Braços
    for dy in range(14, 26):
        put(img, ex - 9, ey + dy, coat)
        put(img, ex - 10, ey + dy, coat_d)
        put(img, ex - 11, ey + dy, out_c)
        put(img, ex + 9, ey + dy, coat)
        put(img, ex + 10, ey + dy, coat_d)
        put(img, ex + 11, ey + dy, out_c)
    # Mãos
    for dx in [-10, -9, 9, 10]:
        put(img, ex + dx, ey + 26, skin)
        put(img, ex + dx, ey + 27, skin)

    # ======== BORBOLETA (canto superior direito) ========
    bx, by = 88, 28

    w_edge = hexc("763b36")
    w_dark = hexc("c34b35")
    w_base = hexc("e38628")
    w_hot = hexc("ff9b30")
    w_bright = hexc("fdbe53")
    w_glow = hexc("ffe36b")
    sp_out = hexc("3f2631")
    sp_ring = hexc("e8b43c")
    sp_core = hexc("fee761")
    body_c = hexc("5c3522")
    ant_c = hexc("5c3522")
    ant_tip = hexc("fee761")

    def fill_ellipse(cx_, cy_, rx, ry, color):
        for y_ in range(max(0, int(cy_ - ry - 1)), min(S, int(cy_ + ry + 2))):
            for x_ in range(max(0, int(cx_ - rx - 1)), min(S, int(cx_ + rx + 2))):
                if ((x_ - cx_) / rx) ** 2 + ((y_ - cy_) / ry) ** 2 <= 1.0:
                    put(img, x_, y_, color)

    def outline_ellipse(cx_, cy_, rx, ry, color):
        for a in range(360):
            rad = math.radians(a)
            x_ = int(cx_ + rx * math.cos(rad))
            y_ = int(cy_ + ry * math.sin(rad))
            put(img, x_, y_, color)

    def wing_fill(wcx, wcy, wrx, wry):
        for y in range(max(0, int(wcy - wry - 2)), min(S, int(wcy + wry + 2))):
            for x in range(max(0, int(wcx - wrx - 2)), min(S, int(wcx + wrx + 2))):
                dx_ = (x - wcx) / wrx
                dy_ = (y - wcy) / wry
                d = math.sqrt(dx_ * dx_ + dy_ * dy_)
                if d <= 1.0:
                    if d > 0.85:
                        put(img, x, y, w_edge)
                    elif d > 0.70:
                        put(img, x, y, w_dark)
                    elif d > 0.50:
                        put(img, x, y, w_base)
                    elif d > 0.30:
                        put(img, x, y, w_hot)
                    else:
                        put(img, x, y, w_bright)

    # Asas superiores
    for side in (-1, 1):
        wcx = bx + side * 11
        wcy = by - 4
        wing_fill(wcx, wcy, 10, 8)
        outline_ellipse(wcx, wcy, 10, 8, sp_out)
        # Spot
        fill_ellipse(wcx + side * 1, wcy, 3, 3, sp_out)
        fill_ellipse(wcx + side * 1, wcy, 2, 2, sp_ring)
        fill_ellipse(wcx + side * 1, wcy, 1, 1, sp_core)

    # Asas inferiores
    for side in (-1, 1):
        wcx = bx + side * 9
        wcy = by + 10
        wing_fill(wcx, wcy, 8, 7)
        outline_ellipse(wcx, wcy, 8, 7, sp_out)
        fill_ellipse(wcx, wcy, 2, 2, sp_out)
        fill_ellipse(wcx, wcy, 1, 1, sp_core)

    # Corpo da borboleta
    fill_ellipse(bx, by + 2, 1.8, 12, body_c)
    for y in range(by - 9, by + 14, 2):
        put(img, bx, y, sp_out)

    # Cabeça
    fill_ellipse(bx, by - 9, 2.5, 2.5, body_c)
    outline_ellipse(bx, by - 9, 2.5, 2.5, sp_out)
    put(img, bx - 1, by - 10, sp_core)
    put(img, bx + 1, by - 10, sp_core)

    # Antenas
    for side in (-1, 1):
        for t in range(15):
            tt = t / 14.0
            ax = int(bx + side * (1 + tt * 8))
            ay = int(by - 10 - tt * 6 - math.sin(tt * 2.5) * 1.5)
            put(img, ax, ay, ant_c)
        lx = int(bx + side * 9)
        ly = int(by - 16 - math.sin(2.5) * 1.5)
        put(img, lx, ly, ant_tip)
        put(img, lx + side, ly, ant_tip)

    # ======== BRILHOS / PARTÍCULAS ========
    sparkle = hexc("fee761")
    sparkle2 = hexc("ffe36b")
    spark_positions = [(25, 30), (68, 18), (105, 45), (18, 70), (110, 75),
                       (30, 15), (60, 42), (100, 25), (55, 85), (15, 50)]
    for sx, sy in spark_positions:
        brd = min(sx, sy, S - 1 - sx, S - 1 - sy)
        if brd > 5:
            cur = get(img, sx, sy)
            if cur[3] == 255 and cur == get(img, sx + 1, sy):
                continue
            put(img, sx, sy, sparkle)
            put(img, sx + 1, sy, sparkle2)
            put(img, sx, sy - 1, sparkle2)

    # ======== CHÃO simples ========
    grass = hexc("479f4a")
    grass_l = hexc("84c669")
    for y in range(100, S - 5):
        for x in range(6, S - 6):
            cur = get(img, x, y)
            if cur[:3] == bg_bot[:3] or (cur[0] > bg_mid[0] - 5 and cur[1] < bg_mid[1] + 5):
                put(img, x, y, grass if (x + y) % 3 else grass_l)

    return img


if __name__ == "__main__":
    img = gen_icon()
    out_path = os.path.join(ROOT, "icon_game.png")
    img.save(out_path)
    print(f"Saved to {out_path} ({img.size[0]}x{img.size[1]})")
    # Também salvar como icon.png para uso no Godot
    icon_path = os.path.join(ROOT, "icon.png")
    img.save(icon_path)
    print(f"Saved to {icon_path}")
