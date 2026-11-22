-- Project ONE Dungeons: Datenmodell (ohne Oberflaeche, offline testbar).
-- Verbindet Spiel-Daten (Dungeonnamen, Stufen, Quest erledigt/im Log,
-- deutsche Questtitel) mit den Quest-Daten aus Forever Dungeon Quests.
local _, dungeons = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Model = {maxTitleRequests = 40}
dungeons.Model = Model

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

function Model:Store()
    if not ONE.db then return {titles = {}} end
    ONE.db.dungeons = type(ONE.db.dungeons) == "table" and ONE.db.dungeons or {}
    local s = ONE.db.dungeons
    s.titles = type(s.titles) == "table" and s.titles or {}
    if s.suitableOnly == nil then s.suitableOnly = true end
    return s
end

function Model:PlayerLevel() return tonumber((Call(UnitLevel, "player"))) or 1 end
function Model:PlayerFaction() return (Call(UnitFactionGroup, "player")) or "Horde" end
function Model:PlayerClass()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, class = pcall(UnitClass, "player")
    return ok and class or nil
end

-- Quest-Status aus dem Spiel; mehrere austauschbare Quest-Nummern zaehlen gemeinsam.
function Model:IsDone(ids)
    if not (ids and C_QuestLog) then return false end
    for _, id in ipairs(ids) do
        if Call(C_QuestLog.IsQuestFlaggedCompleted, id) == true then return true end
    end
    return false
end
function Model:InLog(ids)
    if not (ids and C_QuestLog) then return false end
    for _, id in ipairs(ids) do
        local index = Call(C_QuestLog.GetLogIndexForQuestID, id)
        if type(index) == "number" and index > 0 then return true end
    end
    return false
end

-- Quest-Stufe und Mindeststufe aus der Questdatenbank (QuestieDB, ONE_QuestDB). Die Dungeon-Questdaten
-- (Forever Dungeon Quests) nennen meist die Mindeststufe als "level" (Nutzer 19.11.2026: Ruinen-Quests
-- standen mit 15 da, sind aber Stufe 22). Rueckgabe: Stufe, ab Stufe (nil, wenn unbekannt).
function Model:Levels(quest)
    local db = rawget(_G, "GuildTripQuestDB")
    local q = type(db) == "table" and db.q
    if type(q) == "table" then
        for _, id in ipairs(quest.ids or {}) do
            local e = q[id]
            if type(e) == "table" and tonumber(e[1]) and e[1] > 0 then
                local min = tonumber(e[2])
                return e[1], (min and min > 0 and min < e[1]) and min or nil
            end
        end
    end
    return quest.level, nil
end

function Model:LevelText(quest)
    local level, min = self:Levels(quest)
    if not level then return "" end
    return min and (level .. " |cff9d9d9d(" .. min .. ")|r") or tostring(level)
end

-- Deutscher Titel, falls das Spiel ihn kennt (im Log oder nachgeladen), sonst Quelle.
function Model:Title(quest)
    local store = self:Store()
    for _, id in ipairs(quest.ids or {}) do
        if store.titles[id] then return store.titles[id] end
        local title = C_QuestLog and Call(C_QuestLog.GetTitleForQuestID, id)
        if type(title) == "string" and title ~= "" then
            store.titles[id] = title
            return title
        end
    end
    return quest.name or "?"
end

-- Bittet das Spiel, fehlende Questtitel nachzuladen (Antwort: QUEST_DATA_LOAD_RESULT).
function Model:RequestTitles(quests)
    if not (C_QuestLog and type(C_QuestLog.RequestLoadQuestByID) == "function") then return 0 end
    local store, asked = self:Store(), 0
    for _, quest in ipairs(quests) do
        local id = quest.ids and quest.ids[1]
        if id and not store.titles[id] and asked < self.maxTitleRequests then
            self.requested = self.requested or {}
            if not self.requested[id] then
                self.requested[id] = true
                pcall(C_QuestLog.RequestLoadQuestByID, id)
                asked = asked + 1
            end
        end
    end
    return asked
end
function Model:OnQuestData(questID, success)
    if not success or type(questID) ~= "number" then return false end
    local title = C_QuestLog and Call(C_QuestLog.GetTitleForQuestID, questID)
    if type(title) == "string" and title ~= "" then
        self:Store().titles[questID] = title
        return true
    end
    return false
