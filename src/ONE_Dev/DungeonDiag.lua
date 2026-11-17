-- Project ONE Dungeons, Stufe 0: Was liefert WoW Forever selbst?
-- Prueft Gruppensuche (Dungeonliste, Stufen), Dungeoneingaenge auf der Karte
-- und Quest-Schnittstellen (Questnamen, erledigt, Questreihen, Questgeber).
-- Speichert nur Spieldaten, nichts ueber andere Spieler.
local _, ns = ...
local ONE = _G.ProjectONE
-- Liegt in ONE_Dev (nur fuer die Entwicklung) und haengt sich an den
-- Namensraum des Moduls (ONE.ns.dungeons). Ohne das Modul passiert nichts.
local dungeons = (ONE.ns and ONE.ns.dungeons) or ns
if not dungeons then return end
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end
local Diag = {}
dungeons.Diag = Diag

-- Quests aus bekannten Dungeon-Ketten zum Pruefen (Ragefireabgrund, Brachland,
-- Klingenhauer-Kraal, Todesminen, Scharlachrotes Kloster).
Diag.sampleQuests = {1491, 865, 5722, 5723, 5761, 1101, 1102, 166, 1048, 1951}
Diag.sampleMaps = {1411, 1413, 1414, 1415, 1454, 1458}

local function IsSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, s = pcall(issecretvalue, v)
    return ok and s == true
end
local function Plain(v)
    if IsSecret(v) then return "GEHEIM" end
    local t = type(v)
    if v == nil then return "nil" end
    if t == "number" or t == "boolean" then return v end
    if t == "string" then return #v > 80 and v:sub(1, 80) or v end
    return "<" .. t .. ">"
end
local function Pack(...) return {n = select("#", ...), ...} end
local function Try(fn, ...)
    if type(fn) ~= "function" then return {status = "FEHLT", n = 0} end
    local r = Pack(pcall(fn, ...))
    if not r[1] then return {status = "FEHLER", err = Plain(tostring(r[2])), n = 0} end
    local out = {status = "OK", n = r.n - 1}
    for i = 2, math.min(r.n, 31) do out[i - 1] = Plain(r[i]) end
    return out
end
Diag.Try, Diag.Plain = Try, Plain
local function Field(t, k)
    if type(t) ~= "table" or IsSecret(t) then return nil end
    local ok, v = pcall(function() return t[k] end)
    if ok then return Plain(v) end
end
local function Copy(t, keys)
    local out = {}
    for _, k in ipairs(keys) do out[k] = Field(t, k) end
    return out
end
local function Has(path)
    local cur = _G
    for part in path:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return false end
        cur = cur[part]
    end
    return type(cur) == "function"
end

-- 1) Dungeonliste der Gruppensuche (Name, Stufen, Karten-ID)
function Diag:FinderDungeons()
    local result = {status = "FEHLT", list = {}}
    local order = Try(GetLFDChoiceOrder)
    result.status = order.status
    local okOrder, ids = pcall(function() return GetLFDChoiceOrder() end)
    if not okOrder or type(ids) ~= "table" then return result end
    for _, id in ipairs(ids) do
        if type(id) == "number" and id > 0 and #result.list < 60 then
            local info = Try(GetLFGDungeonInfo, id)
            -- Alle Rueckgabewerte speichern; die Reihenfolge ist in Forever unbelegt.
            result.list[#result.list + 1] = {id = id, values = info}
        end
    end
    return result
end

-- 2) Gruppensuche "Durchsuchen" (neue Forever-Dungeons stehen nur hier)
function Diag:FinderActivities()
    local result = {status = "FEHLT", list = {}}
    if not (C_LFGList and type(C_LFGList.GetAvailableActivities) == "function") then return result end
    local ok, ids = pcall(C_LFGList.GetAvailableActivities, 2)
    result.status = ok and "OK" or "FEHLER"
    if not ok or type(ids) ~= "table" then return result end
    for _, id in ipairs(ids) do
        if #result.list < 80 then
            local okInfo, info = false, nil
            if type(C_LFGList.GetActivityInfoTable) == "function" then
                okInfo, info = pcall(C_LFGList.GetActivityInfoTable, id)
            end
            local row = {id = id}
            if okInfo and type(info) == "table" then
                row.info = Copy(info, {"fullName", "shortName", "minLevel", "maxLevelSuggestion",
                    "minLevelSuggestion", "mapID", "categoryID", "groupFinderActivityGroupID"})
            end
            result.list[#result.list + 1] = row
        end
    end
    return result
end

-- 3) Dungeoneingaenge auf den Karten
function Diag:Entrances()
    local out = {}
    for _, mapID in ipairs(self.sampleMaps) do
        local row = {map = mapID, status = "FEHLT", list = {}}
        if C_EncounterJournal and type(C_EncounterJournal.GetDungeonEntrancesForMap) == "function" then
            local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
            row.status = ok and "OK" or "FEHLER"
            if ok and type(list) == "table" then
                for i, e in ipairs(list) do
                    if i > 20 then break end
                    local pos = Field(e, "position")
                    local raw = type(e) == "table" and e.position
                    row.list[#row.list + 1] = {name = Field(e, "name"), id = Field(e, "journalInstanceID"),
                        x = raw and Field(raw, "x"), y = raw and Field(raw, "y"), pos = pos}
                end
            end
        end
        out[#out + 1] = row
    end
    return out
end

-- 4) Quest-Schnittstellen mit bekannten Quest-Nummern
function Diag:Quests()
    local out = {apis = {
        flagged = Has("C_QuestLog.IsQuestFlaggedCompleted"),
        title = Has("C_QuestLog.GetTitleForQuestID"),
        onMap = Has("C_QuestLog.GetQuestsOnMap"),
        tagInfo = Has("C_QuestLog.GetQuestTagInfo"),
        questLines = Has("C_QuestLine.GetAvailableQuestLines"),
        questLineQuests = Has("C_QuestLine.GetQuestLineQuests"),
        requestLines = Has("C_QuestLine.RequestQuestLinesForMap"),
        difficulty = Has("C_QuestLog.GetQuestDifficultyLevel"),
        logIndex = Has("C_QuestLog.GetLogIndexForQuestID"),
    }, samples = {}}
    for _, id in ipairs(self.sampleQuests) do
        out.samples[#out.samples + 1] = {
            id = id,
            done = Try(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, id)[1],
            title = Try(C_QuestLog and C_QuestLog.GetTitleForQuestID, id)[1],
            level = Try(C_QuestLog and C_QuestLog.GetQuestDifficultyLevel, id)[1],
            inLog = Try(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, id)[1],
        }
    end
    return out
