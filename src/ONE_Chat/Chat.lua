-- Guild Trip Chat: Kern (Nachrichten sammeln, Gespraeche, Reiter, Senden).
-- Freiwilliger Ersatz fuer den WoW-Chat "wie ein Messenger" (Nutzer-Wunsch 15.11.2026):
--  * jedes Gespraech schreibt nur dorthin, wo es hingehoert (Gilde -> Gildenchat,
--    Fluestern -> nur diese Person, Handel -> nur Handelskanal …)
--  * Fluestern als eigene Gespraeche (wie Chats in einem Messenger), Zaehler fuer Ungelesenes
--  * eigene Reiter mit frei gewaehlten Arten
-- Was Blizzard verlangt bzw. erwartet:
--  * Nachrichtenfilter (ChatFrame_AddMessageEventFilter, Spamfilter anderer Addons) gelten auch hier
--  * Ignorierte Spieler erscheinen nicht; Ignorieren/Melden stehen im Namens-Menue
--  * Sagen/Schreien/Kanaele nur per Enter (Tastendruck des Spielers) – nie automatisch
-- Der WoW-Chat bleibt daneben bestehen (Stufe 1).
local _, chat = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Chat = {buffers = {}, unread = {}, whispers = {}, maxLines = 300, listeners = {}}
chat.Chat = Chat

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
Chat.Short = Short

-- Arten von Nachrichten: Ereignisse, Farbe, wohin man schreibt
Chat.KINDS = {
    {key = "guild", label = "Gilde", events = {"CHAT_MSG_GUILD"}, send = "GUILD", color = {.25, 1, .25}},
    {key = "officer", label = "Offiziere", events = {"CHAT_MSG_OFFICER"}, send = "OFFICER", color = {.25, .75, .25}},
    {key = "group", label = "Gruppe", events = {"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER"}, send = "GROUP", color = {.67, .67, 1}},
    {key = "say", label = "Sagen", events = {"CHAT_MSG_SAY"}, send = "SAY", color = {1, 1, 1}},
    {key = "yell", label = "Schreien", events = {"CHAT_MSG_YELL"}, send = "YELL", color = {1, .25, .25}},
    {key = "emote", label = "Emotes", events = {"CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE"}, send = "EMOTE", color = {1, .5, .25}},
    {key = "trade", label = "Handel", channel = true, send = "CHANNEL", color = {1, .75, .75}},
    {key = "general", label = "Allgemein", channel = true, send = "CHANNEL", color = {1, .75, .75}},
    {key = "lfg", label = "Gruppensuche", channel = true, send = "CHANNEL", color = {1, .75, .75}},
    {key = "channel", label = "Andere Kanäle", channel = true, color = {1, .75, .75}},
    {key = "whisper", label = "Flüstern", events = {"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM"}, send = "WHISPER", color = {1, .5, 1}},
    {key = "system", label = "System", events = {"CHAT_MSG_SYSTEM"}, color = {1, 1, 0}},
}
Chat.kindByKey, Chat.kindByEvent = {}, {}
for _, k in ipairs(Chat.KINDS) do
    Chat.kindByKey[k.key] = k
    for _, e in ipairs(k.events or {}) do Chat.kindByEvent[e] = k.key end
end
Chat.kindByEvent.CHAT_MSG_CHANNEL = "channel"

-- Kanalname -> Art (deutsch und englisch, Gross/Klein egal)
Chat.channelKinds = {
    {"handel", "trade"}, {"trade", "trade"}, {"allgemein", "general"}, {"general", "general"},
    {"suchenachgruppe", "lfg"}, {"lookingforgroup", "lfg"}, {"gruppensuche", "lfg"},
}
function Chat.ChannelKind(name)
    local low = tostring(name or ""):lower():gsub("^%d+%.%s*", ""):gsub("%s", "")
    for _, c in ipairs(Chat.channelKinds) do if low:find(c[1], 1, true) == 1 then return c[2] end end
    return "channel"
end

