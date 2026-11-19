-- Offline-Test 0.7.2: Chat-Verlauf ueber Neustart (je Charakter, Grenzen, Alter, einmal je Nachricht)
local root = arg[1] or "src"
local now = 1800000000
date, time = os.date, function() return now end
UnitName = function() return "Kaboom" end
GetRealmName = function() return "Forever" end
C_FriendList = {IsIgnored = function() return false end}
ChatFrame_GetMessageEventFilters = function() return nil end
local ONE = {db = {}}
_G.ProjectONE = ONE
local function Fresh()
    local c = {}
    assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
    return c.Chat
end
local Chat = Fresh()
for i = 1, 130 do Chat:OnEvent("CHAT_MSG_GUILD", "Gilde " .. i, "Rexxar", "", "", "", "", 0, 0, "", 0, i, "") end
for i = 1, 60 do Chat:OnEvent("CHAT_MSG_WHISPER", "Psst " .. i, "Bodra-Forever", "", "", "", "", 0, 0, "", 0, 500 + i, "") end
local h = Chat:SaveHistory()
local key = "Kaboom-Forever"
assert(ONE.db.chatHistory[key] == h, "je Charakter")
assert(#h.views.guild == 100 and #h.views["w:Bodra"] == 50, "100 je Reiter, 50 je Gespraech")
-- jede Nachricht nur einmal (Gilde steht in "Alle" und "Gilde")
local seen = {}
for _, n in ipairs(h.views.all) do seen[n] = true end
local shared = 0
for _, n in ipairs(h.views.guild) do if seen[n] then shared = shared + 1 end end
assert(shared > 0 and #h.entries < #h.views.all + #h.views.guild + #h.views["w:Bodra"], "geteilt statt doppelt")
-- neu laden: Verlauf da, nichts ungelesen, Gespraech wieder in der Liste
local Chat2 = Fresh()
assert(Chat2:LoadHistory() > 0)
local g = Chat2:Buffer("guild")
assert(#g == 100 and g[#g].text == "Gilde 130" and g[#g].restored, "letzte 100 Gildennachrichten")
assert(next(Chat2.unread) == nil, "nichts ungelesen")
assert(Chat2.whispers[1].name == "Bodra" and #Chat2:Buffer("w:Bodra") == 50)
-- aelter als 7 Tage: weg
now = now + 8 * 86400
local Chat3 = Fresh()
assert(Chat3:LoadHistory() == 0, "zu alt")
-- Schalter aus: nichts laden, beim Speichern geloescht
now = now - 8 * 86400
local Chat4 = Fresh()
Chat4:Settings().keepHistory = false
assert(Chat4:LoadHistory() == 0)
Chat4:SaveHistory()
assert(ONE.db.chatHistory[key] == nil, "geloescht")
print("OK test_chathistory_122")
