-- Offline-Test: fester Fahrplan (Nutzer 20.11.2026: zwei Fluege umsonst Ratchet <-> Crossroads, "ich moechte doch
-- einfach nur, dass man so schnell wie moeglich levelt"). Der Plan folgt dem letzten Plan; frisch nur bei echten
-- Aenderungen (Stufe, Abbruch, Gruppe).
local root = arg[1] or "src"
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [1] = {15, 10, 0, 0, false, {11}, {11}, {}, false, false, 900, 0, 0, 1},  -- "Crossroads"
        [2] = {15, 10, 0, 0, false, {12}, {12}, {}, false, false, 900, 0, 0, 1},  -- "Ratchet"
        [3] = {15, 10, 0, 0, false, {13}, {13}, {}, false, false, 900, 0, 0, 1},  -- neben Crossroads
        [4] = {15, 10, 0, 0, false, {14}, {14}, {}, false, false, 900, 0, 0, 1},  -- neu, direkt neben "Ratchet"
    },
    n = {
        [11] = {0, 1, 100, 100},
        [12] = {0, 1, 220, 100},
        [13] = {0, 1, 110, 100},
        [14] = {0, 1, 221, 100},
    },
}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local function World(m, x, y) return 1, x * 10000, y * 10000 end
local log, doneSet = {}, {}
local function Ctx(x, follow)
    return {me = {level = 15, class = 128, faction = "Horde", mapID = 1, x = x, y = .1},
        done = function(id) return doneSet[id] == true end, inLog = function(id) return log[id] ~= nil end,
        complete = function(id) return log[id] == "done" end, world = World, tempo = "all", speed = 7, follow = follow}
end
local function Follow(plan)
    local f = {}
    for i, k in ipairs(plan.orderKeys) do if not f[k] then f[k] = i end end
    return f
