#!/usr/bin/env python3
"""Extrai a tabela das 20 especies recrutaveis (banco $09:$4000, 20 bytes cada).

Campos confirmados comparando com a RAM do jogo rodando (lista $DE00 / bloco $C900):
  +0  nivel em que a forma aparece (1 = forma inicial; 10, 11, 28... = evoluida)
  +1  id grafico da especie (indice de retrato/sprite)
  +2  tipo 1..5 (1 Celerity, 2 Equilibrium, 3 Strength, 4 Super Power, 5 Defense)
  +3  SP base (u16 LE)
  +5  HP base (u16 LE)
  +7  ATK   +8 PRE (precisao)   +9 ESQ (esquiva)  -- acerto% = 100 + PRE(atac) - ESQ(def)
  +10 MOV: pontos de movimento; custo por casa em $09:$4190 + especie*33 + terreno
  +11 tipo contra o qual e forte   (ciclo 1>2>3>4>5>1)
  +12 tipo contra o qual e fraco
  +13 1 = ja vem no time no comeco do jogo
  +14 alcance minimo de ataque     +15 alcance maximo
  +16..+17 golpes especiais / ids de skill (0 = nenhum)
  +18..+19 sempre 00
Uso: extract_species.py ROM saida.json
"""
import json, sys

rom = open(sys.argv[1], 'rb').read()
BASE = 0x09 * 0x4000          # banco $09, endereco $4000
COUNT = 20
TYPES = {1: 'Celerity', 2: 'Equilibrium', 3: 'Strength', 4: 'SuperPower', 5: 'Defense'}

out = []
for i in range(COUNT):
    r = rom[BASE + i * 20: BASE + i * 20 + 20]
    out.append({
        'index': i,
        'level': r[0],
        'gfx_id': r[1],
        'type': TYPES.get(r[2], r[2]),
        'sp': r[3] | r[4] << 8,
        'hp': r[5] | r[6] << 8,
        'atk': r[7], 'acc': r[8], 'eva': r[9],
        'move': r[10],
        'strong_vs': TYPES.get(r[11], r[11]),
        'weak_vs': TYPES.get(r[12], r[12]),
        'starter': bool(r[13]),
        'range': [r[14], r[15]],
        'skills': [x for x in r[16:18] if x],
        'raw': r.hex(' '),
    })

json.dump(out, open(sys.argv[2], 'w'), indent=1)
print('%-3s %-4s %-4s %-11s %4s %4s %4s %4s %4s %4s %-7s %s' %
      ('#', 'lv', 'gfx', 'tipo', 'HP', 'SP', 'ATK', 'PRE', 'ESQ', 'MOV', 'alcance', 'skills'))
for s in out:
    print('%-3d %-4d %02X   %-11s %4d %4d %4d %4d %4d %4d %-7s %s%s' % (
        s['index'], s['level'], s['gfx_id'], s['type'], s['hp'], s['sp'], s['atk'], s['acc'],
        s['eva'], s['move'], '%d-%d' % tuple(s['range']), s['skills'], '  *inicial' if s['starter'] else ''))
