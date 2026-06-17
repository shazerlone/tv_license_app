#!/usr/bin/env python3
"""
ATLAS v4 - institutional-grade redesign (Bloomberg/Palantir/Aladdin language).
No branding/logo. Restrained palette, hairline grid, tracked micro-caps,
tabular mono numerals, candlesticks, depth-shaded dotted globe.
Visual prop for video.
"""
import math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

W, H = 1920, 1080
LSANS  = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
LSANSB = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
MONO   = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONOB  = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
def ft(p,s): return ImageFont.truetype(p,s)

# refined hierarchy
f_tab    = ft(LSANSB,13)   # nav tabs
f_title  = ft(LSANSB,12)   # panel titles (tracked caps)
f_micro  = ft(LSANS,10)    # micro labels (tracked caps)
f_lbl    = ft(LSANS,12)
f_sym    = ft(LSANSB,13)
f_num    = ft(MONO,13)
f_numb   = ft(MONOB,13)
f_num16  = ft(MONOB,16)
f_num22  = ft(MONOB,22)
f_hero   = ft(MONOB,44)
f_clock  = ft(MONOB,15)

# --- palette: near-black, single warm accent, calm green/red ---
BG     = (9,11,14)
PANEL  = (13,16,20)
HEAD   = (16,19,24)
HAIR   = (28,33,40)        # hairline borders
HAIR2  = (22,26,32)
TXT    = (210,217,226)
MUTE   = (108,118,131)
FAINT  = (70,78,90)
ACC    = (224,168,74)      # warm amber accent (used sparingly)
GREEN  = (64,200,132)
RED    = (228,86,98)
WHITE  = (238,243,249)

img = Image.new("RGB",(W,H),BG); d = ImageDraw.Draw(img)

def caps(x,y,text,fnt,fill,tracking=2.0):
    """draw letter-spaced text; returns end x"""
    cx=x
    for ch in text:
        d.text((cx,y),ch,font=fnt,fill=fill)
        cx += d.textlength(ch,font=fnt)+tracking
    return cx

def caps_w(text,fnt,tracking=2.0):
    return sum(d.textlength(ch,font=fnt)+tracking for ch in text)-tracking

def panel(x,y,w,h,title=None,right=None):
    d.rectangle([x,y,x+w,y+h],fill=PANEL,outline=HAIR,width=1)
    if title:
        d.rectangle([x,y,x+w,y+26],fill=HEAD)
        d.line([x,y+26,x+w,y+26],fill=HAIR,width=1)
        d.rectangle([x,y+7,x+2,y+19],fill=ACC)
        caps(x+12,y+8,title,f_title,TXT,1.6)
        if right:
            rw=caps_w(right,f_micro,1.4); caps(x+w-rw-12,y+9,right,f_micro,MUTE,1.4)
    return x,y

def hline(x,y,w,c=HAIR2): d.line([x,y,x+w,y],fill=c,width=1)

# ================= TOP COMMAND BAR (no branding) =================
d.rectangle([0,0,W,46],fill=HEAD); d.line([0,46,W,46],fill=HAIR,width=1)
tabs=[("OVERVIEW",True),("FLOWS",False),("EXECUTION",False),("RISK",False),("WIRE",False)]
tx=24
for name,active in tabs:
    w=caps_w(name,f_tab,1.5)
    caps(tx,16,name,f_tab,WHITE if active else MUTE,1.5)
    if active: d.rectangle([tx-2,42,tx+w+2,44],fill=ACC)
    tx+=w+34
# command field
cfx=tx+20
d.rectangle([cfx,11,cfx+360,35],fill=PANEL,outline=HAIR,width=1)
d.ellipse([cfx+10,18,cfx+20,28],outline=MUTE,width=1); d.line([cfx+18,26,cfx+23,31],fill=MUTE,width=1)
caps(cfx+34,17,"SEARCH MARKETS · FUNDS · INSTRUMENTS",f_micro,FAINT,1.2)
# right cluster
d.ellipse([W-300,19,W-292,27],fill=GREEN)
caps(W-282,18,"CONNECTED",f_micro,MUTE,1.4)
d.text((W-150,15),"21:48:07",font=f_clock,fill=TXT)
caps(W-150,33,"GMT · 17 JUN 2026",f_micro,FAINT,1.0)

