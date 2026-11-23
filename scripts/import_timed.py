#!/usr/bin/env python3
"""Zeitlimits der Quests (quest_template.LimitTime, Sekunden) aus cmangos classic-db -> src/ONE_QuestDB/Timed.lua.
Nur Quests, die es in GuildTripQuestDB gibt. Aufruf: python3 scripts/import_timed.py [Pfad zu ClassicDB.sql.gz]"""
import gzip, re, sys, os
src = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Projekte/quellen/classic-db/ClassicDB.sql.gz")
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
data = gzip.open(src, "rt", encoding="utf-8", errors="replace").read()
m = re.search(r"CREATE TABLE `quest_template` \((.*?)\n\)", data, re.S)
cols = re.findall(r"^\s*`(\w+)`", m.group(1), re.M)
iE, iT = cols.index("entry"), cols.index("LimitTime")
known = set(int(x) for x in re.findall(r"^\[(\d+)\]=", open(os.path.join(root, "src/ONE_QuestDB/Data.lua"), encoding="utf-8").read(), re.M))
out = {}
for ins in re.finditer(r"INSERT INTO `quest_template` VALUES (.*?);\n", data, re.S):
    for row in re.finditer(r"\((\d+,.*?)\)(?=,\(|$)", ins.group(1), re.S):
        f = re.findall(r"'(?:[^'\\]|\\.)*'|[^,]+", row.group(1))
        try:
            e, t = int(f[iE]), int(f[iT])
        except (ValueError, IndexError):
            continue
        if t > 0 and e in known:
            out[e] = t
with open(os.path.join(root, "src/ONE_QuestDB/Timed.lua"), "w", encoding="utf-8") as fh:
    fh.write("-- Guild Trip Questdatenbank – automatisch erzeugt von scripts/import_timed.py, NICHT von Hand aendern.\n")
    fh.write("-- Quelle: cmangos classic-db (quest_template.LimitTime). timed[quest] = Zeitlimit in Sekunden\n")
    fh.write("local D = GuildTripQuestDB\nif not D then return end\nD.timed = {\n")
    for e in sorted(out):
        fh.write("[%d]=%d,\n" % (e, out[e]))
    fh.write("}\n")
print(len(out), "Quests mit Zeitlimit")
