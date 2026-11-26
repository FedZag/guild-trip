-- Guild Trip Dungeons: Gildenausfluege (Stufe 1: anlegen, anmelden, absagen;
-- Stufe 2: Reisevorbereitung; Stufe 3: Erinnerung, Navi zum Treffpunkt, Ankunftstafel).
-- Ein Ausflug = Dungeon + Startzeit + Treffpunkt. Mitglieder melden sich mit
-- ihrer Rolle an ("komme" / "vielleicht"). Laeuft ueber denselben Gilden-Kanal
-- wie der Gruppenfinder (Share.prefix), Nachrichten beginnen mit "T":
--   TA|id|dungeon|start|mapID|x|y|treffpunkt|titel   Ausflug (nur vom Leiter);
--       dungeon = "free" + titel: eigenes Ziel (Questrun, Gildentreffen …), seit 15.11.2026
--   TC|id                                       Ausflug abgesagt (nur vom Leiter)
--   TX|id|art|dauer|wdh|erinn|plaetze|t|h|d|stufeVon|stufeBis|notiz   Zusatzangaben (Termin-Fenster,
--       15.11.2026; aeltere Versionen ignorieren TX – der Ausflug selbst bleibt lesbar)
--   TS|id|status|rolle|stufe|klasse             eigene Anmeldung (status yes/maybe/no)
--   TQ|id|anzahl|zeichen                        Quest-Stand fuer die Reisevorbereitung,
--       ein Zeichen je Quest des Dungeons: d erledigt, l im Questlog, o annehmbar,
--       x Vorquest fehlt, - nicht fuer mich. Nur mit "Dungeon-Fortschritt teilen".
-- Jeder sendet nur, was ihm gehoert (Leiter den Ausflug, Mitglied seine Anmeldung),
-- und wiederholt es auf Anfrage (REQ) – so kennen auch Spaetkommer alles.
-- Ausfluege werden gespeichert und 4 Stunden nach dem Start aufgeraeumt.
local _, dungeons = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- prepData: Quest-Stand der anderen je Ausflug – nur im Arbeitsspeicher, nie gespeichert
local Trips = {keep = 4 * 3600, prepData = {}}
dungeons.Trips = Trips

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function Me()
    local name, realm = Call(UnitFullName, "player")
    if name and realm and realm ~= "" then return name .. "-" .. realm end
    return name or Call(UnitName, "player") or "?"
end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end
local function Same(a, b) return type(a) == "string" and type(b) == "string" and Short(a) == Short(b) end
local function Clean(text, max)
    text = tostring(text or ""):gsub("[|\r\n]", " ")
    if #text > max then text = text:sub(1, max) end
    return text
end
Trips.Short = Short

function Trips:Now() return Call(GetServerTime) or Call(time) or 0 end

function Trips:Store()
    local s = dungeons.Model:Store()
    s.trips = type(s.trips) == "table" and s.trips or {}
    return s.trips
end

