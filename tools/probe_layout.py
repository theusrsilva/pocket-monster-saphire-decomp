#!/usr/bin/env python3
"""Testa arranjos de tiles: probe_layout.py ROM romoffset ntiles out.png"""
import sys
from PIL import Image, ImageDraw
rom=open(sys.argv[1],'rb').read(); off=int(sys.argv[2],16); n=int(sys.argv[3]); out=sys.argv[4]
S=[255,170,85,0]
def tile(t):
    o=off+t*16; im=Image.new('L',(8,8)); p=im.load()
    for y in range(8):
        lo,hi=rom[o+2*y],rom[o+2*y+1]
        for x in range(8): p[x,y]=S[((lo>>(7-x))&1)|(((hi>>(7-x))&1)<<1)]
    return im
tiles=[tile(t) for t in range(n)]
panels=[]
for mode in ('row','col','obj16'):
    for k in range(4,11):
        if mode=='row': w=k; h=(n+w-1)//w; pos=lambda t:(t%w,t//w)
        elif mode=='col': h=k; w=(n+h-1)//h; pos=lambda t:(t//h,t%h)
        else: w=k; h=((n//2+w-1)//w)*2; pos=lambda t:((t//2)%w, (t//2)//w*2 + t%2)
        im=Image.new('L',(w*8,h*8),255)
        for t in range(n):
            x,y=pos(t); im.paste(tiles[t],(x*8,y*8))
        panels.append(('%s%d'%(mode,k),im))
W=sum(p[1].width+6 for p in panels[:7]); 
rowsH=[max(p[1].height for p in panels[i*7:(i+1)*7])+12 for i in range(3)]
big=Image.new('L',(W,sum(rowsH)),255); d=ImageDraw.Draw(big); y=0
for r in range(3):
    x=0
    for name,im in panels[r*7:(r+1)*7]:
        d.text((x,y),name,fill=0); big.paste(im,(x,y+11)); x+=im.width+6
    y+=rowsH[r]
big=big.resize((big.width*2,big.height*2),Image.NEAREST); big.save(out); print(big.size)
