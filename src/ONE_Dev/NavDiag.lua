-- Project ONE Navigation, Stufe 0: Diagnose.
-- Prueft nur, welche Daten der Forever-Client liefert. Keine Navigation,
-- keine Uebertragung, keine Daten anderer Spieler. Ergebnisse landen lokal in
-- ProjectONEDB.navDiag (nur eigener Charakter) und koennen geloescht werden.
local _, ns = ...
local ONE = _G.ProjectONE
-- Liegt in ONE_Dev (nur fuer die Entwicklung) und haengt sich an den
-- Namensraum des Moduls (ONE.ns.nav). Ohne das Modul passiert nichts.
local nav = (ONE.ns and ONE.ns.nav) or ns
if not nav then return end
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end
local Diag = {maxRuns = 40, maxTaxi = 10, maxRide = 60}
nav.Diag = Diag

-- Kartennummern, deren Lage auf den Kontinenten wir pruefen wollen.
Diag.probeMaps = {
    {id = 1411, label = "Durotar"},
    {id = 1413, label = "Brachland"},
    {id = 1454, label = "Orgrimmar"},
    {id = 1414, label = "Kalimdor"},
    {id = 1420, label = "Tirisfal"},
    {id = 1458, label = "Unterstadt"},
    {id = 1434, label = "Schlingendorn"},
    {id = 1415, label = "Oestliche Koenigreiche"},
}

local function IsSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret == true
end

-- Wandelt einen beliebigen Rueckgabewert in einen speicherbaren Wert um,
-- ohne geheime Werte anzufassen (Vergleich/Rechnen waere dort ein Fehler).
function Diag.Plain(v)
    if IsSecret(v) then return "GEHEIM" end
    local t = type(v)
    if v == nil then return "nil" end
    if t == "number" then
        if v ~= v then return "NaN" end
        if v == math.floor(v) then return v end
        return math.floor(v * 10000 + 0.5) / 10000
    end
    if t == "string" then return #v > 80 and v:sub(1, 80) or v end
    if t == "boolean" then return v end
    return "<" .. t .. ">"
end

local function Pack(...) return {n = select("#", ...), ...} end

-- Ruft eine API geschuetzt auf. Ergebnis: status OK/FEHLT/FEHLER + Werte.
function Diag.Try(fn, ...)
    if type(fn) ~= "function" then return {status = "FEHLT", n = 0} end
    local r = Pack(pcall(fn, ...))
    if not r[1] then return {status = "FEHLER", err = Diag.Plain(tostring(r[2])), n = 0} end
    local out = {status = "OK", n = r.n - 1}
    for i = 2, r.n do out[i - 1] = Diag.Plain(r[i]) end
    return out
end

local function Field(tbl, key)
    if type(tbl) ~= "table" or IsSecret(tbl) then return nil end
    local ok, v = pcall(function() return tbl[key] end)
    if ok then return v end
end

-- Liest x/y aus Vector2D oder einfacher Tabelle (Forever liefert beides).
local function XY(vec)
    if vec == nil then return "nil", "nil" end
    if IsSecret(vec) then return "GEHEIM", "GEHEIM" end
    local x, y = Field(vec, "x"), Field(vec, "y")
    if x == nil and type(Field(vec, "GetXY")) == "function" then
        local ok, a, b = pcall(vec.GetXY, vec)
        if ok then x, y = a, b end
    end
    return Diag.Plain(x), Diag.Plain(y)
end

local function Vector(x, y)
    if type(CreateVector2D) == "function" then
        local ok, v = pcall(CreateVector2D, x, y)
        if ok and v then return v end
    end
    return {x = x, y = y}
end

local function Has(path)
    local cur = _G
    for part in path:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return false end
        cur = cur[part]
    end
    return type(cur) == "function"
end

local function Verdict(value)
    if value == "GEHEIM" then return "GEHEIM" end
    if value == "nil" or value == nil then return "LEER" end
    return "OK"
end

function Diag:Database()
    if not DevDB() then return end
    local db = DevDB()
    db.navDiag = type(db.navDiag) == "table" and db.navDiag or {}
    local d = db.navDiag
    d.runs = type(d.runs) == "table" and d.runs or {}
    d.taxi = type(d.taxi) == "table" and d.taxi or {}
    d.rides = type(d.rides) == "table" and d.rides or {}
    return d
