#!/usr/bin/env python3
"""Gegenstandsnamen fuer die Vorschlagsliste im Chat ("[" tippen, Nutzer 23.11.2026).

Quelle: wago.tools ItemSparse (Spieltabelle des Forever-Clients = Fakten aus dem Client), Build aus
scripts/forever_build.txt, je enUS und deDE:
  https://wago.tools/db2/ItemSparse/csv?build=<build>&locale=enUS|deDE
abgelegt unter ../quellen/wago/<buildnr>/ItemSparse_<loc>.csv

Ausgabe: src/ONE_Chat/ItemNames.lua – je Sprache ein Text "id<TAB>qualitaet<TAB>name\\n…" (klein, schnell zu laden).
Weggelassen: Platzhalter/Test-/Alt-Eintraege (OLD, TEST, Deprecated, Monster -, [PH] …) und leere Namen.
"""
import csv, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
build = open(os.path.join(ROOT, "scripts", "forever_build.txt")).read().strip()
src = os.path.join(ROOT, "..", "quellen", "wago", build.split(".")[-1])
SKIP = re.compile(r"^(OLD|TEST|Test |Deprecated|DEPRECATED|Monster - |\[PH\]|PH |zz|ZZ|NPC Equip|Unused|UNUSED)|\b(DEPRECATED|Deprecated|UNUSED|\(test\)|QA )\b")

def load(loc):
    path = os.path.join(src, "ItemSparse_%s.csv" % loc)
    if not os.path.exists(path):
        sys.exit("fehlt: %s (siehe Kopf dieses Skripts)" % path)
    out = {}
    for r in csv.DictReader(open(path, encoding="utf-8")):
        name = (r.get("Display_lang") or "").strip()
        if not name or SKIP.search(name) or "\t" in name or "\n" in name:
            continue
        q = int(r.get("OverallQualityID") or 1)
        out[int(r["ID"])] = (min(max(q, 0), 7), name)
    return out

en, de = load("enUS"), load("deDE")
ids = sorted(set(en) | set(de))

def blob(table):
    lines = []
    for i in ids:
        if i in table:
            q, n = table[i]
            lines.append("%d\t%d\t%s" % (i, q, n))
    return "\n".join(lines) + "\n"

def lua_long(s):
    # langer Lua-String ohne Escapes; Ebene so waehlen, dass "]==]" im Text nicht vorkommt
    eq = "="
    while ("]" + eq + "]") in s:
        eq += "="
    return "[" + eq + "[\n" + s + "]" + eq + "]"

out = os.path.join(ROOT, "src", "ONE_Chat", "ItemNames.lua")
with open(out, "w", encoding="utf-8") as f:
    f.write("-- ERZEUGT mit scripts/build_item_names.py – nicht von Hand aendern.\n")
    f.write("-- Gegenstandsnamen (enUS + deDE) aus wago.tools ItemSparse, Forever-Build %s (Spieltabelle).\n" % build)
    f.write("-- Je Zeile: id<TAB>qualitaet<TAB>name. Fuer die Vorschlagsliste beim Tippen von \"[\" im Chat.\n")
    f.write("local _, chat = ...\n")
    f.write("chat.ItemNames = {build = %r, count = %d,\n" % (build, len(ids)))
    f.write("en = " + lua_long(blob(en)) + ",\n")
    f.write("de = " + lua_long(blob(de)) + ",\n")
    f.write("}\n")
print("ok", len(ids), "Gegenstaende ->", out, os.path.getsize(out), "Bytes")
