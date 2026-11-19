#!/usr/bin/env python3
"""Guild Trip: Ausruestungsdaten fuer "Ausruestung auf deinem Weg" (Leveln).

Liest drei offene Quellen und schreibt src/ONE_Leveling/GearData.lua:
  1. ForeverLevelingBiS von Thunder (MIT), ueber Polestar_ItemDB/Forever.lua (GPL-3.0):
     Leveling-Gegenstaende fuer WoW Forever mit Forever-Werten und Herkunft
     (Quest, Drop mit Chance und Gebiet, Herstellung mit Beruf und Fertigkeit).
  2. Polestar_ItemDB/Items.lua (GPL-3.0): Werte aller Gegenstaende aus den Classic-Era-
     Spieltabellen (Fakten aus dem Client), fuer alles, was ForeverLevelingBiS nicht hat.
  3. cmangos classic-db (GPL-3.0): Dungeon-Beute der klassischen Dungeons (wer steht in welchem
     Dungeon, was faellt mit welcher Chance) - ergaenzt die Dungeons, die (1) nicht abdeckt.

Aufruf: python3 -I scripts/import_gear.py <Polestar_ItemDB-Ordner> <ClassicDB.sql.gz> [ziel=src/ONE_Leveling]

Ausgabe (GuildTripGear):
  items[item] = "<inv> <ilvl> <req> <quality> <class> <subclass> [werte ...]"   (Format wie Polestar)
  src[item]   = { {"q", quest}, {"d", dungeon, npc, chance}, {"c", beruf, fertigkeit} ... }
  npcs[npc]   = Name (Bosse und benannte Gegner in Dungeons)
  dungeons    = Dungeon-Schluessel wie in ONE_Dungeons/Catalog.lua
"""
import gzip
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if len(sys.argv) < 3:
    sys.exit(__doc__)
itemdb, sqlgz = sys.argv[1], sys.argv[2]
dest = sys.argv[3] if len(sys.argv) > 3 else os.path.join(ROOT, "src", "ONE_Leveling")

# Instanz-Karten (Map.db2) -> Dungeon-Schluessel in Guild Trip
MAPS = {389: "rfc", 43: "wc", 36: "dm", 33: "sfk", 34: "stocks", 48: "bfd", 90: "gnomer", 47: "rfk",
        189: "sm", 129: "rfd", 70: "ulda", 209: "zf", 349: "mara", 109: "st", 230: "brd", 429: "dme",
        229: "lbrs", 289: "scholo", 329: "stratlive", 3065: "thanes", 2999: "ruins", 2998: "excavation",
        2959: "dalaran", 2970: "drowned", 3039: "krol", 2994: "alcaz", 2974: "blackmaw", 3001: "shaper"}
# Gebiets-IDs (AreaTable) aus ForeverLevelingBiS -> Dungeon-Schluessel (Namen wie dort)
AREA_NAMES = {"The Deadmines": "dm", "Wailing Caverns": "wc", "Razorfen Kraul": "rfk", "Stratholme": "stratlive",
              "Shadowfang Keep": "sfk", "Blackrock Spire: Upper": "ubrs", "Blackrock Spire: Lower": "lbrs",
              "City of Dalaran": "dalaran", "Blackfathom Deeps": "bfd", "Ruins of Lordaeron": "ruins",
              "The Stockade": "stocks", "Gnomeregan": "gnomer", "Scholomance": "scholo", "Uldaman": "ulda",
              "Ragefire Chasm": "rfc", "Hall of Thanes": "thanes", "Razorfen Downs": "rfd",
              "Excavation Site: Wetlands": "excavation", "Zul'Farrak": "zf", "Maraudon": "mara",
              "Sunken Temple": "st", "Blackrock Depths": "brd", "Dire Maul": "dme"}
for wing in ("Graveyard", "Library", "Armory", "Cathedral"):
    AREA_NAMES["Scarlet Monastery: " + wing] = "sm"


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# ===== 1 + 2: Polestar_ItemDB =====
def read_entries(text):
    return {int(a): b for a, b in re.findall(r'\[(\d+)\]="([^"]*)"', text)}


