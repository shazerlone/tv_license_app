#!/usr/bin/env python3
"""
ATLAS TERMINAL - dramatic 'war room' concept, more panels.
Visual prop for video. Renders two theme variants.
"""
import math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

W, H = 1920, 1080
FP = "/usr/share/fonts/truetype/dejavu/"
def font(n, s): return ImageFont.truetype(FP + n, s)

f_brand = font("DejaVuSans-Bold.ttf", 30)
f_sub   = font("DejaVuSans.ttf", 14)
f_h     = font("DejaVuSans-Bold.ttf", 16)
f_lbl   = font("DejaVuSans.ttf", 12)
f_mono  = font("DejaVuSansMono.ttf", 14)
f_monob = font("DejaVuSansMono-Bold.ttf", 14)
f_big   = font("DejaVuSansMono-Bold.ttf", 38)
f_huge  = font("DejaVuSansMono-Bold.ttf", 52)
f_tiny  = font("DejaVuSansMono.ttf", 11)
f_clock = font("DejaVuSansMono-Bold.ttf", 22)


def build(theme):
    if theme == "cyan":
        BG=(8,11,18); PANEL=(15,20,30); PANEL_HI=(20,27,40); LINE=(32,44,64)
        A1=(45,226,230); A2=(46,230,138); GOLD=(240,196,74); RED=(255,78,96)
        TXT=(208,224,240); DIM=(118,138,162); WHITE=(235,245,255); GLOWBG=(14,26,40)
    else:  # gold/black luxury war-room
        BG=(10,9,7); PANEL=(20,17,12); PANEL_HI=(28,24,16); LINE=(60,50,28)
        A1=(240,196,74); A2=(255,150,40); GOLD=(240,196,74); RED=(255,78,96)
        TXT=(232,222,200); DIM=(150,134,100); WHITE=(255,248,232); GLOWBG=(40,30,10)
    GREEN=(46,230,138)

    img = Image.new("RGB",(W,H),BG); d=ImageDraw.Draw(img)
    g=Image.new("RGB",(W,H),BG); gd=ImageDraw.Draw(g)
    gd.ellipse([W//2-1000,-800,W//2+1000,600], fill=GLOWBG)
    g=g.filter(ImageFilter.GaussianBlur(200)); img=Image.blend(img,g,0.55); d=ImageDraw.Draw(img)

    def panel(x,y,w,h,title=None,accent=A1):
        d.rounded_rectangle([x,y,x+w,y+h], radius=9, fill=PANEL, outline=LINE, width=1)
        if title:
            d.line([x+13,y+32,x+w-13,y+32], fill=LINE)
            d.rectangle([x+13,y+15,x+17,y+28], fill=accent)
            d.text((x+26,y+14), title, font=f_h, fill=WHITE)

    def glow(layer_draw_fn, blur=6):
        nonlocal img,d
        L=Image.new("RGB",(W,H),(0,0,0)); ld=ImageDraw.Draw(L)
        layer_draw_fn(ld); L=L.filter(ImageFilter.GaussianBlur(blur))
        img=ImageChops.screen(img,L); d=ImageDraw.Draw(img)

    # ---- HEADER ----
    d.rectangle([0,0,W,72], fill=tuple(int(c*0.7) for c in PANEL))
    d.line([0,72,W,72], fill=LINE)
    d.rounded_rectangle([26,16,68,58], radius=8, outline=A1, width=2)
    d.line([32,48,42,32,47,42,56,24,62,38], fill=A1, width=2, joint="curve")
    d.text((84,12), "ATLAS  TERMINAL", font=f_brand, fill=WHITE)
    d.text((86,46), "GLOBAL  LIQUIDITY  COMMAND  ·  WAR  ROOM", font=f_sub, fill=A1)
    px=720
    for lbl,vl,c in [("ENGINE","LIVE",GREEN),("LAT","2ms",A1),("NODES","1,284",A1),
                     ("THREAT","HIGH",RED),("FEED","YAHOO",GOLD)]:
        d.rounded_rectangle([px,20,px+138,50], radius=14, fill=PANEL_HI, outline=LINE)
        d.ellipse([px+12,29,px+24,41], fill=c)
        d.text((px+32,24), lbl, font=f_tiny, fill=DIM)
        d.text((px+32,35), vl, font=f_monob, fill=TXT); px+=148
    d.text((W-220,18), "GMT 17 JUN 2026", font=f_lbl, fill=DIM)
    d.text((W-220,38), "21:48:07", font=f_clock, fill=A1)

    # ---- TICKER STRIP ----
    ty=80
    d.rounded_rectangle([16,ty,W-16,ty+50], radius=7, fill=PANEL, outline=LINE)
    tick=[("BTC","104,820",+2.41,GREEN),("XAU","2,398.6",+0.86,GREEN),("SPX","5,612",-0.32,RED),
          ("NDX","18,944",+0.54,GREEN),("ETH","5,512",+3.18,GREEN),("WTI","78.42",-1.12,RED),
          ("EUR","1.0914",+0.07,GREEN),("DXY","104.1",-0.21,RED),("VIX","18.6",-2.40,RED),
          ("SOL","248.6",+7.31,GREEN)]
    cw=(W-32)//len(tick)
    for i,(s,v,ch,c) in enumerate(tick):
        x=24+i*cw
        d.text((x,ty+7), s, font=f_lbl, fill=DIM)
        d.text((x,ty+23), v, font=f_monob, fill=WHITE)
        d.text((x+82,ty+23), f"{'▲' if ch>=0 else '▼'}{abs(ch):.2f}", font=f_tiny, fill=c)
        if i: d.line([x-10,ty+10,x-10,ty+40], fill=LINE)

    # ================= CENTER: 3D WIREFRAME GLOBE =================
    gx,gy,gw,gh=520,142,560,470
    panel(gx,gy,gw,gh,"GLOBAL FLOW SPHERE  ·  REAL-TIME", A1)
    cx0,cy0=gx+gw//2, gy+gh//2+10; R=185
    rot=0.6
    def sph(lat,lon):
        lat=math.radians(lat); lon=math.radians(lon)+rot
        x=math.cos(lat)*math.sin(lon); y=math.sin(lat); z=math.cos(lat)*math.cos(lon)
        return cx0+x*R, cy0-y*R, z
    # latitude rings
    for lat in range(-60,61,30):
        pts=[]
        for lon in range(0,361,6):
            X,Y,Z=sph(lat,lon)
            if Z>-0.05: pts.append((X,Y))
        if len(pts)>1: d.line(pts, fill=tuple(int(c*0.5) for c in A1), width=1)
    # longitude rings
    for lon in range(0,360,30):
        pts=[]
        for lat in range(-90,91,6):
            X,Y,Z=sph(lat,lon)
            if Z>-0.05: pts.append((X,Y))
        if len(pts)>1: d.line(pts, fill=tuple(int(c*0.35) for c in A1), width=1)
    # outer glow ring
    glow(lambda ld: ld.ellipse([cx0-R,cy0-R,cx0+R,cy0+R], outline=A1, width=3), blur=8)
    d.ellipse([cx0-R,cy0-R,cx0+R,cy0+R], outline=tuple(int(c*0.7) for c in A1), width=1)
    # hub nodes + arcs
    hubs={"NY":(40,-74),"LDN":(51,0),"TKO":(35,139),"HK":(22,114),"DXB":(25,55),"SGP":(1,103),"SAO":(-23,-46)}
    pos={}
    for n,(la,lo) in hubs.items():
        X,Y,Z=sph(la,lo); pos[n]=(X,Y,Z)
    flows=[("LDN","NY",GREEN),("TKO","LDN",A1),("HK","NY",GREEN),("DXB","LDN",GOLD),("SGP","NY",A1)]
    def arc(ld,a,b,col):
        (x1,y1,z1),(x2,y2,z2)=pos[a],pos[b]
        mxp=(x1+x2)/2; myp=(y1+y2)/2-90; prev=(x1,y1)
        for t in [i/30 for i in range(31)]:
            bx=(1-t)**2*x1+2*(1-t)*t*mxp+t*t*x2
            by=(1-t)**2*y1+2*(1-t)*t*myp+t*t*y2
            ld.line([prev,(bx,by)], fill=col, width=2); prev=(bx,by)
    for a,b,c in flows: glow(lambda ld,a=a,b=b,c=c: arc(ld,a,b,c), blur=3)
    for a,b,c in flows:
        def crisp(ld,a=a,b=b,c=c):
            (x1,y1,z1),(x2,y2,z2)=pos[a],pos[b]
            mxp=(x1+x2)/2; myp=(y1+y2)/2-90; prev=(x1,y1)
            for t in [i/30 for i in range(31)]:
                bx=(1-t)**2*x1+2*(1-t)*t*mxp+t*t*x2
                by=(1-t)**2*y1+2*(1-t)*t*myp+t*t*y2
                ld.line([prev,(bx,by)], fill=c, width=1); prev=(bx,by)
        crisp(d)
    for n,(X,Y,Z) in pos.items():
        if Z>-0.05:
            d.ellipse([X-5,Y-5,X+5,Y+5], fill=A1)
            d.ellipse([X-10,Y-10,X+10,Y+10], outline=A1, width=1)
            d.text((X+10,Y-4), n, font=f_tiny, fill=TXT)
    # bottom metrics
    for i,(lb,vl,c) in enumerate([("VOL 24H","$4.82T",GREEN),("FLOWS","1,284",A1),
                                  ("NET","+$182.6B",GREEN),("RISK","ELEVATED",GOLD)]):
        bxm=gx+24+i*135
        d.text((bxm,gy+gh-36), lb, font=f_tiny, fill=DIM)
        d.text((bxm,gy+gh-22), vl, font=f_monob, fill=c)

    # ================= LEFT COLUMN =================
    # alerts
    ax,ay,aw,ah=16,142,490,180
    panel(ax,ay,aw,ah,"PRIORITY ALERTS", RED)
    alerts=[("CRIT","Whale wallet moved 12,400 BTC",RED),
            ("HIGH","Gold breaks 2,400 resistance",GOLD),
            ("HIGH","Liquidity vacuum detected · NDX",RED),
            ("INFO","Sovereign fund accumulating",A1)]
    yy=ay+44
    for tg,msg,c in alerts:
        d.rounded_rectangle([ax+14,yy,ax+62,yy+18], radius=5, fill=PANEL_HI, outline=c)
        d.text((ax+19,yy+2), tg, font=f_tiny, fill=c)
        d.text((ax+72,yy+1), msg, font=f_lbl, fill=TXT); yy+=32

    # signal meters (VU style)
    sx,sy,sw,sh=16,334,490,278
    panel(sx,sy,sw,sh,"SIGNAL STRENGTH  ·  ASSET MOMENTUM", A2)
    meters=[("BTC",0.92,GREEN),("ETH",0.81,GREEN),("GOLD",0.74,GOLD),("SPX",0.38,RED),
            ("NDX",0.55,A1),("OIL",0.29,RED),("SOL",0.88,GREEN),("DXY",0.41,RED)]
    yy=sy+46; bw=sw-130
    for name,val,c in meters:
        d.text((sx+18,yy), name, font=f_monob, fill=TXT)
        d.rounded_rectangle([sx+78,yy+1,sx+78+bw,yy+15], radius=4, fill=PANEL_HI)
        n=int(bw/12)
        for k in range(n):
            on = k/n < val
            col = c if on else tuple(int(cc*0.25) for cc in c)
            kx=sx+82+k*12
            d.rectangle([kx,yy+3,kx+8,yy+13], fill=col)
        d.text((sx+78+bw+8,yy), f"{int(val*100)}", font=f_mono, fill=c); yy+=28

    # ================= RIGHT: ORDER BOOK + OPTIONS FLOW =================
    # order book ladder
    ox,oy,ow,oh=1090,142,400,300
    panel(ox,oy,ow,oh,"BTC ORDER BOOK  ·  DEPTH", A1)
    d.text((ox+18,oy+42),"PRICE",font=f_tiny,fill=DIM)
    d.text((ox+150,oy+42),"SIZE",font=f_tiny,fill=DIM)
    d.text((ox+260,oy+42),"DEPTH",font=f_tiny,fill=DIM)
    random.seed(1); yy=oy+62; base=104900
    asks=[(base+i*15, random.uniform(2,40)) for i in range(6)][::-1]
    bids=[(base-15-i*15, random.uniform(2,40)) for i in range(6)]
    for pr,sz in asks:
        w=int(sz/40*(ow-60))
        d.rectangle([ox+ow-30-w,yy,ox+ow-30,yy+16], fill=(50,20,26))
        d.text((ox+18,yy), f"{pr:,.0f}", font=f_mono, fill=RED)
        d.text((ox+150,yy), f"{sz:.1f}", font=f_mono, fill=TXT); yy+=18
    d.rectangle([ox+14,yy+2,ox+ow-14,yy+24], fill=PANEL_HI)
    d.text((ox+18,yy+5), "104,820", font=f_monob, fill=GREEN)
    d.text((ox+150,yy+5), "SPREAD 5.0", font=f_mono, fill=DIM); yy+=30
    for pr,sz in bids:
        w=int(sz/40*(ow-60))
        d.rectangle([ox+ow-30-w,yy,ox+ow-30,yy+16], fill=(16,46,32))
        d.text((ox+18,yy), f"{pr:,.0f}", font=f_mono, fill=GREEN)
        d.text((ox+150,yy), f"{sz:.1f}", font=f_mono, fill=TXT); yy+=18

    # options flow heatmap
    hx,hy,hw,hh=1090,454,400,158
    panel(hx,hy,hw,hh,"OPTIONS FLOW HEATMAP", GOLD)
    cols=12; rows=4; cwt=(hw-40)//cols; cht=(hh-58)//rows
    random.seed(8)
    for r in range(rows):
        for c in range(cols):
            v=random.random()
            if v>0.55: col=(int(20+v*40),int(120+v*110),int(70+v*60))
            elif v<0.3: col=(int(120+ (0.3-v)*300),int(30),int(40))
            else: col=PANEL_HI
            d.rectangle([hx+20+c*cwt, hy+44+r*cht, hx+20+c*cwt+cwt-2, hy+44+r*cht+cht-2], fill=col)
    d.text((hx+20,hy+hh-18),"CALLS",font=f_tiny,fill=GREEN)
    d.text((hx+hw-70,hy+hh-18),"PUTS",font=f_tiny,fill=RED)

    # ---- BTC chart (center bottom-ish? put under globe? keep right of globe) ----
    # screener far right
    scx,scy,scw,sch=1500,142,404,470
    panel(scx,scy,scw,sch,"TOP MOVERS  ·  SCREENER", A1)
    rows2=[("NVDA","1,284.5",+8.42,GREEN),("TSLA","412.80",+5.11,GREEN),("PLTR","78.20",+12.6,GREEN),
           ("COIN","388.4",+9.04,GREEN),("MSTR","2,210",+6.77,GREEN),("AMD","214.9",-3.18,RED),
           ("INTC","41.20",-4.62,RED),("BABA","112.8",+2.05,GREEN),("SOL","248.6",+7.31,GREEN),
           ("AVAX","58.10",-2.44,RED),("ARM","148.2",+6.10,GREEN),("SMCI","902.0",+4.40,GREEN),
           ("RIOT","18.40",+11.2,GREEN),("MARA","26.10",+9.80,GREEN)]
    yy=scy+46
    d.text((scx+16,yy-2),"SYM",font=f_tiny,fill=DIM); d.text((scx+120,yy-2),"PRICE",font=f_tiny,fill=DIM)
    d.text((scx+250,yy-2),"CHG%",font=f_tiny,fill=DIM); d.text((scx+330,yy-2),"TREND",font=f_tiny,fill=DIM)
    yy+=16
    for i,(s,p,c,col) in enumerate(rows2):
        if i%2==0: d.rectangle([scx+8,yy-2,scx+scw-8,yy+20], fill=PANEL_HI)
        d.text((scx+16,yy), s, font=f_monob, fill=WHITE)
        d.text((scx+120,yy), p, font=f_mono, fill=TXT)
        d.text((scx+245,yy), f"{'▲' if c>=0 else '▼'}{abs(c):.1f}", font=f_mono, fill=col)
        random.seed(i+5); sp=[]; vv=0.5
        for k in range(16):
            vv+=random.uniform(-0.2,0.22 if col==GREEN else 0.14); vv=max(0.1,min(0.9,vv))
            sp.append((scx+330+k*4, yy+15-vv*13))
        d.line(sp, fill=col, width=1); yy+=22

    # ================= BOTTOM ROW =================
    # transaction tape + big number
    bx,by,bw,bh=16,624,980,296
    panel(bx,by,bw,bh,"LIVE TRANSACTION TAPE  ·  SETTLEMENTS > $1B", GREEN)
    d.text((bx+24,by+46),"TOTAL CLEARED TODAY",font=f_lbl,fill=DIM)
    glow(lambda ld: ld.text((bx+24,by+64),"$1.284",font=f_huge,fill=GREEN), blur=8)
    d.text((bx+24,by+64),"$1.284",font=f_huge,fill=GREEN)
    d.text((bx+26,by+122),"TRILLION",font=f_big,fill=GREEN)
    d.text((bx+26,by+166),"▲ 18.4% vs prior",font=f_mono,fill=GREEN)
    tape=[("21:48:06","BTC","BUY","$3.20B","COINBASE PRIME",GREEN),
          ("21:48:05","XAU","SELL","$1.92B","LBMA LONDON",RED),
          ("21:48:04","ETH","BUY","$1.41B","BINANCE OTC",GREEN),
          ("21:48:03","SPX","BUY","$2.88B","DARK POOL #7",GREEN),
          ("21:48:01","BTC","BUY","$1.10B","KRAKEN OTC",GREEN),
          ("21:47:58","XAU","BUY","$2.05B","COMEX",GREEN)]
    tx=bx+360; ty2=by+48
    d.line([tx-16,by+42,tx-16,by+bh-14], fill=LINE)
    for hh2,xx in zip(["TIME","ASSET","SIDE","NOTIONAL","VENUE"],[tx,tx+105,tx+185,tx+265,tx+380]):
        d.text((xx,ty2),hh2,font=f_tiny,fill=DIM)
    ty2+=22; hxs=[tx,tx+105,tx+185,tx+265,tx+380]
    for t,a,side,amt,ven,col in tape:
        d.rectangle([tx-6,ty2-2,bx+bw-14,ty2+24], fill=PANEL_HI)
        d.text((hxs[0],ty2),t,font=f_mono,fill=DIM); d.text((hxs[1],ty2),a,font=f_monob,fill=WHITE)
        d.text((hxs[2],ty2),side,font=f_monob,fill=col); d.text((hxs[3],ty2),amt,font=f_monob,fill=col)
        d.text((hxs[4],ty2),ven,font=f_mono,fill=TXT); ty2+=29

    # institutional flow
    fx,fy,fw,fh=1010,624,480,140
    panel(fx,fy,fw,fh,"INSTITUTIONAL FLOW  ·  LIVE", GOLD)
    funds=[("BLACKSTONE","BTC","+ $2.40B",GREEN),("VANGUARD","GOLD","+ $1.18B",GREEN),
           ("CITADEL","NDX","- $880M",RED),("BRIDGEWATER","BTC","+ $640M",GREEN)]
    yy=fy+44
    for nm,asset,amt,col in funds:
        d.ellipse([fx+18,yy+3,fx+28,yy+13], fill=col)
        d.text((fx+38,yy),nm,font=f_mono,fill=TXT); d.text((fx+210,yy),asset,font=f_tiny,fill=DIM)
        d.text((fx+270,yy),amt,font=f_monob,fill=col); yy+=23

    # news wire
    nx,ny,nw,nh=1010,776,480,144
    panel(nx,ny,nw,nh,"PRIORITY WIRE  ·  0-LATENCY", RED)
    news=[("18s","Central bank signals surprise liquidity injection"),
          ("44s","Sovereign fund rotates $40B into bullion"),
          ("1m","Major exchange halts withdrawals amid surge"),
          ("2m","Tech megacap guides revenue above street")]
    yy=ny+42
    for tg,hl in news:
        d.rounded_rectangle([nx+14,yy,nx+54,yy+16], radius=5, fill=PANEL_HI, outline=RED)
        d.text((nx+19,yy+1),tg,font=f_tiny,fill=RED)
        words=hl.split(); line=""; lines=[]
        for w in words:
            if d.textlength(line+" "+w,font=f_lbl)<nw-80: line=(line+" "+w).strip()
            else: lines.append(line); line=w
        lines.append(line)
        for j,ln in enumerate(lines): d.text((nx+62,yy+j*15),ln,font=f_lbl,fill=TXT)
        yy+=18+len(lines)*15

    # status bar
    d.rectangle([0,H-24,W,H], fill=tuple(int(c*0.7) for c in PANEL)); d.line([0,H-24,W,H-24],fill=LINE)
    d.text((18,H-20),"● STREAMING",font=f_tiny,fill=GREEN)
    d.text((140,H-20),"SRC: Yahoo Finance · Global Wires",font=f_tiny,fill=DIM)
    d.text((W-340,H-20),"ATLAS TERMINAL  v0.1  ·  PROTOTYPE",font=f_tiny,fill=DIM)

    out=f"/home/user/tv_license_app/prototype/atlas_v2_{theme}.png"
    img.save(out,"PNG"); print("saved", out)

build("cyan")
build("gold")
