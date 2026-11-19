#!/usr/bin/env python3
"""Bosse und Beute der klassischen Dungeons fuer die Dungeon-Seite (Bosses.lua).

Quellen (beide GPL-3.0-vertraeglich, siehe THIRD_PARTY.md):
  - cmangos classic-db (GPL-3.0): offizielle Boss-Liste je Dungeon (instance_dungeon_encounters =
    DungeonEncounter.dbc, instance_encounters = Boss-NPC), Beute-Tabellen (creature_loot_template,
    reference_loot_template) und Gegenstandsqualitaet (item_template).
  - QuestieDB (Forever, GPLv3 mit Erlaubnis): deutsche Bossnamen (l10n/Forever/lookupNpcs/deDE.lua).
Forever hat bei einigen Dungeons Beute geaendert/ergaenzt – das steht NICHT in classic-db; die
Liste zeigt die Classic-Grundlage. Neue Funde kommen spaeter aus dem Spiel (Roster).

Aufruf:
  python3 -I scripts/import_bosses_classic.py <ClassicDB.sql.gz> <QuestieDB-Ordner> > src/ONE_Dungeons/BossDataClassic.lua
"""
import gzip
import hashlib
import os
import re
import sys
from collections import defaultdict

sqlgz, questiedb = sys.argv[1], sys.argv[2]

# Karten-ID -> Katalog-Schluessel (src/ONE_Dungeons/Catalog.lua)
MAPS = {389: "rfc", 43: "wc", 36: "dm", 33: "sfk", 34: "stocks", 48: "bfd", 90: "gnomer", 47: "rfk",
        189: "sm", 129: "rfd", 70: "ulda", 209: "zf", 349: "mara", 109: "st", 230: "brd", 289: "scholo"}
# geteilte Instanzen: Encounter-ID -> Fluegel (eigene Zuordnung nach Spielwissen)
WINGS = {}
for e in range(267, 276): WINGS[e] = "lbrs"          # Omokk .. Wyrmthalak
for e in range(276, 281): WINGS[e] = "ubrs"          # Emberseer .. Drakkisath
for e in (343, 344, 345, 346): WINGS[e] = "dme"      # Zevrim, Hydrospawn, Lethtendris, Alzzin
for e in (347, 348, 349, 350, 361): WINGS[e] = "dmw" # Illyanna, Kalendris, Immol'thar, Tendris, Tortheldrin
for e in range(362, 369): WINGS[e] = "dmn"           # Wachen, Kromcrush, Cho'Rush, Koenig Gordok
for e in range(472, 479): WINGS[e] = "stratlive"     # Unforgiven .. Balnazzar
for e in range(479, 485): WINGS[e] = "stratud"       # Anastari .. Rivendare
WING_MAPS = {229, 429, 329}

MIN_CHANCE = 1.0   # seltener lohnt die Anzeige nicht
MIN_QUALITY = 2    # ab gruen
MAX_ITEMS = 14


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


WANTED = ["instance_dungeon_encounters", "instance_encounters", "creature_template",
          "creature_loot_template", "reference_loot_template", "item_template"]
tabs = {t: [None, []] for t in WANTED}
cur, cols = None, []
with gzip.open(sqlgz, "rt", encoding="utf-8", errors="replace") as f:
    for line in f:
        if line.startswith("CREATE TABLE `"):
            cur, cols = line.split("`")[1], []
            continue
        if cur and line.startswith("  `"):
            cols.append(line.split("`")[1])
            continue
        if cur in tabs and line.startswith(")"):
            tabs[cur][0] = cols
            continue
        if line.startswith("INSERT INTO `"):
            t = line.split("`")[1]
            if t in tabs:
                tabs[t][1].extend(split_rows(line[line.index("VALUES") + 6:].strip().rstrip(";")))


def rows(t):
    cols, data = tabs[t]
    idx = {c: k for k, c in enumerate(cols)}
    for r in data:
        yield lambda c, r=r: r[idx[c]]


credit = {int(r("entry")): (int(r("creditType")), int(r("creditEntry"))) for r in rows("instance_encounters")}
tmpl = {int(r("Entry")): {"name": r("Name"), "loot": int(r("LootId")), "minlvl": int(r("MinLevel")),
                         "maxlvl": int(r("MaxLevel"))} for r in rows("creature_template")}
quality = {int(r("entry")): int(r("Quality")) for r in rows("item_template")}
itemclass = {int(r("entry")): int(r("class")) for r in rows("item_template")}
refs, loot = defaultdict(list), defaultdict(list)
for r in rows("reference_loot_template"):
    refs[int(r("entry"))].append((int(r("item")), float(r("ChanceOrQuestChance")), int(r("groupid")), int(r("mincountOrRef"))))
