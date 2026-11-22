-- Offline-Test: fertige Abgaben im eigenen Gebiet zuerst, dann wegfliegen (Spieltest 20.11.2026: mit 2 offenen
-- Abgaben im Brachland nach Orgrimmar geschickt). Ausserdem: "alle Klassen ausser einer" ist keine Klassenquest.
local root = arg[1] or "src"
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [1] = {15, 10, 0, 0, false, {11}, {11}, {}, false, false, 900, 0, 0, 1},  -- fertig im Log, Abgabe 1300 yd weg
        [2] = {15, 10, 0, 0, false, {12}, {12}, {}, false, false, 900, 0, 0, 2},  -- Stadt: per Flug etwas schneller
        [3] = {15, 10, 0, 0, false, {13}, {13}, {}, false, false, 900, 0, 0, 2},
        [4] = {4, 2, 0, 1247, false, {14}, {14}, {}, false, false, 100, 0, 0, 1}, -- Stufe 4, alle ausser Hexenmeister
        [5] = {15, 15, 0, 128, false, {13}, {13}, {}, false, false, 900, 0, 0, 2}, -- echte Magier-Quest
    },
    n = {
        [11] = {0, 1, 500, 200},  -- Abgabe im Gebiet 1
        [12] = {0, 2, 500, 500},  -- Stadt (Gebiet 2), Flugpunkt daneben
        [13] = {0, 2, 520, 500},
        [14] = {0, 1, 620, 610},
    },
}
GuildTripLeveling = {r = {}, i = {}, dz = {}, sp = {[5] = 1234}}  -- Quest 5 bringt einen Zauber bei
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
-- Gebiet 1 = 0..3000 yd, Gebiet 2 = 5000..6000 yd (gleicher Kontinent)
local function World(m, x, y)
    if m == 1 then return 1, x * 3000, y * 3000 end
    return 1, 5000 + x * 1000, y * 1000
end
local ctx = {
    me = {level = 15, class = 128, faction = "Horde", mapID = 1, x = .2, y = .6},
    done = function() return false end,
    inLog = function(id) return id == 1 end,
    complete = function(id) return id == 1 end,
    world = World, tempo = "all", speed = 7,
    -- Flugpunkt beim Spieler und in der Stadt
    flights = {{1, 600, 1800, name = "hier"}, {1, 5500, 500, name = "Stadt"}},
}
local function Order(plan)
    local t = {}
    for _, s in ipairs(plan.steps) do for _, a in ipairs(s.actions) do t[#t + 1] = a.kind:sub(1, 1) .. a.id end end
    return table.concat(t, " ")
end
-- Klassenquest-Erkennung
assert(P.IsClassQuest(GuildTripQuestDB.q[5]) and not P.IsClassQuest(GuildTripQuestDB.q[4]), "1247 ist keine Klassenquest")
for _, improve in ipairs({false, true}) do
    ctx.improve = improve
    local plan = assert(P:Plan(ctx))
    local o = Order(plan)
    -- ohne die Regel: Flug zur Stadt (ca. 4 min) knapp vor 1300 yd Fussweg zur Abgabe
    assert(o:sub(1, 2) == "t1", "erst die fertige Abgabe im Gebiet, dann fliegen: " .. o)
    assert(plan.chosen[4] == nil, "Stufe-4-Quest ist grau, keine Klassenquest: " .. tostring(plan.chosen[4]))
    assert(plan.chosen[5] == "class", "echte Klassenquest (mit Zauber) bleibt")
end
-- Klassenquest ohne Zauber und ohne Verbesserung: zaehlt wie jede andere Quest (Nutzer 21.11.2026)
GuildTripLeveling.sp = {}
do
    local plan = assert(P:Plan(ctx))
    assert(plan.chosen[5] ~= "class" and plan.info[5].class == false, "ohne Zauber kein Klassen-Vorrang: " .. tostring(plan.chosen[5]))
end
GuildTripLeveling.sp = {[5] = 1234}
-- weit weg (mehr als P.ZONE_FINISH Minuten): dann zaehlt wieder der echte Weg
GuildTripQuestDB.n[11] = {0, 1, 950, 50}
ctx.improve = false
local far = Order(assert(P:Plan(ctx)))
assert(far:sub(1, 2) ~= "t1", "sehr weite Abgabe haelt das Gebiet nicht: " .. far)
print("OK test_zonefinish_134")
