#!/usr/bin/env python3
"""ATLAS TERMINAL v3 - gold/black luxury 'command' build with control panels.
Visual prop for video: looks like a control console; performs no real action."""
import math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

W,H=1920,1080
FP="/usr/share/fonts/truetype/dejavu/"
def font(n,s): return ImageFont.truetype(FP+n,s)
f_brand=font("DejaVuSans-Bold.ttf",30); f_sub=font("DejaVuSans.ttf",14)
f_h=font("DejaVuSans-Bold.ttf",16); f_lbl=font("DejaVuSans.ttf",12)
f_mono=font("DejaVuSansMono.ttf",14); f_monob=font("DejaVuSansMono-Bold.ttf",14)
f_big=font("DejaVuSansMono-Bold.ttf",36); f_huge=font("DejaVuSansMono-Bold.ttf",50)
f_tiny=font("DejaVuSansMono.ttf",11); f_clock=font("DejaVuSansMono-Bold.ttf",22)

BG=(10,9,7); PANEL=(20,17,12); PANEL_HI=(30,25,16); LINE=(62,52,30)
GOLD=(240,196,74); AMBER=(255,150,40); RED=(255,78,96); GREEN=(70,220,130)
TXT=(232,222,200); DIM=(150,134,100); WHITE=(255,248,232); GLOWBG=(46,34,10)

