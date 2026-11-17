-- Guild Trip, Quests Stufe 0 (Weg 1): Was verraet WoW Forever selbst ueber Quests?
-- /trip questcheck prueft fuer die aktuelle Zone und das eigene Questlog:
--  * verfuegbare Questgeber mit Ort (C_QuestLine.GetAvailableQuestLines)
--  * Quests mit Ort auf der Karte (C_QuestLog.GetQuestsOnMap, C_TaskQuest)
--  * Wegpunkte je Quest im Log (C_QuestLog.GetNextWaypoint, QuestPOIGetIconInfo)
--  * Questziele (C_QuestLog.GetQuestObjectives / GetQuestLogLeaderBoard)
--  * welche Quest-Symbole die Weltkarte selbst zeichnet (Pin-Vorlagen)
-- Ergebnis in GuildTripDevDB.questCheck (erst nach /reload gespeichert).
-- Nur Spieldaten, nichts ueber andere Spieler.
local ONE = _G.ProjectONE
if not ONE then return end
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end

local QC = {}
ONE.QuestCheck = QC

local function Try(fn, ...)
    if type(fn) ~= "function" then return {missing = true} end
    local out = {pcall(fn, ...)}
    if not out[1] then return {error = tostring(out[2])} end
    table.remove(out, 1)
    return out
end

