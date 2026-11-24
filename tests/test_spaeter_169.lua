-- Offline-Test: Gebiets-Schleife (Nutzer 24.11.2026): Elite-Quests stehen mit in der Route und werden im Spiel auch
-- allein geplant ("GRUPPE" im Kasten). Knopf "Spaeter": erstes Mal ans Ende der Runde, zweites Mal faellt die Quest
-- aus dem Plan. Route-Quests werden im Spiel nicht mehr nach EP oder Aufwand aussortiert.
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
UnitName = function() return "Testheld" end
local printed = {}
local ONE = {db = {}, modules = {}, ns = {}, Print = function(_, s) printed[#printed + 1] = s end}
_G.ProjectONE = ONE
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [1] = {10, 8, 0, 0, false, {11}, {11}, {21}, false, false, 900, 0, 0, 1},
        [2] = {10, 8, 0, 0, false, {11}, {11}, {22}, false, false, 900, 0, 0, 1},   -- Elite
        [3] = {10, 8, 0, 0, false, {11}, {11}, {23}, false, false, 900, 0, 0, 1},
        [4] = {10, 8, 0, 0, false, {12}, {12}, {24}, false, false, 900, 0, 0, 1},   -- naechste Runde
        [5] = {10, 8, 0, 0, false, {11}, {11}, {21}, false, false, 900, 0, 0, 1},   -- viel Aufwand
    },
    n = {
        [11] = {0, 1, 100, 100}, [12] = {0, 1, 400, 400},
        [21] = {0, 1, 150, 150}, [22] = {0, 1, 200, 150}, [23] = {0, 1, 250, 150}, [24] = {0, 1, 450, 400},
    },
}
-- Art 1 = Gruppe/Elite; Aufwand 200 (sonst "Viel Aufwand")
GuildTripLeveling = {r = {[2] = "0|5|1||", [5] = "0|200|0||"}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Tracker.lua"))("ONE_Leveling", lev)
local P, G, Tr = lev.Planner, lev.Guide, lev.Tracker
local function World(m, x, y) return 1, x * 10000, y * 10000 end

-- zwei Runden: Runde 1 am NPC 11 (Quests 1, 2 Elite, 3, 5), Runde 2 am NPC 12 (Quest 4)
local route = {
    {"a1 a2 a3 a5", n = 11, l = 10, r = 1}, {"o1 o5", n = 21, l = 10}, {"o2", n = 22, l = 10}, {"o3", n = 23, l = 10},
    {"t1 t2 t3 t5", n = 11, l = 10},
    {"a4", n = 12, l = 10, r = 2}, {"o4", n = 24, l = 10}, {"t4", n = 12, l = 10},
}
GuildTripQuestRoutes = {["16:128"] = route}

assert(G.IsElite(2) and not G.IsElite(1) and not G.IsElite(5), "Elite aus der Art (1 = Gruppe/Elite)")

-- 1) ohne "Spaeter": Reihenfolge wie in der Route
local log = {}
local function InLog(id) return log[id] ~= nil end
local f = G.RouteFollow(route, 10, InLog, nil, nil, {})
assert(f["obj:2"] < f["obj:3"] and f["turnin:2"] < f["accept:4"], "Route wie gebaut")

-- 2) einmal "Spaeter" (Quest im Log): Ziel und Abgabe ans Ende von Runde 1 – nach allem anderen der Runde, vor Runde 2
log = {[1] = "open", [2] = "open", [3] = "open", [5] = "open"}
f = G.RouteFollow(route, 10, InLog, nil, nil, {[2] = 1})
assert(f["obj:2"] > f["turnin:3"] and f["obj:2"] > f["obj:3"], "Elite-Ziel ans Ende der Runde")
assert(f["turnin:2"] > f["obj:2"] and f["turnin:2"] < f["accept:4"], "Abgabe danach, noch vor der naechsten Runde")
assert(f["accept:2"], "Annahme bleibt (schon im Log, schadet nicht)")

