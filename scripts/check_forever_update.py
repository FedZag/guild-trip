"""Guild Trip: Hat WoW Forever ein Update bekommen, und was hat sich fuer uns geaendert?
(Nutzer 19.11.2026: Live-Version regelmaessig pruefen, nach Klassen-Aenderungen alles anpassen.)

  python3 -I scripts/check_forever_update.py            # pruefen und berichten
  python3 -I scripts/check_forever_update.py --accept   # neue Version als geprueft eintragen

Ablauf: neueste Live-Version von wago.tools (Produkt "wowf") gegen scripts/forever_build.txt. Bei neuer Version
werden die Talent- und Zaubertabellen beider Versionen geladen (~/Projekte/quellen/wago/<build>/) und verglichen:
  * Talente je Klasse: neu, entfernt, Hoechstrang geaendert, umbenannt
  * unsere Talentplaene (Leveln + Raid) gegen den neuen Baum (scripts/check_talent_ids.py)
  * Zaubernamen: neue/entfernte/umbenannte Zauber (Anzahl + Beispiele)
Nur Bericht – angepasst wird nach Absprache mit dem Nutzer."""
import csv, json, os, subprocess, sys, urllib.request

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAMP = os.path.join(HERE, "scripts", "forever_build.txt")
CACHE = os.path.expanduser("~/Projekte/quellen/wago")
TABLES = ["TraitDefinition", "TraitNode", "TraitNodeEntry", "TraitNodeXTraitNodeEntry", "SkillLineXTraitTree", "SpellName"]
SKILL = {"MAGE": "237", "DRUID": "574", "HUNTER": "50", "PALADIN": "184", "PRIEST": "613", "ROGUE": "38",
         "SHAMAN": "373", "WARLOCK": "354", "WARRIOR": "26"}

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "GuildTrip-update-check"})
    return urllib.request.urlopen(req, timeout=60).read()

def latest():
    builds = json.loads(get("https://wago.tools/api/builds"))
    return builds["wowf"][0]["version"]

def fetch(build):
    d = os.path.join(CACHE, build.split(".")[-1])
    os.makedirs(d, exist_ok=True)
    for t in TABLES:
        p = os.path.join(d, t + ".csv")
        if not os.path.exists(p) or os.path.getsize(p) < 100:
            open(p, "wb").write(get(f"https://wago.tools/db2/{t}/csv?build={build}"))
    return d

def rows(d, t): return list(csv.DictReader(open(os.path.join(d, t + ".csv"), encoding="utf-8")))

def talents(d):
    spell = {r["ID"]: r["Name_lang"] for r in rows(d, "SpellName")}
    tdef = {r["ID"]: r for r in rows(d, "TraitDefinition")}
    entry = {r["ID"]: r for r in rows(d, "TraitNodeEntry")}
    node = {r["ID"]: r for r in rows(d, "TraitNode")}
    tree = {r["SkillLineID"]: r["TraitTreeID"] for r in rows(d, "SkillLineXTraitTree")}
    out = {c: {} for c in SKILL}
    back = {v: c for c, v in SKILL.items()}
    for r in rows(d, "TraitNodeXTraitNodeEntry"):
        n, e = node.get(r["TraitNodeID"]), entry.get(r["TraitNodeEntryID"])
        if not (n and e): continue
        cls = next((back[s] for s, t in tree.items() if t == n["TraitTreeID"] and s in back), None)
        dd = tdef.get(e["TraitDefinitionID"])
        if not (cls and dd): continue
        sid = int(dd["SpellID"])
        out[cls][sid] = (dd["OverrideName_lang"] or spell.get(dd["SpellID"], "?"), int(e["MaxRanks"]))
    return out, spell

def main():
    new = latest()
    old = open(STAMP).read().strip() if os.path.exists(STAMP) else None
    if "--accept" in sys.argv:
        open(STAMP, "w").write(new + "\n")
        print(f"Als geprueft eingetragen: {new}")
        return
    if new == old:
        print(f"Forever ist aktuell geprueft: {new}")
        return
    print(f"NEUE Forever-Version: {new} (zuletzt geprueft: {old or 'nie'})")
    dn = fetch(new)
    subprocess.run([sys.executable, "-I", os.path.join(HERE, "scripts", "check_talent_ids.py"), dn], cwd=HERE)
    if not old:
        return
    do = fetch(old)
    tn, sn = talents(dn)
    to, so = talents(do)
    for cls in SKILL:
        a, b = to[cls], tn[cls]
        lines = []
        for sid in sorted(set(a) | set(b)):
            if sid not in a: lines.append(f"  + {b[sid][0]} ({sid}, {b[sid][1]} Raenge)")
            elif sid not in b: lines.append(f"  - {a[sid][0]} ({sid})")
            elif a[sid] != b[sid]: lines.append(f"  ~ {a[sid][0]} -> {b[sid][0]}, Raenge {a[sid][1]} -> {b[sid][1]} ({sid})")
        if lines: print(cls + ":"); print("\n".join(lines))
    added = [k for k in sn if k not in so]
    gone = [k for k in so if k not in sn]
    renamed = [k for k in sn if k in so and sn[k] != so[k]]
    print(f"Zauber: {len(added)} neu, {len(gone)} entfernt, {len(renamed)} umbenannt")
    for k in renamed[:15]: print(f"  ~ {so[k]} -> {sn[k]} ({k})")

if __name__ == "__main__":
    main()