-- Tabellen flach und klein halten (keine Funktionen, max. Tiefe 3, max. 40 Eintraege)
local function Plain(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" or t == "nil" then return v end
    if t ~= "table" or depth > 3 then return "<" .. t .. ">" end
    local out, n = {}, 0
    for k, x in pairs(v) do
        n = n + 1
        if n > 40 then out["…"] = "gekuerzt" break end
        if type(x) ~= "function" and type(x) ~= "userdata" then out[k] = Plain(x, depth + 1) end
    end
    return out
end

local function LogQuests()
    local list = {}
    local Q = C_QuestLog
    if Q and Q.GetNumQuestLogEntries and Q.GetInfo then
        local n = Try(Q.GetNumQuestLogEntries)[1] or 0
        for i = 1, n do
            local info = Try(Q.GetInfo, i)[1]
            if type(info) == "table" and not info.isHeader and info.questID then
                list[#list + 1] = {id = info.questID, title = info.title, level = info.level}
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        local n = Try(GetNumQuestLogEntries)[1] or 0
        for i = 1, n do
            local r = Try(GetQuestLogTitle, i)
            local title, level, isHeader, questID = r[1], r[2], r[4], r[8]
            if not isHeader and questID then list[#list + 1] = {id = questID, title = title, level = level, index = i} end
        end
    end
    return list
end

function QC:Run()
    local result = {time = date and date("%Y-%m-%d %H:%M") or "?", addon = ONE.version}
    local mapID = Try(C_Map and C_Map.GetBestMapForUnit, "player")[1]
    result.mapID = mapID
    result.mapName = mapID and (Try(C_Map.GetMapInfo, mapID)[1] or {}).name
    result.player = Plain(Try(C_Map and C_Map.GetPlayerMapPosition, mapID, "player")[1])
    -- vorhanden?
    local has = {}
    for _, name in ipairs({"C_QuestLine.GetAvailableQuestLines", "C_QuestLine.RequestQuestLinesForMap",
        "C_QuestLog.GetQuestsOnMap", "C_QuestLog.GetNextWaypoint", "C_QuestLog.GetNextWaypointText",
        "C_QuestLog.GetQuestObjectives", "C_TaskQuest.GetQuestsForPlayerByMapID", "C_TaskQuest.GetQuestsOnMap",
        "QuestPOIGetIconInfo", "GetQuestLogLeaderBoard", "C_SuperTrack.SetSuperTrackedQuestID",
        "C_AreaPoiInfo.GetAreaPOIForMap", "C_QuestLog.GetQuestAdditionalHighlights", "C_QuestOffer"}) do
        local v = _G
        for part in name:gmatch("[^%.]+") do v = type(v) == "table" and v[part] or nil end
        has[name] = v ~= nil
    end
    result.has = has
    if C_QuestLine and C_QuestLine.RequestQuestLinesForMap and mapID then Try(C_QuestLine.RequestQuestLinesForMap, mapID) end
    ONE:Print("Questcheck läuft … (3 Sekunden)")
    local function Finish()
        if mapID then
            result.questLines = Plain(Try(C_QuestLine and C_QuestLine.GetAvailableQuestLines, mapID)[1])
            result.questsOnMap = Plain(Try(C_QuestLog and C_QuestLog.GetQuestsOnMap, mapID)[1])
            result.taskQuests = Plain(Try(C_TaskQuest and (C_TaskQuest.GetQuestsOnMap or C_TaskQuest.GetQuestsForPlayerByMapID), mapID)[1])
            result.areaPOIs = Plain(Try(C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap, mapID)[1])
        end
        -- Questknoten (C_AreaPoiInfo.GetQuestHubsForMap) und Ereignisse: aktuelle Zone + alle
        -- Zonen beider Kontinente (Kalimdor 1414, Oestliche Koenigreiche 1415), je mit Details
        result.hubs, result.events = {}, {}
        local hubCount, zoneCount = 0, 0
        local zones = {}
        if mapID then zones[#zones + 1] = mapID end
        for _, cont in ipairs({1414, 1415}) do
            local kids = Try(C_Map and C_Map.GetMapChildrenInfo, cont, Enum and Enum.UIMapType and Enum.UIMapType.Zone, true)[1]
            for _, z in ipairs(type(kids) == "table" and kids or {}) do if z.mapID ~= mapID then zones[#zones + 1] = z.mapID end end
        end
        local hubFn = C_AreaPoiInfo and C_AreaPoiInfo.GetQuestHubsForMap
        result.hubsError = nil
        for _, z in ipairs(zones) do
            zoneCount = zoneCount + 1
            local r = Try(hubFn, z)
            if r.error and not result.hubsError then result.hubsError = r.error end
            local ids = r[1]
            if type(ids) == "table" and #ids > 0 then
                local list = {}
                for _, poi in ipairs(ids) do
                    local info = Try(C_AreaPoiInfo.GetAreaPOIInfo, z, poi)[1]
                    list[#list + 1] = type(info) == "table" and Plain(info) or poi
                end
                result.hubs[tostring(z)] = list
                hubCount = hubCount + #ids
            end
            local ev = Try(C_AreaPoiInfo and C_AreaPoiInfo.GetEventsForMap, z)[1]
            if type(ev) == "table" and #ev > 0 then result.events[tostring(z)] = Plain(ev) end
        end
        result.hubSummary = ("%d Questknoten in %d Zonen"):format(hubCount, zoneCount)
        result.log = {}
        for i, q in ipairs(LogQuests()) do
            if i > 12 then break end
            local e = {id = q.id, title = q.title, level = q.level}
            e.waypoint = Plain(Try(C_QuestLog and C_QuestLog.GetNextWaypoint, q.id))
            e.waypointText = Try(C_QuestLog and C_QuestLog.GetNextWaypointText, q.id)[1]
            e.poi = Plain(Try(QuestPOIGetIconInfo, q.id))
            e.objectives = Plain(Try(C_QuestLog and C_QuestLog.GetQuestObjectives, q.id)[1])
            if q.index and GetNumQuestLeaderBoards then
                local n = Try(GetNumQuestLeaderBoards, q.index)[1] or 0
                e.leader = {}
                for k = 1, n do e.leader[k] = Plain(Try(GetQuestLogLeaderBoard, k, q.index)) end
            end
            result.log[#result.log + 1] = e
        end
        -- Welche Pin-Arten zeichnet die Weltkarte selbst (nur Anzahl, Karte muss nicht offen sein)?
        local wm = _G.WorldMapFrame
        if wm and type(wm.pinPools) == "table" then
            result.mapPins = {}
            for template, pool in pairs(wm.pinPools) do
                local n = 0
                if type(pool.EnumerateActive) == "function" then
                    local ok, iter = pcall(pool.EnumerateActive, pool)
                    if ok and type(iter) == "function" then for _ in iter do n = n + 1 end end
                end
                result.mapPins[tostring(template)] = n
            end
        end
        local db = DevDB()
        db.questCheck = result
        local lines = type(result.questLines) == "table" and #result.questLines or 0
        local onMap = type(result.questsOnMap) == "table" and #result.questsOnMap or 0
        local wp = 0
        for _, e in ipairs(result.log) do if type(e.waypoint) == "table" and e.waypoint[2] then wp = wp + 1 end end
        ONE:Print(("Questcheck fertig (%s): %d Questgeber, %d Quests mit Ort, %d Wegpunkte bei %d Log-Quests, %s. Jetzt /reload."):format(
            tostring(result.mapName or mapID), lines, onMap, wp, #result.log, result.hubSummary or "?"))
    end
    if C_Timer and C_Timer.After then C_Timer.After(3, Finish) else Finish() end
end

ONE:RegisterSlash("questcheck", function() QC:Run() end)
