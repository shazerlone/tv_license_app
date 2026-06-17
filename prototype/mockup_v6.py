#!/usr/bin/env python3
"""
ATLAS v6 - high-density Bloomberg-style terminal mockup.
Amber-on-black, monospace, many columns/rows, function bar, and a detailed
INSTITUTIONAL FLOW blotter (named funds + their transactions).
Visual prop for video.
"""
import math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W,H=1920,1080
MONO="/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONOB="/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
def ft(p,s): return ImageFont.truetype(p,s)
f9=ft(MONO,9); f9b=ft(MONOB,9)
f10=ft(MONO,10); f10b=ft(MONOB,10)
f11=ft(MONO,11); f11b=ft(MONOB,11)
f12=ft(MONO,12); f12b=ft(MONOB,12)
f13b=ft(MONOB,13); f16b=ft(MONOB,16); f20b=ft(MONOB,20)

# Bloomberg-ish palette
BG=(3,4,6)
ORANGE=(255,140,0)
AMBER=(253,181,40)
WHITE=(222,224,228)
DIM=(122,128,140)
GREEN=(42,210,98)
RED=(255,76,66)
BLUE=(90,150,255)
YELLOW=(255,214,64)
HEADBG=(16,18,24)
HEADBG2=(22,24,32)
LINE=(38,41,50)
PANEL=(7,8,11)

img=Image.new("RGB",(W,H),BG); d=ImageDraw.Draw(img)

def txt(x,y,s,f=f11,c=WHITE): d.text((x,y),s,font=f,fill=c)
def rtxt(x,y,s,f=f11,c=WHITE):
    w=d.textlength(s,font=f); d.text((x-w,y),s,font=f,fill=c)
def tw(s,f=f11): return d.textlength(s,font=f)

def panel(x,y,w,h,num,title,tag=None,tagc=DIM):
    d.rectangle([x,y,x+w,y+h],fill=PANEL,outline=LINE,width=1)
    d.rectangle([x+1,y+1,x+w-1,y+15],fill=HEADBG)
    tx=x+5
    if num: d.text((tx,y+3),num,font=f10b,fill=AMBER); tx+=tw(num,f10b)+5
    d.text((tx,y+3),title,font=f10b,fill=ORANGE)
    if tag:
        rtxt(x+w-6,y+3,tag,f9,tagc)
    return x,y

def colsep(x,y0,y1): d.line([x,y0,x,y1],fill=LINE)

# ============ TOP COMMAND LINE ============
d.rectangle([0,0,W,22],fill=(10,16,30))
d.text((6,4),"ATLAS",font=f12b,fill=AMBER)
d.text((58,4),"<GO>",font=f11b,fill=YELLOW)
d.rectangle([100,3,520,19],outline=(50,70,120),width=1)
d.text((106,5),"MKT Markets · type command…",font=f10,fill=DIM)
for i,(k,v) in enumerate([("EQ","Equities"),("FI","Rates"),("FX","FX"),("CMD","Comdty"),("NEWS","News")]):
    bx=540+i*150
    d.text((bx,4),f"{i+1})",font=f10b,fill=AMBER); d.text((bx+18,4),k,font=f10b,fill=ORANGE)
    d.text((bx+18+tw(k,f10b)+6,5),v,font=f10,fill=DIM)
rtxt(W-6,4,"17-JUN-2026  21:48:07 GMT",f11b,AMBER)
rtxt(W-220,4,"●LIVE",f11b,GREEN)
d.line([0,22,W,22],fill=LINE)

# ============ MARQUEE / STATUS ROW ============
d.rectangle([0,23,W,39],fill=(8,9,13))
marq=[("S&P","5612.40","-0.32%",RED),("NDX","18944.1","+0.54%",GREEN),("DOW","42184.3","+0.28%",GREEN),
      ("VIX","18.60","-2.40%",GREEN),("UST10","4.302","-1.8bp",GREEN),("DXY","104.10","-0.21%",RED),
      ("EUR","1.0914","+0.07%",GREEN),("BTC","104820","+2.41%",GREEN),("XAU","2398.6","+0.86%",GREEN),
      ("WTI","78.42","-1.12%",RED),("BRENT","82.64","-0.89%",RED),("ETH","5512","+3.18%",GREEN)]
