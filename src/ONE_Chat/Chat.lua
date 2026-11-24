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
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
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
    {key = "whisper", label = "Flüstern", events = {"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM"}, send = "WHISPER", color = {1, .5, 1}},
    {key = "system", label = "System", events = {"CHAT_MSG_SYSTEM",
        "CHAT_MSG_BN_INLINE_TOAST_ALERT", "CHAT_MSG_BN_INLINE_TOAST_BROADCAST", "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE",
        -- 22.11.2026 (Pruefung "alle WoW-Chatfunktionen"): Kanal-Meldungen, Erfolge, Schlachtfeld, Ignoriert, Gefiltert
        "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT",
        "CHAT_MSG_BG_SYSTEM_NEUTRAL", "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE",
        "CHAT_MSG_IGNORED", "CHAT_MSG_FILTERED", "CHAT_MSG_RESTRICTED"}, color = {1, 1, 0}},
    -- NPCs (Questgeber, Bosse): fehlten, solange der WoW-Chat ersetzt ist
    {key = "npc", label = "NPC-Gespräche", events = {"CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE",
        "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_MONSTER_PARTY", "CHAT_MSG_RAID_BOSS_EMOTE", "CHAT_MSG_RAID_BOSS_WHISPER"}, color = {1, 1, .62}},
    -- Beute, Geld, Erfahrung, Ruf, Fertigkeiten: eigenes Gespraech (stumm), damit nichts verloren geht
    {key = "progress", label = "Beute & Fortschritt", events = {"CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_CURRENCY",
        "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_COMBAT_HONOR_GAIN", "CHAT_MSG_SKILL",
        "CHAT_MSG_TRADESKILLS", "CHAT_MSG_OPENING", "CHAT_MSG_PET_INFO"}, color = {.55, .8, 1}},
}
-- Abwesend/Nicht stoeren: automatische Antwort gehoert ins Fluestergespraech (ohne Zaehler und Ton)
Chat.autoReplyEvents = {CHAT_MSG_AFK = "Abwesend", CHAT_MSG_DND = "Nicht stören"}
Chat.kindByKey, Chat.kindByEvent = {}, {}
for _, k in ipairs(Chat.KINDS) do
    Chat.kindByKey[k.key] = k
    for _, e in ipairs(k.events or {}) do Chat.kindByEvent[e] = k.key end
end
Chat.kindByEvent.CHAT_MSG_CHANNEL = "channel"
for e in pairs(Chat.autoReplyEvents) do Chat.kindByEvent[e] = "whisper" end
-- als schlichte Zeile zeigen (ohne Blase/Namen): Arten und einzelne Ereignisse
Chat.plainKinds = {system = true, progress = true}
Chat.plainEvents = {CHAT_MSG_TEXT_EMOTE = true, CHAT_MSG_MONSTER_EMOTE = true, CHAT_MSG_RAID_BOSS_EMOTE = true}
function Chat.IsPlain(entry)
    return type(entry) == "table" and (Chat.plainKinds[entry.kind] or Chat.plainEvents[entry.event] or false) and true or false
end
-- "%s" im Text durch den Namen ersetzen (NPC-Emotes, Erfolge – so macht es auch der WoW-Chat)
function Chat.FillName(text, name)
    text = tostring(text or "")
    if not text:find("%s", 1, true) then return text end
    local ok, out = pcall(string.format, (text:gsub("%%([^s])", "%%%%%1")), tostring(name or ""))
    return ok and out or text
end
-- Kanal-Meldung ("Kanal betreten: 2. Handel") aus dem Kennwort von WoW
function Chat.ChannelNoticeText(event, token, args)
    local fmt = rawget(_G, "CHAT_" .. tostring(token) .. "_NOTICE_BN") or rawget(_G, "CHAT_" .. tostring(token) .. "_NOTICE")
    if type(fmt) ~= "string" then return nil end
    local num, name = args[8], args[4]
    local ok, out
    if event == "CHAT_MSG_CHANNEL_NOTICE_USER" then
        ok, out = pcall(string.format, fmt, num, name, args[2], args[5])
    else
        ok, out = pcall(string.format, fmt, num, name)
    end
    return ok and out or nil
end

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
    local s = self:Settings()
    if s.look == "flat" then return true end
    if s.look == "glass" or s.look == "native" then return false end
    local f = s.flat
    if f == nil then return self.OtherChatAddon() ~= nil end
    return f == true
