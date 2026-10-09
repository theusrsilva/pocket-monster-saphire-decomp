#!/usr/bin/env python3
"""Renderiza o mapa de uma fase direto da ROM.

Cabecalho da fase: banco $7D:$4000 + fase*64 (copiado para $C300 pelo jogo).
Entradas de 4 bytes [banco, 00, ptr lo, ptr hi]:
  +00 paletas de BG (64 bytes, 8x4 cores BGR555)    +04 paletas de OBJ
  +08/+0C/+10 blocos de tiles: [destino u16][tamanho u16] + dados (destino >= $9800 volta p/ $8800)
  +14..+20 mapas extras para $9800/$9C00 (nulos nas fases)
  +24 mapa: ids de metatile u16, (+38/2) colunas x (+3A) linhas, celula de 16x16 px
  +28 metatiles: 8 bytes = tiles TL TR BL BR + atributos CGB de cada um
  +2C, +30 dados auxiliares da fase (ainda nao identificados)
  +34 u16 scroll max X  +36 u16 scroll max Y  +38 u16 bytes por linha  +3A linhas  +3C u16 tamanho
LCDC = $E7: fundo usa enderecamento com sinal ($8800-$97FF, tile 0 em $9000).

Uso: render_stage.py ROM fase saida.png  (ou 'all' para todas, saida = pasta)
"""
import os, sys
from PIL import Image

rom = b''


def load(path):
    global rom
    rom = open(path, 'rb').read()
    return rom


def at(bank, addr):
    return bank * 0x4000 + (addr - 0x4000)


def header(stage):
    h = rom[at(0x7D, 0x4000) + stage * 64: at(0x7D, 0x4000) + stage * 64 + 64]
    ents = []
    for k in range(13):
        bk, _, lo, hi = h[k * 4:k * 4 + 4]
        ents.append((bk, hi << 8 | lo))
    w = h[0x38] | h[0x39] << 8
    rows = h[0x3A]
    return ents, w, rows


def bgr555(lo, hi):
    v = lo | hi << 8
    r, g, b = v & 31, (v >> 5) & 31, (v >> 10) & 31
    return (r * 255 // 31, g * 255 // 31, b * 255 // 31)


def draw_tile(px, ox, oy, t, attr, vram, pal):
    p = pal[attr & 7]
    src = vram[(attr >> 3) & 1]
    addr = 0x9000 + (t if t < 128 else t - 256) * 16 - 0x8000
    for y in range(8):
        yy = 7 - y if attr & 0x40 else y
        lo, hi = src[addr + yy * 2], src[addr + yy * 2 + 1]
        for x in range(8):
            xx = 7 - x if attr & 0x20 else x
            px[ox + x, oy + y] = p[((lo >> (7 - xx)) & 1) | (((hi >> (7 - xx)) & 1) << 1)]


def render(stage):
    ents, rowbytes, rows = header(stage)
    pb, pa = ents[0]
    pal = [[bgr555(rom[at(pb, pa) + p * 8 + c * 2], rom[at(pb, pa) + p * 8 + c * 2 + 1])
            for c in range(4)] for p in range(8)]
    vram = [bytearray(0x2000), bytearray(0x2000)]   # 2 bancos de VRAM ($8000-$9FFF)
    for k in (2, 3, 4):
        bk, a = ents[k]
        if not a:
            continue
        o = at(bk, a)
        dest = rom[o] | rom[o + 1] << 8
        size = rom[o + 2] | rom[o + 3] << 8
        o += 4
        for i in range(size):
            if dest >= 0x9800:
                dest = 0x8800
            vram[0][dest - 0x8000] = rom[o + i]
            dest += 1
    mb, ma = ents[9]               # mapa: ids de metatile u16, 32 por linha
    tb, ta = ents[10]              # metatiles: 4 tiles (TL TR BL BR) + 4 atributos
    cols = rowbytes // 2
    img = Image.new('RGB', (cols * 16, rows * 16))
    px = img.load()
    for cy in range(rows):
        for cx in range(cols):
            o = at(mb, ma) + (cy * cols + cx) * 2
            mt = rom[o] | rom[o + 1] << 8
            mo = at(tb, ta) + mt * 8
            for q in range(4):
                t, attr = rom[mo + q], rom[mo + 4 + q]
                draw_tile(px, cx * 16 + (q & 1) * 8, cy * 16 + (q >> 1) * 8, t, attr, vram, pal)
    return img


if __name__ == '__main__':
    load(sys.argv[1])
    if sys.argv[2] == 'all':
        os.makedirs(sys.argv[3], exist_ok=True)
        for s in range(32):
            render(s).save(os.path.join(sys.argv[3], 'stage_%02d.png' % s))
        print('ok')
    else:
        render(int(sys.argv[2])).save(sys.argv[3])
