"""Sprites futuristas para a sequencia de conclusao."""
from common import C, from_ascii, grid, save, new, hexc
from chars import compose, apply, rows_ov, base_pal

W = 16

CYBER_CYAN = hexc("00e5ff")
CYBER_CYAN_D = hexc("0097a7")
CYBER_DARK = hexc("1a1a2e")
CYBER_PANEL = hexc("16213e")
CYBER_GLOW = hexc("7fefff")
CYBER_WHITE = hexc("e0f7fa")

AGENT_RED = hexc("ff1744")
AGENT_RED_D = hexc("b71c1c")
AGENT_DARK = hexc("0d0d1a")
AGENT_PANEL = hexc("1a1a2e")
AGENT_GREY = hexc("37474f")
AGENT_GREY_D = hexc("263238")

VISOR = {
    "d": rows_ov(0, [
        "................",
        "......CCCC......",
        "....OCCCCCCO....",
        "...OCCCCCCCCO...",
        "..OCCCCCCCCCCOO.",
        "..OCCCCCCCCCCO..",
        "..OcVVVVVVVVcO..",
        "..OcVvVVVVvVcO..",
        "..OCCCCCCCCCCO..",
        "..OcCCCCCCCCcO..",
        "...OcCCCCCCcO...",
        "....OOOOOOOO....",
    ]),
    "u": rows_ov(0, [
        "................",
        "......CCCC......",
        "....OCCCCCCO....",
        "...OCCCCCCCCO...",
        "..OCCCCCCCCCCOO.",
        "..OCCCCCCCCCCO..",
        "..OCCCCCCCCCCO..",
        "..OCCCCCCCCCCO..",
        "..OcCCCCCCCCcO..",
        "..OCcCCCCCCcCO..",
        "...OccccccccO...",
        "....OOOOOOOO....",
    ]),
    "s": rows_ov(0, [
        "................",
        ".......CCCC.....",
        "......CCCCCCO...",
        "....OCCCCCCCCOO.",
        "...OCCCCCCCCCOO.",
        "...OCCCCCCCCcO..",
        "...OVVVCCCCCcO..",
        "..OVvVVCCCChO...",
        "..OVVVCCCChO....",
        ".OCCCCCCCcO.....",
        "..OcCCCCcO......",
        "...OOOOOOO......",
    ]),
}

FUTURISTIC_CLOAK = {
    "d": [
        "....OAAAAAAO....",
        "...OAAGGGGaAAO..",
        "..OAaAAGGAAaAO..",
        "..OAaAAGGAAaAO..",
        "..OSOAAGAAOSO...",
        "...OOAAGAAOO....",
        "....OAAAAAAO....",
        "...OAAAAAAAAO...",
        "...OAAAAAAAAO...",
        "..OAAAAAAAAAO...",
        "..OAAAAAAAAAO...",
        "...OOOOOOOOOO...",
    ],
    "s": [
        ".....OAAAAO.....",
        "....OAAGAAAO....",
        "....OAAaGAAO....",
        "....OAAaGAAO....",
        "....OAOSOGAO....",
        ".....OAAGAO.....",
        ".....OAAAAO.....",
        "....OAAAAAAO....",
        "....OAAAAAAO....",
        "...OAAAAAAAAO...",
        "...OAAAAAAAAO...",
        "....OOOOOOOO....",
    ],
}
FUTURISTIC_CLOAK["u"] = FUTURISTIC_CLOAK["d"]

GLOW_LINES = {
    "d": rows_ov(16, ["...OOVVVVVVOO...", "....OVVVVVVO...."]),
    "u": rows_ov(16, ["...OOVVVVVVOO...", "....OVVVVVVO...."]),
    "s": rows_ov(16, [".....OVVVVO.....", "....OVVVVVO....."]),
}

FIGURE_SPEC = dict(
    pal=base_pal(H=CYBER_DARK, h=CYBER_PANEL, A=CYBER_DARK, a=CYBER_PANEL,
        B=CYBER_DARK, P=CYBER_DARK, p=CYBER_PANEL, F=CYBER_PANEL,
        S=CYBER_WHITE, s=CYBER_CYAN_D, C=CYBER_DARK, c=CYBER_PANEL,
        V=CYBER_CYAN, v=CYBER_GLOW, G=CYBER_CYAN_D),
    dress=False, ov=[(VISOR, "dus", 0), (GLOW_LINES, "dus", 0)],
)

AGENT_VISOR = {
    "d": rows_ov(0, [
        "................",
        ".....OOOOOO.....",
        "....OCCCCCCO....",
        "...OCCCCCCCCOO..",
        "..OGGGGGGGGGgO..",
        "..OGgggggggggO..",
        "..OgRRRRRRRRgO..",
        "..OgRrRRRRrRgO..",
        "..OGGGGGGGGGO...",
        "..OgGGGGGGGgO...",
        "...OgGGGGGgO....",
        "....OOOOOOOO....",
    ]),
    "u": rows_ov(0, [
        "................",
        ".....OOOOOO.....",
        "....OGGGGGGO....",
        "...OGGGGGGGGO...",
        "..OGGGGGGGGGgO..",
        "..OGgggggggggO..",
        "..OGGGGGGGGGGO..",
        "..OGGGGGGGGGGO..",
        "..OgGGGGGGGGgO..",
        "..OGgGGGGGGgGO..",
        "...OggggggggO...",
        "....OOOOOOOO....",
    ]),
    "s": rows_ov(0, [
        "................",
        "......OOOOOO....",
        ".....OGGGGGGO...",
        "....OGGGGGGGGO..",
        "...OGGGGGGGGgO..",
        "...OGGGGGGGGgO..",
        "...ORRRGGGGGgO..",
        "..ORrRRGGGghO...",
        "..ORRRGGGGhO....",
        ".OGGGGGGGgO.....",
        "..OgGGGGgO......",
        "...OOOOOOO......",
    ]),
}