-- ===== Andere Chat-Addons (ElvUI & Co., 15.11.2026) =====
-- Sie bauen den WoW-Chat selbst um. Guild Trip laeuft daneben, aber:
--  * "WoW-Chat ausblenden" bleibt gesperrt (zwei Addons wuerden um dieselben Fenster kaempfen)
--  * Hinweis im Zahnrad (doppelte Toene vermeiden), schlichtes Aussehen als Vorgabe
Chat.otherChatAddons = {
    {"ElvUI", "ElvUI"}, {"Prat-3.0", "Prat"}, {"Chatter", "Chatter"}, {"Glass", "Glass"},
    {"Tukui", "Tukui"}, {"GW2_UI", "GW2 UI"}, {"BasicChatMods", "BasicChatMods"}, {"WIM", "WIM"},
}
-- Name des ersten geladenen Chat-Addons oder nil
function Chat.OtherChatAddon()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if type(loaded) ~= "function" then return nil end
    for _, a in ipairs(Chat.otherChatAddons) do
        if Call(loaded, a[1]) then return a[2] end
    end
end
-- Darf Guild Trip den WoW-Chat ausblenden? (Stufe 3) Nein, solange ein Chat-Addon laeuft.
function Chat:CanHideBlizzardChat()
    local other = self.OtherChatAddon()
    if other then return false, T("%s verwaltet den WoW-Chat – Ausblenden ist deshalb gesperrt.", other) end
    return true
end
-- Schlichtes Aussehen: eingestellt, sonst automatisch bei ElvUI & Co.
function Chat:Flat()
    local f = self:Settings().flat
    if f == nil then return self.OtherChatAddon() ~= nil end
    return f == true
end