mx=8
for s,v,c,col in marq:
    d.text((mx,26),s,font=f10b,fill=AMBER); mx+=tw(s,f10b)+6
    d.text((mx,26),v,font=f10,fill=WHITE); mx+=tw(v,f10)+6
    d.text((mx,26),c,font=f10,fill=col); mx+=tw(c,f10)+14
    d.text((mx-9,26),"|",font=f10,fill=LINE)
d.line([0,39,W,39],fill=LINE)

Y0=42; YB=H-20
# columns
x1,w1=4,440
x2,w2=x1+w1+4,624
x3,w3=x2+w2+4,470
x4,w4=x3+w3+4,W-(x2+w2+4+470+4)-4

# ============================================================
# COLUMN 1 — MARKETS
# ============================================================
def market_table(x,y,w,num,title,tag,cols,rows,rowh=13):
    h=18+len(rows)*rowh+4; panel(x,y,w,h,num,title,tag)
    cy=y+19
    # column headers
    for cx,al,name in cols:
        if al=='l': d.text((x+cx,cy),name,font=f9b,fill=DIM)
        else: rtxt(x+cx,cy,name,f9b,DIM)
    cy+=rowh
    for r in rows:
        for (cx,al,_),val in zip(cols,r):
            s,col=val
            if al=='l': d.text((x+cx,cy),s,font=f10,fill=col)
            else: rtxt(x+cx,cy,s,f10,col)
        cy+=rowh
    return y+h+4

cy=Y0
# WORLD INDICES
idx=[("DOW JONES","42,184.30","+118.40","+0.28"),("S&P 500","5,612.40","-18.10","-0.32"),
     ("NASDAQ","18,944.10","+102.30","+0.54"),("RUSSELL 2K","2,284.60","-6.20","-0.27"),
     ("S&P/TSX","22,140.5","+44.1","+0.20"),("FTSE 100","8,412.70","+24.10","+0.29"),
     ("EURO STOXX","5,012.40","+18.20","+0.36"),("DAX","18,720.40","+88.00","+0.47"),
     ("CAC 40","7,640.20","-12.40","-0.16"),("NIKKEI 225","39,210.50","+210.60","+0.54"),
     ("HANG SENG","18,402.10","-142.30","-0.77"),("SHANGHAI","3,084.70","+8.90","+0.29"),
     ("KOSPI","2,742.30","+15.10","+0.55"),("SENSEX","78,420.60","+312.40","+0.40")]
cols=[(0,'l','INDEX'),(200,'r','LAST'),(310,'r','NET'),(self_w:=w1-8,'r','%CHG')]
rows=[[(n,WHITE),(l,WHITE),(net,GREEN if not net.startswith('-') else RED),(p+"%",GREEN if not p.startswith('-') else RED)] for n,l,net,p in idx]
cy=market_table(x1,cy,w1,"11)","WORLD INDICES","WEI",cols,rows)

# RATES
rts=[("US 2Y","4.214","-3.1"),("US 5Y","4.108","-2.4"),("US 10Y","4.302","-1.8"),("US 30Y","4.466","-1.2"),
     ("BUND 10Y","2.412","-2.0"),("GILT 10Y","4.118","-1.6"),("JGB 10Y","0.984","+0.4"),("OAT 10Y","3.024","-1.4")]
cols=[(0,'l','GOVT'),(190,'r','YIELD'),(w1-8,'r','CHG bp')]
rows=[[(n,WHITE),(y,YELLOW),(c,GREEN if not c.startswith('-') else RED)] for n,y,c in rts]
cy=market_table(x1,cy,w1,"12)","RATES / SOVEREIGN","BTMM",cols,rows)

# FX
fx=[("EUR/USD","1.09140","+0.07"),("USD/JPY","156.420","-0.20"),("GBP/USD","1.27310","+0.09"),
    ("USD/CHF","0.89240","-0.07"),("AUD/USD","0.66420","+0.29"),("USD/CAD","1.36820","-0.06"),
    ("USD/CNH","7.24100","-0.17"),("EUR/GBP","0.85730","-0.05"),("DXY","104.100","-0.21")]
cols=[(0,'l','PAIR'),(200,'r','LAST'),(w1-8,'r','%CHG')]
rows=[[(n,WHITE),(l,WHITE),(c+"%",GREEN if not c.startswith('-') else RED)] for n,l,c in fx]
cy=market_table(x1,cy,w1,"13)","FX RATES","FXIP",cols,rows)

