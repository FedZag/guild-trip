-- Guild Trip: Questgeber selbst sammeln (0.6.5, Etappe 3 von "Quests wie Questie").
-- Forever liefert keine Questgeber fuer neue Quests (GetAvailableQuestLines leer), deshalb:
--  * Spricht der Spieler mit einem NPC (oder Gegenstand), der Quests anbietet, merken wir uns
--    Ort (Spielerposition), Name und die angebotenen Quests (ID, Titel, Stufe).
--  * Mit "Quests teilen" gehen neue Funde an die Gilde (Nachricht QG ueber QuestShare);
--    Funde der anderen landen in derselben Sammlung (kontoweit gespeichert, ohne Finder-Namen).
--  * Auf Karte/Minimap (QuestPins) zeigt ein "!" Questgeber mit Quests, die fuer mich passen:
--    nicht erledigt, nicht im Log, gleiche Fraktion, Stufe passend.
-- Questie-Daten werden bewusst NICHT uebernommen (GPL). Ist Questie geladen, zeigt es eigene
-- "!" – dann blenden wir unsere aus (doppelt waere unuebersichtlich).
--
-- Nachricht (Praefix ONEQST1): QG|schluessel|name|karte|x|y|fraktion|id,stufe,titel;...
--   x/y in Tausendsteln, id 0 = Quest nur mit Titel bekannt
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local G = {maxGivers = 3000}
nav.QuestGivers = G

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function Clean(text, max)
    text = tostring(text or ""):gsub("[|;,\r\n]", " ")
    if #text > max then text = text:sub(1, max) end
    return text
end
local function Now() return Try(GetServerTime) or Try(time) or 0 end
local function Faction() return Try(UnitFactionGroup, "player") or "?" end
local function Level() return Try(UnitLevel, "player") or 1 end


-- Startpaket (Pack.lua, aus eigenen Funden gebaut) einmal je Sitzung einmischen:
-- nur Schluessel, die noch fehlen; eigene Funde haben immer Vorrang.
local function MergePack(store, list)
    for key, e in pairs(list or {}) do
        if store[key] == nil then
            local copy = {pack = true}
            for k, v in pairs(e) do
                if type(v) == "table" then local t = {} for a, b in pairs(v) do t[a] = type(b) == "table" and {title = b.title, level = b.level} or b end copy[k] = t
                else copy[k] = v end
            end
            store[key] = copy
        end
    end
end

function G:Store()
    if not ONE.db then return {} end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    local s = type(ONE.db.nav.givers) == "table" and ONE.db.nav.givers or {}
    ONE.db.nav.givers = s
    if not self.packMerged and nav.Pack then self.packMerged = true MergePack(s, nav.Pack.givers) end
    return s
end

-- Schluessel aus der GUID: "Creature-0-1-2-3-NPCID-..." -> "c3245", Gegenstaende "o…"
function G.KeyFromGUID(guid, name)
    if type(guid) == "string" then
        local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
        if kind and id then return (kind == "GameObject" and "o" or "c") .. id end
    end
    if type(name) == "string" and name ~= "" then return "n" .. Clean(name, 30) end
end

function G:QuestieLoaded()
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return Try(fn, "Questie") and true or false
end