end

local function Push(list, item, limit)
    list[#list + 1] = item
    while #list > limit do table.remove(list, 1) end
end

local function Stamp()
    local t = Diag.Try(GetServerTime)
    return t[1]
end

-- Kurzer Zustand: wo bin ich, was mache ich gerade (nur eigener Charakter).
function Diag:Situation()
    local s = {}
    local inst = self.Try(IsInInstance)
    s.instance, s.instanceType = inst[1], inst[2]
    s.zone = self.Try(GetZoneText)[1]
    s.subZone = self.Try(GetSubZoneText)[1]
    s.combat = self.Try(InCombatLockdown)[1]
    s.swimming = self.Try(IsSwimming)[1]
    s.mounted = self.Try(IsMounted)[1]
    s.flying = self.Try(IsFlying)[1]
    s.onTaxi = self.Try(UnitOnTaxi, "player")[1]
    s.dead = self.Try(UnitIsDeadOrGhost, "player")[1]
    return s
end

-- D1: eigene Position, Karte, Weltkoordinaten, Kontinent.
function Diag:Position()
    local r = {}
    local best = self.Try(C_Map and C_Map.GetBestMapForUnit, "player")
    r.bestStatus, r.map = best.status, best[1]
    local mapID = type(r.map) == "number" and r.map or nil
    if mapID then
        local info = self.Try(C_Map.GetMapInfo, mapID)
        r.mapInfo = info.status
        local okInfo, raw = pcall(C_Map.GetMapInfo, mapID)
        if okInfo and type(raw) == "table" then
            r.mapName = self.Plain(Field(raw, "name"))
            r.mapType = self.Plain(Field(raw, "mapType"))
            r.parent = self.Plain(Field(raw, "parentMapID"))
        end
        local okPos, pos = false, nil
        if C_Map and type(C_Map.GetPlayerMapPosition) == "function" then
            okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
        end
        r.posStatus = okPos and "OK" or "FEHLER"
        r.x, r.y = XY(okPos and pos or nil)
        if okPos and pos and type(r.x) == "number" and type(r.y) == "number"
            and C_Map and type(C_Map.GetWorldPosFromMapPos) == "function" then
            local okW, instanceID, world = pcall(C_Map.GetWorldPosFromMapPos, mapID, pos)
            r.worldStatus = okW and "OK" or "FEHLER"
            if okW then
                r.continent = self.Plain(instanceID)
                r.worldX, r.worldY = XY(world)
            end
        else
            r.worldStatus = "UEBERSPRUNGEN"
        end
    end
    return r
end

function Diag:Facing()
    local f = self.Try(GetPlayerFacing)
    return {status = f.status, value = f[1]}
end

function Diag:UnitPos()
    local u = self.Try(UnitPosition, "player")
    return {status = u.status, y = u[1], x = u[2], z = u[3], instance = u[4]}
end

-- D4: Lage bekannter Karten auf ihren Kontinenten (Mitte der Karte).
function Diag:MapProbe()
    local out = {}
    for _, probe in ipairs(self.probeMaps) do
        local row = {id = probe.id, label = probe.label}
        if C_Map and type(C_Map.GetWorldPosFromMapPos) == "function" then
            local ok, instanceID, world = pcall(C_Map.GetWorldPosFromMapPos, probe.id, Vector(.5, .5))
            row.status = ok and "OK" or "FEHLER"
            if ok then
                row.continent = self.Plain(instanceID)
                row.worldX, row.worldY = XY(world)
            end
        else
            row.status = "FEHLT"
        end
        local size = self.Try(C_Map and C_Map.GetMapWorldSize, probe.id)
        row.width, row.height = size[1], size[2]
        local okInfo, info = false, nil
        if C_Map and type(C_Map.GetMapInfo) == "function" then
            okInfo, info = pcall(C_Map.GetMapInfo, probe.id)
        end
        if okInfo and type(info) == "table" then
            row.name = self.Plain(Field(info, "name"))
            row.mapType = self.Plain(Field(info, "mapType"))
            row.parent = self.Plain(Field(info, "parentMapID"))
        end
        out[#out + 1] = row
    end
    return out
end

function Diag:Speed()
    local s = self.Try(GetUnitSpeed, "player")
    return {status = s.status, current = s[1], run = s[2], flight = s[3], swim = s[4]}
end

-- D8 ohne Seiteneffekt: darf hier ein Blizzard-Wegpunkt gesetzt werden?
function Diag:WaypointAbility(mapID)
    local w = {}
    w.canSet = mapID and self.Try(C_Map and C_Map.CanSetUserWaypointOnMap, mapID)[1] or "nil"
    w.setUserWaypoint = Has("C_Map.SetUserWaypoint")
    w.createPoint = Has("UiMapPoint.CreateFromCoordinates")
    w.superTrack = Has("C_SuperTrack.SetSuperTrackedUserWaypoint")
    w.navDistance = self.Try(C_Navigation and C_Navigation.GetDistance)[1]
    return w
end

function Diag:Apis()
    return {
        loadAddOn = Has("C_AddOns.LoadAddOn"),
        allTaxiNodes = Has("C_TaxiMap.GetAllTaxiNodes"),
        taxiMapID = Has("GetTaxiMapID"),
        numRoutes = Has("GetNumRoutes"),
        taxiNodeGetType = Has("TaxiNodeGetType"),
        unitOnTaxi = Has("UnitOnTaxi"),
        bindLocation = Has("GetBindLocation"),
        addDataProvider = type(_G.WorldMapFrame) == "table"
            and type(_G.WorldMapFrame.AddDataProvider) == "function",
    }
end

function Diag:Build()
    local b = self.Try(GetBuildInfo)
    return {version = b[1], build = b[2], date = b[3], interface = b[4]}
end

function Diag:Collect(note)
    local pos = self:Position()
    local run = {
        time = Stamp(),
        note = note ~= "" and note or nil,
        addon = ONE.version,
        build = self:Build(),
        situation = self:Situation(),
        position = pos,
        facing = self:Facing(),
        unitPosition = self:UnitPos(),
        maps = self:MapProbe(),
        speed = self:Speed(),
        waypoint = self:WaypointAbility(type(pos.map) == "number" and pos.map or nil),
        apis = self:Apis(),
    }
    return run
end

local function Mark(ok) return ok and "|cff66ff66OK|r" or "|cffff6666NEIN|r" end
local function Word(v)
    if v == "OK" then return "|cff66ff66OK|r" end
    if v == "GEHEIM" then return "|cffffcc33GEHEIM|r" end
    return "|cffff6666" .. tostring(v) .. "|r"
end

function Diag:Report(run)
    local p, s = run.position, run.situation
    ONE:Print("Navi-Test gespeichert (" .. tostring(s.zone) .. (s.subZone ~= "" and s.subZone ~= "nil"
        and (" / " .. tostring(s.subZone)) or "") .. ", Instanz: " .. tostring(s.instanceType) .. ")")
    ONE:Print("1 Position: " .. Word(Verdict(p.x)) .. "  Karte " .. tostring(p.map)
        .. "  Kontinent " .. tostring(p.continent) .. "  Welt " .. Word(Verdict(p.worldX)))
    ONE:Print("2 Blickrichtung: " .. Word(Verdict(run.facing.value))
        .. "  3 Hoehe (z): " .. tostring(run.unitPosition.z))
    local okMaps, total = 0, #run.maps
    local continents = {}
    for _, m in ipairs(run.maps) do
        if m.status == "OK" and type(m.worldX) == "number" then okMaps = okMaps + 1 end
        continents[#continents + 1] = m.label:sub(1, 4) .. "=" .. tostring(m.continent)
    end
    ONE:Print("4 Kartenlage: " .. okMaps .. "/" .. total .. " OK  (" .. table.concat(continents, " ") .. ")")
    ONE:Print("5 Tempo: " .. Word(Verdict(run.speed.current)) .. "  6 Wegpunkt erlaubt: "
        .. tostring(run.waypoint.canSet) .. "  Pfeil-API: " .. Mark(run.waypoint.superTrack))
    ONE:Print("Danke! Bitte nach allen Tests einmal /reload eingeben, damit WoW speichert.")
end

function Diag:Run(note)
    local db = self:Database()
    if not db then ONE:Print("Navi-Test: Speicher nicht bereit, bitte /reload.") return end
    local run = self:Collect(note or "")
    Push(db.runs, run, self.maxRuns)
    self:Report(run)
    return run
end

-- Flugkarte: automatisch mitschreiben, sobald man beim Flugmeister die Karte oeffnet.
function Diag:CaptureTaxi()
    local db = self:Database()
    if not db then return end
    local mapRes = self.Try(GetTaxiMapID)
    local mapID = mapRes[1]
    local entry = {time = Stamp(), taxiMap = mapID, situation = self:Situation(),
        position = self:Position(), counts = {}, nodes = {}}
    local okAll, nodes = false, nil
    if type(mapID) == "number" and C_TaxiMap and type(C_TaxiMap.GetAllTaxiNodes) == "function" then
        okAll, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
    end
    entry.status = okAll and type(nodes) == "table" and "OK" or "FEHLER"
    if entry.status == "OK" then
        for i, node in ipairs(nodes) do
            local state = self.Plain(Field(node, "state"))
            local key = tostring(state)
            entry.counts[key] = (entry.counts[key] or 0) + 1
            if i <= 80 then
                local px, py = XY(Field(node, "position"))
                local slot = Field(node, "slotIndex")
                local row = {
                    id = self.Plain(Field(node, "nodeID")),
                    name = self.Plain(Field(node, "name")),
                    state = state, x = px, y = py,
                    slot = self.Plain(slot),
                    layer = self.Plain(Field(node, "isMapLayerTransition")),
                }
                if type(slot) == "number" and not IsSecret(slot) then
                    row.type = self.Try(TaxiNodeGetType, slot)[1]
                    row.routes = self.Try(GetNumRoutes, slot)[1]
                end
                entry.nodes[#entry.nodes + 1] = row
            end
        end
        entry.total = #nodes
    end
    Push(db.taxi, entry, self.maxTaxi)
    local c = entry.counts
    ONE:Print("Navi-Test: Flugkarte gespeichert (" .. tostring(entry.total or 0) .. " Punkte: "
        .. tostring(c["0"] or 0) .. " hier, " .. tostring(c["1"] or 0) .. " erreichbar, "
        .. tostring(c["2"] or 0) .. " nicht verbunden).")
end

-- Fahrt-Test: auf Schiff/Zeppelin 3 Minuten lang alle 3 Sekunden die eigene
-- Position notieren, um Kontinentwechsel und Datenluecken zu sehen.
function Diag:StartRide()
    local db = self:Database()
    if not db then return end
    if self.rideTicker then
        ONE:Print("Fahrt-Test laeuft bereits.")
        return
    end
    if not (C_Timer and type(C_Timer.NewTicker) == "function") then
        ONE:Print("Fahrt-Test nicht moeglich: Zeitgeber fehlt.")
        return
    end
    local ride = {time = Stamp(), samples = {}}
    Push(db.rides, ride, 5)
    local count = 0
    ONE:Print("Fahrt-Test gestartet: 3 Minuten lang wird mitgeschrieben. Einfach weiterfahren.")
    self.rideTicker = C_Timer.NewTicker(3, function()
        count = count + 1
        local p = self:Position()
        local s = self:Situation()
        ride.samples[#ride.samples + 1] = {n = count, map = p.map, x = p.x, y = p.y,
            continent = p.continent, worldX = p.worldX, worldY = p.worldY,
            zone = s.zone, instance = s.instanceType}
        if count >= self.maxRide then
            self.rideTicker:Cancel()
            self.rideTicker = nil
            ONE:Print("Fahrt-Test fertig (" .. count .. " Messpunkte). Bitte spaeter /reload.")
        end
    end, self.maxRide)
end

-- Pfeil-Test: setzt einen Blizzard-Wegpunkt in die Mitte der aktuellen Zone.
function Diag:ArrowTest(off)
    local db = self:Database()
    if not db then return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        ONE:Print("Pfeil-Test bitte nach dem Kampf.")
        return
    end
    if off then
        local own = self.arrowPoint
        local okGet, current = false, nil
        if C_Map and type(C_Map.GetUserWaypoint) == "function" then
            okGet, current = pcall(C_Map.GetUserWaypoint)
        end
        if own and okGet and current then
            local cx, cy = XY(Field(current, "position"))
            local cm = Field(current, "uiMapID")
            if cm == own.map and type(cx) == "number" and type(cy) == "number"
                and math.abs(cx - own.x) < .001 and math.abs(cy - own.y) < .001 then
                pcall(C_Map.ClearUserWaypoint)
                ONE:Print("Test-Wegpunkt entfernt.")
            else
                ONE:Print("Wegpunkt wurde inzwischen geaendert – Guild Trip laesst ihn stehen.")
            end
        else
            ONE:Print("Kein Test-Wegpunkt von Guild Trip aktiv.")
        end
        self.arrowPoint = nil
        return
    end
    local pos = self:Position()
    local result = {time = Stamp(), map = pos.map, situation = self:Situation()}
    if type(pos.map) ~= "number" then
        result.status = "KEINE KARTE"
    else
        result.canSet = self.Try(C_Map and C_Map.CanSetUserWaypointOnMap, pos.map)[1]
        local okPoint, point = false, nil
        if UiMapPoint and type(UiMapPoint.CreateFromCoordinates) == "function" then
            okPoint, point = pcall(UiMapPoint.CreateFromCoordinates, pos.map, .5, .5)
        end
        if okPoint and point then
            result.set = self.Try(C_Map.SetUserWaypoint, point).status
            result.superTrack = self.Try(C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint, true).status
            self.arrowPoint = {map = pos.map, x = .5, y = .5}
        else
            result.set = "KEIN PUNKT"
        end
        result.status = "OK"
    end
    db.arrow = result
    ONE:Print("Pfeil-Test: Wegpunkt " .. tostring(result.set) .. ", Verfolgung "
        .. tostring(result.superTrack) .. ". Siehst du jetzt einen Pfeil/Abstand am Bildschirm?")
    ONE:Print("Danach mit /trip navpfeil aus wieder entfernen.")
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function()
            result.distanceLater = self.Try(C_Navigation and C_Navigation.GetDistance)[1]
            result.trackingLater = self.Try(C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint)[1]
        end)
    end
end

function Diag:Clear()
    if not DevDB() then return end
    DevDB().navDiag = nil
    if self.rideTicker then self.rideTicker:Cancel(); self.rideTicker = nil end
    ONE:Print("Alle Navi-Testdaten geloescht.")
end

function Diag:Summary()
    local db = self:Database()
    if not db then return end
    ONE:Print("Navi-Test: " .. #db.runs .. " Messungen, " .. #db.taxi .. " Flugkarten, "
        .. #db.rides .. " Fahrten gespeichert.")
end

function Diag:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TAXIMAP_OPENED")
    frame:SetScript("OnEvent", function()
        if not ONE:IsEnabled("nav") then return end
        -- Kurz warten: die Knotenliste ist beim ersten Event manchmal leer.
        if C_Timer and C_Timer.After then
            C_Timer.After(.3, function() self:CaptureTaxi() end)
        else
            self:CaptureTaxi()
        end
    end)
    self.frame = frame
end

-- ===== Anmeldung (nur mit ONE_Dev) =====
local function Paused()
    if ONE:IsEnabled("nav") then return false end
    ONE:Print("Das Navi-Modul ist pausiert (/trip modules).")
    return true
end
ONE:RegisterSlash("navdiag", function(rest)
    if Paused() then return end
    if rest == "fahrt" then
        Diag:StartRide()
    elseif rest == "loeschen" or rest == "löschen" then
        Diag:Clear()
    elseif rest == "status" then
        Diag:Summary()
    elseif rest == "mitte" then
        -- Pfeil zur Mitte der aktuellen Zone (frueher Knopf auf der Navi-Seite)
        if nav and nav.Arrow then nav.Arrow:StartProbe() end
    else
        -- Alles andere ist eine freiwillige Notiz, z. B. "/trip navdiag hoehle".
        Diag:Run(rest)
    end
end, "Navi-Test (fahrt | status | mitte | loeschen | <Notiz>)")
ONE:RegisterSlash("navpfeil", function(rest)
    if Paused() then return end
    Diag:ArrowTest(rest == "aus")
end, "Blizzard-Pfeil-Test (aus = entfernen)")
Diag:Initialize()
