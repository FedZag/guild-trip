"""Guild Trip: Gastwirte (Ruhestein-Orte) fuer die Quest-Fuehrung erzeugen -> src/ONE_Leveling/Inns.lua

  python3 -I scripts/build_inns.py ~/Projekte/quellen/forever-db ~/Projekte/quellen/wago/70959/FactionTemplate.csv

Quellen: forever-db (Polestar, GPL-3; npc.jsonl + spawn.jsonl: Gastwirte und Weltkoordinaten), FactionTemplate
der Forever-Spieldaten (wago.tools: wer darf den Gastwirt nutzen), deutsche Namen aus ONE_QuestDB/Names_deDE.lua."""
import csv, json, os, re, sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fdb, ftcsv = sys.argv[1], sys.argv[2]

inn = {}
for line in open(os.path.join(fdb, "npc.jsonl"), encoding="utf-8"):
    n = json.loads(line)
    if n.get("subname") == "Innkeeper":
        inn[n["id"]] = n
ft = {int(r["ID"]): r for r in csv.DictReader(open(ftcsv, encoding="utf-8"))}
pos = {}
for line in open(os.path.join(fdb, "spawn.jsonl"), encoding="utf-8"):
    s = json.loads(line)
    if s.get("kind") == "npc" and s["id"] in inn and s.get("map") in (0, 1) and s["id"] not in pos:
        pos[s["id"]] = (s["map"], s["x"], s["y"])
de = {}
for line in open(os.path.join(HERE, "src/ONE_QuestDB/Names_deDE.lua"), encoding="utf-8"):
    m = re.match(r'^\[(\d+)\]="(.*)",$', line.strip())
    if m and int(m.group(1)) in inn:
        de[int(m.group(1))] = m.group(2)

def usable(t):
    r = ft.get(t)
    if not r: return 0
    enemy = int(r["EnemyGroup"])
    mask = 0
    if not enemy & 2: mask |= 1   # Allianz
    if not enemy & 4: mask |= 2   # Horde
    return mask

out = ["-- Guild Trip Gastwirte (Ruhestein-Orte) – ERZEUGT von scripts/build_inns.py, nicht von Hand aendern.",
       "-- Quelle: forever-db (Polestar, GPL-3.0) + FactionTemplate der Forever-Spieldaten; deutsche Namen aus QuestieDB.",
       "-- {npc, Kontinent, Welt-x, Welt-y, nutzbar (1 = Allianz, 2 = Horde, 3 = beide), englischer Name, deutscher Name}",
       "local _, lev = ...",
       "lev.INNS = {"]
count = 0
for i in sorted(pos):
    mask = usable(inn[i].get("faction_template", 0))
    if not mask: continue
    c, x, y = pos[i]
    out.append('    {%d, %d, %.1f, %.1f, %d, "%s", %s},' % (i, c, x, y, mask, inn[i]["name"].replace('"', '\\"'),
               ('"%s"' % de[i]) if i in de else "nil"))
    count += 1
out.append("}")
open(os.path.join(HERE, "src/ONE_Leveling/Inns.lua"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print(f"{count} Gastwirte geschrieben ({len(de)} mit deutschem Namen)")
