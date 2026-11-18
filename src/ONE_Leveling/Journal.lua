-- Guild Trip Quest-Fuehrung: Reisetagebuch (0.7.1).
-- Merkt sich je Charakter, was du erlebt hast – mit Datum, Uhrzeit und Ort:
--   * Quest abgegeben (mit Stufe der Quest)        * Stufe erreicht (und wie lange die Stufe gedauert hat)
--   * neues Gebiet zum ersten Mal betreten          * Dungeon-Lauf (aus dem Dungeon-Rueckblick)
-- Nur lokal gespeichert (ONE.db.journal), nichts wird geteilt oder in den Chat geschrieben.
-- Ansicht: Leveln › Tagebuch (neueste zuerst, je Tag eine Ueberschrift).
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local J = {max = 2000}
lev.Journal = J

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local function G(name) return rawget(_G, name) end
local function Now() return Call(G("GetServerTime")) or (os and os.time and os.time()) or 0 end
-- Schalter: Optionen › Leveln › "Reisetagebuch führen" (db.leveling.journal, Vorgabe an)
local function FeatureOn()
    local db = lev.Guide and lev.Guide.DB and lev.Guide:DB()
    return not (db and db.journal == false)
end

local function CharKey()
    local name, realm = Call(G("UnitFullName"), "player")
    name = name or Call(G("UnitName"), "player") or "?"
    return (realm and realm ~= "") and (name .. "-" .. realm) or name
end

-- Eintraege dieser Figur (aelteste zuerst) + Merker (Stufen-Beginn, besuchte Gebiete)
function J:Store()
    ONE.db.journal = type(ONE.db.journal) == "table" and ONE.db.journal or {}
    local key = CharKey()
    local s = type(ONE.db.journal[key]) == "table" and ONE.db.journal[key] or {}
    ONE.db.journal[key] = s
    s.list = type(s.list) == "table" and s.list or {}
    s.zones = type(s.zones) == "table" and s.zones or {}
    return s
end

-- Wo bin ich? mapID, x, y (0..1), Gebietsname
local function Here()
    local C = G("C_Map")
    local mapID = C and Call(C.GetBestMapForUnit, "player")
    local x, y
    if mapID and C.GetPlayerMapPosition then
        local pos = Call(C.GetPlayerMapPosition, mapID, "player")
        if type(pos) == "table" then
            x, y = pos.x, pos.y
            if x == nil and pos.GetXY then x, y = Call(pos.GetXY, pos) end
        end
    end
    local info = mapID and C and Call(C.GetMapInfo, mapID)
    return mapID, x, y, (type(info) == "table" and info.name) or Call(G("GetZoneText")) or ""
end

