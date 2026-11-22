-- Offline-Test: Ziele einer Quest in mehreren Gebieten (Routen-Bau 22.11.2026, Spieltest "Chens leeres Faesschen":
-- Loewen/Ebenenschreiter im Norden, Donnerechsen im Sueden). Die Route hat je Teil einen Schritt "o5.1", "o5.2" mit
-- p = Ziel-Knoten. Im Spiel gilt der erste Teil mit offenen Zielen – keine neue Regel, die Route steht fest.
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
local ONE = {db = {}, modules = {}, ns = {}}
_G.ProjectONE = ONE
GuildTripQuestDB = {
    q = {
        [5] = {10, 8, 0, 0, false, {11}, {11}, {21, 22, 25}, false, false, 900, 0, 0, 1},
        [7] = {10, 8, 0, 0, false, {11}, {11}, {28}, false, false, 900, 0, 0, 1},
    },
    n = {
        [11] = {0, 1, 100, 500},
        [21] = {0, 1, 120, 520}, [22] = {0, 1, 130, 530},   -- Teil 1: beim Geber
        [25] = {0, 1, 100, 100}, [28] = {0, 1, 120, 120},   -- Teil 2 und Quest 7: im Norden
    },
    obj = {[5] = {i = {{21}, {22}, {25}}}},
}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local nav = {}
ONE.ns.nav = nav
assert(loadfile(root .. "/ONE_Nav/MobInfo.lua"))("ONE_Nav", nav)
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
local P, G, M = lev.Planner, lev.Guide, nav.MobInfo
local function World(m, x, y) return 1, x * 10000, y * 10000 end
local route = {
    {"a5 a7", n = 11, l = 10}, {"o5.1", n = 21, l = 10, p = {21, 22}}, {"o7", n = 28, l = 10},
    {"o5.2", n = 25, l = 10, p = {25}}, {"t7", n = 11, l = 10}, {"t5", n = 11, l = 10},
}
local objectives = {}
local log = {}
local inLog = function(id) return log[id] ~= nil end
local open = function(id) return M.OpenTargets(GuildTripQuestDB, id, objectives[id]) end

-- 1) Fahrplan: erster Teil mit offenen Zielen
local f, nodes = G.RouteFollow(route, 10, inLog, open)
assert(f["obj:5"] == 3 and nodes[5][1] == 21, "nicht im Log: erster Teil")
assert(f["obj:7"] == 4 and f["turnin:5"] == 7, "andere Schritte unveraendert")
log[5] = "open"
objectives[5] = {{type = "item", finished = false}, {type = "item", finished = false}, {type = "item", finished = false}}
f, nodes = G.RouteFollow(route, 10, inLog, open)
assert(f["obj:5"] == 3, "nichts erledigt: erster Teil")
objectives[5] = {{type = "item", finished = true}, {type = "item", finished = false}, {type = "item", finished = false}}
f = G.RouteFollow(route, 10, inLog, open)
assert(f["obj:5"] == 3, "Teil 1 noch nicht fertig (Nieren offen): bleibt bei Teil 1")
objectives[5] = {{type = "item", finished = true}, {type = "item", finished = true}, {type = "item", finished = false}}
f, nodes = G.RouteFollow(route, 10, inLog, open)
assert(f["obj:5"] == 5 and nodes[5][1] == 25 and #nodes[5] == 1, "Teil 1 fertig: Teil 2 im Norden")
-- Route ohne Teile: wie bisher
local f0 = G.RouteFollow({{"a5", l = 10}, {"o5", l = 10}, {"t5", l = 10}}, 10, inLog, open)
assert(f0["obj:5"] == 2, "Route ohne Teile: wie bisher")

-- 2) Planer: der Ziel-Schritt liegt im geltenden Teil und kommt an seiner Stelle der Route
local function Plan()
    local c = {me = {level = 10, xp = 0, xpMax = 10000, class = 128, race = 16, faction = "Horde", mapID = 1, x = .1, y = .5},
        done = function() return false end, inLog = inLog, complete = function() return false end, world = World,
        tempo = "need", speed = 7, route = true, flow = true, targets = open}
    c.follow, c.objNodes = G.RouteFollow(route, 10, inLog, open)
    return assert(P:Plan(c))
end
local function Find(plan, id)
    for i, s in ipairs(plan.steps) do
        for _, a in ipairs(s.actions or {}) do if a.kind == "obj" and a.id == id then return s, i end end
    end
end
log[7] = "open"
objectives[7] = {{type = "monster", finished = false}}
objectives[5] = {{type = "item", finished = false}, {type = "item", finished = false}, {type = "item", finished = false}}
local plan = Plan()
local s = assert(Find(plan, 5))
assert(#s.area == 2 and s.y > .4, "Teil 1: nur Loewen/Schreiter beim Geber (" .. #s.area .. ")")
objectives[5] = {{type = "item", finished = true}, {type = "item", finished = true}, {type = "item", finished = false}}
plan = Plan()
local s5, i5 = Find(plan, 5)
local _, i7 = Find(plan, 7)
assert(s5 and #s5.area == 1 and s5.y < .2, "Teil 2: Donnerechsen im Norden")
local keys = table.concat(plan.orderKeys, " ")
assert(keys:find("obj:7.-obj:5.-turnin:7"), "Reihenfolge der Route: o7, o5.2, t7: " .. keys)
assert(i7 and i5 and i7 <= i5, "erst Quest 7, dann die Echsen")
print("OK test_zielteile_158")
