#!/usr/bin/env python3
"""Extrai as 32 fases: cabecalho, inimigos, posicoes iniciais dos aliados e mapa anotado.

Fontes na ROM:
  cabecalho da fase  $7D:$4000 + fase*64           (ver render_stage.py)
  inimigos           $30:$40E6 -> 32 ponteiros u16 (banco $30), lista de registros de 24 bytes,
                     terminada por nivel = $FF. Copiados para a SRAM $B200 (20 vagas x 64 bytes).
  inicio dos aliados $10:$450E -> 32 ponteiros u16 (banco $10), registros de 6 bytes
                     [00 00, y u16, x u16], terminados por $FFFF (10 vagas por fase)
  sprites do mapa    $FD:$4000 + especie*64 (16x16, tiles TL TR BL BR)

Registro de inimigo (24 bytes):
  +0 nivel  +1 especie  +2 tipo  +3 y(px u16)  +5 x(px u16)  +7 slot grafico
  +8 SP(u16)  +10 HP(u16)  +12 ATK  +13 DEF  +14 SPD  +15 MOV  +16 forte contra
  +17 fraco contra  +18 alcance min  +19 alcance max  +20..+23 golpe [id, poder, custo, ?]

Uso: extract_stages.py ROM saida.json pasta_png
"""
import json, os, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
rom = open(sys.argv[1], 'rb').read()


def at(bank, addr):
    return bank * 0x4000 + (addr - 0x4000)


def u16(o):
    return rom[o] | rom[o + 1] << 8


TYPES = {1: 'Celerity', 2: 'Equilibrium', 3: 'Strength', 4: 'SuperPower', 5: 'Defense'}
NSTAGES = 32


def enemies(stage):
    p = u16(at(0x30, 0x40E6) + stage * 2)
    if p == 0xFFFF:
        return []
    o = at(0x30, p)
    out = []
    while rom[o] != 0xFF and len(out) < 20:
        r = rom[o:o + 24]
        out.append({
            'level': r[0], 'species': r[1], 'type': TYPES.get(r[2], r[2]),
            'y': u16(o + 3) // 16, 'x': u16(o + 5) // 16, 'slot': r[7],
            'sp': u16(o + 8), 'hp': u16(o + 10), 'atk': r[12], 'def': r[13], 'spd': r[14],
            'move': r[15], 'strong_vs': TYPES.get(r[16], r[16]), 'weak_vs': TYPES.get(r[17], r[17]),
            'range': [r[18], r[19]], 'skill': list(r[20:24]) if r[20] else None,
            'raw': r.hex(' ')})
        o += 24
    return out


def starts(stage):
    p = u16(at(0x10, 0x450E) + stage * 2)
    o = at(0x10, p)
    out = []
    while u16(o) != 0xFFFF and len(out) < 10:
        out.append({'y': u16(o + 2) // 16, 'x': u16(o + 4) // 16})
        o += 6
    return out


def map_sprite(species):
    S = [(0, 0, 0, 0), (255, 255, 255, 255), (150, 150, 150, 255), (20, 20, 20, 255)]
    im = Image.new('RGBA', (16, 16))
    px = im.load()
    base = at(0xFD, 0x4000) + species * 64
    for q in range(4):
        for y in range(8):
            lo, hi = rom[base + q * 16 + y * 2], rom[base + q * 16 + y * 2 + 1]
            for x in range(8):
                c = ((lo >> (7 - x)) & 1) | (((hi >> (7 - x)) & 1) << 1)
                px[(q & 1) * 8 + x, (q >> 1) * 8 + y] = S[c]
    return im


if __name__ == '__main__':
    import render_stage
    render_stage.load(sys.argv[1])
    outdir = sys.argv[3]
    os.makedirs(outdir, exist_ok=True)
    data = []
    for s in range(NSTAGES):
        en, st = enemies(s), starts(s)
        img = render_stage.render(s).convert('RGBA')
        dr = ImageDraw.Draw(img)
        for e in en:
            x, y = e['x'] * 16, e['y'] * 16
            dr.rectangle([x, y, x + 15, y + 15], fill=(255, 60, 60, 120))
            img.alpha_composite(map_sprite(e['species']), (x, y))
            dr.rectangle([x, y, x + 15, y + 15], outline=(220, 0, 0, 255))
        for i, p in enumerate(st):
            x, y = p['x'] * 16, p['y'] * 16
            dr.rectangle([x + 1, y + 1, x + 14, y + 14], outline=(0, 90, 255, 255), width=2)
            dr.text((x + 5, y + 3), str(i + 1), fill=(0, 60, 200, 255))
        img.convert('RGB').save(os.path.join(outdir, 'stage_%02d_units.png' % s))
        data.append({'stage': s, 'enemies': en, 'player_starts': st})
        print('fase %2d: %2d inimigos, %2d posicoes iniciais' % (s, len(en), len(st)))
    json.dump(data, open(sys.argv[2], 'w'), indent=1)