end

-- Sichtbar: eigene Fraktion (oder neutral) und eigene Klasse (oder keine Klassenquest).
function Model:Visible(quest)
    local faction = quest.faction
    if faction and faction ~= "Neutral" and faction ~= self:PlayerFaction() then return false end
    if quest.classOnly and quest.classOnly ~= self:PlayerClass() then return false end
    return true
end

function Model:PrereqState(quest)
    local done, total, unknown = 0, 0, 0
    for _, p in ipairs(quest.prereqs or {}) do
        total = total + 1
        if not p.ids then unknown = unknown + 1
        elseif self:IsDone(p.ids) then done = done + 1 end
    end
    return done, total, unknown
end

-- done (erledigt) | log (im Questlog) | locked (Vorquests fehlen) | open (annehmbar)
function Model:Status(quest)
    if self:IsDone(quest.ids) then return "done" end
    if self:InLog(quest.ids) then return "log" end
    local done, total, unknown = self:PrereqState(quest)
    if total > 0 and done + unknown < total then return "locked" end
    return "open"
end

function Model:QuestTable(name)
    if not self.byName then
        self.byName = {}
        for _, d in ipairs((dungeons.QuestData or {}).dungeons or {}) do self.byName[d.name] = d end
    end
    return name and self.byName[name]
end

-- Name und Stufen eines Dungeons, wenn moeglich direkt aus der Gruppensuche.
function Model:GameInfo(entry)
    local name, min, max = entry.name, entry.min, entry.max
    if C_LFGList and type(C_LFGList.GetActivityInfoTable) == "function" and #entry.activities > 0 then
        local lo, hi
        for _, id in ipairs(entry.activities) do
            local info = Call(C_LFGList.GetActivityInfoTable, id)
            if type(info) == "table" then
                if #entry.activities == 1 and type(info.fullName) == "string" and info.fullName ~= "" then
                    name = info.fullName
                end
                local a, b = tonumber(info.minLevelSuggestion), tonumber(info.maxLevelSuggestion)
                if a and a > 0 then lo = lo and math.min(lo, a) or a end
                if b and b > 0 then hi = hi and math.max(hi, b) or b end
            end
        end
        min, max = lo or min, hi or max
    end
    return name, min, max
end

-- Farbe wie bei Quests: zu schwer rot/orange, passend gelb, leicht gruen, trivial grau.
function Model:Difficulty(min, max, level)
    level = level or self:PlayerLevel()
    if level < min - 2 then return "hard", {1, .1, .1} end
    if level < min then return "medium", {1, .5, .25} end
    if level <= max then return "fit", {1, .82, 0} end
    if level <= max + 5 then return "easy", {.25, .75, .25} end
    return "trivial", {.6, .6, .6}
end
function Model:IsSuitable(min, max, level)
    level = level or self:PlayerLevel()
    return level >= min - 2 and level <= max + 2
end

-- Alle Dungeons fuer diesen Charakter, inklusive Quest-Zaehlung.
function Model:Dungeons()
    local level, faction = self:PlayerLevel(), self:PlayerFaction()
    local list = {}
    for _, entry in ipairs(dungeons.Catalog or {}) do
        if not entry.faction or entry.faction == faction then
            local name, min, max = self:GameInfo(entry)
            local data = self:QuestTable(entry.quests)
            local quests = {}
            for _, q in ipairs(data and data.quests or {}) do
                if self:Visible(q) then quests[#quests + 1] = q end
            end
            local done = 0
            for _, q in ipairs(quests) do if self:IsDone(q.ids) then done = done + 1 end end
            local kind, color = self:Difficulty(min, max, level)
            -- Englische Oberflaeche: englischer Katalogname (auch auf deutschem Spiel)
            if ONE.Language and ONE:Language() == "en" and entry.en then name = entry.en end
            list[#list + 1] = {key = entry.key, entry = entry, name = name, en = entry.en, min = min, max = max,
                quests = quests, done = done, open = #quests - done, hasData = data ~= nil,
                keyNote = data and data.keyNote, kind = kind, color = color,
                suitable = self:IsSuitable(min, max, level)}
        end
    end
    return list
end

function Model:MapFor(quest)
    local zone = quest.zone
    return zone and dungeons.Zones and dungeons.Zones[zone] or nil
end