items_lua = open(os.path.join(itemdb, "Items.lua"), encoding="utf-8").read()
era = read_entries(items_lua[items_lua.index("DB.Register("):])
fl = open(os.path.join(itemdb, "Forever.lua"), encoding="utf-8").read()
lev_start = fl.index("DB.RegisterLeveling(")
forever_stats = read_entries(fl[fl.index("DB.Register("):lev_start])
lev = fl[lev_start:]
professions = re.search(r'professions = \{([^}]*)\}', lev).group(1)
professions = re.findall(r'"([^"]*)"', professions)


def section(name, nxt):
    a = lev.index("\n%s = {" % name)
    b = lev.index("\n%s = {" % nxt) if nxt else len(lev)
    return lev[a:b]


src_raw = read_entries(section("src", "quests"))
npc_names = read_entries(section("npcs", "zones"))
zone_names = read_entries(section("zones", None))

stats = dict(era)
stats.update(forever_stats)  # Forever-Werte gehen vor
src = defaultdict(list)
npcs = {}
unknown_areas = defaultdict(int)
for item, v in src_raw.items():
    for part in v.split(","):
        m = re.match(r"q(\d+)$", part)
        if m:
            src[item].append(("q", int(m.group(1))))
            continue
        m = re.match(r"d(\d+)x(\d+)z(\d+)$", part)
        if m:
            npc, chance, zone = int(m.group(1)), int(m.group(2)) / 10, int(m.group(3))
            key = AREA_NAMES.get(zone_names.get(zone, ""))
            if key:
                src[item].append(("d", key, npc, chance))
                if npc and npc in npc_names:
                    npcs[npc] = npc_names[npc]
            else:
                # Drop in der offenen Welt (benannter Gegner): Gebietsname behalten
                src[item].append(("w", zone_names.get(zone, "?"), npc, chance))
                if npc and npc in npc_names:
                    npcs[npc] = npc_names[npc]
                unknown_areas[zone_names.get(zone, zone)] += 1
            continue
        m = re.match(r"c(\d+)p(\d+)s(\d+)$", part)
        if m:
            prof = professions[int(m.group(2)) - 1] if 0 < int(m.group(2)) <= len(professions) else "?"
            src[item].append(("c", prof, int(m.group(3)), int(m.group(1))))
covered = {s[1] for v in src.values() for s in v if s[0] == "d"}
print("ForeverLevelingBiS: %d Gegenstaende, Dungeons: %s" % (len(src_raw), ", ".join(sorted(covered))))

# ===== 3: classic-db =====
def sql_tables(path, wanted):
    """Liest INSERT-Zeilen der gewuenschten Tabellen: {tabelle: (spalten, [zeilen])}"""
    out = {t: [None, []] for t in wanted}
    cur, cols = None, []
    value_re = re.compile(r"\((.*?)\)(?:,|;)\s*$")
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("CREATE TABLE `"):
                cur = line.split("`")[1]
                cols = []
                continue
            if cur and line.startswith("  `"):
                cols.append(line.split("`")[1])
                continue
            if cur in out and line.startswith(")"):
                out[cur][0] = cols
                continue
            if line.startswith("INSERT INTO `"):
                t = line.split("`")[1]
                if t in out:
                    body = line[line.index("VALUES") + 6:].strip().rstrip(";")
                    for row in split_rows(body):
                        out[t][1].append(row)
    return out


def split_rows(body):
    rows, i, n = [], 0, len(body)
    while i < n:
        if body[i] != "(":
            i += 1
            continue
        i += 1
        vals, cur, q = [], [], False
        while i < n:
            c = body[i]
            if q:
                if c == "\\":
                    cur.append(body[i + 1]); i += 2; continue
                if c == "'":
                    q = False
                else:
                    cur.append(c)
            else:
                if c == "'":
                    q = True
                elif c == ",":
                    vals.append("".join(cur)); cur = []
                elif c == ")":
                    vals.append("".join(cur)); i += 1; break
                else:
                    cur.append(c)
            i += 1
        rows.append(vals)
    return rows


tabs = sql_tables(sqlgz, ["creature", "creature_template", "creature_loot_template", "reference_loot_template", "item_template",
                         "npc_trainer", "npc_trainer_template", "npc_vendor", "npc_vendor_template", "quest_template",
                         "spell_template"])


def rows(t):
    cols, data = tabs[t]
    idx = {c: k for k, c in enumerate(cols)}
    for r in data:
        yield lambda c, r=r: r[idx[c]]


