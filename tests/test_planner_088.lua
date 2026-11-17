-- Offline-Test: Termin-Fenster (Logik) – Vorgaben je Art, Pflichtfelder, Zusammenfassung,
-- Anlegen mit Zusatzangaben, Teilen (TX), woechentliche Wiederholung, Erinnerung je Termin.
local root = arg[1] or "src"
local sent = {}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg) sent[#sent + 1] = msg return true end}
C_Timer = {After = function(_, fn) fn() end, NewTicker = function() return {} end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local now = os.time({year = 2026, month = 11, day = 16, hour = 12, min = 0, sec = 0})
GetServerTime = function() return now end
date, time = os.date, os.time
UnitName = function() return "Hordi" end
UnitFullName = function() return "Hordi", "" end
UnitLevel = function() return 20 end
UnitClass = function() return "Priester", "PRIEST" end
UnitFactionGroup = function() return "Horde" end
IsInGuild = function() return true end
GetZoneText = function() return "Brachland" end
GetSubZoneText = function() return "Wegekreuz" end
C_Map = {GetBestMapForUnit = function() return 1413 end,
    GetPlayerMapPosition = function() return {GetXY = function() return .52, .30 end} end}
local notes = {}
local ONE = {db = {}}
function ONE:Print() end
function ONE:Notify(text) notes[#notes + 1] = text end
_G.ProjectONE = ONE
local d = {}
for _, f in ipairs({"QuestData", "Catalog", "Model", "Share", "Trips", "TripsPlanner"}) do
    assert(loadfile(root .. "/ONE_Dungeons/" .. f .. ".lua"))("ONE_Dungeons", d)
end
d.Share.Tell = function() end
d.Entrances = {Get = function(_, key) if key == "wc" then return {mapID = 1413, x = .46, y = .36} end end}
local Tr, P, S = d.Trips, d.TripsPlanner, d.Share

-- 1) Pflichtfelder: Art, dann Titel bzw. Ziel, Uhrzeit in der Zukunft
local s = P:Defaults()
assert(P:Missing(s) == "Wähle eine Art.")
P:ApplyKind(s, "quest")
assert(P:Missing(s) == "Gib dem Termin einen Titel.")
s.title = "HDW Questrun"
assert(P:Missing(s) == nil, P:Missing(s))
s.day, s.minutes = 0, 10 * 60 -- heute 10:00, schon vorbei
assert(P:Missing(s) == "Diese Uhrzeit ist schon vorbei.")
s.day, s.minutes = 1, 18 * 60 + 30

-- 2) Vorgaben je Art
local dg = P:Defaults()
P:ApplyKind(dg, "dungeon")
assert(dg.key and dg.size == 5 and dg.roles[1] == 1 and dg.roles[3] == 3, tostring(dg.key))
assert(dg.lmin and dg.lmax and 20 >= dg.lmin - 2 and 20 <= dg.lmax, "passender Dungeon fuer Stufe 20")
dg.key = "wc" P:ApplyTarget(dg)
assert(dg.lmin == 15 and dg.lmax == 24 and dg.meet == "entrance", "Stufe + Eingang aus dem Katalog")
assert(P:Missing(dg) == nil or P:Missing(dg) == "Diese Uhrzeit ist schon vorbei.")
local raid = P:Defaults()
P:ApplyKind(raid, "raid")
assert(raid.key == "raid:zg" and raid.size == 20 and raid.lmin == 58 and raid.meet == "capital")
raid.key = "raid:mc" P:ApplyTarget(raid)
assert(raid.size == 40 and raid.lmin == 60)
local meet = P:Defaults()
P:ApplyKind(meet, "meet")
assert(meet.size == 0 and meet.roles[1] == 0 and not P.NeedsTarget(meet))

-- 3) Zusammenfassung
s.dur, s.size, s.roles, s.lmin, s.lmax, s.rep = 120, 5, {1, 1, 3}, 15, 24, "w"
local sum = P:Summary(s)
assert(sum:find("HDW Questrun") and sum:find("morgen 18:30–20:30") and sum:find("wöchentlich")
    and sum:find("5 Plätze %(1 T, 1 H, 3 DD%)") and sum:find("Stufe 15–24") and sum:find("dein Standort"), sum)

