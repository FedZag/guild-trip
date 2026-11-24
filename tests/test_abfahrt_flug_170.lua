-- Offline-Test (Spieltest 24.11.2026, Brachland -> Unterstadt): "jetzt muesste ich nach Orgrimmar laufen um mit dem
-- Zeppelin nach UC zu fliegen und das obwohl ich easy den Flug von Crossroads nach OG nehmen koennte".
-- 1) P.Travel zu einem anderen Kontinent: Weg zur Abfahrt mit Flug, wenn der lohnt – erster Schritt ist der Flug.
-- 2) G.RouteReady: fertige Quest im Log, deren Abgabe im selben Gebiet erst in einer spaeteren Runde liegt, wird
--    vor dem Verlassen des Gebiets abgegeben (ans Ende der laufenden Runde).
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
_G.ProjectONE = {db = {}, modules = {}, ns = {}}
GuildTripQuestDB = {q = {}, n = {}}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
local P, G = lev.Planner, lev.Guide

-- Welt-Yards wie Forever: Regthar (westlich vom Wegekreuz), Flugpunkte Wegekreuz/Orgrimmar, Zeppelin vor Orgrimmar
local regthar = {1, -275, -2280}
local crossroads = {1, -441.8, -2596.1, name = "Crossroads"}
local org = {1, 1677.6, -4315.7, name = "Orgrimmar"}
local zep = {1, 1340, -4640, from = 1, to = 0, name = "Zeppelin ab Orgrimmar nach Unterstadt", arrive = {0, 2066, 288}}
local silverpine = {0, 900, 1000}
local net = {speed = 7, flights = {crossroads, org}, departures = {zep}}
local m, via = P.Travel(regthar, silverpine, net)
assert(via and via.kind == "flight", "Weg zum Zeppelin soll mit Flug beginnen, war " .. tostring(via and via.kind))
assert(via.from == crossroads and via.to == org, "Flug Wegekreuz -> Orgrimmar erwartet")
assert(via.boat and via.boat.kind == "boat" and via.boat.dep == zep, "danach der Zeppelin")
local walkOnly = P.Travel(regthar, silverpine, {speed = 7, flights = {}, departures = {zep}})
assert(m < walkOnly, ("mit Flug schneller als zu Fuss (%.1f < %.1f)"):format(m, walkOnly))
-- direkt vor Orgrimmar: kein Flug, zu Fuss zum Zeppelin
local _, v2 = P.Travel({1, 1300, -4500}, silverpine, net)
assert(v2 and v2.kind == "boat", "neben dem Zeppelin kein Flug")

-- Route: Runde 1 Brachland (Quest 10 laeuft, 11 fertig – Abgabe erst in Runde 3), Runde 2 Silberwald, Runde 3 Brachland
local route = {
    {"a10 a11", n = 1, l = 17, z = 1413, r = 1},
    {"o10", n = 2, l = 17, z = 1413},
    {"t10", n = 1, l = 17, z = 1413},
    {"a20", n = 5, l = 17, z = 1421, r = 2},
    {"o20", n = 6, l = 17, z = 1421},
    {"t20", n = 5, l = 18, z = 1421},
    {"o11", n = 3, l = 19, z = 1413, r = 3},
    {"t11", n = 4, l = 19, z = 1413},
}
local log = {[10] = "open", [11] = "done"}
local inLog = function(id) return log[id] ~= nil end
local done = function() return false end
local complete = function(id) return log[id] == "done" end
local f = G.RouteFollow(route, 17, inLog, nil, done, nil, complete)
assert(f["turnin:11"] > f["turnin:10"] and f["turnin:11"] < f["accept:20"],
    ("fertige Quest 11 vor dem Silberwald abgeben (t11 %.3f, t10 %s, a20 %s)"):format(f["turnin:11"], f["turnin:10"], f["accept:20"]))
-- ohne "fertig": bleibt in Runde 3
local f2 = G.RouteFollow(route, 17, inLog, nil, done, nil, function() return false end)
assert(f2["turnin:11"] > f2["turnin:20"], "unfertige Quest bleibt in ihrer Runde")
-- Abgabe in anderem Gebiet (Silberwald-Quest fertig, man ist im Brachland): nicht vorziehen
log = {[10] = "open", [20] = "done"}
local f3 = G.RouteFollow(route, 17, inLog, nil, done, nil, complete)
assert(f3["turnin:20"] > f3["turnin:10"] and f3["turnin:20"] == f2["turnin:20"], "Abgabe in anderem Gebiet bleibt")
-- 3) Schon in der spaeteren Runde (Spieltest 24.11.2026: Brachland-Quests der naechsten Runde im Log, Route wollte erst
--    kurz ins Steinkrallengebirge): steht man in diesem Gebiet, erst diese Runde fertig, die fruehere Runde danach
local route2 = {
    {"a10", n = 1, l = 17, z = 1413, r = 1},
    {"t10", n = 1, l = 17, z = 1413},
    {"a20", n = 5, l = 17, z = 1442, r = 2},
    {"o20", n = 6, l = 17, z = 1442},
    {"t20", n = 5, l = 18, z = 1442},
    {"a30 a31", n = 3, l = 18, z = 1413, r = 3},
    {"o30", n = 4, l = 19, z = 1413},
    {"t30", n = 3, l = 20, z = 1413},
    {"o31", n = 4, l = 19, z = 1413},
    {"t31", n = 3, l = 20, z = 1413},
    {"a40", n = 7, l = 20, z = 1442, r = 4},
}
log = {[30] = "open"}
local done10 = function(id) return id == 10 end
local g = G.RouteFollow(route2, 19, inLog, nil, done10, nil, complete, 1413)
assert(g["accept:31"] < g["accept:20"] and g["turnin:30"] < g["accept:20"], "erst die Brachland-Runde fertig")
assert(g["accept:20"] < g["obj:20"] and g["obj:20"] < g["turnin:20"] and g["turnin:20"] < g["accept:40"],
    "fruehere Runde danach in ihrer Reihenfolge, vor der naechsten Runde")
-- im anderen Gebiet: Reihenfolge der Route bleibt
local g2 = G.RouteFollow(route2, 19, inLog, nil, done10, nil, complete, 1442)
assert(g2["accept:20"] < g2["accept:31"], "im Steinkrallengebirge bleibt die Route")
-- nichts aus der spaeteren Runde im Log: Route bleibt
log = {}
local g3 = G.RouteFollow(route2, 19, inLog, nil, done10, nil, complete, 1413)
assert(g3["accept:20"] < g3["accept:30"], "ohne Quests der spaeteren Runde bleibt die Route")
print("OK abfahrt_flug")
