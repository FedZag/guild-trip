-- Offline-Test: Questtext im Tooltip des Kastens (Nutzer 25.11.2026: "beim drueberfahren den kompletten text").
-- Nur Titelzeilen, nur angenommene Quests, Text aus GetQuestLogQuestText(index).
local root = arg[1] or "src"
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
GetLocale = function() return "deDE" end
local ONE = {modules = {}, ns = {}, db = {}}
_G.ProjectONE = ONE
local lev = {}
for _, f in ipairs({"Planner", "Guide", "Tracker"}) do assert(loadfile(root .. "/ONE_Leveling/" .. f .. ".lua"))("ONE_Leveling", lev) end
local Tr, G = lev.Tracker, lev.Guide
assert(Tr.QuestText(100) == nil, "ohne Spiel-API kein Text")
local log = {[100] = 3, [200] = 5}
C_QuestLog = {GetLogIndexForQuestID = function(id) return log[id] end}
local asked = 0
GetQuestLogQuestText = function(i)
    asked = asked + 1
    if i == 3 then return "  Olgra hat Mankriks Frau getoetet.\n\nBringt mir ihre Schmuckstuecke.  ", "Bringt Mankrik Olgras Schmuckstuecke." end
    if i == 5 then return "", "" end
end
local d, o = Tr.QuestText(100)
assert(d == "Olgra hat Mankriks Frau getoetet.\n\nBringt mir ihre Schmuckstuecke.", "Beschreibung ohne Rand-Leerzeichen")
assert(o == "Bringt Mankrik Olgras Schmuckstuecke.", "Questziel")
Tr.QuestText(100)
assert(asked == 1, "Text wird gemerkt")
assert(Tr.QuestText(200) == nil, "leerer Text: nichts")
assert(Tr.QuestText(300) == nil, "nicht im Log: nichts")
-- welche Zeilen
local step = {actions = {{id = 100}, {id = 300}}}
assert(#Tr.TextQuests({kind = "now", nav = {step = step}}) == 2, "Titelzeile JETZT")
assert(#Tr.TextQuests({kind = "nxTitle", nav = {step = step}}) == 2, "Titelzeile ALS NAECHSTES")
assert(Tr.TextQuests({kind = "obj2", nav = {step = step, qid = 100}})[1] == 100, "Questname bei mehreren Quests")
assert(#Tr.TextQuests({kind = "obj", nav = {step = step, qid = 100}}) == 0, "Teilziel-Zeile ohne Text")
assert(Tr.TextQuests({kind = "nxWho", off = 100})[1] == 100, "Quest nicht im Plan")
-- Tooltip
local lines = {}
local tt = {AddLine = function(_, s) lines[#lines + 1] = s end}
assert(Tr.AddQuestText(tt, {100, 300}) == 1, "nur die angenommene Quest")
local all = table.concat(lines, "|")
assert(all:find("Questziel") and all:find("Beschreibung") and all:find("Mankriks Frau"), "Ziel und ganze Beschreibung")
local src = io.open(root .. "/ONE_Leveling/Tracker.lua"):read("*a")
assert(src:find("Tr.AddQuestText(GameTooltip, self.qids)", 1, true), "im OnEnter eingehaengt")
print("OK test_questtext_178")
