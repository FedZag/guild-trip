-- Offline-Test: Arbeitsgebiet (Nutzer 20.11.2026: "wollen wir nicht Brachland erst fertig machen, solange dort
-- noch nuetzliche Quests sind?"). Ein kurzer Abstecher in die Stadt plant nicht alles um.
local root = arg[1] or "src"
local BARRENS, ORG = 1413, 1454
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [1] = {15, 10, 0, 0, false, {11}, {11}, {}, false, false, 900, 0, 0, BARRENS},
        [2] = {15, 10, 0, 0, false, {12}, {12}, {}, false, false, 900, 0, 0, BARRENS},
        [3] = {15, 10, 0, 0, false, {13}, {13}, {}, false, false, 900, 0, 0, ORG},  -- Stadt, direkt nebenan
        [4] = {15, 10, 0, 0, false, {14}, {14}, {}, false, false, 900, 0, 0, ORG},  -- Stadt, weiter weg
        [5] = {15, 10, 0, 0, false, {15}, {15}, {}, false, false, 900, 0, 0, ORG},
    },
    n = {
        [11] = {0, BARRENS, 500, 500},
        [12] = {0, BARRENS, 520, 500},
        [13] = {0, ORG, 105, 100},   -- 50 yd vom Spieler
        [14] = {0, ORG, 900, 100},   -- 800 yd weiter (mehr als P.AWAY_NEAR)
        [15] = {0, ORG, 920, 100},
    },
}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
-- Stadt 0..1000 yd, Brachland 3000..4000 yd (gleicher Kontinent, ca. 6 min zu Fuss)
local function World(m, x, y)
    if m == ORG then return 1, x * 1000, y * 1000 end
    return 1, 3000 + x * 1000, y * 1000
end
local function Ctx(work)
    return {
        me = {level = 15, class = 128, faction = "Horde", mapID = ORG, x = .1, y = .1},
        done = function() return false end, inLog = function() return false end, complete = function() return false end,
        world = World, tempo = "all", speed = 7, workZone = work,
    }
end
local function Order(plan)
    local t = {}
    for _, s in ipairs(plan.steps) do for _, a in ipairs(s.actions) do t[#t + 1] = a.kind:sub(1, 1) .. a.id end end
    return table.concat(t, " ")
end
-- Schleifen um Stuetzpunkte (21.11.2026): was hier in der Stadt lohnt, gleich jetzt (sonst kaeme man extra wieder
-- her), dann ins Brachland – kein Hin und Her Stadt -> Brachland -> Stadt
for _, work in ipairs({BARRENS, false}) do
    local plan = assert(P:Plan(Ctx(work or nil)))
    local o = Order(plan)
    assert(o:find("^a3 t3"), "Nebenan zuerst: " .. o)
    local lastCity, firstBarrens = 0, nil
    local k = 0
    for tok in o:gmatch("%S+") do
        k = k + 1
        local id = tonumber(tok:sub(2))
        if id >= 3 then lastCity = k elseif not firstBarrens then firstBarrens = k end
    end
    assert(firstBarrens and lastCity < firstBarrens, "kein Hin und Her: " .. o)
    assert(plan.workZone == BARRENS, "Arbeitsgebiet = erstes Gebiet ausserhalb der Stadt")
end
-- Brachland leer (alles erledigt): Arbeitsgebiet faellt weg, Stadt wie bisher
local doneB = Ctx(BARRENS)
doneB.done = function(id) return id == 1 or id == 2 end
plan = assert(P:Plan(doneB))
assert(Order(plan):find("^a3") and plan.workZone == nil, "nichts mehr im Brachland: " .. Order(plan))
-- im Brachland stehend ohne gemerktes Arbeitsgebiet: Brachland wird es
local inB = Ctx(nil)
inB.me.mapID, inB.me.x, inB.me.y = BARRENS, .5, .5
assert(assert(P:Plan(inB)).workZone == BARRENS)
print("OK test_workzone_138")
