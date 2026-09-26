"""Sprites dos personagens: 16x24 por frame, folhas 4 colunas (idle, passo1, meio, passo2) x 3 linhas (baixo, cima, lado).

Cada personagem = corpo-base (cabeça/tronco/pernas) + sobreposições (chapéu, barba, avental...) + paleta própria.
O lado é desenhado olhando para a esquerda; a direita é o flip_h no Godot.
"""
from common import C, from_ascii, grid, save, new, paste

W = 16

HEAD = {
    "d": [
        "................",
        ".....OOOOOO.....",
        "....OHHHHHHO....",
        "...OHHHHHHHHO...",
        "..OHHHHHHHHHHO..",
        "..OHhHHHHHHhHO..",
        "..OHSSSSSSSSHO..",
        "..OSSESSSSESSO..",
        "..OSSESSSSESSO..",
        "..OsSSSSSSSSsO..",
        "...OsSSSSSSsO...",
        "....OOOOOOOO....",
    ],
    "u": [
        "................",
        ".....OOOOOO.....",
        "....OHHHHHHO....",
        "...OHHHHHHHHO...",
        "..OHHHHHHHHHHO..",
        "..OHHHHHHHHHHO..",
        "..OHHHHHHHHHHO..",
        "..OHHHHHHHHHHO..",
        "..OhHHHHHHHHhO..",
        "..OShHHHHHHhSO..",
        "...OhhhhhhhhO...",
        "....OOOOOOOO....",
    ],
    "s": [
        "................",
        "......OOOOOO....",
        ".....OHHHHHHO...",
        "....OHHHHHHHHO..",
        "...OHHHHHHHHHO..",
        "...OHHHHHHHHhO..",
        "...OSSSHHHHHhO..",
        "..OSSESSHHHhO...",
        "..OSSESSSHHhO...",
        ".OSSSSSSSShO....",
        "..OsSSSSSsO.....",
        "...OOOOOOO......",
    ],
}

BODY = {
    "d": [
        "....OAAAAAAO....",
        "...OAAAAAAAAO...",
        "..OAaAAAAAAaAO..",
        "..OAaAAAAAAaAO..",
        "..OSOAAAAAAOSO..",
        "...OOBBBBBBOO...",
        "....OAAAAAAO....",
    ],
    "s": [
        ".....OAAAAO.....",
        "....OAAAAAAO....",
        "....OAAaAAAO....",
        "....OAAaAAAO....",
        "....OAOSOAAO....",
        "....OBBOBBBO....",
        ".....OAAAAO.....",
    ],
}
BODY["u"] = BODY["d"]

_LEG_D_IDLE = [
    "....OPPPPPPO....",
    "....OPPOOPPO....",
    "....OPPOOPPO....",
    "....OFFOOFFO....",
    ".....OO..OO.....",
]
_LEG_D_STEP = [
    "....OPPPPPPO....",
    "....OPPOOPPO....",
    "....OPPOOFFO....",
    "....OFFO.OO.....",
    ".....OO.........",
]
_LEG_S = {
    "idle": [
        ".....OPPPPO.....",
        ".....OPPPPO.....",
        ".....OPPpPO.....",
        "....OFFOFFO.....",
        ".....OO.OO......",
    ],
    "a": [
        ".....OPPPPO.....",
        "....OPPOpppO....",
        "....OPPOOppO....",
        "...OFFO..OFFO...",
        "....OO....OO....",
    ],
    "mid": [
        ".....OPPPPO.....",
        ".....OPPPPO.....",
        ".....OPPPPO.....",
        ".....OFFFFO.....",
        "......OOOO......",
    ],
    "b": [
        ".....OPPPPO.....",
        "....OpppOPPO....",
        "....OppOOPPO....",
        "...OFFO..OFFO...",
        "....OO....OO....",
    ],
}


def _mirror(rows):
    return [r[::-1] for r in rows]


LEGS = {
    "d": [_LEG_D_IDLE, _LEG_D_STEP, _LEG_D_IDLE, _mirror(_LEG_D_STEP)],
    "s": [_LEG_S["idle"], _LEG_S["a"], _LEG_S["mid"], _LEG_S["b"]],
}
LEGS["u"] = LEGS["d"]

