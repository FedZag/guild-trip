-- Guild Trip Reisepass (0.6.8, Nutzer-Idee „Gilden-Reisepass mit Stempeln“):
-- Jeder Dungeon, den du betrittst, gibt einen Stempel (erster Besuch, Anzahl Läufe, Gruppengröße),
-- jeder Gildenausflug, zu dem du zugesagt hast, ebenfalls (Datum, wie viele dabei waren).
-- Mit „Fortschritt teilen“ sieht die Gilde die Pässe der anderen (Nachricht PS über ONEGRP1).
-- Gespeichert je Figur in ONE.db.dungeons.pass[Name]; fremde Pässe nur für die Sitzung.
local _, dungeons = ...
local ONE = _G.ProjectONE
local Pass = {peers = {}, maxTrips = 60, minGap = 3600}
dungeons.Passport = Pass

local function Call(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b, c = pcall(fn, ...) if ok then return a, b, c end end
local function Now() return Call(GetServerTime) or Call(time) or 0 end
local function Me() return Call(UnitName, "player") or "?" end
local function Short(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end

-- Eigener Pass dieser Figur
function Pass:Mine()
    if not ONE.db then return {d = {}, t = {}} end
    ONE.db.dungeons = type(ONE.db.dungeons) == "table" and ONE.db.dungeons or {}
    local all = type(ONE.db.dungeons.pass) == "table" and ONE.db.dungeons.pass or {}
    ONE.db.dungeons.pass = all
    local me = Me()
    local p = type(all[me]) == "table" and all[me] or {}
    p.d = type(p.d) == "table" and p.d or {}
    p.t = type(p.t) == "table" and p.t or {}
    all[me] = p
    return p
end

-- Dungeon betreten: neuer Stempel bzw. weiterer Lauf (Neu laden im selben Dungeon zählt nicht)
function Pass:Visit(key, size, when)
    if type(key) ~= "string" or key == "" then return false end
    when = when or Now()
    local p = self:Mine()
    local s = p.d[key]
    if s and s.last and when - s.last < self.minGap then s.last = when return false end
    if s then
        s.runs, s.last = (s.runs or 1) + 1, when
    else
        p.d[key] = {first = when, last = when, runs = 1, size = size or 0}
    end
    self:Changed()
    return true
end

-- Gildenausflug: Stempel, sobald er begonnen hat und du zugesagt hast
function Pass:StampTrips(now)
    local Trips = dungeons.Trips
    if not (Trips and Trips.List) then return 0 end
    now = now or Now()
    local p, added = self:Mine(), 0
    for _, trip in ipairs(Trips:List()) do
        local mine = Trips:Mine(trip)
        if trip.id and (trip.start or 0) <= now and mine and mine.status == "yes" and not self:HasTrip(p, trip.id) then
            local c = Trips:Counts(trip)
            p.t[#p.t + 1] = {id = trip.id, title = Trips:Name(trip), time = trip.start, count = c.yes or 1, key = trip.key}
            added = added + 1
        end
    end
    while #p.t > self.maxTrips do table.remove(p.t, 1) end
    if added > 0 then self:Changed() end
    return added
end
function Pass:HasTrip(p, id)
    for _, t in ipairs(p.t) do if t.id == id then return true end end
    return false
end

-- Stempel als Liste fuer die Anzeige: Dungeons (neueste zuerst) und Ausfluege (neueste zuerst)
function Pass.Stamps(p)
    local d, t = {}, {}
    for key, s in pairs(p and p.d or {}) do d[#d + 1] = {key = key, first = s.first, last = s.last, runs = s.runs or 1, size = s.size} end
    table.sort(d, function(a, b) return (a.first or 0) > (b.first or 0) end)
    for _, s in ipairs(p and p.t or {}) do t[#t + 1] = s end
    table.sort(t, function(a, b) return (a.time or 0) > (b.time or 0) end)
    return d, t
end
function Pass.Count(p)
    local n = 0
    for _ in pairs(p and p.d or {}) do n = n + 1 end
    return n + #(p and p.t or {})
end

-- ===== Gilde =====
-- PS|<dungeon-schluessel,…>|<anzahl ausfluege>|<erster stempel (zeit)>
function Pass:Message()
    local p = self:Mine()
    local keys = {}
    for key in pairs(p.d) do keys[#keys + 1] = key end
    table.sort(keys)
    local list = table.concat(keys, ",")
    if #list > 200 then list = list:sub(1, 200):match("^(.*),") or "" end
    return "PS|" .. list .. "|" .. #p.t
end
function Pass:Send()
    local S = dungeons.Share
    if not (S and S.IsSharing and S:IsSharing()) then return false end
    return S:Send(self:Message())
end
function Pass:Receive(msg, sender)
    local list, trips = msg:match("^PS|([^|]*)|(%d+)")
    if not list then return false end
    local d = {}
    for key in list:gmatch("[^,]+") do d[key] = {runs = 1} end
    self.peers[Short(sender)] = {name = Short(sender), d = d, t = {}, trips = tonumber(trips) or 0, seen = Call(GetTime) or 0}
    if dungeons.Share and dungeons.Share.onChange then pcall(dungeons.Share.onChange) end
    return true
end
-- Alle Paesse fuer die Liste: du zuerst, dann die Gilde nach Anzahl Stempel
function Pass:People()
    local me = self:Mine()
    local out = {{name = Short(Me()), me = true, pass = me, count = Pass.Count(me)}}
    for name, peer in pairs(self.peers) do
        if name ~= Short(Me()) then
            local n = 0
            for _ in pairs(peer.d) do n = n + 1 end
            out[#out + 1] = {name = name, pass = peer, count = n + (peer.trips or 0)}
        end
    end
    table.sort(out, function(a, b)
        if a.me ~= b.me then return a.me == true end
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return out
end

function Pass:Changed()
    if self.sendTimer then return end
    self.sendTimer = true
    local function Go() self.sendTimer = nil self:Send() end
    if C_Timer and C_Timer.After then C_Timer.After(5, Go) else Go() end
    if dungeons.Share and dungeons.Share.onChange then pcall(dungeons.Share.onChange) end
end

-- Dungeon erkannt? (gleiche Zuordnung wie fuer die Eingaenge: Instanzname -> Katalog)
function Pass:CheckInstance()
    local inside, kind = Call(IsInInstance)
    if not inside or kind ~= "party" then return false end
    local E = dungeons.Entrances
    local name = Call(GetInstanceInfo)
    local cands = E and E.Match and E.Match(name) or {}
    local d = cands[1]
    if not d then return false end
    local size = Call(GetNumGroupMembers) or 0
    return self:Visit(d.key, size)
end

-- An die vorhandene Gildennachricht anhaengen (ohne Share.lua zu aendern):
-- Fortschritt senden schickt auch den Pass, eingehende PS-Nachrichten landen hier
local S = dungeons.Share
if S then
    local receive, progress = S.Receive, S.SendProgress
    S.Receive = function(self, prefix, msg, channel, sender)
        if prefix == self.prefix and type(msg) == "string" and msg:sub(1, 3) == "PS|" and type(sender) == "string"
            and not (S.Same and S.Same(sender, Me())) then
            Pass:Receive(msg, sender)
            return
        end
        return receive(self, prefix, msg, channel, sender)
    end
    S.SendProgress = function(self, ...)
        local ok = progress(self, ...)
        if ok then Pass:Send() end
        return ok
    end
end

if type(CreateFrame) == "function" then
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
    local wait = 0
    f:SetScript("OnEvent", function() if ONE.db then Pass:CheckInstance() end end)
    -- Ausfluege: alle 30 s pruefen, ob einer begonnen hat
    f:SetScript("OnUpdate", function(_, elapsed)
        wait = wait + (elapsed or 0)
        if wait < 30 then return end
        wait = 0
        if ONE.db then Pass:StampTrips() end
    end)
    Pass.frame = f
end
