"""Gera assets de UI pixel art para o HUD do gameplay."""
from common import *


def panel_9slice(w=48, h=48):
    """Painel 9-slice estilo RPG medieval: borda de pedra com cantos ornados."""
    img = new(w, h)
    bg = C["out2"]
    border = C["stone_d"]
    border_l = C["stone"]
    corner = C["gold_d"]
    inner = (24, 30, 46, 230)

    # fundo
    rect(img, 2, 2, w - 4, h - 4, inner)

    # bordas
    hline(img, 2, w - 3, 0, border)
    hline(img, 2, w - 3, 1, border_l)
    hline(img, 2, w - 3, h - 1, border)
    hline(img, 2, w - 3, h - 2, C["stone_dd"])
    vline(img, 0, 2, h - 3, border)
    vline(img, 1, 2, h - 3, border_l)
    vline(img, w - 1, 2, h - 3, border)
    vline(img, w - 2, 2, h - 3, C["stone_dd"])

    # cantos ornados
    for cx, cy in [(0, 0), (w - 4, 0), (0, h - 4), (w - 4, h - 4)]:
        rect(img, cx, cy, 4, 4, corner)
        put(img, cx + 1, cy + 1, C["gold"])
        put(img, cx + 2, cy + 2, C["gold"])

    # inner shadow top
    for x in range(3, w - 3):
        put(img, x, 2, (20, 24, 38, 200))
    # inner shadow left
    for y in range(3, h - 3):
        put(img, 2, y, (20, 24, 38, 200))

    return img


def tooltip_9slice():
    """Tooltip menor, borda fina dourada."""
    w, h = 32, 20
    img = new(w, h)
    rect(img, 1, 1, w - 2, h - 2, (18, 22, 36, 220))
    # border
    hline(img, 1, w - 2, 0, C["gold_d"])
    hline(img, 1, w - 2, h - 1, C["gold_d"])
    vline(img, 0, 1, h - 2, C["gold_d"])
    vline(img, w - 1, 1, h - 2, C["gold_d"])
    # corner dots
    for cx, cy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        put(img, cx, cy, C["gold"])
    return img


def stat_bar_fill():
    """Barra de stat: 4 frames (medo=azul, raiva=vermelho, lealdade=dourado, credulidade=verde), 1px de altura, 32px largura."""
    frames = []
    colors = [
        (C["blue_l"], C["blue"], C["blue_d"]),      # medo
        (C["red_l"], C["red"], C["red_d"]),          # raiva
        (C["gold_l"], C["gold"], C["gold_d"]),       # lealdade
        (C["teal_l"], C["teal"], C["teal_d"]),       # credulidade
    ]
    fw = 32
    for light, mid, dark in colors:
        f = new(fw, 6)
        hline(f, 0, fw - 1, 0, dark)
        for y in range(1, 3):
            hline(f, 0, fw - 1, y, mid)
        hline(f, 0, fw - 1, 3, light)
        hline(f, 0, fw - 1, 4, mid)
        hline(f, 0, fw - 1, 5, dark)
        frames.append(f)
    return grid([frames])


def stat_bar_bg():
    """Fundo da barra de stat (vazio/escuro)."""
    fw = 32
    f = new(fw, 6)
    hline(f, 0, fw - 1, 0, C["stone_dd"])
    rect(f, 0, 1, fw, 4, (30, 34, 50, 200))
    hline(f, 0, fw - 1, 5, C["stone_dd"])
    return f


def stat_icons():
    """4 ícones 10x10 para medo/raiva/lealdade/credulidade em strip horizontal."""
    icons = []

    # Medo (olho)
    f = new(10, 10)
    ellipse(f, 5, 5, 4, 3, C["blue"])
    disc(f, 5, 5, 2, C["blue_l"])
    disc(f, 5, 5, 1, C["white"])
    outline(f, C["blue_d"])
    icons.append(f)

    # Raiva (chama)
    f = new(10, 10)
    pal = {
        '#': C["red"], '.': C["red_l"], 'o': C["orange"],
        '*': C["flame_l"], '^': C["flame"],
    }
    rows = [
        "    .     ",
        "   .#.    ",
        "  .##.    ",
        "  .###.   ",
        " .o###.   ",
        " .o*###.  ",
        " .o*##.   ",
        " .####.   ",
        "  .##.    ",
        "   ..     ",
    ]
    f = from_ascii(rows, pal, 10)
    icons.append(f)

    # Lealdade (coroa)
    f = new(10, 10)
    pal = {'#': C["gold"], '.': C["gold_l"], 'o': C["gold_d"]}
    rows = [
        "          ",
        "  .   .   ",
        " .#. .#.  ",
        " .##.##.  ",
        "  .###.   ",
        "  .###.   ",
        " o#####o  ",
        " o#####o  ",
        "  ooooo   ",
        "          ",
    ]
    f = from_ascii(rows, pal, 10)
    icons.append(f)

    # Credulidade (pergaminho)
    f = new(10, 10)
    pal = {'#': C["cream"], '.': C["wood"], 'o': C["wood_d"], '-': C["stone"]}
    rows = [
        "          ",
        "  .####.  ",
        " .#----#. ",
        " .#----#. ",
        " .#----#. ",
        " .#----#. ",
        " .#----#. ",
        "  .####.  ",
        "   oooo   ",
        "          ",
    ]
    f = from_ascii(rows, pal, 10)
    icons.append(f)

    return hstrip(icons)


