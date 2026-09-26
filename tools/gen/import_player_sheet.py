"""Converte uma folha gerada por IA (fundo magenta) em assets/gen/chars/player_intern.png (64x72, 4x3 frames de 16x24).
Uso: python import_player_sheet.py caminho/da/imagem.png"""
import sys

from PIL import Image

from common import OUT


def main(path):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, _ = px[x, y]
            if r > 200 and b > 200 and g < 90:
                px[x, y] = (0, 0, 0, 0)
    box = im.getbbox()
    if box:
        im = im.crop(box)
    im = im.resize((64, 72), Image.NEAREST)
    im.save(f"{OUT}/chars/player_intern.png")
    print("salvo em assets/gen/chars/player_intern.png", im.size)


if __name__ == "__main__":
    main(sys.argv[1])
