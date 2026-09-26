"""Layout do mapa (coordenadas do MUNDO, 1280x960; 1 pixel nativo = 2 unidades do mundo; célula = 32)."""
CELL = 32
COLS, ROWS = 40, 30

LOCATIONS = {
    "throne": (640, 110),
    "castle_gate": (640, 238),
    "castle_yard": (640, 284),
    "fountain": (640, 404),
    "plaza": (604, 474),
    "well": (548, 392),
    "notice_board": (732, 360),
    "stall": (716, 464),
    "bakery": (304, 440),
    "residence": (112, 440),
    "forge": (968, 440),
    "temple": (224, 728),
    "lake": (880, 694),
    "forest": (1130, 170),
    "road_south": (640, 944),
}

CASTLE = (448, 0, 384, 224)          # x, y, w, h
LAKE = (900, 800, 170, 88)           # cx, cy, rx, ry

# casas: id, tipo, x0, y0 (mundo, múltiplos de 32), porta (índice do tile)
BUILDINGS = [
    ("res_a", "house_red_wood_4", 32, 320),
    ("bakery", "bakery", 224, 320),
    ("res_b", "house_grey_stone_3", 416, 320),
    ("forge", "forge", 896, 320),
    ("res_c", "house_red_stone_4", 1088, 320),
    ("res_d", "house_grey_wood_4x2", 352, 544),
    ("res_f", "house_red_wood_3", 512, 544),
    ("res_e", "house_grey_stone_3", 1120, 544),
    ("temple", "temple", 128, 576),
]

FARM = (16, 800, 128, 96)            # canteiros (x, y, w, h)

# tipo -> (largura em tiles, altura em tiles, índice do tile da porta)
BTYPES = {
    "house_red_wood_4": (4, 3, 1),
    "house_red_wood_3": (3, 3, 1),
    "house_red_stone_4": (4, 3, 2),
    "house_grey_stone_3": (3, 3, 1),
    "house_grey_wood_4x2": (4, 4, 1),
    "bakery": (5, 3, 2),
    "forge": (5, 3, 2),
    "temple": (6, 4, None),
}


def _cells(c0, c1, r0, r1):
    return {(c, r) for c in range(c0, c1 + 1) for r in range(r0, r1 + 1)}


ROAD = set()
ROAD |= _cells(19, 20, 7, 10)        # castelo -> praça
ROAD |= _cells(17, 22, 7, 8)         # pátio do castelo
ROAD |= _cells(0, 39, 14, 15)        # estrada leste-oeste
ROAD |= _cells(19, 20, 16, 29)       # estrada sul
ROAD |= _cells(5, 18, 23, 24)        # estrada do templo
ROAD |= _cells(6, 7, 22, 22)         # acesso à porta do templo
PLAZA = _cells(16, 23, 10, 15)


def door_paths():
    """Células de 'pedras de passagem' da porta de cada casa até a estrada."""
    out = set()
    for _id, kind, x0, y0 in BUILDINGS:
        w, h, door = BTYPES[kind]
        if door is None:
            continue
        c = x0 // CELL + door
        r = (y0 + h * CELL) // CELL
        for _ in range(4):
            if (c, r) in ROAD or (c, r) in PLAZA:
                break
            out.add((c, r))
            r += 1
    return out


STEPS = door_paths()

VILLAGERS = {
    "villager_farmer": (80, 776),
    "villager_woman": (420, 700),
    "villager_elder": (300, 770),
    "villager_boy": (560, 530),
    "villager_lady": (1150, 440),
}