end
-- Aussehen des Chats (Nutzer 19.11.2026: eigene Wahl nur fuer den Chat):
-- "auto" = wie das Hauptfenster, sonst "glass", "native" oder "flat". Liefert das wirksame Aussehen.
function Chat:Look()
    if self:Flat() then return "flat" end
    local look = self:Settings().look
    if look == "glass" or look == "native" then return look end
    local G = ONE.Glass
    if not (G and G.Active) or not G:Active() then return "native" end
    return "glass"
end
-- Glas-Farben nur fuer den Chat: nil = wie das Hauptfenster
function Chat:GlassStore()
    local g = self:Settings().glass
    return type(g) == "table" and g or nil
end

-- ===== Einstellungen und Reiter =====
Chat.DEFAULT_TABS = {
    {id = "all", label = "Alle", kinds = {guild = true, officer = true, group = true, say = true, yell = true, emote = true,
        whisper = true, system = true, trade = true, general = true, lfg = true, channel = true, npc = true}, send = "general", builtin = true},
    {id = "guild", label = "Gilde", kinds = {guild = true, officer = true}, send = "guild", builtin = true},
    {id = "group", label = "Gruppe", kinds = {group = true}, send = "group", builtin = true},
    {id = "trade", label = "Handel", kinds = {trade = true}, send = "trade", builtin = true},
    {id = "near", label = "In der Nähe", kinds = {say = true, yell = true, emote = true, npc = true}, send = "say", builtin = true},
    -- 21.11.2026: Systemzeilen und Meldungen anderer Addons als eigenes Gespraech (Messenger)
    {id = "system", label = "System & Addons", kinds = {system = true}, builtin = true},
    -- 22.11.2026: Beute, Geld, Erfahrung, Ruf (stumm)
    {id = "progress", label = "Beute & Fortschritt", kinds = {progress = true}, builtin = true},
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
    -- 19.11.2026 (Nutzer): "Alle" schreibt in den Allgemein-Kanal (/1), nicht mehr in die Gilde
    if s.allSendV ~= 1 then
        s.allSendV = 1
        for _, t in ipairs(s.tabs) do if t.id == "all" and t.builtin and t.send == "guild" then t.send = "general" end end
    end
    -- 21.11.2026: Gespraech "System & Addons" bei bestehenden Reitern nachtragen
    if s.sysTabV ~= 1 then
        s.sysTabV = 1
        local has = false
        for _, t in ipairs(s.tabs) do if t.id == "system" then has = true end end
        if not has then s.tabs[#s.tabs + 1] = {id = "system", label = "System & Addons", kinds = {system = true}, builtin = true} end
    end
    -- 23.11.2026 (Nutzer): Chat soll dem Design des Hauptfensters folgen. Eine Kopie mit
    -- fertigem Skin entstand oft aus Versehen (ein Klick auf den Durchschalt-Knopf im Zahnrad)
    -- und koppelte den Chat ab. Nur eigene Farben ("custom") bleiben.
    if s.glassFollowV ~= 1 then
        s.glassFollowV = 1
        if type(s.glass) == "table" and s.glass.skin ~= "custom" then s.glass = nil end
    end
    -- 22.11.2026: NPC-Gespraeche (in "Alle" und "In der Naehe") und "Beute & Fortschritt" nachtragen
    if s.npcTabV ~= 1 then
        s.npcTabV = 1
        local has = false
        for _, t in ipairs(s.tabs) do
            if t.builtin and (t.id == "all" or t.id == "near") and type(t.kinds) == "table" then t.kinds.npc = true end
            if t.id == "progress" then has = true end
        end
        if not has then s.tabs[#s.tabs + 1] = {id = "progress", label = "Beute & Fortschritt", kinds = {progress = true}, builtin = true} end
        if type(s.muted) == "table" then s.muted.progress = true end
    end
    -- Messenger (Nutzer 21.11.2026): Stil, angeheftete und stumme Gespraeche, Emojis
    if s.style ~= "classic" then s.style = "messenger" end
    if type(s.pinned) ~= "table" then s.pinned = {"guild"} end
    if type(s.muted) ~= "table" then s.muted = {trade = true, progress = true} end
    if s.emojiImages == nil then s.emojiImages = true end
    if s.asciiSmileys == nil then s.asciiSmileys = true end
    if s.bigEmoji == nil then s.bigEmoji = true end
    if s.bubbleColors == nil then s.bubbleColors = true end
    if s.classIcons == nil then s.classIcons = true end
    if s.fontSize == nil then s.fontSize = 14 end
    if s.opacity == nil then s.opacity = 1 end      -- Deckkraft des Hintergrunds (0 … 1, 0 = durchsichtig)
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

-- ===== Battle.net (Spieltest 21.11.2026: Nachrichten aus dem Launcher fehlten) =====
-- Battle.net-Freunde fluestern ueber eigene Ereignisse (CHAT_MSG_BN_*). Der Absender kommt dort als
-- verschluesselter Anzeigename, der nur bis zum Ausloggen gilt – als Name nehmen wir deshalb die BattleTag
-- ("Name#1234"; Charakternamen haben nie ein #). Gesendet wird an die Konto-Nummer (BNSendWhisper).
Chat.bnIds = {}
function Chat.IsBN(name) return type(name) == "string" and name:find("#", 1, true) ~= nil end
-- Konto-Nummer -> {tag, online, zone, character, game}
function Chat.BNInfo(id)
    if type(id) ~= "number" or id == 0 then return nil end
    if C_BattleNet and type(C_BattleNet.GetAccountInfoByID) == "function" then
        local a = Call(C_BattleNet.GetAccountInfoByID, id)
        if type(a) == "table" and a.battleTag then
            local g = type(a.gameAccountInfo) == "table" and a.gameAccountInfo or {}
            return {tag = a.battleTag, online = (g.isOnline or a.isOnline) and true or false, zone = g.areaName or g.richPresence,
                character = g.characterName, level = g.characterLevel, class = g.className, id = a.bnetAccountID or id}
        end
    end
    if type(BNGetFriendInfoByID) == "function" then
        local ok, acc, _, tag, _, character, _, _, online = pcall(BNGetFriendInfoByID, id)
        if ok and tag then return {tag = tag, online = online and true or false, character = character, id = acc or id} end
    end
end
-- BattleTag -> Konto-Nummer (aus den letzten Nachrichten, sonst aus der Freundesliste)
function Chat.BNFind(tag)
    if Chat.bnIds[tag] then return Chat.bnIds[tag] end
    local n = type(BNGetNumFriends) == "function" and Call(BNGetNumFriends) or 0
    for i = 1, tonumber(n) or 0 do
        local id, t
        if C_BattleNet and type(C_BattleNet.GetFriendAccountInfo) == "function" then
            local a = Call(C_BattleNet.GetFriendAccountInfo, i)
            if type(a) == "table" then id, t = a.bnetAccountID, a.battleTag end
        elseif type(BNGetFriendInfo) == "function" then
            local ok, acc, _, bt = pcall(BNGetFriendInfo, i)
            if ok then id, t = acc, bt end
        end
        if t == tag and id then Chat.bnIds[tag] = id return id end
    end
end
-- Name zur Konto-Nummer (BattleTag), merkt sich die Nummer fuers Antworten; sonst der Anzeigename
function Chat.BNName(id, fallback)
    local info = Chat.BNInfo(id)
    if info and info.tag then Chat.bnIds[info.tag] = id return info.tag end
    return fallback
end
-- Battle.net-Hinweis ("X ist jetzt online", Rundruf …) als Systemtext
function Chat.BNToastText(event, token, name, text)
    if event == "CHAT_MSG_BN_INLINE_TOAST_BROADCAST" then
        local fmt = rawget(_G, "BN_INLINE_TOAST_BROADCAST")
        local ok, out = pcall(string.format, type(fmt) == "string" and fmt or "%s: %s", name or "?", text or "")
        return ok and out or ((name or "?") .. ": " .. (text or ""))
    end
    local fmt = type(token) == "string" and rawget(_G, "BN_INLINE_TOAST_" .. token)
    if type(fmt) ~= "string" then return nil end
    if fmt:find("%d", 1, true) then
        local n = type(BNGetNumFriendInvites) == "function" and Call(BNGetNumFriendInvites) or 0
        local ok, out = pcall(string.format, fmt, tonumber(n) or 0)
        return ok and out or nil
    end
    if fmt:find("%s", 1, true) then
        local ok, out = pcall(string.format, fmt, name or "?")
        return ok and out or nil
    end
    return fmt
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
    local bn = event:find("^CHAT_MSG_BN_") ~= nil
    if bn then
        author = Chat.BNName(args[13], author)
        guid = nil
        if event == "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE" then
            -- offline: offene Nachricht an die Person rot markieren, sonst nur ein Hinweis
            if author and self:FailPendingFor(author) then return nil end
            local fmt = rawget(_G, "BN_WHISPER_PLAYER_OFFLINE") or rawget(_G, "ERR_FRIEND_OFFLINE_S")
            local ok, out = pcall(string.format, type(fmt) == "string" and fmt or "%s ist offline.", author or "?")
            text, author = ok and out or tostring(author), ""
        elseif kind == "system" then
            text = Chat.BNToastText(event, text, author, args[1])
            if not text then return nil end
            author = ""
        end
    end
    local auto
    if not bn then
        if event == "CHAT_MSG_CHANNEL_NOTICE" or event == "CHAT_MSG_CHANNEL_NOTICE_USER" then
            text = Chat.ChannelNoticeText(event, text, args)
            if not text then return nil end
            author = ""
        elseif event == "CHAT_MSG_IGNORED" then
            local fmt = rawget(_G, "CHAT_IGNORED")
            local ok, out = pcall(string.format, type(fmt) == "string" and fmt or "%s ignoriert dich.", Short(author))
            text, author = ok and out or tostring(author), ""
        elseif event == "CHAT_MSG_ACHIEVEMENT" or event == "CHAT_MSG_GUILD_ACHIEVEMENT" then
            text, author = Chat.FillName(text, Short(author)), ""
        elseif Chat.plainEvents[event] or event == "CHAT_MSG_RAID_BOSS_WHISPER" then
            text = Chat.FillName(text, author)
        elseif Chat.autoReplyEvents[event] then
            auto = T(Chat.autoReplyEvents[event])
        end
    end
    -- Ignorierte nie zeigen (Fluestern blockt der Server, Kanaele nicht immer)
    if not bn and author and author ~= "" and C_FriendList and type(C_FriendList.IsIgnored) == "function" and Call(C_FriendList.IsIgnored, author) then
        return nil
    end
    local entry = {time = (type(time) == "function" and time()) or 0, kind = kind, event = event, text = text or "",
        author = author or "", channel = channelName, lineID = lineID, guid = guid, bn = bn or nil,
        inform = event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER_INFORM",
        npc = kind == "npc" or nil, auto = auto and true or nil}
    if auto then entry.text = auto .. ": " .. tostring(text or "") end
    -- Zugestellt-Haken: die Bestaetigung des Servers ersetzt die schon gezeigte eigene Nachricht
    if entry.inform then
        local pending = self:ConfirmPending(entry)
        if pending then return pending end
    elseif kind == "system" and self:FailPending(entry.text) then
        return nil
    end
    self:Store(entry)
    return entry
end

-- ===== Fluestern: zugestellt / nicht zugestellt (21.11.2026) =====
-- Beim Senden erscheint die Nachricht sofort (pending). Der Server bestaetigt jedes zugestellte Fluestern
-- (CHAT_MSG_WHISPER_INFORM) – dann Haken. Ist die Person offline, kommt statt dessen die Systemmeldung
-- "Kein Spieler namens …" – dann rote Blase "nicht zugestellt". Reihenfolge je Person: aelteste zuerst.
Chat.pending = {}
Chat.PENDING_WAIT = 6
function Chat:AddPending(name, text)
    name = Short(name)
    local entry = {time = (type(time) == "function" and time()) or 0, kind = "whisper", event = "CHAT_MSG_WHISPER_INFORM", text = text, author = name,
        inform = true, pending = true, sentAt = (type(GetTime) == "function" and GetTime()) or 0}
    self.pending[name] = self.pending[name] or {}
    table.insert(self.pending[name], entry)
    self:Store(entry)
    if C_Timer and C_Timer.After then C_Timer.After(self.PENDING_WAIT + .5, function() Chat:ExpirePending() end) end
    return entry
end
function Chat:Notify(entry, views)
    for _, fn in ipairs(self.listeners) do pcall(fn, entry, views, true) end
end
function Chat:ConfirmPending(entry)
    local list = self.pending[Short(entry.author)]
    local p = list and table.remove(list, 1)
    if not p then return nil end
    p.pending, p.failed = nil, nil
    p.delivered = true
    p.text, p.author, p.lineID, p.guid = entry.text, entry.author, entry.lineID, entry.guid
    self:Notify(p, {self.WhisperView(p.author)})
    return p
end
-- Systemmeldung "Kein Spieler namens 'X' ist online" -> aelteste offene Nachricht an X: nicht zugestellt
function Chat.NotFoundName(text)
    local fmt = rawget(_G, "ERR_CHAT_PLAYER_NOT_FOUND_S")
    if type(fmt) ~= "string" or type(text) ~= "string" then return nil end
    local a, b = fmt:match("^(.-)%%s(.*)$")
    if not a then return nil end
    local function Esc(x) return (x:gsub("%p", "%%%0")) end
    local ok, name = pcall(string.match, text, "^" .. Esc(a) .. "(.+)" .. Esc(b) .. "$")
    return ok and name or nil
end
function Chat:FailPending(text)
    return self:FailPendingFor(Chat.NotFoundName(text))
end
function Chat:FailPendingFor(name)
    local list = name and self.pending[Short(name)]
    local p = list and table.remove(list, 1)
    if not p then return false end
    p.pending, p.failed = nil, true
    self:Notify(p, {self.WhisperView(p.author)})
    return true
end
-- Offene Nachrichten ohne Antwort des Servers: nach PENDING_WAIT Sekunden ohne Haken stehen lassen
function Chat:ExpirePending()
    local now = (type(GetTime) == "function" and GetTime()) or 0
    for name, list in pairs(self.pending) do
        while list[1] and now - (list[1].sentAt or 0) > self.PENDING_WAIT do
            local p = table.remove(list, 1)
            p.pending = nil
            self:Notify(p, {self.WhisperView(name)})
        end
    end
end

-- Guild-Trip-Meldung als Systemzeile (ONE:Print schreibt in DEFAULT_CHAT_FRAME, der bei ersetztem Chat unsichtbar ist)
function Chat:AddSystem(text)
    local entry = {time = (type(time) == "function" and time()) or 0, kind = "system", event = "GUILDTRIP",
        text = "|cff66d9ff[Guild Trip]|r " .. tostring(text or ""), author = ""}
    self:Store(entry)
    return entry
end
function Chat.HookPrint()
    if Chat.printHooked or type(ONE.Print) ~= "function" then return end
    Chat.printHooked = true
    local orig = ONE.Print
    ONE.Print = function(self, message, ...)
        orig(self, message, ...)
        local H = chat.Hider
        if H and H.Enabled and Call(H.Enabled, H) then
            Call(Chat.AddSystem, Chat, self.T and self.T(message) or message)
        end
    end
end

-- ===== Meldungen ANDERER Addons (21.11.2026) =====
-- Ist der WoW-Chat ersetzt, landen Ausgaben anderer Addons (print, DEFAULT_CHAT_FRAME:AddMessage) im versteckten
-- WoW-Chat. Ein stiller Nach-Hook (hooksecurefunc, kein Eingriff) auf die WoW-Chatfenster holt sie als Systemzeile
-- hierher. Wer schreibt, verraet der Aufrufstapel: nur Zeilen, die ein fremdes Addon selbst schreibt.
-- Nicht: normale Chat-Nachrichten (die zeigt der Guild-Trip-Chat schon selbst), Blizzard, Guild Trip selbst.
-- Name des Addons, das die Zeile geschrieben hat (oder nil), aus dem Text von debugstack()
function Chat.AddonFromStack(stack)
    if type(stack) ~= "string" then return nil end
    -- vom WoW-Chat selbst verarbeitete Ereignisse (Gilde, Fluestern, System …): nicht doppelt zeigen
    for _, h in ipairs({"MessageEventHandler", "SystemEventHandler", "ConfigEventHandler"}) do
        if stack:find(h, 1, true) then return nil end
    end
    local top = true
    for line in stack:gmatch("[^\n]+") do
        local folder = line:match("[Aa]dd[Oo]ns[/\\]([^/\\%]\"]+)[/\\]")
        -- ganz oben steht dieser Haken selbst: ueberspringen
        local hook = folder == "ONE_Chat" and line:find("Chat%.lua")
        if not hook then top = false end
        if folder and not (top and hook) then
            local low = folder:lower()
            if low:find("^blizzard_") then -- WoW selbst: weitersuchen (z. B. print-Weiterleitung)
            elseif low:find("^one_") or low == "guildtrip" then return nil -- eigene Zeilen kommen ueber HookPrint
            else return folder end
        end
    end
end
function Chat:AddAddonLine(addon, text)
    text = tostring(text or "")
    if text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):find("^%s*$") then return nil end
    -- dieselbe Zeile in mehreren WoW-Fenstern nur einmal
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if self.lastAddonLine == text and now - (self.lastAddonTime or -10) < 1 then return nil end
    self.lastAddonLine, self.lastAddonTime = text, now
    local entry = {time = (type(time) == "function" and time()) or 0, kind = "system", event = "ADDON",
        text = text, author = "", addon = addon}
    self:Store(entry)
    return entry
end
function Chat.OnBlizzardLine(_, text)
    local H = chat.Hider
    if not (H and H.Enabled and Call(H.Enabled, H)) then return end
    if type(debugstack) ~= "function" then return end
    local ok, stack = pcall(debugstack, 2, 20, 0)
    local addon = ok and Chat.AddonFromStack(stack)
    if addon then Call(Chat.AddAddonLine, Chat, addon, text) end
end
function Chat.HookAddonLines()
    if Chat.addonHooked or type(hooksecurefunc) ~= "function" then return end
    Chat.addonHooked = true
    local n = tonumber(_G.NUM_CHAT_WINDOWS) or 10
    for i = 1, n do
        local f = rawget(_G, "ChatFrame" .. i)
        if type(f) == "table" and type(f.AddMessage) == "function" then
            pcall(hooksecurefunc, f, "AddMessage", Chat.OnBlizzardLine)
        end
    end
end

function Chat:Store(entry)
    local views = {}
    if entry.kind == "whisper" then
        local view = self.WhisperView(entry.author)
        views[#views + 1] = view
        self:TouchWhisper(Short(entry.author), not entry.inform and not entry.auto)
    end
    -- Meldungen von Guild Trip und anderen Addons nur unter "System & Addons", nicht in "Alle" (Nutzer 22.11.2026)
    local own = entry.event == "GUILDTRIP" or entry.event == "ADDON"
    for _, t in ipairs(self:Tabs()) do
        if t.kinds[entry.kind] and not (own and t.id == "all") then views[#views + 1] = t.id end
    end
    for _, view in ipairs(views) do
        local buf = self:Buffer(view)
        buf[#buf + 1] = entry
        if #buf > self.maxLines then table.remove(buf, 1) end
        -- ungelesen, ausser man schaut gerade hin (eigene Fluester-Antworten nie)
        if not entry.inform and not entry.auto and not (self.visible and self.current == view) then
            self.unread[view] = (self.unread[view] or 0) + 1
        end
    end
    for _, fn in ipairs(self.listeners) do pcall(fn, entry, views) end
end

-- ===== Verlauf ueber Neustart (Nutzer 19.11.2026) =====
-- Beim Ausloggen/Neuladen: die letzten HIST_TAB Nachrichten je Reiter, HIST_WHISPER je Fluestergespraech
-- (hoechstens HIST_CONVOS Gespraeche), nichts aelter als HIST_DAYS Tage. Je Charakter, nur auf diesem PC
-- (ONE.db.chatHistory). Jede Nachricht steht nur einmal drin, die Reiter verweisen auf sie.
Chat.HIST_TAB, Chat.HIST_WHISPER, Chat.HIST_CONVOS, Chat.HIST_DAYS = 100, 50, 10, 7
local function Now() return (type(time) == "function" and time()) or 0 end
function Chat.CharKey()
    local name = type(UnitName) == "function" and UnitName("player") or "?"
    local realm = type(GetRealmName) == "function" and GetRealmName() or ""
    return (name or "?") .. "-" .. (realm or "")
end
function Chat:KeepHistory() return self:Settings().keepHistory ~= false end
function Chat:SaveHistory()
    if not ONE.db then return nil end
    ONE.db.chatHistory = type(ONE.db.chatHistory) == "table" and ONE.db.chatHistory or {}
    local key = Chat.CharKey()
    if not self:KeepHistory() then ONE.db.chatHistory[key] = nil return nil end
    local oldest = Now() - self.HIST_DAYS * 86400
    local entries, index, views = {}, {}, {}
    local convos = {}
    for i, w in ipairs(self.whispers) do if i <= self.HIST_CONVOS then convos[Chat.WhisperView(w.name)] = true end end
    for view, buf in pairs(self.buffers) do
        local whisper = tostring(view):sub(1, 2) == "w:"
        if not whisper or convos[view] then
            local limit = whisper and self.HIST_WHISPER or self.HIST_TAB
            local list = {}
            for i = math.max(1, #buf - limit + 1), #buf do
                local e = buf[i]
                if e and (e.time or 0) >= oldest then
                    local n = index[e]
                    if not n then
                        entries[#entries + 1] = {t = e.time, k = e.kind, ev = e.event, x = e.text, a = e.author, c = e.channel, i = e.inform or nil,
                            -- 22.11.2026: Spieler-GUID mit speichern (Klassenfarbe/-symbol nach /reload), nur echte Spieler
                            g = type(e.guid) == "string" and e.guid:find("^Player%-") and e.guid or nil, n = e.npc or nil, au = e.auto or nil}
                        n = #entries
                        index[e] = n
                    end
                    list[#list + 1] = n
                end
            end
            if #list > 0 then views[view] = list end
        end
    end
    local whispers = {}
    for i, w in ipairs(self.whispers) do if i <= self.HIST_CONVOS then whispers[#whispers + 1] = {name = w.name, last = w.last} end end
    ONE.db.chatHistory[key] = {saved = Now(), entries = entries, views = views, whispers = whispers}
    return ONE.db.chatHistory[key]
end
function Chat:LoadHistory()
    local all = ONE.db and type(ONE.db.chatHistory) == "table" and ONE.db.chatHistory
    local h = all and all[Chat.CharKey()]
    if not (type(h) == "table" and self:KeepHistory()) then return 0 end
    local oldest = Now() - self.HIST_DAYS * 86400
    local made = {}
    local function Entry(n)
        if made[n] ~= nil then return made[n] end
        local r = h.entries and h.entries[n]
        local e = false
        if type(r) == "table" and (r.t or 0) >= oldest then
            e = {time = r.t, kind = r.k, event = r.ev, text = r.x or "", author = r.a or "", channel = r.c, inform = r.i, restored = true,
                guid = type(r.g) == "string" and r.g or nil, npc = r.n or nil, auto = r.au or nil}
        end
        made[n] = e
        return e
    end
    local count = 0
    for view, list in pairs(h.views or {}) do
        local buf = self:Buffer(view)
        for _, n in ipairs(list) do
            local e = Entry(n)
            if e then buf[#buf + 1] = e count = count + 1 end
        end
    end
    for _, w in ipairs(h.whispers or {}) do
        if type(w) == "table" and w.name then self.whispers[#self.whispers + 1] = {name = w.name, last = w.last or 0} end
    end
    return count
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
    -- stummgeschaltete Gespraeche (Messenger, Rechtsklick › Stummschalten): kein Ton
    if type(s.muted) == "table" and views and #views > 0 then
        -- "Alle" zaehlt nur, wenn die Nachricht sonst nirgends steht
        local loud, other = false, false
        for _, v in ipairs(views) do
            if v ~= "all" then other = true if not s.muted[v] then loud = true end end
        end
        if not other then loud = not s.muted.all end
        if not loud then return nil end
    end
    if entry.auto then return nil end
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

-- Emote-Befehl (/winken, /wave …) -> Kennwort von WoW (WAVE). Forever sperrt DoEmote fuer Addons, der WoW-Chat
-- wuerde es hier aus Addon-Code aufrufen -> "geblockt". Erlaubt ist C_ChatInfo.PerformEmote (22.11.2026).
function Chat.EmoteToken(cmd)
    cmd = tostring(cmd or ""):lower()
    if cmd == "" then return nil end
    if not Chat.emoteCmds then
        local map = {}
        for i = 1, tonumber(rawget(_G, "MAXEMOTEINDEX")) or 800 do
            local token = rawget(_G, "EMOTE" .. i .. "_TOKEN")
            if token then
                for j = 1, 10 do
                    local c = rawget(_G, "EMOTE" .. i .. "_CMD" .. j)
                    if type(c) == "string" then map[c:lower()] = token end
                end
            end
        end
        Chat.emoteCmds = map
    end
    return Chat.emoteCmds[cmd]
end

-- "/w Name Text" (alle Fluester-Befehle des Clients): Name, Text – sonst nil
function Chat.WhisperCommand(text)
    local cmd, name, rest = tostring(text or ""):match("^(/%S+)%s+([^%s]+)%s*(.-)$")
    if not cmd then return nil end
    local low = cmd:lower()
    for _, key in ipairs({"SLASH_WHISPER", "SLASH_SMART_WHISPER"}) do
        for i = 1, 10 do
            local c = rawget(_G, key .. i)
            if type(c) == "string" and c:lower() == low then return name, rest end
        end
    end
    if low == "/w" or low == "/whisper" or low == "/t" or low == "/tell" or low == "/fl" or low == "/flüstern" then return name, rest end
    return nil
end
-- Privates Befehlsfeld wie Blizzards eigenes Makro-Feld (Mixin der Blizzard-Eingabe), nie sichtbar.
-- Fehlt die Vorlage (anderer Client), nil -> alter Weg ueber das WoW-Feld.
function Chat.CommandBox()
    if Chat.cmdBox then return Chat.cmdBox end
    local mixin = rawget(_G, "ChatFrameEditBoxBaseMixin")
    local mix = rawget(_G, "Mixin")
    if type(mixin) ~= "table" or type(mix) ~= "function" or type(CreateFrame) ~= "function" then return nil end
    local ok, box = pcall(CreateFrame, "EditBox")
    if not ok or not box then return nil end
    mix(box, mixin)
    if box.SetAutoFocus then box:SetAutoFocus(false) end
    if box.Hide then box:Hide() end
    box.chatFrame = _G.DEFAULT_CHAT_FRAME
    if box.SetChatType then box:SetChatType("SAY") end
    if box.SetStickyType then box:SetStickyType("SAY") end
    Chat.cmdBox = box
    return box
end

-- Text aus dem Eingabefeld senden. Slash-Befehle gehen ueber ein eigenes Befehlsfeld.
-- Rueckgabe: true oder nil + Hinweis
function Chat:Send(view, text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    if text:sub(1, 1) == "/" then
        local cmd, rest = text:match("^(%S+)%s*(.-)$")
        local token = Chat.EmoteToken(cmd)
        if token and C_ChatInfo and type(C_ChatInfo.PerformEmote) == "function" then
            -- ohne Namen: wie im WoW-Chat an das aktuelle Ziel
            local target = rest ~= "" and rest or nil
            if not pcall(C_ChatInfo.PerformEmote, token, target) then return nil, T("Emote ging nicht.") end
            return true
        end
        -- "/w Name Text": ueber unseren Fluesterweg (landet im Gespraech, beruehrt kein Blizzard-Feld)
        local wName, wRest = Chat.WhisperCommand(text)
        if wName and Short(wName) == wName then
            local view = self:OpenWhisper(wName)
            if wRest == "" then
                if chat.UI and chat.UI.OpenInput then chat.UI:OpenInput(view) end
                return true
            end
            return self:Send(view, wRest)
        end
        -- Eigenes, privates Befehlsfeld (Spielbild 24.11.2026: "Ein Makroskript wurde geblockt" beim
        -- Gilden-Einladen): Ueber das Blizzard-Eingabefeld gesendet, setzt unser (unsicherer) Code dort
        -- Chat-Art/Ziel – WoW kopiert genau diese Werte in JEDES Makro, das danach laeuft. Dann sind alle
        -- Makro-Knoepfe (/ginvite, auch eigene Makros des Spielers) bis /reload blockiert.
        local own = Chat.CommandBox()
        if own then
            own:SetText(text)
            local ok = pcall(own.SendText, own)
            own:SetText("")
            if own.Hide then own:Hide() end
            if not ok then return nil, T("Befehle gehen hier nicht – bitte im WoW-Chat.") end
            return true
        end
        local box = (type(ChatEdit_ChooseBoxForSend) == "function" and Call(ChatEdit_ChooseBoxForSend))
            or (_G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.editBox)
        if not (box and type(ChatEdit_SendText) == "function") then return nil, T("Befehle gehen hier nicht – bitte im WoW-Chat.") end
        box:SetText(text)
        Call(ChatEdit_SendText, box, 0)
        return true
    end
    local chatType, target = self:Target(view)
    if not chatType then return nil, target end
    if chatType == "WHISPER" and Chat.IsBN(target) then
        -- Battle.net-Freund: an die Konto-Nummer
        local id = Chat.BNFind(target)
        if not id then return nil, T("%s ist nicht in deiner Battle.net-Freundesliste.", target) end
        if type(BNSendWhisper) ~= "function" then return nil, T("Senden geht in diesem Client nicht.") end
        for part in Chat.Split(text, 255) do
            local ok = pcall(BNSendWhisper, id, part)
            if not ok then return nil, T("Senden ging nicht.") end
            self:AddPending(target, part)
        end
        if self:Settings().sentSound then self:PlaySound("chatSent") end
        return true
    end
    if type(SendChatMessage) ~= "function" then return nil, T("Senden geht in diesem Client nicht.") end
    for part in Chat.Split(text, 255) do
        local ok = pcall(SendChatMessage, part, chatType, nil, target)
        if not ok then return nil, T("Senden ging nicht.") end
        if chatType == "WHISPER" then self:AddPending(target, part) end
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
    if Chat.IsPlain(entry) then
        parts[#parts + 1] = entry.text
        return table.concat(parts)
    end
    local name = Short(entry.author)
    local code = self.ClassColorCode(entry.guid, self.parchment)
    local shown = code and (code .. name .. "|r") or name
    local link = entry.npc and shown or ("|Hplayer:" .. (entry.author or name) .. ":" .. tostring(entry.lineID or 0) .. "|h" .. shown .. "|h")
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
