"""Guild-Trip-Logo (Monogramm "GT", vom Nutzer gewaehlt am 12.11.2026;
Stil von Entwurf A "Runenring" vom 10.11.2026 uebernommen).
Eigene Zeichnung: nachtblauer Grund (fraktionsneutral), goldener Ring mit Rautennieten, goldenes GT.
Erzeugt Emblem.tga (128 px, Fenster-Portrait) und ONE_Minimap.tga (64 px).
Aufruf: python3 scripts/build_logo.py
"""
from pathlib import Path
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
N=512
SERIF='/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'
def grad_radial(size, inner, outer):
    im=Image.new('RGBA',(size,size)); px=im.load(); c=size/2
    for y in range(size):
        for x in range(size):
            t=min(1,math.hypot(x-c,y-c)/c)
            px[x,y]=tuple(int(inner[i]*(1-t)+outer[i]*t) for i in range(3))+(255,)
    return im
def gold_text(img, text, size, cy=None, font=SERIF, stroke=10):
    """Goldschrift, exakt mittig (nach tatsaechlicher Buchstabenbox, nicht nach Schriftzeile)."""
    d=ImageDraw.Draw(img); f=ImageFont.truetype(font,size)
    l,t,r,b=d.textbbox((0,0),text,font=f,stroke_width=stroke)
    x=(N-(r-l))/2-l
    y=(N-(b-t))/2-t
    # gleichmaessiger dunkler Schein statt versetztem Schatten: wirkt optisch mittig
    sh=Image.new('RGBA',img.size,(0,0,0,0)); ImageDraw.Draw(sh).text((x,y),text,font=f,fill=(0,0,0,220),stroke_width=stroke+4,stroke_fill=(0,0,0,220))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    mask=Image.new('L',img.size,0); ImageDraw.Draw(mask).text((x,y),text,font=f,fill=255)
    outline=Image.new('L',img.size,0); ImageDraw.Draw(outline).text((x,y),text,font=f,fill=255,stroke_width=stroke,stroke_fill=255)
    dark=Image.new('RGBA',img.size,(40,20,6,255)); dark.putalpha(outline); img.alpha_composite(dark)
    top=y+t+stroke
    g=Image.new('RGBA',img.size); gd=ImageDraw.Draw(g)
    for yy in range(N):
        tt=min(1,max(0,(yy-top)/max(1,(b-t))))
        gd.line((0,yy,N,yy),fill=(int(255-40*tt),int(236-110*tt),int(160-120*tt),255))
    g.putalpha(mask); img.alpha_composite(g)
    hl=Image.new('L',img.size,0); ImageDraw.Draw(hl).text((x,y-3),text,font=f,fill=90)
    hl=ImageChops.subtract(hl,ImageChops.offset(mask,0,6))
    w2=Image.new('RGBA',img.size,(255,250,220,255)); w2.putalpha(hl); img.alpha_composite(w2)
def ring(img, r_out, r_in, top, bottom, notches=0):
    m=Image.new('L',img.size,0); d=ImageDraw.Draw(m); c=N/2
    d.ellipse((c-r_out,c-r_out,c+r_out,c+r_out),fill=255); d.ellipse((c-r_in,c-r_in,c+r_in,c+r_in),fill=0)
    g=Image.new('RGBA',img.size); gd=ImageDraw.Draw(g)
    for y in range(N):
        t=y/N; gd.line((0,y,N,y),fill=tuple(int(top[i]*(1-t)+bottom[i]*t) for i in range(3))+(255,))
    g.putalpha(m); img.alpha_composite(g)
    d=ImageDraw.Draw(img)
    d.ellipse((c-r_out,c-r_out,c+r_out,c+r_out),outline=(30,14,4,255),width=6)
    d.ellipse((c-r_in,c-r_in,c+r_in,c+r_in),outline=(30,14,4,255),width=6)
    for k in range(notches):
        a=2*math.pi*k/notches; rm=(r_out+r_in)/2
        x,y=c+rm*math.cos(a),c+rm*math.sin(a); s=(r_out-r_in)*.28
        d.polygon([(x,y-s),(x+s,y),(x,y+s),(x-s,y)],fill=(60,28,8,255))
        d.polygon([(x,y-s*.55),(x+s*.55,y),(x,y+s*.55),(x-s*.55,y)],fill=(255,214,120,255))
def disc(inner,outer):
    img=Image.new('RGBA',(N,N),(0,0,0,0)); g=grad_radial(N,inner,outer)
    m=Image.new('L',(N,N),0); ImageDraw.Draw(m).ellipse((0,0,N-1,N-1),fill=255); g.putalpha(m); img.alpha_composite(g); return img

OUT = Path(__file__).resolve().parents[1] / 'src' / 'ONE_Core' / 'Textures' / 'Common'
# Logo seit 0.6.2: Wappen der Gilden-Website (scripts/art/wappen.svg, eigene Zeichnung:
# Schild, gekreuzte Aexte, Kompass mit Fragezeichen) auf dunklem runden Grund.
import subprocess, io
# Farben wie das Profilbild der Website: dunkles Rot, zum Rand fast schwarz
RED_IN, RED_OUT = (110, 24, 18), (22, 8, 8)
WAPPEN = Path(__file__).resolve().parent / 'art' / 'wappen_gt.svg'   # Wappen mit GT statt Kompass
def wappen(height):
    png = subprocess.run(['rsvg-convert', '-h', str(height), str(WAPPEN)], check=True, capture_output=True).stdout
    return Image.open(io.BytesIO(png)).convert('RGBA')
def place(img, crest, cy_shift=0):
    shadow = Image.new('RGBA', crest.size, (0, 0, 0, 0))
    shadow.putalpha(crest.getchannel('A').point(lambda v: v * 0.7))
    x, y = (N - crest.width) // 2, (N - crest.height) // 2 + cy_shift
    img.alpha_composite(shadow, (x + 8, y + 12))
    img.alpha_composite(crest, (x, y))
# Minimap: mit eigenem Goldring (die Minimap-Umrandung ist schmal)
a=disc(RED_IN,RED_OUT); ring(a,250,200,(255,222,140),(150,98,36),notches=12)
place(a, wappen(int(N*0.62)))
a.resize((64,64),Image.LANCZOS).save(OUT/'ONE_Minimap.tga')
# Fenster-Portrait: OHNE eigenen Ring, denn Blizzards Portraitrahmen ist der Ring.
p=disc(RED_IN,RED_OUT)
place(p, wappen(int(N*0.66)))
p.resize((128,128),Image.LANCZOS).save(OUT/'Emblem.tga')
# Projektbild fuer CurseForge (400x400, nicht im Addon)
dist = Path(__file__).resolve().parents[1] / 'dist'
dist.mkdir(exist_ok=True)
c=disc(RED_IN,RED_OUT); ring(c,250,200,(255,222,140),(150,98,36),notches=12)
place(c, wappen(int(N*0.62)))
c.resize((400,400),Image.LANCZOS).save(dist/'GuildTrip_Logo_400.png')
print('geschrieben:', OUT/'Emblem.tga', OUT/'ONE_Minimap.tga', dist/'GuildTrip_Logo_400.png')