# COMMODITIES + CRYPTO compact
cmd=[("GOLD","2,398.60","+0.86"),("SILVER","31.420","+1.55"),("WTI CRUDE","78.42","-1.12"),
     ("BRENT","82.64","-0.89"),("NAT GAS","2.842","+2.19"),("COPPER","4.512","+0.62"),
     ("BTC/USD","104,820","+2.41"),("ETH/USD","5,512","+3.18")]
cols=[(0,'l','COMDTY/DIGITAL'),(200,'r','LAST'),(w1-8,'r','%CHG')]
rows=[[(n,WHITE),(l,WHITE),(c+"%",GREEN if not c.startswith('-') else RED)] for n,l,c in cmd]
cy=market_table(x1,cy,w1,"14)","COMMODITIES & CRYPTO","GLCO",cols,rows)

# FX CROSS-RATE MATRIX
ccy=["USD","EUR","JPY","GBP","CHF","AUD","CAD"]
fxmat={"USD":1.0,"EUR":1.0914,"JPY":1/156.42,"GBP":1.2731,"CHF":1/0.8924,"AUD":0.6642,"CAD":1/1.3682}
fmh=18+(len(ccy)+1)*15+4; panel(x1,cy,w1,fmh,"15)","FX CROSS-RATE MATRIX","WCRS",DIM)
cellw=(w1-44)//len(ccy); my=cy+19
d.text((x1+6,my),"",font=f9b,fill=DIM)
for j,cj in enumerate(ccy): rtxt(x1+40+(j+1)*cellw-4,my,cj,f9b,AMBER)
my+=15
random.seed(7)
for i,ci in enumerate(ccy):
    d.text((x1+6,my),ci,font=f9b,fill=AMBER)
    for j,cj in enumerate(ccy):
        cell_x=x1+40+(j+1)*cellw-4
        if i==j:
            rtxt(cell_x,my,"—",f9,DIM)
        else:
            rate=fxmat[cj]/fxmat[ci]
            up=random.random()>0.5
            s=f"{rate:.4f}" if rate<10 else f"{rate:.2f}"
            rtxt(cell_x,my,s,f9,GREEN if up else RED)
    my+=15

# UST YIELD CURVE
yc_y=cy+fmh+4; yc_h=YB-yc_y
panel(x1,yc_y,w1,yc_h,"16)","US TREASURY CURVE  ·  vs PRIOR","YCRV",DIM)
curve=[("1M",5.30),("3M",5.18),("6M",4.92),("1Y",4.55),("2Y",4.214),("5Y",4.108),("7Y",4.20),("10Y",4.302),("30Y",4.466)]
prior=[5.34,5.22,4.97,4.60,4.27,4.16,4.25,4.34,4.49]
gl=x1+30; gr=x1+w1-12; gt=yc_y+26; gb=yc_y+yc_h-22; gw=gr-gl; gh=gb-gt
ymin=4.0; ymax=5.4
def CY(v): return gt+(ymax-v)/(ymax-ymin)*gh
for yv in [4.0,4.4,4.8,5.2]:
    yy=CY(yv); d.line([gl,yy,gr,yy],fill=(20,22,28)); rtxt(gl-4,yy-6,f"{yv:.1f}",f9,DIM)
pts=[(gl+i*gw/(len(curve)-1),CY(v)) for i,(_,v) in enumerate(curve)]
ppts=[(gl+i*gw/(len(curve)-1),CY(v)) for i,v in enumerate(prior)]
d.line(ppts,fill=(90,90,110),width=1)  # prior (grey)
for k in range(len(ppts)-1):  # dashed effect
    pass
d.line(pts,fill=AMBER,width=2)
for i,(lbl,v) in enumerate(curve):
    px,py=pts[i]; d.ellipse([px-2,py-2,px+2,py+2],fill=AMBER)
    d.text((px-7,gb+5),lbl,font=f9,fill=DIM)
    if i in (0,4,7,8): rtxt(px+14,py-12,f"{v:.3f}",f9,WHITE)

