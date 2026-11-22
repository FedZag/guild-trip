-- Guild Trip Quest-Fuehrung: echte Sammel-/Kampfzeit je Quest mitmessen (Nutzer 19.11.2026: "fast 1 Stunde
-- fuer 15 Armschienen", "ja, mitmessen"). Kampflog ist in Forever gesperrt – deshalb zaehlt die Zeit
-- ZWISCHEN zwei Fortschritten im Questlog (z. B. "Armschienen 4/15" -> "5/15"): sie gehoert der Quest,
-- die gerade weitergekommen ist. Fehlgeschlagene Kills zaehlen so automatisch mit.
-- Nicht gezaehlt wird ein Abschnitt, wenn man dazwischen weit gelaufen ist (Reise, Ruhestein, Stadt)
-- oder sehr lange nichts passiert ist (Pause). Ist die Quest erfuellt, wird hochgerechnet:
--   ONE.db.questWork[questID] = {m = Minuten fuer alle Ziele (Mittel), n = wie oft gemessen}
-- Glueck/Pech gleicht sich ueber mehrere Messungen aus. Nichts wird geteilt oder gesendet.
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local W = {}
lev.WorkLog = W

W.MOVE = 500      -- weiter gelaufen (Yards) zwischen zwei Fortschritten: Abschnitt zaehlt nicht
W.GAP = 600       -- laenger (Sekunden) nichts weitergekommen: Pause, zaehlt nicht
W.MIN_SHARE = .3  -- so viel der Ziele muss gemessen sein, sonst keine Hochrechnung
W.KEEP = 5        -- Mittel ueber hoechstens so viele Messungen (neue zaehlen mehr)

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

function W:Store()
    if not ONE.db then return {} end
    ONE.db.questWork = type(ONE.db.questWork) == "table" and ONE.db.questWork or {}
    return ONE.db.questWork
end

-- laufende Messungen je Figur (ueberstehen /reload)
local function CharKey()
    local name, realm = Call(rawget(_G, "UnitFullName"), "player")
    name = name or Call(rawget(_G, "UnitName"), "player") or "?"
    return (realm and realm ~= "") and (name .. "-" .. realm) or name
end
function W:Running()
    if not ONE.db then self.mem = self.mem or {} return self.mem end
    ONE.db.leveling = type(ONE.db.leveling) == "table" and ONE.db.leveling or {}
    local d = ONE.db.leveling
    d.workRun = type(d.workRun) == "table" and d.workRun or {}
    local key = CharKey()
    d.workRun[key] = type(d.workRun[key]) == "table" and d.workRun[key] or {}
    return d.workRun[key]
end

-- Fortschritt einer Quest: erfuellt, noetig (Summe ueber alle Ziele)
function W.Progress(objectives)
    local have, need = 0, 0
    for _, o in ipairs(objectives or {}) do
        local r = tonumber(o.numRequired) or 0
        if r > 0 then
            need = need + r
            have = have + math.min(r, tonumber(o.numFulfilled) or 0)
        end
    end
    return have, need
end

-- Ein Blick ins Questlog. quests = {{id, have, need}}, now = Sekunden, pos = {c, x, y} oder nil
function W:Observe(quests, now, pos)
    local run = self:Running()
    run.q = type(run.q) == "table" and run.q or {}
    local seen, finishedNow = {}, {}
    local moved = false
    local last = run.last
    if last and pos and last.c == pos[1] then
        moved = math.sqrt((pos[2] - last.x) ^ 2 + (pos[3] - last.y) ^ 2) > self.MOVE
    elseif last and pos then
        moved = true
    end
    local usable = last and not moved and (now - last.t) <= self.GAP and (now - last.t) >= 0
    local progressed = {}
    for _, q in ipairs(quests) do
        seen[q.id] = true
        local r = run.q[q.id]
        if not r then
            run.q[q.id] = {have = q.have, need = q.need, sec = 0, units = 0}
        else
            if q.need > 0 and q.have > r.have then
                progressed[#progressed + 1] = {r = r, d = q.have - r.have}
                if q.have >= q.need then finishedNow[#finishedNow + 1] = q.id end
            end
            r.have, r.need = q.have, q.need
        end
    end
    -- ein Kill kann mehrere Quests weiterbringen: die Zeit wird geteilt
    if usable and #progressed > 0 then
        local share = (now - last.t) / #progressed
        for _, p in ipairs(progressed) do p.r.sec, p.r.units = p.r.sec + share, p.r.units + p.d end
    end
    if #progressed > 0 and pos then run.last = {t = now, c = pos[1], x = pos[2], y = pos[3]} end
    -- erfuellt: hochrechnen und merken
    local saved = {}
    for _, id in ipairs(finishedNow) do
        local r = run.q[id]
        if r.units > 0 and r.units >= math.max(2, r.need * self.MIN_SHARE) then
            local minutes = r.sec / r.units * r.need / 60
            saved[#saved + 1] = self:Save(id, minutes)
        end
        run.q[id] = nil
    end
    -- nicht mehr im Log (abgegeben/abgebrochen): vergessen
    for id in pairs(run.q) do if not seen[id] then run.q[id] = nil end end
    return saved
end

function W:Save(id, minutes)
    local s = self:Store()
    local old = s[id]
    local n = old and old.n or 0
    local k = math.min(n, self.KEEP - 1)
    local m = old and old.m and (old.m * k + minutes) / (k + 1) or minutes
    s[id] = {m = math.floor(m * 10 + .5) / 10, n = n + 1}
    return s[id]
end

-- gemessene Minuten fuer den Planer: {questID = Minuten}
function W:Measured()
    local out = {}
    for id, v in pairs(self:Store()) do
        if type(v) == "table" and type(v.m) == "number" then out[id] = v.m end
    end
    return out
end

-- Questlog lesen (wie ONE_Nav/Quests.lua)
function W.ReadLog()
    local list, CQ = {}, rawget(_G, "C_QuestLog")
    if not (CQ and CQ.GetNumQuestLogEntries and CQ.GetInfo and CQ.GetQuestObjectives) then return list end
    for i = 1, Call(CQ.GetNumQuestLogEntries) or 0 do
        local info = Call(CQ.GetInfo, i)
        if type(info) == "table" and not info.isHeader and info.questID then
            local have, need = W.Progress(Call(CQ.GetQuestObjectives, info.questID))
            list[#list + 1] = {id = info.questID, have = have, need = need}
        end
    end
    return list
end

function W:Scan()
    local nav = ONE.ns and ONE.ns.nav
    local tr = nav and nav.Travel
    local pos
    if tr then
        local c, x, y = tr.PlayerWorld()
        if c then pos = {c, x, y} end
    end
    local saved = self:Observe(self.ReadLog(), Call(rawget(_G, "GetTime")) or 0, pos)
    if #saved > 0 and lev.Guide and lev.Guide.Replan then pcall(lev.Guide.Replan, lev.Guide) end
end

function W:Initialize()
    if ONE.RegisterSlash then
        ONE:RegisterSlash("sammelzeit", function()
            local n, list = 0, {}
            for id, v in pairs(self:Store()) do
                if type(v) == "table" and v.m then n = n + 1 list[#list + 1] = {id = id, m = v.m, n = v.n} end
            end
            table.sort(list, function(a, b) return a.m > b.m end)
            ONE:Print(T("Sammelzeit gemessen: %d Quests.", n))
            for i = 1, math.min(5, #list) do
                local d = list[i]
                local title = lev.Guide and lev.Guide.Title and lev.Guide.Title(d.id) or ("#" .. d.id)
                ONE:Print(T("  %s: %.0f min (%dx gemessen)", title, d.m, d.n or 1))
            end
        end, T("Gemessene Sammelzeit je Quest anzeigen"))
    end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "QUEST_LOG_UPDATE")
    local pending = false
    f:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        local after = rawget(_G, "C_Timer") and C_Timer.After
        local function Run() pending = false pcall(W.Scan, W) end
        if after then after(.5, Run) else Run() end
    end)
    self.events = f
end
