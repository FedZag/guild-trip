-- Offline-Test: Gruppengesuche fuer Elite-Quests (Kennung "q<QuestID>").
local root = arg[1] or "src"
local sent = {}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, msg, channel) sent[#sent + 1] = {prefix, msg, channel} return true end}
C_Timer = {After = function(_, fn) fn() end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
GetTime = function() return 500 end
UnitName = function() return "Hordi" end
UnitFullName = function() return "Hordi", "" end
UnitLevel = function() return 20 end
UnitClass = function() return "Priester", "PRIEST" end
IsInGuild = function() return true end
GetNumGroupMembers = function() return 2 end
local inLog = {[555] = true}
C_QuestLog = {GetLogIndexForQuestID = function(id) return inLog[id] and 3 or nil end,
    GetTitleForQuestID = function(id) return id == 777 and "Der Riese" or nil end}
local ONE = {db = {}, modules = {}}
function ONE:Print() end
function ONE:IsEnabled() return true end
function ONE:RegisterModule(id, def) self.modules[id] = def end
_G.ProjectONE = ONE
local d = {}
for _, f in ipairs({"QuestData", "Catalog", "Model", "Share", "Init"}) do assert(loadfile(root .. "/ONE_Dungeons/" .. f .. ".lua"))("ONE_Dungeons", d) end
local S = d.Share
local told = {}
S.Tell = function(_, text) told[#told + 1] = text end

-- 1) Eigenes Gesuch ueber die Modul-Schnittstelle (wie die Quest-Seite)
local ad = ONE.modules.dungeons:PostQuestAd(555, "Gor der Schlächter", 3)
S:Flush(10)
assert(ad and ad.key == "q555" and ad.size == 3 and ad.have == 2)
assert(sent[#sent][2]:find("^GA|" .. ad.gid .. "|q555|T,H,D|2|3||Gor der Schlächter$"), sent[#sent][2])
assert(ONE.modules.dungeons:MyQuestAd() == 555)
assert(S:AdName(ad) == "Quest: Gor der Schlächter")
-- zweites Gesuch ersetzt das erste (GC geht raus)
local ad2 = ONE.modules.dungeons:PostQuestAd(556, "Andere", 5)
S:Flush(10)
assert(sent[#sent - 1][2] == "GC|" .. ad.gid and S.myAd == ad2 and not S.ads[ad.gid])
S:CloseAd()

-- 2) Fremdes Gesuch: Hinweis nur, wenn ich die Quest auch habe
S:Receive(S.prefix, "GA|X1|q555|T,H,D|1|5||Gor der Schlächter", "GUILD", "Thrall")
assert(#told == 1 and told[1]:find("Thrall") and told[1]:find("Gor der Schlächter") and told[1]:find("auch"), told[1])
local fits, open = S:Fit(S.ads.X1)
assert(fits and open == 1)
S:Receive(S.prefix, "GA|X2|q999|T,H,D|1|5||Fremd", "GUILD", "Rehgar")
assert(#told == 1, "ohne die Quest kein Hinweis")
assert(S:Fit(S.ads.X2) == false)
-- 3) Alte Clients ohne Titel: Name aus dem Spiel bzw. Nummer
S:Receive(S.prefix, "GA|X3|q777|D|1|5|", "GUILD", "Garrosh")
assert(S:AdName(S.ads.X3) == "Quest: Der Riese")
S:Receive(S.prefix, "GA|X4|q888|D|1|5|", "GUILD", "Garrosh")
assert(S:AdName(S.ads.X4) == "Quest: #888")
-- Dungeon-Gesuche unveraendert
assert(S:QuestOf({key = "wc"}) == nil and S:AdName({key = "wc"}) ~= "")
print("OK test_questads_067")
