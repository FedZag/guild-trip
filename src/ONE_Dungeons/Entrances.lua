-- Guild Trip: Dungeon-Eingaenge fuer das Navi (0.6.5).
-- Quellen, beste zuerst:
--  1. "game":  Forever selbst (C_EncounterJournal.GetDungeonEntrancesForMap, falls vorhanden)
--  2. "self":  selbst gemerkt – betritt der Spieler einen Dungeon, ist die letzte Position
--              draussen (hoechstens 2 Minuten alt) der Eingang
--  3. "guild": von Gildenmitgliedern geteilt (nur mit "Dungeon-Fortschritt teilen")
--  4. "data":  QuestieDB Forever (EntranceData.lua, scripts/import_entrances.lua)
--  5. "seed":  ungefaehre Classic-Werte (eigenes Spielwissen) – nur noch fuer Duesterbruch-Fluegel u. Ae.
-- Gespeichert in ONE.db.dungeons.entrances[schluessel] = {mapID, x, y, source}.
-- Nachricht (Praefix ONEGRP1): DE|schluessel|karte|x|y  (x/y in Tausendsteln)
local _, dungeons = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local E = {rank = {game = 5, self = 4, guild = 3, pack = 2, data = 1.5, seed = 1}, maxAge = 120}
dungeons.Entrances = E

-- Ungefaehre Eingaenge (Classic-uiMapIDs, Anteile 0..1). Neue Forever-Dungeons fehlen
-- bewusst – die kommen ueber Quelle 1-3.
E.seed = {
    rfc = {1454, .520, .495}, wc = {1413, .460, .360}, dm = {1436, .426, .718}, sfk = {1421, .448, .678},
    stocks = {1453, .405, .555}, bfd = {1440, .142, .139}, gnomer = {1426, .244, .398}, rfk = {1413, .423, .899},
    sm = {1420, .849, .306}, rfd = {1413, .490, .945}, ulda = {1418, .444, .122}, zf = {1446, .387, .200},
    mara = {1443, .290, .625}, st = {1435, .698, .535}, brd = {1428, .290, .380}, lbrs = {1428, .290, .380},
    ubrs = {1428, .290, .380}, dme = {1444, .648, .302}, dmw = {1444, .603, .302}, dmn = {1444, .625, .249},
    scholo = {1422, .697, .732}, stratlive = {1423, .270, .115}, stratud = {1423, .435, .194},
}

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
end
local function Clock() return type(GetTime) == "function" and GetTime() or 0 end

function E:Store()
    local s = dungeons.Model:Store()
    s.entrances = type(s.entrances) == "table" and s.entrances or {}
    return s.entrances
end

-- Eintrag setzen, wenn die Quelle mindestens so gut ist wie die vorhandene
function E:Set(key, mapID, x, y, source)
    if not (key and mapID and x and y and self.rank[source]) then return false end
    local store, old = self:Store(), self:Store()[key]
    if old and (self.rank[old.source] or 0) > self.rank[source] then return false end
    store[key] = {mapID = mapID, x = x, y = y, source = source}
    return true
end

