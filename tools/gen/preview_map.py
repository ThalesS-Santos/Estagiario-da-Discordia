import json, os
from PIL import Image
G = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gen")
m = json.load(open(os.path.join(G, "map.json"), encoding="utf-8"))
meta = m["meta"]
def frame(name, f=0, row=0):
    img = Image.open(os.path.join(G, name + ".png")).convert("RGBA")
    md = meta.get(name, {"hframes":1})
    hf = md.get("hframes",1); vf = md.get("vframes",1)
    fw, fh = img.width//hf, img.height//vf
    return img.crop((f*fw, row*fh, f*fw+fw, row*fh+fh)), md.get("origin",[fw//2, fh-1])
S = 2
out = Image.open(os.path.join(G,"terrain/ground.png")).convert("RGBA")
out = out.resize((out.width*S, out.height*S), Image.NEAREST)
def blit(name, x, y, f=0, row=0, flip=False, origin=None):
    img, o = frame(name, f, row)
    if origin is not None: o = origin
    if flip: img = img.transpose(Image.FLIP_LEFT_RIGHT); o=[img.width-o[0], o[1]]
    img = img.resize((img.width*S, img.height*S), Image.NEAREST)
    out.alpha_composite(img, (int(x - o[0]*S), int(y - o[1]*S))) if 0 <= 0 else None
def safe_blit(*a, **k):
    try: blit(*a, **k)
    except ValueError: pass
lp = m["lake"]["pos"]
shore = Image.open(os.path.join(G,"terrain/lake_shore.png")).convert("RGBA")
out.alpha_composite(shore.resize((shore.width*S, shore.height*S), Image.NEAREST), tuple(lp))
wat,_ = frame("terrain/lake"if False else "terrain/lake_water")
px = wat.load()
for y in range(wat.height):
    for x in range(wat.width):
        p = px[x,y]
        if p[3]:
            v = p[0]/255*1.25
            px[x,y] = (min(255,int(0.16*v*255)), min(255,int(0.42*v*255)), min(255,int(0.69*v*255)), 255)
out.alpha_composite(wat.resize((wat.width*S, wat.height*S), Image.NEAREST), tuple(lp))
c = m["castle"]
cas = Image.open(os.path.join(G,"buildings/castle.png")).convert("RGBA")
out.alpha_composite(cas.resize((cas.width*S, cas.height*S), Image.NEAREST), tuple(c["pos"]))
for d in m["decor"]:
    safe_blit(d["s"], d["p"][0], d["p"][1], row=d.get("row",0))
items = list(m["placed"])
for name,(x,y) in m["villagers"].items(): items.append({"s":"chars/"+name,"p":[x,y]})
npcs = {"npc_king":(640,92),"npc_baker":(304,430),"npc_smith":(968,440),"npc_guard":(640,252),"npc_priestess":(224,728),"npc_merchant":(716,484),"npc_orphan":(880,694)}
for n,(x,y) in npcs.items(): items.append({"s":"chars/"+n,"p":[x,y]})
items.append({"s":"buildings/throne","p":c["throne"]})
items.append({"s":"buildings/castle_gate","p":c["gate"]})
for it in sorted(items, key=lambda d: d["p"][1]):
    if it["s"] == "props/fountain_base":
        for l in it["layers"]: safe_blit(l, *it["p"])
    else:
        safe_blit(it["s"], it["p"][0], it["p"][1], flip=it.get("flip",False))
out.save(os.path.join(os.path.dirname(__file__), "_preview_map.png"))
print("ok", out.size)
