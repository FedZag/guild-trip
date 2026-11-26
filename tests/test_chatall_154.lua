-- Offline-Test 22.11.2026 (Nutzer: "kontrollieren, ob alle WoW-Chatfunktionen auch im Messenger funktionieren"):
-- NPC-Gespraeche, Abwesend/Nicht-stoeren-Antworten, Kanal-Meldungen, Erfolge, Ignoriert, Beute & Fortschritt,
-- Emote-Befehle ueber die erlaubte Funktion (DoEmote ist in Forever gesperrt), Antworten-Taste/WoW-Fluestern
-- bei ersetztem WoW-Chat.
local root = arg[1] or "src"
date, time = os.date, function() return 1800000000 end
GetTime = function() return 100 end
local chatSent, emotes = {}, {}
SendChatMessage = function(...) chatSent[#chatSent + 1] = {...} end
C_FriendList = {IsIgnored = function() return false end}
C_ChatInfo = {PerformEmote = function(token, target) emotes[#emotes + 1] = {token, target} end}
EMOTE1_TOKEN, EMOTE1_CMD1, EMOTE1_CMD2 = "WAVE", "/wave", "/winken"
CHAT_YOU_JOINED_NOTICE = "Kanal betreten: [%d. %s]"
CHAT_IGNORED = "%s ignoriert dich."
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Chat/Chat.lua"))("ONE_Chat", c)
local Chat = c.Chat
local function Ev(event, text, author, a)
    a = a or {}
    return Chat:OnEvent(event, text, author or "", a[3] or "", a[4] or "", a[5] or "", "", 0, a[8] or 0, a[9] or "", 0, 7, a[12] or "", 0)
end

-- 1) alle Ereignisse sind angemeldet
for _, ev in ipairs({"CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_WHISPER",
    "CHAT_MSG_RAID_BOSS_EMOTE", "CHAT_MSG_AFK", "CHAT_MSG_DND", "CHAT_MSG_IGNORED", "CHAT_MSG_CHANNEL_NOTICE",
    "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_COMBAT_XP_GAIN",
    "CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_SKILL", "CHAT_MSG_BG_SYSTEM_NEUTRAL"}) do
    assert(Chat.kindByEvent[ev], "nicht angemeldet: " .. ev)
end

-- 2) NPC sagt etwas: als Blase in "In der Naehe" und "Alle", Name ohne Spieler-Link
local e = Ev("CHAT_MSG_MONSTER_SAY", "Hallo, Reisender!", "Gornek")
assert(e and e.kind == "npc" and e.npc, "NPC")
assert(#Chat:Buffer("near") == 1 and #Chat:Buffer("all") == 1, "NPC in der Naehe und Alle")
assert(not Chat:Format(e):find("|Hplayer", 1, true), "NPC-Name ist kein Spieler-Link")
-- NPC-Emote: %s wird zum Namen, schlichte Zeile
e = Ev("CHAT_MSG_MONSTER_EMOTE", "%s brüllt wütend!", "Kodo")
assert(e.text == "Kodo brüllt wütend!" and Chat.IsPlain(e), e.text)

-- 3) Abwesend-Antwort: im Fluestergespraech, ohne Zaehler und Ton
e = Ev("CHAT_MSG_AFK", "bin essen", "Lyra-Forever")
assert(e.kind == "whisper" and e.auto and e.text == "Abwesend: bin essen", tostring(e.text))
assert(#Chat:Buffer("w:Lyra") == 1 and not Chat.unread["w:Lyra"], "kein Zaehler")
assert(Chat:SoundFor(e, {"w:Lyra"}) == nil, "kein Ton")
e = Ev("CHAT_MSG_DND", "Raid", "Lyra-Forever")
assert(e.text == "Nicht stören: Raid")

-- 4) Kanal-Meldung, Ignoriert, Erfolg: lesbare Systemzeile
e = Ev("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", "", {[4] = "Handel", [8] = 2})
assert(e and e.kind == "system" and e.text == "Kanal betreten: [2. Handel]", tostring(e and e.text))
e = Ev("CHAT_MSG_CHANNEL_NOTICE", "UNBEKANNT", "", {[4] = "X", [8] = 3})
assert(e == nil, "unbekannte Meldung ohne Text: nichts zeigen")
e = Ev("CHAT_MSG_IGNORED", "", "Troll-Forever")
assert(e.text == "Troll ignoriert dich.")
e = Ev("CHAT_MSG_GUILD_ACHIEVEMENT", "%s hat den Erfolg [Stufe 20] errungen!", "Bonsai-Forever")
assert(e.kind == "system" and e.text == "Bonsai hat den Erfolg [Stufe 20] errungen!", e.text)

-- 5) Beute & Fortschritt: eigenes Gespraech, stumm, nicht in "Alle"
local before = #Chat:Buffer("all")
e = Ev("CHAT_MSG_LOOT", "Ihr erhaltet Beute: [Leinenstoff].", "Ich")
assert(e.kind == "progress" and Chat.IsPlain(e) and #Chat:Buffer("progress") == 1 and #Chat:Buffer("all") == before)
assert(Chat:Settings().muted.progress, "stumm")
Ev("CHAT_MSG_COMBAT_XP_GAIN", "Kodo stirbt, Ihr bekommt 45 Erfahrung.", "")
assert(#Chat:Buffer("progress") == 2)

-- 6) Bestehende Einstellungen bekommen NPC und das neue Gespraech nachgetragen
ONE.db.chat = {tabs = {{id = "all", kinds = {guild = true}, builtin = true}, {id = "near", kinds = {say = true}, builtin = true}},
    muted = {trade = true}}
local s = Chat:Settings()
assert(s.tabs[1].kinds.npc and s.tabs[2].kinds.npc and Chat:Tab("progress") and s.muted.progress, "nachgetragen")
ONE.db.chat = nil

-- 7) Emote-Befehle: ueber PerformEmote (erlaubt), nicht ueber den WoW-Chat (DoEmote gesperrt)
ChatEdit_SendText = function() error("darf fuer Emotes nicht benutzt werden") end
assert(Chat:Send("guild", "/winken"))
assert(emotes[1][1] == "WAVE" and emotes[1][2] == nil, "an das aktuelle Ziel")
assert(Chat:Send("guild", "/WAVE Lyra") and emotes[2][1] == "WAVE" and emotes[2][2] == "Lyra")
-- andere Befehle gehen weiter an den WoW-Chat
local sent
ChatEdit_SendText = function(box) sent = box.t end
DEFAULT_CHAT_FRAME = {editBox = {SetText = function(self, t) self.t = t end}}
assert(Chat:Send("guild", "/s hallo") and sent == "/s hallo")

