#!/usr/bin/env python3
"""Despeja cada banco usado da ROM como folha de tiles 2bpp (PNG).

Uso: dump_tiles.py ROM OUTDIR
Gera OUTDIR/bank_XX.png (16 tiles por linha, 4 tons de cinza, escala 2x)
e OUTDIR/overview.png com uma miniatura de cada banco.
"""
import os, sys
from PIL import Image, ImageDraw

rom = open(sys.argv[1], 'rb').read()
outdir = sys.argv[2]
os.makedirs(outdir, exist_ok=True)
SHADES = [255, 170, 85, 0]
TPR = 16          # tiles por linha
BANK = 0x4000

def tile_pixels(buf, off):
    px = []
    for row in range(8):
        lo = buf[off + row * 2]
        hi = buf[off + row * 2 + 1]
        px.append([SHADES[((lo >> (7 - x)) & 1) | (((hi >> (7 - x)) & 1) << 1)] for x in range(8)])
    return px

def render(buf):
    ntiles = len(buf) // 16
    rows = (ntiles + TPR - 1) // TPR
    img = Image.new('L', (TPR * 8, rows * 8), 255)
    p = img.load()
    for t in range(ntiles):
        tp = tile_pixels(buf, t * 16)
        ox, oy = (t % TPR) * 8, (t // TPR) * 8
        for y in range(8):
            for x in range(8):
                p[ox + x, oy + y] = tp[y][x]
    return img

thumbs = []
for b in range(len(rom) // BANK):
    blk = rom[b * BANK:(b + 1) * BANK]
    if not any(blk):
        continue
    img = render(blk)
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(os.path.join(outdir, 'bank_%02X.png' % b))
    thumbs.append((b, img))

# overview: 8 bancos por linha
cols = 8
tw, th = thumbs[0][1].size
ov = Image.new('L', (cols * (tw + 4), ((len(thumbs) + cols - 1) // cols) * (th + 14)), 255)
dr = ImageDraw.Draw(ov)
for i, (b, img) in enumerate(thumbs):
    x, y = (i % cols) * (tw + 4), (i // cols) * (th + 14)
    dr.text((x + 2, y), 'bank %02X' % b, fill=0)
    ov.paste(img, (x, y + 12))
ov.save(os.path.join(outdir, 'overview.png'))
print('ok', len(thumbs), 'bancos')