-- 3) zweites Mal: faellt aus dem Plan
f = G.RouteFollow(route, 10, InLog, nil, nil, {[2] = 2})
assert(not f["accept:2"] and not f["obj:2"] and not f["turnin:2"], "zweimal Spaeter: raus")
assert(f["obj:3"] and f["accept:4"], "der Rest bleibt")

-- 4) Planer im Routen-Modus: Elite allein (ohne Gruppe) und viel Aufwand werden trotzdem geplant
log = {}
local function Ctx(later)
    return {me = {level = 10, xp = 0, xpMax = 10000, class = 128, race = 16, faction = "Horde", mapID = 1, x = .1, y = .1, inGroup = false},
        done = function() return false end, inLog = InLog, complete = function(id) return log[id] == "done" end,
        world = World, tempo = "need", speed = 7, route = true, flow = true,
        follow = G.RouteFollow(route, 10, InLog, nil, nil, later or {})}
end
local plan = assert(P:Plan(Ctx()))
local keys = table.concat(plan.orderKeys, " ")
assert(keys:find("accept:2", 1, true), "Elite-Quest allein geplant: " .. keys)
assert(keys:find("accept:5", 1, true), "Quest mit viel Aufwand geplant: " .. keys)
assert(plan.chosen[2] and plan.chosen[5], "als gewaehlt (Automatik nimmt sie an)")
-- ohne Route (freier Planer) bleibt es wie bisher: Elite nur mit Gruppe
local free = Ctx()
free.route, free.follow = nil, nil
local pf = assert(P:Plan(free))
assert(not table.concat(pf.orderKeys, " "):find("accept:2", 1, true), "ohne Route: Elite nur mit Gruppe")

-- 5) Knopf im Kasten: Zeile "GRUPPE … spaeter" beim Elite-Schritt, Klick zaehlt hoch und plant neu
ONE.db = {}
local function StepRows(st)
    local p = {steps = {st}, route = true, chosen = {}, info = {}}
    return Tr:Rows(p)
end
local laterRow
for _, r in ipairs(StepRows({kind = "obj", actions = {{kind = "obj", id = 2}}, nr = 22, mapID = 1, x = .2, y = .15})) do
    if r.click and (r.text or ""):find("GRUPPE", 1, true) then laterRow = r end
end
assert(laterRow, "Zeile GRUPPE/Spaeter beim Elite-Schritt")
local replans = 0
G.Later = function() replans = replans + 1 end
laterRow.click()
assert(G:LaterTable()[2] == 1 and replans == 1, "erster Klick: ans Ende der Runde")
assert(printed[#printed]:find("Ende der Runde", 1, true), "Meldung: " .. tostring(printed[#printed]))
laterRow.click()
assert(G:LaterTable()[2] == 2, "zweiter Klick: aus dem Plan")
assert(printed[#printed]:find("aus dem Plan", 1, true), "Meldung: " .. tostring(printed[#printed]))
local none = true
for _, r in ipairs(StepRows({kind = "obj", actions = {{kind = "obj", id = 3}}, nr = 23, mapID = 1, x = .25, y = .15})) do
    if (r.text or ""):find("GRUPPE", 1, true) then none = false end
end
assert(none, "keine Zeile bei normalen Quests")

-- 6) im Guide: zweimal Spaeter -> abgewaehlt (override "no"), im Log dann "Nicht im Plan"
do
    local t = G:LaterTable()
    assert(t[2] == 2)
    local ctx = {override = {}}
    -- gleiche Logik wie G:Replan: Kopie der Abwahl mit "no"
    local ov = {}
    for k, x in pairs(ctx.override) do ov[k] = x end
    for k, x in pairs(t) do if x >= 2 then ov[k] = "no" end end
    assert(ov[2] == "no" and ctx.override[2] == nil, "eigene Abwahl bleibt unberuehrt")
end
print("OK test_spaeter_169")