npc_dungeon = {}
spawns = defaultdict(list)  # Kreatur -> [(map, x, y)] in der offenen Welt
for r in rows("creature"):
    m = int(r("map"))
    if m in MAPS:
        npc_dungeon[int(r("id"))] = MAPS[m]
    elif m in (0, 1):
        spawns[int(r("id"))].append((m, float(r("position_x")), float(r("position_y"))))
alltmpl = {}
for r in rows("creature_template"):
    alltmpl[int(r("Entry"))] = {"name": r("Name"), "rank": int(r("Rank")), "loot": int(r("LootId")),
                                "trainer": int(r("TrainerTemplateId")), "vendor": int(r("VendorTemplateId"))}
tmpl = {e: t for e, t in alltmpl.items() if e in npc_dungeon}
itemt = {}
for r in rows("item_template"):
    inv = int(r("InventoryType"))
    if inv > 0:
        itemt[int(r("entry"))] = {"q": int(r("Quality")), "req": int(r("RequiredLevel")), "inv": inv}
refs = defaultdict(list)
for r in rows("reference_loot_template"):
    refs[int(r("entry"))].append((int(r("item")), float(r("ChanceOrQuestChance")), int(r("groupid")), int(r("mincountOrRef"))))
loot = defaultdict(list)
for r in rows("creature_loot_template"):
    loot[int(r("entry"))].append((int(r("item")), float(r("ChanceOrQuestChance")), int(r("groupid")), int(r("mincountOrRef"))))


def resolve(entries):
    """Chance je Eintrag: Gruppen (groupid > 0) ohne eigene Chance teilen sich, was die
    anderen Eintraege der Gruppe von 100 % uebrig lassen (Regel von cmangos)."""
    out = []
    groups = defaultdict(list)
    for e in entries:
        if e[2] > 0:
            groups[e[2]].append(e)
        else:
            out.append((e[0], e[1], e[3]))
    for g, es in groups.items():
        explicit = sum(abs(e[1]) for e in es if e[1] != 0)
        zero = [e for e in es if e[1] == 0]
        share = max(0.0, 100 - explicit) / len(zero) if zero else 0
        for e in es:
            out.append((e[0], e[1] if e[1] != 0 else share, e[3]))
    return out


def expand(entries, factor=1.0, depth=0):
    for item, chance, ref in resolve(entries):
        if ref < 0 and depth < 3:
            # Verweis auf eine gemeinsame Beuteliste: Chance des Verweises (100 %, wenn keine) x Chance darin
            share = (abs(chance) if chance != 0 else 100) / 100
            yield from expand(refs.get(-ref, []), factor * share, depth + 1)
        elif ref >= 0:
            yield item, abs(chance) * factor


MIN_CHANCE = 1.0  # unter 1 % lohnt sich die Jagd beim Leveln nicht
added = 0
for npc, t in tmpl.items():
    key = npc_dungeon[npc]
    for item, chance in expand(loot.get(t["loot"], [])):
        it = itemt.get(item)
        if not it or it["q"] < 2 or chance < MIN_CHANCE:
            continue
        # nur Bosse/Elite mit Namen oder gute Chance (sonst ueberall Grauzeug der Trashgegner)
        if t["rank"] == 0 and chance < 5:
            continue
        if any(s[0] == "d" and s[2] == npc for s in src[item]):
            continue
        src[item].append(("d", key, npc, round(chance, 1)))
        npcs[npc] = t["name"]
        if item not in stats and item in era:
            stats[item] = era[item]
        added += 1
print("classic-db: %d Dungeon-Drops ergaenzt" % added)

# ===== Rezepte: woher lernt man den Herstellungszauber? =====
# ui_map-Rahmen aus forever-db (Welt-Yards je Gebietskarte) fuer Kartenkoordinaten
import json
UIMAPS = []
uimap_path = os.path.join(os.path.dirname(itemdb.rstrip("/")), "..", "forever-db", "data", "ui_map.jsonl")
uimap_path = os.path.normpath(uimap_path)
if os.path.exists(uimap_path):
    for l in open(uimap_path, encoding="utf-8"):
        u = json.loads(l)
        if u["ui_map"] not in (1414, 1415, 947):  # Kontinente/Welt nicht
            UIMAPS.append(u)


def to_map(m, x, y):
    best = None
    for u in UIMAPS:
        if u["map"] != m:
            continue
        mx = (u["left"] - y) / (u["left"] - u["right"])
        my = (u["top"] - x) / (u["top"] - u["bottom"])
        if 0 <= mx <= 1 and 0 <= my <= 1:
            area = abs((u["left"] - u["right"]) * (u["top"] - u["bottom"]))
            if not best or area < best[0]:
                best = (area, u["ui_map"], round(mx, 4), round(my, 4))
    return best and best[1:]


