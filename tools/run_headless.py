#!/usr/bin/env python3
"""Roda a ROM no PyBoy sem janela. Uso como modulo: from run_headless import Emu"""
import os, sys
os.environ.setdefault('SDL_VIDEODRIVER', 'dummy')
from pyboy import PyBoy

class Emu:
    def __init__(self, rom, outdir):
        self.pb = PyBoy(rom, window='null', sound_emulated=False, cgb=True)
        self.pb.set_emulation_speed(0)
        self.out = outdir; self.n = 0
        os.makedirs(outdir, exist_ok=True)
    def wait(self, frames):
        for _ in range(frames): self.pb.tick(1, False)
        self.pb.tick(1, True)
    def press(self, btn, hold=4, after=20):
        self.pb.button_press(btn); self.wait(hold); self.pb.button_release(btn); self.wait(after)
    def shot(self, name=None):
        self.n += 1
        p = os.path.join(self.out, '%03d_%s.png' % (self.n, name or 'shot'))
        self.pb.screen.image.save(p); return p
    def wram(self):
        return bytes(self.pb.memory[0xC000:0xE000])
    def mem(self, a, n=1):
        return bytes(self.pb.memory[a:a+n])
