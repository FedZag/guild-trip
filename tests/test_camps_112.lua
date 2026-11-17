-- Offline-Test 0.7.0: Fundorte der Questgegner (Lager) + Farm-Runde.
local root = arg[1] or "src"
GuildTripQuestDB = {
    q = {[1] = {5, 1, 0, 0, false, {}, {}, {500, 501, -9}, false, false, 0, 0, 0, 1}},
    m = {
        [500] = {5, 6, 3, 1429, 100, 100, 12, 1429, 800, 800, 6}, -- zwei Lager
        [501] = {5, 6, 3, 1429, 500, 500, 9},
    },
    mobNames = {[500] = "Wolf", [501] = "Bär"},
}
local log = {{id = 1, title = "Jagd", complete = false}, {id = 2, title = "Anderes", complete = false}}
local nav = {Quests = {Log = function() return log end}}
local printed, pointed = {}, {}
local ONE = {db = {}, modules = {}}
function ONE:Print(t) printed[#printed + 1] = t end
_G.ProjectONE = ONE
-- Spieler bei (0.5, 0.5) auf 1429; Entfernung in Yards = Kartenabstand * 1000
local px, py = .5, .5
ONE.modules.nav = {
    DistanceTo = function(_, m, x, y) return math.sqrt((x - px) ^ 2 + (y - py) ^ 2) * 1000 end,
    PointTo = function(_, label, m, x, y) pointed[#pointed + 1] = {label = label, x = x, y = y} return true end,
}
assert(loadfile(root .. "/ONE_Nav/Camps.lua"))("ONE_Nav", nav)
local C = nav.Camps

-- 1) Lager je Quest (Objekte < 0 zaehlen nicht), Punkte nur fuer offene Quests
local camps = C:ForQuest(1)
assert(#camps == 3 and camps[1].name == "Wolf" and camps[1].x == .1 and camps[1].count == 12 and camps[3].name == "Bär")
assert(#C:ForQuest(2) == 0 and #C:ForQuest(99) == 0)
assert(#C:Points(log) == 3)
log[1].complete = true
assert(#C:Points(log) == 0, "fertige Quest: keine Lager")
log[1].complete = false

-- 2) Runde: erst das naechste Lager (Baer in der Mitte), dann weiter beim Ankommen
assert(C:StartRound(log[1]))
assert(pointed[1].label == "Bär (1/3)" and pointed[1].x == .5, pointed[1].label)
C:Tick() -- schon da (Abstand 0) -> naechstes
assert(#pointed == 2 and pointed[2].label == "Wolf (2/3)", pointed[2].label)
local nextX = pointed[2].x
C:Tick() -- noch weit weg: nichts
assert(#pointed == 2)
px, py = nextX, nextX
C:Tick()
assert(#pointed == 3 and pointed[3].label == "Wolf (3/3)")
-- alle besucht -> von vorn
px, py = pointed[3].x, pointed[3].y
C:Tick()
assert(#pointed == 4 and C.round.visitedCount == 1, "Runde beginnt von vorn")
-- 3) Quest fertig -> Ende
log[1].complete = true
C:Tick()
assert(C.round == nil and printed[#printed]:find("fertig"))
-- 4) Abgeschaltet: keine Punkte
log[1].complete = false
ONE.FeatureOn = function(_, id) return id ~= "nav.camps" end
assert(#C:Points(log) == 0)
-- 5) Ohne Gegnerdaten: nichts, kein Fehler
ONE.FeatureOn = nil
GuildTripQuestDB.m = nil
assert(#C:ForQuest(1) == 0 and not C:StartRound(log[1]))
print("OK test_camps_112")
