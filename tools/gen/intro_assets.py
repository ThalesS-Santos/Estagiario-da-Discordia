"""Abertura em primeira pessoa (visor de pulso do estagiário) e portal de chegada na vila.

Camadas da abertura em 320x180 (a tela 1280x720 dividida por 4). Cada camada tem o tamanho
da tela inteira para o Godot só empilhar TextureRects com escala 4.
O antebraço é desenhado na horizontal e inclinado por cisalhamento de colunas (1 px a cada
SLOPE colunas), o que mantém a pixel art limpa (sem rotação com serrilhado).
"""
from PIL import ImageDraw

from common import C, hexc, mix, new, save, get, outline, rng, math, hstrip

W, H = 320, 180
SLOPE = 5

CY = C["water_l"]
CY_L = hexc("b9f6ff")
CY_M = C["water"]
CY_D = C["teal_d"]
GLASS = hexc("0b2a33")
GLASS_D = hexc("06161d")
METAL = C["stone_dd"]
METAL_D = C["out2"]
METAL_L = C["stone_d"]
METAL_H = C["stone"]
OUT = C["out"]
SKIN = C["skin"]
SKIN_D = C["skin_d"]
SKIN_L = mix(C["skin"], C["white"], 0.35)
SKIN_C = C["skin2"]
JK = C["brown"]
JK_D = C["brown_d"]
JK_L = C["brown_l"]
JK_DD = mix(C["brown_d"], C["out"], 0.5)

# retângulo do holograma (coordenadas da tela 320x180)
PANEL = (36, 6, 284, 100)


def _a(c, a):
    return c[:3] + (int(a),)


def _px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height and c is not None:
        img.putpixel((int(x), int(y)), c)


def _dither(x, y, t):
    """Pontilhado ordenado 4x4: True se o pixel (x, y) recebe o tom de intensidade t (0..1)."""
    m = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
    return t * 16.0 > m[y % 4][x % 4] + 0.5


