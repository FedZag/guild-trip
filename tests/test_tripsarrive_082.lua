-- Offline-Test: Gildenausflug Stufe 3 (Erinnerung, Navi zum Treffpunkt, Ankunftstafel).
local root = arg[1] or "src"
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end, SendAddonMessage = function() return true end}
C_Timer = {After = function(_, fn) fn() end, NewTicker = function() return {} end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local now = 1800000000
GetServerTime = function() return now end
date, time = os.date, os.time
UnitName = function() return "Hordi" end
UnitFullName = function() return "Hordi", "" end
UnitLevel = function() return 20 end
local myClass = "PRIEST"
UnitClass = function() return "Klasse", myClass end
UnitFactionGroup = function() return "Horde" end
IsInGuild = function() return true end
GetZoneText = function() return "Orgrimmar" end
GetSubZoneText = function() return "Tal der Stärke" end
C_Map = {GetBestMapForUnit = function() return 1454 end,
    GetPlayerMapPosition = function() return {GetXY = function() return .5, .25 end} end}

-- Navi: Karte 1454 und 1411 auf Kontinent 1 (1 Kartenanteil = 1000 Yards), 1415 auf Kontinent 2
local CONT = {[1454] = 1, [1411] = 1, [1415] = 2}
local myDist = 500
local pointed = {}
local nav = {
    DistanceTo = function() return myDist end,
    DistanceBetween = function(_, a, ax, ay, b, bx, by)
        if CONT[a] ~= CONT[b] then return nil, "continent" end
        return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) * 1000
    end,
    PointTo = function(_, label, mapID, x, y) pointed[#pointed + 1] = {label, mapID, x, y} return true end,
}
local peers = {}
local guild = {LivePeers = function() return peers end}
local notes = {}
local ONE = {db = {}, modules = {nav = nav, guild = guild}}
function ONE:Print() end
function ONE:Notify(text) notes[#notes + 1] = text end
local featureOn = true
function ONE:FeatureOn() return featureOn end
_G.ProjectONE = ONE
local d = {}
for _, f in ipairs({"QuestData", "Catalog", "Model", "Share", "Trips"}) do assert(loadfile(root .. "/ONE_Dungeons/" .. f .. ".lua"))("ONE_Dungeons", d) end
d.Share.Tell = function() end
local Tr, S = d.Trips, d.Share

local start = now + 3600
local trip = Tr:Create("wc", start, Tr:HereMeet())
S:Flush(10)
-- Andere melden sich an
S:Receive(S.prefix, "TS|" .. trip.id .. "|yes|T|21|WARRIOR", "GUILD", "Thrall-Realm")
S:Receive(S.prefix, "TS|" .. trip.id .. "|yes|H|20|SHAMAN", "GUILD", "Rehgar")
S:Receive(S.prefix, "TS|" .. trip.id .. "|maybe|D|19|MAGE", "GUILD", "Jaina")

-- 1) Eine Stunde vorher: keine Erinnerung, keine Tafel
Tr:Tick()
assert(#notes == 0 and not Tr:BoardActive(trip))

-- 2) 10 Minuten vorher: genau eine Erinnerung, auch bei mehreren Takten
now = start - 600
Tr:Tick() Tr:Tick()
assert(#notes == 1 and notes[1]:find("10 Minuten") and notes[1]:find("Tal der Stärke"), notes[1])
assert(Tr:BoardActive(trip))

-- 3) Ankunftstafel: Thrall nah, Rehgar weit, Jaina anderer Kontinent; ich 500 Yards weg
peers = {
    {name = "Thrall-Realm", mapID = 1454, x = .51, y = .25},
    {name = "Rehgar", mapID = 1411, x = .5, y = .95},
    {name = "Jaina", mapID = 1415, x = .1, y = .1},
}
local board = Tr:Board(trip)
local by = {}
for _, e in ipairs(board) do by[e.name] = e end
assert(by.Thrall.state == "here", by.Thrall.state)
assert(by.Rehgar.state == "away" and math.floor(by.Rehgar.dist) == 700 and by.Rehgar.eta == 2, tostring(by.Rehgar.eta))
assert(by.Jaina.state == "continent")
assert(by.Hordi.state == "away" and by.Hordi.dist == 500)
assert(Tr:BoardText(by.Thrall) == "am Treffpunkt")
assert(Tr:BoardText(by.Rehgar) == "700 m · ca. 2 min", Tr:BoardText(by.Rehgar))
peers = {}
assert(Tr:BoardText(Tr:Board(trip)[1]) == "kein Standort")
-- Reihenfolge der Tafel = Reihenfolge der Anmeldeliste
local list = Tr:Signups(trip)
for i, e in ipairs(Tr:Board(trip)) do assert(e.name == list[i].name) end

-- 4) Hexer bekommt Beschwoerungs-Vorschlag (weit weg / anderer Kontinent), andere nicht
peers = {{name = "Rehgar", mapID = 1411, x = .5, y = .95}, {name = "Jaina", mapID = 1415, x = .1, y = .1},
    {name = "Thrall-Realm", mapID = 1454, x = .51, y = .25}}
assert(#Tr:SummonList(Tr:Board(trip)) == 0)
myClass = "WARLOCK"
local summon = Tr:SummonList(Tr:Board(trip))
table.sort(summon)
assert(#summon == 2 and summon[1] == "Jaina" and summon[2] == "Rehgar", table.concat(summon, ",")) -- sich selbst nie
myClass = "PRIEST"

-- 5) Start: Meldung + Navi zum Treffpunkt, nur einmal
now = start + 5
Tr:Tick() Tr:Tick()
assert(#notes == 2 and notes[2]:find("beginnt jetzt") and notes[2]:find("Navi"), notes[2])
assert(#pointed == 1 and pointed[1][2] == 1454 and pointed[1][3] == .5)

-- 6) Schon am Treffpunkt: kein Navi
myDist = 10
assert(Tr:StartNavi(trip) == false)

-- 7) Nicht angemeldet / zu spaet eingeloggt / Schalter aus: keine Meldung
local t2 = Tr:Create("rfc", now + 600, Tr:HereMeet())
Tr:SignUp(t2.id, "no")
now = now + 600 - 300
Tr:Tick()
assert(#notes == 2)
Tr:SignUp(t2.id, "yes")
featureOn = false
Tr:Tick()
assert(#notes == 2)
featureOn = true
now = t2.start + 20 * 60
t2.reminded = {soon = true}
Tr:Tick()
assert(#notes == 2 and t2.reminded.start, "zu spaet: keine Startmeldung")
print("OK: Gildenausflug Stufe 3")
