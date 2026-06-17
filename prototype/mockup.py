#!/usr/bin/env python3
"""
Prototype mockup renderer for the cinematic market command-center desktop app.
Produces a 1920x1080 still that represents the intended UI / look-and-feel.
This is a VISUAL PROP for video production: it displays data dramatically,
it does not (and cannot) control any real markets.
"""
import math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

random.seed(7)

W, H = 1920, 1080
F = "/usr/share/fonts/truetype/dejavu/"
def font(name, size): return ImageFont.truetype(F + name, size)

# palette
BG       = (8, 11, 18)
PANEL    = (15, 20, 30)
PANEL_HI = (20, 27, 40)
LINE     = (32, 44, 64)
CYAN     = (45, 226, 230)
GREEN    = (46, 230, 138)
RED      = (255, 78, 96)
GOLD     = (240, 196, 74)
TXT      = (208, 224, 240)
DIM      = (118, 138, 162)
WHITE    = (235, 245, 255)

f_brand  = font("DejaVuSans-Bold.ttf", 30)
f_sub    = font("DejaVuSans.ttf", 15)
f_h      = font("DejaVuSans-Bold.ttf", 17)
f_lbl    = font("DejaVuSans.ttf", 13)
f_mono   = font("DejaVuSansMono.ttf", 15)
f_monob  = font("DejaVuSansMono-Bold.ttf", 15)
f_big    = font("DejaVuSansMono-Bold.ttf", 40)
f_huge   = font("DejaVuSansMono-Bold.ttf", 54)
f_tiny   = font("DejaVuSansMono.ttf", 12)
f_clock  = font("DejaVuSansMono-Bold.ttf", 22)

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)