def ap_gem():
    """Gem/cristal para PA: 2 frames (cheio, vazio), 12x14 cada."""
    frames = []

    # cheio (brilhante)
    pal_full = {
        '#': C["gold"], '.': C["gold_l"], 'o': C["gold_d"],
        '*': C["flame_l"], '^': C["yellow_l"],
    }
    rows = [
        "    ..    oo",
        "   .^^.   oo",
        "  .^**^.  oo",
        "  .^*#^.  oo",
        " .^*##^.  oo",
        " .^####. ooo",
        " .#####. ooo",
        "  .####.  oo",
        "  .o##o.  oo",
        "   .oo.   oo",
        "    ..    oo",
        "          oo",
        "          oo",
        "          oo",
    ]
    f = from_ascii(rows, pal_full, 12)
    outline(f, C["out"])
    frames.append(f)

    # vazio (opaco)
    pal_empty = {
        '#': C["stone_dd"], '.': C["stone_d"], 'o': C["out"],
        '*': C["stone"], '^': C["stone"],
    }
    f = from_ascii(rows, pal_empty, 12)
    outline(f, C["out"])
    frames.append(f)

    return hstrip(frames)


def instab_frame():
    """Frame decorado para a barra de instabilidade: 80x10."""
    w, h = 80, 10
    img = new(w, h)
    # outer border
    hline(img, 2, w - 3, 0, C["stone_d"])
    hline(img, 2, w - 3, h - 1, C["stone_dd"])
    vline(img, 0, 2, h - 3, C["stone_d"])
    vline(img, w - 1, 2, h - 3, C["stone_dd"])
    vline(img, 1, 1, h - 2, C["stone"])
    vline(img, w - 2, 1, h - 2, C["stone"])
    hline(img, 1, w - 2, 1, C["stone"])
    hline(img, 1, w - 2, h - 2, C["stone"])
    # corners
    for cx, cy in [(0, 0), (w - 3, 0), (0, h - 3), (w - 3, h - 3)]:
        rect(img, cx, cy, 3, 3, C["gold_d"])
        put(img, cx + 1, cy + 1, C["gold"])
    # inner bg
    rect(img, 2, 2, w - 4, h - 4, (18, 22, 36, 230))
    return img