-- 8) Ersetzter WoW-Chat: Fluestern aus WoW-Menues und Antworten-Taste landen hier
local UI = {shown = {}}
function UI:Show(view) self.shown[#self.shown + 1] = view or "?" end
function UI:OpenInput(view, text) self:Show(view) if text and text ~= "" then self.input:SetText(text) end return true end
UI.input = {SetFocus = function() end, SetText = function(self, t) self.t = t end}
c.UI = UI
CreateFrame = function() return {Hide = function() end, SetScript = function() end, RegisterEvent = function() end} end
UIParent = {}
SLASH_SMART_WHISPER1 = "/w"
local hooks = {}
hooksecurefunc = function(a, b, c2)
    if type(a) == "table" then hooks["util." .. b] = c2 else hooks[a] = b end
end
ChatFrame_OpenChat, ChatFrame_SendTell, ChatFrame_ReplyTell = function() end, function() end, function() end
-- neuer Client: Blizzards Menues rufen ChatFrameUtil direkt (Spieltest 26.11.2026: Gildenmenue › Fluestern)
ChatFrameUtil = {OpenChat = function() end, SendTell = function() end, ReplyTell = function() end, ReplyTell2 = function() end}
assert(loadfile(root .. "/ONE_Chat/Hider.lua"))("ONE_Chat", c)
local H = c.Hider
H.Enabled = function() return true end
H:HookOpeners()
assert(hooks.ChatFrame_OpenChat and hooks.ChatFrame_SendTell and hooks.ChatFrame_ReplyTell, "Haken gesetzt")
hooks.ChatFrame_OpenChat("/w Lyra Hallo du")
assert(UI.shown[#UI.shown] == "w:Lyra" and UI.input.t == "Hallo du", "Fluestern aus WoW -> Gespraech hier")
hooks.ChatFrame_OpenChat("/ginvite ")
assert(UI.input.t == "/ginvite ", "anderer Text ins Eingabefeld")
Chat.lastWhisperFrom = "Bonsai"
hooks.ChatFrame_ReplyTell()
assert(UI.shown[#UI.shown] == "w:Bonsai", "Antworten-Taste")
-- ChatFrameUtil (Gildenmenue, Freunde): SendTell ruft intern auch OpenChat -> nur EIN Oeffnen
assert(hooks["util.SendTell"] and hooks["util.OpenChat"] and hooks["util.ReplyTell"], "ChatFrameUtil-Haken gesetzt")
local timers = {}
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local before = #UI.shown
hooks["util.OpenChat"]("/w Thrall-Forever ")
hooks["util.SendTell"]("Thrall-Forever")
assert(#timers == 1, "ein Zeitgeber fuer beide Haken")
timers[1]()
assert(#UI.shown == before + 1 and UI.shown[#UI.shown] == "w:Thrall", "Gildenmenue › Fluestern: Gespraech hier (einmal)")
C_Timer = nil
-- WoW-Chat nicht ersetzt: nichts abfangen
H.Enabled = function() return false end
local n = #UI.shown
hooks.ChatFrame_OpenChat("/w Lyra x")
assert(#UI.shown == n, "ohne Ersetzen unveraendert")
print("OK test_chatall_154")