craft_spells = {s[3] for v in src.values() for s in v if s[0] == "c"}
learn = defaultdict(list)
places = {}


def place(npc):
    if npc in places or not spawns.get(npc):
        return npc in places
    m, x, y = spawns[npc][0]
    pm = to_map(m, x, y)
    if pm:
        places[npc] = pm
        npcs[npc] = alltmpl.get(npc, {}).get("name", "?")
    return bool(pm)


# Lern-Zauber -> Herstellungszauber (Effekt 36 = Zauber lernen); Lehrer und Rezepte nennen den Lern-Zauber
teaches = {}
for r in rows("spell_template"):
    for k in (1, 2, 3):
        if int(r("Effect%d" % k)) == 36:
            t = int(r("EffectTriggerSpell%d" % k))
            if t in craft_spells:
                teaches[int(r("Id"))] = t


def craft_of(spell):
    return spell if spell in craft_spells else teaches.get(spell)


# Lehrer: direkt (npc_trainer) oder ueber Vorlagen (creature_template.TrainerTemplateId)
by_template = defaultdict(list)
for e, t in alltmpl.items():
    if t["trainer"]:
        by_template[t["trainer"]].append(e)
for table, owners in (("npc_trainer", None), ("npc_trainer_template", by_template)):
    for r in rows(table):
        spell = craft_of(int(r("spell")))
        if not spell:
            continue
        who = owners.get(int(r("entry")), []) if owners else [int(r("entry"))]
        for npc in who:
            if place(npc):
                learn[spell].append(("t", npc, int(r("reqskillvalue")), int(r("spellcost"))))
# Rezept-Gegenstaende: lehren einen Herstellungszauber (Ausloeser 6 = beim Benutzen lernen)
recipe_item = {}
for r in rows("item_template"):
    for k in range(1, 6):
        sp = craft_of(int(r("spellid_%d" % k)))
        if sp and int(r("spelltrigger_%d" % k)) in (0, 6):
            recipe_item[int(r("entry"))] = sp
vendor_by_template = defaultdict(list)
for e, t in alltmpl.items():
    if t["vendor"]:
        vendor_by_template[t["vendor"]].append(e)
for table, owners in (("npc_vendor", None), ("npc_vendor_template", vendor_by_template)):
    for r in rows(table):
        it = int(r("item"))
        if it not in recipe_item:
            continue
        who = owners.get(int(r("entry")), []) if owners else [int(r("entry"))]
        for npc in who:
            if place(npc):
                learn[recipe_item[it]].append(("v", npc, it, int(r("maxcount")) > 0 and 1 or 0))
# Rezept-Drops (nur nennenswerte Chancen) und Questbelohnungen
drop_best = {}
rare = {}
for e, t in alltmpl.items():
    if not t["loot"]:
        continue
    for it, chance in expand(loot.get(t["loot"], [])):
        if it in recipe_item and chance > 0:
            if chance < 0.5:
                rare[(recipe_item[it], it)] = rare.get((recipe_item[it], it), 0) + 1
                continue
            key = (recipe_item[it], it)
            if key not in drop_best or chance > drop_best[key][1]:
                drop_best[key] = (e, chance)
# seltene Weltdrops: viele Gegner, jeder unter 0,5 % -> ohne Ort, nur "seltener Weltdrop"
for (spell, it), n in rare.items():
    if (spell, it) not in drop_best:
        learn[spell].append(("r", it, n))
for (spell, it), (npc, chance) in drop_best.items():
    dkey = npc_dungeon.get(npc)
    if dkey:
        learn[spell].append(("d", dkey, npc, it, round(chance, 1)))
        npcs[npc] = alltmpl[npc]["name"]
    elif place(npc):
        learn[spell].append(("w", npc, it, round(chance, 1)))
for r in rows("quest_template"):
    rewards = [int(r("RewItemId%d" % k)) for k in range(1, 5)] + [int(r("RewChoiceItemId%d" % k)) for k in range(1, 7)]
    for it in rewards:
        if it in recipe_item:
            learn[recipe_item[it]].append(("q", int(r("entry")), it))
