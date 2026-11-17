-- Guild Trip (nur lokal, ONE_Dev): Woher koennten Dungeon-Eingaenge kommen?
-- /trip eingangcheck prueft:
--  * Forever selbst: C_EncounterJournal (GetDungeonEntrancesForMap u. a.), EJ_*-Funktionen,
--    C_AreaPoiInfo (Orte auf der Karte), C_Map-Funktionen mit "Dungeon/Instance/Entrance"
--  * welche Pin-Vorlagen die Weltkarte kennt (z. B. DungeonEntrancePinTemplate)
--  * andere geladene Addons und globale Tabellen mit "Dungeon/Entrance/Instance" im Namen
--    (z. B. Questie, Atlas, HandyNotes, OpenMaps) – nur Namen, keine Daten kopieren
-- Ergebnis in GuildTripDevDB.entranceCheck (erst nach /reload gespeichert).
local ONE = _G.ProjectONE
if not ONE then return end
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end

local EC = {}
ONE.EntranceCheck = EC

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil, "fehlt" end
    local ok, a = pcall(fn, ...)
    if not ok then return nil, tostring(a) end
    return a
end
local function Keys(t, pattern)
    local out = {}
    if type(t) ~= "table" then return out end
    for k, v in pairs(t) do
        if type(k) == "string" and (not pattern or k:lower():find(pattern)) then out[#out + 1] = k .. ":" .. type(v) end
    end
    table.sort(out)
    return out
end
local function Small(v, depth)
    depth = depth or 0
    local t = type(v)
    if t ~= "table" then return (t == "function" or t == "userdata") and ("<" .. t .. ">") or v end
    if depth > 2 then return "<table>" end
    local out, n = {}, 0
    for k, x in pairs(v) do
        n = n + 1
        if n > 25 then out["…"] = "gekuerzt" break end
        out[k] = Small(x, depth + 1)
    end
    return out
end

function EC:Run()
    local r = {when = date and date("%Y-%m-%d %H:%M") or "?"}
    local here = Try(C_Map and C_Map.GetBestMapForUnit, "player")
    r.mapID = here
    -- 1) Forever selbst
    r.encounterJournal = Keys(_G.C_EncounterJournal)
    r.ejGlobals = Keys(_G, "^ej_")
    r.mapFunctions = {}
    for _, k in ipairs(Keys(_G.C_Map)) do
        local l = k:lower()
        if l:find("dungeon") or l:find("instance") or l:find("entrance") then r.mapFunctions[#r.mapFunctions + 1] = k end
    end
    r.areaPoi = Keys(_G.C_AreaPoiInfo)
    -- Eingaenge je Zone (alle Zonen, die die Dungeon-Daten kennen, plus aktuelle)
    local zones, seen = {}, {}
    local dz = ONE.ns and ONE.ns.dungeons and ONE.ns.dungeons.Zones or {}
    for _, id in pairs(dz) do if not seen[id] then seen[id] = true zones[#zones + 1] = id end end
    if here and not seen[here] then zones[#zones + 1] = here end
    r.entrances, r.pois = {}, {}
    local entranceCount, poiCount = 0, 0
    local getE = C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap
    local getP = C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap
    for _, id in ipairs(zones) do
        local list, err = Try(getE, id)
        if type(list) == "table" and #list > 0 then
            r.entrances[tostring(id)] = Small(list)
            entranceCount = entranceCount + #list
        elseif err and not r.entranceError then r.entranceError = err end
        local pois = Try(getP, id)
        if type(pois) == "table" and #pois > 0 then
            local names = {}
            for _, poiID in ipairs(pois) do
                local info = Try(C_AreaPoiInfo.GetAreaPOIInfo, id, poiID)
                names[#names + 1] = type(info) == "table" and ((info.name or "?") .. " @" .. tostring(info.atlasName or info.textureIndex or "")) or tostring(poiID)
            end
            r.pois[tostring(id)] = names
            poiCount = poiCount + #pois
        end
    end
    -- 2) Pin-Vorlagen der Weltkarte
    local wm = _G.WorldMapFrame
    r.mapPinTemplates = wm and Keys(wm.pinPools) or {}
    -- 3) andere Addons
    r.addons = {}
    local num = Try((C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns) or 0
    for i = 1, num do
        local name = Try((C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo, i)
        local loaded = name and Try((C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded, name)
        if name and loaded and not name:match("^ONE_") and not name:match("^Blizzard_") then r.addons[#r.addons + 1] = name end
    end
    table.sort(r.addons)
    r.globals = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "table" and not k:match("^ONE") then
            local l = k:lower()
            if l:find("entrance") or (l:find("dungeon") and not l:find("^lfg")) or l:find("questie") or l:find("atlas") or l:find("handynotes") or l:find("openmap") then
                r.globals[#r.globals + 1] = k
            end
        end
    end
    table.sort(r.globals)
    -- Questie: welche Module gibt es (nur Namen)?
    local QL = _G.QuestieLoader
    if type(QL) == "table" then
        r.questieModules = Keys(QL._modules or QL.modules)
    end
    DevDB().entranceCheck = r
    ONE:Print(("Eingangcheck fertig: %d Eingänge aus dem Spiel (%s), %d Karten-Orte, %d Pin-Vorlagen, %d andere Addons. Jetzt /reload."):format(
        entranceCount, getE and "Abfrage vorhanden" or "Abfrage fehlt", poiCount, #r.mapPinTemplates, #r.addons))
end

ONE:RegisterSlash("eingangcheck", function() EC:Run() end)