function J:Add(entry)
    if not FeatureOn() then return nil end
    local s = self:Store()
    local mapID, x, y, zone = Here()
    entry.t = entry.t or Now()
    entry.map, entry.zone = entry.map or mapID, entry.zone or zone
    entry.x = entry.x or (x and math.floor(x * 1000 + .5)) or nil
    entry.y = entry.y or (y and math.floor(y * 1000 + .5)) or nil
    s.list[#s.list + 1] = entry
    while #s.list > self.max do table.remove(s.list, 1) end
    if self.onChange then pcall(self.onChange) end
    return entry
end

-- ===== Ereignisse =====
function J:OnQuestTurnedIn(questID, xp)
    if type(questID) ~= "number" then return end
    local title = lev.Guide and lev.Guide.Title and lev.Guide.Title(questID) or ("#" .. questID)
    local nav = ONE.ns and ONE.ns.nav
    local level = nav and nav.QuestLevels and nav.QuestLevels.Level(questID)
    return self:Add({kind = "quest", id = questID, title = title, qlevel = level, xp = tonumber(xp)})
end

function J:OnLevelUp(level)
    level = tonumber(level)
    if not level then return end
    local s = self:Store()
    local now = Now()
    local took = s.levelStart and s.levelStartLevel == level - 1 and (now - s.levelStart) or nil
    s.levelStart, s.levelStartLevel = now, level
    return self:Add({kind = "level", level = level, took = took})
end

function J:OnZone()
    local mapID, _, _, zone = Here()
    if not mapID then return end
    local s = self:Store()
    if s.zones[mapID] then return end
    s.zones[mapID] = Now()
    return self:Add({kind = "zone", map = mapID, zone = zone})
end

-- vom Dungeon-Rueckblick
function J:OnDungeon(run)
    if type(run) ~= "table" then return end
    local deaths = 0
    for _, d in pairs(run.deaths or {}) do deaths = deaths + d end
    return self:Add({kind = "dungeon", name = run.name, secs = run.secs, record = run.record, deaths = deaths,
        bosses = #(run.bosses or {})})
end

-- ===== Texte =====
local function Duration(secs)
    secs = math.max(0, math.floor(secs or 0))
    local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
    if h > 0 then return T("%d Std. %d Min.", h, m) end
    return T("%d Min.", math.max(1, m))
end
J.Duration = Duration

function J.Text(e)
    if e.kind == "quest" then
        local lvl = e.qlevel and ("[" .. e.qlevel .. "] ") or ""
        return T("Quest abgegeben: %s", lvl .. (e.title or "?")) .. (e.xp and e.xp > 0 and ("  |cff9d9d9d" .. T("+%d EP", e.xp) .. "|r") or "")
    elseif e.kind == "level" then
        return "|cffffd100" .. T("Stufe %d erreicht", e.level) .. "|r" .. (e.took and ("  |cff9d9d9d" .. T("(Stufe dauerte %s)", Duration(e.took)) .. "|r") or "")
    elseif e.kind == "zone" then
        return T("Neues Gebiet: %s", e.zone or "?")
    elseif e.kind == "dungeon" then
        return T("Dungeon: %s in %s", e.name or "?", Duration(e.secs)) .. (e.record and (" |cff40ff40" .. T("(Bestzeit)") .. "|r") or "")
            .. "  |cff9d9d9d" .. T("%d Bosse, %d Tode", e.bosses or 0, e.deaths or 0) .. "|r"
    end
    return "?"
end

-- Kurzer Rueckblick ueber alles: Quests, Stufen, Gebiete, Dungeons
function J:Summary()
    local n = {quest = 0, level = 0, zone = 0, dungeon = 0}
    for _, e in ipairs(self:Store().list) do n[e.kind] = (n[e.kind] or 0) + 1 end
    return T("%d Quests · %d Stufen · %d Gebiete · %d Dungeons", n.quest, n.level, n.zone, n.dungeon), n
end

-- Listeneintraege fuer die Seite: neueste zuerst, je Tag eine Ueberschrift
function J:Items(max)
    local list = self:Store().list
    local out, lastDay = {}, nil
    local dateFn = G("date") or (os and os.date)
    local shown = 0
    for i = #list, 1, -1 do
        local e = list[i]
        local day = dateFn and dateFn("%d.%m.%Y", e.t) or ""
        if day ~= lastDay then
            lastDay = day
            out[#out + 1] = {key = "jd" .. i, header = true, text = day}
        end
        local clock = dateFn and dateFn("%H:%M", e.t) or ""
        local where = e.zone and e.zone ~= "" and ("  |cff9d9d9d· " .. e.zone .. "|r") or ""
        out[#out + 1] = {key = "j" .. i, entry = e, text = clock .. "  " .. J.Text(e) .. (e.kind ~= "zone" and where or ""),
            qid = e.kind == "quest" and e.id or nil}
        shown = shown + 1
        if max and shown >= max then break end
    end
    return out
end

function J:Initialize()
    local f = CreateFrame("Frame")
    for _, ev in ipairs({"QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD"}) do
        pcall(f.RegisterEvent, f, ev)
    end
    f:SetScript("OnEvent", function(_, event, a, b)
        if event == "QUEST_TURNED_IN" then J:OnQuestTurnedIn(a, b)
        elseif event == "PLAYER_LEVEL_UP" then J:OnLevelUp(a)
        else
            -- Stufen-Beginn beim ersten Mal merken (ohne Eintrag), dann Gebiet pruefen
            local s = J:Store()
            local lvl = Call(G("UnitLevel"), "player")
            if not s.levelStart and lvl then s.levelStart, s.levelStartLevel = Now(), lvl end
            J:OnZone()
        end
    end)
    self.events = f
    -- Dungeon-Rueckblick meldet fertige Laeufe
    local dg = ONE.ns and ONE.ns.dungeons
    if dg and dg.Recap then
        local finish = dg.Recap.Finish
        dg.Recap.Finish = function(r, ...)
            local run = finish(r, ...)
            if run then pcall(J.OnDungeon, J, run) end
            return run
        end
    end
end