known = sum(1 for sp in craft_spells if learn.get(sp))
print("Rezepte: %d Herstellungszauber, Herkunft bekannt fuer %d (Lehrer/Haendler/Drop/Quest), Orte: %d" % (len(craft_spells), known, len(places)))

# ===== Ausgabe =====
out_items = {i: stats[i] for i in src if i in stats}
missing = [i for i in src if i not in stats]
if missing:
    print("ohne Werte (ausgelassen): %d" % len(missing))
lines = [
    "-- Guild Trip: Ausruestung auf deinem Weg - ERZEUGT von scripts/import_gear.py, nicht von Hand aendern.",
    "-- Quellen: ForeverLevelingBiS v0.12.0-beta von Thunder (MIT) ueber Polestar_ItemDB (GPL-3.0);",
    "-- Polestar_ItemDB/Items.lua (Classic-Era-Spieltabellen, Fakten); cmangos classic-db (GPL-3.0). Siehe THIRD_PARTY.md.",
    "-- items[g] = \"<platz> <gstufe> <mindeststufe> <qualitaet> <klasse> <unterklasse> [werte]\"",
    "-- src[g] = {{\"q\", quest} | {\"d\", dungeon, npc, chance% (0 = unbekannt)} | {\"w\", gebiet, npc, chance%} | {\"c\", beruf, fertigkeit, zauber}}",
    "GuildTripGear = GuildTripGear or {}",
    "local G = GuildTripGear",
    "G.items = {",
]
for i in sorted(out_items):
    lines.append("[%d]=%s," % (i, lua_str(out_items[i])))
lines.append("}")
lines.append("G.src = {")
for i in sorted(out_items):
    parts = []
    for s in src[i]:
        if s[0] == "q":
            parts.append("{\"q\",%d}" % s[1])
        elif s[0] in ("d", "w"):
            parts.append("{\"%s\",%s,%d,%s}" % (s[0], lua_str(s[1]), s[2], ("%g" % s[3])))
        else:
            parts.append("{\"c\",%s,%d,%d}" % (lua_str(s[1]), s[2], s[3]))
    lines.append("[%d]={%s}," % (i, ",".join(parts)))
lines.append("}")
lines.append("-- learn[zauber] = {{\"t\", lehrer, fertigkeit, preis(kupfer)} | {\"v\", haendler, rezept, begrenzt} |")
lines.append("--   {\"d\", dungeon, npc, rezept, chance%} | {\"w\", npc, rezept, chance%} | {\"q\", quest, rezept} |")
lines.append("--   {\"r\", rezept, anzahl gegner} (seltener Weltdrop: viele Gegner, je unter 0,5 %)}")
lines.append("G.learn = {")
for sp in sorted(learn):
    parts = []
    seen = set()
    for l in learn[sp]:
        if l in seen:
            continue
        seen.add(l)
        if l[0] == "t":
            parts.append("{\"t\",%d,%d,%d}" % l[1:])
        elif l[0] == "v":
            parts.append("{\"v\",%d,%d,%d}" % l[1:])
        elif l[0] == "d":
            parts.append("{\"d\",%s,%d,%d,%g}" % (lua_str(l[1]), l[2], l[3], l[4]))
        elif l[0] == "w":
            parts.append("{\"w\",%d,%d,%g}" % l[1:])
        elif l[0] == "r":
            parts.append("{\"r\",%d,%d}" % l[1:])
        else:
            parts.append("{\"q\",%d,%d}" % l[1:])
    lines.append("[%d]={%s}," % (sp, ",".join(parts)))
lines.append("}")
lines.append("-- places[npc] = {uiMapID, x, y} (Kartenanteile) fuer Lehrer, Haendler und Rezept-Gegner")
lines.append("G.places = {")
for n in sorted(places):
    lines.append("[%d]={%d,%g,%g}," % ((n,) + places[n]))
lines.append("}")
lines.append("G.npcs = {")
for n in sorted(npcs):
    lines.append("[%d]=%s," % (n, lua_str(npcs[n])))
lines.append("}")
path = os.path.join(dest, "GearData.lua")
with open(path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
dcount = defaultdict(int)
for i in out_items:
    for s in src[i]:
        if s[0] == "d":
            dcount[s[1]] += 1
print("geschrieben:", path, "Gegenstaende:", len(out_items), "Groesse: %d KB" % (os.path.getsize(path) // 1024))
print("Drops je Dungeon:", dict(sorted(dcount.items())))
