-- Guild Trip Quest-Fuehrung: echte Quest-EP still mitschreiben (Nutzer 19.11.2026: "EP der neuen
-- Forever-Quests messen"). Bei jeder Abgabe liefert WoW die EP (QUEST_TURNED_IN). Daraus wird die
-- Grund-EP der Quest zurueckgerechnet (Abzug fuer zu hohe Spielerstufe wie P.QuestXP) und gemerkt:
--   ONE.db.questXP[questID] = {b = Grund-EP, x = erhaltene EP, p = deine Stufe, q = Queststufe, n = wie oft}
-- Die Fuehrung nimmt gemessene Werte statt der Schaetzung aus der Datenbank. Nichts wird geteilt oder
-- gesendet; Claude liest die Werte spaeter aus der Spieldatei und verbessert damit die mitgelieferten Daten.
-- /trip epdaten zeigt, wie viele Quests gemessen sind und wo die Datenbank daneben lag.
local _, lev = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local X = {}
lev.XPLog = X

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

function X:Store()
    if not ONE.db then return {} end
    ONE.db.questXP = type(ONE.db.questXP) == "table" and ONE.db.questXP or {}
    return ONE.db.questXP
end

-- Datenbank-Eintrag einer Quest (Stufe, Grund-EP)
local function DBEntry(id)
    local d = rawget(_G, "GuildTripQuestDB")
    return d and d.q and d.q[id]
end

-- Abgabe: erhaltene EP + Spielerstufe -> Grund-EP
function X:OnTurnIn(questID, xp, plvl)
    questID, xp = tonumber(questID), tonumber(xp)
    if not questID or not xp or xp <= 0 then return nil end
    plvl = plvl or Call(rawget(_G, "UnitLevel"), "player")
    if not plvl or plvl >= 60 then return nil end
    local e = DBEntry(questID)
    local qlvl = e and e[1] and e[1] > 0 and e[1] or plvl
    local _, f = lev.Planner.QuestXP(100, qlvl, plvl)
    local s = self:Store()
    local old = s[questID]
    local entry = {b = math.floor(xp / f + .5), x = xp, p = plvl, q = qlvl, n = (old and old.n or 0) + 1}
    -- volle EP (Abstand bis 5 Stufen) sind genauer als zurueckgerechnete: nicht durch eine Schaetzung ersetzen
    if old and old.p and old.q and (old.p - old.q) <= 5 and (plvl - qlvl) > 5 then
        old.n = entry.n
        return old
    end
    s[questID] = entry
    return entry
end

-- gemessene Grund-EP fuer den Planer: {questID = Grund-EP}
function X:Measured()
    local out = {}
    for id, v in pairs(self:Store()) do
        if type(v) == "table" and type(v.b) == "number" then out[id] = v.b end
    end
    return out
end

-- Zusammenfassung fuer /trip epdaten: gemessen, davon abweichend (> 10 %)
function X:Summary()
    local n, off, list = 0, 0, {}
    for id, v in pairs(self:Store()) do
        if type(v) == "table" and v.b then
            n = n + 1
            local e = DBEntry(id)
            local base = e and e[11] or 0
            if base > 0 and math.abs(v.b - base) / base > .1 then
                off = off + 1
                list[#list + 1] = {id = id, measured = v.b, db = base}
            end
        end
    end
    table.sort(list, function(a, b) return math.abs(a.measured - a.db) > math.abs(b.measured - b.db) end)
    return n, off, list
end

function X:Initialize()
    if ONE.RegisterSlash then
        ONE:RegisterSlash("epdaten", function()
            local n, off, list = X:Summary()
            ONE:Print(T("Quest-EP gemessen: %d Quests, davon %d anders als in der Datenbank.", n, off))
            for i = 1, math.min(5, #list) do
                local d = list[i]
                local title = lev.Guide and lev.Guide.Title and lev.Guide.Title(d.id) or ("#" .. d.id)
                ONE:Print(("  %s: %d %s (%s %d)"):format(title, d.measured, T("EP"), T("Datenbank"), d.db))
            end
        end, T("Gemessene Quest-EP anzeigen"))
    end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "QUEST_TURNED_IN")
    f:SetScript("OnEvent", function(_, _, questID, xp) X:OnTurnIn(questID, xp) end)
    self.events = f
end
