#!/usr/bin/env python3
"""Lista as mensagens de um script do índice $5D:$4000.
O índice tem um ponteiro u16 por script ([$C2B0]); cada script é uma lista de entradas de 4 bytes
[lo, hi, banco, 00] indexada pela mensagem ([$C2B1]). Rotina leitora: ROM0:$3296.
Uso: script_messages.py ROM script_hex [primeira] [ultima]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
rom = open(sys.argv[1], 'rb').read()
at = lambda b, a: b * 0x4000 + a - 0x4000
CMD_LEN = {0xE0 + i: rom[0x3427 + i * 4 + 2] for i in range(32)}

def decode(o):
    s = []
    while True:
        c = rom[o]
        if c == 0xFF:
            return ''.join(s)
        if c < 0xE0:
            s.append(chr(c) if 32 <= c < 127 else '{%02X}' % c); o += 1
        else:
            n = max(CMD_LEN[c], 1)
            s.append('{%02X%s}' % (c, (':' + rom[o + 1:o + n].hex().upper()) if n > 1 else '')); o += n
        if len(s) > 600:
            return ''.join(s) + '...'

def message(script, idx):
    p = rom[at(0x5D, 0x4000) + script * 2] | rom[at(0x5D, 0x4000) + script * 2 + 1] << 8
    e = at(0x5D, p) + idx * 4
    lo, hi, bank = rom[e], rom[e + 1], rom[e + 2]
    addr = lo | hi << 8
    if not (0x4000 <= addr < 0x8000) or bank not in (0x5D, 0x70):
        return None, None
    return '%02X:%04X' % (bank, addr), decode(at(bank, addr))

if __name__ == '__main__':
    sc = int(sys.argv[2], 16)
    a = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    b = int(sys.argv[4]) if len(sys.argv) > 4 else 40
    for i in range(a, b + 1):
        where, txt = message(sc, i)
        if txt is not None:
            print('%3d [%s] %s' % (i, where, txt[:160]))
