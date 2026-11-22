-- Offline-Test: Ziel-Schritt nur fuer die NOCH OFFENEN Ziele einer Quest (Spieltest 22.11.2026, "Chens leeres
-- Faesschen" 821: Loewenhauer und Nieren fertig, Donnerechsen-Hoerner weiter noerdlich – der Guide schickte ins alte
-- Gebiet). Nutzer: "wenn gegner in einem gebiet fuer eine quest fertig sind und die selbe quest dich in ein anderes
-- gebiet schickt … sollte es der planer auch tun". Ohne Zuordnung oder ohne Fortschritt: wie bisher (alle Ziele).
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
        [5] = {10, 8, 0, 0, false, {11}, {11}, {21, 22, 25}, false, false, 900, 0, 0, 1},
        [6] = {10, 8, 0, 0, false, {11}, {11}, {26, 27}, false, false, 900, 0, 0, 1},  -- ohne Zuordnung
    },
    n = {
        [11] = {0, 1, 100, 500},
        [21] = {0, 1, 120, 520}, [22] = {0, 1, 130, 530},   -- Loewen, Nieren: gleich beim Geber
        [25] = {0, 1, 100, 100},                            -- Donnerechsen: weit im Norden
        [26] = {0, 1, 300, 500}, [27] = {0, 1, 300, 150},
    },
    -- Ziele je Art in Spielreihenfolge: Gegenstand 1 von 21, Gegenstand 2 von 22, Gegenstand 3 von 25
    obj = {[5] = {i = {{21}, {22}, {25}}}},
}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local nav = {}
ONE.ns.nav = nav
assert(loadfile(root .. "/ONE_Nav/MobInfo.lua"))("ONE_Nav", nav)
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local M = assert(nav.MobInfo and nav.MobInfo.OpenTargets and nav.MobInfo, "MobInfo.OpenTargets")
local function World(m, x, y) return 1, x * 10000, y * 10000 end
local route = {{"a5 a6", n = 11, l = 10}, {"o5", n = 21, l = 10}, {"t5", n = 11, l = 10}, {"o6", n = 26, l = 10}, {"t6", n = 11, l = 10}}

local objectives = {}
local function Ctx(log)
    return {me = {level = 10, xp = 0, xpMax = 10000, class = 128, race = 16, faction = "Horde", mapID = 1, x = .1, y = .5},
        done = function() return false end, inLog = function(id) return log[id] ~= nil end,
        complete = function() return false end, world = World, tempo = "need", speed = 7, route = true, flow = true,
        follow = lev.Guide.RouteFollow(route, 10, function(id) return log[id] ~= nil end),
        targets = function(id) return M.OpenTargets(GuildTripQuestDB, id, objectives[id]) end}
end
local function ObjStep(plan, id)
    for _, s in ipairs(plan.steps) do
        for _, a in ipairs(s.actions or {}) do if a.kind == "obj" and a.id == id then return s end end
    end
end
local function Far(s)  -- Zielgebiet zeigt in den Norden (Knoten 25: y = .1)
    for _, a in ipairs(s.area or {}) do if a[3] > 2000 then return false end end
    return s.y and s.y < .2
end

-- 1) nichts erledigt: wie bisher (alle Ziele, naechstes beim Geber)
objectives[5] = {{type = "item", finished = false}, {type = "item", finished = false}, {type = "item", finished = false}}
local s = assert(ObjStep(assert(P:Plan(Ctx({[5] = "open"}))), 5), "Ziel-Schritt fuer 5")
assert(not Far(s) and #s.area == 3, "nichts erledigt: alle drei Ziele, Schritt beim Geber")

-- 2) Loewen und Nieren fertig: nur noch die Donnerechsen im Norden – Schritt, Pfeil-Ziel und Gebiet dort
objectives[5] = {{type = "item", finished = true}, {type = "item", finished = true}, {type = "item", finished = false}}
local plan = assert(P:Plan(Ctx({[5] = "open"})))
s = assert(ObjStep(plan, 5), "Ziel-Schritt fuer 5 (Rest)")
assert(Far(s) and #s.area == 1, "nur offene Ziele: Schritt und Gebiet bei den Donnerechsen (y=" .. tostring(s.y) .. ")")

-- 3) ohne Zuordnung (keine Daten in obj): wie bisher, alle Ziele
objectives[6] = {{type = "monster", finished = true}, {type = "monster", finished = false}}
s = assert(ObjStep(assert(P:Plan(Ctx({[6] = "open"}))), 6), "Ziel-Schritt fuer 6")
assert(#s.area == 2, "ohne Zuordnung: alle Ziele der Quest")

-- 4) nicht im Log: alle Ziele (ctx.targets wird nicht gefragt)
local asked = false
local c = Ctx({})
c.targets = function() asked = true return {25} end
P:Plan(c)
assert(not asked, "nicht im Log: keine offenen Ziele abfragen")
-- 5) Questgegner-Zeichen (MobInfo.OpenTargets): ein offenes Ziel ohne Zuordnung (unbekannte Art, z. B. eine
-- zusaetzliche Zeile im Log) holt die Gegner schon erledigter Ziele NICHT zurueck (Spieltest 22.11.2026)
local Q = GuildTripQuestDB
local function Set(list) local t = {} for _, n in ipairs(list) do t[n] = true end return t end
local t = Set(M.OpenTargets(Q, 5, {{type = "item", finished = true}, {type = "item", finished = true},
    {type = "item", finished = false}, {type = "log", finished = false}}))
assert(t[25] and not t[21] and not t[22], "unbekanntes offenes Ziel: erledigte Gegner bleiben ohne Zeichen")
t = Set(M.OpenTargets(Q, 5, {{type = "item", finished = true}, {type = "item", finished = true}, {finished = false}}))
assert(t[25] and not t[21] and not t[22], "Ziel ohne Art: nur Gegner, die keinem erledigten Ziel gehoeren")
t = Set(M.OpenTargets(Q, 5, {{type = "item", finished = true}, {type = "item", finished = true}, {type = "item", finished = true}}))
assert(not next(t), "alles erledigt: keine Zeichen")
t = Set(M.OpenTargets(Q, 6, {{type = "monster", finished = true}, {type = "monster", finished = false}}))
assert(t[26] and t[27], "ohne Daten: alle Ziele wie bisher")
print("OK test_offeneziele_157")
