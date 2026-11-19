-- Offline-Test: Guild-Trip-Chat (Kern) – Nachrichten sammeln, Gespraeche, Ungelesenes,
-- Blizzard-Filter und Ignorierliste, Ziel je Reiter/Gespraech, Senden, eigene Reiter, Darstellung.
local root = arg[1] or "src"
date, time = os.date, function() return 1800000000 end
local sentMsgs, slash = {}, {}
SendChatMessage = function(msg, chatType, lang, target) sentMsgs[#sentMsgs + 1] = {msg, chatType, target} end
ChatEdit_ChooseBoxForSend = function() return {SetText = function(self, t) self.t = t end, t = ""} end
ChatEdit_SendText = function(box) slash[#slash + 1] = box.t end
GetChannelList = function() return 1, "Allgemein", false, 2, "Handel", false end
local raid, group = false, false
IsInRaid = function() return raid end
IsInGroup = function() return group end
local ignored = {Spammer = true}
C_FriendList = {IsIgnored = function(name) return ignored[name] end}
local filters = {}
ChatFrame_GetMessageEventFilters = function(event) return filters[event] end
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
local Chat = c.Chat

-- 1) Gildennachricht: in "Alle" und "Gilde", ungelesen
local e = Chat:OnEvent("CHAT_MSG_GUILD", "Wer kommt mit?", "Rexxar-Forever", "", "", "", "", 0, 0, "", 0, 77, "Player-1")
assert(e and e.kind == "guild" and e.lineID == 77)
assert(#Chat:Buffer("all") == 1 and #Chat:Buffer("guild") == 1 and #Chat:Buffer("trade") == 0)
assert(Chat.unread.guild == 1 and Chat.unread.all == 1)
-- gerade sichtbar: kein Ungelesen
Chat.visible, Chat.current = true, "guild"
Chat:OnEvent("CHAT_MSG_GUILD", "Ich!", "Tibeah", "", "", "", "", 0, 0, "", 0, 78, "")
assert(Chat.unread.guild == 1 and Chat.unread.all == 2)
Chat:MarkRead("guild")
assert(Chat.unread.guild == nil)

-- 2) Fluestern: eigenes Gespraech, Antwort (inform) nie ungelesen, zuletzt aktive zuerst
Chat.visible = false
Chat:OnEvent("CHAT_MSG_WHISPER", "Bist du dabei?", "Thrall-Forever", "", "", "", "", 0, 0, "", 0, 80, "")
Chat:OnEvent("CHAT_MSG_WHISPER", "Hallo", "Jaina", "", "", "", "", 0, 0, "", 0, 81, "")
Chat:OnEvent("CHAT_MSG_WHISPER_INFORM", "Ja!", "Thrall-Forever", "", "", "", "", 0, 0, "", 0, 82, "")
assert(#Chat:Buffer("w:Thrall") == 2 and Chat.unread["w:Thrall"] == 1, "Antwort zaehlt nicht als ungelesen")
assert(Chat.whispers[1].name == "Thrall" and Chat.whispers[2].name == "Jaina")
assert(Chat.lastWhisperFrom == "Jaina", "R antwortet dem letzten, der geschrieben hat")

-- 3) Handelskanal ueber CHAT_MSG_CHANNEL (Kanalname deutsch), nur im Reiter Handel/Alle
Chat:OnEvent("CHAT_MSG_CHANNEL", "WTS Leinen", "Haendler", "", "2. Handel - Orgrimmar", "", "", 2, 2, "Handel - Orgrimmar", 0, 90, "")
assert(#Chat:Buffer("trade") == 1 and Chat:Buffer("trade")[1].kind == "trade")
assert(Chat.ChannelKind("1. General - Durotar") == "general" and Chat.ChannelKind("Gildenrekrutierung") == "channel")

-- 4) Ignorierte und Blizzard-Filter
assert(Chat:OnEvent("CHAT_MSG_GUILD", "Kauft Gold", "Spammer", "", "", "", "", 0, 0, "", 0, 91, "") == nil)
filters.CHAT_MSG_GUILD = {function(_, _, msg) if msg:find("boese") then return true end return false end}
assert(Chat:OnEvent("CHAT_MSG_GUILD", "boese Nachricht", "X", "", "", "", "", 0, 0, "", 0, 92, "") == nil, "Filter blockt")
filters.CHAT_MSG_GUILD = {function(_, _, msg, a2, ...) return false, msg:gsub("Gold", "***"), a2, ... end}
local f = Chat:OnEvent("CHAT_MSG_GUILD", "Gold billig", "Y", "", "", "", "", 0, 0, "", 0, 93, "")
assert(f and f.text == "*** billig" and f.author == "Y", "Filter aendert Text")
filters.CHAT_MSG_GUILD = nil

-- 5) Ziel je Ansicht: jedes Gespraech schreibt nur dorthin, wo es hingehoert
assert(select(1, Chat:Target("guild")) == "GUILD")
local t, n = Chat:Target("w:Thrall")
assert(t == "WHISPER" and n == "Thrall")
local ok, why = Chat:Target("group")
assert(ok == nil and why == "Du bist in keiner Gruppe.")
group = true assert(Chat:Target("group") == "PARTY")
raid = true assert(Chat:Target("group") == "RAID")
t, n = Chat:Target("trade")
assert(t == "CHANNEL" and n == 2, "Handel = Kanalnummer 2")
assert(Chat:Target("near") == "SAY")