# subtle vignette / top glow background
glow = Image.new("RGB", (W, H), BG)
gd = ImageDraw.Draw(glow)
gd.ellipse([W//2-900, -700, W//2+900, 500], fill=(14, 26, 40))
glow = glow.filter(ImageFilter.GaussianBlur(180))
img = Image.blend(img, glow, 0.6)
d = ImageDraw.Draw(img)

def panel(x, y, w, h, title=None, accent=CYAN):
    d.rounded_rectangle([x, y, x+w, y+h], radius=10, fill=PANEL, outline=LINE, width=1)
    if title:
        d.line([x+14, y+34, x+w-14, y+34], fill=LINE, width=1)
        d.rectangle([x+14, y+16, x+18, y+30], fill=accent)
        d.text((x+28, y+15), title, font=f_h, fill=WHITE)
    return x, y

def glow_text(draw_img, xy, text, fnt, color, blur=6):
    layer = Image.new("RGB", (W, H), (0,0,0))
    ld = ImageDraw.Draw(layer)
    ld.text(xy, text, font=fnt, fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return ImageChops_screen(draw_img, layer)

from PIL import ImageChops
def screen(base, layer):
    return ImageChops.screen(base, layer)

# ---------------- HEADER ----------------
d.rectangle([0, 0, W, 74], fill=(11, 15, 23))
d.line([0, 74, W, 74], fill=LINE, width=1)
# logo mark
d.rounded_rectangle([28, 18, 70, 60], radius=8, outline=CYAN, width=2)
d.line([34, 50, 44, 34, 49, 44, 58, 26, 64, 40], fill=CYAN, width=2, joint="curve")
d.text((86, 14), "ATLAS  TERMINAL", font=f_brand, fill=WHITE)
d.text((88, 48), "GLOBAL  LIQUIDITY  COMMAND  ENGINE", font=f_sub, fill=CYAN)

# status pills
def pill(x, label, val, col):
    d.rounded_rectangle([x, 22, x+150, 52], radius=15, fill=PANEL_HI, outline=LINE)
    d.ellipse([x+14, 31, x+26, 43], fill=col)
    d.text((x+34, 27), f"{label}", font=f_tiny, fill=DIM)
    d.text((x+34, 37)[0:2], "", font=f_tiny, fill=DIM)
    d.text((x+34, 38), val, font=f_monob, fill=TXT)
px = 760
for lbl, vl, c in [("ENGINE", "LIVE", GREEN), ("LATENCY", "3ms", CYAN),
                   ("NODES", "1,284", CYAN), ("FEED", "YAHOO", GOLD)]:
    pill(px, lbl, vl, c); px += 162

d.text((W-250, 20), "GMT  17 JUN 2026", font=f_lbl, fill=DIM)
d.text((W-250, 40), "21:48:07", font=f_clock, fill=CYAN)

# ---------------- TICKER STRIP ----------------
ty = 84
d.rounded_rectangle([20, ty, W-20, ty+58], radius=8, fill=PANEL, outline=LINE)
tick = [("BTC/USD","104,820",  +2.41, GREEN),("XAU GOLD","2,398.6", +0.86, GREEN),
        ("S&P 500","5,612.4",  -0.32, RED),("NASDAQ","18,944",  +0.54, GREEN),
        ("ETH/USD","5,512.0",  +3.18, GREEN),("CRUDE WTI","78.42", -1.12, RED),
        ("EUR/USD","1.0914",   +0.07, GREEN),("DXY","104.1",  -0.21, RED)]
cw = (W-40)//len(tick)
for i,(s,v,ch,c) in enumerate(tick):
    x = 28 + i*cw
    d.text((x, ty+9), s, font=f_lbl, fill=DIM)
    d.text((x, ty+27), v, font=f_monob, fill=WHITE)
    arrow = "▲" if ch>=0 else "▼"
    d.text((x+96, ty+27), f"{arrow}{abs(ch):.2f}%", font=f_mono, fill=c)
    if i: d.line([x-12, ty+12, x-12, ty+46], fill=LINE)

# ---------------- LEFT: GLOBAL FLOW MAP ----------------
mx, my, mw, mh = 20, 158, 760, 470
panel(mx, my, mw, mh, "GLOBAL CAPITAL FLOW  ·  REAL-TIME", CYAN)
# stylized continents as dot cloud
random.seed(3)
def blob(cx, cy, rw, rh, n):
    pts=[]
    for _ in range(n):
        a=random.uniform(0,2*math.pi); r=random.uniform(0,1)
        x=cx+math.cos(a)*rw*r; y=cy+math.sin(a)*rh*r
        pts.append((x,y))
    return pts
dots=[]
for (cx,cy,rw,rh,n) in [(150,300,55,60,120),(230,360,40,55,80),(360,280,55,45,110),
                        (380,360,40,55,90),(560,300,80,50,160),(600,400,30,30,50),
                        (640,250,30,25,45)]:
    dots+=blob(mx+cx,my+cy,rw,rh,n)
for (x,y) in dots:
    d.ellipse([x-1,y-1,x+1,y+1], fill=(40,70,96))

# hub nodes (financial centers)
hubs={"NY":(mx+170,my+285),"LDN":(mx+350,my+250),"FRA":(mx+380,my+270),
      "TKO":(mx+650,my+285),"HK":(mx+600,my+330),"DXB":(mx+470,my+320),"SGP":(mx+610,my+380)}
# flow arcs
arc_layer = Image.new("RGB",(W,H),(0,0,0))
ad=ImageDraw.Draw(arc_layer)
flows=[("LDN","NY",GREEN),("TKO","LDN",CYAN),("HK","NY",GREEN),("DXB","LDN",GOLD),
       ("NY","SGP",CYAN),("FRA","HK",GREEN)]
for a,b,c in flows:
    (x1,y1),(x2,y2)=hubs[a],hubs[b]
    mxp=(x1+x2)/2; myp=min(y1,y2)-70
    prev=(x1,y1)
    for t in [i/40 for i in range(41)]:
        bx=(1-t)**2*x1+2*(1-t)*t*mxp+t*t*x2
        by=(1-t)**2*y1+2*(1-t)*t*myp+t*t*y2
        ad.line([prev,(bx,by)], fill=c, width=2); prev=(bx,by)
arc_layer=arc_layer.filter(ImageFilter.GaussianBlur(2))
img=ImageChops.screen(img,arc_layer); d=ImageDraw.Draw(img)
for a,b,c in flows:  # crisp line on top
    (x1,y1),(x2,y2)=hubs[a],hubs[b]; mxp=(x1+x2)/2; myp=min(y1,y2)-70
    prev=(x1,y1)
    for t in [i/40 for i in range(41)]:
        bx=(1-t)**2*x1+2*(1-t)*t*mxp+t*t*x2
        by=(1-t)**2*y1+2*(1-t)*t*myp+t*t*y2
        d.line([prev,(bx,by)], fill=c, width=1); prev=(bx,by)
for name,(x,y) in hubs.items():
    d.ellipse([x-16,y-16,x+16,y+16], outline=CYAN, width=1)
    d.ellipse([x-5,y-5,x+5,y+5], fill=CYAN)
    d.text((x+12,y+8), name, font=f_tiny, fill=TXT)
# metrics row inside map
d.text((mx+24, my+mh-34), "VOLUME 24H", font=f_tiny, fill=DIM)
d.text((mx+24, my+mh-20), "$4.82T", font=f_monob, fill=GREEN)
d.text((mx+220, my+mh-34), "ACTIVE FLOWS", font=f_tiny, fill=DIM)
d.text((mx+220, my+mh-20), "1,284", font=f_monob, fill=CYAN)
d.text((mx+430, my+mh-34), "NET INFLOW", font=f_tiny, fill=DIM)
d.text((mx+430, my+mh-20), "+$182.6B", font=f_monob, fill=GREEN)
d.text((mx+640, my+mh-34), "RISK", font=f_tiny, fill=DIM)
d.text((mx+640, my+mh-20), "ELEVATED", font=f_monob, fill=GOLD)

# ---------------- CENTER: BTC CHART ----------------
cx0, cy0, cw0, ch0 = 800, 158, 700, 300
panel(cx0, cy0, cw0, ch0, "BTC / USD  ·  1H  ·  YAHOO FINANCE", GOLD)
d.text((cx0+cw0-180, cy0+13), "104,820.40", font=f_h, fill=GREEN)
d.text((cx0+cw0-180, cy0+34), "+2.41%  +2,468", font=f_lbl, fill=GREEN)
# area chart
gx, gy, gw, gh = cx0+24, cy0+58, cw0-48, ch0-100
random.seed(11)
pts=[]; val=0.45
for i in range(gw//6+1):
    val += random.uniform(-0.06,0.07); val=max(0.08,min(0.92,val))
    pts.append((gx+i*6, gy+gh-val*gh))
# trend up bias
pts=[(x, y - (i/len(pts))*gh*0.35) for i,(x,y) in enumerate(pts)]
pts=[(x, max(gy+6,min(gy+gh,y))) for x,y in pts]
# fill
poly=[(gx,gy+gh)]+pts+[(gx+gw,gy+gh)]
fill_layer=Image.new("RGB",(W,H),(0,0,0)); fl=ImageDraw.Draw(fill_layer)
fl.polygon(poly, fill=(10,60,40))
fill_layer=fill_layer.filter(ImageFilter.GaussianBlur(1))
img=ImageChops.screen(img,fill_layer); d=ImageDraw.Draw(img)
d.line(pts, fill=GREEN, width=2, joint="curve")
# glow on line
gl=Image.new("RGB",(W,H),(0,0,0)); gld=ImageDraw.Draw(gl)
gld.line(pts, fill=GREEN, width=3); gl=gl.filter(ImageFilter.GaussianBlur(4))
img=ImageChops.screen(img,gl); d=ImageDraw.Draw(img)
# grid labels
for i in range(4):
    yy=gy+i*gh/3
    d.line([gx,yy,gx+gw,yy], fill=(24,32,46))
    d.text((gx+gw+6, yy-7), f"{105-i*0.8:.0f}k", font=f_tiny, fill=DIM)

# ---------------- CENTER LOWER: GOLD chart small ----------------
gx2, gy2, gw2, gh2 = 800, 470, 340, 158
panel(gx2, gy2, gw2, gh2, "GOLD  XAU", GOLD)
d.text((gx2+gw2-120, gy2+13), "2,398.6", font=f_h, fill=GREEN)
random.seed(5); p2=[]; v=0.4
for i in range((gw2-48)//5+1):
    v+=random.uniform(-0.08,0.09); v=max(0.1,min(0.9,v))
    p2.append((gx2+24+i*5, gy2+44+(gh2-70)-v*(gh2-70)))
d.line(p2, fill=GOLD, width=2, joint="curve")

# heat / sentiment gauge
hx, hy, hwd, hht = 1160, 470, 340, 158
panel(hx, hy, hwd, hht, "FEAR / GREED INDEX", CYAN)
# arc gauge
cxg, cyg, rg = hx+hwd//2, hy+hht-26, 70
for ang in range(180, 361):
    t=(ang-180)/180
    col=(int(255*(1-t)+46*t), int(80*(1-t)+230*t), int(90*(1-t)+138*t))
    a=math.radians(ang)
    d.line([cxg+math.cos(a)*(rg-8), cyg+math.sin(a)*(rg-8),
            cxg+math.cos(a)*rg, cyg+math.sin(a)*rg], fill=col, width=4)
needle=math.radians(180+0.78*180)
d.line([cxg, cyg, cxg+math.cos(needle)*(rg-12), cyg+math.sin(needle)*(rg-12)], fill=WHITE, width=2)
d.text((cxg-30, hy+50), "78", font=f_big, fill=GREEN)
d.text((cxg-34, hy+96), "EXTREME GREED", font=f_tiny, fill=GREEN)

# ---------------- RIGHT TOP: SCREENER ----------------
sx, sy, swd, sht = 1520, 158, 380, 300
panel(sx, sy, swd, sht, "TOP MOVERS  ·  SCREENER", CYAN)
rows=[("NVDA","1,284.5",+8.42,GREEN),("TSLA","412.80",+5.11,GREEN),
      ("PLTR","78.20",+12.6,GREEN),("COIN","388.4",+9.04,GREEN),
      ("MSTR","2,210",+6.77,GREEN),("AMD","214.9",-3.18,RED),
      ("INTC","41.20",-4.62,RED),("BABA","112.8",+2.05,GREEN),
      ("SOL","248.6",+7.31,GREEN),("AVAX","58.10",-2.44,RED)]
ry=sy+46
d.text((sx+18, ry-4), "SYMBOL", font=f_tiny, fill=DIM)
d.text((sx+150, ry-4), "PRICE", font=f_tiny, fill=DIM)
d.text((sx+290, ry-4), "CHG%", font=f_tiny, fill=DIM)
ry+=18
for i,(s,p,c,col) in enumerate(rows):
    if i%2==0: d.rectangle([sx+8, ry-2, sx+swd-8, ry+20], fill=PANEL_HI)
    d.text((sx+18, ry), s, font=f_monob, fill=WHITE)
    d.text((sx+150, ry), p, font=f_mono, fill=TXT)
    arrow="▲" if c>=0 else "▼"
    d.text((sx+285, ry), f"{arrow}{abs(c):.2f}", font=f_mono, fill=col)
    # mini sparkline
    random.seed(i+2); sp=[]; vv=0.5
    for k in range(18):
        vv+=random.uniform(-0.2,0.22 if col==GREEN else 0.14); vv=max(0.1,min(0.9,vv))
        sp.append((sx+ swd-90 +k*4, ry+16-vv*14))
    d.line(sp, fill=col, width=1)
    ry+=22

# ---------------- RIGHT LOWER: HEDGE FUND FLOW ----------------
fx, fy, fwd, fht = 1520, 470, 380, 158
panel(fx, fy, fwd, fht, "INSTITUTIONAL FLOW  ·  LIVE", GOLD)
funds=[("BLACKSTONE","BTC","+ $2.40B",GREEN),
       ("VANGUARD","GOLD","+ $1.18B",GREEN),
       ("CITADEL","NDX","- $880M",RED),
       ("BRIDGEWATER","BTC","+ $640M",GREEN)]
fyy=fy+46
for nm,asset,amt,col in funds:
    d.ellipse([fx+18,fyy+4,fx+28,fyy+14], fill=col)
    d.text((fx+38, fyy), nm, font=f_mono, fill=TXT)
    d.text((fx+200, fyy), asset, font=f_tiny, fill=DIM)
    d.text((fx+250, fyy), amt, font=f_monob, fill=col)
    fyy+=26

# ---------------- BOTTOM: BIG TXN + NEWS ----------------
bx, by, bwd, bht = 20, 640, 1480, 280
panel(bx, by, bwd, bht, "LIVE TRANSACTION TAPE  ·  SETTLEMENTS > $1B", GREEN)
# headline big number
d.text((bx+24, by+50), "TOTAL CLEARED TODAY", font=f_lbl, fill=DIM)
glayer=Image.new("RGB",(W,H),(0,0,0)); gdl=ImageDraw.Draw(glayer)
gdl.text((bx+24, by+70), "$1.284", font=f_huge, fill=GREEN)
glayer=glayer.filter(ImageFilter.GaussianBlur(8)); img=ImageChops.screen(img,glayer); d=ImageDraw.Draw(img)
d.text((bx+24, by+70), "$1.284", font=f_huge, fill=GREEN)
d.text((bx+220, by+90), "TRILLION", font=f_big, fill=GREEN)
d.text((bx+24, by+138), "▲ 18.4%  vs prior session", font=f_mono, fill=GREEN)

# tape rows
tape=[("21:48:06","BTC","BUY","$3.20B","COINBASE PRIME",GREEN),
      ("21:48:05","XAU","SELL","$1.92B","LBMA LONDON",RED),
      ("21:48:04","ETH","BUY","$1.41B","BINANCE OTC",GREEN),
      ("21:48:03","SPX","BUY","$2.88B","DARK POOL #7",GREEN),
      ("21:48:01","BTC","BUY","$1.10B","KRAKEN OTC",GREEN)]
tx=bx+520; ty2=by+50
d.line([tx-16, by+44, tx-16, by+bht-16], fill=LINE)
hdr=["TIME","ASSET","SIDE","NOTIONAL","VENUE"]
hx2=[tx, tx+110, tx+190, tx+270, tx+400]
for hh,xx in zip(hdr,hx2): d.text((xx,ty2), hh, font=f_tiny, fill=DIM)
ty2+=22
for t,a,side,amt,ven,col in tape:
    d.rectangle([tx-6,ty2-2,bx+bwd-16,ty2+24], fill=PANEL_HI)
    d.text((hx2[0],ty2), t, font=f_mono, fill=DIM)
    d.text((hx2[1],ty2), a, font=f_monob, fill=WHITE)
    d.text((hx2[2],ty2), side, font=f_monob, fill=col)
    d.text((hx2[3],ty2), amt, font=f_monob, fill=col)
    d.text((hx2[4],ty2), ven, font=f_mono, fill=TXT)
    ty2+=30

# ---------------- BOTTOM RIGHT: NEWS WIRE ----------------
nx, ny, nwd, nht = 1520, 640, 380, 280
panel(nx, ny, nwd, nht, "PRIORITY WIRE  ·  0-LATENCY", RED)
news=[("18s","Central bank signals surprise liquidity injection"),
      ("44s","Sovereign fund rotates $40B into bullion"),
      ("1m","Major exchange halts withdrawals amid surge"),
      ("2m","Tech megacap guides revenue above street"),
      ("3m","Stablecoin issuer reports record inflows")]
nyy=ny+48
for tg,headline in news:
    d.rounded_rectangle([nx+16,nyy,nx+58,nyy+18], radius=6, fill=(40,16,20), outline=RED)
    d.text((nx+22,nyy+1), tg, font=f_tiny, fill=RED)
    # wrap headline
    words=headline.split(); line=""; lines=[]
    for w in words:
        if d.textlength(line+" "+w, font=f_lbl) < nwd-80: line=(line+" "+w).strip()
        else: lines.append(line); line=w
    lines.append(line)
    for j,ln in enumerate(lines):
        d.text((nx+66, nyy+j*16), ln, font=f_lbl, fill=TXT)
    nyy+=20+len(lines)*16

# bottom status bar
d.rectangle([0,H-26,W,H], fill=(11,15,23)); d.line([0,H-26,W,H-26], fill=LINE)
d.text((20,H-22), "● STREAMING", font=f_tiny, fill=GREEN)
d.text((150,H-22), "SRC: Yahoo Finance · Global Wires", font=f_tiny, fill=DIM)
d.text((W-360,H-22), "ATLAS TERMINAL  v0.1  ·  PROTOTYPE", font=f_tiny, fill=DIM)

img.save("/home/user/tv_license_app/prototype/atlas_prototype.png", "PNG")
print("saved")
