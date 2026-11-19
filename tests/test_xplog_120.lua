-- Offline-Test 0.7.2: echte Quest-EP mitschreiben (XPLog) – Grund-EP zurueckrechnen, volle Werte behalten
local root = arg[1] or "src"
local level = 12
UnitLevel = function() return level end
local handler
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function(_, _, fn) handler = fn end} end
GuildTripQuestDB = {q = {[100] = {10, 8, 0, 0, false, {}, {}, {}, false, false, 600}, [200] = {12, 10, 0, 0, false, {}, {}, {}, false, false, 900}}}
local ONE = {db = {}}
function ONE:RegisterSlash(n, fn) self.slash = {n, fn} end
local printed = {}
function ONE:Print(t) printed[#printed + 1] = t end
_G.ProjectONE = ONE
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/XPLog.lua"))("ONE_Leveling", lev)
local X = lev.XPLog
X:Initialize()
-- 1) volle EP (Abstand <= 5): Grund-EP = erhaltene EP
handler(nil, "QUEST_TURNED_IN", 100, 650)
assert(ONE.db.questXP[100].b == 650 and ONE.db.questXP[100].p == 12, "Grund-EP gemessen")
-- 2) zu hohe Stufe (Abstand 8 -> 40 %): zurueckgerechnet, ersetzt aber keinen vollen Wert
level = 18
handler(nil, "QUEST_TURNED_IN", 100, 300)
assert(ONE.db.questXP[100].b == 650 and ONE.db.questXP[100].n == 2, "voller Wert bleibt")
level = 20
handler(nil, "QUEST_TURNED_IN", 200, 480)
assert(ONE.db.questXP[200].b == 1200, "aus 40 % zurueckgerechnet: " .. ONE.db.questXP[200].b)
-- 3) ohne EP oder auf 60: nichts
level = 60
handler(nil, "QUEST_TURNED_IN", 300, 0)
handler(nil, "QUEST_TURNED_IN", 301, 500)
assert(not ONE.db.questXP[300] and not ONE.db.questXP[301])
-- 4) fuer den Planer + Zusammenfassung
local m = X:Measured()
assert(m[100] == 650 and m[200] == 1200)
local n, off, list = X:Summary()
assert(n == 2 and off == 1 and list[1].id == 200, "200 weicht ab (1200 statt 900), 100 nicht (650 statt 600 < 10 %)")
assert(ONE.slash[1] == "epdaten")
ONE.slash[2]()
assert(printed[1]:find("2 Quests") and printed[1]:find("1 anders"), printed[1])
print("OK test_xplog_120")
