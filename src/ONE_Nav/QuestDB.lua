-- Guild Trip Navi: Questdatenbank (Addon ONE_QuestDB, Daten aus QuestieDB Forever, GPLv3) anbinden.
-- * Questgeber "!" fuer Quests, die du annehmen kannst: Stufe, Volk, Klasse, Vorquests erledigt,
--   noch nicht erledigt und nicht im Log. Nur fuer die Gebiete, die gerade gebraucht werden.
-- * Ort fuer Quests im Log, wenn das Spiel keinen liefert: Ziel-NPCs/-Objekte bzw. Abgabe.
-- Eigene und Gilden-Funde haben Vorrang (Forever weicht von Classic ab).
local _, nav = ...
local ONE = _G.ProjectONE
local QDB = {}
nav.QuestDB = QDB

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

function QDB.Data()
    local d = rawget(_G, "GuildTripQuestDB")
    return type(d) == "table" and type(d.q) == "table" and d or nil
end
function QDB:Available() return self.Data() ~= nil end

-- Bitmasken wie in der Spieldatenbank
QDB.RACE = {Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Undead = 16, Tauren = 32, Gnome = 64, Troll = 128}
QDB.CLASS = {WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024}
QDB.FACTION_MASK = {Alliance = 77, Horde = 178}

-- bit.band ohne Bibliothek (Testumgebung)
local function Band(a, b)
    local lib = rawget(_G, "bit")
    if type(lib) == "table" and lib.band then return lib.band(a, b) end
    local r, p = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + p end
        a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
    end
    return r
end
QDB.Band = Band

function QDB.Player()
    local _, race = Try(UnitRace, "player")
    local _, class = Try(UnitClass, "player")
    return {
        level = Try(UnitLevel, "player") or 1,
        race = race and QDB.RACE[race] or nil,       -- neue Voelker (Forever) -> nur Fraktion pruefen
        class = class and QDB.CLASS[class] or nil,
        faction = Try(UnitFactionGroup, "player") or "?",
    }
end

local function Done(id) return Try(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, id) == true end
local function InLog(id)
    local i = Try(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, id)
    return type(i) == "number" and i > 0
end

-- Passt die Quest zu mir? e = {stufe, mindeststufe, volk, klasse, vorquests, …}
function QDB.Fits(id, e, me)
    if Done(id) or InLog(id) then return false end
    local lvl, min, race, class, pre = e[1], e[2], e[3], e[4], e[5]
    if min > 0 and min > me.level then return false end
    if lvl > 0 and (lvl > me.level + 2 or lvl < me.level - 8) then return false end
    if race > 0 and race < 255 then
        local mine = me.race or QDB.FACTION_MASK[me.faction]
        if mine and Band(race, mine) == 0 then return false end
    end
    if class > 0 and me.class and Band(class, me.class) == 0 then return false end
    if type(pre) == "table" and #pre > 0 then
        -- Vorquests "eine von": mindestens eine muss erledigt sein
        local any = false
        for _, p in ipairs(pre) do if Done(p) then any = true break end end
        if not any then return false end
    end
    -- Vorquests "alle" (QuestieDB): jede muss erledigt sein
    if type(e[9]) == "table" then
        for _, p in ipairs(e[9]) do if not Done(p) then return false end end
    end
    -- schließt sich mit anderen Quests aus (z. B. Fraktionswahl): keine davon erledigt oder im Log
    if type(e[10]) == "table" then
        for _, p in ipairs(e[10]) do if Done(p) or InLog(p) then return false end end
    end
    -- höchste Stufe, bis zu der die Quest angeboten wird
    if (e[13] or 0) > 0 and me.level > e[13] then return false end
    return true
end

-- Einmal je Sitzung: Geber -> Quests, Karte -> Geber
function QDB:Index()
    if self.index then return self.index end
    local d = self.Data()
    if not d then return nil end
    local byGiver, byMap = {}, {}
    for id, e in pairs(d.q) do
        for _, nr in ipairs(e[6]) do
            byGiver[nr] = byGiver[nr] or {}
            table.insert(byGiver[nr], id)
        end
    end
    for nr in pairs(byGiver) do
        local n = d.n[nr]
        if n then
            local seen = {}
            for i = 2, #n, 3 do
                local m = n[i]
                if not seen[m] then
                    seen[m] = true
                    byMap[m] = byMap[m] or {}
                    table.insert(byMap[m], nr)
                end
            end
        end
    end
    self.index = {byGiver = byGiver, byMap = byMap}
    return self.index
end

-- Erster Punkt eines Ortes auf einer Karte (bzw. der erste ueberhaupt)
function QDB.Point(nr, mapID)
    local d = QDB.Data()
    local n = d and d.n[nr]
    if not n then return nil end
    for i = 2, #n, 3 do
        if not mapID or n[i] == mapID then return n[i], n[i + 1] / 1000, n[i + 2] / 1000 end
    end
end
local function FactionOK(nr, faction)
    local d = QDB.Data()
    local f = d.n[nr] and d.n[nr][1] or 0
    if f == 1 and faction == "Horde" then return false end
    if f == 2 and faction == "Alliance" then return false end
    return true
end
function QDB.Key(nr) return (nr < 0 and "o" or "c") .. math.abs(nr) end

-- Questgeber mit passenden Quests auf diesen Karten: {key, name, mapID, x, y, quests = {{id, title, level}}, db = true}
function QDB:Givers(mapIDs, me)
    local d, idx = self.Data(), self:Index()
    if not (d and idx) then return {} end
    me = me or self.Player()
    local out, done = {}, {}
    for _, m in ipairs(mapIDs or {}) do
        for _, nr in ipairs(idx.byMap[m] or {}) do
            if not done[nr .. ":" .. m] and FactionOK(nr, me.faction) then
                done[nr .. ":" .. m] = true
                local quests = {}
                for _, id in ipairs(idx.byGiver[nr] or {}) do
                    local e = d.q[id]
                    if e and QDB.Fits(id, e, me) then
                        quests[#quests + 1] = {id = id, title = d.titles and d.titles[id] or ("#" .. id), level = e[1]}
                    end
                end
                if #quests > 0 then
                    table.sort(quests, function(a, b) return (a.level or 0) < (b.level or 0) end)
                    local mapID, x, y = QDB.Point(nr, m)
                    out[#out + 1] = {key = QDB.Key(nr), name = d.names and d.names[nr] or "", mapID = mapID, x = x, y = y,
                        quests = quests, db = true}
                end
            end
        end
    end
    return out
end

-- Ort fuer eine Quest im Log: fertig -> Abgabe, sonst Ziel (bevorzugt auf der aktuellen Karte)
function QDB:Location(q, here)
    local d = self.Data()
    local e = d and q and d.q[q.id]
    if not e then return nil end
    local list = q.complete and e[7] or e[8]
    if (not list or #list == 0) and not q.complete then list = e[7] end
    for _, pass in ipairs({here or false, false}) do
        for _, nr in ipairs(list or {}) do
            local mapID, x, y = QDB.Point(nr, pass or nil)
            if mapID then return {mapID = mapID, x = x, y = y, db = true} end
        end
    end
end