AGENT_ARMOR = {
    "d": rows_ov(12, [
        "....OAAAAAAO....", "...OAAAAAAAAO...",
        "..OAaAAAAAAaAO..", "..OAaAAAAAAaAO..",
        "..OSOAAAAAAOSO..", "...OOBBBBBBOO...",
        "....OAAAAAAO....",
    ]),
    "s": rows_ov(12, [
        ".....OAAAAO.....", "....OAAAAAAO....",
        "....OAAaAAAO....", "....OAAaAAAO....",
        "....OAOSOAAO....", "....OBBOBBBO....",
        ".....OAAAAO.....",
    ]),
}
AGENT_ARMOR["u"] = AGENT_ARMOR["d"]

AGENT_SPEC = dict(
    pal=base_pal(H=AGENT_DARK, h=AGENT_PANEL, A=AGENT_DARK, a=AGENT_PANEL,
        B=AGENT_GREY_D, P=AGENT_DARK, p=AGENT_PANEL, F=AGENT_PANEL,
        S=CYBER_WHITE, s=CYBER_CYAN_D, G=AGENT_GREY, g=AGENT_GREY_D,
        R=AGENT_RED, r=AGENT_RED_D, C=AGENT_DARK, c=AGENT_PANEL),
    dress=False, ov=[(AGENT_VISOR, "dus", 0), (AGENT_ARMOR, "dus", 0)],
)


def build_figure_sheet(spec, use_cloak=False):
    dirs = ("d", "u", "s")
    frames = []
    for d in dirs:
        row = []
        for f in range(4):
            rows = compose(d, f, spec.get("dress", False))
            if use_cloak and d in FUTURISTIC_CLOAK:
                rows = rows[:12] + FUTURISTIC_CLOAK[d]
            for ov, scope, dx in spec.get("ov", []):
                base = scope.replace("_under", "")
                if base != "all" and d not in base:
                    continue
                if all(isinstance(k, int) for k in ov):
                    data = ov
                elif d in ov:
                    data = ov[d]
                else:
                    continue
                rows = apply(rows, data, "under" if scope.endswith("_under") else "over", dx)
            pal = dict(spec["pal"])
            row.append(from_ascii(rows, pal, W))
        frames.append(row)
    return grid(frames)


def build_portal(color1, color2, glow_color):
    import math
    frames = []
    for fi in range(4):
        img = new(32, 32)
        phase = fi * math.pi / 2
        cx, cy = 16, 16
        for angle_i in range(60):
            a = angle_i * math.pi * 2 / 60 + phase * 0.3
            r = 13 + math.sin(a * 3 + phase) * 2
            x = int(cx + math.cos(a) * r)
            y = int(cy + math.sin(a) * r)
            if 0 <= x < 32 and 0 <= y < 32:
                img.putpixel((x, y), color1)
            r2 = 8 + math.sin(a * 2 - phase) * 1.5
            x3 = int(cx + math.cos(a) * r2)
            y3 = int(cy + math.sin(a) * r2)
            if 0 <= x3 < 32 and 0 <= y3 < 32:
                img.putpixel((x3, y3), color2)
        for gy in range(8, 25):
            for gx in range(8, 25):
                dist = math.sqrt((gx - 16)**2 + (gy - 16)**2)
                if dist < 7:
                    alpha = int(200 * (1 - dist / 7) * (0.5 + 0.5 * math.sin(phase + dist)))
                    old = img.getpixel((gx, gy))
                    if old[3] < alpha:
                        img.putpixel((gx, gy), (*glow_color[:3], max(0, min(255, alpha))))
        frames.append(img)
    out = new(32 * 4, 32)
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * 32, 0))
    return out


def build_energy_bolt():
    import math
    frames = []
    for fi in range(4):
        img = new(8, 8)
        phase = fi * math.pi / 2
        cx, cy = 4, 4
        for y in range(8):
            for x in range(8):
                dist = math.sqrt((x - cx)**2 + (y - cy)**2)
                if dist < 2:
                    a = int(255 * (1 - dist / 2))
                    img.putpixel((x, y), (255, 255, 255, a))
                elif dist < 3.5:
                    a = int(180 * (1 - (dist - 2) / 1.5) * (0.7 + 0.3 * math.sin(phase + dist * 2)))
                    img.putpixel((x, y), (*AGENT_RED[:3], max(0, min(255, a))))
        frames.append(img)
    out = new(8 * 4, 8)
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * 8, 0))
    return out


def build_all():
    save(build_figure_sheet(FIGURE_SPEC, use_cloak=True), "conclusion/figure_mystery.png")
    save(build_figure_sheet(AGENT_SPEC, use_cloak=False), "conclusion/agent.png")
    save(build_portal(CYBER_CYAN, CYBER_GLOW, CYBER_CYAN), "conclusion/portal_cyan.png")
    save(build_portal(AGENT_RED, hexc("ff5252"), AGENT_RED), "conclusion/portal_red.png")
    save(build_energy_bolt(), "conclusion/energy_bolt.png")
    print("Conclusion assets built ok")


if __name__ == "__main__":
    build_all()
