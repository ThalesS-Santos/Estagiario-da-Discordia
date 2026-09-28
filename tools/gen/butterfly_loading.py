"""Gera a borboleta de loading (64x48) — estilo monarca pixel art."""
import os, sys, math
sys.path.insert(0, os.path.dirname(__file__))
from common import *

def gen_butterfly_loading():
    W, H = 64, 48
    img = new(W, H)
    cx = W // 2  # 32

    # Paleta
    out      = hexc("3f2631")
    body_dk  = hexc("5c3522")
    body     = hexc("8a5234")
    ant_col  = hexc("5c3522")
    ant_tip  = hexc("fee761")

    w_edge   = hexc("763b36")
    w_dark   = hexc("c34b35")
    w_base   = hexc("e38628")
    w_hot    = hexc("ff9b30")
    w_bright = hexc("fdbe53")
    w_glow   = hexc("ffe36b")
    w_inner  = hexc("fcbc8f")

    sp_out   = hexc("3f2631")
    sp_ring  = hexc("e8b43c")
    sp_core  = hexc("fee761")

    def fill_ellipse(cx_, cy_, rx, ry, color):
        for y_ in range(max(0, int(cy_-ry-1)), min(H, int(cy_+ry+2))):
            for x_ in range(max(0, int(cx_-rx-1)), min(W, int(cx_+rx+2))):
                if ((x_-cx_)/rx)**2 + ((y_-cy_)/ry)**2 <= 1.0:
                    put(img, x_, y_, color)

    def outline_ellipse(cx_, cy_, rx, ry, color):
        for a in range(360):
            rad = math.radians(a)
            x_ = int(cx_ + rx * math.cos(rad))
            y_ = int(cy_ + ry * math.sin(rad))
            put(img, x_, y_, color)

    # ======== ASAS SUPERIORES ========
    for side in (-1, 1):
        # Forma principal: elipse inclinada
        wcx = cx + side * 13
        wcy = 16
        wrx, wry = 12.5, 10.5

        # Preencher com gradiente radial
        for y in range(max(0,int(wcy-wry-2)), min(H,int(wcy+wry+2))):
            for x in range(max(0,int(wcx-wrx-2)), min(W,int(wcx+wrx+2))):
                dx_ = (x - wcx) / wrx
                dy_ = (y - wcy) / wry
                d = math.sqrt(dx_*dx_ + dy_*dy_)
                if d <= 1.0:
                    if d > 0.88:
                        put(img, x, y, w_edge)
                    elif d > 0.75:
                        put(img, x, y, w_dark)
                    elif d > 0.55:
                        put(img, x, y, w_base)
                    elif d > 0.35:
                        put(img, x, y, w_hot)
                    else:
                        put(img, x, y, w_bright)

        # Contorno
        outline_ellipse(wcx, wcy, wrx, wry, out)

        # Spots grandes (olho da asa)
        scx = cx + side * 14
        scy = 16
        fill_ellipse(scx, scy, 3.5, 3.5, sp_out)
        fill_ellipse(scx, scy, 2.3, 2.3, sp_ring)
        fill_ellipse(scx, scy, 1.2, 1.2, sp_core)

        # Spot menor superior
        scx2 = cx + side * 9
        scy2 = 10
        fill_ellipse(scx2, scy2, 2.0, 2.0, sp_out)
        fill_ellipse(scx2, scy2, 1.0, 1.0, sp_ring)

        # Veias (linhas do centro para fora)
        for angle_deg in (-30, 0, 30, 50, -50):
            rad = math.radians(angle_deg)
            for r in range(3, int(wrx)):
                vx = int(cx + side * (2 + r * math.cos(rad)))
                vy = int(wcy + r * math.sin(rad) * 0.8)
                dx_ = (vx - wcx) / wrx
                dy_ = (vy - wcy) / wry
                if dx_*dx_ + dy_*dy_ < 0.85:
                    cur = get(img, vx, vy)
                    if cur and cur[3] > 0 and cur != out:
                        put(img, vx, vy, w_edge)

    # ======== ASAS INFERIORES ========
    for side in (-1, 1):
        wcx = cx + side * 11
        wcy = 33
        wrx, wry = 10.5, 9.5

        for y in range(max(0,int(wcy-wry-2)), min(H,int(wcy+wry+2))):
            for x in range(max(0,int(wcx-wrx-2)), min(W,int(wcx+wrx+2))):
                dx_ = (x - wcx) / wrx
                dy_ = (y - wcy) / wry
                d = math.sqrt(dx_*dx_ + dy_*dy_)
                if d <= 1.0:
                    if d > 0.88:
                        put(img, x, y, w_edge)
                    elif d > 0.72:
                        put(img, x, y, w_dark)
                    elif d > 0.50:
                        put(img, x, y, w_base)
                    elif d > 0.30:
                        put(img, x, y, w_hot)
                    else:
                        put(img, x, y, w_inner)

        outline_ellipse(wcx, wcy, wrx, wry, out)

        # Borda inferior serrilhada (caudas da borboleta)
        tail_x = cx + side * 8
        for ty in range(int(wcy + wry), int(wcy + wry + 4)):
            put(img, tail_x, ty, w_edge)
            put(img, tail_x + side, ty, out)
        put(img, tail_x, int(wcy + wry + 4), out)

        # Spot na asa inferior
        scx = cx + side * 11
        scy = 33
        fill_ellipse(scx, scy, 2.5, 2.5, sp_out)
        fill_ellipse(scx, scy, 1.3, 1.3, sp_core)

        # Spots decorativos na borda
        for i in range(3):
            angle = math.radians(-40 + i * 40)
            sx_ = int(wcx + (wrx - 3) * math.cos(angle))
            sy_ = int(wcy + (wry - 3) * math.sin(angle))
            fill_ellipse(sx_, sy_, 1.3, 1.3, sp_out)
            put(img, sx_, sy_, sp_ring)

    # ======== CORPO ========
    fill_ellipse(cx - 0.5, 24, 2.0, 16.0, body)
    # Segmentação
    for y in range(10, 42, 2):
        put(img, cx-2, y, body_dk)
        put(img, cx+1, y, body_dk)
    # Contorno do corpo
    for y in range(8, 42):
        for dx in [-2, 1]:
            cur = get(img, cx+dx, y)
            if cur and cur[3] > 0:
                put(img, cx + dx + (-1 if dx < 0 else 1), y, out)

    # Cabeça (disco)
    fill_ellipse(cx - 0.5, 9, 2.8, 2.8, body)
    outline_ellipse(cx - 0.5, 9, 2.8, 2.8, out)

    # Olhos
    put(img, cx - 2, 9, sp_core)
    put(img, cx + 1, 9, sp_core)

    # Cauda afinando
    for y in range(40, 45):
        w = max(0, 2 - (y - 40))
        for dx in range(-w, w+1):
            put(img, cx + dx, y, body_dk if abs(dx) == 0 else out)
    put(img, cx, 45, out)

    # ======== ANTENAS ========
    # Curvas bezier-like
    for side in (-1, 1):
        pts = []
        for t in range(20):
            tt = t / 19.0
            x_ = cx + side * (1 + tt * 10 + tt*tt * 3)
            y_ = 8 - tt * 7 - math.sin(tt * 2.5) * 2
            pts.append((int(x_), int(y_)))
        for (x_, y_) in pts:
            put(img, x_, y_, ant_col)
        # Ponta brilhante
        if pts:
            lx, ly = pts[-1]
            put(img, lx, ly, ant_tip)
            put(img, lx+side, ly, ant_tip)
            put(img, lx, ly-1, ant_tip)

    # Limpar pixels soltos do corpo que ficaram sobre as asas
    # (o corpo deve ficar por cima)
    fill_ellipse(cx - 0.5, 24, 1.8, 15.5, body)
    for y in range(10, 40, 2):
        put(img, cx-1, y, body_dk)
        put(img, cx, y, body_dk)

    return img


if __name__ == "__main__":
    img = gen_butterfly_loading()
    out_path = os.path.join(ROOT, "assets", "butterfly_loading.png")
    img.save(out_path)
    print(f"Saved to {out_path} ({img.size[0]}x{img.size[1]})")
