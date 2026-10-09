#!/usr/bin/env python3
"""Controle passo a passo: play.py IN_STATE OUT_STATE "a b up*3 wait60 start" SHOT.png
Cada token: botao[*n] (a,b,start,select,up,down,left,right) ou waitN.
Salva screenshot 3x e dump de WRAM (OUT_STATE.wram)."""
import os, sys; os.environ['SDL_VIDEODRIVER']='dummy'
sys.path.insert(0, os.path.dirname(__file__))
from run_headless import Emu
from PIL import Image
rom = os.path.join(os.path.dirname(__file__), '..', 'rom', 'saphire.gbc')
e = Emu(rom, '/tmp')
if sys.argv[1] != '-':
    with open(sys.argv[1], 'rb') as f: e.pb.load_state(f)
frames = []
for tok in sys.argv[3].split():
    if tok.startswith('wait'):
        e.wait(int(tok[4:]))
    else:
        b, _, n = tok.partition('*')
        for _ in range(int(n or 1)):
            e.press(b, 4, 16)
    frames.append(e.pb.screen.image.copy())
with open(sys.argv[2], 'wb') as f: e.pb.save_state(f)
open(sys.argv[2] + '.wram', 'wb').write(e.wram())
open(sys.argv[2] + '.hram', 'wb').write(e.mem(0xFF80, 0x7F))
im = e.pb.screen.image.convert('RGB')
im.resize((480, 432), Image.NEAREST).save(sys.argv[4])
