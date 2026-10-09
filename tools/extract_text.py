#!/usr/bin/env python3
"""Extrai o script de falas do Pocket Monster Saphire (GBC, Sintax, 2003).

O "texto" do jogo e um bytecode simples:
  - bytes < $E0 sao caracteres (ASCII; $A1 e outros > $7E sao glifos especiais)
  - bytes $E0-$FF sao comandos; a tabela em ROM0:$3427 tem 4 bytes por
    comando: [ponteiro do handler lo, hi, tamanho da instrucao, 00]
  - $FF termina a mensagem

Mensagens sao indexadas por uma tabela em banco $5D:$4000
(script [c2b0] -> lista de entradas de 4 bytes [lo, hi, banco, 00]).

Uso: extract_text.py ROM saida.json saida.txt
"""
import json, re, sys

rom = open(sys.argv[1], 'rb').read()
out_json, out_txt = sys.argv[2], sys.argv[3]

CMD_TABLE = 0x3427
CMD_LEN = {0xE0 + i: rom[CMD_TABLE + i * 4 + 2] for i in range(32)}
CMD_NAME = {0xEA: 'SPK', 0xEE: 'GIVE', 0xFF: 'END'}
TEXT_BANKS = (0x5D, 0x70)


def decode(a):
    s, i = [], a
    while i < len(rom):
        c = rom[i]
        if c == 0xFF:
            return ''.join(s), i + 1
        if c < 0xE0:
            s.append(chr(c) if 32 <= c < 127 else '{%02X}' % c)
            i += 1
        else:
            n = max(CMD_LEN[c], 1)
            args = rom[i + 1:i + n]
            s.append('{%s%s}' % (CMD_NAME.get(c, '%02X' % c),
                                 (':' + args.hex().upper()) if args else ''))
            i += n
        if i - a > 4000:
            break
    return ''.join(s), i


entries = []
for bank in TEXT_BANKS:
    base = bank * 0x4000
    i = base
    while i < base + 0x4000:
        m = re.compile(rb'[A-Za-z][ -~]{7,}').search(rom, i, base + 0x4000)
        if not m:
            break
        st = m.start()
        # inclui comandos imediatamente antes (ex.: EA xx antes da fala)
        b = st
        if b >= 2 and rom[b - 2] == 0xEA:
            b -= 2
        text, end = decode(b)
        plain = re.sub(r'\{[^}]*\}', '', text)
        if sum(ch.isalpha() for ch in plain) >= 6:
            entries.append({'rom': '%06X' % b, 'bank': '%02X' % bank,
                            'addr': '%04X' % (0x4000 + b - base),
                            'len': end - b, 'text': text})
        i = max(end, st + 1)

json.dump(entries, open(out_json, 'w'), indent=1, ensure_ascii=False)
with open(out_txt, 'w') as f:
    for e in entries:
        f.write('[%s | %s:%s] %s\n' % (e['rom'], e['bank'], e['addr'], e['text']))
print(len(entries), 'mensagens,',
      sum(len(re.sub(r'\{[^}]*\}', '', e['text'])) for e in entries), 'caracteres')
print('tamanhos dos comandos:', {('%02X' % k): v for k, v in CMD_LEN.items()})