# vestido/manto longo: substitui linhas 18-23
_DRESS_D = [
    "....OAAAAAAO....",
    "...OAAAAAAAAO...",
    "...OAaAAAAaAO...",
    "..OAAaAAAAaAAO..",
    "..OAAAAAAAAAAO..",
    "...OOOOOOOOOO...",
]
_DRESS_D_STEP = _DRESS_D[:5] + ["...OOOOOOFFO...."]
_DRESS_S = [
    ".....OAAAAO.....",
    "....OAAAAAAO....",
    "....OAAaAAAO....",
    "...OAAAaAAAAO...",
    "...OAAAAAAAAO...",
    "....OOOOOOOO....",
]
_DRESS_S_A = _DRESS_S[:4] + ["..OAAAAAAAAAO...", "..OFOOOOOOOO...."]
_DRESS_S_B = _DRESS_S[:4] + ["...OAAAAAAAAAO..", "....OOOOOOOOFO.."]
DRESS = {
    "d": [_DRESS_D, _DRESS_D_STEP, _DRESS_D, _DRESS_D[:5] + ["....OFFOOOOOO..."]],
    "s": [_DRESS_S, _DRESS_S_A, _DRESS_S, _DRESS_S_B],
}
DRESS["u"] = DRESS["d"]

for _k, _v in list(HEAD.items()) + list(BODY.items()):
    for _r in _v:
        assert len(_r) == W, (_k, _r, len(_r))


def compose(d, frame, dress=False):
    rows = list(HEAD[d]) + list(BODY[d]) + list(LEGS[d][frame])
    if dress:
        rows = rows[:18] + list(DRESS[d][frame])
    assert len(rows) == 24
    for r in rows:
        assert len(r) == W, r
    return rows


def apply(rows, ov, mode="over", dx=0):
    """ov: {linha: string}. '.' mantém; ' ' apaga; outro caractere pinta. mode 'under' só pinta onde está vazio."""
    rows = [list(r) for r in rows]
    for y, s in ov.items():
        assert len(s) == W, (y, s, len(s))
        if y < 0 or y >= len(rows):
            continue
        for x, ch in enumerate(s):
            tx = x + dx
            if ch == "." or tx < 0 or tx >= W:
                continue
            if mode == "under" and rows[y][tx] != ".":
                continue
            rows[y][tx] = "." if ch == " " else ch
    return ["".join(r) for r in rows]


def rows_ov(start, lines):
    return {start + i: s for i, s in enumerate(lines)}


