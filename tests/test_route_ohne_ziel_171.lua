-- Offline-Test: Route mit Abgabe, aber ohne Ziel-Halt fuer eine Quest mit offenen Zielen (Route mit aelteren Daten
-- gebaut – Spieltest 24.11.2026 "Die Warsongberichte": Kasten nur "abgeben bei Kadrak", die Spaeher in Eschental
-- fehlten; die Abgabe wurde nie bereit, die Quest fiel aus dem Plan). Jetzt: Ziel und Abgabe werden wie bei einer
-- selbst angenommenen Quest eingereiht. Quests ohne Ziele (annehmen + abgeben am selben NPC) bleiben wie in der Route.
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
local ONE = {db = {}, modules = {}, ns = {}}
_G.ProjectONE = ONE
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [7] = {10, 8, 0, 0, false, {11}, {11}, {25}, false, false, 900, 0, 0, 1},   -- Ziel beim Spaeher (Knoten 25)
        [8] = {10, 8, 0, 0, false, {11}, {11}, {}, false, false, 300, 0, 0, 1},     -- ohne Ziele
        [9] = {10, 8, 0, 0, false, {12}, {12}, {26}, false, false, 900, 0, 0, 1},   -- normale Routen-Quest danach
        [10] = {10, 8, 0, 0, false, {11}, {11}, {27}, false, false, 2500, 0, 0, 1},  -- selbst angenommen, Ziel im Nachbargebiet
    },
    n = {
        [11] = {0, 1, 100, 500}, [12] = {0, 1, 400, 500},
        [25] = {0, 1, 160, 500}, [26] = {0, 2, 450, 500},  -- Ziel von 9 im Gebiet 2 (Route geht spaeter hin)
        [27] = {0, 2, 120, 520},                           -- Ziel von 10: gleich hinter der Grenze in Gebiet 2
    },
    obj = {[7] = {i = {{25}}}},
}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local nav = {}
ONE.ns.nav = nav
assert(loadfile(root .. "/ONE_Nav/MobInfo.lua"))("ONE_Nav", nav)
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local function World(m, x, y) return 1, x * 10000, y * 10000 end
-- alte Route: "a7 t7" am selben Halt, kein o7
local route = {{"a7 t7 a8 t8", n = 11, l = 10}, {"a9", n = 12, l = 10}, {"o9", n = 26, l = 10}, {"t9", n = 12, l = 10}}
local function Ctx(log)
    local inLog = function(id) return log[id] ~= nil end
    return {me = {level = 10, xp = 0, xpMax = 10000, class = 128, race = 16, faction = "Horde", mapID = 1, x = .01, y = .05},
        done = function() return false end, inLog = inLog,
        complete = function(id) return log[id] == "done" end, world = World, tempo = "need", speed = 7, route = true, flow = true,
        follow = lev.Guide.RouteFollow(route, 10, inLog)}
end
local function Pos(plan, kind, id)
    for i, s in ipairs(plan.steps) do
        for _, a in ipairs(s.actions or {}) do if a.kind == kind and a.id == id then return i end end
    end
end

-- 1) 7 im Log, Ziel offen: Ziel-Schritt kommt in den Plan, Abgabe danach
local plan = assert(P:Plan(Ctx({[7] = "open", [8] = "open"})))
local o7, t7 = Pos(plan, "obj", 7), Pos(plan, "turnin", 7)
assert(o7, "Route ohne Ziel-Halt: Ziel der Quest 7 muss in den Plan")
assert(t7 and t7 > o7, "Abgabe von 7 erst nach dem Ziel")
assert(plan.chosen[7], "Quest 7 bleibt gewaehlt")
-- 2) Quest ohne Ziele: Abgabe wie in der Route
assert(Pos(plan, "turnin", 8), "Quest ohne Ziele: Abgabe aus der Route bleibt")
-- 3) Ziel schon fertig: nur die Abgabe (aus der Route)
plan = assert(P:Plan(Ctx({[7] = "done"})))
assert(not Pos(plan, "obj", 7) and Pos(plan, "turnin", 7), "Ziel fertig: nur Abgabe")
-- 4) Ziel im anderen Gebiet (Spieltest 24.11.2026: Eschental mit Stufe 19 zu gefaehrlich): erst, wenn die Route
-- ohnehin dort ist – nicht sofort hinlaufen, obwohl es nah ist
plan = assert(P:Plan(Ctx({[10] = "open"})))
local o10, a9 = Pos(plan, "obj", 10), Pos(plan, "accept", 9)
assert(o10 and a9 and o10 > a9, "Ziel im anderen Gebiet erst beim Routen-Besuch dort (o10=" .. tostring(o10) .. ", a9=" .. tostring(a9) .. ")")
-- 5) Route geht nicht mehr in das Gebiet: Quest bleibt im Log, kein Ziel- und kein Abgabe-Schritt
route = {{"a7 t7 a8 t8", n = 11, l = 10}, {"a9", n = 12, l = 10}, {"t9", n = 12, l = 10}}
GuildTripQuestDB.q[9][8] = {}
plan = assert(P:Plan(Ctx({[10] = "open"})))
assert(not Pos(plan, "obj", 10) and not Pos(plan, "turnin", 10), "Gebiet ohne Routen-Besuch und ueber der Stufe: Quest wartet im Log")
print("OK test_route_ohne_ziel_171")