-- Fund eintragen; quests = {{id=, level=, title=}}. Liefert true, wenn etwas neu war.
function G:Add(key, name, mapID, x, y, faction, quests, fromGuild)
    if not (key and mapID and x and y and type(quests) == "table" and #quests > 0) then return false end
    local store = self:Store()
    local g = store[key]
    local new = false
    if not g then
        g = {quests = {}}
        store[key] = g
        new = true
    end
    -- eigene Funde ueberschreiben den Ort, Gildenfunde nur, wenn wir keinen haben
    if not fromGuild or not g.mapID then
        g.name, g.mapID, g.x, g.y, g.faction = Clean(name, 40), mapID, x, y, faction
    end
    g.seen = Now()
    for _, q in ipairs(quests) do
        local qk = (q.id and q.id > 0) and q.id or ("t:" .. Clean(q.title, 60))
        if not g.quests[qk] then new = true end
        local old = g.quests[qk] or {}
        g.quests[qk] = {title = Clean(q.title or old.title, 60), level = q.level or old.level}
        -- Titel-Eintrag wird ueberfluessig, sobald die ID bekannt ist
        if type(qk) == "number" and q.title then g.quests["t:" .. Clean(q.title, 60)] = nil end
    end
    if new then self:Trim() end
    return new
end

-- Sammlung begrenzen (aelteste Funde zuerst weg)
function G:Trim()
    local store, list = self:Store(), {}
    for key, g in pairs(store) do list[#list + 1] = {key, g.seen or 0} end
    if #list <= self.maxGivers then return end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    for i = 1, #list - self.maxGivers do store[list[i][1]] = nil end
end

-- Was bietet der NPC gerade an? (Gossip-Fenster, Quest-Begruessung, einzelne Quest)
function G:Offered(event)
    local out = {}
    if event == "GOSSIP_SHOW" then
        local list = Try(C_GossipInfo and C_GossipInfo.GetAvailableQuests)
        for _, q in ipairs(type(list) == "table" and list or {}) do
            out[#out + 1] = {id = q.questID, level = q.questLevel, title = q.title, trivial = q.isTrivial}
        end
    elseif event == "QUEST_GREETING" then
        for i = 1, Try(GetNumAvailableQuests) or 0 do
            local title = Try(GetAvailableTitle, i)
            local level = Try(GetAvailableLevel, i)
            if title then out[#out + 1] = {id = 0, level = level, title = title} end
        end
    elseif event == "QUEST_DETAIL" then
        local id, title = Try(GetQuestID), Try(GetTitleText)
        -- nur neue Angebote, nicht das Abgabe-/Fortschrittsfenster einer Log-Quest
        local inLog = id and Try(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, id)
        if (id or title) and not (type(inLog) == "number" and inLog > 0) then
            out[#out + 1] = {id = id or 0, title = title}
        end
    end
    return out
end

function G:OnEvent(event)
    if ONE.FeatureOn and not ONE:FeatureOn("nav.givers") then return end
    local quests = self:Offered(event)
    if #quests == 0 then return end
    local guid, name = Try(UnitGUID, "npc"), Try(UnitName, "npc")
    local key = self.KeyFromGUID(guid, name)
    local mapID, x, y = nav.Travel.PlayerMapPosition()
    if not (key and mapID) then return end
    -- Stufe kennt QUEST_DETAIL nicht: aus der letzten Gossip-Liste uebernehmen
    local old = self:Store()[key]
    for _, q in ipairs(quests) do
        if not q.level and old and old.quests[q.id] then q.level = old.quests[q.id].level end
    end
    if self:Add(key, name, mapID, x, y, Faction(), quests) then
        self:Share(key)
        if nav.QuestPins then nav.QuestPins:Refresh() end
    end
end

-- ===== Teilen (nur mit Haekchen "Quests teilen") =====
function G:Message(key)
    local g = self:Store()[key]
    if not (g and g.mapID) then return end
    local entries = {}
    for qk, q in pairs(g.quests) do
        local id = type(qk) == "number" and qk or 0
        entries[#entries + 1] = table.concat({id, q.level or 0, Clean(q.title, 40)}, ",")
    end
    table.sort(entries)
    local head = table.concat({"QG", key, Clean(g.name, 30), g.mapID, math.floor(g.x * 1000 + .5),
        math.floor(g.y * 1000 + .5), g.faction or "?"}, "|") .. "|"
    local body = ""
    for _, e in ipairs(entries) do
        if #head + #body + #e + 1 > 250 then break end
        body = body == "" and e or (body .. ";" .. e)
    end
    return head .. body
end
function G:Share(key)
    local QS = nav.QuestShare
    if not (QS and QS:IsSharing()) then return false end
    local msg = self:Message(key)
    return msg and QS:Send(msg) or false
end
function G:Receive(p)
    local key, name, mapID, x, y, faction = p[2], p[3], tonumber(p[4]), tonumber(p[5]), tonumber(p[6]), p[7]
    if not (key and key:match("^[con]") and mapID and x and y) then return end
    local quests = {}
    for e in ((p[8] or "") .. ";"):gmatch("([^;]*);") do
        local id, level, title = e:match("^(%d+),(%d+),(.*)$")
        if id and (tonumber(id) > 0 or title ~= "") then
            quests[#quests + 1] = {id = tonumber(id), level = tonumber(level) > 0 and tonumber(level) or nil, title = title ~= "" and title or nil}
        end
    end
    if self:Add(key, name, mapID, x / 1000, y / 1000, faction, quests, true) and nav.QuestPins then nav.QuestPins:Refresh() end
end

-- ===== Abfrage: Questgeber mit Quests fuer mich =====
function G:Fits(qk, q, level, logTitles)
    if type(qk) == "number" then
        if Try(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, qk) == true then return false end
        local index = Try(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, qk)
        if type(index) == "number" and index > 0 then return false end
    elseif q.title and logTitles[q.title] then
        return false
    end
    if q.level and q.level > 0 and (q.level > level + 2 or q.level < level - 8) then return false end
    return true
end
function G:Available(maps)
    if ONE.FeatureOn and not ONE:FeatureOn("nav.givers") then return {} end
    local out, level, faction = {}, Level(), Faction()
    local logTitles = {}
    for _, q in ipairs(nav.Quests and nav.Quests:Log() or {}) do logTitles[q.title] = true end
    for key, g in pairs(self:Store()) do
        if g.mapID and (g.faction == nil or g.faction == "?" or g.faction == faction) then
            local quests = {}
            for qk, q in pairs(g.quests or {}) do
                if self:Fits(qk, q, level, logTitles) then quests[#quests + 1] = q end
            end
            if #quests > 0 then
                table.sort(quests, function(a, b) return (a.level or 0) < (b.level or 0) end)
                out[#out + 1] = {key = key, name = g.name, mapID = g.mapID, x = g.x, y = g.y, quests = quests}
            end
        end
    end
    -- Classic-Questdaten (ONE_QuestDB) fuer die gebrauchten Karten; selbst gefundene NPCs haben Vorrang
    if maps and nav.QuestDB and nav.QuestDB:Available() then
        local store = self:Store()
        for _, g in ipairs(nav.QuestDB:Givers(maps)) do
            if not store[g.key] then
                -- Quests im Log (auch nur per Titel bekannt) nicht nochmal anbieten
                local quests = {}
                for _, q in ipairs(g.quests) do if not logTitles[q.title] then quests[#quests + 1] = q end end
                if #quests > 0 then g.quests = quests out[#out + 1] = g end
            end
        end
    end
    return out
end

function G:Initialize()
    if not CreateFrame then return false end
    local frame = CreateFrame("Frame")
    for _, e in ipairs({"GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL"}) do pcall(frame.RegisterEvent, frame, e) end
    frame:SetScript("OnEvent", function(_, event) G:OnEvent(event) end)
    self.frame = frame
    return true
end
