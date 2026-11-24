-- Offline-Test 24.11.2026: Slash-Befehle aus dem Guild-Trip-Chat laufen ueber ein eigenes Befehlsfeld,
-- nie ueber das Blizzard-Eingabefeld. Grund (Spielbild "Ein Makroskript wurde geblockt"): setzt Addon-Code
-- dort Chat-Art/Ziel, kopiert WoW diese Werte in jedes Makro -> /ginvite-Knoepfe (Wappen, Alt+Klick) blockiert.
local root = arg[1] or "src"
date, time = os.date, function() return 1800000000 end
local blizzard = 0
ChatEdit_ChooseBoxForSend = function() blizzard = blizzard + 1 return {SetText = function() end} end
ChatEdit_SendText = function() blizzard = blizzard + 1 end
local sentMsgs = {}
SendChatMessage = function(msg, chatType, lang, target) sentMsgs[#sentMsgs + 1] = {msg, chatType, target} end
C_ChatInfo = {SendChatMessage = SendChatMessage}
-- Blizzards Mixin nachgebaut: SendText merkt sich den Text
local ran = {}
ChatFrameEditBoxBaseMixin = {
    SetChatType = function(self, t) self.attr.chatType = t end,
    SetStickyType = function(self, t) self.attr.stickyType = t end,
    SendText = function(self) ran[#ran + 1] = self.text end,
}
Mixin = function(o, m) for k, v in pairs(m) do o[k] = v end return o end
local created = 0
CreateFrame = function(kind)
    created = created + 1
    assert(kind == "EditBox")
    return {attr = {}, text = "", SetText = function(self, t) self.text = t end, Hide = function() end,
        SetAutoFocus = function() end}
end
DEFAULT_CHAT_FRAME = {}
SLASH_SMART_WHISPER1 = "/w"
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
local Chat = c.Chat

-- 1) Befehl: eigenes Feld, Blizzard-Feld unberuehrt
assert(Chat:Send("guild", "/roll 100") == true)
assert(ran[1] == "/roll 100", "Befehl lief nicht ueber das eigene Feld")
assert(blizzard == 0, "Blizzard-Eingabefeld wurde benutzt (macht Makros kaputt)")
local box = Chat.CommandBox()
assert(box.attr.chatType == "SAY" and box.chatFrame == DEFAULT_CHAT_FRAME and box.text == "")
-- ein Feld fuer alle Befehle
Chat:Send("guild", "/ginvite Lyra")
assert(created == 1 and ran[2] == "/ginvite Lyra" and blizzard == 0)

-- 2) "/w Name Text" geht ueber unseren Fluesterweg (kein Blizzard-Feld, Gespraech entsteht)
assert(Chat:Send("guild", "/w Lyra Hallo du") == true)
assert(sentMsgs[#sentMsgs][1] == "Hallo du" and sentMsgs[#sentMsgs][2] == "WHISPER" and sentMsgs[#sentMsgs][3] == "Lyra")
assert(blizzard == 0 and #ran == 2)
local found = false
for _, w in ipairs(Chat.whispers) do if w.name == "Lyra" then found = true end end
assert(found, "Fluestergespraech fehlt")
-- mit Realm: Namen nicht kuerzen, eigenes Befehlsfeld
Chat:Send("guild", "/w Lyra-Anderswo hi")
assert(ran[3] == "/w Lyra-Anderswo hi" and blizzard == 0)
assert(Chat.WhisperCommand("/W Bob na") == "Bob" and Chat.WhisperCommand("/roll 5") == nil)

-- 3) Client ohne Vorlage: alter Weg bleibt
Chat.cmdBox, ChatFrameEditBoxBaseMixin = nil, nil
Chat:Send("guild", "/roll 1")
assert(blizzard == 2)
print("OK test_cmdbox_168")