-- Katalog-Eintraege, deren Name zum Text passt (deutsch oder englisch, auch Teilwort)
function E.Match(text)
    local out = {}
    if type(text) ~= "string" or text == "" then return out end
    local t = text:lower()
    for _, d in ipairs(dungeons.Catalog or {}) do
        for _, n in ipairs({d.name, d.en}) do
            local base = n and n:lower():gsub("%s*%b()", "")
            if base and base ~= "" and (t == base or t:find(base, 1, true) or base:find(t, 1, true)) then
                out[#out + 1] = d
                break
            end
        end
    end
    return out
end

-- Bei mehreren Treffern (Stratholme, Duesterbruch) den mit dem naechsten Startwert nehmen
function E.Closest(cands, mapID, x, y)
    if #cands <= 1 then return cands[1] end
    local best, bestD
    for _, d in ipairs(cands) do
        local s = E.seed[d.key]
        local dist = (s and s[1] == mapID) and ((s[2] - x) ^ 2 + (s[3] - y) ^ 2) or 99
        if not bestD or dist < bestD then best, bestD = d, dist end
    end
    return best
end

-- Quelle 1: Forever selbst (einmal je Sitzung alle bekannten Zonen fragen)
function E:ScanGame()
    if self.scanned then return end
    self.scanned = true
    local api = C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap
    if type(api) ~= "function" then return end
    local seen = {}
    for _, mapID in pairs(dungeons.Zones or {}) do
        if not seen[mapID] then
            seen[mapID] = true
            for _, e in ipairs(Try(api, mapID) or {}) do
                local pos = e.position
                local x, y = pos and (pos.x or (pos.GetXY and select(1, pos:GetXY()))), pos and (pos.y or (pos.GetXY and select(2, pos:GetXY())))
                if x and y then
                    local d = E.Closest(E.Match(e.name), mapID, x, y)
                    if d then self:Set(d.key, mapID, x, y, "game") end
                end
            end
        end
    end
end

-- Eingang fuer einen Dungeon: {mapID, x, y, source} oder nil
function E:Get(key)
    self:ScanGame()
    local e = self:Store()[key]
    if e then return e end
    -- Startpaket aus eigenen Funden (EntrancePack.lua), dann ungefaehre Startwerte
    local p = dungeons.EntrancePack and dungeons.EntrancePack[key]
    if p then return {mapID = p[1], x = p[2], y = p[3], source = "pack"} end
    -- Eingänge aus der Questdatenbank (EntranceData.lua, QuestieDB Forever – schon im Forever-Kartenrahmen)
    local q = dungeons.EntranceData and dungeons.EntranceData[key]
    if q then return {mapID = q[1], x = q[2], y = q[3], source = "data"} end
    local s = E.seed[key]
    if s then return {mapID = s[1], x = s[2], y = s[3], source = "seed"} end
end

-- Navi starten (Etappen ueber Zeppelin/Schiff macht der Pfeil selbst)
function E:Navi(d)
    local e = d and self:Get(d.key)
    local navi = ONE.modules and ONE.modules.nav
    if not e then ONE:Print(T("Für %s ist noch kein Eingang bekannt – betritt den Dungeon einmal, dann merkt Guild Trip ihn sich.", d and d.name or "?")) return false end
    if not (navi and navi.PointTo) then return false end
    return navi:PointTo(T("Eingang: %s", d.name), e.mapID, e.x, e.y)
end

-- ===== Quelle 2: selbst merken =====
-- Letzte Position draussen (alle 2 s), beim Betreten eines Dungeons als Eingang speichern
function E:TrackOutside()
    if Try(IsInInstance) then return end
    local mapID = Try(C_Map and C_Map.GetBestMapForUnit, "player")
    local pos = mapID and Try(C_Map.GetPlayerMapPosition, mapID, "player")
    local x, y
    if type(pos) == "table" then
        x, y = pos.x, pos.y
        if x == nil and pos.GetXY then x, y = pos:GetXY() end
    end
    if mapID and x and y and x > 0 and y > 0 then self.outside = {mapID = mapID, x = x, y = y, at = Clock()} end
end
function E:OnEnterWorld()
    if ONE.FeatureOn and not ONE:FeatureOn("dungeons.entrances") then return end
    local inside, kind = Try(IsInInstance)
    if not inside or kind ~= "party" then self:TrackOutside() return end
    local o = self.outside
    if not o or Clock() - o.at > self.maxAge then return end
    local name = Try(GetInstanceInfo)
    local d = E.Closest(E.Match(name), o.mapID, o.x, o.y)
    if not d then return end
    if self:Set(d.key, o.mapID, o.x, o.y, "self") then self:Share(d.key) end
    self.outside = nil
end

-- ===== Quelle 3: Gilde =====
function E:Share(key)
    local S = dungeons.Share
    local e = self:Store()[key]
    if not (S and e and S:IsSharing()) then return false end
    return S:Send(table.concat({"DE", key, e.mapID, math.floor(e.x * 1000 + .5), math.floor(e.y * 1000 + .5)}, "|"))
end
function E:Receive(p)
    local key, mapID, x, y = p[2], tonumber(p[3]), tonumber(p[4]), tonumber(p[5])
    local known = false
    for _, d in ipairs(dungeons.Catalog or {}) do if d.key == key then known = true end end
    if not (known and mapID and x and y) then return false end
    return self:Set(key, mapID, x / 1000, y / 1000, "guild")
end

function E:SourceText(source)
    return source == "seed" and T("ungefährer Classic-Wert") or source == "pack" and T("aus dem Guild-Trip-Startpaket") or source == "guild" and T("von der Gilde")
        or source == "self" and T("selbst gemerkt") or source == "game" and T("aus dem Spiel") or ""
end

function E:Initialize()
    if not CreateFrame then return false end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
    pcall(f.RegisterEvent, f, "ZONE_CHANGED_NEW_AREA")
    f:SetScript("OnEvent", function()
        if C_Timer and C_Timer.After then C_Timer.After(1, function() pcall(E.OnEnterWorld, E) end) else pcall(E.OnEnterWorld, E) end
    end)
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(2, function() pcall(E.TrackOutside, E) end)
    end
    self.frame = f
    return true
end