# ------------------------------------------------------------------ sobreposições
CROWN = rows_ov(0, [
    "..O....OO....O..",
    ".OYO..OYYO..OYO.",
    ".OYYOOYYYYOOYYO.",
    ".OYYYYYYYYYYYYO.",
    ".OYRYYYDDYYYRYO.",
    "..OOOOOOOOOOOO..",
])
KING_BEARD = {
    "d": rows_ov(9, ["..OHSSHHHHSSHO..", "...OHHHHHHHHO...", "....OHHhhHHO...."]),
    "s": rows_ov(9, [".OSHHHHSSShO....", "..OHHHHHHsO.....", "...OHHhHO......."]),
}
ERMINE = {
    "d": rows_ov(12, ["...OWWWWWWWWO...", "..OWkWWWWWWkWO.."]),
    "u": rows_ov(12, ["...OWWWWWWWWO...", "..OWkWWWWWWkWO.."]),
    "s": rows_ov(12, ["....OWWWWWWO....", "....OWkWWWWO...."]),
}
CAP = rows_ov(0, [
    "................",
    ".....OOOOOO.....",
    "....OLLLLLLO....",
    "...OLbbbbbbLO...",
    "..ObbbbbbbbbbO..",
    "..OddddddddddO..",
])
MUSTACHE = {"d": {9: "..OsShHHHHhSsO.."}, "s": {9: ".OSHHSSSSShO...."}}
APRON_W = {
    "d": rows_ov(13, [
        "...OAAWWWWAAO...",
        "..OAaAWWWWAaAO..",
        "..OAaWWWWWWaAO..",
        "..OSOWWWWWWOSO..",
        "...OOWWWWWWOO...",
        "....OWWWWWWO....",
        "....OwWWWWwO....",
    ]),
    "s": {13: ".....W..........", 14: ".....W..........", 15: ".....W..........",
          16: ".....W..........", 17: ".....W..........", 18: "......W........."},
    "u": {17: "......WWWW......", 18: ".......WW......."},
}
APRON_M = {k: {r: s.replace("W", "M").replace("w", "m") for r, s in v.items()} for k, v in APRON_W.items()}
BARE_ARMS = {
    "d": {14: "...Ss......sS...", 15: "...Ss......sS..."},
    "u": {14: "...Ss......sS...", 15: "...Ss......sS..."},
    "s": {14: ".......s........", 15: ".......S........"},
}
BLACK_BEARD = {
    "d": rows_ov(9, ["..OHSHHHHHHSHO..", "...OHHHHHHHHO...", "....OOHHHHOO...."]),
    "s": rows_ov(9, [".OSHHHHHSShO....", "..OHHHHHHsO.....", "...OOHHOO......."]),
}
HELMET = {
    "d": rows_ov(0, [
        ".......RR.......",
        ".....OORROO.....",
        "....OGGGGGGO....",
        "...OGGGGGGGGO...",
        "..OgGGGGGGGGgO..",
        "..OggggggggggO..",
        "..Og........gO..",
        "..Og........gO..",
    ]),
    "u": rows_ov(0, [
        ".......RR.......",
        ".....OORROO.....",
        "....OGGGGGGO....",
        "...OGGGGGGGGO...",
        "..OgGGGGGGGGgO..",
        "..OggggggggggO..",
        "..OggggggggggO..",
        "..OggggggggggO..",
        "..OggggggggggO..",
    ]),
    "s": rows_ov(0, [
        ".........RR.....",
        "......OORROO....",
        ".....OGGGGGGO...",
        "....OGGGGGGGGO..",
        "...OgGGGGGGGgO..",
        "...OggggggggggO.",
        "...Og....ggggO..",
        "...Og....gggO...",
    ]),
}
GUARD_ARMS = {
    "d": {14: "...Gg......gG...", 15: "...Gg......gG..."},
    "u": {14: "...Gg......gG...", 15: "...Gg......gG..."},
    "s": {14: ".......g........", 15: ".......G........"},
}
SPEAR = {
    "d": {0: "..............G.", 1: ".............GGG", 2: "..............G.", 3: "..............w.",
          **{r: "..............w." for r in range(4, 23)}},
    "u": {0: ".G..............", 1: "GGG.............", 2: ".G..............", 3: ".w..............",
          **{r: ".w.............." for r in range(4, 23)}},
    "s": {0: "............G...", 1: "...........GGG..", 2: "............G...",
          **{r: "............w..." for r in range(3, 23)}},
}
BUN = {
    "d": {0: "......OHHO......"},
    "u": {0: "......OHHO......", 11: "...OHHHHHHHHO...", 12: "....OHHHHHHO....", 13: ".....OhhhhO....."},
    "s": {1: "......OOOOOOOO..", 2: ".....OHHHHHHHhO.", 3: "....OHHHHHHHHhO."},
}
LONG_HAIR = {
    "d": {6: "...H........H...", 7: ".OH..........HO.", 8: ".OH..........HO.", 9: ".OH..........HO.",
          10: ".OHO........OHO.", 11: "..O..........O.."},
    "s": {8: "...........HO...", 9: "..........HhO...", 10: "..........HhO...", 11: "...........OO..."},
}
PENDANT = {"d": {14: ".......YY.......", 15: ".......OO......."}}
HAT = rows_ov(0, [
    ".....OOOOOO.....",
    "....OnnnnnnO.R..",
    "....OnnnnnnORR..",
    "....ONNNNNNOR...",
    "OOOOOnnnnnnOOOOO",
    "OnnnnnnnnnnnnnnO",
    ".OOOOOOOOOOOOOO.",
])
STRAW_HAT = {k: s.replace("R", ".").replace("N", "n") for k, s in HAT.items()}
BACKPACK = {"u": rows_ov(12, [
    "....OOOOOOOO....",
    "....OmMMMMmO....",
    "....OMMMMMMO....",
    "....OMMYYMMO....",
    "....OMMMMMMO....",
    "....OmmmmmmO....",
    "....OOOOOOOO....",
])}
POUCH = {"d": {17: "...OOBBBBBBOYO..", 18: "....OAAAAAAOYO.."}, "s": {17: "....OBBOBBBOY...", 18: ".....OAAAAOYO..."}}
MESSY = {
    "d": {0: "....O..OO..O....", 1: "...OHOOHHOOHOL..", 2: "...OHHHHHHHHO...", 6: "....H......H...."},
    "u": {0: "....O..OO..O....", 1: "...OHOOHHOOHOL..", 2: "...OHHHHHHHHO..."},
    "s": {0: ".....O..OO..O...", 1: "....OHOOHHOOHOL.", 2: "....OHHHHHHHHO..", 6: "......H........."},
}
PATCHES = {"d": {15: ".........Q......", 20: "......Q........."}, "s": {15: ".....Q..........", 20: ".......Q........"},
           "u": {14: "......Q........."}}