-- 6) Senden: Ziel, lange Texte geteilt, Slash-Befehle an den WoW-Chat
assert(Chat:Send("w:Thrall", "  Bin unterwegs  "))
assert(sentMsgs[1][1] == "Bin unterwegs" and sentMsgs[1][2] == "WHISPER" and sentMsgs[1][3] == "Thrall")
Chat:Send("guild", string.rep("wort ", 70))
assert(#sentMsgs == 3 and #sentMsgs[2][1] <= 255 and sentMsgs[3][2] == "GUILD", "lange Nachricht in zwei Teilen")
assert(Chat:Send("guild", "/tanzen") and slash[1] == "/tanzen" and #sentMsgs == 3)
assert(Chat:Send("guild", "   ") == nil, "leer: nichts senden")

-- 7) Eigene Reiter
local tab = Chat:SaveTab({label = "Raidabend", kinds = {group = true, whisper = true, quatsch = true}, send = "group"})
assert(tab and tab.kinds.group and tab.kinds.whisper and not tab.kinds.quatsch and tab.send == "group")
Chat:OnEvent("CHAT_MSG_RAID", "Pull", "Diwo", "", "", "", "", 0, 0, "", 0, 95, "")
assert(#Chat:Buffer(tab.id) == 1)
assert(Chat:SaveTab({label = "  "}) == nil, "Name noetig")
assert(not Chat:RemoveTab("guild"), "eingebaute Reiter bleiben")
assert(Chat:RemoveTab(tab.id) and not Chat:Tab(tab.id))

-- 8) Darstellung: Zeit, Art (nur in "Alle"), Spieler-Link mit Zeilennummer, "An …" bei eigener Antwort
local line = Chat:Format(Chat:Buffer("guild")[1], true)
assert(line:find("|Hplayer:Rexxar%-Forever:77|h") and line:find("%[Gilde%]") and line:find("Wer kommt mit%?"), line)
local inform = Chat:Buffer("w:Thrall")[2]
assert(Chat:Format(inform):find("An |Hplayer:"), Chat:Format(inform))
Chat:Settings().stamps = false
assert(not Chat:Format(Chat:Buffer("guild")[1]):find("|cff8a8a8a"))
-- 9) Klaenge: Fluestern an, Gilde/Gruppe/Senden nur nach Einstellung, Gilde hoechstens alle 3 s, eigene nie
local played = {}
ONE.Sound = {PlayAlert = function(_, key) played[#played + 1] = key return true end}
local clock = 100
GetTime = function() return clock end
UnitName = function() return "Hordi" end
local s = Chat:Settings()
assert(s.whisperSound and not s.guildSound and not s.groupSound and not s.sentSound, "Vorgaben")
assert(Chat:SoundFor({kind = "whisper", author = "Thrall"}) == "chatWhisper")
assert(Chat:SoundFor({kind = "whisper", author = "Thrall", inform = true}) == nil, "eigene Antwort klingt nicht")
assert(Chat:SoundFor({kind = "guild", author = "Rexxar"}) == nil, "Gilde aus")
s.guildSound = true
assert(Chat:SoundFor({kind = "guild", author = "Rexxar"}) == "chatMessage")
clock = 101
assert(Chat:SoundFor({kind = "guild", author = "Tibeah"}) == nil, "hoechstens alle 3 Sekunden")
clock = 104
assert(Chat:SoundFor({kind = "guild", author = "Hordi"}) == nil, "eigene Gildennachricht klingt nicht")
assert(Chat:SoundFor({kind = "officer", author = "Tibeah"}) == "chatMessage")
assert(Chat:SoundFor({kind = "group", author = "Diwo"}) == nil, "Gruppe aus")
s.whisperSound = false
assert(Chat:SoundFor({kind = "whisper", author = "Thrall"}) == nil)
Chat:Send("guild", "ohne Ton")
assert(#played == 0)
s.sentSound = true
Chat:Send("guild", "mit Ton")
assert(played[1] == "chatSent")
-- nur Nachrichten "nebenan" klingen: im aktiven Gespraech/Reiter bleibt es still
s.whisperSound = true
clock = 200
Chat.visible, Chat.current = true, "w:Thrall"
assert(Chat:SoundFor({kind = "whisper", author = "Thrall"}, {"w:Thrall", "all"}) == nil, "aktives Gespraech: still")
assert(Chat:SoundFor({kind = "whisper", author = "Jaina"}, {"w:Jaina", "all"}) == "chatWhisper", "anderes Gespraech: Klang")
Chat.current = "all"
assert(Chat:SoundFor({kind = "whisper", author = "Jaina"}, {"w:Jaina", "all"}) == nil, "steht schon im offenen Reiter Alle")
assert(Chat:SoundFor({kind = "guild", author = "Rexxar"}, {"all", "guild"}) == nil)
Chat.current = "trade"
assert(Chat:SoundFor({kind = "guild", author = "Rexxar"}, {"all", "guild"}) == "chatMessage", "Gilde nebenan")
Chat.visible = false
clock = 300
Chat.current = "guild"
assert(Chat:SoundFor({kind = "guild", author = "Rexxar"}, {"all", "guild"}) == "chatMessage", "Fenster zu: Klang")
-- 10) Andere Chat-Addons (ElvUI & Co.): erkannt, Ausblenden gesperrt, schlichtes Aussehen als Vorgabe
local loaded = {}
C_AddOns = {IsAddOnLoaded = function(name) return loaded[name] == true end}
assert(Chat.OtherChatAddon() == nil and Chat:CanHideBlizzardChat() and not Chat:Flat())
loaded.ElvUI = true
assert(Chat.OtherChatAddon() == "ElvUI")
local can, why = Chat:CanHideBlizzardChat()
assert(can == false and why:find("ElvUI"), why)
assert(Chat:Flat(), "bei ElvUI schlicht als Vorgabe")
s.flat = false
assert(not Chat:Flat(), "abschaltbar")
loaded = {["Prat-3.0"] = true}
assert(Chat.OtherChatAddon() == "Prat")
s.flat = nil
C_AddOns = nil
-- Klassenfarben: Namen in Klassenfarbe (RAID_CLASS_COLORS), auf Pergament dunkle Fassung mit Alpha "fe"
GetPlayerInfoByGUID = function(guid) if guid == "G-PRIEST" then return "Priester", "PRIEST" end end
RAID_CLASS_COLORS = {PRIEST = {r = 1, g = 1, b = 1, colorStr = "ffffffff"}}
assert(Chat.ClassColorCode("G-PRIEST") == "|cffffffff")
assert(Chat.ClassColorCode("G-PRIEST", true) == "|cfe4e5666")
assert(Chat.ClassColorCode(nil) == nil and Chat.ClassColorCode("G-UNBEKANNT") == nil)
Chat.parchment = true
local line = Chat:Format({kind = "guild", author = "Anduin-Forever", guid = "G-PRIEST", text = "Hallo", lineID = 3})
assert(line:find("|cfe4e5666Anduin|r", 1, true), line)
Chat.parchment = nil
GetPlayerInfoByGUID, RAID_CLASS_COLORS = nil, nil
print("OK test_chat_089")
