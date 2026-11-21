-- Offline-Test: Sammelzeit je Quest mitmessen (Spieltest 19.11.2026: "an die 50 Zentauren fuer 15 Armschienen")
local root = arg[1] or "src"
local ONE = {db = {}}
_G.ProjectONE = ONE
local lev = {}
UnitFullName = function() return "Hordi", "Realm" end
assert(loadfile(root .. "/ONE_Leveling/WorkLog.lua"))("ONE_Leveling", lev)
local W = lev.WorkLog

-- Fortschritt aus den Zielen
assert(select(2, W.Progress({{numFulfilled = 3, numRequired = 15}, {numFulfilled = 9, numRequired = 8}})) == 23)
assert(W.Progress({{numFulfilled = 3, numRequired = 15}, {numFulfilled = 9, numRequired = 8}}) == 11)

local here = {1, 1000, 1000}
local t = 0
local function Look(have, other, pos) return W:Observe({{id = 855, have = have, need = 15}, {id = 7, have = other or 0, need = 4}}, t, pos or here) end
-- Annahme im Lager, Hinweg 900 yd: erster Fortschritt zaehlt nicht (weit gelaufen)
Look(0)
t = t + 300
Look(1, 0, {1, 1900, 1000})
here = {1, 1900, 1000}
-- dann 14 Armschienen je 4 min (Pech beim Droppen), ein Abschnitt mit Pause (20 min) zaehlt nicht
for i = 2, 15 do
    t = t + (i == 8 and 1200 or 240)
    local saved = Look(i)
    if i < 15 then assert(#saved == 0) end
end
local m = ONE.db.questWork[855]
assert(m and m.n == 1, "gemessen")
-- 13 gezaehlte Abschnitte a 4 min -> hochgerechnet auf 15 = 60 min
assert(math.abs(m.m - 60) < .2, "Minuten: " .. tostring(m.m))
assert(W:Measured()[855] == m.m)
-- laufende Messung ist weg
assert(W:Running().q[855] == nil)

-- ein Kill bringt zwei Quests weiter: Zeit wird geteilt
ONE.db.questWork = {}
W:Running().q, W:Running().last = {}, nil
t = 0
local function Two(n) W:Observe({{id = 1, have = n, need = 3}, {id = 2, have = n, need = 3}}, t, here) end
Two(0) t = 30 Two(1) t = 90 Two(2) t = 150 Two(3)
-- 2 gezaehlte Abschnitte a 60 s, je zur Haelfte -> 30 s je Ziel, 3 Ziele = 1,5 min
assert(math.abs(ONE.db.questWork[1].m - 1.5) < .01 and math.abs(ONE.db.questWork[2].m - 1.5) < .01,
    "geteilt: " .. tostring(ONE.db.questWork[1] and ONE.db.questWork[1].m))

-- Mittel ueber Messungen (Glueck/Pech gleicht sich aus)
W:Save(1, 2.5)
assert(ONE.db.questWork[1].n == 2 and math.abs(ONE.db.questWork[1].m - 2) < .01)

-- Planer: gemessene Minuten ersetzen die Schaetzung
GuildTripQuestDB = {q = {[855] = {14, 9, 0, 0, false, {11}, {11}, {12}, false, false, 1250, 0, 0, 1}},
    n = {[11] = {0, 1, 500, 500}, [12] = {0, 1, 520, 500}}}
GuildTripLeveling = {r = {[855] = "0|50|0||"}, i = {}, dz = {}}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local ctx = {me = {level = 14, class = 1, faction = "Horde", mapID = 1, x = .5, y = .5},
    world = function(mp, x, y) return 1, mp * 1000 + x * 1000, y * 1000 end, tempo = "all", speed = 7}
local est = P:Plan(ctx).info[855]
ctx.workMinutes = {[855] = 60}
local real = P:Plan(ctx).info[855]
assert(math.abs(est.work - 50) < .01 and math.abs(real.work - 60 * 60 / P.KILL_SEC) < .01, "Aufwand aus Messung")
assert(real.minutes > est.minutes)
print("OK test_worklog_132")
