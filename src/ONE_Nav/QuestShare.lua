-- Guild Trip: Gilden-Quest-Abgleich (0.6.5) – "wer in der Gilde hat dieselbe Quest".
-- Nur mit eigenem Haekchen (Optionen › Teilen › "Quests teilen"), nur ueber den
-- Gilden-Addon-Kanal. Die Daten der anderen leben nur im Arbeitsspeicher.
--
-- Nachrichten (Praefix ONEQST1, je hoechstens 250 Zeichen):
--   Q0|stufe|klasse            Beginn meines Quest-Stands (ersetzt den alten)
--   Q1|eintrag;eintrag;...     Quests, eintrag = id,fertig,erfuellt,noetig[,karte,x,y]
--                              (fertig 1/0, x/y in Tausendsteln, Ort nur ohne Zonenrand)
--   QOFF                       Teilen ausgeschaltet
--   QREQ                       "Bitte schickt euren Stand"
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local QS = {prefix = "ONEQST1", peers = {}, queue = {}, peerTimeout = 900, resend = 300, lastSent = "", lastAt = -1000}
nav.QuestShare = QS

local function Clock() return type(GetTime) == "function" and GetTime() or 0 end
local function Me()
    if type(UnitFullName) == "function" then
        local ok, name, realm = pcall(UnitFullName, "player")
        if ok and name then return (realm and realm ~= "") and (name .. "-" .. realm) or name end
    end
    return type(UnitName) == "function" and UnitName("player") or "?"
