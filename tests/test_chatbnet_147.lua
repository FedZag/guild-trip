-- Offline-Test 21.11.2026: Battle.net-Nachrichten (Launcher) im Guild-Trip-Chat.
-- Fluestern von Battle.net-Freunden: eigenes Gespraech unter der BattleTag, Antworten per BNSendWhisper,
-- Haken/rot wie beim normalen Fluestern; "X ist online" und Rundrufe als Systemzeile.
local root = arg[1] or "src"
date, time = os.date, function() return 1800000000 end
GetTime = function() return 100 end
local bnSent, chatSent = {}, {}
SendChatMessage = function(...) chatSent[#chatSent + 1] = {...} end
BNSendWhisper = function(id, msg) bnSent[#bnSent + 1] = {id, msg} end
local friends = {
    [42] = {bnetAccountID = 42, battleTag = "Kumpel#1234", accountName = "|Kq42|k",
        gameAccountInfo = {isOnline = true, characterName = "Grimmbart", areaName = "Orgrimmar"}},
    [43] = {bnetAccountID = 43, battleTag = "Weg#5678", gameAccountInfo = {isOnline = false}},
}
C_BattleNet = {
    GetAccountInfoByID = function(id) return friends[id] end,
    GetFriendAccountInfo = function(i) return friends[41 + i] end,
}
BNGetNumFriends = function() return 2 end
BN_INLINE_TOAST_FRIEND_ONLINE = "%s ist jetzt online."
BN_INLINE_TOAST_FRIEND_PENDING = "Du hast %d Freundschaftsanfragen."
C_FriendList = {IsIgnored = function() return false end}
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
local Chat = c.Chat
local function BN(event, text, id, kname)
    return Chat:OnEvent(event, text, kname or "|Kq" .. id .. "|k", "", "", "", "", 0, 0, "", 0, 7, "", id)
end

-- 1) Ereignisse sind angemeldet (Init meldet alle aus kindByEvent an)
for _, ev in ipairs({"CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_BN_INLINE_TOAST_ALERT",
    "CHAT_MSG_BN_INLINE_TOAST_BROADCAST", "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE"}) do
    assert(Chat.kindByEvent[ev], "nicht angemeldet: " .. ev)
end

-- 2) Eingehend: Gespraech unter der BattleTag (nicht dem verschluesselten Anzeigenamen), ungelesen
local e = BN("CHAT_MSG_BN_WHISPER", "Na, wie laeufts?", 42)
assert(e and e.kind == "whisper" and e.author == "Kumpel#1234" and e.bn and not e.inform, "Absender = BattleTag")
assert(#Chat:Buffer("w:Kumpel#1234") == 1 and Chat.unread["w:Kumpel#1234"] == 1)
assert(Chat.whispers[1].name == "Kumpel#1234" and Chat.lastWhisperFrom == "Kumpel#1234")
assert(#Chat:Buffer("all") == 1, "steht auch in Alle")

-- 3) Antworten: geht per BNSendWhisper an die Konto-Nummer, nicht per SendChatMessage
assert(Chat:Send("w:Kumpel#1234", "Gut!"))
assert(#bnSent == 1 and bnSent[1][1] == 42 and bnSent[1][2] == "Gut!" and #chatSent == 0)
local buf = Chat:Buffer("w:Kumpel#1234")
assert(buf[#buf].pending, "sofort sichtbar, wartet auf Bestaetigung")
-- Bestaetigung vom Server ersetzt die wartende Nachricht (Haken)
local conf = BN("CHAT_MSG_BN_WHISPER_INFORM", "Gut!", 42)
assert(conf and conf.delivered and #Chat:Buffer("w:Kumpel#1234") == 2, "Haken statt doppelter Zeile")

-- 4) Freund aus der Liste anschreiben, der noch nie geschrieben hat (Nummer aus der Freundesliste)
Chat.bnIds = {}
assert(Chat.BNFind("Weg#5678") == 43)
assert(Chat:Send("w:Weg#5678", "Hallo?"))
assert(bnSent[2][1] == 43)
-- offline: die wartende Nachricht wird rot, keine Extra-Zeile
local before = #Chat:Buffer("system")
assert(BN("CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE", "", 43) == nil)
local w = Chat:Buffer("w:Weg#5678")
assert(w[#w].failed, "nicht zugestellt")
assert(#Chat:Buffer("system") == before)
-- unbekannter Freund: Hinweis statt Fehler
local ok, msg = Chat:Send("w:Fremd#0001", "Hi")
assert(not ok and msg:find("Battle.net"), "Hinweis bei unbekannter BattleTag")

-- 5) Battle.net-Hinweise als Systemzeile, mit BattleTag statt verschluesseltem Namen
local t = BN("CHAT_MSG_BN_INLINE_TOAST_ALERT", "FRIEND_ONLINE", 42)
assert(t and t.kind == "system" and t.text == "Kumpel#1234 ist jetzt online.", t and t.text)
BNGetNumFriendInvites = function() return 3 end
local p = BN("CHAT_MSG_BN_INLINE_TOAST_ALERT", "FRIEND_PENDING", 0, "")
assert(p and p.text == "Du hast 3 Freundschaftsanfragen.")
assert(BN("CHAT_MSG_BN_INLINE_TOAST_ALERT", "UNBEKANNT", 42) == nil, "unbekannter Hinweis: nichts Kaputtes zeigen")
local r = BN("CHAT_MSG_BN_INLINE_TOAST_BROADCAST", "Heute Raid!", 42)
assert(r and r.kind == "system" and r.text:find("Kumpel#1234", 1, true) and r.text:find("Heute Raid!", 1, true))

-- 6) Ohne Battle.net-Funktionen: verschluesselter Name bleibt (zeigt WoW richtig an), nichts bricht
C_BattleNet, BNGetFriendInfoByID = nil, nil
local k = BN("CHAT_MSG_BN_WHISPER", "Hallo", 99)
assert(k and k.author == "|Kq99|k")

-- 7) Senden per BNSendWhisper nur in Chat.lua (Tastendruck in der Eingabezeile)
local forb = assert(io.open("tests/test_forbidden_123.lua")):read("*a")
assert(forb:find("BNSendWhisper", 1, true), "BNSendWhisper steht in der Liste der Sende-Stellen")
-- Spielbild 24.11.2026 ("Battle.net · Blizzard App", Einladen ging nicht): erstes Spielkonto = App,
-- zweites = WoW -> Charakter aus dem WoW-Konto; BattleTag nie als Spielername
friends[44] = {bnetAccountID = 44, battleTag = "Aventor#2500",
    gameAccountInfo = {isOnline = true, clientProgram = "App", richPresence = "Blizzard App"}}
local games = {{isOnline = true, clientProgram = "App"},
    {isOnline = true, clientProgram = "WoW", characterName = "Aventorin", realmName = "Forever", areaName = "Dalaran", gameAccountID = 9}}
BNGetFriendIndex = function(id) return id == 44 and 3 or nil end
C_BattleNet = {GetAccountInfoByID = function(id) return friends[id] end}
C_BattleNet.GetFriendNumGameAccounts = function(i) return i == 3 and #games or 0 end
C_BattleNet.GetFriendGameAccountInfo = function(i, j) return i == 3 and games[j] or nil end
GetRealmName = function() return "Forever" end
Chat.bnIds["Aventor#2500"] = 44
local info = Chat.BNInfo(44)
assert(info.character == "Aventorin" and info.zone == "Dalaran" and info.gameAccount == 9, "WoW-Konto statt App")
assert(Chat.BNPlayerName("Aventor#2500") == "Aventorin", "Spielername zum Einladen")
GetRealmName = function() return "Anderswo" end
assert(Chat.BNPlayerName("Aventor#2500") == "Aventorin-Forever", "fremder Realm mit Bindestrich")
-- nur App: kein Spielername (kein Einladen mit BattleTag)
games[2] = nil
assert(Chat.BNInfo(44).character == nil and Chat.BNPlayerName("Aventor#2500") == nil)
-- anderes WoW (anderes Projekt) zaehlt nicht
WOW_PROJECT_ID = 2
games[2] = {isOnline = true, clientProgram = "WoW", characterName = "Retailkerl", wowProjectID = 1}
assert(Chat.BNPlayerName("Aventor#2500") == nil, "anderes WoW-Spiel: nicht einladbar")
WOW_PROJECT_ID = nil
print("OK test_chatbnet_147")