-- Alte Ausfluege aufraeumen; Ergebnis: sichtbare Ausfluege nach Startzeit
function Trips:List()
    local now, out = self:Now(), {}
    local again = {}
    for id, trip in pairs(self:Store()) do
        if type(trip) ~= "table" or (trip.start or 0) + self.keep < now then
            -- woechentlich: der Leiter legt den naechsten Termin an (Anmeldungen beginnen neu)
            if type(trip) == "table" and trip.rep == "w" and not trip.stub and self:IsLeader(trip) then again[#again + 1] = trip end
            self:Store()[id] = nil
        elseif not trip.stub then
            out[#out + 1] = trip
        end
    end
    for _, old in ipairs(again) do
        local start = old.start
        while start + self.keep < now do start = start + 7 * 86400 end
        local extra = {}
        for _, k in ipairs(Trips.extraKeys) do extra[k] = old[k] end
        local trip = self:Create(old.key, start, old.meet, old.title, extra)
        if trip then out[#out + 1] = trip end
    end
    table.sort(out, function(a, b) return (a.start or 0) < (b.start or 0) end)
    return out
end

-- ===== Termin-Arten und Zusatzangaben (Termin-Fenster, 15.11.2026) =====
-- size 0 = offen; roles = {Tank, Heiler, DD} als Vorschlag
Trips.kinds = {
    {key = "dungeon", label = "Dungeon", size = 5, roles = {1, 1, 3}},
    {key = "raid", label = "Raid", size = 20, roles = {2, 4, 14}},
    {key = "quest", label = "Quests", size = 5, roles = {0, 0, 0}},
    {key = "meet", label = "Treffen", size = 0},
    {key = "pvp", label = "PvP", size = 0},
    {key = "farm", label = "Farmen", size = 0},
    {key = "fest", label = "Fest", size = 0},
    {key = "other", label = "Anderes", size = 0},
}
Trips.kindByKey = {}
for _, k in ipairs(Trips.kinds) do Trips.kindByKey[k.key] = k end
-- Classic-Raids (der Dungeon-Katalog kennt keine Raids); Schluessel "raid:<kurz>"
Trips.raids = {
    {key = "raid:zg", name = "Zul'Gurub", min = 58, size = 20},
    {key = "raid:aq20", name = "Ruinen von Ahn'Qiraj", min = 60, size = 20},
    {key = "raid:mc", name = "Geschmolzener Kern", min = 60, size = 40},
    {key = "raid:ony", name = "Onyxias Hort", min = 60, size = 40},
    {key = "raid:bwl", name = "Pechschwingenhort", min = 60, size = 40},
    {key = "raid:aq40", name = "Tempel von Ahn'Qiraj", min = 60, size = 40},
    {key = "raid:naxx", name = "Naxxramas", min = 60, size = 40},
}
Trips.durations = {60, 120, 180, 240, 0}
Trips.reminds = {15, 60, 0}
Trips.sizes = {5, 10, 20, 40, 0}
Trips.extraKeys = {"kind", "dur", "rep", "remind", "size", "roles", "lmin", "lmax", "note"}

function Trips.RaidName(key)
    for _, r in ipairs(Trips.raids) do if r.key == key then return T(r.name) end end
end

-- Treffpunkt nach Wahl: here (eigener Standort), entrance (Dungeon-Eingang),
-- capital (Hauptstadt der eigenen Fraktion, ungefaehr), later (noch offen)
Trips.capitals = {
    Horde = {mapID = 1454, x = .515, y = .665, name = "Orgrimmar, Tal der Stärke"},
    Alliance = {mapID = 1453, x = .620, y = .700, name = "Sturmwind, Handelsdistrikt"},
}
function Trips:MeetFor(choice, key)
    if choice == "here" then return self:HereMeet() end
    if choice == "entrance" and dungeons.Entrances and key then
        local e = dungeons.Entrances:Get(key)
        if e then return {mapID = e.mapID, x = e.x, y = e.y, name = T("Eingang: %s", dungeons.Share:DungeonName(key))} end
        return nil
    end
    if choice == "capital" then
        local faction = Call(UnitFactionGroup, "player")
        local c = self.capitals[faction == "Alliance" and "Alliance" or "Horde"]
        return {mapID = c.mapID, x = c.x, y = c.y, name = T(c.name)}
    end
    return {name = ""}
end

-- "T 1/1 · H 0/1 · DD 2/3" (nur wenn Rollen geplant sind)
function Trips:RoleText(trip)
    local r = trip and trip.roles
    if type(r) ~= "table" or (r[1] or 0) + (r[2] or 0) + (r[3] or 0) == 0 then return nil end
    local c = self:Counts(trip)
    return string.format("%s %d/%d · %s %d/%d · %s %d/%d", T("T"), c.T, r[1] or 0, T("H"), c.H, r[2] or 0, T("DD"), c.D, r[3] or 0)
end

-- Kurzinfo: "Quests · 2 Std. · Stufe 15–24 · woechentlich"
function Trips:InfoText(trip)
    local parts = {}
    local k = trip.kind and Trips.kindByKey[trip.kind]
    if k then parts[#parts + 1] = T(k.label) end
    if (trip.dur or 0) > 0 then parts[#parts + 1] = T("%d Std.", math.floor(trip.dur / 60)) end
    if trip.lmin or trip.lmax then parts[#parts + 1] = T("Stufe %d–%d", trip.lmin or 1, trip.lmax or 60) end
    if (trip.size or 0) > 0 then parts[#parts + 1] = T("%d Plätze", trip.size) end
    if trip.rep == "w" then parts[#parts + 1] = T("wöchentlich") end
    return table.concat(parts, " · ")
end

function Trips:SendExtra(trip)
    if not trip.kind then return false end
    local r = type(trip.roles) == "table" and trip.roles or {}
    return self:Send(table.concat({"TX", trip.id, Clean(trip.kind, 8), tostring(trip.dur or 0), trip.rep == "w" and "w" or "",
        tostring(trip.remind or 15), tostring(trip.size or 0), tostring(r[1] or 0), tostring(r[2] or 0), tostring(r[3] or 0),
        tostring(trip.lmin or 0), tostring(trip.lmax or 0), Clean(trip.note, 60)}, "|"))
end

-- Anzeigename: eigener Titel (freies Ziel) oder Dungeon-Name
Trips.FREE = "free"
function Trips:Name(trip)
    if not trip then return "?" end
    if type(trip.title) == "string" and trip.title ~= "" then return trip.title end
    if trip.key == Trips.FREE then return T("Gildenausflug") end
    return Trips.RaidName(trip.key) or dungeons.Share:DungeonName(trip.key)
end
function Trips.IsFree(trip) return trip and trip.key == Trips.FREE end

function Trips:Get(id) local t = self:Store()[id] return t and not t.stub and t or nil end
function Trips:IsLeader(trip) return trip and Same(trip.leader, Me()) end
function Trips:Mine(trip) return trip and trip.signups and trip.signups[Short(Me())] end

-- Anmeldungen zaehlen: zugesagt je Rolle + vielleicht
function Trips:Counts(trip)
    local c = {T = 0, H = 0, D = 0, yes = 0, maybe = 0}
    for _, s in pairs(trip and trip.signups or {}) do
        if s.status == "yes" then
            c.yes = c.yes + 1
            if c[s.role] then c[s.role] = c[s.role] + 1 end
        elseif s.status == "maybe" then
            c.maybe = c.maybe + 1
        end
    end
    return c
end

-- Anmeldungen als Liste (zugesagt zuerst, dann vielleicht; nach Rolle)
local ROLE_ORDER = {T = 1, H = 2, D = 3}
function Trips:Signups(trip)
    local out = {}
    for _, s in pairs(trip and trip.signups or {}) do
        if s.status == "yes" or s.status == "maybe" then out[#out + 1] = s end
    end
    table.sort(out, function(a, b)
        if a.status ~= b.status then return a.status == "yes" end
        if a.role ~= b.role then return (ROLE_ORDER[a.role] or 9) < (ROLE_ORDER[b.role] or 9) end
        return a.name < b.name
    end)
    return out
end

-- Treffpunkt = eigener Standort jetzt (Karte, x/y 0..1, Name des Gebiets)
function Trips:HereMeet()
    local map = C_Map and Call(C_Map.GetBestMapForUnit, "player")
    local pos = map and C_Map and Call(C_Map.GetPlayerMapPosition, map, "player")
    local x, y
    if pos and pos.GetXY then x, y = pos:GetXY() end
    local name = Call(GetSubZoneText)
    if not name or name == "" then name = Call(GetZoneText) end
    if not (map and x and y) then return {name = name or ""} end
    return {mapID = map, x = x, y = y, name = name or ""}
end

-- ===== Senden =====
function Trips:Send(msg) return dungeons.Share:Send(msg) end

function Trips:SendTrip(trip)
    local m = trip.meet or {}
    local ok = self:Send(table.concat({"TA", trip.id, trip.key, tostring(trip.start),
        tostring(m.mapID or 0), tostring(m.x and math.floor(m.x * 10000) or 0), tostring(m.y and math.floor(m.y * 10000) or 0),
        Clean(m.name, 40), Clean(trip.title, 40)}, "|"))
    self:SendExtra(trip)
    return ok
end

function Trips:SendSignup(trip)
    local s = self:Mine(trip)
    if not s then return false end
    return self:Send(table.concat({"TS", trip.id, s.status, s.role or "D", tostring(s.level or 0), tostring(s.class or "")}, "|"))
end

-- Auf Anfrage alles Eigene wiederholen
function Trips:Broadcast()
    for _, trip in ipairs(self:List()) do
        if self:IsLeader(trip) then self:SendTrip(trip) end
        local mine = self:Mine(trip)
        if mine and mine.status ~= "no" then self:SendSignup(trip) self:SendPrep(trip) end
    end
end

-- ===== Reisevorbereitung =====
-- Alle Quests des Dungeons in fester Reihenfolge (gleich fuer alle Mitglieder)
function Trips:Quests(key)
    for _, entry in ipairs(dungeons.Catalog or {}) do
        if entry.key == key then
            local data = dungeons.Model:QuestTable(entry.quests)
            return data and data.quests or {}
        end
    end
    return {}
end

function Trips:MyCodes(key)
    local M, out = dungeons.Model, {}
    for i, q in ipairs(self:Quests(key)) do
        local code = "-"
        if M:Visible(q) then code = ({done = "d", log = "l", locked = "x", open = "o"})[M:Status(q)] or "o" end
        out[i] = code
    end
    return table.concat(out)
end

function Trips:SendPrep(trip)
    local mine = self:Mine(trip)
    if not (mine and mine.status ~= "no" and dungeons.Share:IsSharing()) then return false end
    local codes = self:MyCodes(trip.key)
    if codes == "" or #codes > 200 then return false end
    return self:Send(table.concat({"TQ", trip.id, tostring(#codes), codes}, "|"))
end

-- Nach Quest-Aenderungen (kurz gesammelt) den neuen Stand senden
function Trips:QuestsChanged()
    if self.pending then return end
    self.pending = true
    local function Go()
        self.pending = false
        for _, trip in ipairs(self:List()) do self:SendPrep(trip) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(3, Go) else Go() end
end

-- Je Quest: wer traegt sie (im Log), wer braucht sie, wem fehlt die Vorquest.
-- Ergebnis: rows (nur Quests, die jemand braucht) und unknown (Teilnehmer ohne Stand).
function Trips:Prep(trip)
    local quests = self:Quests(trip.key)
    local me = Short(Me())
    local members, unknown = {}, {}
    for _, s in pairs(trip.signups or {}) do
        if s.status == "yes" or s.status == "maybe" then
            local codes = s.name == me and self:MyCodes(trip.key) or (self.prepData[trip.id] or {})[s.name]
            if codes and #codes == #quests then members[#members + 1] = {name = s.name, codes = codes}
            else unknown[#unknown + 1] = s.name end
        end
    end
    table.sort(members, function(a, b) return a.name < b.name end)
    table.sort(unknown)
    local rows = {}
    for i, q in ipairs(quests) do
        local row = {quest = q, index = i, carriers = {}, open = {}, locked = {}}
        for _, m in ipairs(members) do
            local c = m.codes:sub(i, i)
            if c == "l" then row.carriers[#row.carriers + 1] = m.name
            elseif c == "o" then row.open[#row.open + 1] = m.name
            elseif c == "x" then row.locked[#row.locked + 1] = m.name end
        end
        if #row.carriers + #row.open + #row.locked > 0 then
            -- Klassenquests holt jeder selbst; sonst reicht ein Traeger fuer alle
            if q.classOnly then row.state = "self"
            elseif #row.carriers > 0 then row.state = "carried"
            elseif #row.open > 0 then row.state = "fetch"
            else row.state = "locked" end
            rows[#rows + 1] = row
        end
    end
    local order = {fetch = 1, locked = 2, self = 3, carried = 4}
    table.sort(rows, function(a, b)
        if a.state ~= b.state then return order[a.state] < order[b.state] end
        return a.index < b.index
    end)
    return rows, unknown, members
end

-- Kurzer Text zu einer Zeile der Reisevorbereitung
function Trips:PrepText(row)
    local q = row.quest
    local parts = {}
    if row.state == "carried" then parts[#parts + 1] = T("Träger: %s", table.concat(row.carriers, ", "))
    elseif row.state == "fetch" then parts[#parts + 1] = T("Noch kein Träger – holen bei %s", q.giver or "?")
    elseif row.state == "self" then parts[#parts + 1] = T("Klassenquest – jeder selbst: %s", table.concat(row.open, ", "))
    end
    if #row.locked > 0 then
        local pre = {}
        for _, p in ipairs(dungeons.Model:Prereqs(q)) do pre[#pre + 1] = p.name end
        parts[#parts + 1] = T("Vorquest fehlt: %s", table.concat(row.locked, ", "))
            .. (#pre > 0 and (" (" .. table.concat(pre, ", ") .. ")") or "")
    end
    return table.concat(parts, " · ")
end

-- ===== Eigene Aktionen =====
function Trips:Create(key, start, meet, title, extra)
    if type(key) ~= "string" or type(start) ~= "number" then return nil end
    title = type(title) == "string" and Clean(title, 40):match("^%s*(.-)%s*$") or nil
    if key == Trips.FREE and (not title or title == "") then return nil end -- freies Ziel braucht einen Titel
    local me = Me()
    local id = Clean(Short(me), 12) .. tostring(start % 1000000) .. tostring(math.random and math.random(10, 99) or 10)
    local trip = {id = id, leader = me, key = key, start = start, meet = meet or {}, signups = {},
        title = title ~= "" and title or nil}
    for _, k in ipairs(Trips.extraKeys) do if type(extra) == "table" and extra[k] ~= nil then trip[k] = extra[k] end end
    if type(trip.note) == "string" then trip.note = Clean(trip.note, 60) end
    self:Store()[id] = trip
    self:SendTrip(trip)
    self:SignUp(id, "yes")
    return trip
end

function Trips:Cancel(id)
    local trip = self:Get(id)
    if not (trip and self:IsLeader(trip)) then return false end
    self:Store()[id] = nil
    self:Send("TC|" .. id)
    return true
end

-- status: "yes" (komme), "maybe" (vielleicht), "no" (abmelden)
function Trips:SignUp(id, status)
    local trip = self:Get(id)
    if not trip then return false end
    local S, M = dungeons.Share, dungeons.Model
    trip.signups = trip.signups or {}
    trip.signups[Short(Me())] = {name = Short(Me()), status = status, role = S:Settings().role,
        level = M:PlayerLevel(), class = M:PlayerClass()}
    self:SendSignup(trip)
    self:SendPrep(trip)
    return true
end

-- ===== Empfangen (aus Share:Receive) =====
function Trips:Receive(kind, p, sender)
    local store = self:Store()
    local id = p[2]
    if not id or id == "" then return end
    if kind == "TA" then
        local trip = store[id]
        if trip and not trip.stub and not Same(trip.leader, sender) then return end
        local isNew = not trip or trip.stub
        trip = trip or {id = id, signups = {}}
        -- Zusatzangaben eines anderen Absenders (TX vor TA) verwerfen
        if trip.xfrom and not Same(trip.xfrom, sender) then for _, k in ipairs(Trips.extraKeys) do trip[k] = nil end end
        trip.stub, trip.leader, trip.key, trip.start = nil, sender, p[3], tonumber(p[4]) or 0
        local map, x, y = tonumber(p[5]) or 0, tonumber(p[6]) or 0, tonumber(p[7]) or 0
        trip.meet = map > 0 and {mapID = map, x = x / 10000, y = y / 10000, name = p[8] or ""} or {name = p[8] or ""}
        trip.title = (p[9] and p[9] ~= "") and p[9] or nil
        store[id] = trip
        if isNew and trip.start + self.keep >= self:Now() then
            dungeons.Share:Tell(T("Neuer Gildenausflug: %s am %s (von %s).", self:Name(trip),
                self:When(trip.start), Short(sender)))
        end
    elseif kind == "TX" then
        -- Zusatzangaben nur vom Leiter (kommt TX vor TA an, wird der Absender beim TA geprueft)
        local trip = store[id]
        if trip and not trip.stub and not Same(trip.leader, sender) then return end
        if not trip then trip = {id = id, stub = true, start = self:Now(), signups = {}} store[id] = trip end
        local function N(v, max) v = tonumber(v) return v and v >= 0 and v <= max and math.floor(v) or nil end
        trip.kind = Trips.kindByKey[p[3] or ""] and p[3] or nil
        trip.dur, trip.rep, trip.remind, trip.size = N(p[4], 1440), p[5] == "w" and "w" or nil, N(p[6], 1440), N(p[7], 40)
        trip.roles = {N(p[8], 40) or 0, N(p[9], 40) or 0, N(p[10], 40) or 0}
        local lmin, lmax = N(p[11], 100), N(p[12], 100)
        trip.lmin, trip.lmax = (lmin or 0) > 0 and lmin or nil, (lmax or 0) > 0 and lmax or nil
        trip.note = (p[13] and p[13] ~= "") and p[13]:sub(1, 60) or nil
        trip.xfrom = sender
    elseif kind == "TC" then
        local trip = store[id]
        if trip and Same(trip.leader, sender) then store[id] = nil end
    elseif kind == "TQ" then
        local trip = store[id]
        local n, codes = tonumber(p[3]), p[4] or ""
        if not trip or trip.stub or not n or #codes ~= n or codes:find("[^dlox%-]") then return end
        if n ~= #self:Quests(trip.key) then return end -- andere Datenversion
        self.prepData[id] = self.prepData[id] or {}
        self.prepData[id][Short(sender)] = codes
    elseif kind == "TS" then
        local status = p[3]
        if status ~= "yes" and status ~= "maybe" and status ~= "no" then return end
        local trip = store[id] or {id = id, stub = true, start = self:Now(), signups = {}}
        store[id] = trip
        trip.signups = trip.signups or {}
        local before = trip.signups[Short(sender)]
        trip.signups[Short(sender)] = {name = Short(sender), status = status, role = p[4], level = tonumber(p[5]) or 0, class = p[6]}
        if self:IsLeader(trip) and status ~= "no" and not (before and before.status == status) then
            dungeons.Share:Tell(T("%s kommt mit zum Ausflug nach %s (%s).", Short(sender), self:Name(trip),
                dungeons.Share:RoleName(p[4])))
        end
    end
end

-- ===== Stufe 3: Erinnerung, Navi fuer alle, Ankunftstafel =====
Trips.remindBefore = 15 * 60  -- erste Erinnerung 15 Minuten vorher
Trips.lateStart = 15 * 60     -- wer spaeter einloggt, bekommt keine Startmeldung mehr
Trips.boardBefore = 30 * 60   -- Ankunftstafel ab 30 Minuten vorher …
Trips.boardAfter = 2 * 3600   -- … bis 2 Stunden nach dem Start
Trips.speed = 7               -- Yards je Sekunde zu Fuss (grobe Schaetzung)
Trips.hereRange = 40          -- so nah = "da"
Trips.summonRange = 500       -- weiter weg = Hexer kann beschwoeren

local function Nav() return ONE.modules and ONE.modules.nav end
local function FeatureOn(id) return not ONE.FeatureOn or ONE:FeatureOn(id) end

function Trips:Joined(trip)
    local m = self:Mine(trip)
    return m ~= nil and (m.status == "yes" or m.status == "maybe")
end

function Trips:BoardActive(trip)
    local now = self:Now()
    return trip and now >= trip.start - self.boardBefore and now <= trip.start + self.boardAfter
end

-- Eigene Entfernung zum Treffpunkt (Yards) oder nil
function Trips:MyDistance(trip)
    local m, navi = trip and trip.meet, Nav()
    if not (m and m.mapID and navi and navi.DistanceTo) then return nil end
    return navi:DistanceTo(m.mapID, m.x, m.y)
end

-- Navi zum Treffpunkt, wenn man nicht schon dort steht
function Trips:StartNavi(trip)
    local m, navi = trip and trip.meet, Nav()
    if not (m and m.mapID and navi and navi.PointTo) then return false end
    local d = self:MyDistance(trip)
    if d and d <= self.hereRange then return false end
    -- Laeuft ein anderes Navi-Addon mit eigenem Pfeil (Polestar), nicht von selbst starten
    if navi.AutoNaviAllowed and not navi:AutoNaviAllowed() then return false end
    return navi:PointTo(T("Treffpunkt"), m.mapID, m.x, m.y) and true or false
end

-- Je Teilnehmer: Entfernung und geschaetzte Ankunft.
-- state: here (da), away (unterwegs, dist/eta), continent (anderer Kontinent), unknown (kein Standort)
function Trips:Board(trip)
    local me, m, navi = Short(Me()), trip.meet or {}, Nav()
    local guild = ONE.modules and ONE.modules.guild
    local peers = {}
    if guild and guild.LivePeers then
        for _, p in ipairs(guild:LivePeers() or {}) do peers[Short(p.name)] = p end
    end
    local out = {}
    for _, s in ipairs(self:Signups(trip)) do
        local e = {name = s.name, signup = s, state = "unknown"}
        local dist, why
        if m.mapID then
            if s.name == me then
                dist = self:MyDistance(trip)
                if not dist and navi and navi.DistanceBetween then
                    local here = self:HereMeet()
                    if here.mapID then dist, why = navi:DistanceBetween(here.mapID, here.x, here.y, m.mapID, m.x, m.y) end
                end
            elseif peers[s.name] and navi and navi.DistanceBetween then
                local p = peers[s.name]
                dist, why = navi:DistanceBetween(p.mapID, p.x, p.y, m.mapID, m.x, m.y)
            end
        end
        if dist then
            e.dist = dist
            if dist <= self.hereRange then e.state = "here"
            else e.state, e.eta = "away", math.max(1, math.ceil(dist / self.speed / 60)) end
        elseif why == "continent" then
            e.state = "continent"
        end
        out[#out + 1] = e
    end
    return out
end

function Trips:BoardText(e)
    if e.state == "here" then return T("am Treffpunkt") end
    if e.state == "away" then return T("%d m · ca. %d min", math.floor(e.dist + .5), e.eta) end
    if e.state == "continent" then return T("anderer Kontinent") end
    return T("kein Standort")
end

-- Hexer: wen lohnt es zu beschwoeren (weit weg oder anderer Kontinent)?
function Trips:SummonList(board)
    local class = dungeons.Model:PlayerClass()
    if class ~= "WARLOCK" then return {} end
    local out, me = {}, Short(Me())
    for _, e in ipairs(board) do
        local far = e.state == "continent" or (e.state == "away" and e.dist > self.summonRange)
        if far and e.name ~= me then out[#out + 1] = e.name end
    end
    return out
end

-- Takt: Erinnerungen (je Ausflug und Anlass nur einmal, auch ueber /reload) und
-- Auffrischen der sichtbaren Ankunftstafel
function Trips:Tick()
    local now, board = self:Now(), false
    for _, trip in ipairs(self:List()) do
        if self:BoardActive(trip) then board = true end
        if self:Joined(trip) and FeatureOn("dungeons.tripReminders") then
            trip.reminded = trip.reminded or {}
            local left = trip.start - now
            local name = self:Name(trip)
            local meet = trip.meet and trip.meet.name ~= "" and trip.meet.name or T("noch offen")
            local before = (trip.remind or self.remindBefore / 60) * 60
            if left > 0 and before > 0 and left <= before and not trip.reminded.soon then
                trip.reminded.soon = true
                ONE:Notify(T("Gildenausflug nach %s beginnt in %d Minuten – Treffpunkt: %s.", name, math.ceil(left / 60), meet),
                    {source = T("Guild Trip Ausflug")})
            elseif left <= 0 and not trip.reminded.start then
                trip.reminded.start = true
                if left > -self.lateStart then
                    local navi = self:StartNavi(trip)
                    ONE:Notify(navi and T("Gildenausflug nach %s beginnt jetzt – das Navi zeigt dir den Weg zum Treffpunkt (%s).", name, meet)
                        or T("Gildenausflug nach %s beginnt jetzt – Treffpunkt: %s.", name, meet), {source = T("Guild Trip Ausflug"), sound = "trip"})
                end
            end
        end
    end
    local ui = ONE.UI
    if board and ui and ui.frame and ui.frame:IsShown() and ui.activeTab == "dungeons" and dungeons.TripsPage then
        dungeons.TripsPage:Refresh()
    end
end

function Trips:Initialize()
    if self.ticker or not (C_Timer and type(C_Timer.NewTicker) == "function") then return end
    self.ticker = C_Timer.NewTicker(10, function() self:Tick() end)
end

-- ===== Anzeige =====
local DAYS = {"So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"}
-- "heute 20:00", "morgen 19:30", "Fr 14.11. 20:00"
function Trips:When(start)
    if type(date) ~= "function" then return tostring(start) end
    local now = self:Now()
    local d, today = date("*t", start), date("*t", now)
    local tomorrow = date("*t", now + 86400)
    local clock = string.format("%02d:%02d", d.hour, d.min)
    if d.year == today.year and d.yday == today.yday then return T("heute %s", clock) end
    if d.year == tomorrow.year and d.yday == tomorrow.yday then return T("morgen %s", clock) end
    return string.format("%s %02d.%02d. %s", T(DAYS[d.wday] or ""), d.day, d.month, clock)
end

-- Auswahl fuer das Formular: die naechsten 7 Tage und Uhrzeiten im 30-Minuten-Takt
function Trips:DayOptions()
    local out, now = {}, self:Now()
    for i = 0, 6 do
        local t = now + i * 86400
        local label = i == 0 and T("Heute") or i == 1 and T("Morgen")
            or (type(date) == "function" and string.format("%s %s", T(DAYS[date("*t", t).wday] or ""), date("%d.%m.", t)) or tostring(i))
        out[#out + 1] = {value = i, text = label}
    end
    return out
end
function Trips:TimeOptions()
    local out = {}
    for m = 10 * 60, 23 * 60 + 30, 30 do out[#out + 1] = {value = m, text = string.format("%02d:%02d", math.floor(m / 60), m % 60)} end
    return out
end
-- Tag (0 = heute) + Minuten seit Mitternacht -> Zeitpunkt
function Trips:StartFrom(dayOffset, minutes)
    if type(date) ~= "function" or type(time) ~= "function" then return nil end
    local d = date("*t", self:Now() + (dayOffset or 0) * 86400)
    return time({year = d.year, month = d.month, day = d.day, hour = math.floor(minutes / 60), min = minutes % 60, sec = 0})
end
