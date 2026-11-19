-- Offline-Test: Gilden-Quest-Abgleich (senden nur mit Haekchen, empfangen, Orte von anderen).
local root = arg[1] or "src"
local sent = {}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, channel) sent[#sent + 1] = {prefix, msg, channel} return true end}
C_Timer = {After = function(_, fn) fn() end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local clock = 100
GetTime = function() return clock end
UnitName = function() return "Hordi" end
UnitFullName = function() return "Hordi", "" end
UnitLevel = function() return 20 end
UnitClass = function() return "Priester", "PRIEST" end
IsInGuild = function() return true end
Enum = {UIMapType = {Continent = 2, Zone = 3}}
-- zwei Quests im Log, eine mit Ort mitten in der Zone, eine nur am Zonenrand
local log = {
    {questID = 101, title = "Eierjagd", level = 18, isComplete = false},
    {questID = 202, title = "Verog", level = 20, isComplete = true},
}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) return log[i] end,
    GetQuestObjectives = function(id)
        if id == 101 then return {{text = "Eier", numFulfilled = 3, numRequired = 8, finished = false}} end
        return {{text = "Kopf", numFulfilled = 1, numRequired = 1, finished = true}}
    end,
    GetQuestsOnMap = function(map)
        if map == 1413 then return {{questID = 101, x = .45, y = .62}, {questID = 202, x = .99, y = .5}} end
        return {}
    end,
}
C_Map = {GetBestMapForUnit = function() return 1413 end, GetMapInfo = function() return nil end}
local ONE = {db = {}}
function ONE:Print() end
local shareOpt
ONE.UI = {AddShareOption = function(_, o) shareOpt = o return true end}
_G.ProjectONE = ONE
local nav = {}
assert(loadfile(root .. "/ONE_Nav/Quests.lua"))("ONE_Nav", nav)
assert(loadfile(root .. "/ONE_Nav/QuestShare.lua"))("ONE_Nav", nav)
local QS = nav.QuestShare
QS:Initialize()
assert(shareOpt and shareOpt.id == "quests" and shareOpt.get() == false, "Haekchen in Optionen › Teilen")

-- 1) Ohne Haekchen geht kein eigener Stand raus (nur die Bitte QREQ)
for _, s in ipairs(sent) do assert(s[2] == "QREQ", "ohne Haekchen nichts teilen: " .. s[2]) end
sent = {}
QS:Receive(QS.prefix, "QREQ", "GUILD", "Thrall")
assert(#sent == 0, "QREQ ohne Haekchen beantwortet")

-- 2) Haekchen an -> Q0 + Q1 mit Fortschritt, Ort nur ohne Zonenrand
shareOpt.set(true)
assert(QS:IsSharing() and ONE.db.nav.questShare.Hordi == true)
assert(sent[1][1] == "ONEQST1" and sent[1][2] == "Q0|20|PRIEST" and sent[1][3] == "GUILD", sent[1][2])
local q1 = sent[2][2]
assert(q1:find("^Q1|") and q1:find("101,0,3,8,1413,450,620", 1, true) and q1:find("202,1,1,1", 1, true), q1)
assert(not q1:find("202,1,1,1,", 1, true), "Randpunkt darf nicht geteilt werden: " .. q1)
-- unveraendert -> nicht erneut senden
local n = #sent
assert(QS:SendState() == false and #sent == n)
clock = clock + 400
assert(QS:SendState() == true, "nach 5 Minuten wiederholen")

-- 3) Empfangen: wer hat dieselbe Quest, Ort von anderen
QS:Receive(QS.prefix, "Q0|21|WARRIOR", "GUILD", "Thrall-Forever")
QS:Receive(QS.prefix, "Q1|101,0,5,8,1413,400,600;303,0,0,4,1414,100,200", "GUILD", "Thrall-Forever")
QS:Receive(QS.prefix, "Q0|19|SHAMAN", "GUILD", "Rehgar")
QS:Receive(QS.prefix, "Q1|101,1,8,8", "GUILD", "Rehgar")
local h = QS:Holders(101)
assert(#h == 2 and h[1].name == "Rehgar" and h[1].done and h[2].name == "Thrall" and h[2].f == 5)
local text, count = QS:HoldersText(101)
assert(count == 2 and text == "Rehgar fertig, Thrall 5/8", text)
local loc = QS:Location(303)
assert(loc and loc.mapID == 1414 and math.abs(loc.x - .1) < 1e-9 and loc.from == "Thrall")
assert(nav.Quests:Where({id = 303}).from == "Thrall", "Luecke mit Ort der Gilde fuellen")
assert(nav.Quests:Where({id = 101}).mapID == 1413 and not nav.Quests:Where({id = 101}).from, "eigener Ort zuerst")
-- eigene Nachrichten und Muell ignorieren
QS:Receive(QS.prefix, "Q0|1|X", "GUILD", "Hordi")
QS:Receive(QS.prefix, "Q1|kaputt;,,", "GUILD", "Garrosh")
assert(#QS:Peers() == 2)

-- 4) QOFF und Zeitablauf
QS:Receive(QS.prefix, "QOFF", "GUILD", "Rehgar")
assert(#QS:Holders(101) == 1)
clock = clock + 1000
assert(#QS:Peers() == 0, "alte Staende fallen weg")

-- 5) Haekchen aus -> QOFF
shareOpt.set(false)
assert(sent[#sent][2] == "QOFF" and not QS:IsSharing())

-- 6) Viele Quests -> mehrere Q1, jede unter 250 Zeichen
for i = 1, 25 do log[#log + 1] = {questID = 10000 + i, title = "Q" .. i, level = 20} end
local msgs = QS:Messages()
assert(#msgs >= 3, "aufgeteilt")
for _, m in ipairs(msgs) do assert(#m <= 250, #m) end
-- 7) Reiter: Navi laedt vor der Fuehrung -> trotzdem kein "Quests"-Reiter, wenn ONE_Leveling kommt
local oldC = rawget(_G, "C_AddOns")
_G.C_AddOns = {GetAddOnEnableState = function(name) return name == "ONE_Leveling" and 2 or 0 end}
assert(nav.Quests.LevelingComing(), "Fuehrung wird geladen")
_G.C_AddOns = {GetAddOnEnableState = function() return 0 end}
assert(not nav.Quests.LevelingComing(), "Fuehrung nicht installiert")
_G.C_AddOns = oldC
print("OK test_questshare_066")
