#!/usr/bin/env python3
"""Import: welche Klassenquests einen Zauber/eine Faehigkeit beibringen -> src/ONE_Leveling/ClassSpells.lua

Quelle: cmangos classic-db (GPL-3.0, Stand wie in THIRD_PARTY.md), quest_template RewSpell/RewSpellCast.
Nur Quests mit Klassenbeschraenkung, die auch in ONE_QuestDB stehen. Die Quest-Fuehrung bevorzugt
Klassenquest-Reihen, an deren Ende ein Zauber steht (Nutzer 21.11.2026: "wie wichtig ist die Klassenquest gerade,
ist die Belohnung sinnvoll fuers weitere Questen?").

Aufruf: python3 -I scripts/import_classspells.py <ClassicDB.sql.gz> [ziel=src/ONE_Leveling]
"""
import gzip
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if len(sys.argv) < 2:
    sys.exit(__doc__)
sqlgz = sys.argv[1]
dest = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "src", "ONE_Leveling")

# Klassenquests in ONE_QuestDB (4. Wert = Klassenmaske)
ours = set()
with open(os.path.join(ROOT, "src", "ONE_QuestDB", "Data.lua"), encoding="utf-8") as fh:
    for line in fh:
        m = re.match(r"\[(\d+)\]=\{-?\d+,-?\d+,-?\d+,(\d+),", line)
        if m and int(m.group(2)) > 0:
            ours.add(int(m.group(1)))

TOKEN = re.compile(r"'((?:[^'\\]|\\.)*)'|(-?[0-9.eE+-]+)|(NULL)")


def rows(line):
    i, n, cur = line.index("VALUES") + 6, len(line), None
    while i < n:
        c = line[i]
        if c == "(" and cur is None:
            cur, i = [], i + 1
            continue
        if cur is not None:
            if c == ")":
                yield cur
                cur, i = None, i + 1
                continue
            if c in ", \n":
                i += 1
                continue
            m = TOKEN.match(line, i)
            if not m:
                i += 1
                continue
            if m.group(1) is not None:
                cur.append(m.group(1))
            elif m.group(3):
                cur.append(None)
            else:
                v = m.group(2)
                cur.append(float(v) if ("." in v or "e" in v.lower()) else int(v))
            i = m.end()
            continue
        i += 1


cols, out, cur = [], {}, False
with gzip.open(sqlgz, "rt", encoding="utf-8", errors="replace") as fh:
    for line in fh:
        m = re.match(r"CREATE TABLE `(\w+)`", line)
        if m:
            cur = m.group(1) == "quest_template"
            continue
        if cur and line.startswith("  `"):
            cols.append(line.split("`")[1])
            continue
        if line.startswith("INSERT INTO `quest_template`"):
            for r in rows(line):
                d = dict(zip(cols, r))
                qid = d.get("entry")
                sp = d.get("RewSpellCast") or d.get("RewSpell") or 0
                if qid in ours and sp and d.get("RequiredClasses"):
                    out[qid] = sp

path = os.path.join(dest, "ClassSpells.lua")
with open(path, "w", encoding="utf-8") as fh:
    fh.write("-- Guild Trip Quest-Fuehrung: Klassenquests, die einen Zauber/eine Faehigkeit beibringen – automatisch erzeugt\n")
    fh.write("-- von scripts/import_classspells.py, NICHT von Hand aendern. Quelle: cmangos classic-db (GPL-3.0),\n")
    fh.write("-- quest_template RewSpell/RewSpellCast. sp[quest] = Zauber-ID (gelernt oder als Lernzauber gewirkt).\n")
    fh.write("GuildTripLeveling = GuildTripLeveling or {}\nGuildTripLeveling.sp = {\n")
    for qid in sorted(out):
        fh.write("[%d]=%d,\n" % (qid, out[qid]))
    fh.write("}\n")
print("%d Klassenquests mit Zauber -> %s" % (len(out), path))
