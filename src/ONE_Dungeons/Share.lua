-- Project ONE Dungeons: Gilden-Funk fuer Dungeon-Fortschritt und Gruppengesuche.
-- Nur Gilden-Addon-Kanal (kein Server, kein externer Dienst). Gespeichert wird
-- nichts: alles lebt nur im Arbeitsspeicher, solange die Spieler online sind.
--
-- Nachrichten (Praefix ONEGRP1, je hoechstens 250 Zeichen):
--   P0|stufe|klasse            Beginn meines Fortschritts (ersetzt alten Stand)
--   P1|schluessel|id,id,...    offene Quests in einem fuer mich passenden Dungeon
--   POFF                       Teilen ausgeschaltet
--   REQ                        "Bitte schickt euren Stand und eure Gesuche"
--   GA|gid|schluessel|rollen|dabei|groesse|notiz|titel    Gruppengesuch (wird wiederholt);
--                              schluessel "q<QuestID>" = Gesuch fuer eine (Elite-)Quest, titel = Questname
--   GC|gid                     Gesuch geschlossen
--   DE|schluessel|karte|x|y    gefundener Dungeon-Eingang (Entrances.lua)
--   GJ|gid|rolle|stufe|klasse  "Ich bin dabei" (Fluester-Kanal an den Suchenden)
local _, dungeons = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Share = {prefix = "ONEGRP1", peers = {}, ads = {}, applicants = {}, queue = {},
    peerTimeout = 900, adTimeout = 200, adLifetime = 1800, adRepeat = 60, counter = 0}
dungeons.Share = Share

local ROLES = {T = "Tank", H = "Heiler", D = "Schaden"}
Share.ROLES = ROLES

local function Clock() return type(GetTime) == "function" and GetTime() or 0 end
local function Me()
    if type(UnitFullName) == "function" then
        local ok, name, realm = pcall(UnitFullName, "player")
        if ok and name then return (realm and realm ~= "") and (name .. "-" .. realm) or name end
    end
    return type(UnitName) == "function" and UnitName("player") or "?"