end
-- erster Plan in "Crossroads": Quest 4 noch unbekannt (Vorquest fehlt -> spaeter "neu")
doneSet[4] = true
local p1 = assert(P:Plan(Ctx(.1)))
assert(p1.orderKeys and #p1.orderKeys > 0, "Plan merkt sich die Reihenfolge")
local k1 = table.concat(p1.orderKeys, " ")
-- nach "Ratchet" geflogen, ohne etwas zu erledigen: der Fahrplan bleibt gleich
local p2 = assert(P:Plan(Ctx(.22, Follow(p1))))
-- (was hier bereit ist, wird vor dem Weggehen angenommen – sonst Rueckweg)
local function Without(keys, drop) local t = {} for _, k in ipairs(keys) do if k ~= drop then t[#t + 1] = k end end return table.concat(t, " ") end
-- (21.11.2026: auch spaetere alte Halte genau hier – hier die Abgabe – kommen gleich mit, statt spaeter herzukommen)
assert(p2.orderKeys[1] == "accept:2" and p2.orderKeys[2] == "turnin:2", "hier bereit: zuerst annehmen und abgeben " .. table.concat(p2.orderKeys, " "))
local function Without2(keys) local t = {} for _, k in ipairs(keys) do if k ~= "accept:2" and k ~= "turnin:2" then t[#t + 1] = k end end return table.concat(t, " ") end
assert(Without2(p2.orderKeys) == Without2(p1.orderKeys), "sonst alte Reihenfolge: " .. table.concat(p2.orderKeys, " ") .. " / " .. k1)
-- ohne Fahrplan haette der Ortswechsel die Reihenfolge umgeworfen
local free = assert(P:Plan(Ctx(.22)))
assert(table.concat(free.orderKeys, " ") ~= k1, "Gegenprobe: frisch geplant sortiert um")
-- ersten Halt erledigen: der Rest bleibt in alter Reihenfolge
local first = p1.orderKeys[1]
local id = tonumber(first:match("%d+"))
log[id] = "open"
local p3 = assert(P:Plan(Ctx(.1, Follow(p1))))
local rest = {}
for i = 2, #p1.orderKeys do rest[#rest + 1] = p1.orderKeys[i] end
assert(table.concat(p3.orderKeys, " ", 1, #rest) == table.concat(rest, " "), "Rest in alter Reihenfolge")
-- neue Quest (z. B. nach Stufenaufstieg frei): direkt nebenan mitnehmen, weit weg erst nach den alten Halten
-- (Spieltest 20.11.2026: nach Stufe 15 mitten auf 3000 m zurueck zu Ebru geschickt)
doneSet[4] = nil
local p4 = assert(P:Plan(Ctx(.221, Follow(p3))))
assert(p4.orderKeys[1] == "accept:4", "nebenan mitnehmen: " .. p4.orderKeys[1])
local far = assert(P:Plan(Ctx(.1, Follow(p3))))
local rank4
for i, k in ipairs(far.orderKeys) do if k == "accept:4" then rank4 = i end end
assert(far.orderKeys[1] ~= "accept:4" and (not rank4 or rank4 > #rest), "weit weg: erst nach den alten Halten")

-- ===== Guide: was ist eine echte Aenderung? =====
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
local ONE = {db = {}, modules = {}, ns = {}}
_G.ProjectONE = ONE
local L2 = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", L2)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", L2)
local G = L2.Guide
for _, ev in ipairs({"PLAYER_LEVEL_UP", "GROUP_ROSTER_UPDATE", "QUEST_REMOVED", "QUEST_ACCEPTED", "ZONE_CHANGED_NEW_AREA"}) do
    assert(G.IsFresh(ev, 8) == false, "Fahrplan bleibt bei " .. ev)
end
local f = G.FollowKeys({orderKeys = {"accept:1", "turnin:1", "accept:1"}})
assert(f["accept:1"] == 1 and f["turnin:1"] == 2, "Rang je Halt")
assert(G.FollowKeys(nil) == nil)
-- Fahrplan uebersteht /reload (gemerkt je Figur, hoechstens 12 h)
UnitName = function() return "Testheld" end
local now = 1000000
time = function() return now end
ONE.db.leveling = {follow = {Testheld = {keys = {"accept:5", "turnin:5"}, t = now - 60}}}
local sf = assert(G:SavedFollow(), "gemerkter Fahrplan")
assert(G.FollowKeys(sf)["turnin:5"] == 2)
now = now + 13 * 3600
assert(G:SavedFollow() == nil, "zu alt: frisch planen")
ONE.db.leveling.follow.Testheld = nil
assert(G:SavedFollow() == nil)

-- "nahe Ort" nur im selben Gebiet (Spieltest: Brachland-Ort "nahe Brackenwall")
do
    local T2 = {}
    local L3 = {}
    assert(loadfile(root .. "/ONE_Leveling/FlightMasters.lua"))("ONE_Leveling", L3)
    for _, f in ipairs(L3.FLIGHTMASTERS) do if f[1] == 55 then assert(f[7] == 1445, "Brackenwall liegt in den Duestermarschen") end
        if f[1] == 80 then assert(f[7] == 1413, "Ratchet im Brachland") end end
    L2.FLIGHTMASTERS = L3.FLIGHTMASTERS
    assert(loadfile(root .. "/ONE_Leveling/Tracker.lua"))("ONE_Leveling", L2)
    local Tr = L2.Tracker
    -- Welt = Weltkoordinaten direkt (Brachland-Punkt bei Burned-Out Remains: Brackenwall 839 yd, Camp Taurajo 1018 yd)
    ONE.ns.nav = {Travel = {World = function(m, x, y) return 1, x, y end, ShortName = function(n) return n:match("^([^,]+)") end},
        Flights = {Nodes = function() return {
            [55] = {continent = 1, x = -3147.4, y = -2842.2, name = "Brackenwall Village, Dustwallow Marsh"},
            [80] = {continent = 1, x = -894.6, y = -3773.0, name = "Ratchet, The Barrens"}} end}}
    assert(Tr.NearName(1413, -3300, -2050) == nil, "kein Ort aus einem anderen Gebiet: " .. tostring(Tr.NearName(1413, -3300, -2050)))
    assert(Tr.NearName(1413, -900, -3700) == "Ratchet", "Ort im selben Gebiet")
end
print("OK test_fahrplan_140")