# ============================================================
# COLUMN 2 — CHART + HEDGE FUND FLOWS
# ============================================================
# main chart
chh=250; panel(x2,Y0,w2,chh,"21)","BTC US Equity  ·  CRYPTO","GIP  1HR",AMBER)
# instrument header line
hy=Y0+18
d.text((x2+6,hy),"BTC/USD",font=f13b,fill=ORANGE)
d.text((x2+90,hy),"104,820.40",font=f16b,fill=GREEN)
d.text((x2+220,hy+2),"+2,468.10",font=f11b,fill=GREEN)
d.text((x2+310,hy+2),"+2.41%",font=f11b,fill=GREEN)
d.text((x2+390,hy),"Bid 104,818",font=f10,fill=DIM)
d.text((x2+500,hy),"Ask 104,823",font=f10,fill=DIM)
hy2=Y0+34
for i,(k,v) in enumerate([("O","102,410"),("H","105,180"),("L","101,980"),("Vol","38.4K BTC"),("VWAP","103,920"),("MCap","2.06T")]):
    bx=x2+6+i*102; d.text((bx,hy2),k,font=f9b,fill=DIM); d.text((bx+tw(k,f9b)+4,hy2),v,font=f9,fill=WHITE)
# chart area
gl=x2+6; gt=Y0+50; gr=x2+w2-54; gb=Y0+chh-46; gw=gr-gl; gh=gb-gt
random.seed(21); n=90; price=0.5; cwid=gw/n; ohlc=[]; vols=[]
for i in range(n):
    o=price; price+=random.uniform(-0.05,0.055)+0.004; c=price
    ohlc.append((o,max(o,c)+random.uniform(0,0.03),min(o,c)-random.uniform(0,0.03),c)); vols.append(random.uniform(0.2,1))
lo=min(x[2] for x in ohlc); hi=max(x[1] for x in ohlc); rng=hi-lo
def PY(v): return gt+(hi-v)/rng*gh
for i in range(5):
    yv=gt+i*gh/4; d.line([gl,yv,gr,yv],fill=(20,22,28))
    rtxt(gr+50,yv-6,f"{(105.2-i*0.9):.1f}k",f9,DIM)
# moving average
ma=[]
for i in range(n):
    s=max(0,i-9); seg=[ohlc[j][3] for j in range(s,i+1)]; ma.append(sum(seg)/len(seg))