-- 4) Anlegen: freies Ziel mit Titel, Zusatzangaben am Termin, TA + TX gehen raus
s.note = "Tränke mitbringen"
local trip = P:Create(s)
S:Flush(20)
assert(trip and trip.key == Tr.FREE and trip.title == "HDW Questrun" and trip.kind == "quest")
assert(trip.dur == 120 and trip.rep == "w" and trip.size == 5 and trip.roles[3] == 3 and trip.lmin == 15 and trip.note == "Tränke mitbringen")
assert(trip.meet.mapID == 1413 and trip.meet.name == "Wegekreuz")
local ta, tx
for _, m in ipairs(sent) do
    if m:find("^TA|" .. trip.id) then ta = m end
    if m:find("^TX|" .. trip.id) then tx = m end
end
assert(ta and tx, "TA und TX")
assert(tx == "TX|" .. trip.id .. "|quest|120|w|15|5|1|1|3|15|24|Tränke mitbringen", tx)
assert(Tr:InfoText(trip) == "Quests · 2 Std. · Stufe 15–24 · 5 Plätze · wöchentlich", Tr:InfoText(trip))
assert(Tr:RoleText(trip) == "T 0/1 · H 0/1 · DD 1/3", Tr:RoleText(trip)) -- Leiter ist als DD angemeldet

-- 5) Empfang bei anderen: TX vor TA (Stub), danach TA vom selben Absender
Tr:Store()[trip.id] = nil
S:Receive(S.prefix, tx, "GUILD", "Thrall-Forever")
assert(Tr:Store()[trip.id].stub and Tr:Store()[trip.id].note == "Tränke mitbringen")
S:Receive(S.prefix, ta, "GUILD", "Thrall-Forever")
local got = Tr:Get(trip.id)
assert(got and got.kind == "quest" and got.roles[1] == 1 and got.rep == "w" and got.title == "HDW Questrun")
-- TX von jemand anderem wird ignoriert
S:Receive(S.prefix, "TX|" .. trip.id .. "|raid|60||0|40|9|9|9|1|2|Fake", "GUILD", "Boese")
assert(got.kind == "quest" and got.note == "Tränke mitbringen")
-- unsinnige Werte werden verworfen
S:Receive(S.prefix, "TX|stub2|kaputt|99999|x|abc|500|1|1|1|0|0|", "GUILD", "Jemand")
local st = Tr:Store().stub2
assert(st.kind == nil and st.dur == nil and st.size == nil and st.remind == nil)

-- 6) Erinnerung je Termin: 60 Minuten vorher statt 15
Tr:Store()[trip.id] = nil
local early = Tr:Create(Tr.FREE, now + 2 * 3600, Tr:HereMeet(), "Gildentreffen", {kind = "meet", remind = 60})
now = early.start - 50 * 60
Tr:Tick()
assert(#notes == 1 and notes[1]:find("50 Minuten"), tostring(notes[1]))
Tr:Store()[early.id] = nil -- sonst meldet er sich gleich zum Start
local silent = Tr:Create(Tr.FREE, now + 3600, Tr:HereMeet(), "Ohne", {kind = "meet", remind = 0})
now = silent.start - 5 * 60
Tr:Tick()
assert(#notes == 1, "remind = 0: keine Vorab-Erinnerung")

-- 7) Woechentlich: nach Ablauf legt der Leiter den naechsten Termin an (gleiche Angaben, neue Anmeldungen)
for k in pairs(Tr:Store()) do Tr:Store()[k] = nil end
local weekly = Tr:Create(Tr.FREE, now + 3600, Tr:HereMeet(), "Raidabend", {kind = "raid", rep = "w", size = 40, note = "Flasks"})
now = weekly.start + Tr.keep + 60
local list = Tr:List()
assert(#list == 1 and list[1].id ~= weekly.id and list[1].start == weekly.start + 7 * 86400, "naechste Woche")
assert(list[1].title == "Raidabend" and list[1].rep == "w" and list[1].note == "Flasks" and list[1].size == 40)
print("OK test_planner_088")
