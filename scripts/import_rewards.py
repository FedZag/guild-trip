#!/usr/bin/env python3
"""Import: Quest-Belohnungen + Aufwand fuer die Quest-Fuehrung (Guild Trip) -> src/ONE_Leveling/Rewards.lua

Quellen (alle mit festem Stand, siehe THIRD_PARTY.md):
  - QuestieDB Forever (GPLv3, Erlaubnis Questie/Questie#8365): welche Gegenstaende eine Quest belohnt
    (item.questRewards, Forever-genau inkl. neuer Forever-Quests), Gegenstandsart (class/subClass)
  - cmangos classic-db (GPL-3.0): Auswahl- oder feste Belohnung, Gold, Questart (Elite/Dungeon/Schlachtzug),
    Zielanzahlen und Dropchancen (fuer die Zeitschaetzung)
  - wago.tools ItemSparse, Forever-Build 1.60.1.70938 (Spieltabelle = Fakten aus dem Client):
    Platz, Qualitaet, Gegenstandsstufe, Mindeststufe, Taschenplaetze, Verkaufswert, Werte-Arten, Klassen

Aufruf (python3 -I, Lua 5.1 noetig zum Lesen der Questie-Tabellen):
  python3 -I scripts/import_rewards.py <QuestieDB-Ordner> <ClassicDB.sql.gz> <ItemSparse.csv> [ziel=src/ONE_Leveling]

Nur Quests, die auch in ONE_QuestDB stehen. Werte im Spiel werden zusaetzlich ueber GetItemStats gelesen
(Gear.lua); die Tabelle hier ist die Vorab-Auskunft fuer Quests, deren Belohnung noch nicht im Speicher ist.
"""
import csv
import gzip
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def die(msg):
    sys.stderr.write(msg + "\n")
    sys.exit(1)


if len(sys.argv) < 4:
    die(__doc__)
questie, sqlgz, sparse = sys.argv[1], sys.argv[2], sys.argv[3]
dest = sys.argv[4] if len(sys.argv) > 4 else os.path.join(ROOT, "src", "ONE_Leveling")


def git_rev(path):
    try:
        return subprocess.check_output(["git", "-C", path, "log", "-1", "--format=%h %ad", "--date=short"],
                                       text=True).strip()
    except Exception:
        return "?"


# ===== Lua-Tabellen lesen (Sandbox ohne os/io) =====
LUA_DUMP = r"""
local itemsFile, qdbFile = arg[1], arg[2]
local f = assert(loadfile(itemsFile)) setfenv(f, {}) local items = f()
local env = {} local g = assert(loadfile(qdbFile)) setfenv(g, env) g()
local q = env.GuildTripQuestDB.q
for id, e in pairs(q) do io.write("Q ", id, " ", tonumber(e[14]) or 0, "\n") end
-- Dungeon-Gebiete (Questie support/Forever/Zones/dungeons.lua) -> Katalog-Schluessel (ONE_Dungeons/Catalog.lua, englischer Name)
local ZoneDB = {private = {}}
local ldr = {ImportModule = function(_, name) if name == "ZoneDB" then return ZoneDB end return {Current = 0, Wotlk = 3, Cata = 4} end}
local dz = assert(loadfile(DUNGEONS)) setfenv(dz, {QuestieLoader = ldr, UnitFactionGroup = function() return "Alliance" end}) dz()
local ns = {} local cat = assert(loadfile(CATALOG)) setfenv(cat, {}) cat("ONE_Dungeons", ns)
local byName = {} for _, c in ipairs(ns.Catalog) do byName[c.en] = c.key end
local ALIAS = {["The Temple of Atal'Hakkar"] = "Sunken Temple", ["Dire Maul"] = "Dire Maul: East",
  ["Stratholme"] = "Stratholme: Main Gate", ["Blackrock Spire"] = "Lower Blackrock Spire"}
for area, d in pairs(ZoneDB.private.dungeons) do
  local key = byName[d[1]] or byName[ALIAS[d[1]] or ""]
  if key then
    io.write("D ", area, " ", key, "\n")
    for _, alt in ipairs(d[2] or {}) do io.write("D ", alt, " ", key, "\n") end
  end
end
for id, v in pairs(items) do
  if type(v) == "table" then
    io.write("I ", id, " ", tonumber(v[12]) or -1, " ", tonumber(v[13]) or -1, " ", tonumber(v[9]) or 0, " ", tonumber(v[10]) or 0, "\n")
    if type(v[6]) == "table" then for _, qid in ipairs(v[6]) do io.write("R ", qid, " ", id, "\n") end end
  end
end
"""
combined = os.path.join(questie, "src", "corrections", "Forever", "combined", "foreverItemDB.lua")
qdb = os.path.join(ROOT, "src", "ONE_QuestDB", "Data.lua")
out = subprocess.check_output(["lua5.1", "-e", "arg={...}" if False else LUA_DUMP.replace("arg[1]", repr(combined))
                               .replace("arg[2]", repr(qdb))
                               .replace("DUNGEONS", repr(os.path.join(questie, "support", "Forever", "Zones", "dungeons.lua")))
                               .replace("CATALOG", repr(os.path.join(ROOT, "src", "ONE_Dungeons", "Catalog.lua")))], text=True)