d.line([(gl+i*cwid+cwid/2,PY(ma[i])) for i in range(n)],fill=YELLOW,width=1)
# volume + candles
vmax=max(vols)
for i,(o,h_,l_,c) in enumerate(ohlc):
    cx=gl+i*cwid+cwid/2; up=c>=o; col=GREEN if up else RED
    vh=vols[i]/vmax*30; d.rectangle([cx-cwid*0.3,gb+14-vh,cx+cwid*0.3,gb+14],fill=(col[0]//3+10,col[1]//3+10,col[2]//3+10))
    d.line([cx,PY(h_),cx,PY(l_)],fill=col)
    bw=max(2,cwid*0.6); d.rectangle([cx-bw/2,PY(max(o,c)),cx+bw/2,PY(min(o,c))],fill=col)
last=ohlc[-1][3]; ly=PY(last)
d.line([gl,ly,gr,ly],fill=(60,70,82))
d.rectangle([gr,ly-7,gr+52,ly+7],fill=GREEN); d.text((gr+3,ly-6),"104.8k",font=f9b,fill=(4,10,6))
# time axis
for i in range(0,n,15):
    cx=gl+i*cwid; d.text((cx,gb+16),f"{(9+i//15)%24:02d}:00",font=f9,fill=DIM)

# --- OPTIONS FLOW / UNUSUAL ACTIVITY ---
ofy=Y0+chh+4; ofh=160; panel(x2,ofy,w2,ofh,"23)","OPTIONS FLOW  ·  UNUSUAL ACTIVITY","OMON",GREEN)
OC={'time':6,'tk':54,'cp':120,'strike':200,'exp':280,'sz':380,'prem':470,'iv':540,'dlt':w2-8}
ohyr=ofy+18
for key,al,name in [('time','l','TIME'),('tk','l','TICKER'),('cp','l','C/P'),('strike','r','STRIKE'),
   ('exp','l','EXPIRY'),('sz','r','SIZE'),('prem','r','PREMIUM'),('iv','r','IV'),('dlt','r','Δ/SENT')]:
    if al=='l': d.text((x2+OC[key],ohyr),name,font=f9b,fill=DIM)
    else: rtxt(x2+OC[key],ohyr,name,f9b,DIM)
d.line([x2+4,ohyr+13,x2+w2-4,ohyr+13],fill=LINE)
opt=[("NVDA","CALL","1300","20JUN","12,400","$48.2M","62.1","BULLISH",GREEN),
 ("SPY","PUT","552","18JUL","28,000","$31.8M","18.4","HEDGE",RED),
 ("TSLA","CALL","440","27JUN","8,800","$22.4M","71.8","BULLISH",GREEN),
 ("AAPL","CALL","240","19SEP","15,200","$18.9M","29.6","BULLISH",GREEN),
 ("QQQ","PUT","470","16AUG","19,400","$26.1M","21.2","HEDGE",RED),
 ("AMD","CALL","230","18JUL","9,600","$11.2M","54.3","SWEEP",GREEN),
 ("META","CALL","640","20JUN","6,100","$14.7M","41.0","BLOCK",GREEN),
 ("IWM","PUT","224","19DEC","22,500","$9.4M","23.8","BEARISH",RED)]
ocy=ohyr+18
for tk,cp,stk,exp,sz,prem,iv,sent,col in opt:
    d.text((x2+OC['time'],ocy),f"21:4{random.randint(0,7)}",font=f9,fill=DIM)
    d.text((x2+OC['tk'],ocy),tk,font=f9b,fill=YELLOW)
    d.text((x2+OC['cp'],ocy),cp,font=f9b,fill=GREEN if cp=="CALL" else RED)
    rtxt(x2+OC['strike'],ocy,stk,f9,WHITE)
    d.text((x2+OC['exp'],ocy),exp,font=f9,fill=WHITE)
    rtxt(x2+OC['sz'],ocy,sz,f9,WHITE)
    rtxt(x2+OC['prem'],ocy,prem,f9b,col)
    rtxt(x2+OC['iv'],ocy,iv,f9,AMBER)
    rtxt(x2+OC['dlt'],ocy,sent,f9b,col)
    ocy+=15

# --- HEDGE FUND / INSTITUTIONAL FLOW BLOTTER ---
fy=ofy+ofh+4; fh=YB-fy
panel(x2,fy,w2,fh,"22)","INSTITUTIONAL ORDER FLOW  ·  SMART MONEY","HDS / 13F LIVE",GREEN)
# columns
C={'time':6,'fund':52,'act':164,'sec':238,'side':270,'sh':372,'not':452,'px':540,'venue':w2-8}
hyr=fy+18
hdr=[('time','l','TIME'),('fund','l','FUND / MANAGER'),('act','l','ACTION'),('sec','l','SEC'),
     ('side','l','SIDE'),('sh','r','SHARES'),('not','r','NOTIONAL'),('px','r','PRICE'),('venue','r','VENUE')]
for key,al,name in hdr:
    if al=='l': d.text((x2+C[key],hyr),name,font=f9b,fill=DIM)
    else: rtxt(x2+C[key],hyr,name,f9b,DIM)
d.line([x2+4,hyr+13,x2+w2-4,hyr+13],fill=LINE)

funds=["Citadel Advisors","Millennium Mgmt","Bridgewater Assoc","Renaissance Tech","Point72 Asset Mgmt",
 "Two Sigma Invest","BlackRock Inc","Vanguard Group","Man Group plc","AQR Capital","Elliott Mgmt",
 "Pershing Square","Balyasny Asset","ExodusPoint Cap","Marshall Wace","D.E. Shaw & Co",
 "Viking Global","Coatue Mgmt","Tiger Global","Baupost Group"]
secs=[("NVDA",1284.5),("AAPL",228.4),("MSFT",468.2),("AMZN",214.8),("META",612.4),("GOOGL",184.2),
 ("TSLA",412.8),("BTC",104820.0),("ETH",5512.0),("XAU",2398.6),("ES1",5614.0),("AVGO",1742.0),
 ("JPM",244.6),("XOM",112.4),("UNH",512.8),("LLY",928.4)]
acts=[("ACCUMULATE",GREEN,"BUY"),("ADD",GREEN,"BUY"),("NEW POSITION",GREEN,"BUY"),
 ("REDUCE",RED,"SELL"),("TRIM",RED,"SELL"),("EXIT",RED,"SELL"),("ROTATE→",AMBER,"BUY")]
random.seed(99)
rowh=15; nrows=(fh-40)//rowh
cyr=hyr+18
sec_t=8
for i in range(nrows):
    sec_t-=random.uniform(0.0,0.9)
    tstr=f"21:{47-(i//4):02d}:{(58-(i*7)%60):02d}"
    fund=funds[i%len(funds)]
    sym,base=secs[(i*5+3)%len(secs)]
    act,acol,side=acts[(i*3+1)%len(acts)]
    px=base*(1+random.uniform(-0.004,0.004))
    sh=random.choice([0.12,0.25,0.4,0.8,1.2,2.4,3.6,5.1,8.0])
    notion=sh* (base if base>50 else base*1000) /1.0
    notv=random.uniform(0.4,4.2)
    venue=random.choice(["NYSE","NSDQ","DARK7","CBOE","ARCA","CME","LMAX","XOTC","EDGX","IEX"])
    scol=GREEN if side=="BUY" else RED
    d.text((x2+C['time'],cyr),tstr,font=f9,fill=DIM)
    d.text((x2+C['fund'],cyr),fund,font=f10,fill=WHITE)
    d.text((x2+C['act'],cyr),act,font=f9b,fill=acol)
    d.text((x2+C['sec'],cyr),sym,font=f10b,fill=YELLOW)
    d.text((x2+C['side'],cyr),side,font=f9b,fill=scol)
    rtxt(x2+C['sh'],cyr,f"{sh:,.2f}M" if base<50 else f"{sh*1000:,.0f}",f9,WHITE)
    rtxt(x2+C['not'],cyr,f"${notv:,.2f}B",f9b,scol)
    rtxt(x2+C['px'],cyr,f"{px:,.2f}" if base<10000 else f"{px:,.0f}",f9,WHITE)
    rtxt(x2+C['venue'],cyr,venue,f9,DIM)
    if i%2==1: d.rectangle([x2+2,cyr-2,x2+w2-2,cyr+12],fill=None,outline=None)
    cyr+=rowh

# ============================================================
# COLUMN 3 — NEWS + ECON CALENDAR + RATINGS
# ============================================================
# NEWS
nh=560; panel(x3,Y0,w3,nh,"31)","TOP NEWS  ·  FIRST WORD","N  ·  STREAMING",AMBER)
news=[("21:48","BBG","Central bank signals surprise liquidity facility; futures bid",RED),
 ("21:47","RTRS","Gold extends record run as real yields slip to 3-week low",WHITE),
 ("21:46","DJ","Sovereign wealth fund said to rotate ~$40B into bullion - sources",ORANGE),
 ("21:44","BBG","Mega-cap chipmaker guides Q3 revenue well above consensus",GREEN),
 ("21:43","WSJ","Major crypto exchange pauses withdrawals amid record volume",RED),
 ("21:41","FT","ECB officials split on timing of next rate cut, minutes show",WHITE),
 ("21:40","BBG","Treasury curve steepens; desks flag duration unwind into close",WHITE),
 ("21:38","RTRS","Oil slides as OPEC+ weighs unwinding voluntary output cuts",RED),
 ("21:36","CNBC","Activist builds 5.4% stake in industrial conglomerate",GREEN),
 ("21:34","BBG","Yen intervention chatter resurfaces near 156.50 vs dollar",WHITE),
 ("21:32","DJ","Bank earnings season: trading revenue seen up double digits",GREEN),
 ("21:30","RTRS","China stimulus pledge lifts metals; copper at 6-week high",GREEN),
 ("21:28","BBG","Megafund cuts equity beta, adds gold & TIPS - filing",ORANGE),
 ("21:25","FT","Private credit funds raise record dry powder in Q2",WHITE),
 ("21:22","WSJ","Semis lead Nasdaq higher as AI capex guidance reaffirmed",GREEN),
 ("21:19","BBG","VIX slips below 19 as hedging demand fades into expiry",GREEN),
 ("21:16","RTRS","Dollar mixed; Fed speakers stick to data-dependent script",WHITE),
 ("21:12","DJ","Bitcoin ETFs see $1.2B net inflow, largest in six weeks",GREEN)]
cyn=Y0+18
for tm,src,hl,col in news:
    d.text((x3+6,cyn),tm,font=f9,fill=DIM)
    d.rectangle([x3+44,cyn,x3+44+tw(src,f9b)+8,cyn+12],outline=BLUE,width=1)
    d.text((x3+48,cyn),src,font=f9b,fill=BLUE)
    # wrap headline
    avail=w3-(44+tw(src,f9b)+8)-14
    words=hl.split(); line=""; lines=[]
    for wd in words:
        if tw((line+" "+wd).strip(),f10)<avail: line=(line+" "+wd).strip()
        else: lines.append(line); line=wd
    lines.append(line)
    hx=x3+44+tw(src,f9b)+8+6
    for j,ln in enumerate(lines): d.text((hx,cyn+j*12),ln,font=f10,fill=col)
    cyn+=max(15, 4+len(lines)*12)
    d.line([x3+6,cyn-3,x3+w3-6,cyn-3],fill=(18,20,26))

# ECON CALENDAR
ecy=Y0+nh+4; ech=YB-ecy
panel(x3,ecy,w3,ech,"32)","ECONOMIC CALENDAR  ·  TODAY","ECO",DIM)
EC={'t':6,'cty':60,'evt':100,'act':w3-150,'sur':w3-90,'pri':w3-8}
hy=ecy+18
for key,name in [('t','TIME'),('cty','CTY'),('evt','EVENT'),('act','ACT'),('sur','SVY'),('pri','PRI')]:
    if key in('act','sur','pri'): rtxt(x3+EC[key],hy,name,f9b,DIM)
    else: d.text((x3+EC[key],hy),name,font=f9b,fill=DIM)
eco=[("13:30","US","Initial Jobless Claims","221K","230K","225K",GREEN),
 ("13:30","US","Philly Fed Mfg Index","4.2","2.9","1.3",GREEN),
 ("14:00","US","Existing Home Sales","4.02M","4.10M","4.15M",RED),
 ("15:30","US","EIA Crude Inventories","-2.4M","-1.1M","+3.6M",GREEN),
 ("09:00","EC","ECB Rate Decision","4.25%","4.25%","4.50%",WHITE),
 ("07:00","UK","CPI YoY","2.1%","2.3%","2.6%",GREEN),
 ("23:50","JP","Trade Balance","-0.46T","-0.52T","-0.38T",GREEN),
 ("02:00","CN","1Y Loan Prime Rate","3.10%","3.10%","3.35%",WHITE)]
cye=hy+15
for tm,cty,evt,act,sur,pri,col in eco:
    d.text((x3+EC['t'],cye),tm,font=f9,fill=DIM)
    d.text((x3+EC['cty'],cye),cty,font=f9b,fill=AMBER)
    ev=evt if tw(evt,f9)<(EC['act']-EC['evt']-8) else evt[:int((EC['act']-EC['evt']-8)/tw('m',f9))]
    d.text((x3+EC['evt'],cye),ev,font=f9,fill=WHITE)
    rtxt(x3+EC['act'],cye,act,f9b,col)
    rtxt(x3+EC['sur'],cye,sur,f9,DIM)
    rtxt(x3+EC['pri'],cye,pri,f9,DIM)
    cye+=15

# ============================================================
# COLUMN 4 — MOVERS + ORDER BOOK + HEATMAP + BREADTH
# ============================================================
# MOST ACTIVE
mh=300; panel(x4,Y0,w4,mh,"41)","MOST ACTIVE  ·  TOP MOVERS","MOST",AMBER)
mov=[("NVDA","1284.50","+8.42","182M"),("PLTR","78.20","+12.61","94M"),("TSLA","412.80","+5.11","88M"),
 ("AMD","214.90","-3.18","71M"),("MSTR","2210.0","+6.77","12M"),("COIN","388.40","+9.04","28M"),
 ("SMCI","902.00","+4.40","9M"),("INTC","41.20","-4.62","64M"),("AAPL","228.40","+0.92","52M"),
 ("META","612.40","+1.84","21M"),("AMZN","214.80","+1.22","44M"),("MU","132.40","+3.92","33M"),
 ("ARM","148.20","+6.10","18M"),("RIOT","18.40","+11.20","58M"),("MARA","26.10","+9.80","41M"),
 ("BABA","112.80","+2.05","26M"),("HOOD","42.80","+5.55","30M")]
MC={'s':6,'last':150,'chg':250,'vol':w4-8}
hy=Y0+18
for key,name in [('s','SYM'),('last','LAST'),('chg','%CHG'),('vol','VOL')]:
    if key=='s': d.text((x4+MC[key],hy),name,font=f9b,fill=DIM)
    else: rtxt(x4+MC[key],hy,name,f9b,DIM)
cym=hy+15
for s,l,c,v in mov:
    col=GREEN if not c.startswith('-') else RED
    d.text((x4+MC['s'],cym),s,font=f10b,fill=WHITE)
    rtxt(x4+MC['last'],cym,l,f9,WHITE); rtxt(x4+MC['chg'],cym,c,f9b,col); rtxt(x4+MC['vol'],cym,v,f9,DIM)
    cym+=15

# ORDER BOOK
oh=180; oy=Y0+mh+4; panel(x4,oy,w4,oh,"42)","BTC ORDER BOOK","DEPTH",DIM)
random.seed(3); mid=104820
hy=oy+18
d.text((x4+6,hy),"BID SZ",font=f9b,fill=DIM); d.text((x4+90,hy),"PRICE",font=f9b,fill=DIM); rtxt(x4+w4-8,hy,"ASK SZ",f9b,DIM)
cyo=hy+15
for i in range(8):
    bsz=random.uniform(2,30); asz=random.uniform(2,30)
    bp=mid-10-i*10; ap=mid+10+i*10
    # bid bar
    d.rectangle([x4+6,cyo,x4+6+int(bsz/30*70),cyo+11],fill=(14,46,30))
    d.text((x4+6,cyo),f"{bsz:5.2f}",font=f9,fill=GREEN)
    d.text((x4+90,cyo),f"{bp:,.0f}",font=f9,fill=GREEN)
    d.text((x4+170,cyo),f"{ap:,.0f}",font=f9,fill=RED)
    rtxt(x4+w4-8,cyo,f"{asz:5.2f}",f9,RED)
    d.rectangle([x4+w4-8-int(asz/30*70),cyo,x4+w4-8,cyo+11],fill=(46,18,22))
    cyo+=16

# SECTOR HEATMAP
hh=150; hyy=oy+oh+4; panel(x4,hyy,w4,hh,"43)","SECTOR HEATMAP  ·  GICS","RRG",DIM)
sect=[("Tech","+1.84"),("Comm","+0.92"),("Disc","+0.41"),("Fin","-0.22"),
 ("Health","+0.68"),("Indu","+0.12"),("Energy","-1.04"),("Util","-0.38"),
 ("Mat","+0.55"),("Stpl","-0.08"),("RE","-0.61"),("Crypto","+2.41")]
gc=4; gr=3; cwd=(w4-8)//gc; cht=(hh-22)//gr
for i,(nm,ch) in enumerate(sect):
    r=i//gc; c=i%gc; v=float(ch)
    if v>=0: col=(int(10+min(1,v/2.5)*20),int(60+min(1,v/2.5)*120),int(40+min(1,v/2.5)*60))
    else: col=(int(70+min(1,-v/2.5)*150),20,28)
    bx=x4+4+c*cwd; by=hyy+18+r*cht
    d.rectangle([bx,by,bx+cwd-2,by+cht-2],fill=col)
    d.text((bx+4,by+4),nm,font=f9b,fill=WHITE); d.text((bx+4,by+cht-16),ch+"%",font=f9,fill=WHITE)

# MARKET BREADTH
by2=hyy+hh+4; bh2=YB-by2; panel(x4,by2,w4,bh2,"44)","MARKET INTERNALS","BREADTH",DIM)
cyb=by2+20
internals=[("Advancers","1,842",GREEN),("Decliners","1,108",RED),("Unchanged","94",DIM),
 ("New Highs","218",GREEN),("New Lows","41",RED),("TICK","+612",GREEN),
 ("Put/Call","0.82",WHITE),("Fear&Greed","78  GREED",GREEN)]
for i,(k,v,col) in enumerate(internals):
    bx=x4+8+(i%2)*(w4//2); ry=cyb+(i//2)*22
    d.text((bx,ry),k,font=f9b,fill=DIM); d.text((bx,ry+9),v,font=f10b,fill=col)

# ============ FUNCTION BAR ============
d.rectangle([0,H-20,W,H],fill=(10,12,18)); d.line([0,H-20,W,H-20],fill=LINE)
fkeys=["1)HELP","2)MENU","3)NEWS","4)CHART","5)FLOWS","6)ALERT","7)PORT","8)SCREEN","9)ECO","10)FX","11)WEI","12)MOST"]
fx2=8
for k in fkeys:
    num,lbl=k.split(")"); d.text((fx2,H-16),num+")",font=f9b,fill=AMBER); fx2+=tw(num+")",f9b)+2
    d.text((fx2,H-16),lbl,font=f9b,fill=WHITE); fx2+=tw(lbl,f9b)+16
rtxt(W-8,H-16,"ATLAS PROFESSIONAL  ·  GLOBAL MKT ENGINE",f9b,ORANGE)

img.save("/home/user/tv_license_app/prototype/atlas_v6.png","PNG"); print("saved")