SCARF_SIDES = {"d": {6: "..OK........KO..", 7: "..OK........KO..", 8: "..OK........KO..", 9: "..OK........KO..",
                     10: "...OK......KO..."}}
CANE = {"d": {r: "...............w" for r in range(12, 24)}, "s": {r: "..w............." for r in range(13, 24)}}


CLOAK_INTERN = {
    "d": {
        12: "...OMMAAAAMMO...", 13: "..OMMMAAAAMMMO..", 14: "..OMMMAARAMMMO..",
        15: "..OMMAAARAAMMO..", 16: "..OSOAAARAAOSO..", 17: "...OOAAAAAAOO...",
    },
    "u": {
        12: "...OMMMMMMMMO...", 13: "..OMMMMMMMMMMO..", 14: "..OMMMMMMMMMMO..",
        15: "..OMMMMMMMMMMO..", 16: "..OMmMMMMMMmMO..", 17: "...OOMMMMMMOO...",
        18: "....OmMMMMmO....",
    },
    "s": {
        12: ".....OAAAAOM....", 13: "....OAAAAAAOMM..", 14: "....OAAaAAAOMMM.",
        15: "....OAARAAAOMMM.", 16: "....OAOSOAAOMMM.", 17: "....OBBOBBBOMM..",
        18: ".....OAAAAOMm...",
    },
}

def base_pal(**over):
    p = {
        "O": C["out"], "E": C["black"], "S": C["skin"], "s": C["skin_d"],
        "H": C["brown"], "h": C["brown_d"], "A": C["blue"], "a": C["blue_d"], "B": C["brown_d"],
        "P": C["brown"], "p": C["brown_d"], "F": C["brown_d"],
        "W": C["white"], "w": C["grey_l"], "k": C["black"], "Y": C["gold"], "y": C["gold_d"],
        "R": C["red"], "D": C["water"], "G": C["stone_l"], "g": C["stone"],
        "L": C["blue_l"], "b": C["blue"], "d": C["blue_d"], "M": C["brown"], "m": C["brown_d"],
        "n": C["brown"], "N": C["red"], "Q": C["blue_l"], "K": C["purple"],
    }
    p.update(over)
    return p


