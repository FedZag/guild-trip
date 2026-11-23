-- Offline-Test 0.8.0: Quest-EP im Questlog (Gesamtpruefung 23.11.2026, Idee wie "Quest XP Tracker").
-- Wert vom Spiel zuerst, sonst gemessene Grund-EP, sonst Datenbank – mit Abzug nach Stufenabstand wie die Quest-Fuehrung.
local root = arg[1] or "src"
local ONE = {db = {}, Language = function() return "de" end}
ONE.T = function(t, ...) if select("#", ...) > 0 then return t:format(...) end return t end
_G.ProjectONE = ONE
local nav = {}
assert(loadfile(root .. "/ONE_Nav/QuestLevels.lua"))("ONE_Nav", nav)
local QL = nav.QuestLevels
local plvl = 20
UnitLevel = function() return plvl end
UnitXPMax = function() return 10000 end
GuildTripQuestDB = {q = {[100] = {18, nil, nil, nil, nil, nil, nil, nil, nil, nil, 1250}, [200] = {12, nil, nil, nil, nil, nil, nil, nil, nil, nil, 1000}}}
-- 1) Datenbank, volle EP bis 5 Stufen darunter
local xp, guess = QL.XP(100)
assert(xp == 1250 and guess == true, tostring(xp))
-- 2) Stufenabstand 8 -> 40 %
assert(QL.XP(200) == 400, tostring(QL.XP(200)))
-- 3) gemessene Grund-EP vor der Datenbank
ONE.db.questXP = {[100] = {b = 1500}}
assert(QL.XP(100) == 1500)
-- 4) Wert vom Spiel gewinnt (nicht geschaetzt)
GetQuestLogRewardXP = function(id) return id == 100 and 1337 or 0 end
xp, guess = QL.XP(100)
assert(xp == 1337 and guess == false)
assert(QL.XP(200) == 400, "Spiel liefert 0 -> Schaetzung")
-- 5) Text: Tausenderpunkt, ~ bei Schaetzung, Anteil an der Stufe
assert(QL.XPText(100) == "1.337 EP", QL.XPText(100))
assert(QL.XPText(200, true) == "~400 EP (4 % der Stufe)", QL.XPText(200, true))
-- 6) Stufe 60 / unbekannt: nichts
assert(QL.XP(999) == nil)
plvl = 60
assert(QL.XP(100) == nil and QL.XPText(100) == nil)
-- 7) gleiche Tabelle wie die Quest-Fuehrung (Planner.QuestXP)
local src = io.open(root .. "/ONE_Leveling/Planner.lua"):read("*a")
local body = src:match("(function P%.QuestXP%(base, qlvl, plvl%).-\nend)")
assert(body, "Planner.QuestXP gefunden")
local P = {}
assert(loadstring("local P = ... " .. body))(P)
for _, d in ipairs({0, 5, 6, 7, 8, 9, 10, 15}) do
    assert(P.QuestXP(1230, 30, 30 + d) == QL.QuestXP(1230, 30, 30 + d), "Abstand " .. d)
end
print("OK test_questxp_159")
