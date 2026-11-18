-- Offline-Test 0.7.1: Reisetagebuch (Quests, Stufen, neue Gebiete, Dungeons – nur lokal).
local root = arg[1] or "src"
local now = os.time({year = 2026, month = 11, day = 18, hour = 20, min = 5})
GetServerTime = function() return now end
date = os.date
local me = "Tester"
UnitFullName = function() return me, "Realm" end
UnitLevel = function() return 15 end
local map = 1436
C_Map = {GetBestMapForUnit = function() return map end,
    GetPlayerMapPosition = function() return {x = .5, y = .25} end,
    GetMapInfo = function(id) return {name = ({[1436] = "Westfall", [1433] = "Rotkammgebirge"})[id]} end}
local events
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function(_, _, fn) events = fn end} end
local ONE = {db = {}}
_G.ProjectONE = ONE
local guideDB = {}
local lev = {Guide = {DB = function() return guideDB end, Title = function(id) return "Quest " .. id end}}
local recap = {Finish = function() return {name = "Die Todesminen", secs = 2520, record = true, deaths = {Bob = 2}, bosses = {"a", "b"}} end}
ONE.ns = {nav = {QuestLevels = {Level = function(id) return id == 12 and 14 or nil end}}, dungeons = {Recap = recap}}
assert(loadfile(root .. "/ONE_Leveling/Journal.lua"))("ONE_Leveling", lev)
local J = lev.Journal
J:Initialize()

-- 1) Einloggen: Stufen-Beginn gemerkt, Gebiet Westfall neu
events(nil, "PLAYER_ENTERING_WORLD")
local s = J:Store()
assert(s.levelStart == now and s.levelStartLevel == 15 and #s.list == 1 and s.list[1].kind == "zone" and s.list[1].zone == "Westfall")
events(nil, "ZONE_CHANGED_NEW_AREA")
assert(#s.list == 1, "Gebiet nur beim ersten Mal")
-- 2) Quest abgegeben (mit Stufe und EP), Ort gemerkt
now = now + 600
events(nil, "QUEST_TURNED_IN", 12, 850)
local q = s.list[2]
assert(q.kind == "quest" and q.title == "Quest 12" and q.qlevel == 14 and q.xp == 850 and q.map == 1436 and q.x == 500 and q.y == 250)
assert(J.Text(q) == "Quest abgegeben: [14] Quest 12  |cff9d9d9d+850 EP|r", J.Text(q))
-- 3) Stufe erreicht: Dauer der Stufe
now = now + 3600 + 1200
events(nil, "PLAYER_LEVEL_UP", 16)
local l = s.list[3]
assert(l.kind == "level" and l.level == 16 and l.took == 600 + 3600 + 1200)
assert(J.Text(l):find("Stufe 16 erreicht", 1, true) and J.Text(l):find("1 Std. 30 Min.", 1, true), J.Text(l))
-- 4) Neues Gebiet
map = 1433
events(nil, "ZONE_CHANGED_NEW_AREA")
assert(s.list[4].zone == "Rotkammgebirge")
-- 5) Dungeon-Lauf aus dem Rueckblick
recap:Finish()
local d = s.list[5]
assert(d.kind == "dungeon" and d.secs == 2520 and d.record and d.deaths == 2 and d.bosses == 2)
assert(J.Text(d):find("Die Todesminen in 42 Min.", 1, true))
-- 6) Ansicht: neueste zuerst, Tagesueberschrift, Zusammenfassung
local items = J:Items()
assert(items[1].header and items[1].text == "18.11.2026" and items[2].entry.kind == "dungeon", items[1].text)
assert(J:Summary() == "1 Quests · 1 Stufen · 2 Gebiete · 1 Dungeons")
for _, it in ipairs(items) do if it.entry and it.entry.kind == "quest" then assert(it.qid == 12) end end
-- 7) Je Charakter getrennt
me = "Twink"
assert(#J:Store().list == 0)
me = "Tester"
-- 8) Abgeschaltet: nichts Neues
guideDB.journal = false
events(nil, "QUEST_TURNED_IN", 13, 100)
assert(#J:Store().list == 5)
guideDB.journal = nil
-- 9) Hoechstens J.max Eintraege
J.max = 5
events(nil, "QUEST_TURNED_IN", 14, 100)
assert(#J:Store().list == 5 and J:Store().list[5].id == 14 and J:Store().list[1].kind == "quest", "aelteste fliegen raus")
print("OK test_journal_117")
