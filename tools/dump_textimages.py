#!/usr/bin/env python3
"""Renderiza os "textos em imagem" (nomes de Pokémon, golpes etc.) de um banco com o
formato do carregador ROM0:$300B: tabela [banco, 00, ptr u16] por id em BANCO:$4000;
cada imagem tem W x H tiles em ordem de linhas.
Uso: dump_textimages.py ROM banco_hex largura altura primeiro_id ultimo_id saida.png"""
import sys
from PIL import Image, ImageDraw
rom = open(sys.argv[1], 'rb').read()
bank, W, H, first, last = int(sys.argv[2], 16), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5], 16), int(sys.argv[6], 16)
at = lambda b, a: b * 0x4000 + a - 0x4000
S = [255, 170, 85, 0]
def tile(o):
    im = Image.new('L', (8, 8)); p = im.load()
    for y in range(8):
        lo, hi = rom[o + 2 * y], rom[o + 2 * y + 1]
        for x in range(8): p[x, y] = S[((lo >> (7 - x)) & 1) | (((hi >> (7 - x)) & 1) << 1)]
    return im
n = last - first + 1
cols = 3
cw, ch = W * 8 + 40, H * 8 + 6
img = Image.new('L', (cols * cw, ((n + cols - 1) // cols) * ch), 255)
d = ImageDraw.Draw(img)
for k in range(n):
    i = first + k
    o = at(bank, 0x4000) + i * 4
    bk, a = rom[o], rom[o + 2] | rom[o + 3] << 8
    x0, y0 = (k % cols) * cw, (k // cols) * ch
    d.text((x0, y0 + 2), '%02X' % i, fill=0)
    if not (0x4000 <= a < 0x8000):
        continue
    for t in range(W * H):
        img.paste(tile(at(bk, a) + t * 16), (x0 + 22 + (t % W) * 8, y0 + (t // W) * 8))
img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(sys.argv[7])