end
Share.Me = Me
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
Share.Short = Short
local function Same(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    return a:lower() == b:lower() or Short(a):lower() == Short(b):lower()
end
Share.Same = Same
local function Clean(text, max)
    text = tostring(text or ""):gsub("[|\r\n]", " ")
    if #text > max then text = text:sub(1, max) end
    return text
end
local function Split(msg)
    local out = {}
    for part in (msg .. "|"):gmatch("([^|]*)|") do out[#out + 1] = part end
    return out
end

-- ===== Einstellungen (pro Charakter) =====
function Share:Settings()
    local s = dungeons.Model:Store()
    s.shareChars = type(s.shareChars) == "table" and s.shareChars or {}
    if s.notify == nil then s.notify = true end
    if s.role ~= "T" and s.role ~= "H" and s.role ~= "D" then s.role = "D" end
    return s
end
function Share:IsSharing() return self:Settings().shareChars[Me()] == true end
function Share:SetSharing(on)
    self:Settings().shareChars[Me()] = on and true or nil
    if on then self:SendProgress() else self:Send("POFF") end
end

-- ===== Senden mit Drossel (WoW begrenzt Addon-Nachrichten) =====
function Share:Send(msg, channel, target)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return false end
    if (channel or "GUILD") == "GUILD" and not (IsInGuild and IsInGuild()) then return false end
    self.queue[#self.queue + 1] = {msg, channel or "GUILD", target}
    if not self.ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
        self.ticker = C_Timer.NewTicker(.35, function() self:Flush(1) end)
    elseif not self.ticker then
        self:Flush(#self.queue)
    end
    return true
end
function Share:Flush(n)
    for _ = 1, n or 1 do
        local item = table.remove(self.queue, 1)
        if not item then break end
        pcall(C_ChatInfo.SendAddonMessage, self.prefix, item[1], item[2], item[3])
    end
end

-- ===== Eigener Fortschritt =====
function Share:MyProgress()
    local out = {}
    for _, d in ipairs(dungeons.Model:Dungeons()) do
        if d.suitable and d.open > 0 then
            local ids = {}
            for _, q in ipairs(d.quests) do
                if q.ids and dungeons.Model:Status(q) ~= "done" then ids[#ids + 1] = q.ids[1] end
            end
            if #ids > 0 then out[#out + 1] = {key = d.key, ids = ids} end
        end
    end
    return out
end
function Share:SendProgress()
    if not self:IsSharing() then return false end
    local M = dungeons.Model
    self:Send("P0|" .. M:PlayerLevel() .. "|" .. tostring(M:PlayerClass() or ""))
    for _, entry in ipairs(self:MyProgress()) do
        local ids = table.concat(entry.ids, ",")
        if #ids > 220 then ids = ids:sub(1, 220):match("^(.*),") or ids:sub(1, 220) end
        self:Send("P1|" .. entry.key .. "|" .. ids)
    end
    return true
end

-- ===== Gesuche =====
function Share:PostAd(key, roles, have, note, title, size)
    self.counter = self.counter + 1
    local gid = Clean(Short(Me()), 20) .. math.floor(Clock()) % 100000 .. self.counter
    if self.myAd then self:CloseAd() end
    self.myAd = {gid = gid, owner = Me(), key = key, roles = roles, have = have or 1, size = size or 5,
        note = Clean(note, 80), title = title and Clean(title, 60) or nil, created = Clock(), seen = Clock()}
    self.ads[gid] = self.myAd
    self.applicants[gid] = {}
    self:BroadcastAd()
    return self.myAd
end
function Share:BroadcastAd()
    local ad = self.myAd
    if not ad then return end
    if Clock() - ad.created > self.adLifetime then return self:CloseAd() end
    ad.seen = Clock()
    self:Send(table.concat({"GA", ad.gid, ad.key, ad.roles, ad.have, ad.size, ad.note, ad.title or ""}, "|"))
end
function Share:CloseAd()
    local ad = self.myAd
    if not ad then return end
    self:Send("GC|" .. ad.gid)
    self.ads[ad.gid], self.applicants[ad.gid], self.myAd = nil, nil, nil
end
function Share:Join(gid)
    local ad = self.ads[gid]
    if not ad or Same(ad.owner, Me()) then return false end
    local M = dungeons.Model
    ad.joined = true
    return self:Send(table.concat({"GJ", gid, self:Settings().role, M:PlayerLevel(), tostring(M:PlayerClass() or "")}, "|"),
        "WHISPER", ad.owner)
end

-- ===== Empfangen =====
function Share:Receive(prefix, msg, channel, sender)
    if prefix ~= self.prefix or type(msg) ~= "string" or type(sender) ~= "string" then return end
    if Same(sender, Me()) or #msg > 255 then return end
    local p = Split(msg)
    local kind, now = p[1], Clock()
    if kind == "P0" then
        self.peers[sender] = {name = sender, level = tonumber(p[2]) or 0, class = p[3], seen = now, dungeons = {}}
    elseif kind == "P1" then
        local peer = self.peers[sender]
        if not peer or not p[2] or p[2] == "" then return end
        local ids = {}
        for id in (p[3] or ""):gmatch("%d+") do ids[tonumber(id)] = true end
        peer.dungeons[p[2]] = ids
        peer.seen = now
    elseif kind == "POFF" then
        self.peers[sender] = nil
    elseif kind == "REQ" then
        local delay = 1 + (math.random and math.random() * 5 or 2)
        local function Reply()
            self:SendProgress() self:BroadcastAd()
            if dungeons.Trips then dungeons.Trips:Broadcast() end
        end
        if C_Timer and C_Timer.After then C_Timer.After(delay, Reply) else Reply() end
    elseif kind == "DE" and dungeons.Entrances then
        dungeons.Entrances:Receive(p)
    elseif (kind == "TA" or kind == "TC" or kind == "TS" or kind == "TQ" or kind == "TX") and dungeons.Trips then
        dungeons.Trips:Receive(kind, p, sender)
    elseif kind == "GA" and p[2] then
        local ad = self.ads[p[2]]
        local isNew = not ad
        ad = ad or {gid = p[2], owner = sender, created = now}
        ad.key, ad.roles = p[3], p[4] or ""
        ad.have, ad.size, ad.note, ad.seen = tonumber(p[5]) or 1, tonumber(p[6]) or 5, p[7] or "", now
        if p[8] and p[8] ~= "" then ad.title = p[8] end
        self.ads[p[2]] = ad
        if isNew then self:Announce(ad) end
    elseif kind == "GC" and p[2] then
        local ad = self.ads[p[2]]
        if ad and Same(ad.owner, sender) then self.ads[p[2]] = nil end
    elseif kind == "GJ" and p[2] then
        local mine = self.myAd
        if mine and mine.gid == p[2] then
            self.applicants[p[2]] = self.applicants[p[2]] or {}
            self.applicants[p[2]][sender] = {name = sender, role = p[3], level = tonumber(p[4]) or 0, class = p[5], seen = now}
            self:Tell(T("%s möchte mit in %s (%s).", Short(sender), self:DungeonName(mine.key), self:RoleName(p[3])))
        end
    end
    if self.onChange then self.onChange() end
end

-- Englische Oberflaeche: englischer Katalogname, sonst der deutsche.
function Share:DungeonName(key)
    local english = ONE.Language and ONE:Language() == "en"
    for _, e in ipairs(dungeons.Catalog or {}) do if e.key == key then return english and e.en or e.name end end
    return key or "?"
end
-- Quest-Gesuch? Liefert die Quest-ID ("q123" -> 123)
function Share:QuestOf(ad)
    local key = type(ad) == "table" and ad.key or ad
    return type(key) == "string" and tonumber(key:match("^q(%d+)$")) or nil
end
-- Anzeigename eines Gesuchs: Dungeon oder "Quest: Name"
function Share:AdName(ad)
    local id = self:QuestOf(ad)
    if not id then return self:DungeonName(ad.key) end
    local title = ad.title
    if not title or title == "" then
        local ok, t = pcall(C_QuestLog and C_QuestLog.GetTitleForQuestID or error, id)
        title = ok and type(t) == "string" and t ~= "" and t or ("#" .. id)
    end
    return T("Quest: %s", title)
end
function Share:RoleName(key) return ROLES[key] and T(ROLES[key]) or "?" end

-- Passt ein Gesuch zu mir? Wer hoch genug ist, darf immer mit (Ausruestung,
-- helfen) – auch wenn er den Dungeon schon hatte. Nur zu niedrig zaehlt nicht.
-- Rueckgabe: kannMit, offeneQuests, ueberStufe
function Share:Fit(ad)
    -- Quest-Gesuch: passt, wenn ich dieselbe Quest im Log habe
    local quest = self:QuestOf(ad)
    if quest then
        local have = dungeons.Model:InLog({quest})
        return have, have and 1 or 0, false
    end
    local level = dungeons.Model:PlayerLevel()
    for _, d in ipairs(dungeons.Model:Dungeons()) do
        if d.key == ad.key then return level >= d.min - 2, d.open, level > d.max + 2 end
    end
    return false, 0, false
end
-- Nur Chatzeile (kein Hinweisfenster) + "!" am Minimap-Knopf.
function Share:Tell(text)
    ONE:Notify(text, {source = T("Guild Trip Gruppen"), toast = false, silent = true})
    if ONE.MinimapButton and ONE.MinimapButton.SetAlert then
        ONE.MinimapButton:SetAlert("groups", text, "groups")
    end
end
function Share:Announce(ad)
    if not self:Settings().notify then return end
    local fits, open, over = self:Fit(ad)
    if not fits then return end
    local name, owner = self:AdName(ad), Short(ad.owner)
    if self:QuestOf(ad) then
        return self:Tell(T("%s sucht eine Gruppe für %s – du hast die Quest auch. (/trip › Dungeons › Gruppen)", owner, name))
    end
    self:Tell(open > 0 and T("%s sucht eine Gruppe für %s – du hast dort %d offene Quests. (/trip › Dungeons › Gruppen)", owner, name, open)
        or over and T("%s sucht eine Gruppe für %s – komm mit für Ausrüstung oder zum Helfen. (/trip › Dungeons › Gruppen)", owner, name)
        or T("%s sucht eine Gruppe für %s. (/trip › Dungeons › Gruppen)", owner, name))
end

-- ===== Abfragen fuer die Oberflaeche =====
function Share:Expire()
    local now = Clock()
    for name, peer in pairs(self.peers) do
        if now - peer.seen > self.peerTimeout or peer.seen > now then self.peers[name] = nil end
    end
    for gid, ad in pairs(self.ads) do
        if ad ~= self.myAd and (now - ad.seen > self.adTimeout or ad.seen > now) then self.ads[gid] = nil end
    end
end
-- Wer aus der Gilde hat in diesem Dungeon noch Quests offen?
function Share:Needers(key)
    self:Expire()
    local out = {}
    for _, peer in pairs(self.peers) do
        local ids = peer.dungeons[key]
        if ids and next(ids) then
            local n = 0
            for _ in pairs(ids) do n = n + 1 end
            out[#out + 1] = {name = peer.name, level = peer.level, class = peer.class, open = n, ids = ids}
        end
    end
    table.sort(out, function(a, b) return Short(a.name) < Short(b.name) end)
    return out
end
-- Wer braucht genau diese Quest?
function Share:QuestNeeders(key, quest)
    local out = {}
    for _, n in ipairs(self:Needers(key)) do
        for _, id in ipairs(quest.ids or {}) do
            if n.ids[id] then out[#out + 1] = n break end
        end
    end
    return out
end
function Share:Ads()
    self:Expire()
    local list = {}
    for _, ad in pairs(self.ads) do list[#list + 1] = ad end
    table.sort(list, function(a, b)
        local fa, fb = (self:Fit(a)), (self:Fit(b))
        if fa ~= fb then return fa end
        return (a.created or 0) > (b.created or 0)
    end)
    return list
end

function Share:Invite(name)
    if C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" and pcall(C_PartyInfo.InviteUnit, name) then return true end
    if type(InviteUnit) == "function" and pcall(InviteUnit, name) then return true end
    return false
end
-- Gesuch im Gildenchat: erreicht auch Mitglieder ohne ONE. Nur auf Knopfdruck.
function Share:PostToGuildChat()
    local ad = self.myAd
    if not ad then return false end
    local text = ad.note ~= "" and T("[Guild Trip] Gruppe für %s: suche %s – %s. Meldet euch bei %s!", self:AdName(ad), self:RoleText(ad.roles), ad.note, Short(ad.owner))
        or T("[Guild Trip] Gruppe für %s: suche %s. Meldet euch bei %s!", self:AdName(ad), self:RoleText(ad.roles), Short(ad.owner))
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" then return false end
    return pcall(send, text, "GUILD") == true
end
function Share:RoleText(roles)
    local out = {}
    for key in tostring(roles or ""):gmatch("[THD]") do out[#out + 1] = self:RoleName(key) end
    return #out > 0 and table.concat(out, ", ") or "alle"
end

function Share:Whisper(name)
    if type(ChatFrame_SendTell) == "function" then return pcall(ChatFrame_SendTell, name) end
    return false
end

function Share:Initialize()
    if not (C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function") then return false end
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            self:Receive(...)
        elseif C_Timer and C_Timer.After then
            -- kurz warten, bis das Spiel den neuen Quest-Stand kennt
            C_Timer.After(5, function() self:SendProgress() end)
        end
    end)
    self.frame = frame
    if C_Timer and C_Timer.After then
        C_Timer.After(12, function() self:SendProgress() self:Send("REQ") end)
    end
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(self.adRepeat, function() self:BroadcastAd() end)
    end
    return true
end
