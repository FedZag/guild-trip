-- Offline-Test 0.7.1: Questlevel vor Questnamen (Quest-Fuehrung, Kasten, Chat-Links – nur Anzeige).
local root = arg[1] or "src"
GuildTripQuestDB = {q = {[7] = {5, 1, 0, 0, false, {}, {}, {}, false, false, 0, 0, 0, 1}, [8] = {0, 1}}}
C_QuestLog = {GetLogIndexForQuestID = function(id) return id == 9 and 3 or nil end,
    GetInfo = function(i) if i == 3 then return {level = 14} end end}
local filters = {}
ChatFrame_AddMessageEventFilter = function(ev, fn) filters[ev] = fn end
local ONE = {db = {}}
_G.ProjectONE = ONE
local nav = {}
assert(loadfile(root .. "/ONE_Nav/QuestLevels.lua"))("ONE_Nav", nav)
local QL = nav.QuestLevels

-- 1) Stufe: Questlog vor Datenbank, unbekannt = nichts
assert(QL.Level(9) == 14 and QL.Level(7) == 5 and QL.Level(8) == nil and QL.Level(99) == nil)
assert(QL.Prefix(7) == "[5] " and QL.Prefix(8) == "" and QL.Prefix(1, 30) == "[30] ")
-- 2) Chat-Links umschreiben (nur Anzeige)
local link = "|cffffff00|Hquest:7:5|h[Säuberung]|h|r"
assert(QL.Rewrite("Wer hilft bei " .. link .. "?") == "Wer hilft bei |cffffff00|Hquest:7:5|h[[5] Säuberung]|h|r?")
-- Stufe -1 (skaliert): aus der Datenbank; doppelt nicht nochmal
assert(QL.Rewrite("|Hquest:7:-1|h[X]|h") == "|Hquest:7:-1|h[[5] X]|h")
assert(QL.Rewrite("|Hquest:7:5|h[[5] X]|h") == "|Hquest:7:5|h[[5] X]|h")
-- unbekannte Quest mit Stufe 0: unveraendert; ohne Link: unveraendert
assert(QL.Rewrite("|Hquest:99:0|h[Y]|h") == "|Hquest:99:0|h[Y]|h")
assert(QL.Rewrite("Hallo") == "Hallo")
-- 3) Filter: angemeldet fuer Gilde/Gruppe/Fluestern, gibt die geaenderte Zeile weiter, blockiert nie
assert(QL:Initialize() and filters.CHAT_MSG_GUILD and filters.CHAT_MSG_WHISPER and filters.CHAT_MSG_PARTY)
local block, msg, author = filters.CHAT_MSG_GUILD(nil, "CHAT_MSG_GUILD", link, "Bob")
assert(block == false and msg:find("[5] Säuberung", 1, true) and author == "Bob")
assert(filters.CHAT_MSG_GUILD(nil, "CHAT_MSG_GUILD", "ohne Link") == false)
-- 4) Abgeschaltet: nichts
ONE.FeatureOn = function(_, id) return id ~= "nav.questLevels" end
assert(QL.Prefix(7) == "" and select(2, filters.CHAT_MSG_GUILD(nil, "x", link)) == nil)
print("OK test_questlevels_116")