def _shear(local, ox, oy, rising_right=True, slope=SLOPE):
    """Cola a imagem local na tela deslocando cada coluna 1 px para cima a cada `slope` colunas."""
    out = new(W, H)
    lw = local.width
    for x in range(lw):
        dy = -(x // slope) if rising_right else -((lw - 1 - x) // slope)
        for y in range(local.height):
            p = local.getpixel((x, y))
            if p[3]:
                _px(out, x + ox, y + oy + dy, p)
    return out


def _shear_pt(x, y, ox, oy, lw=0, rising_right=True, slope=SLOPE):
    dy = -(x // slope) if rising_right else -((lw - 1 - x) // slope)
    return (x + ox, y + oy + dy)


# ======================================================================== braço esquerdo
AX = 60          # eixo do antebraço na imagem local
LW, LH = 300, 120
MOD = (202, AX - 17, 228, AX + 14)       # módulo do visor (x0, y0, x1, y1) local
SCR = (205, AX - 13, 225, AX + 9)        # tela do módulo
EMIT = (215, AX - 19)                    # lente emissora do holograma
ARM_OX, ARM_OY = -30, 118                # onde a imagem local cai na tela


def _sleeve(img, x0, x1, hw0, hw1, hem_at_end=True, cuff_side="right"):
    """Manga do paletó entre x0 e x1 (local), com meia-largura interpolada hw0 -> hw1."""
    for x in range(x0, x1):
        t = (x - x0) / max(x1 - x0 - 1, 1)
        hw = hw0 + (hw1 - hw0) * t
        top, bot = round(AX - hw), round(AX + hw)
        for y in range(top, bot + 1):
            v = (y - top) / max(bot - top, 1)
            if v < 0.12:
                c = JK_L
            elif v < 0.2:
                c = JK_L if _dither(x, y, 0.5) else JK
            elif v > 0.84:
                c = JK_DD if v > 0.93 else JK_D
            elif v > 0.72:
                c = JK_D if _dither(x, y, 0.5) else JK
            else:
                c = JK
            _px(img, x, y, c)
    d = ImageDraw.Draw(img)
    # dobras do tecido: curtas e irregulares, mais juntas perto do punho (o tecido embola ali)
    span = x1 - x0
    near_cuff = (0.93, 0.86, 0.8, 0.62, 0.35) if cuff_side == "right" else (0.07, 0.14, 0.2, 0.38, 0.65)
    r = rng(x0 * 7 + x1)
    for k in near_cuff:
        cx = x0 + int(span * k)
        hw = hw0 + (hw1 - hw0) * k
        y0 = AX - hw + r.randint(4, 9)
        ln = r.randint(8, 14)
        lean = r.choice((3, 4, 5)) * (1 if cuff_side == "right" else -1)
        d.line([(cx, y0), (cx + lean, y0 + ln)], fill=JK_D)
        d.line([(cx - 1, y0 + 1), (cx - 1 + lean, y0 + ln - 1)], fill=JK_L)
        if r.random() < 0.6:
            y1 = AX + r.randint(2, 8)
            d.line([(cx + lean + 1, y1), (cx + lean + 4, y1 + r.randint(4, 7))], fill=JK_D)
    # barra da manga (bainha escura com pesponto)
    hx0, hx1 = (x1 - 9, x1) if cuff_side == "right" else (x0, x0 + 9)
    hw = hw1 if cuff_side == "right" else hw0
    for x in range(hx0, hx1):
        for y in range(round(AX - hw), round(AX + hw) + 1):
            if get(img, x, y)[3]:
                v = (y - (AX - hw)) / (2 * hw)
                _px(img, x, y, JK_D if v < 0.8 else JK_DD)
    sx = hx0 + 2 if cuff_side == "right" else hx1 - 3
    for y in range(round(AX - hw) + 2, round(AX + hw) - 1, 3):
        _px(img, sx, y, JK_L)
    # botões da manga
    bx = hx0 - 5 if cuff_side == "right" else hx1 + 2
    for i in range(2):
        by = round(AX + hw - 7)
        x = bx - i * 6 if cuff_side == "right" else bx + i * 6
        for dx, dy, c in ((0, 0, JK_DD), (1, 0, JK_DD), (0, 1, JK_DD), (1, 1, JK_DD), (0, 0, C["gold_d"]), (1, 0, C["gold"])):
            _px(img, x + dx, by + dy, c)


def _cuff(img, x0, x1, hw):
    for x in range(x0, x1):
        for y in range(AX - hw, AX + hw + 1):
            v = (y - (AX - hw)) / (2 * hw)
            c = C["white"] if v < 0.72 else C["grey_l"]
            if v > 0.9:
                c = C["grey"]
            _px(img, x, y, c)
    for y in range(AX - hw, AX + hw + 1):
        _px(img, x1 - 1, y, C["grey_l"])


def _hand_left(img, x0):
    """Costas da mão esquerda em punho relaxado, dedos para a direita; polegar do lado de baixo."""
    # dorso
    for x in range(x0, x0 + 24):
        t = (x - x0) / 23
        top = round(AX - 15 - 2 * t)
        bot = round(AX + 13 + 1 * t)
        for y in range(top, bot + 1):
            v = (y - top) / max(bot - top, 1)
            c = SKIN_L if v < 0.14 else (SKIN_D if v > 0.86 else SKIN)
            _px(img, x, y, c)
    # tendões suaves até os nós dos dedos
    for yy in (AX - 9, AX - 2, AX + 5):
        for x in range(x0 + 5, x0 + 20):
            if (x + yy) % 2 == 0:
                _px(img, x, yy, mix(SKIN, SKIN_D, 0.45))
    # dedos dobrados (mínimo em cima, indicador embaixo)
    fingers = [(AX - 17, 6), (AX - 10, 7), (AX - 2, 7), (AX + 6, 7)]
    fx0 = x0 + 21
    for i, (fy, fh) in enumerate(fingers):
        ln = 10 + (1 if i in (1, 2) else 0)
        for x in range(fx0, fx0 + ln):
            for y in range(fy, fy + fh):
                edge_r = x == fx0 + ln - 1 and (y == fy or y == fy + fh - 1)
                if edge_r:
                    continue
                v = (y - fy) / max(fh - 1, 1)
                c = SKIN
                if x >= fx0 + ln - 4:
                    c = SKIN_D                      # parte que dobra para baixo
                elif v < 0.3:
                    c = SKIN_L
                elif v > 0.8:
                    c = SKIN_D
                _px(img, x, y, c)
        # nó do dedo
        _px(img, fx0 + 1, fy + fh // 2 - 1, SKIN_L)
        _px(img, fx0 + 2, fy + fh // 2 - 1, SKIN_L)
        _px(img, fx0 + 1, fy + fh // 2, SKIN_L)
        # vinco entre dedos
        if i < len(fingers) - 1:
            for x in range(fx0 - 1, fx0 + ln):
                _px(img, x, fy + fh, SKIN_C)
    # polegar deitado ao longo do indicador, saindo por baixo do dorso
    for x in range(x0 + 4, x0 + 29):
        t = (x - x0 - 4) / 24
        top = round(AX + 12 + 1.5 * t)
        bot = round(AX + 21 - 1.5 * t)
        if x >= x0 + 27:
            top += 1
            bot -= 1
        for y in range(top, bot + 1):
            v = (y - top) / max(bot - top, 1)
            c = SKIN_L if v < 0.3 else (SKIN_D if v > 0.7 else SKIN)
            _px(img, x, y, c)
    # vinco que separa polegar e dorso + unha
    for x in range(x0 + 5, x0 + 27):
        t = (x - x0 - 4) / 24
        _px(img, x, round(AX + 12 + 1.5 * t) - 1, SKIN_C)
    for x in range(x0 + 23, x0 + 27):
        _px(img, x, AX + 15, mix(SKIN_L, C["white"], 0.4))
    _px(img, x0 + 24, AX + 16, mix(SKIN_L, C["white"], 0.4))


def _device(img):
    """Pulseira + módulo do visor Panóptico sobre o punho."""
    bx0, bx1 = 204, 226
    for x in range(bx0, bx1):
        for y in range(AX - 21, AX + 22):
            v = (y - (AX - 21)) / 42
            c = METAL
            if v < 0.08:
                c = METAL_L
            elif v > 0.9:
                c = METAL_D
            if x in (bx0, bx1 - 1):
                c = METAL_D
            _px(img, x, y, c)
    for x in (207, 223):
        for y in range(AX - 20, AX + 21):
            _px(img, x, y, METAL_D)
    mx0, my0, mx1, my1 = MOD
    for x in range(mx0, mx1):
        for y in range(my0, my1):
            c = METAL_L
            if y == my0 or x == mx0:
                c = METAL_H
            elif y == my1 - 1 or x == mx1 - 1:
                c = METAL_D
            elif y == my1 - 2 or x == mx1 - 2:
                c = METAL
            _px(img, x, y, c)
    # cantos arredondados
    for x, y in ((mx0, my0), (mx1 - 1, my0), (mx0, my1 - 1), (mx1 - 1, my1 - 1)):
        _px(img, x, y, (0, 0, 0, 0))
    sx0, sy0, sx1, sy1 = SCR
    for x in range(sx0 - 1, sx1 + 1):
        for y in range(sy0 - 1, sy1 + 1):
            _px(img, x, y, METAL_D)
    for x in range(sx0, sx1):
        for y in range(sy0, sy1):
            _px(img, x, y, GLASS_D)
    # lente emissora (holograma sai daqui)
    ex, ey = EMIT
    for x in range(ex - 3, ex + 3):
        for y in range(ey, ey + 3):
            _px(img, x, y, METAL_D)
    for x in range(ex - 2, ex + 2):
        _px(img, x, ey + 1, CY_M)
    _px(img, ex - 1, ey + 1, CY_L)
    # botão lateral e LEDs da pulseira
    for y in range(AX - 6, AX - 1):
        _px(img, mx1, y, METAL_H)
        _px(img, mx1 + 1, y, METAL_D)
    _px(img, 209, AX + 17, C["red_l"])
    _px(img, 212, AX + 17, C["leaf_hh"])
    _px(img, 215, AX + 17, CY)
    for x in range(mx0 + 3, mx1 - 3, 2):
        _px(img, x, my1 - 3, METAL)


def left_arm():
    local = new(LW, LH)
    _sleeve(local, 0, 204, 28, 23)
    _cuff(local, 198, 206, 20)
    for x in range(226, 234):
        for y in range(AX - 16, AX + 17):
            v = (y - (AX - 16)) / 32
            _px(local, x, y, SKIN_L if v < 0.12 else (SKIN_D if v > 0.82 else SKIN))
    _hand_left(local, 231)
    _device(local)
    arm = outline(_shear(local, ARM_OX, ARM_OY), OUT)
    return arm, local


def device_screen_frames():
    """4 quadros da telinha do módulo: desligada, chiado, olho Panóptico, olho brilhando."""
    frames = []
    sx0, sy0, sx1, sy1 = SCR
    r = rng(11)
    eye = [
        "....XXXXXX....",
        "..XX......XX..",
        ".X...XXXX...X.",
        "X...X.oo.X...X",
        "X...X.oo.X...X",
        ".X...XXXX...X.",
        "..XX......XX..",
        "....XXXXXX....",
    ]
    for f in range(4):
        local = new(LW, LH)
        for x in range(sx0, sx1):
            for y in range(sy0, sy1):
                if f == 0:
                    c = GLASS_D
                    if x - sx0 + (y - sy0) in (3, 4):
                        c = mix(GLASS_D, METAL_L, 0.5)       # reflexo no vidro
                elif f == 1:
                    n = r.random()
                    c = CY_L if n > 0.86 else (CY_M if n > 0.6 else (GLASS if n > 0.3 else GLASS_D))
                else:
                    c = GLASS
                    if (y - sy0) % 2 == 1:
                        c = mix(GLASS, GLASS_D, 0.6)
                _px(local, x, y, c)
        if f >= 2:
            ex0 = sx0 + (sx1 - sx0 - 14) // 2
            ey0 = sy0 + 4
            for j, row in enumerate(eye):
                for i, ch in enumerate(row):
                    if ch == "X":
                        _px(local, ex0 + i, ey0 + j, CY if f == 2 else CY_L)
                    elif ch == "o":
                        _px(local, ex0 + i, ey0 + j, CY_L if f == 2 else C["white"])
            # barrinhas de status embaixo do olho
            for i in range(3 if f == 2 else 5):
                _px(local, sx0 + 3 + i * 3, sy1 - 4, CY_M)
                _px(local, sx0 + 4 + i * 3, sy1 - 4, CY_M)
        frames.append(_shear(local, ARM_OX, ARM_OY))
    return frames


# ======================================================================== mão direita (toque)
RLW = 170
R_TIP = (4, AX + 7)          # ponta do indicador (local)


def right_hand_local():
    local = new(RLW, LH)
    _sleeve(local, 60, RLW, 22, 27, cuff_side="left")
    _cuff(local, 54, 62, 19)
    # punho/pulso
    for x in range(46, 56):
        for y in range(AX - 15, AX + 16):
            v = (y - (AX - 15)) / 30
            _px(local, x, y, SKIN_L if v < 0.12 else (SKIN_D if v > 0.82 else SKIN))
    # dorso da mão direita (dedos para a esquerda)
    for x in range(24, 48):
        t = (48 - x) / 24
        top = round(AX - 14 - 2 * t)
        bot = round(AX + 12 + 1 * t)
        for y in range(top, bot + 1):
            v = (y - top) / max(bot - top, 1)
            _px(local, x, y, SKIN_L if v < 0.14 else (SKIN_D if v > 0.86 else SKIN))
    # dedos dobrados (mínimo, anelar, médio)
    for i, (fy, fh) in enumerate([(AX - 16, 6), (AX - 9, 7), (AX - 1, 6)]):
        for x in range(14, 26):
            for y in range(fy, fy + fh):
                if x == 14 and (y == fy or y == fy + fh - 1):
                    continue
                v = (y - fy) / max(fh - 1, 1)
                c = SKIN_D if x < 18 else (SKIN_L if v < 0.3 else (SKIN_D if v > 0.8 else SKIN))
                _px(local, x, y, c)
        for x in range(14, 27):
            _px(local, x, fy + fh, SKIN_C)
        _px(local, 24, fy + fh // 2 - 1, SKIN_L)
    # indicador esticado apontando para a esquerda
    for x in range(R_TIP[0], 26):
        top, bot = AX + 6, AX + 12
        if x < R_TIP[0] + 2:
            top += 1
            bot -= 1
        for y in range(top, bot + 1):
            v = (y - top) / max(bot - top, 1)
            _px(local, x, y, SKIN_L if v < 0.3 else (SKIN_D if v > 0.75 else SKIN))
    for x in range(R_TIP[0] + 1, R_TIP[0] + 4):
        _px(local, x, AX + 8, mix(SKIN_L, C["white"], 0.3))     # unha
    for x in (12, 18):
        _px(local, x, AX + 7, SKIN_C)                            # articulações
    # polegar por baixo
    for x in range(22, 44):
        t = (44 - x) / 22
        top = round(AX + 12 + 1.2 * t)
        bot = round(AX + 18 - 0.8 * t)
        for y in range(top, bot + 1):
            v = (y - top) / max(bot - top, 1)
            _px(local, x, y, SKIN_L if v < 0.25 else (SKIN_D if v > 0.75 else SKIN))
    return local


R_SLOPE = 2      # a mão direita vem de baixo, mais inclinada


def right_hand(tip_screen):
    """Mão direita posicionada para a ponta do indicador tocar `tip_screen` (pose do toque)."""
    local = right_hand_local()
    tx, ty = _shear_pt(R_TIP[0], R_TIP[1], 0, 0, RLW, rising_right=False, slope=R_SLOPE)
    ox, oy = tip_screen[0] - tx, tip_screen[1] - ty
    return outline(_shear(local, ox, oy, rising_right=False, slope=R_SLOPE), OUT)


# ======================================================================== fundo: sala de salto
def bay_frames():
    frames = []
    cx, cy = 160, 128
    for f in range(4):
        img = new(W, H, hexc("0c0f19"))
        # placas do piso
        pw, ph = 32, 20
        for y in range(H):
            for x in range(W):
                gx, gy = x // pw, (y + 6) // ph
                c = hexc("121626") if (gx + gy) % 2 == 0 else hexc("10131f")
                lx, ly = x % pw, (y + 6) % ph
                if lx == 0 or ly == 0:
                    c = hexc("080a12")
                elif lx == 1 or ly == 1:
                    c = hexc("1b2135")
                if (lx, ly) in ((3, 3), (pw - 3, 3), (3, ph - 3), (pw - 3, ph - 3)):
                    c = hexc("2a3350")
                img.putpixel((x, y), c)
        # plataforma de salto
        for y in range(H):
            for x in range(W):
                e = ((x + 0.5 - cx) / 150) ** 2 + ((y + 0.5 - cy) / 66) ** 2
                if e < 1.0:
                    k = math.sqrt(e)
                    base = img.getpixel((x, y))
                    if k < 0.62:
                        c = mix(base, hexc("0f2a36"), 0.8)
                        if (x + y * 2) % 12 == 0 or (x - y * 2) % 12 == 0:
                            c = mix(c, CY_D, 0.6)            # grade hexagonal
                        img.putpixel((x, y), c)
                    elif 0.62 <= k < 0.66:
                        img.putpixel((x, y), CY_D)
                    elif 0.8 <= k < 0.84:
                        img.putpixel((x, y), mix(base, CY_M, 0.35))
                    elif 0.93 <= k < 1.0:
                        ang = math.degrees(math.atan2((y - cy) / 66, (x - cx) / 150)) % 360
                        seg = (ang + f * 4) % 15
                        c = CY if seg < 7 else mix(CY_D, base, 0.3)
                        if k > 0.975:
                            c = mix(c, base, 0.5)
                        img.putpixel((x, y), c)
        # onda de energia que corre para dentro
        wave = [0.9, 0.76, 0.52, 0.34][f]
        for y in range(H):
            for x in range(W):
                k = math.sqrt(((x + 0.5 - cx) / 150) ** 2 + ((y + 0.5 - cy) / 66) ** 2)
                if abs(k - wave) < 0.018:
                    img.putpixel((x, y), mix(img.getpixel((x, y)), CY_L, 0.55))
        # luzes de piso nas bordas
        for i in range(6):
            for x0 in (12, W - 16):
                y0 = 20 + i * 28
                c = CY if (i + f) % 3 else CY_L
                for dx in range(4):
                    img.putpixel((x0 + dx, y0), c)
                    img.putpixel((x0 + dx, y0 + 1), CY_D)
        # vinheta pontilhada
        for y in range(H):
            for x in range(W):
                dx = abs(x + 0.5 - W / 2) / (W / 2)
                dy = abs(y + 0.5 - H / 2) / (H / 2)
                v = max(0.0, (dx * dx + dy * dy) ** 0.5 - 0.72) / 0.5
                if v > 0 and _dither(x, y, min(v, 1.0)):
                    img.putpixel((x, y), mix(img.getpixel((x, y)), hexc("05060b"), 0.65))
        frames.append(img)
    return frames


# ======================================================================== holograma
def holo_panel():
    x0, y0, x1, y1 = PANEL
    img = new(W, H)
    for y in range(y0, y1):
        for x in range(x0, x1):
            a = 212 if (y - y0) % 2 == 0 else 196
            c = _a(GLASS_D, a)
            if (x - x0) % 8 == 0 and (y - y0) % 8 == 0:
                c = _a(CY_D, 230)                               # grade de pontos
            img.putpixel((x, y), c)
    # faixa do cabeçalho
    for y in range(y0 + 1, y0 + 12):
        for x in range(x0 + 1, x1 - 1):
            img.putpixel((x, y), _a(mix(GLASS, CY_D, 0.4), 225))
    for x in range(x0 + 1, x1 - 1):
        img.putpixel((x, y0 + 12), _a(CY_M, 220))
    # borda + brilho externo
    for x in range(x0, x1):
        img.putpixel((x, y0), _a(CY, 240))
        img.putpixel((x, y1 - 1), _a(CY, 240))
        img.putpixel((x, y0 - 1), _a(CY, 70))
        img.putpixel((x, y1), _a(CY, 70))
    for y in range(y0, y1):
        img.putpixel((x0, y), _a(CY, 240))
        img.putpixel((x1 - 1, y), _a(CY, 240))
        img.putpixel((x0 - 1, y), _a(CY, 70))
        img.putpixel((x1, y), _a(CY, 70))
    # cantoneiras
    for (cx, cy, sx, sy) in ((x0, y0, 1, 1), (x1 - 1, y0, -1, 1), (x0, y1 - 1, 1, -1), (x1 - 1, y1 - 1, -1, -1)):
        for i in range(9):
            for w in range(2):
                img.putpixel((cx + sx * i, cy + sy * w - sy * 2), _a(CY_L, 255))
                img.putpixel((cx + sx * w - sx * 2, cy + sy * i), _a(CY_L, 255))
    # réguas laterais
    for y in range(y0 + 18, y1 - 6, 4):
        ln = 3 if (y - y0) % 16 == 2 else 1
        for i in range(ln):
            img.putpixel((x0 + 2 + i, y), _a(CY_M, 200))
            img.putpixel((x1 - 3 - i, y), _a(CY_M, 200))
    # olho Panóptico no cabeçalho
    eye = ["..XXXX..", ".X.oo.X.", "X.oooo.X", ".X.oo.X.", "..XXXX.."]
    for j, row in enumerate(eye):
        for i, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x0 + 5 + i, y0 + 4 + j), _a(CY_L if ch == "o" else CY, 255))
    # barras de sinal à direita
    for i in range(4):
        hgt = 2 + i * 2
        for y in range(y0 + 10 - hgt, y0 + 10):
            img.putpixel((x1 - 16 + i * 3, y), _a(CY if i < 3 else CY_D, 255))
            img.putpixel((x1 - 15 + i * 3, y), _a(CY if i < 3 else CY_D, 255))
    return img


def holo_beam_frames(emit):
    ex, ey = emit
    x0, _y0, x1, y1 = PANEL
    top_l, top_r = x0 + 50, x1 - 50
    frames = []
    r = rng(5)
    for f in range(3):
        img = new(W, H)
        for y in range(y1 + 1, ey + 1):
            t = (y - y1) / max(ey - y1, 1)                     # 0 no painel, 1 na lente
            l = top_l + (ex - 2 - top_l) * t
            rr = top_r + (ex + 2 - top_r) * t
            for x in range(int(l), int(rr) + 1):
                u = (x - l) / max(rr - l, 1)
                edge = min(u, 1 - u)
                inten = 0.25 + 0.55 * t + (0.25 if edge < 0.06 else 0.0)
                if _dither(x + f, y, min(inten, 1.0) * 0.6):
                    img.putpixel((x, y), _a(CY, 90 + int(90 * t)))
        # raios internos
        for _ in range(5):
            u = r.uniform(0.1, 0.9)
            tx = top_l + (top_r - top_l) * u
            ImageDraw.Draw(img).line([(ex, ey), (tx, y1 + 1)], fill=_a(CY_L, 120))
        frames.append(img)
    return frames


# ======================================================================== portal da vila
PORTAL_FW, PORTAL_FH = 32, 44
PORTAL_OPEN = 5
PORTAL_LOOP = 6


def _portal_frame(rx, ry, phase, flash=False, r=None):
    ground = new(PORTAL_FW, PORTAL_FH)
    cx, cy = 16, 22
    # brilho no chão
    for y in range(38, 44):
        for x in range(PORTAL_FW):
            e = ((x + 0.5 - cx) / max(rx + 4, 2)) ** 2 + ((y + 0.5 - 41) / 2.6) ** 2
            if e < 1:
                ground.putpixel((x, y), _a(CY_M if e > 0.45 else CY, 150 if e > 0.45 else 210))
    oval = _portal_oval(rx, ry, phase, flash, r)
    ground.alpha_composite(oval)
    return ground


def _portal_oval(rx, ry, phase, flash, r):
    img = new(PORTAL_FW, PORTAL_FH)
    cx, cy = 16, 22
    if rx < 1 or ry < 1:
        return img
    for y in range(PORTAL_FH):
        for x in range(PORTAL_FW):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            e = dx * dx + dy * dy
            if e >= 1.0:
                continue
            k = math.sqrt(e)
            if flash:
                c = CY_L if k < 0.7 else CY
            elif k > 0.82:
                ang = math.atan2(dy, dx)
                c = CY_L if math.sin(ang * 5 + phase * 2) > 0.55 else CY
            elif k > 0.7:
                c = CY_M
            else:
                ang = math.atan2(dy, dx)
                s = math.sin(3 * ang + 7 * k - phase)
                if s > 0.55:
                    c = C["teal_l"]
                elif s > 0.1:
                    c = C["purple"]
                elif s > -0.4:
                    c = C["purple_d"]
                else:
                    c = hexc("120d2a")
                if k < 0.16:
                    c = C["white"]
            img.putpixel((x, y), _a(c, 255))
    if rx >= 2:
        outline(img, C["out2"])
    if r and rx > 4:
        for _ in range(4):
            a = r.uniform(0, math.tau)
            px = int(cx + math.cos(a) * (rx + r.uniform(1, 4)))
            py = int(cy + math.sin(a) * (ry + r.uniform(0, 3)))
            if 0 <= px < PORTAL_FW and 0 <= py < 38:
                img.putpixel((px, py), _a(CY_L, 255))
    return img


def portal_sheet():
    r = rng(9)
    frames = [
        _portal_frame(1, 4, 0, flash=True),
        _portal_frame(1.5, 12, 0, flash=True),
        _portal_frame(3, 18, 0.5, r=r),
        _portal_frame(7, 18, 1.0, r=r),
        _portal_frame(10, 18, 1.5, flash=True, r=r),
    ]
    for i in range(PORTAL_LOOP):
        frames.append(_portal_frame(10, 18, i * math.tau / PORTAL_LOOP, r=r))
    return hstrip(frames)


def spark():
    img = new(3, 3)
    for x, y in ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
        img.putpixel((x, y), _a(CY_L if (x, y) == (1, 1) else CY, 255))
    return img


# ======================================================================== saída
def generate():
    arm, _local = left_arm()
    save(arm, "intro/arm_left.png")
    save(hstrip(device_screen_frames()), "intro/device_screen.png")
    scr_c = _shear_pt((SCR[0] + SCR[2]) // 2, (SCR[1] + SCR[3]) // 2 + 3, ARM_OX, ARM_OY)
    save(right_hand(scr_c), "intro/hand_right.png")
    save(hstrip(bay_frames()), "intro/bay.png")
    save(holo_panel(), "intro/holo_panel.png")
    emit = _shear_pt(EMIT[0], EMIT[1], ARM_OX, ARM_OY)
    save(hstrip(holo_beam_frames(emit)), "intro/holo_beam.png")
    save(portal_sheet(), "fx/portal.png")
    save(spark(), "fx/portal_spark.png")
    return {
        "intro/layout": {"panel": list(PANEL), "emit": list(emit), "screen": list(scr_c)},
        "fx/portal": {"hframes": PORTAL_OPEN + PORTAL_LOOP, "open": PORTAL_OPEN, "loop": PORTAL_LOOP,
                      "origin": [16, 42]},
    }


def preview():
    """Monta um quadro da abertura em 1280x720 para conferência visual."""
    from PIL import Image
    import os
    from common import OUT as GEN
    meta = generate()
    frame = Image.open(os.path.join(GEN, "intro/bay.png")).crop((0, 0, W, H)).convert("RGBA")
    beam = Image.open(os.path.join(GEN, "intro/holo_beam.png")).crop((0, 0, W, H))
    frame.alpha_composite(beam)
    frame.alpha_composite(Image.open(os.path.join(GEN, "intro/holo_panel.png")))
    frame.alpha_composite(Image.open(os.path.join(GEN, "intro/arm_left.png")))
    frame.alpha_composite(Image.open(os.path.join(GEN, "intro/device_screen.png")).crop((2 * W, 0, 3 * W, H)))
    here = os.path.dirname(__file__)
    frame.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(here, "_preview_intro.png"))
    frame.alpha_composite(Image.open(os.path.join(GEN, "intro/hand_right.png")))
    frame.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(here, "_preview_intro_tap.png"))
    p = Image.open(os.path.join(GEN, "fx/portal.png"))
    p.resize((p.width * 6, p.height * 6), Image.NEAREST).save(os.path.join(os.path.dirname(__file__), "_preview_portal.png"))
    print(meta)


if __name__ == "__main__":
    preview()