# ------------------------------------------------------------------ personagens
CHARS = {
    "npc_king": dict(
        pal=base_pal(H=C["grey_l"], h=C["grey"], A=C["purple"], a=C["purple_d"], B=C["gold"],
                     P=C["purple"], p=C["purple_d"], F=C["gold_d"]),
        pal_u=dict(A=C["red"], a=C["red_d"], B=C["red_d"]),
        dress=True, ov=[(CROWN, "all", 0), (KING_BEARD, "ds", 0), (ERMINE, "dus", 0)],
    ),
    "npc_baker": dict(
        pal=base_pal(H=C["brown_l"], h=C["brown"], A=C["cream"], a=C["dirt"], B=C["brown_d"],
                     P=C["brown"], p=C["brown_d"], F=C["wood_d"], w=C["grey_l"]),
        ov=[(CAP, "all", 0), (MUSTACHE, "ds", 0), (APRON_W, "dus", 0)],
    ),
    "npc_smith": dict(
        pal=base_pal(S=C["skin"], s=C["skin_d"], H=C["brown_d"], h=C["out"], A=C["grey_d"], a=C["stone_dd"],
                     B=C["black"], P=C["out2"], p=C["black"], F=C["black"], M=C["wood"], m=C["wood_d"]),
        ov=[(BARE_ARMS, "dus", 0), (APRON_M, "dus", 0), (BLACK_BEARD, "ds", 0)],
    ),
    "npc_guard": dict(
        pal=base_pal(A=C["red"], a=C["red_d"], B=C["gold"], P=C["brown"], p=C["brown_d"], F=C["out"],
                     w=C["wood_d"], H=C["brown_d"]),
        ov=[(HELMET, "dus", 0), (GUARD_ARMS, "dus", 0), (SPEAR, "dus_under", 0)],
    ),
    "npc_priestess": dict(
        pal=base_pal(H=C["wood_d"], h=C["out"], A=C["white"], a=C["grey_l"], B=C["gold"], F=C["gold_d"]),
        dress=True, ov=[(BUN, "dus", 0), (LONG_HAIR, "ds", 0), (PENDANT, "d", 0)],
    ),
    "npc_merchant": dict(
        pal=base_pal(S=C["skin2"], s=C["skin2_d"], H=C["black"], h=C["out2"], A=C["teal"], a=C["teal_d"],
                     B=C["brown_d"], P=C["brown_d"], p=C["out"], F=C["out"], n=C["brown_l"], N=C["red"]),
        ov=[(HAT, "all", 0), (MUSTACHE, "ds", 0), (BACKPACK, "u", 0), (POUCH, "ds", 0)],
    ),
    "player_intern": dict(
        pal=base_pal(H=C["brown_d"], h=C["out"], A=C["white"], a=C["grey_l"], B=C["grey_d"],
                     P=C["stone_dd"], p=C["out2"], F=C["black"], R=C["red"], M=C["brown"], m=C["brown_d"]),
        head={
        "s": [
            "................",
            "......OOOOOO....",
            ".....OHHHHHHO...",
            "....OHHHHHHHHO..",
            "...OHHHHHHHHHO..",
            "...OHhSSHHHHhO..",
            "...OSSSSSSSHhO..",
            "..OSSESSSSSHhO..",
            "..OSSESSSSShO...",
            ".OSSSSSSSSsO....",
            "..OsSSSSSsO.....",
            "...OOOOOOO......",
        ],
        },
        body={
        "s": [
            ".....OAMMMMO....",
            "....OAAMMMMMO...",
            "....ORAMMMMMO...",
            "....OAAMmMMMO...",
            "....OSOMMmMMO...",
            ".....OMMMMMO....",
            ".....OAAAAO.....",
        ],
        },
        crouch=True,
        ov=[(CLOAK_INTERN, "du", 0)],
    ),
    "npc_orphan": dict(
        pal=base_pal(H=C["orange"], h=C["red"], A=C["brown_l"], a=C["brown"], B=C["brown_d"],
                     P=C["brown"], p=C["brown_d"], F=C["skin_d"], L=C["leaf"], Q=C["blue_l"]),
        ov=[(MESSY, "dus", 0), (PATCHES, "dus", 0)], child=True,
    ),
    # moradores extras (decorativos)
    "villager_farmer": dict(
        pal=base_pal(A=C["leaf"], a=C["leaf_d"], B=C["brown_d"], P=C["blue_d"], p=C["out2"], n=C["yellow"],
                     H=C["brown"]),
        ov=[(STRAW_HAT, "all", 0)],
    ),
    "villager_woman": dict(
        pal=base_pal(H=C["yellow"], h=C["orange"], A=C["red"], a=C["red_d"], B=C["cream"], F=C["wood_d"]),
        dress=True, ov=[(LONG_HAIR, "ds", 0)],
    ),
    "villager_elder": dict(
        pal=base_pal(H=C["grey_l"], h=C["grey"], A=C["brown"], a=C["brown_d"], B=C["out"], F=C["out"],
                     w=C["wood_d"]),
        dress=True, ov=[(KING_BEARD, "ds", 0), (CANE, "ds_under", 0)],
    ),
    "villager_boy": dict(
        pal=base_pal(H=C["black"], h=C["out2"], A=C["blue_l"], a=C["blue"], P=C["brown_d"], p=C["out"]),
        ov=[], child=True,
    ),
    "villager_lady": dict(
        pal=base_pal(H=C["purple_l"], h=C["purple"], K=C["purple_l"], A=C["teal_l"], a=C["teal"], B=C["cream"],
                     S=C["skin2"], s=C["skin2_d"], F=C["out"]),
        dress=True, ov=[(SCARF_SIDES, "d", 0)],
    ),
}


