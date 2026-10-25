# hero_grid.py — a labelled comparison sheet: rows x columns of renders on a neutral backdrop (hero_review.py's output; the Director's before / after
# and blind sheets). Usage: python3 -I hero_grid.py out.png "title" "row|labels" "column|labels" files...   (row-major; an empty row label hides the column)
import sys
from PIL import Image, ImageDraw, ImageFont
out,title,rl,cl=sys.argv[1:5]; files=sys.argv[5:]; rl=rl.split("|"); cl=cl.split("|")
F="/System/Library/Fonts/Supplemental/Arial Bold.ttf"; FN="/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"
H=420; TOP=110; PAD=14
RF=ImageFont.truetype(F,60 if max(len(r) for r in rl)<=1 else 34)
LW=(max(int(RF.getlength(r)) for r in rl)+30) if any(rl) else 20
ims=[Image.open(f).convert("RGBA") for f in files]; ims=[i.resize((int(i.width*H/i.height),H),Image.LANCZOS) for i in ims]
nc=len(cl); nr=len(rl); cw=[max(ims[r*nc+c].width for r in range(nr)) for c in range(nc)]
W=LW+sum(cw)+PAD*(nc+1); Ht=TOP+nr*(H+PAD)+PAD
s=Image.new("RGBA",(W,Ht)); d=ImageDraw.Draw(s)
for y in range(Ht):
    t=y/(Ht-1); d.line([(0,y),(W,y)],fill=tuple(int(a+(b-a)*t) for a,b in zip((112,116,124),(78,81,88)))+(255,))
ts=34
while ts>18 and ImageFont.truetype(F,ts).getlength(title)>W-2*PAD: ts-=1
d.text((PAD,18),title,fill=(245,245,245),font=ImageFont.truetype(F,ts))
x=LW+PAD
for c in range(nc):
    d.text((x+cw[c]//2,82),cl[c],fill=(225,228,232),font=ImageFont.truetype(FN,26),anchor="mm"); x+=cw[c]+PAD
for r in range(nr):
    y=TOP+r*(H+PAD); d.text((LW//2+4,y+H//2),rl[r],fill=(245,245,245),font=RF,anchor="mm")
    x=LW+PAD
    for c in range(nc):
        im=ims[r*nc+c]; s.alpha_composite(im,(x+(cw[c]-im.width)//2,y)); x+=cw[c]+PAD
s.convert("RGB").save(out); print("wrote",out,s.size)
