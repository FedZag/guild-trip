-- Guild Trip Navi: Quest-Links mit Bezug zu dir (Chat-Ideen 24.11.2026)
-- Zeilen im Tooltip eines Quest-Links (Chat in allen Ansichten, auch WoW-Chat): erledigt / im Questlog,
-- passt die Stufe, EP, wo sie beginnt, wer in der Gilde sie hat. Klick auf den Link: Knopf "Navi zum Start"
-- (bzw. "Navi zum Ziel", wenn sie schon im Questlog steht). Ueber ONE.LinkTips (ONE_Core).
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local QT = {}
nav.QuestTip = QT

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function CQ() return rawget(_G, "C_QuestLog") or {} end
function QT.Done(id) return Try(CQ().IsQuestFlaggedCompleted, id) == true end
function QT.InLog(id)
    local i = Try(CQ().GetLogIndexForQuestID, id)
    return type(i) == "number" and i > 0
end
function QT.MapName(mapID)
    local info = rawget(_G, "C_Map") and Try(C_Map.GetMapInfo, mapID)
    return type(info) == "table" and info.name or nil
end

-- Erster Questgeber, der zu deiner Fraktion passt: name, mapID, x, y
function QT.Start(id)
    local QDB = nav.QuestDB
    local d = QDB and QDB.Data()
    local e = d and d.q[id]
    if not (e and type(e[6]) == "table") then return nil end
    local faction = Try(UnitFactionGroup, "player")
    local here = rawget(_G, "C_Map") and Try(C_Map.GetBestMapForUnit, "player")
    local fallback
    for _, nr in ipairs(e[6]) do
        local f = d.n and d.n[nr] and d.n[nr][1] or 0
        if not ((f == 1 and faction == "Horde") or (f == 2 and faction == "Alliance")) then
            local mapID, x, y = QDB.Point(nr, here)
            if not mapID then mapID, x, y = QDB.Point(nr) end
            if mapID then
                local hit = {name = d.names and d.names[nr] or T("Questgeber"), mapID = mapID, x = x, y = y}
                if mapID == here then return hit end
                fallback = fallback or hit
            end
        end
    end
    return fallback
end

-- Stufe: Text und Farbe (nil, wenn unbekannt)
function QT.LevelLine(id, e, me)
    local QL = nav.QuestLevels
    local lvl = (QL and QL.Level(id)) or (e and e[1]) or 0
    local min = e and e[2] or 0
    if lvl <= 0 then return nil end
    local xp = QL and QL.XPText(id)
    local tail = xp and ("  ·  " .. xp) or ""
    if min > me then return {T("Guild Trip: erst ab Stufe %d (du bist %d)", min, me), 1, .3, .3} end
    if lvl > me + 2 then return {T("Guild Trip: Stufe %d – noch schwer für dich", lvl) .. tail, 1, .55, .2} end
    if lvl < me - 8 then return {T("Guild Trip: Stufe %d – bringt dir kaum noch EP", lvl) .. tail, .6, .6, .6} end
    return {T("Guild Trip: Stufe %d – passt zu dir", lvl) .. tail, .25, 1, .25}
end

-- Nicht fuer dich? (andere Fraktion/Klasse) -> Text oder nil
function QT.NotForYou(e)
    local QDB = nav.QuestDB
    if not (e and QDB) then return nil end
    local me = QDB.Player()
    local race, class = e[3] or 0, e[4] or 0
    local fm = QDB.FACTION_MASK[me.faction]
    if race > 0 and race < 255 and fm and QDB.Band(race, fm) == 0 then return T("Guild Trip: Quest der anderen Fraktion") end
    if class > 0 and me.class and QDB.Band(class, me.class) == 0 then return T("Guild Trip: Quest für eine andere Klasse") end
    return nil
end

function QT.Provider(link, kind)
    if kind ~= "quest" then return nil end
    if ONE.FeatureOn and not ONE:FeatureOn("nav.questTip") then return nil end
    local id = tonumber(link:match("^quest:(%d+)"))
    if not id then return nil end
    local QDB = nav.QuestDB
    local d = QDB and QDB.Data()
    local e = d and d.q[id]
    local lines, button = {}, nil
    local me = Try(UnitLevel, "player") or 1
    local navi = ONE.modules and ONE.modules.nav
    if QT.Done(id) then
        lines[#lines + 1] = {T("Guild Trip: hast du schon erledigt"), .6, .6, .6}
    elseif QT.InLog(id) then
        lines[#lines + 1] = {T("Guild Trip: steht in deinem Questlog"), 1, .82, 0}
        local complete = Try(CQ().IsComplete, id) == true
        local loc = QDB and QDB:Location({id = id, complete = complete})
        if loc and navi and navi.PointTo then
            button = {label = complete and T("Navi zur Abgabe") or T("Navi zum Ziel"), run = function()
                navi:PointTo(d.titles and d.titles[id] or T("Quest"), loc.mapID, loc.x, loc.y)
            end}
        end
    else
        local nfy = QT.NotForYou(e)
        if nfy then
            lines[#lines + 1] = {nfy, .6, .6, .6}
        else
            local lv = QT.LevelLine(id, e, me)
            if lv then lines[#lines + 1] = lv end
            local start = QT.Start(id)
            if start then
                local zone = QT.MapName(start.mapID)
                lines[#lines + 1] = {zone and T("Beginnt bei %s (%s)", start.name, zone) or T("Beginnt bei %s", start.name), .8, .8, .8}
                if navi and navi.PointTo then
                    button = {label = T("Navi zum Start"), run = function() navi:PointTo(start.name, start.mapID, start.x, start.y) end}
                end
            end
        end
    end
    -- wer in der Gilde sie gerade hat ("Thrall 5/8, …")
    local holders = nav.QuestShare and nav.QuestShare.HoldersText and Try(nav.QuestShare.HoldersText, nav.QuestShare, id)
    if type(holders) == "string" and holders ~= "" then lines[#lines + 1] = {T("Gilde: %s", holders), .5, .8, 1} end
    if #lines == 0 and not button then return nil end
    return {lines = lines, button = button}
end

if ONE.LinkTips then ONE.LinkTips:Register("nav.questTip", QT.Provider) end
