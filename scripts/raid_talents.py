"""Raid-Talentplaene: Talentnamen (englisch, aus Guides) -> Forever-Talentnummern (TraitDefinition.SpellID).
Liest wago-Tabellen (Forever 1.60.1.70959 = Live 19.11.2026) aus <wago-Ordner>, prueft Punkte (51), Hoechstraenge und Klasse,
gibt Lua-Zeilen {nummer, rang} in Reihenfolge nach Baum-Reihe (PosY) aus.
  python3 -I scripts/raid_talents.py <wago-Ordner> <klasse> "Name 5/5, Name 3/3, ..."
"""
import csv, sys, re
wago, cls, text = sys.argv[1], sys.argv[2].upper(), sys.argv[3]
SKILL = {"MAGE": "237", "DRUID": "574", "HUNTER": "50", "PALADIN": "184", "PRIEST": "613", "ROGUE": "38",
         "SHAMAN": "373", "WARLOCK": "354", "WARRIOR": "26"}
def rows(t): return list(csv.DictReader(open(f"{wago}/{t}.csv", encoding="utf-8")))
spell = {r["ID"]: r["Name_lang"] for r in rows("SpellName")}
tdef = {r["ID"]: r for r in rows("TraitDefinition")}
entry = {r["ID"]: r for r in rows("TraitNodeEntry")}
node = {r["ID"]: r for r in rows("TraitNode")}
tree = {r["SkillLineID"]: r["TraitTreeID"] for r in rows("SkillLineXTraitTree")}[SKILL[cls]]
byname = {}
for x in rows("TraitNodeXTraitNodeEntry"):
    n, e = node.get(x["TraitNodeID"]), entry.get(x["TraitNodeEntryID"])
    if not n or not e or n["TraitTreeID"] != tree: continue
    d = tdef.get(e["TraitDefinitionID"])
    if not d: continue
    name = d["OverrideName_lang"] or spell.get(d["SpellID"], "")
    cand = (int(d["SpellID"]), int(e["MaxRanks"]), int(n["PosY"]), int(n["PosX"]), n["TraitSubTreeID"])
    old = byname.get(name.lower())
    # doppelte Namen: der Knoten in einer normalen Reihe (PosY klein) gewinnt
    if not old or cand[2] < old[2]: byname[name.lower()] = cand
# andere Namen in Guides -> Name im Client
ALIAS = {"holy binding": "binding heal"}
picks, total, bad = [], 0, []
for name, r, mx in re.findall(r"([A-Za-z' :\-]+?)\s+(\d+)/(\d+)", text):
    name = name.strip(" ,")
    hit = byname.get(name.lower()) or byname.get(ALIAS.get(name.lower(), ""))
    if not hit: bad.append(name); continue
    sid, maxr, y, x, sub = hit
    if int(r) > maxr: bad.append(f"{name} Rang {r}>{maxr}")
    picks.append((sub, y, x, sid, int(r), name)); total += int(r)
picks.sort()
print(f"-- {cls}: {total} Punkte" + (f", NICHT GEFUNDEN: {bad}" if bad else ""))
print("{" + ", ".join(f"{{{p[3]}, {p[4]}}}" for p in picks) + "},")