img=Image.new("RGB",(W,H),BG); d=ImageDraw.Draw(img)
g=Image.new("RGB",(W,H),BG); gd=ImageDraw.Draw(g)
gd.ellipse([W//2-1000,-800,W//2+1000,600],fill=GLOWBG)
g=g.filter(ImageFilter.GaussianBlur(200)); img=Image.blend(img,g,0.5); d=ImageDraw.Draw(img)

def panel(x,y,w,h,title=None,accent=GOLD):
    d.rounded_rectangle([x,y,x+w,y+h],radius=9,fill=PANEL,outline=LINE,width=1)
    if title:
        d.line([x+13,y+32,x+w-13,y+32],fill=LINE)
        d.rectangle([x+13,y+15,x+17,y+28],fill=accent)
        d.text((x+26,y+14),title,font=f_h,fill=WHITE)

def glow(fn,blur=6):
    global img,d
    L=Image.new("RGB",(W,H),(0,0,0)); ld=ImageDraw.Draw(L)
    fn(ld); L=L.filter(ImageFilter.GaussianBlur(blur)); img=ImageChops.screen(img,L); d=ImageDraw.Draw(img)

# HEADER
d.rectangle([0,0,W,72],fill=(16,13,9)); d.line([0,72,W,72],fill=LINE)
d.rounded_rectangle([26,16,68,58],radius=8,outline=GOLD,width=2)
d.line([32,48,42,32,47,42,56,24,62,38],fill=GOLD,width=2,joint="curve")
d.text((84,12),"ATLAS  TERMINAL",font=f_brand,fill=WHITE)
d.text((86,46),"GLOBAL  LIQUIDITY  COMMAND  ·  WAR  ROOM",font=f_sub,fill=GOLD)
px=720
for lbl,vl,c in [("ENGINE","LIVE",GREEN),("LAT","2ms",GOLD),("NODES","1,284",GOLD),("THREAT","HIGH",RED),("FEED","YAHOO",AMBER)]:
    d.rounded_rectangle([px,20,px+138,50],radius=14,fill=PANEL_HI,outline=LINE)
    d.ellipse([px+12,29,px+24,41],fill=c); d.text((px+32,24),lbl,font=f_tiny,fill=DIM)
    d.text((px+32,35),vl,font=f_monob,fill=TXT); px+=148
d.text((W-220,18),"GMT 17 JUN 2026",font=f_lbl,fill=DIM)
d.text((W-220,38),"21:48:07",font=f_clock,fill=GOLD)

# TICKER
ty=80; d.rounded_rectangle([16,ty,W-16,ty+50],radius=7,fill=PANEL,outline=LINE)
tick=[("BTC","104,820",+2.41,GREEN),("XAU","2,398.6",+0.86,GREEN),("SPX","5,612",-0.32,RED),("NDX","18,944",+0.54,GREEN),("ETH","5,512",+3.18,GREEN),("WTI","78.42",-1.12,RED),("EUR","1.0914",+0.07,GREEN),("DXY","104.1",-0.21,RED),("VIX","18.6",-2.40,RED),("SOL","248.6",+7.31,GREEN)]
cw=(W-32)//len(tick)
for i,(s,v,ch,c) in enumerate(tick):
    x=24+i*cw; d.text((x,ty+7),s,font=f_lbl,fill=DIM); d.text((x,ty+23),v,font=f_monob,fill=WHITE)
    d.text((x+82,ty+23),f"{'▲' if ch>=0 else '▼'}{abs(ch):.2f}",font=f_tiny,fill=c)
    if i: d.line([x-10,ty+10,x-10,ty+40],fill=LINE)

# ---- LEFT COL: ALERTS + TARGET LIST ----
panel(16,142,350,150,"PRIORITY ALERTS",RED)
for i,(tg,msg,c) in enumerate([("CRIT","Whale moved 12,400 BTC",RED),("HIGH","Gold breaks 2,400",GOLD),("HIGH","Liquidity vacuum · NDX",RED),("INFO","Sovereign accumulating",GOLD)]):
    yy=186+i*26; d.rounded_rectangle([30,yy,76,yy+18],radius=5,fill=PANEL_HI,outline=c)
    d.text((35,yy+2),tg,font=f_tiny,fill=c); d.text((86,yy+1),msg,font=f_lbl,fill=TXT)

panel(16,300,350,306,"TARGET LIST  ·  ENGAGEMENT",AMBER)
targets=[("XAU/USD","GOLD",0.92,"LOCKED",GREEN),("BTC/USD","CRYPTO",0.78,"ENGAGED",GREEN),("SPX","INDEX",0.46,"TRACKING",GOLD),("NDX","INDEX",0.61,"ENGAGED",GREEN),("EUR/USD","FX",0.33,"TRACKING",GOLD),("ETH/USD","CRYPTO",0.84,"LOCKED",GREEN),("WTI","ENERGY",0.27,"STANDBY",DIM)]
yy=346
for sym,cls,val,st,c in targets:
    d.text((30,yy),sym,font=f_monob,fill=WHITE); d.text((140,yy+1),cls,font=f_tiny,fill=DIM)
    d.rounded_rectangle([30,yy+18,300,yy+26],radius=3,fill=PANEL_HI)
    d.rounded_rectangle([30,yy+18,30+int(270*val),yy+26],radius=3,fill=c)
    d.text((300,yy),st,font=f_tiny,fill=c); d.text((250,yy),f"{int(val*100)}%",font=f_tiny,fill=DIM)
    yy+=36

# ---- RADAR SWEEP ----
panel(374,142,300,300,"TACTICAL RADAR  ·  SECTOR SWEEP",GOLD)
rcx,rcy,rr=374+150,142+165,118
for ring in range(1,5):
    d.ellipse([rcx-rr*ring/4,rcy-rr*ring/4,rcx+rr*ring/4,rcy+rr*ring/4],outline=tuple(int(c*0.4) for c in GOLD),width=1)
d.line([rcx-rr,rcy,rcx+rr,rcy],fill=tuple(int(c*0.4) for c in GOLD)); d.line([rcx,rcy-rr,rcx,rcy+rr],fill=tuple(int(c*0.4) for c in GOLD))
# sweep wedge
sweep=Image.new("RGB",(W,H),(0,0,0)); sd=ImageDraw.Draw(sweep)
for k in range(60):
    a=-50-k*0.9; col=tuple(int(c*(1-k/60)) for c in GREEN)
    sd.pieslice([rcx-rr,rcy-rr,rcx+rr,rcy+rr],a-1,a+1,fill=col)
sweep=sweep.filter(ImageFilter.GaussianBlur(2)); img=ImageChops.screen(img,sweep); d=ImageDraw.Draw(img)
d.line([rcx,rcy,rcx+rr*math.cos(math.radians(-50)),rcy+rr*math.sin(math.radians(-50))],fill=GREEN,width=2)
random.seed(4)
for _ in range(7):
    a=random.uniform(0,2*math.pi); rad=random.uniform(20,rr-10)
    bx=rcx+math.cos(a)*rad; by=rcy+math.sin(a)*rad
    c=random.choice([GREEN,GOLD,RED]); d.ellipse([bx-3,by-3,bx+3,by+3],fill=c)
    glow(lambda ld,bx=bx,by=by,c=c: ld.ellipse([bx-4,by-4,bx+4,by+4],fill=c),blur=4)
d.text((384,418),"7 ACTIVE CONTACTS",font=f_tiny,fill=GREEN)

# signal meters
panel(374,450,300,156,"MOMENTUM",GREEN)
for i,(name,val,c) in enumerate([("BTC",0.92,GREEN),("XAU",0.74,GOLD),("SPX",0.38,RED),("NDX",0.55,GOLD),("ETH",0.81,GREEN)]):
    yy=494+i*22; d.text((388,yy),name,font=f_monob,fill=TXT)
    bw=160
    for k in range(int(bw/10)):
        on=k/(bw/10)<val; col=c if on else tuple(int(cc*0.22) for cc in c)
        d.rectangle([440+k*10,yy+2,440+k*10+7,yy+12],fill=col)
    d.text((614,yy),f"{int(val*100)}",font=f_mono,fill=c)

# ---- GLOBE ----
gx,gy,gw,gh=682,142,420,464; panel(gx,gy,gw,gh,"GLOBAL FLOW SPHERE  ·  REAL-TIME",GOLD)
cx0,cy0=gx+gw//2,gy+gh//2+8; R=160; rot=0.6
def sph(lat,lon):
    lat=math.radians(lat); lon=math.radians(lon)+rot
    x=math.cos(lat)*math.sin(lon); y=math.sin(lat); z=math.cos(lat)*math.cos(lon)
    return cx0+x*R,cy0-y*R,z
for lat in range(-60,61,30):
    pts=[(X,Y) for lon in range(0,361,6) for (X,Y,Z) in [sph(lat,lon)] if Z>-0.05]
    if len(pts)>1: d.line(pts,fill=tuple(int(c*0.5) for c in GOLD),width=1)
for lon in range(0,360,30):
    pts=[(X,Y) for lat in range(-90,91,6) for (X,Y,Z) in [sph(lat,lon)] if Z>-0.05]
    if len(pts)>1: d.line(pts,fill=tuple(int(c*0.32) for c in GOLD),width=1)
glow(lambda ld: ld.ellipse([cx0-R,cy0-R,cx0+R,cy0+R],outline=GOLD,width=3),blur=8)
d.ellipse([cx0-R,cy0-R,cx0+R,cy0+R],outline=tuple(int(c*0.7) for c in GOLD),width=1)
hubs={"NY":(40,-74),"LDN":(51,0),"TKO":(35,139),"HK":(22,114),"DXB":(25,55),"SGP":(1,103),"SAO":(-23,-46)}
pos={n:sph(la,lo) for n,(la,lo) in hubs.items()}
flows=[("LDN","NY",GREEN),("TKO","LDN",GOLD),("HK","NY",GREEN),("DXB","LDN",AMBER),("SGP","NY",GOLD)]
def arc(ld,a,b,col,wd):
    (x1,y1,_),(x2,y2,_)=pos[a],pos[b]; mxp=(x1+x2)/2; myp=(y1+y2)/2-80; prev=(x1,y1)
    for t in [i/30 for i in range(31)]:
        bx=(1-t)**2*x1+2*(1-t)*t*mxp+t*t*x2; by=(1-t)**2*y1+2*(1-t)*t*myp+t*t*y2
        ld.line([prev,(bx,by)],fill=col,width=wd); prev=(bx,by)
for a,b,c in flows: glow(lambda ld,a=a,b=b,c=c: arc(ld,a,b,c,2),blur=3)
for a,b,c in flows: arc(d,a,b,c,1)
for n,(X,Y,Z) in pos.items():
    if Z>-0.05:
        d.ellipse([X-5,Y-5,X+5,Y+5],fill=GOLD); d.ellipse([X-10,Y-10,X+10,Y+10],outline=GOLD,width=1)
        d.text((X+10,Y-4),n,font=f_tiny,fill=TXT)
for i,(lb,vl,c) in enumerate([("VOL 24H","$4.82T",GREEN),("FLOWS","1,284",GOLD),("NET","+$182.6B",GREEN)]):
    d.text((gx+24+i*135,gy+gh-34),lb,font=f_tiny,fill=DIM); d.text((gx+24+i*135,gy+gh-20),vl,font=f_monob,fill=c)

# ---- ORDER BOOK + HEATMAP ----
ox,oy,ow,oh=1110,142,360,300; panel(ox,oy,ow,oh,"BTC ORDER BOOK  ·  DEPTH",GOLD)
d.text((ox+18,oy+42),"PRICE",font=f_tiny,fill=DIM); d.text((ox+150,oy+42),"SIZE",font=f_tiny,fill=DIM)
random.seed(1); yy=oy+62; base=104900
asks=[(base+i*15,random.uniform(2,40)) for i in range(6)][::-1]
bids=[(base-15-i*15,random.uniform(2,40)) for i in range(6)]
for pr,sz in asks:
    w=int(sz/40*(ow-60)); d.rectangle([ox+ow-30-w,yy,ox+ow-30,yy+16],fill=(50,20,26))
    d.text((ox+18,yy),f"{pr:,.0f}",font=f_mono,fill=RED); d.text((ox+150,yy),f"{sz:.1f}",font=f_mono,fill=TXT); yy+=18
d.rectangle([ox+14,yy+2,ox+ow-14,yy+24],fill=PANEL_HI); d.text((ox+18,yy+5),"104,820",font=f_monob,fill=GREEN)
d.text((ox+150,yy+5),"SPREAD 5.0",font=f_mono,fill=DIM); yy+=30
for pr,sz in bids:
    w=int(sz/40*(ow-60)); d.rectangle([ox+ow-30-w,yy,ox+ow-30,yy+16],fill=(16,46,32))
    d.text((ox+18,yy),f"{pr:,.0f}",font=f_mono,fill=GREEN); d.text((ox+150,yy),f"{sz:.1f}",font=f_mono,fill=TXT); yy+=18

hx,hy,hw,hh=1110,454,360,152; panel(hx,hy,hw,hh,"OPTIONS FLOW HEATMAP",AMBER)
cols=11;rows=4;cwt=(hw-40)//cols;cht=(hh-58)//rows; random.seed(8)
for r in range(rows):
    for c in range(cols):
        v=random.random()
        if v>0.55: col=(int(20+v*40),int(120+v*110),int(70+v*60))
        elif v<0.3: col=(int(120+(0.3-v)*300),30,40)
        else: col=PANEL_HI
        d.rectangle([hx+20+c*cwt,hy+44+r*cht,hx+20+c*cwt+cwt-2,hy+44+r*cht+cht-2],fill=col)

# ---- SCREENER ----
scx,scy,scw,sch=1478,142,426,464; panel(scx,scy,scw,sch,"TOP MOVERS  ·  SCREENER",GOLD)
rows2=[("NVDA","1,284.5",+8.42,GREEN),("TSLA","412.80",+5.11,GREEN),("PLTR","78.20",+12.6,GREEN),("COIN","388.4",+9.04,GREEN),("MSTR","2,210",+6.77,GREEN),("AMD","214.9",-3.18,RED),("INTC","41.20",-4.62,RED),("BABA","112.8",+2.05,GREEN),("SOL","248.6",+7.31,GREEN),("AVAX","58.10",-2.44,RED),("ARM","148.2",+6.10,GREEN),("SMCI","902.0",+4.40,GREEN),("RIOT","18.40",+11.2,GREEN),("MARA","26.10",+9.80,GREEN)]
yy=scy+46; d.text((scx+16,yy-2),"SYM",font=f_tiny,fill=DIM); d.text((scx+120,yy-2),"PRICE",font=f_tiny,fill=DIM); d.text((scx+250,yy-2),"CHG%",font=f_tiny,fill=DIM); d.text((scx+340,yy-2),"TREND",font=f_tiny,fill=DIM); yy+=16
for i,(s,p,c,col) in enumerate(rows2):
    if i%2==0: d.rectangle([scx+8,yy-2,scx+scw-8,yy+20],fill=PANEL_HI)
    d.text((scx+16,yy),s,font=f_monob,fill=WHITE); d.text((scx+120,yy),p,font=f_mono,fill=TXT)
    d.text((scx+245,yy),f"{'▲' if c>=0 else '▼'}{abs(c):.1f}",font=f_mono,fill=col)
    random.seed(i+5); sp=[];vv=0.5
    for k in range(16):
        vv+=random.uniform(-0.2,0.22 if col==GREEN else 0.14); vv=max(0.1,min(0.9,vv)); sp.append((scx+340+k*4,yy+15-vv*13))
    d.line(sp,fill=col,width=1); yy+=22

# ============ BOTTOM BAND ============
# OVERRIDE CONSOLE
bx,by,bw,bh=16,614,600,306; panel(bx,by,bw,bh,"MARKET OVERRIDE CONSOLE",RED)
modes=[("XAU/USD","FORCE BID",GREEN,"ARMED"),("BTC/USD","ACCUMULATE",GREEN,"ACTIVE"),("S&P 500","SUPPRESS",RED,"STANDBY"),("EUR/USD","STABILIZE",GOLD,"ARMED")]
yy=by+50
for sym,mode,c,st in modes:
    d.text((bx+22,yy),sym,font=f_monob,fill=TXT)
    d.rounded_rectangle([bx+150,yy-2,bx+290,yy+18],radius=9,fill=PANEL_HI,outline=c)
    d.text((bx+160,yy),mode,font=f_tiny,fill=c)
    d.ellipse([bx+320,yy+1,bx+332,yy+13],fill=c)
    d.text((bx+342,yy),st,font=f_mono,fill=c); yy+=34
# sliders
for lbl,val,c in [("GLOBAL LIQUIDITY",0.72,GREEN),("LEVERAGE  x18",0.85,GOLD)]:
    d.text((bx+22,yy),lbl,font=f_lbl,fill=DIM)
    d.rounded_rectangle([bx+22,yy+18,bx+420,yy+26],radius=4,fill=PANEL_HI)
    d.rounded_rectangle([bx+22,yy+18,bx+22+int(398*val),yy+26],radius=4,fill=c)
    d.ellipse([bx+22+int(398*val)-7,yy+15,bx+22+int(398*val)+7,yy+29],fill=WHITE); yy+=42
# execute button
glow(lambda ld: ld.rounded_rectangle([bx+bw-180,by+bh-58,bx+bw-22,by+bh-20],radius=10,fill=(60,18,22),outline=RED,width=2),blur=6)
d.rounded_rectangle([bx+bw-180,by+bh-58,bx+bw-22,by+bh-20],radius=10,fill=(60,18,22),outline=RED,width=2)
d.text((bx+bw-150,by+bh-50),"▶ EXECUTE",font=f_monob,fill=RED)

# TRANSACTION TAPE
tx,tyb,tw,th=632,614,620,306; panel(tx,tyb,tw,th,"LIVE TRANSACTION TAPE  ·  > $1B",GREEN)
d.text((tx+24,tyb+46),"TOTAL CLEARED TODAY",font=f_lbl,fill=DIM)
glow(lambda ld: ld.text((tx+24,tyb+62),"$1.284",font=f_huge,fill=GREEN),blur=8)
d.text((tx+24,tyb+62),"$1.284",font=f_huge,fill=GREEN); d.text((tx+26,tyb+118),"TRILLION",font=f_big,fill=GREEN)
d.text((tx+26,tyb+160),"▲ 18.4% vs prior",font=f_mono,fill=GREEN)
tape=[("21:48:06","BTC","BUY","$3.20B","CB PRIME",GREEN),("21:48:05","XAU","SELL","$1.92B","LBMA",RED),("21:48:04","ETH","BUY","$1.41B","BINANCE",GREEN),("21:48:03","SPX","BUY","$2.88B","DARK #7",GREEN),("21:48:01","BTC","BUY","$1.10B","KRAKEN",GREEN),("21:47:58","XAU","BUY","$2.05B","COMEX",GREEN)]
tcx=tx+250; yy=tyb+48; d.line([tcx-14,tyb+42,tcx-14,tyb+th-14],fill=LINE)
hxs=[tcx,tcx+78,tcx+148,tcx+218,tcx+300]
for hh2,xx in zip(["TIME","AST","SIDE","NOT.","VENUE"],hxs): d.text((xx,yy),hh2,font=f_tiny,fill=DIM)
yy+=22
for t,a,side,amt,ven,col in tape:
    d.rectangle([tcx-6,yy-2,tx+tw-14,yy+24],fill=PANEL_HI)
    d.text((hxs[0],yy),t,font=f_tiny,fill=DIM); d.text((hxs[1],yy),a,font=f_monob,fill=WHITE)
    d.text((hxs[2],yy),side,font=f_monob,fill=col); d.text((hxs[3],yy),amt,font=f_monob,fill=col)
    d.text((hxs[4],yy),ven,font=f_mono,fill=TXT); yy+=29

# COMMAND CONSOLE + WIRE
cmx,cmy,cmw,cmh=1268,614,636,140; panel(cmx,cmy,cmw,cmh,"COMMAND CONSOLE",GREEN)
cmds=["> target XAUUSD --mode accumulate","> flow inject 40B --venue dark","> sweep sector ALL --depth 3","> override SPX --suppress 0.4"]
yy=cmy+44
for c in cmds: d.text((cmx+20,yy),c,font=f_mono,fill=GREEN); yy+=20
d.text((cmx+20,yy),"> _",font=f_monob,fill=GREEN); d.rectangle([cmx+42,yy,cmx+54,yy+16],fill=GREEN)

nx,ny,nw,nh=1268,766,636,154; panel(nx,ny,nw,nh,"PRIORITY WIRE  ·  0-LATENCY",RED)
news=[("18s","Central bank signals surprise liquidity injection"),("44s","Sovereign fund rotates $40B into bullion"),("1m","Major exchange halts withdrawals amid surge"),("2m","Tech megacap guides revenue above street")]
yy=ny+42
for tg,hl in news:
    d.rounded_rectangle([nx+14,yy,nx+54,yy+16],radius=5,fill=PANEL_HI,outline=RED); d.text((nx+19,yy+1),tg,font=f_tiny,fill=RED)
    d.text((nx+62,yy),hl,font=f_lbl,fill=TXT); yy+=26

# status bar
d.rectangle([0,H-24,W,H],fill=(16,13,9)); d.line([0,H-24,W,H-24],fill=LINE)
d.text((18,H-20),"● STREAMING",font=f_tiny,fill=GREEN); d.text((140,H-20),"SRC: Yahoo Finance · Global Wires",font=f_tiny,fill=DIM)
d.text((W-340,H-20),"ATLAS TERMINAL  v0.1  ·  PROTOTYPE",font=f_tiny,fill=DIM)

img.save("/home/user/tv_license_app/prototype/atlas_v3_gold.png","PNG"); print("saved")
