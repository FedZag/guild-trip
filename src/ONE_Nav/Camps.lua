-- Guild Trip: Fundorte der Questgegner + Farm-Runde (0.7.0).
-- Fuer jede offene Quest in deinem Log: wo stehen die Gegner, die du brauchst (Lager aus
-- GuildTripQuestDB.m, scripts/import_mobs.lua)? Kleine Ringe auf Karte und Minimap.
-- Klick auf ein Lager startet eine Runde: der Pfeil fuehrt zum naechsten Lager, und sobald du
-- dort bist, weiter zum naechsten noch nicht besuchten – bis die Quest fertig ist.
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local C = {arrive = 60, tick = 2}
nav.Camps = C

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
function C.FeatureOn() return not ONE.FeatureOn or ONE:FeatureOn("nav.camps") end

-- Lager der Gegner einer Quest: {npc, name, mapID, x, y, count}
function C:ForQuest(qid)
    local Q = rawget(_G, "GuildTripQuestDB")
    local e = Q and Q.q and Q.q[qid]
    if not (e and Q.m) then return {} end
    local out = {}
    for _, nr in ipairs(e[8] or {}) do
        local row = nr > 0 and Q.m[nr]
        if row then
            for i = 4, #row, 4 do
                out[#out + 1] = {npc = nr, name = Q.mobNames and Q.mobNames[nr] or (Q.names and Q.names[nr]) or ("#" .. nr),
                    mapID = row[i], x = row[i + 1] / 1000, y = row[i + 2] / 1000, count = row[i + 3], qid = qid}
            end
        end
    end
    return out
end

-- Punkte fuer QuestPins: nur offene, nicht fertige Quests
function C:Points(log)
    local out = {}
    if not self.FeatureOn() then return out end
    for _, q in ipairs(log or {}) do
        if not q.complete then
            for _, c in ipairs(self:ForQuest(q.id)) do
                out[#out + 1] = {camp = c, q = q, mapID = c.mapID, x = c.x, y = c.y}
            end
        end
    end
    return out
end

-- ===== Runde =====
local function Distance(c)
    local navi = ONE.modules and ONE.modules.nav
    return navi and navi.DistanceTo and Call(navi.DistanceTo, navi, c.mapID, c.x, c.y)
end

-- naechstes noch nicht besuchtes Lager (Luftlinie vom Spieler)
function C:Next()
    local r = self.round
    if not r then return nil end
    local best, bd
    for i, c in ipairs(r.camps) do
        if not r.visited[i] then
            local d = Distance(c) or math.huge
            if not bd or d < bd then best, bd = i, d end
        end
    end
    return best
end

function C:PointTo(i)
    local r = self.round
    local c = r and r.camps[i]
    local navi = ONE.modules and ONE.modules.nav
    if not (c and navi and navi.PointTo) then return false end
    r.current = i
    return Call(navi.PointTo, navi, T("%s (%d/%d)", c.name, r.visitedCount + 1, #r.camps), c.mapID, c.x, c.y) and true or false
end

function C:StartRound(q)
    local camps = q and self:ForQuest(q.id) or {}
    if #camps == 0 then return false end
    self.round = {q = q, qid = q.id, camps = camps, visited = {}, visitedCount = 0}
    ONE:Print(T("Farm-Runde für „%s“: %d Lager – der Pfeil führt von Lager zu Lager.", q.title or "?", #camps))
    return self:PointTo(self:Next())
end

function C:StopRound(why)
    if not self.round then return end
    self.round = nil
    if why then ONE:Print(why) end
end

-- Im Takt: angekommen? -> naechstes Lager; Quest fertig? -> Ende
function C:Tick()
    local r = self.round
    if not r then return end
    for _, q in ipairs(nav.Quests and nav.Quests:Log() or {}) do
        if q.id == r.qid and q.complete then return self:StopRound(T("„%s“ ist fertig – Farm-Runde beendet.", q.title or "?")) end
    end
    local c = r.current and r.camps[r.current]
    local d = c and Distance(c)
    if d and d <= self.arrive then
        r.visited[r.current] = true
        r.visitedCount = r.visitedCount + 1
        local nextI = self:Next()
        if not nextI then
            -- alle besucht: von vorn (die Gegner sind inzwischen wieder da)
            r.visited, r.visitedCount = {}, 1
            r.visited[r.current] = true
            nextI = self:Next()
        end
        if nextI then self:PointTo(nextI) end
    end
end

function C:Initialize()
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        C_Timer.NewTicker(self.tick, function() if C.round then pcall(C.Tick, C) end end)
    end
end