def instab_fill():
    """Preenchimento gradiente da barra instab: 76x6, 4 segmentos de cor."""
    w, h = 76, 6
    img = new(w, h)
    for x in range(w):
        t = x / (w - 1)
        if t < 0.33:
            r0, g0, b0 = 0x20, 0xcc, 0x40
            r1, g1, b1 = 0xf0, 0xd8, 0x30
            lt = t / 0.33
        elif t < 0.66:
            r0, g0, b0 = 0xf0, 0xd8, 0x30
            r1, g1, b1 = 0xf0, 0x80, 0x20
            lt = (t - 0.33) / 0.33
        else:
            r0, g0, b0 = 0xf0, 0x80, 0x20
            r1, g1, b1 = 0xe0, 0x18, 0x18
            lt = (t - 0.66) / 0.34
        r = int(r0 + (r1 - r0) * lt)
        g = int(g0 + (g1 - g0) * lt)
        b = int(b0 + (b1 - b0) * lt)
        put(img, x, 0, (r // 2, g // 2, b // 2, 255))
        for y in range(1, 3):
            put(img, x, y, (min(r + 30, 255), min(g + 30, 255), min(b + 30, 255), 255))
        put(img, x, 3, (r, g, b, 255))
        for y in range(4, h):
            put(img, x, y, (r * 3 // 4, g * 3 // 4, b * 3 // 4, 255))
    return img


def day_banner():
    """Banner decorado para DIA X/3: ornamento medieval, 48x16 9-slice."""
    w, h = 48, 16
    img = new(w, h)
    # ribbon bg
    rect(img, 3, 2, w - 6, h - 4, (40, 26, 18, 220))
    # ribbon border
    hline(img, 3, w - 4, 1, C["wood"])
    hline(img, 3, w - 4, h - 2, C["wood_d"])
    vline(img, 2, 2, h - 3, C["wood"])
    vline(img, w - 3, 2, h - 3, C["wood_d"])
    # ribbon tails (left)
    for dy in range(3):
        put(img, 0, 4 + dy, C["red_d"])
        put(img, 1, 4 + dy, C["red"])
        put(img, 2, 4 + dy, C["red"])
    for dy in range(3):
        put(img, 0, h - 7 + dy, C["red_d"])
        put(img, 1, h - 7 + dy, C["red"])
        put(img, 2, h - 7 + dy, C["red"])
    # right tail
    for dy in range(3):
        put(img, w - 1, 4 + dy, C["red_d"])
        put(img, w - 2, 4 + dy, C["red"])
        put(img, w - 3, 4 + dy, C["red"])
    for dy in range(3):
        put(img, w - 1, h - 7 + dy, C["red_d"])
        put(img, w - 2, h - 7 + dy, C["red"])
        put(img, w - 3, h - 7 + dy, C["red"])
    # gold corners
    for cx, cy in [(2, 1), (w - 4, 1), (2, h - 3), (w - 4, h - 3)]:
        put(img, cx, cy, C["gold"])
        put(img, cx + 1, cy, C["gold"])
        put(img, cx, cy + 1, C["gold"])
    return img


def button_9slice():
    """Botão 9-slice: 3 estados (normal, hover, pressed) empilhados, 32x14 cada."""
    w, h = 32, 14
    states = []
    configs = [
        (C["stone_dd"], C["stone_d"], (28, 34, 52, 230)),   # normal
        (C["gold"], C["gold_d"], (38, 44, 62, 240)),        # hover
        (C["gold_l"], C["gold"], (24, 30, 46, 245)),        # pressed
    ]
    for border, border_d, bg in configs:
        f = new(w, h)
        rect(f, 2, 2, w - 4, h - 4, bg)
        hline(f, 2, w - 3, 0, border)
        hline(f, 2, w - 3, 1, border)
        hline(f, 2, w - 3, h - 1, border_d)
        hline(f, 2, w - 3, h - 2, border_d)
        vline(f, 0, 2, h - 3, border)
        vline(f, 1, 2, h - 3, border)
        vline(f, w - 1, 2, h - 3, border_d)
        vline(f, w - 2, 2, h - 3, border_d)
        # corners
        for cx, cy in [(0, 0), (w - 3, 0), (0, h - 3), (w - 3, h - 3)]:
            rect(f, cx, cy, 3, 3, border)
        states.append(f)
    return grid([[s] for s in states])


def separator():
    """Linha decorativa horizontal, 64x3."""
    w = 64
    img = new(w, 3)
    hline(img, 0, w - 1, 1, C["stone_d"])
    # ornament center
    mid = w // 2
    for dx in range(-2, 3):
        put(img, mid + dx, 0, C["gold_d"])
        put(img, mid + dx, 1, C["gold"])
        put(img, mid + dx, 2, C["gold_d"])
    put(img, mid, 1, C["gold_l"])
    return img


def memory_icon():
    """Ícone de memória (bolha de pensamento), 10x10."""
    f = new(10, 10)
    pal = {'#': C["stone_l"], '.': C["stone"], 'o': C["stone_d"]}
    rows = [
        "   ....   ",
        "  .####.  ",
        " .######. ",
        " .######. ",
        " .######. ",
        "  .####.  ",
        "   o..o   ",
        "    oo    ",
        "     o    ",
        "          ",
    ]
    f = from_ascii(rows, pal, 10)
    return f


def generate():
    meta = {}

    save(panel_9slice(), "ui/panel.png")
    meta["ui/panel"] = {"9slice": [4, 4, 4, 4]}

    save(tooltip_9slice(), "ui/tooltip.png")
    meta["ui/tooltip"] = {"9slice": [3, 3, 3, 3]}

    save(stat_bar_fill(), "ui/stat_bar_fill.png")
    meta["ui/stat_bar_fill"] = {"hframes": 4, "vframes": 1}

    save(stat_bar_bg(), "ui/stat_bar_bg.png")

    save(stat_icons(), "ui/stat_icons.png")
    meta["ui/stat_icons"] = {"hframes": 4}

    save(ap_gem(), "ui/ap_gem.png")
    meta["ui/ap_gem"] = {"hframes": 2}

    save(instab_frame(), "ui/instab_frame.png")

    save(instab_fill(), "ui/instab_fill.png")

    save(day_banner(), "ui/day_banner.png")
    meta["ui/day_banner"] = {"9slice": [6, 4, 6, 4]}

    save(button_9slice(), "ui/button.png")
    meta["ui/button"] = {"9slice": [4, 4, 4, 4], "vframes": 3}

    save(separator(), "ui/separator.png")

    save(memory_icon(), "ui/memory_icon.png")

    print(f"  UI: {len(meta) + 3} assets gerados")
    return meta


if __name__ == "__main__":
    generate()