-- ===== Einstellungen und Reiter =====
Chat.DEFAULT_TABS = {
    {id = "all", label = "Alle", kinds = {guild = true, officer = true, group = true, say = true, yell = true, emote = true,
        whisper = true, system = true, trade = true, general = true, lfg = true, channel = true}, send = "guild", builtin = true},
    {id = "guild", label = "Gilde", kinds = {guild = true, officer = true}, send = "guild", builtin = true},
    {id = "group", label = "Gruppe", kinds = {group = true}, send = "group", builtin = true},
    {id = "trade", label = "Handel", kinds = {trade = true}, send = "trade", builtin = true},
    {id = "near", label = "In der Nähe", kinds = {say = true, yell = true, emote = true}, send = "say", builtin = true},
}
function Chat:Settings()
    ONE.db.chat = type(ONE.db.chat) == "table" and ONE.db.chat or {}
    local s = ONE.db.chat
    if type(s.tabs) ~= "table" then
        s.tabs = {}
        for _, t in ipairs(self.DEFAULT_TABS) do
            local kinds = {}
            for k, v in pairs(t.kinds) do kinds[k] = v end
            s.tabs[#s.tabs + 1] = {id = t.id, label = t.label, kinds = kinds, send = t.send, builtin = true}
        end
    end
    if s.fontSize == nil then s.fontSize = 14 end
    if s.opacity == nil then s.opacity = 1 end      -- Deckkraft des Hintergrunds (0.2 … 1)
    if s.idleAlpha == nil then s.idleAlpha = 1 end  -- ganzes Fenster, wenn die Maus weg ist (1 = nicht ausblenden)
    if s.spacing == nil then s.spacing = 2 end
    if s.lookVersion ~= 2 then s.lookVersion = 2 s.spacing = 2 end -- 17.11.2026: luftigeres Aussehen
    if s.stamps == nil then s.stamps = true end
    if s.blink == nil then s.blink = true end
    if s.whisperSound == nil then s.whisperSound = true end
    if s.guildSound == nil then s.guildSound = false end
    if s.groupSound == nil then s.groupSound = false end
    if s.sentSound == nil then s.sentSound = false end
    return s
end
function Chat:Tabs() return self:Settings().tabs end
function Chat:Tab(id) for _, t in ipairs(self:Tabs()) do if t.id == id then return t end end end

-- Eigenen Reiter anlegen/aendern: kinds = {art = true}, send = Art, in die geschrieben wird
function Chat:SaveTab(def)
    if type(def) ~= "table" or type(def.label) ~= "string" or not def.label:match("%S") then return nil end
    local tabs = self:Tabs()
    local tab = def.id and self:Tab(def.id)
    if not tab then
        tab = {id = "c" .. tostring(#tabs + 1) .. tostring(math.random and math.random(100, 999) or 100)}
        tabs[#tabs + 1] = tab
    end
    tab.label = def.label:sub(1, 20)
    tab.kinds = {}
    for k, on in pairs(def.kinds or {}) do if on and self.kindByKey[k] then tab.kinds[k] = true end end
    tab.send = self.kindByKey[def.send or ""] and self.kindByKey[def.send].send and def.send or nil
    return tab
end
function Chat:RemoveTab(id)
    for i, t in ipairs(self:Tabs()) do
        if t.id == id and not t.builtin then table.remove(self:Tabs(), i) return true end
    end
    return false
end

-- ===== Nachrichten sammeln =====
-- Ansicht ("view"): Reiter-ID oder "w:<Name>" fuer ein Fluestergespraech
function Chat:Buffer(view)
    self.buffers[view] = self.buffers[view] or {}
    return self.buffers[view]
end
function Chat.WhisperView(name) return "w:" .. Short(name) end

-- Blizzards Nachrichtenfilter (Spamfilter usw.) anwenden. Ergebnis: nil = verwerfen, sonst Argumente
function Chat:Filter(event, ...)
    local args = {...}
    local filters = type(ChatFrame_GetMessageEventFilters) == "function" and Call(ChatFrame_GetMessageEventFilters, event)
    if type(filters) == "table" then
        for _, fn in ipairs(filters) do
            local ok, stop, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14 =
                pcall(fn, _G.DEFAULT_CHAT_FRAME, event, unpack(args, 1, 14))
            if ok then
                if stop then return nil end
                if a1 ~= nil then args = {a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14} end
            end
        end
    end
    return args
end

-- Ereignis -> Eintrag; liefert den Eintrag (oder nil, wenn verworfen)
function Chat:OnEvent(event, ...)
    local kind = self.kindByEvent[event]
    if not kind then return nil end
    local args = self:Filter(event, ...)
    if not args then return nil end
    local text, author = args[1], args[2]
    local channelName, lineID, guid = args[4], args[11], args[12]
    if kind == "channel" then kind = Chat.ChannelKind(args[9] or channelName) end
    -- Ignorierte nie zeigen (Fluestern blockt der Server, Kanaele nicht immer)
    if author and author ~= "" and C_FriendList and type(C_FriendList.IsIgnored) == "function" and Call(C_FriendList.IsIgnored, author) then
        return nil
    end
    local entry = {time = (type(time) == "function" and time()) or 0, kind = kind, event = event, text = text or "",
        author = author or "", channel = channelName, lineID = lineID, guid = guid,
        inform = event == "CHAT_MSG_WHISPER_INFORM"}
    self:Store(entry)
    return entry
end

function Chat:Store(entry)
    local views = {}
    if entry.kind == "whisper" then
        local view = self.WhisperView(entry.author)
        views[#views + 1] = view
        self:TouchWhisper(Short(entry.author), not entry.inform)
    end
    for _, t in ipairs(self:Tabs()) do if t.kinds[entry.kind] then views[#views + 1] = t.id end end
    for _, view in ipairs(views) do
        local buf = self:Buffer(view)
        buf[#buf + 1] = entry
        if #buf > self.maxLines then table.remove(buf, 1) end
        -- ungelesen, ausser man schaut gerade hin (eigene Fluester-Antworten nie)
        if not entry.inform and not (self.visible and self.current == view) then
            self.unread[view] = (self.unread[view] or 0) + 1
        end
    end
    for _, fn in ipairs(self.listeners) do pcall(fn, entry, views) end
end

-- Fluestergespraeche: zuletzt aktive zuerst
function Chat:TouchWhisper(name, incoming)
    for i, w in ipairs(self.whispers) do
        if w.name == name then table.remove(self.whispers, i) break end
    end
    table.insert(self.whispers, 1, {name = name, last = (type(time) == "function" and time()) or 0})
    if incoming then self.lastWhisperFrom = name end
end
function Chat:OpenWhisper(name)
    name = Short(name)
    local found = false
    for _, w in ipairs(self.whispers) do if w.name == name then found = true end end
    if not found then table.insert(self.whispers, 1, {name = name, last = 0}) end
    return self.WhisperView(name)
end
function Chat:CloseWhisper(name)
    for i, w in ipairs(self.whispers) do if w.name == name then table.remove(self.whispers, i) return true end end
end

function Chat:MarkRead(view) self.unread[view] = nil end
function Chat:UnreadTotal()
    local n = 0
    for _, c in pairs(self.unread) do n = n + c end
    return n
end

-- ===== Klaenge (15.11.2026): dezent, je Art abschaltbar =====
-- Fluestern: eigener Klang; Gilde/Gruppe: leises "Pling" hoechstens alle 3 Sekunden; Senden: Tippen
Chat.soundGap = 3
function Chat:PlaySound(key)
    if not (ONE.Sound and ONE.Sound.PlayAlert) then return false end
    return ONE.Sound:PlayAlert(key)
end
-- views: Ansichten, in denen die Nachricht erscheint. Kein Klang, wenn man eine davon gerade
-- ansieht (Fenster offen und aktiv) – nur Nachrichten "nebenan" machen sich bemerkbar.
function Chat:SoundFor(entry, views)
    local s = self:Settings()
    if entry.inform then return nil end
    if self.visible and self.current then
        for _, v in ipairs(views or {}) do if v == self.current then return nil end end
    end
    if entry.kind == "whisper" then return s.whisperSound and "chatWhisper" or nil end
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local want = (entry.kind == "guild" or entry.kind == "officer") and s.guildSound
        or entry.kind == "group" and s.groupSound
    if not want then return nil end
    -- eigene Nachrichten nicht (der Server schickt sie zurueck)
    local me = type(UnitName) == "function" and Call(UnitName, "player")
    if me and Short(entry.author) == me then return nil end
    if self.lastPling and now - self.lastPling < self.soundGap then return nil end
    self.lastPling = now
    return "chatMessage"
end

-- ===== Senden =====
-- Kanalnummer eines Kanals der Art (trade/general/lfg) aus den beigetretenen Kanaelen
function Chat.ChannelNumber(kind)
    -- alle Rueckgabewerte (je Kanal: Nummer, Name, gesperrt) – Call() liefert nur drei
    if type(GetChannelList) ~= "function" then return nil end
    local res = {pcall(GetChannelList)}
    if not res[1] then return nil end
    local list = {}
    for i = 2, #res do list[#list + 1] = res[i] end
    for i = 1, #list, 3 do
        local id, name = list[i], list[i + 1]
        if type(id) == "number" and Chat.ChannelKind(name) == kind then return id end
    end
end

-- Ziel einer Ansicht: {chatType, target} oder nil + Hinweis
function Chat:Target(view)
    if type(view) == "string" and view:sub(1, 2) == "w:" then return "WHISPER", view:sub(3) end
    local tab = self:Tab(view)
    local kind = tab and tab.send and self.kindByKey[tab.send]
    if not kind or not kind.send then return nil, T("In diesem Reiter kann man nicht schreiben.") end
    if kind.send == "GROUP" then
        if Call(IsInRaid) then return "RAID" end
        if LE_PARTY_CATEGORY_INSTANCE and Call(IsInGroup, LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
        if Call(IsInGroup) then return "PARTY" end
        return nil, T("Du bist in keiner Gruppe.")
    end
    if kind.send == "CHANNEL" then
        local n = Chat.ChannelNumber(kind.key)
        if not n then return nil, T("Du bist nicht im Kanal %s.", T(kind.label)) end
        return "CHANNEL", n
    end
    return kind.send
end

-- Text aus dem Eingabefeld senden. Slash-Befehle gehen an den WoW-Chat.
-- Rueckgabe: true oder nil + Hinweis
function Chat:Send(view, text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    if text:sub(1, 1) == "/" then
        local box = (type(ChatEdit_ChooseBoxForSend) == "function" and Call(ChatEdit_ChooseBoxForSend))
            or (_G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.editBox)
        if not (box and type(ChatEdit_SendText) == "function") then return nil, T("Befehle gehen hier nicht – bitte im WoW-Chat.") end
        box:SetText(text)
        Call(ChatEdit_SendText, box, 0)
        return true
    end
    local chatType, target = self:Target(view)
    if not chatType then return nil, target end
    if type(SendChatMessage) ~= "function" then return nil, T("Senden geht in diesem Client nicht.") end
    for part in Chat.Split(text, 255) do
        local ok = pcall(SendChatMessage, part, chatType, nil, target)
        if not ok then return nil, T("Senden ging nicht.") end
    end
    if self:Settings().sentSound then self:PlaySound("chatSent") end
    return true
end

-- Lange Texte in Stuecke zu hoechstens max Zeichen (an Leerzeichen)
function Chat.Split(text, max)
    local parts = {}
    while #text > max do
        local cut = text:sub(1, max):match("^.*()%s") or max + 1
        parts[#parts + 1] = text:sub(1, cut - 1)
        text = text:sub(cut):gsub("^%s+", "")
    end
    if text ~= "" then parts[#parts + 1] = text end
    local i = 0
    return function() i = i + 1 return parts[i] end
end

-- ===== Darstellung einer Zeile =====
-- Klassenfarben fuer Pergament: dunkler, aber im Ton der Klasse (Weiss/Gelb waeren unlesbar).
-- Alpha "fe" markiert "schon pergamenttauglich" – Book.InkCodes laesst sie dann unveraendert.
Chat.parchmentClass = {
    WARRIOR = "7a4f22", PALADIN = "a3306b", HUNTER = "4a7418", ROGUE = "8a7300", PRIEST = "4e5666",
    SHAMAN = "00519e", MAGE = "1a7aa0", WARLOCK = "5a3d9c", DRUID = "b05000",
}
function Chat.ClassColorCode(guid, parchment)
    if not guid or guid == "" or type(GetPlayerInfoByGUID) ~= "function" then return nil end
    local _, class = Call(GetPlayerInfoByGUID, guid)
    if not class then return nil end
    if parchment and Chat.parchmentClass[class] then return "|cfe" .. Chat.parchmentClass[class] end
    local colors = rawget(_G, "CUSTOM_CLASS_COLORS") or rawget(_G, "RAID_CLASS_COLORS")
    local c = colors and colors[class]
    if c then
        if c.colorStr then return "|c" .. c.colorStr end
        if c.r then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    end
    local color = C_ClassColor and Call(C_ClassColor.GetClassColor, class)
    if color and color.GenerateHexColorMarkup then return Call(color.GenerateHexColorMarkup, color) end
end

-- Zeile als Text mit Farbcodes; showKind = Art voranstellen (im Reiter "Alle")
function Chat:Format(entry, showKind)
    local s = self:Settings()
    local parts = {}
    if s.stamps and type(date) == "function" then parts[#parts + 1] = "|cff8a8a8a" .. date("%H:%M", entry.time) .. "|r " end
    local kind = self.kindByKey[entry.kind]
    if showKind and kind and entry.kind ~= "system" then parts[#parts + 1] = "[" .. T(kind.label) .. "] " end
    if entry.kind == "system" then
        parts[#parts + 1] = entry.text
        return table.concat(parts)
    end
    local name = Short(entry.author)
    local code = self.ClassColorCode(entry.guid, self.parchment)
    local shown = code and (code .. name .. "|r") or name
    local link = "|Hplayer:" .. (entry.author or name) .. ":" .. tostring(entry.lineID or 0) .. "|h" .. shown .. "|h"
    if entry.inform then
        parts[#parts + 1] = T("An %s", link) .. ": "
    elseif entry.event == "CHAT_MSG_TEXT_EMOTE" then
        parts[#parts + 1] = entry.text
        return table.concat(parts)
    elseif entry.kind == "emote" then
        parts[#parts + 1] = link .. " "
    else
        parts[#parts + 1] = link .. ": "
    end
    parts[#parts + 1] = entry.text
    return table.concat(parts)
end
