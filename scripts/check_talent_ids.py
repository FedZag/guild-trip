"""Prueft alle Talentplaene (Leveln + Situationen/Raid) gegen die Talentbaeume einer Forever-Version.
Jede Nummer muss ein Talent der Klasse sein, Rang <= Hoechstrang, je Plan hoechstens 51 Punkte.
  python3 -I scripts/check_talent_ids.py <wago-Ordner mit TraitDefinition.csv, TraitNode*.csv, SkillLineXTraitTree.csv>
Nach jedem Forever-Update laufen lassen (Nutzer 19.11.2026: Klassen-Aenderungen sofort nachziehen)."""
import csv, subprocess, sys
w = sys.argv[1]
def rows(t): return list(csv.DictReader(open(f"{w}/{t}.csv", encoding="utf-8")))
SKILL = {"MAGE": "237", "DRUID": "574", "HUNTER": "50", "PALADIN": "184", "PRIEST": "613", "ROGUE": "38", "SHAMAN": "373", "WARLOCK": "354", "WARRIOR": "26"}
spell = {r["ID"]: int(r["SpellID"]) for r in rows("TraitDefinition")}
entry = {r["ID"]: r for r in rows("TraitNodeEntry")}
tree_of = {r["ID"]: r["TraitTreeID"] for r in rows("TraitNode")}
tree_for = {r["SkillLineID"]: r["TraitTreeID"] for r in rows("SkillLineXTraitTree")}
mx = {}
for r in rows("TraitNodeXTraitNodeEntry"):
    e, t = entry.get(r["TraitNodeEntryID"]), tree_of.get(r["TraitNodeID"])
    if e and t and e["TraitDefinitionID"] in spell: mx.setdefault(t, {})[spell[e["TraitDefinitionID"]]] = int(e["MaxRanks"])
dump = subprocess.run(["lua5.1", "-e", """
_G.ProjectONE = {db = {}} local c = {}
for _, f in ipairs({"Data.lua", "DataClasses.lua"}) do assert(loadfile("src/ONE_Classes/" .. f))("ONE_Classes", c) end
for cls, def in pairs(c.Data.classes) do for spec, b in pairs(def.build) do
  local function D(list, label) if list then for _, s in ipairs(list) do print(cls, spec, label, s[1], s[2]) end end end
  D(b.talents, "Leveln") for n, sit in pairs(b.situations or {}) do D(sit.talents, n) end end end"""],
    capture_output=True, text=True, check=True).stdout
plans, bad = {}, 0
for line in dump.split("\n"):
    if not line: continue
    cls, spec, label, sid, rank = line.split("\t")
    plans.setdefault((cls, spec, label), []).append((int(sid), int(rank)))
for (cls, spec, label), steps in sorted(plans.items()):
    m = mx.get(tree_for.get(SKILL.get(cls, ""), ""), {})
    for sid, rank in steps:
        if sid not in m: print(f"{cls} {spec} {label}: {sid} ist kein Talent der Klasse"); bad += 1
        elif rank > m[sid]: print(f"{cls} {spec} {label}: {sid} Rang {rank} > {m[sid]}"); bad += 1
    # Plaene nennen den Ziel-Rang (ein Talent kann mehrfach vorkommen: erst 1, spaeter 3) -> hoechster zaehlt
    top = {}
    for sid, rank in steps: top[sid] = max(top.get(sid, 0), rank)
    total = sum(top.values())
    if total > 51: print(f"{cls} {spec} {label}: {total} Punkte"); bad += 1
print(f"{len(plans)} Plaene geprueft, {bad} Probleme")