end

-- 5) Verfuegbare Questreihen / Questgeber auf der aktuellen Karte
function Diag:QuestGivers()
    local out = {}
    local okMap, mapID = false, nil
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player") end
    out.map = okMap and Plain(mapID) or "nil"
    if type(mapID) ~= "number" then return out end
    if C_QuestLine and type(C_QuestLine.RequestQuestLinesForMap) == "function" then
        pcall(C_QuestLine.RequestQuestLinesForMap, mapID)
    end
    local lines = {}
    if C_QuestLine and type(C_QuestLine.GetAvailableQuestLines) == "function" then
        local ok, list = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
        out.linesStatus = ok and "OK" or "FEHLER"
        if ok and type(list) == "table" then
            for i, l in ipairs(list) do
                if i > 25 then break end
                lines[#lines + 1] = Copy(l, {"questLineName", "questName", "questLineID", "questID", "x", "y",
                    "isHidden", "isLegendary", "isDaily", "isCampaign", "floorLocation"})
            end
            out.linesTotal = #list
        end
    else
        out.linesStatus = "FEHLT"
    end
    out.lines = lines
    if lines[1] and type(lines[1].questLineID) == "number" and C_QuestLine
        and type(C_QuestLine.GetQuestLineQuests) == "function" then
        local ok, quests = pcall(C_QuestLine.GetQuestLineQuests, lines[1].questLineID)
        out.firstLineQuests = ok and type(quests) == "table" and quests or "nil"
    end
    local onMap = Try(C_QuestLog and C_QuestLog.GetQuestsOnMap, mapID)
    out.questsOnMapStatus = onMap.status
    local okQ, quests = false, nil
    if C_QuestLog and type(C_QuestLog.GetQuestsOnMap) == "function" then okQ, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID) end
    out.questsOnMap = okQ and type(quests) == "table" and #quests or "nil"
    return out
end

function Diag:Run()
    if not DevDB() then return end
    local run = {
        time = Try(GetServerTime)[1],
        build = Try(GetBuildInfo),
        level = Try(UnitLevel, "player")[1],
        finder = self:FinderDungeons(),
        activities = self:FinderActivities(),
        entrances = self:Entrances(),
        quests = self:Quests(),
        givers = self:QuestGivers(),
    }
    DevDB().dungeonDiag = run
    local entr = 0
    for _, e in ipairs(run.entrances) do entr = entr + #e.list end
    local titles = 0
    for _, q in ipairs(run.quests.samples) do if type(q.title) == "string" and q.title ~= "nil" then titles = titles + 1 end end
    ONE:Print("Dungeon-Test gespeichert:")
    ONE:Print("Gruppensuche: " .. #run.finder.list .. " Dungeons, " .. #run.activities.list .. " Einträge im Durchsuchen")
    ONE:Print("Dungeoneingänge auf Karten: " .. entr .. " · Questnamen erkannt: " .. titles .. "/" .. #run.quests.samples)
    ONE:Print("Questreihen auf dieser Karte: " .. tostring(run.givers.linesTotal or run.givers.linesStatus)
        .. " · Quests auf Karte: " .. tostring(run.givers.questsOnMap))
    ONE:Print("Danke! Bitte jetzt /reload eingeben, damit WoW speichert.")
    return run
end

-- ===== Anmeldung (nur mit ONE_Dev) =====
ONE:RegisterSlash("dungeondiag", function()
    if not ONE:IsEnabled("dungeons") then
        ONE:Print("Das Dungeon-Modul ist pausiert (/trip modules).")
        return
    end
    Diag:Run()
end, "Dungeon-Test: was liefert das Spiel selbst?")