# ================= TICKER RAIL =================
ry=46+1
d.rectangle([0,ry,W,ry+34],fill=BG); d.line([0,ry+34,W,ry+34],fill=HAIR,width=1)
tick=[("BTC","104,820.40",+2.41),("XAU","2,398.60",+0.86),("S&P","5,612.40",-0.32),
      ("NDX","18,944.10",+0.54),("ETH","5,512.00",+3.18),("WTI","78.42",-1.12),
      ("EUR","1.09140",+0.07),("DXY","104.10",-0.21),("UST10Y","4.214",-0.03),
      ("VIX","18.60",-2.40)]
cw=W//len(tick)
for i,(s,v,ch) in enumerate(tick):
    x=20+i*cw; col=GREEN if ch>=0 else RED
    caps(x,ry+6,s,f_micro,MUTE,1.2)
    d.text((x,ry+17),v,font=f_num,fill=TXT)
    d.text((x+96,ry+17),f"{'+' if ch>=0 else ''}{ch:.2f}%",font=f_num,fill=col)
    if i: d.line([x-14,ry+7,x-14,ry+27],fill=HAIR)

TOP=86  # content top
BOT=H-22

# columns
MX=16; G=12
xA,wA = 16, 360
xB,wB = xA+wA+G, 560
xC,wC = xB+wB+G, 440
xD,wD = xC+wC+G, W-(xC+wC+G)-16   # ~ 492

# ============================================================
# COLUMN A — POSITIONS / TARGETS, EXPOSURE, RISK
# ============================================================
# Targets / book
ah1=300; panel(xA,TOP,wA,ah1,"ACTIVE BOOK","7 INSTRUMENTS")
rows=[("XAU/USD","Bullion","LONG",  "+1.18B",GREEN,0.92),
      ("BTC/USD","Crypto", "LONG",  "+2.40B",GREEN,0.78),
      ("S&P 500","Index",  "SHORT", "-0.88B",RED,0.46),
      ("NDX 100","Index",  "LONG",  "+0.64B",GREEN,0.61),
      ("EUR/USD","FX",     "FLAT",  " 0.04B",MUTE,0.33),
      ("ETH/USD","Crypto", "LONG",  "+0.41B",GREEN,0.84),
      ("WTI",    "Energy", "SHORT", "-0.22B",RED,0.27)]
yy=TOP+38
caps(xA+14,yy-12,"INSTRUMENT",f_micro,FAINT,1.0)
caps(xA+150,yy-12,"SIDE",f_micro,FAINT,1.0)
caps(xA+wA-90,yy-12,"P&L USD",f_micro,FAINT,1.0)
for sym,cls,side,pnl,col,conf in rows:
    d.text((xA+14,yy),sym,font=f_sym,fill=TXT)
    caps(xA+14,yy+15,cls.upper(),f_micro,FAINT,1.0)
    sc = GREEN if side=="LONG" else RED if side=="SHORT" else MUTE
    d.text((xA+150,yy+1),side,font=f_numb,fill=sc)
    pw=d.textlength(pnl,font=f_numb); d.text((xA+wA-14-pw,yy+1),pnl,font=f_numb,fill=col)
    # confidence micro bar
    d.rectangle([xA+150,yy+18,xA+150+90,yy+21],fill=HAIR)
    d.rectangle([xA+150,yy+18,xA+150+int(90*conf),yy+21],fill=col)
    yy+=33
    hline(xA+14,yy-6,wA-28)

# Exposure
ah2=300; panel(xA,TOP+ah1+G,wA,ah2,"EXPOSURE BY ASSET CLASS","NET $4.82B")
ey=TOP+ah1+G+40
exp=[("Crypto",0.34,GREEN),("Equities",0.27,RED),("Bullion",0.21,GREEN),
     ("Rates",0.10,MUTE),("FX",0.05,MUTE),("Energy",0.03,RED)]