for r in rows("creature_loot_template"):
    loot[int(r("entry"))].append((int(r("item")), float(r("ChanceOrQuestChance")), int(r("groupid")), int(r("mincountOrRef"))))


def resolve(entries):
    """Gruppen (groupid > 0) ohne eigene Chance teilen sich den Rest bis 100 % (Regel von cmangos)."""
    out, groups = [], defaultdict(list)
    for e in entries:
        (groups[e[2]].append(e) if e[2] > 0 else out.append((e[0], e[1], e[3])))
    for es in groups.values():
        explicit = sum(abs(e[1]) for e in es if e[1] != 0)
        zero = [e for e in es if e[1] == 0]
        share = max(0.0, 100 - explicit) / len(zero) if zero else 0
        for e in es:
            out.append((e[0], e[1] if e[1] != 0 else share, e[3]))
    return out


def expand(entries, factor=1.0, depth=0):
    for item, chance, ref in resolve(entries):
        if ref < 0 and depth < 3:
            yield from expand(refs.get(-ref, []), factor * (abs(chance) if chance != 0 else 100) / 100, depth + 1)
        elif ref >= 0:
            yield item, abs(chance) * factor, depth


# deutsche Namen aus QuestieDB (nur Text lesen, nichts ausfuehren)
de = {}
de_path = os.path.join(questiedb, "l10n", "Forever", "lookupNpcs", "deDE.lua")
for npc, name in re.findall(r'^\[(\d+)\] = \{"((?:[^"\\]|\\.)*)"', open(de_path, encoding="utf-8").read(), re.M):
    de[int(npc)] = name.replace('\\"', '"')

dungeons = defaultdict(list)
for r in rows("instance_dungeon_encounters"):
    mp, eid, idx, name = int(r("MapId")), int(r("Id")), int(r("EncounterIndex")), r("EncounterName")
    key = WINGS.get(eid) if mp in WING_MAPS else MAPS.get(mp)
    if not key:
        continue
    ctype, npc = credit.get(eid, (None, 0))
    if ctype != 0 or npc not in tmpl:
        continue
    t = tmpl[npc]
    best = defaultdict(float)
    for item, chance, depth in expand(loot.get(t["loot"], [])):
        # ab gruen immer; weisse Waffen/Ruestung nur, wenn der Boss sie selbst fallen laesst
        own_white = depth == 0 and quality.get(item, 0) == 1 and itemclass.get(item) in (2, 4)
        if quality.get(item, 0) >= MIN_QUALITY or own_white:
            best[item] = min(100.0, best[item] + chance)
    items = sorted((i for i in best if best[i] >= MIN_CHANCE), key=lambda i: (-quality.get(i, 0), -best[i], i))[:MAX_ITEMS]
    dungeons[key].append({"idx": idx, "encounter": eid, "npc": npc, "name": name or t["name"], "de": de.get(npc),
                          "level": t["maxlvl"] if t["maxlvl"] > 0 else None, "items": items,
                          "drops": {i: round(best[i], 1) for i in items}})


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


sha = hashlib.sha256(open(sqlgz, "rb").read()).hexdigest()
out = ["-- ERZEUGT mit scripts/import_bosses_classic.py – nicht von Hand aendern.",
       "-- Bosse (DungeonEncounter) und Beute der klassischen Dungeons aus cmangos classic-db (GPL-3.0),",
       "-- deutsche Bossnamen aus QuestieDB (Forever, GPLv3 mit Erlaubnis). Siehe THIRD_PARTY.md.",
       "-- Forever-eigene Beute-Aenderungen sind hier NICHT enthalten (Classic-Grundlage).",
       "local _, dungeons = ...", "",
       "dungeons.BossDataClassic = {",
       '    source = {name = "cmangos classic-db", license = "GPL-3.0", file = %s, sha256 = %s},'
       % (q(os.path.basename(sqlgz)), q(sha[:16]))]
total = items_total = 0
for key in sorted(dungeons):
    out.append("    %s = {" % key)
    for b in sorted(dungeons[key], key=lambda b: (b["idx"], b["encounter"])):
        total += 1
        items_total += len(b["items"])
        parts = ["npc = %d" % b["npc"], "encounter = %d" % b["encounter"], "name = " + q(b["name"])]
        if b["de"] and b["de"] != b["name"]:
            parts.append("de = " + q(b["de"]))
        if b["level"]:
            parts.append("level = %d" % b["level"])
        parts.append("items = {%s}" % ", ".join(str(i) for i in b["items"]))
        if b["items"]:
            parts.append("drops = {%s}" % ", ".join("[%d] = %s" % (i, b["drops"][i]) for i in b["items"]))
        out.append("        {%s}," % ", ".join(parts))
    out.append("    },")
out.append("}")
print("\n".join(out))
print("classic-db: %d Dungeons, %d Bosse, %d Gegenstaende" % (len(dungeons), total, items_total), file=sys.stderr)
