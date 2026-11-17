-- Offline-Test: Questgeber sammeln, zusammenfuehren, filtern, teilen.
local root = arg[1] or "src"
local sent = {}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg) sent[#sent + 1] = msg return true end}
C_Timer = {After = function(_, fn) fn() end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
GetTime = function() return 1 end
local now = 1000
GetServerTime = function() return now end
UnitName = function(u) return u == "npc" and "Gor'n" or "Hordi" end
UnitFullName = function() return "Hordi", "" end
UnitLevel = function() return 12 end
UnitClass = function() return "Priester", "PRIEST" end
UnitFactionGroup = function() return "Horde" end
UnitGUID = function() return "Creature-0-4170-1-123-3245-0000ABCD" end
IsInGuild = function() return true end
local done, inLog = {[50] = true}, {[51] = true}
local gossip = {}
C_GossipInfo = {GetAvailableQuests = function() return gossip end}
C_QuestLog = {IsQuestFlaggedCompleted = function(id) return done[id] or false end,
    GetLogIndexForQuestID = function(id) return inLog[id] and 1 or nil end,
    GetNumQuestLogEntries = function() return 1 end,
    GetInfo = function() return {questID = 51, title = "Im Log", level = 12} end,
    GetQuestObjectives = function() return {} end}
C_Map = {GetBestMapForUnit = function() return 1411 end,
    GetPlayerMapPosition = function() return {x = .4, y = .6} end}
local ONE = {db = {}}
function ONE:IsEnabled() return true end
_G.ProjectONE = ONE
local nav = {}
for _, f in ipairs({"Travel", "Quests", "QuestShare", "QuestGivers"}) do assert(loadfile(root .. "/ONE_Nav/" .. f .. ".lua"))("ONE_Nav", nav) end
local G = nav.QuestGivers

-- 1) Schluessel aus der GUID
assert(G.KeyFromGUID("Creature-0-4170-1-123-3245-0000ABCD") == "c3245")
assert(G.KeyFromGUID("GameObject-0-1-2-3-178-00") == "o178")
assert(G.KeyFromGUID(nil, "Brett") == "nBrett" and G.KeyFromGUID(nil, nil) == nil)

-- 2) Gossip-Fenster: Fund mit Ort und Stufen
gossip = {{questID = 100, questLevel = 11, title = "Wölfe"}, {questID = 50, questLevel = 10, title = "Erledigt"},
    {questID = 51, questLevel = 12, title = "Im Log"}, {questID = 101, questLevel = 20, title = "Zu hoch"},
    {questID = 102, questLevel = 2, title = "Grau"}}
G:OnEvent("GOSSIP_SHOW")
local g = G:Store().c3245
assert(g and g.name == "Gor'n" and g.mapID == 1411 and g.x == .4 and g.faction == "Horde")
assert(g.quests[100].level == 11)
-- 3) Nur passende Quests: nicht erledigt, nicht im Log, Stufe 12 -> 4..14
local av = G:Available()
assert(#av == 1 and #av[1].quests == 1 and av[1].quests[1].title == "Wölfe", #av)

-- 4) Quest-Begruessung nur mit Titel; spaeter mit ID -> Titel-Eintrag verschwindet
G:Add("c9", "Brett", 1411, .1, .2, "Horde", {{id = 0, title = "Nur Titel", level = 12}})
assert(G:Store().c9.quests["t:Nur Titel"])
G:Add("c9", "Brett", 1411, .1, .2, "Horde", {{id = 300, title = "Nur Titel"}})
assert(G:Store().c9.quests[300] and not G:Store().c9.quests["t:Nur Titel"])
-- Titel einer Log-Quest gilt als "schon angenommen"
G:Add("c8", "X", 1411, .1, .2, "Horde", {{id = 0, title = "Im Log", level = 12}})
for _, a in ipairs(G:Available()) do assert(a.key ~= "c8", "Titel im Log") end
-- fremde Fraktion nicht zeigen
G:Add("c7", "Allianzler", 1429, .5, .5, "Alliance", {{id = 400, title = "Für die Allianz", level = 12}})
for _, a in ipairs(G:Available()) do assert(a.key ~= "c7", "Fraktion") end

-- 5) Teilen nur mit Haekchen; Nachricht <= 250 und Rundlauf
assert(G:Share("c3245") == false and #sent == 0)
ONE.db.nav.questShare = {Hordi = true}
assert(G:Share("c3245") == true)
local msg = sent[#sent]
assert(#msg <= 250 and msg:find("^QG|c3245|Gor'n|1411|400|600|Horde|"), msg)
local copy = {}
for k, v in pairs(G:Store().c3245.quests) do copy[k] = v end
ONE.db.nav.givers = {}
nav.QuestShare:Receive(nav.QuestShare.prefix, msg, "GUILD", "Thrall")
local r = G:Store().c3245
assert(r and r.mapID == 1411 and math.abs(r.x - .4) < 1e-9 and r.quests[100].title == "Wölfe" and r.quests[100].level == 11)
-- Gildenfund ueberschreibt eigenen Ort nicht
G:Add("c3245", "Gor'n", 1411, .9, .9, "Horde", {{id = 100, title = "Wölfe"}}, true)
assert(r.x ~= .9)
-- lange Listen werden gekuerzt
local many = {}
for i = 1, 40 do many[i] = {id = 1000 + i, level = 12, title = ("Sehr langer Questtitel Nummer %d"):format(i)} end
G:Add("c1", "Viel", 1411, .3, .3, "Horde", many)
assert(#G:Message("c1") <= 250)
-- Muell ignorieren
nav.QuestShare:Receive(nav.QuestShare.prefix, "QG|x1|Böse|abc|1|2|Horde|1,1,a", "GUILD", "Garrosh")
assert(not G:Store().x1)

-- 6) Begrenzung: aelteste Funde fallen weg
G.maxGivers = 3
for i = 1, 5 do now = now + 10 G:Add("z" .. i, "Z", 1411, .5, .5, "Horde", {{id = 2000 + i, title = "Z"}}) end
local count = 0
for _ in pairs(G:Store()) do count = count + 1 end
assert(count == 3 and G:Store().z5 and not G:Store().c3245, count)
print("OK test_questgivers_069")