end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
QS.Short = Short
local function Split(msg, sep)
    local out = {}
    for part in (msg .. sep):gmatch("([^" .. sep .. "]*)" .. sep) do out[#out + 1] = part end
    return out
end
local function After(sec, fn) if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end end

-- ===== Einstellung (pro Charakter) =====
function QS:Settings()
    if not ONE.db then return {} end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    local s = type(ONE.db.nav.questShare) == "table" and ONE.db.nav.questShare or {}
    ONE.db.nav.questShare = s
    return s
end
function QS:IsSharing() return self:Settings()[Me()] == true end
function QS:SetSharing(on)
    self:Settings()[Me()] = on and true or nil
    self.lastSent = ""
    if on then self:SendState(true) else self:Send("QOFF") end
end

-- ===== Senden mit Drossel =====
function QS:Send(msg)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return false end
    if not (IsInGuild and IsInGuild()) then return false end
    self.queue[#self.queue + 1] = msg
    if not self.ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
        self.ticker = C_Timer.NewTicker(.4, function() self:Flush(1) end)
    elseif not self.ticker then
        self:Flush(#self.queue)
    end
    return true
end
function QS:Flush(n)
    for _ = 1, n or 1 do
        local msg = table.remove(self.queue, 1)
        if not msg then break end
        pcall(C_ChatInfo.SendAddonMessage, self.prefix, msg, "GUILD")
    end
end

-- Summe ueber alle Ziele: erfuellt/noetig
local function Count(q)
    local f, r = 0, 0
    for _, o in ipairs(q.objectives or {}) do
        local need = tonumber(o.numRequired) or 0
        if need <= 0 then need = 1 end
        f = f + math.min(tonumber(o.numFulfilled) or (o.finished and need or 0), need)
        r = r + need
    end
    return f, r
end
QS.Count = Count

-- Eigener Stand als Nachrichten (Q0 + so viele Q1 wie noetig)
function QS:Messages()
    local Q = nav.Quests
    local log, locs = Q:Log(), Q:Locations()
    local level = type(UnitLevel) == "function" and UnitLevel("player") or 0
    local class = type(UnitClass) == "function" and select(2, UnitClass("player")) or ""
    local out, entries = {"Q0|" .. tostring(level or 0) .. "|" .. tostring(class or "")}, {}
    for _, q in ipairs(log) do
        local f, r = Count(q)
        local e = table.concat({q.id, q.complete and 1 or 0, f, r}, ",")
        local loc = locs[q.id]
        if loc and not loc.edge then
            e = e .. "," .. table.concat({loc.mapID, math.floor(loc.x * 1000 + .5), math.floor(loc.y * 1000 + .5)}, ",")
        end
        entries[#entries + 1] = e
    end
    local line = ""
    for _, e in ipairs(entries) do
        if #line + #e + 4 > 240 then out[#out + 1] = "Q1|" .. line line = "" end
        line = line == "" and e or (line .. ";" .. e)
    end
    if line ~= "" then out[#out + 1] = "Q1|" .. line end
    return out
end

-- Stand senden; ohne force nur, wenn er sich geaendert hat oder lange her ist
function QS:SendState(force)
    if not self:IsSharing() or not nav.Quests then return false end
    local msgs = self:Messages()
    local all = table.concat(msgs, "\n")
    if not force and all == self.lastSent and Clock() - self.lastAt < self.resend - 10 then return false end
    self.lastSent, self.lastAt = all, Clock()
    for _, m in ipairs(msgs) do self:Send(m) end
    return true
end

-- Quest-Aenderungen sammeln: hoechstens alle 8 Sekunden senden
function QS:Changed()
    if self.pending or not self:IsSharing() then return end
    self.pending = true
    After(8, function() self.pending = nil self:SendState() end)
end

-- ===== Empfangen =====
function QS:Receive(prefix, msg, channel, sender)
    if prefix ~= self.prefix or type(msg) ~= "string" or type(sender) ~= "string" then return end
    if Short(sender):lower() == Short(Me()):lower() or #msg > 255 then return end
    local p = Split(msg, "|")
    local kind, name, now = p[1], Short(sender), Clock()
    if kind == "Q0" then
        self.peers[name] = {name = name, level = tonumber(p[2]) or 0, class = p[3], seen = now, quests = {}}
    elseif kind == "Q1" then
        local peer = self.peers[name]
        if not peer then return end
        peer.seen = now
        for _, e in ipairs(Split(p[2] or "", ";")) do
            local v = Split(e, ",")
            local id = tonumber(v[1])
            if id then
                local entry = {done = v[2] == "1", f = tonumber(v[3]) or 0, r = tonumber(v[4]) or 0}
                local map, x, y = tonumber(v[5]), tonumber(v[6]), tonumber(v[7])
                if map and x and y then entry.mapID, entry.x, entry.y = map, x / 1000, y / 1000 end
                peer.quests[id] = entry
            end
        end
    elseif kind == "MV" then
        if nav.Merchants then nav.Merchants:Receive(p) end
        return
    elseif kind == "QG" then
        if nav.QuestGivers then nav.QuestGivers:Receive(p) end
        return
    elseif kind == "QOFF" then
        self.peers[name] = nil
    elseif kind == "QREQ" then
        After(1 + (math.random and math.random() * 5 or 2), function() self:SendState(true) end)
    end
    if self.onChange then self.onChange() end
end

-- Aktive Mitspieler (alte Staende fallen weg)
function QS:Peers()
    local now, out = Clock(), {}
    for name, peer in pairs(self.peers) do
        if now - (peer.seen or 0) > self.peerTimeout then self.peers[name] = nil else out[#out + 1] = peer end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Wer hat diese Quest? {name, level, class, done, f, r}
function QS:Holders(questID)
    local out = {}
    for _, peer in ipairs(self:Peers()) do
        local e = peer.quests[questID]
        if e then out[#out + 1] = {name = peer.name, level = peer.level, class = peer.class, done = e.done, f = e.f, r = e.r} end
    end
    return out
end

-- Ort der Quest laut den anderen (fuellt Luecken, wenn das Spiel uns keinen gibt)
function QS:Location(questID)
    for _, peer in ipairs(self:Peers()) do
        local e = peer.quests[questID]
        if e and e.mapID then return {mapID = e.mapID, x = e.x, y = e.y, from = peer.name} end
    end
end

-- Kurztext fuer die Quest-Seite: "Thrall 3/8, Rehgar fertig"
function QS:HoldersText(questID)
    local parts = {}
    for _, h in ipairs(self:Holders(questID)) do
        local state = h.done and T("fertig") or (h.r > 0 and ("%d/%d"):format(h.f, h.r) or "")
        parts[#parts + 1] = h.name .. (state ~= "" and (" " .. state) or "")
    end
    return table.concat(parts, ", "), #parts
end

function QS:Initialize()
    if ONE.UI and ONE.UI.AddShareOption then
        ONE.UI:AddShareOption({id = "quests", module = "nav", order = 25, label = "Quests teilen",
            tooltip = "Gildenmitglieder mit Guild Trip sehen, welche Quests du offen hast, wie weit du bist und wo das Ziel liegt – so findet ihr Mitspieler für dieselbe Quest. Nichts wird gespeichert.",
            get = function() return QS:IsSharing() end,
            set = function(on) QS:SetSharing(on) end})
    end
    if not (C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function") then return false end
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    local frame = CreateFrame("Frame")
    for _, e in ipairs({"CHAT_MSG_ADDON", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP"}) do
        pcall(frame.RegisterEvent, frame, e)
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then self:Receive(...) else self:Changed() end
    end)
    self.frame = frame
    -- Erst den eigenen Stand schicken, dann die anderen fragen (alle, auch ohne eigenes Teilen)
    After(15, function() self:SendState(true) self:Send("QREQ") end)
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(self.resend, function() self:SendState() end)
    end
    return true
end