known_quests, item_kind, q_rewards, q_zone, dungeon_area = set(), {}, {}, {}, {}
for line in out.splitlines():
    p = line.split()
    if p[0] == "Q":
        known_quests.add(int(p[1]))
        q_zone[int(p[1])] = int(p[2])
    elif p[0] == "D":
        dungeon_area[int(p[1])] = p[2]
    elif p[0] == "I":
        item_kind[int(p[1])] = (int(p[2]), int(p[3]), int(p[4]), int(p[5]))
    elif p[0] == "R":
        q_rewards.setdefault(int(p[1]), []).append(int(p[2]))

# ===== cmangos classic-db (SQL-Dump) =====
TOKEN = re.compile(r"'((?:[^'\\]|\\.)*)'|(-?[0-9.eE+-]+)|(NULL)")


def rows(line):
    """VALUES (…),(…); -> Listen von Werten (Strings/Zahlen)."""
    i = line.index("VALUES") + 6
    n = len(line)
    cur = None
    while i < n:
        c = line[i]
        if c == "(" and cur is None:
            cur = []
            i += 1
            continue
        if cur is not None:
            if c == ")":
                yield cur
                cur = None
                i += 1
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


columns, data = {}, {}
WANT = {"quest_template", "creature_template", "creature_loot_template", "gameobject_loot_template",
        "gameobject_template"}
current = None
with gzip.open(sqlgz, "rt", encoding="utf-8", errors="replace") as fh:
    for line in fh:
        m = re.match(r"CREATE TABLE `(\w+)`", line)
        if m:
            current = m.group(1) if m.group(1) in WANT else None
            if current:
                columns[current] = []
            continue
        if current and line.startswith("  `"):
            columns[current].append(line.split("`")[1])
            continue
        m = re.match(r"INSERT INTO `(\w+)`", line)
        if m and m.group(1) in WANT:
            t = m.group(1)
            data.setdefault(t, []).extend(rows(line))

def table(name):
    cols = columns[name]
    for r in data.get(name, []):
        yield dict(zip(cols, r))


quests = {r["entry"]: r for r in table("quest_template")}
loot_of = {}  # creature entry -> loot id
for r in table("creature_template"):
    if r.get("LootId"):
        loot_of[r["Entry"]] = r["LootId"]
go_loot = {}
for r in table("gameobject_template"):
    if r.get("type") in (3, 25):  # Truhe / Fischschwarm: data1 = Beutetabelle
        go_loot[r["entry"]] = r.get("data1") or 0
# Quest-Drops (negative Chance) sind in Forever deutlich seltener als in cmangos
# (Spieltest 19.11.2026: 15 Zentaurenarmschienen, cmangos 80 % -> fast 1 Stunde, "an die 50 Zentauren").
# Hoechstens so viel annehmen; echte Werte misst die Fuehrung im Spiel (ONE_Leveling/WorkLog.lua):
QUEST_DROP_CAP = 0.3
chance = {}  # (lootid, item) -> Wahrscheinlichkeit 0..1
for r in table("creature_loot_template"):
    raw = r["ChanceOrQuestChance"] or 0
    c = abs(raw) / 100.0
    if c > 0:
        chance[("c", r["entry"], r["item"])] = (c, raw < 0)