for name,frac,col in exp:
    caps(xA+14,ey,name.upper(),f_micro,MUTE,1.2)
    pct=f"{int(frac*100)}%"; pw=d.textlength(pct,font=f_num)
    d.text((xA+wA-14-pw,ey-2),pct,font=f_num,fill=TXT)
    d.rectangle([xA+14,ey+15,xA+wA-14,ey+23],fill=HAIR)
    d.rectangle([xA+14,ey+15,xA+14+int((wA-28)*frac),ey+23],fill=col)
    ey+=40

# Risk gauges
ah3=BOT-(TOP+ah1+ah2+2*G); panel(xA,TOP+ah1+ah2+2*G,wA,ah3,"RISK MONITOR","REAL-TIME")
gy=TOP+ah1+ah2+2*G+44
metrics=[("VALUE AT RISK","$212.4M",GREEN),("GROSS LEVERAGE","3.8x",ACC),
         ("LIQUIDITY","HIGH",GREEN),("DRAWDOWN","-1.2%",RED)]
for i,(lb,vl,col) in enumerate(metrics):
    cx=xA+14+(i%2)*(wA//2-6); cyv=gy+(i//2)*60
    caps(cx,cyv,lb,f_micro,MUTE,1.0)
    d.text((cx,cyv+14),vl,font=f_num22,fill=col)

# ============================================================
# COLUMN B — PRICE CHART (candles) + GLOBE
# ============================================================
bh1=440; panel(xB,TOP,wB,bh1,"BTC / USD · SPOT","1H · YAHOO FINANCE")
# header readout
d.text((xB+14,TOP+34),"104,820.40",font=f_num22,fill=GREEN)
d.text((xB+170,TOP+40),"+2,468.10  (+2.41%)",font=f_numb,fill=GREEN)
caps(xB+wB-220,TOP+34,"O 102,410   H 105,180",f_micro,MUTE,1.0)
caps(xB+wB-220,TOP+46,"L 101,980   V 38.4K BTC",f_micro,MUTE,1.0)
# chart area
gxl,gyt = xB+14, TOP+78
gxr,gyb = xB+wB-58, TOP+bh1-30
gw,gh = gxr-gxl, gyb-gyt
# grid
for i in range(5):
    yv=gyt+i*gh/4; d.line([gxl,yv,gxr,yv],fill=HAIR2)
    price=105.2-i*0.9
    d.text((gxr+8,yv-7),f"{price:,.1f}k",font=f_num,fill=FAINT)
# candles
random.seed(21); n=58; price=0.5; cwid=gw/n
ohlc=[]
for i in range(n):
    o=price; price+= random.uniform(-0.05,0.055)+0.004
    c=price; hi=max(o,c)+random.uniform(0,0.03); lo=min(o,c)-random.uniform(0,0.03)
    ohlc.append((o,hi,lo,c))
lo_all=min(x[2] for x in ohlc); hi_all=max(x[1] for x in ohlc); rng=hi_all-lo_all
def py(v): return gyb-(v-lo_all)/rng*gh
for i,(o,hi,lo,c) in enumerate(ohlc):
    cx=gxl+i*cwid+cwid/2; up=c>=o; col=GREEN if up else RED
    d.line([cx,py(hi),cx,py(lo)],fill=col,width=1)
    bw=max(2,cwid*0.6)
    d.rectangle([cx-bw/2,py(max(o,c)),cx+bw/2,py(min(o,c))],fill=col)
# last price marker
d.line([gxl,py(ohlc[-1][3]),gxr,py(ohlc[-1][3])],fill=(60,70,82))
d.rectangle([gxr,py(ohlc[-1][3])-8,gxr+52,py(ohlc[-1][3])+8],fill=GREEN)
d.text((gxr+4,py(ohlc[-1][3])-7),"104.8k",font=f_num,fill=(8,12,10))

# ---- GLOBE (depth-shaded dot sphere) ----
bh2=BOT-(TOP+bh1+G); panel(xB,TOP+bh1+G,wB,bh2,"GLOBAL LIQUIDITY · CROSS-BORDER FLOW","$4.82T / 24H")
gcx=xB+wB//2; gcy=TOP+bh1+G+bh2//2+16; R=min(bh2//2-40, 168)
rot=0.5
def sph(lat,lon):
    la=math.radians(lat); lo=math.radians(lon)+rot
    x=math.cos(la)*math.sin(lo); y=math.sin(la); z=math.cos(la)*math.cos(lo)
    return gcx+x*R, gcy-y*R, z
# dotted sphere, brightness by depth
for lat in range(-82,83,4):
    step = max(4, int(4/max(0.12,math.cos(math.radians(lat)))))
    for lon in range(0,360,step):
        X,Y,Z=sph(lat,lon)
        if Z>0:
            b=0.25+0.55*Z
            col=(int(48+150*b*0.6),int(52+150*b*0.6),int(60+150*b*0.62))
            r=1 if Z<0.6 else 1.4
            d.ellipse([X-r,Y-r,X+r,Y+r],fill=col)
# rim
d.ellipse([gcx-R,gcy-R,gcx+R,gcy+R],outline=(46,54,66),width=1)
# arcs (thin amber/green, with end nodes)
hubs={"NY":(40,-74),"LDN":(51,0),"TKO":(35,139),"HK":(22,114),"DXB":(25,55),"SGP":(1,103)}
pos={n:sph(la,lo) for n,(la,lo) in hubs.items()}
flows=[("LDN","NY",ACC),("TKO","LDN",GREEN),("HK","NY",GREEN),("DXB","LDN",ACC)]
for a,b,col in flows:
    (x1,y1,z1),(x2,y2,z2)=pos[a],pos[b]
    if z1<=0 and z2<=0: continue
    mxp=(x1+x2)/2; myp=(y1+y2)/2-70; prev=(x1,y1)
    for t in [i/40 for i in range(41)]:
        bx=(1-t)**2*x1+2*(1-t)*t*mxp+t*t*x2; by=(1-t)**2*y1+2*(1-t)*t*myp+t*t*y2
        d.line([prev,(bx,by)],fill=col,width=1); prev=(bx,by)
    # moving packet marker
    tt=0.62; bx=(1-tt)**2*x1+2*(1-tt)*tt*mxp+tt*tt*x2; by=(1-tt)**2*y1+2*(1-tt)*tt*myp+tt*tt*y2
    d.ellipse([bx-2,by-2,bx+2,by+2],fill=WHITE)
for n,(X,Y,Z) in pos.items():
    if Z>0:
        d.ellipse([X-2.5,Y-2.5,X+2.5,Y+2.5],fill=ACC)
        caps(X+7,Y-5,n,f_micro,MUTE,0.5)
# corner stats
for i,(lb,vl,col) in enumerate([("INFLOW","+$182.6B",GREEN),("OUTFLOW","-$98.2B",RED),("NET","+$84.4B",GREEN)]):
    cx=xB+14+i*150; cyv=TOP+bh1+G+bh2-40
    caps(cx,cyv,lb,f_micro,FAINT,1.0); d.text((cx,cyv+13),vl,font=f_numb,fill=col)

# ============================================================
# COLUMN C — ORDER BOOK + DEPTH + TAPE
# ============================================================
ch1=300; panel(xC,TOP,wC,ch1,"BTC ORDER BOOK","CONSOLIDATED")
caps(xC+14,TOP+34,"PRICE",f_micro,FAINT,1.0)
caps(xC+150,TOP+34,"SIZE",f_micro,FAINT,1.0)
caps(xC+wC-90,TOP+34,"TOTAL",f_micro,FAINT,1.0)
random.seed(3); yy=TOP+50; base=104900; tot=0
asks=[(base+i*10, random.uniform(2,30)) for i in range(7)][::-1]
bids=[(base-10-i*10, random.uniform(2,30)) for i in range(7)]
for pr,sz in asks:
    w=int(sz/30*(wC-40)); d.rectangle([xC+wC-14-w,yy-1,xC+wC-14,yy+15],fill=(40,20,24))
    d.text((xC+14,yy),f"{pr:,.0f}",font=f_num,fill=RED)
    d.text((xC+150,yy),f"{sz:5.2f}",font=f_num,fill=TXT)
    tot+=sz; d.text((xC+wC-90,yy),f"{tot:5.1f}",font=f_num,fill=MUTE); yy+=15
d.rectangle([xC+8,yy+2,xC+wC-8,yy+22],fill=HEAD)
d.text((xC+14,yy+5),"104,820",font=f_numb,fill=GREEN)
caps(xC+150,yy+8,"SPREAD 5.0 · MID 104,817",f_micro,MUTE,1.0); yy+=28
tot=0
for pr,sz in bids:
    w=int(sz/30*(wC-40)); d.rectangle([xC+wC-14-w,yy-1,xC+wC-14,yy+15],fill=(18,42,30))
    d.text((xC+14,yy),f"{pr:,.0f}",font=f_num,fill=GREEN)
    d.text((xC+150,yy),f"{sz:5.2f}",font=f_num,fill=TXT)
    tot+=sz; d.text((xC+wC-90,yy),f"{tot:5.1f}",font=f_num,fill=MUTE); yy+=15

# depth chart
ch2=170; panel(xC,TOP+ch1+G,wC,ch2,"MARKET DEPTH")
dyt=TOP+ch1+G+34; dyb=TOP+ch1+G+ch2-16; dh=dyb-dyt; mid=xC+wC//2
random.seed(9)
# bids cumulative (left), asks (right)
pts_b=[(mid,dyb)]; cum=0
for i in range(20):
    cum+=random.uniform(1,4); x=mid-(i+1)*(wC//2-14)/20; pts_b.append((x,dyb-min(dh,cum/70*dh)))
pts_a=[(mid,dyb)]; cum=0
for i in range(20):
    cum+=random.uniform(1,4); x=mid+(i+1)*(wC//2-14)/20; pts_a.append((x,dyb-min(dh,cum/70*dh)))
d.polygon(pts_b+[(pts_b[-1][0],dyb)],fill=(16,40,30)); d.line(pts_b,fill=GREEN,width=1)
d.polygon(pts_a+[(pts_a[-1][0],dyb)],fill=(40,20,24)); d.line(pts_a,fill=RED,width=1)
d.line([mid,dyt,mid,dyb],fill=HAIR)

# tape
ch3=BOT-(TOP+ch1+ch2+2*G); panel(xC,TOP+ch1+ch2+2*G,wC,ch3,"TIME & SALES · BLOCK > $1B","LIVE")
ty0=TOP+ch1+ch2+2*G+34
caps(xC+14,ty0,"TIME",f_micro,FAINT,1.0); caps(xC+86,ty0,"SYM",f_micro,FAINT,1.0)
caps(xC+150,ty0,"NOTIONAL",f_micro,FAINT,1.0); caps(xC+wC-90,ty0,"VENUE",f_micro,FAINT,1.0)
tape=[("21:48:06","BTC","BUY","3.20B","CB PRIME"),("21:48:05","XAU","SELL","1.92B","LBMA"),
      ("21:48:04","ETH","BUY","1.41B","BINANCE"),("21:48:03","SPX","BUY","2.88B","XCBT"),
      ("21:48:01","BTC","BUY","1.10B","KRAKEN"),("21:47:58","XAU","BUY","2.05B","COMEX"),
      ("21:47:55","NDX","SELL","1.33B","XCME"),("21:47:51","ETH","BUY","1.02B","OKX")]
yy=ty0+18
for t,a,side,amt,ven in tape:
    col=GREEN if side=="BUY" else RED
    d.text((xC+14,yy),t,font=f_num,fill=MUTE); d.text((xC+86,yy),a,font=f_numb,fill=TXT)
    d.text((xC+150,yy),f"{side} ${amt}",font=f_numb,fill=col)
    vw=d.textlength(ven,font=f_num); d.text((xC+wC-14-vw,yy),ven,font=f_num,fill=MUTE)
    yy+=19; hline(xC+14,yy-4,wC-28)

# ============================================================
# COLUMN D — SCREENER + WIRE
# ============================================================
dh1=560; panel(xD,TOP,wD,dh1,"MARKET SCREENER · TOP MOVERS","SORT ▾ %CHG")
caps(xD+14,TOP+34,"SYMBOL",f_micro,FAINT,1.0); caps(xD+150,TOP+34,"LAST",f_micro,FAINT,1.0)
caps(xD+250,TOP+34,"CHG%",f_micro,FAINT,1.0); caps(xD+wD-110,TOP+34,"INTRADAY",f_micro,FAINT,1.0)
scr=[("NVDA","1,284.50",+8.42),("PLTR","78.20",+12.61),("MSTR","2,210.00",+6.77),
     ("COIN","388.40",+9.04),("TSLA","412.80",+5.11),("SMCI","902.00",+4.40),
     ("ARM","148.20",+6.10),("AMD","214.90",-3.18),("INTC","41.20",-4.62),
     ("BABA","112.80",+2.05),("RIOT","18.40",+11.20),("MARA","26.10",+9.80),
     ("AVAX","58.10",-2.44),("SOL","248.60",+7.31),("MU","132.40",+3.92),
     ("HOOD","42.80",+5.55)]
yy=TOP+52
for i,(s,p,c) in enumerate(scr):
    col=GREEN if c>=0 else RED
    if i%2==0: d.rectangle([xD+1,yy-3,xD+wD-1,yy+22],fill=(16,19,24))
    d.text((xD+14,yy),s,font=f_sym,fill=TXT)
    pw=d.textlength(p,font=f_num); d.text((xD+240-pw,yy+1),p,font=f_num,fill=TXT)
    d.text((xD+250,yy+1),f"{'+' if c>=0 else ''}{c:.2f}",font=f_numb,fill=col)
    random.seed(i+11); sp=[]; vv=0.5
    for k in range(22):
        vv+=random.uniform(-0.18,0.2 if c>=0 else 0.14); vv=max(0.1,min(0.9,vv))
        sp.append((xD+wD-110+k*4.2,yy+18-vv*15))
    d.line(sp,fill=col,width=1)
    yy+=31

# wire
dh2=BOT-(TOP+dh1+G); panel(xD,TOP+dh1+G,wD,dh2,"NEWS WIRE · PRIORITY","FILTERED")
wire=[("21:48","MACRO","Central bank signals surprise liquidity facility; futures bid"),
      ("21:46","FLOW","Sovereign wealth fund rotates est. $40B into bullion"),
      ("21:43","CRYPTO","Major exchange pauses withdrawals amid record volume"),
      ("21:39","EQUITY","Mega-cap guides Q3 revenue materially above consensus"),
      ("21:35","RATES","Curve steepens as desk flags duration unwind")]
yy=TOP+dh1+G+38
for tm,tagn,hl in wire:
    d.text((xD+14,yy),tm,font=f_num,fill=MUTE)
    tw=caps_w(tagn,f_micro,1.0)
    d.rectangle([xD+58,yy-1,xD+58+tw+12,yy+14],outline=ACC,width=1)
    caps(xD+64,yy+1,tagn,f_micro,ACC,1.0)
    # wrap headline
    words=hl.split(); line=""; lines=[]
    for w in words:
        if d.textlength(line+" "+w,font=f_lbl)<wD-30: line=(line+" "+w).strip()
        else: lines.append(line); line=w
    lines.append(line)
    for j,ln in enumerate(lines): d.text((xD+14,yy+18+j*16),ln,font=f_lbl,fill=TXT)
    yy+=22+len(lines)*16+8
    hline(xD+14,yy-8,wD-28)

# ================= STATUS BAR =================
d.rectangle([0,H-22,W,H],fill=HEAD); d.line([0,H-22,W,H-22],fill=HAIR,width=1)
d.ellipse([16,H-16,24,H-8],fill=GREEN); caps(30,H-17,"MARKET DATA STREAMING",f_micro,MUTE,1.2)
caps(240,H-17,"SOURCE · YAHOO FINANCE / CONSOLIDATED WIRES",f_micro,FAINT,1.2)
caps(W-180,H-17,"LATENCY 2MS · 1,284 NODES",f_micro,FAINT,1.2)

img.save("/home/user/tv_license_app/prototype/atlas_v4.png","PNG"); print("saved")