def _scope_ok(scope, d):
    base = scope.replace("_under", "")
    return base == "all" or d in base


def build_frame(spec, d, f, crouch=False):
    rows = compose(d, f, spec.get("dress", False))
    if spec.get("head", {}).get(d):
        rows[0:12] = spec["head"][d]
    if spec.get("body", {}).get(d):
        rows[12:19] = spec["body"][d]
    for ov, scope, dx in spec.get("ov", []):
        if not _scope_ok(scope, d):
            continue
        if all(isinstance(k, int) for k in ov):
            data = ov
        elif d in ov:
            data = ov[d]
        else:
            continue
        rows = apply(rows, data, "under" if scope.endswith("_under") else "over", dx)
    if spec.get("child"):
        rows = [r for i, r in enumerate(rows) if i not in (13, 18, 20)]
        rows = ["." * W] * 3 + rows
    if crouch:
        # agachado: 1 linha do tronco + 2 das pernas (mantém a cabeça inteira e as pernas legíveis)
        rows = [r for i, r in enumerate(rows) if i not in (13, 20, 21)]
        rows = ["." * W] * 3 + rows
        if d == "d" and f in (0, 2):  # joelhos abertos
            rows[-3:] = ["...OPPO....OPPO.", "...OFFO....OFFO.", "....OO......OO.."]
        if d == "u" and f in (0, 2):
            rows[-3:] = ["...OPPO....OPPO.", "...OFFO....OFFO.", "....OO......OO.."]
        if d == "s":
            rows[3:12] = [("." + r[:-1]) for r in rows[3:12]]  # tronco/cabeça 1px à frente
    pal = dict(spec["pal"])
    if d == "u" and "pal_u" in spec:
        pal.update(spec["pal_u"])
    return from_ascii(rows, pal, W)


def build_sheet(spec):
    dirs = ("d", "u", "s")
    rows = [[build_frame(spec, d, f) for f in range(4)] for d in dirs]
    if spec.get("crouch"):
        rows += [[build_frame(spec, d, f, True) for f in range(4)] for d in dirs]
    return grid(rows)


def shadow():
    img = new(14, 5)
    from common import ellipse
    ellipse(img, 7, 2.5, 6.5, 2.2, (24, 20, 37, 90))
    ellipse(img, 7, 2.5, 4.5, 1.4, (24, 20, 37, 120))
    return img


def build_all():
    out = {}
    for cid, spec in CHARS.items():
        sheet = build_sheet(spec)
        save(sheet, f"chars/{cid}.png")
        out[cid] = sheet
    save(shadow(), "chars/shadow.png")
    return out


if __name__ == "__main__":
    sheets = build_all()
    # prévia ampliada
    from PIL import Image
    prev = new(64 * 6 + 8, (72 * 6 + 8) * 2, (60, 110, 60, 255))
    tiles = list(sheets.values())
    cols = 6
    big = new(cols * (64 * 4 + 8), ((len(tiles) + cols - 1) // cols) * (72 * 4 + 8), (110, 170, 90, 255))
    for i, s in enumerate(tiles):
        big.alpha_composite(s.resize((s.width * 4, s.height * 4), Image.NEAREST),
                            ((i % cols) * (64 * 4 + 8), (i // cols) * (72 * 4 + 8)))
    big.save(__import__("os").path.join(__import__("os").path.dirname(__file__), "_preview_chars.png"))
    print("ok", len(sheets))