for r in table("gameobject_loot_template"):
    c = abs(r["ChanceOrQuestChance"] or 0)
    if c > 0:
        chance[("o", r["entry"], r["item"])] = (c / 100.0, False)
# Gegenstand -> typische Dropchance fuer "sammle X": Mittelwert (Median) ueber alle Monster, die ihn tragen –
# NICHT die beste (ein einzelner Anfuehrer mit 100 % machte aus 15 Armschienen 15 Kills). Objekte nur ohne Monster.
by_item = {}
for (kind, lid, item), (c, quest) in chance.items():
    by_item.setdefault(item, {"c": [], "o": []})[kind].append((c, quest))
item_drop = {}
for item, lists in by_item.items():
    vals = sorted(lists["c"] or lists["o"])
    c, quest = vals[len(vals) // 2]
    # Deckel nur fuer "von vielen Monstern sammeln" – Beute eines einzelnen Anfuehrers (1-2 Monster) bleibt sicher
    if quest and len(lists["c"]) >= 3:
        c = min(c, QUEST_DROP_CAP)
    item_drop[item] = c

# ===== ItemSparse =====
sparse_rows = {}
with open(sparse, newline="", encoding="utf-8") as fh:
    for r in csv.DictReader(fh):
        sparse_rows[int(r["ID"])] = r


def num(v, default=0):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return default


# ===== zusammenfuehren =====
KIND = {1: 1, 81: 2, 62: 4, 41: 8}  # cmangos Type -> Bit: Gruppe/Elite, Dungeon, Schlachtzug, PvP
rewards, used_items = {}, set()
stat = {"nosparse": 0, "cm": 0, "guess": 0, "money": 0, "work": 0}
for qid in sorted(known_quests):
    cm = quests.get(qid)
    qs = sorted(set(q_rewards.get(qid, [])))
    fixed, choice = [], []
    money, work, kind, players = 0, 0, 0, 0
    if cm:
        stat["cm"] += 1
        cm_fixed = [cm["RewItemId%d" % i] for i in range(1, 5) if cm["RewItemId%d" % i]]
        cm_choice = [cm["RewChoiceItemId%d" % i] for i in range(1, 7) if cm["RewChoiceItemId%d" % i]]
        money = max(0, cm["RewOrReqMoney"] or 0)
        kind = KIND.get(cm["Type"] or 0, 0)
        players = cm.get("SuggestedPlayers") or 0
        # Questie ist fuer Forever massgeblich: Gegenstaende, die cmangos nicht kennt, nach Anzahl einordnen
        known = set(cm_fixed) | set(cm_choice)
        fixed = [i for i in cm_fixed if not qs or i in qs]
        choice = [i for i in cm_choice if not qs or i in qs]
        extra = [i for i in qs if i not in known]
        if extra:
            (choice if len(extra) + len(choice) > 1 and not fixed else fixed).extend(extra)
        # Aufwand: Toetungen + Sammeln (Anzahl / Dropchance) + Objekte
        for i in range(1, 5):
            cid, cnt = cm["ReqCreatureOrGOId%d" % i], cm["ReqCreatureOrGOCount%d" % i] or 0
            if cid and cnt:
                work += cnt
            iid, icnt = cm["ReqItemId%d" % i], cm["ReqItemCount%d" % i] or 0
            if iid and icnt and iid != cm.get("SrcItemId"):
                p = item_drop.get(iid, 0)
                work += icnt / p if p >= 0.05 else icnt * (3 if p == 0 else 20)
    else:
        stat["guess"] += 1
        (choice if len(qs) > 1 else fixed).extend(qs)
    if q_zone.get(qid) in dungeon_area and not kind & 4:
        kind |= 2
    if money:
        stat["money"] += 1
    if work:
        stat["work"] += 1
    if fixed or choice or money or work or kind:
        rewards[qid] = (money, min(999, int(round(work))), kind + (16 if players and players > 1 and not kind else 0),
                        fixed, choice)
        used_items.update(fixed)
        used_items.update(choice)

items = {}
for iid in sorted(used_items):
    r = sparse_rows.get(iid)
    cls, sub, qilvl, qreq = item_kind.get(iid, (-1, -1, 0, 0))
    if not r:  # nicht in der Spieltabelle (Forever-Hotfix-Gegenstand): Stufe aus Questie, Platz im Spiel per GetItemInfoInstant
        stat["nosparse"] += 1
        items[iid] = (0, 0, qilvl, qreq, cls, sub, 0, 0, 0, [])
        continue
    stats = [num(r["StatModifier_bonusStat_%d" % k], -1) for k in range(10)]
    stats = [s for s in stats if s > 0]
    allow = num(r["AllowableClass"], -1)
    items[iid] = (num(r["InventoryType"]), num(r["OverallQualityID"]), num(r["ItemLevel"]), num(r["RequiredLevel"]),
                  cls, sub, num(r["ContainerSlots"]), num(r["SellPrice"]), 0 if allow in (-1, 0) else allow % 4096,
                  stats)


def S(t):
    return ",".join(str(v) for v in t) if t else ""


def L(t):
    return "{" + ",".join(str(v) for v in t) + "}" if t else "false"


os.makedirs(dest, exist_ok=True)
qrev = git_rev(questie)
with open(os.path.join(dest, "Rewards.lua"), "w", encoding="utf-8") as fh:
    fh.write("-- Guild Trip Quest-Fuehrung: Belohnungen + Aufwand – automatisch erzeugt von scripts/import_rewards.py,"
             " NICHT von Hand aendern.\n")
    fh.write("-- Quellen: QuestieDB Forever %s (GPLv3, Erlaubnis Questie/Questie#8365), cmangos classic-db e4825cf"
             " (GPL-3.0),\n-- wago.tools ItemSparse Forever-Build 1.60.1.70938 (Spieltabelle).\n" % qrev)
    fh.write("-- Kompakt als Text (spart Speicher im Spiel, gelesen erst bei Bedarf ueber Planner.Rew/Planner.Item):\n")
    fh.write("-- r[quest] = \"kupfer|aufwand (Toetungen/Aktionen)|art (1 Gruppe/Elite, 2 Dungeon, 4 Schlachtzug, 8 PvP,"
             " 16 Gruppe empfohlen)|feste Gegenstaende (a,b)|Auswahl (a,b)\"\n")
    fh.write("-- i[gegenstand] = \"platz (InventoryType)|qualitaet|gegenstandsstufe|mindeststufe|klasse|unterklasse|"
             "taschenplaetze|verkauf (kupfer)|klassenmaske (0 = alle)|werte-arten (a,b)\"\n")
    fh.write("GuildTripLeveling = GuildTripLeveling or {}\nlocal D = GuildTripLeveling\n")
    fh.write("D.source = %s\n" % ('"QuestieDB %s + cmangos classic-db e4825cf + ItemSparse 1.60.1.70938"' % qrev))
    fh.write("D.r = {\n")
    for qid in sorted(rewards):
        m, w, k, fx, ch = rewards[qid]
        fh.write('[%d]="%d|%d|%d|%s|%s",\n' % (qid, m, w, k, S(fx), S(ch)))
    fh.write("}\n-- Dungeon-Gebiet (zoneOrSort der Quest) -> Schluessel in ONE_Dungeons/Catalog.lua\nD.dz = {\n")
    for area in sorted(dungeon_area):
        fh.write("[%d]=%s,\n" % (area, '"%s"' % dungeon_area[area]))
    fh.write("}\nD.i = {\n")
    for iid in sorted(items):
        e = items[iid]
        fh.write('[%d]="%d|%d|%d|%d|%d|%d|%d|%d|%d|%s",\n' % ((iid,) + e[:9] + (S(e[9]),)))
    fh.write("}\n")

size = os.path.getsize(os.path.join(dest, "Rewards.lua"))
print("Quests %d (cmangos %d, nur Questie %d), mit Gold %d, mit Aufwand %d; Gegenstaende %d (%d nicht in ItemSparse);"
      " Datei %.0f KB" % (len(rewards), stat["cm"], stat["guess"], stat["money"], stat["work"], len(items),
                          stat["nosparse"], size / 1024))
