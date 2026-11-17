-- Offline-Test fuer ONE_Nav 0.3.8b (Stufe 1: Pfeil + Reisehinweis). Run: lua tests/test_nav_038b.lua src
local root = arg[1] or "src"
local printed = {}
local frames = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) printed[#printed + 1] = m end}
local Mock = {}
Mock.__index = Mock
local function New(kind, parent)
    local f = setmetatable({kind = kind, parent = parent, scripts = {}, shown = true, events = {}}, Mock)
    frames[#frames + 1] = f
    return f
end
function Mock:SetSize(w, h) self.w, self.h = w, h end
function Mock:SetPoint(...) self.point = {...} end
function Mock:ClearAllPoints() self.point = nil end
function Mock:SetAllPoints() end
function Mock:SetFrameStrata() end
function Mock:SetClampedToScreen() end
function Mock:EnableMouse() end
function Mock:SetMovable() end
function Mock:RegisterForDrag() end
function Mock:StartMoving() self.moving = true end
function Mock:StopMovingOrSizing() self.moving = false end
function Mock:SetScript(e, fn) self.scripts[e] = fn end
function Mock:RegisterEvent(e) self.events[e] = true end
function Mock:Show() self.shown = true end
function Mock:Hide() self.shown = false end
function Mock:IsShown() return self.shown end
function Mock:SetTexture(t) self.texture, self.atlas = t, nil end
function Mock:SetAtlas(a) self.atlas, self.texture = a, nil end
function Mock:SetRotation(r) self.rotation = r end
function Mock:SetText(t) self.text = t end
function Mock:GetText() return self.text end
function Mock:SetWidth() end
function Mock:SetJustifyH() end
function Mock:SetShadowOffset() end
function Mock:GetCenter() return self.cx or 500, self.cy or 400 end
function Mock:GetEffectiveScale() return 1 end
function Mock:CreateTexture() return New("Texture", self) end
function Mock:CreateFontString() return New("FontString", self) end
CreateFrame = function(kind, _, parent) return New(kind, parent) end
UIParent = New("Frame")
UIParent.cx, UIParent.cy = 500, 400
local now = 1000
GetTime = function() return now end
C_Timer = {After = function(_, fn) fn() end}
UnitFullName = function() return "Testheld", "Testrealm" end
InCombatLockdown = function() return false end
issecretvalue = function() return false end
CreateVector2D = function(x, y) return {x = x, y = y} end

-- Welt: Karte 1411 = Kontinent 1, 1000 x 1000 yd, links oben bei (X=1000 Nord, Y=1000 West)
-- Karte 1420 = Kontinent 0. Taxikarte 1464 = gleiche Projektion wie 1411.
local function project(mapID, p)
    if mapID == 1411 or mapID == 1464 then return 1, {x = 1000 - p.y * 1000, y = 1000 - p.x * 1000} end
    if mapID == 1420 then return 0, {x = 500 - p.y * 1000, y = 500 - p.x * 1000} end
    error("unknown map " .. tostring(mapID))
end
local playerMap, playerX, playerY = 1411, .5, .5
local facing = 0
C_Map = {
    GetWorldPosFromMapPos = function(m, p) return project(m, p) end,
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function() return {x = playerX, y = playerY} end,
}
GetPlayerFacing = function() return facing end

local ONE = {db = {}, modules = {}, slashCommands = {}}
function ONE:Print(m) DEFAULT_CHAT_FRAME:AddMessage(m) end
function ONE:IsEnabled(id) return self.db.modules == nil or self.db.modules[id] ~= false end
function ONE:RegisterSlash(name, fn) self.slashCommands[name] = fn return true end
function ONE:RegisterModule(id, def) self.modules[id] = def def.Initialize(def) end
_G.ProjectONE = ONE

-- Gilden-Schnittstelle simulieren (wie ONE_Guild Init.lua)
local peers = {}
ONE.modules.guild = {
    GetPeer = function(_, name)
        for k, p in pairs(peers) do
            if k:lower() == name:lower() or k:lower():match("^[^-]+") == name:lower() then
                return {name = p.name, mapID = p.mapID, x = p.x, y = p.y, seen = p.seen}
            end
        end
    end,
    DescribePeer = function(_, p) return {region = "Durotar", place = p.place} end,
}

local nav = {}
local toc = assert(io.open(root .. "/ONE_Nav/ONE_Nav.toc")):read("*a")
assert(toc:find("## OptionalDeps: ONE_Guild", 1, true))
for name in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile(root .. "/ONE_Nav/" .. name))("ONE_Nav", nav) end
local T = nav.Travel
assert(T and nav.Flights and nav.Arrow and ONE.slashCommands.navi)
local f = io.open(root .. "/ONE_Nav/Textures/Arrow.tga", "rb")
assert(f, "Pfeiltextur fehlt") f:close()

local function near(a, b) return math.abs(a - b) < 1e-6 end
-- 1) Winkel: Welt-X = Nord, Welt-Y = West, Facing 0 = Nord, gegen Uhrzeigersinn
assert(near(T.ArrowAngle(0, 0, 10, 0, 0), 0), "Ziel im Norden, Blick Nord")
assert(near(T.ArrowAngle(0, 0, 0, 10, 0), math.pi / 2), "Ziel im Westen -> Pfeil nach links")
assert(near(T.ArrowAngle(0, 0, 10, 0, math.pi / 2), -math.pi / 2), "Blick West, Ziel Nord -> rechts")
assert(near(math.abs(T.ArrowAngle(0, 0, -10, 0, 0)), math.pi), "Ziel hinter mir")
assert(near(T.ArrowAngle(0, 0, 10, 0, 2 * math.pi - .1), .1), "Winkel normalisiert")
assert(T.FormatDistance(145.4) == "145 m" and T.FormatDistance(12345) == "12.3k m")

-- 2) Weltkoordinaten
local c, x, y = T.World(1411, .5, .25)
assert(c == 1 and x == 750 and y == 500)
assert(T.World(nil, .5, .5) == nil)

-- 3) Reisehinweise
local nodes = {
    [23] = {name = "Orgrimmar, Durotar", continent = 1, x = 0, y = 0},
    [25] = {name = "Crossroads, Brachland", continent = 1, x = -5000, y = 2000},
    [80] = {name = "Ratchet, Brachland", continent = 1, x = -6000, y = 0},
    [22] = {name = "Thunder Bluff, Mulgore", continent = 1, x = -5000, y = 6000},
}
local known = {[23] = true, [25] = true, [80] = true}
local A = T.Advice
assert(A(nil, {continent = 1, x = 0, y = 0}).kind == "noself")
assert(A({continent = 1, x = 0, y = 0}, nil).kind == "notarget")
local r = A({continent = 1, x = 0, y = 0}, {continent = 0, x = 0, y = 0}, nodes, known)
assert(r.kind == "continent" and r.tip:find("Orgrimmar", 1, true), "Kalimdor -> EK braucht Zeppelin/Schiff")
r = A({continent = 0, x = 0, y = 0}, {continent = 1, x = 0, y = 0}, nodes, known)
assert(r.kind == "continent" and r.tip:find("Unterstadt", 1, true))
-- Allianz bekommt Schiffe statt Horde-Zeppeline
local oldFaction = UnitFactionGroup
UnitFactionGroup = function() return "Alliance" end
r = A({continent = 1, x = 0, y = 0}, {continent = 0, x = 0, y = 0}, nodes, known)
assert(r.tip:find("Auberdine", 1, true) and not r.tip:find("Orgrimmar", 1, true), "Allianz-Reisetipp: " .. tostring(r.tip))
UnitFactionGroup = oldFaction
r = A({continent = 9, x = 0, y = 0}, {continent = 1, x = 0, y = 0}, nodes, known)
assert(r.kind == "continent" and r.tip:find("unbekannt", 1, true))
assert(A({continent = 1, x = 0, y = 0}, {continent = 1, x = 5, y = 5}, nodes, known).kind == "arrived")
assert(A({continent = 1, x = 0, y = 0}, {continent = 1, x = 800, y = 0}, nodes, known).kind == "near")
r = A({continent = 1, x = 10, y = 10}, {continent = 1, x = -5050, y = 2050}, nodes, {})
assert(r.kind == "far" and r.tip:find("Flugkarte", 1, true), "ohne bekannte Flugpunkte: Hinweis auf Flugmeister")
r = A({continent = 1, x = 10, y = 10}, {continent = 1, x = -5050, y = 2050}, nodes, known)
assert(r.kind == "flight" and r.text == "Flugpunkt: Orgrimmar › Crossroads", r.text)
r = A({continent = 1, x = 10, y = 10}, {continent = 1, x = -5000, y = 5900}, nodes, known)
assert(r.tip and r.tip:find("Thunder Bluff", 1, true) and r.tip:find("nicht entdeckt", 1, true),
    "naeherer, unbekannter Flugpunkt als Tipp")
-- Unbekannte Flugpunkte werden nie als Flugstrecke vorgeschlagen
assert(not (r.text or ""):find("Thunder Bluff", 1, true))

-- 4) Flugpunkte merken (Umrechnung vertrauenswuerdig: "hier" liegt an der eigenen Position)
GetTaxiMapID = function() return 1464 end
local taxiList = {
    {nodeID = 23, name = "Orgrimmar, Durotar", state = 0, position = {x = .5, y = .5}},
    {nodeID = 25, name = "Crossroads, Brachland", state = 1, position = {x = .2, y = .9}},
    {nodeID = 22, name = "Thunder Bluff, Mulgore", state = 2, position = {x = .1, y = .9}},
    {nodeID = 3208, name = "zzOLDPowderfuse Port, Riverglades", state = 2, position = {x = .5, y = .5}},
}
C_TaxiMap = {GetAllTaxiNodes = function() return taxiList end}
assert(nav.Flights:Capture() == 2)
local kn, nd = nav.Flights:Known(), nav.Flights:Nodes()
assert(kn[23] and kn[25] and not kn[22], "nur Status 0/1 gelten als bekannt")
assert(nd[25] and nd[25].continent == 1 and near(nd[25].x, 100) and near(nd[25].y, 800))
assert(nd[22], "unbekannte Flugpunkte werden als Ort gemerkt (fuer Tipps)")
assert(nd[3208] == nil and not kn[3208], "zzOLD-Knoten gefiltert")
assert(ONE.db.nav.chars["Testheld-Testrealm"].known[23])
assert(nav.Flights:Capture() == 0, "erneutes Oeffnen lernt nichts doppelt")
-- Nicht vertrauenswuerdig: Spieler steht weit weg vom "hier"-Knoten -> nur eigener Punkt
ONE.db.nav = nil
playerX, playerY = .9, .9
nav.Flights:Capture()
nd = nav.Flights:Nodes()
assert(nd[23] and near(nd[23].x, 100) and near(nd[23].y, 100), "aktueller Knoten = eigene Position")
assert(nd[25] == nil, "ungepruefte Umrechnung darf nicht gespeichert werden")
assert(nav.Flights:Known()[25], "bekannt ist er trotzdem")
playerX, playerY = .5, .5
nav.Flights:Capture()

-- 5) Pfeil starten, drehen, Entfernung, Hinweis
assert(not ONE.modules.nav:StartTo("niemand"), "ohne Live-Position kein Start")
peers["Beta-Realm"] = {name = "Beta-Realm", mapID = 1411, x = .5, y = .3, seen = now}
ONE.slashCommands.navi("beta")
local arrow = nav.Arrow
assert(arrow.active and arrow.frame.shown)
assert(arrow.title.text == "Zu Beta · Durotar", tostring(arrow.title.text))
assert(arrow.distance.text == "200 m", arrow.distance.text)
assert(arrow.hint.text:find("zu Fuß", 1, true))
assert(arrow.tip.text:find("keine Wegführung", 1, true), "Ehrlichkeitszeile fehlt")
assert(arrow.arrow.shown and near(arrow.arrow.rotation, 0), "Ziel im Norden, Blick Nord -> Pfeil nach oben")
facing = math.pi / 2
arrow.frame.scripts.OnUpdate(arrow.frame, .05)
assert(near(arrow.arrow.rotation, -math.pi / 2), "Blick nach Westen -> Pfeil nach rechts")
facing = 0
-- Ziel bewegt sich: Aktualisierung nach 1 s
peers["Beta-Realm"].x, peers["Beta-Realm"].y = .3, .5
arrow.frame.scripts.OnUpdate(arrow.frame, 1)
assert(near(arrow.arrow.rotation, math.pi / 2), "Ziel jetzt im Westen")
-- Ziel auf anderem Kontinent: seit 0.6.4 Etappe 1 zum Zeppelin/Schiff (Pfeil zeigt dorthin)
peers["Beta-Realm"].mapID = 1420
arrow.frame.scripts.OnUpdate(arrow.frame, 1)
assert(arrow.hint.text:find("Etappe 1", 1, true) or arrow.hint.text:find("Abflugort", 1, true)
    or arrow.hint.text:find("Anderer Kontinent", 1, true), arrow.hint.text)
assert(arrow.tip.text:find("Drüben", 1, true) or arrow.tip.text:find("Zeppelin", 1, true), arrow.tip.text)
peers["Beta-Realm"].mapID = 1411
-- Eigene Position fehlt (Instanz)
local savedBest = C_Map.GetBestMapForUnit
C_Map.GetBestMapForUnit = function() return nil end
arrow.frame.scripts.OnUpdate(arrow.frame, 1)
assert(not arrow.arrow.shown and arrow.hint.text:find("nicht verfügbar", 1, true))
C_Map.GetBestMapForUnit = savedBest
-- Blickrichtung nicht lesbar -> kein falscher Pfeil
GetPlayerFacing = function() return nil end
arrow.frame.scripts.OnUpdate(arrow.frame, 1)
assert(not arrow.arrow.shown)
GetPlayerFacing = function() return facing end

-- 6) Veraltete und verlorene Position (nur RAM, max. 5 Minuten)
now = now + 30
arrow.frame.scripts.OnUpdate(arrow.frame, 1)
assert(arrow.tip.text:find("Position vor 30 s", 1, true), arrow.tip.text)
peers["Beta-Realm"] = nil
now = now + 60
arrow.frame.scripts.OnUpdate(arrow.frame, 1)
assert(arrow.active and arrow.tip.text:find("zuletzt gesehen", 1, true))
assert(ONE.db.nav.lastPeer == nil and ONE.db.nav.history == nil, "keine Positionshistorie speichern")
now = now + 300
arrow.frame.scripts.OnUpdate(arrow.frame, 1)
assert(not arrow.active and not arrow.frame.shown, "nach 5 Minuten ohne Position beenden")

-- 7) Verschieben, festsetzen, zuruecksetzen
peers["Beta-Realm"] = {name = "Beta-Realm", mapID = 1411, x = .5, y = .3, seen = now}
assert(ONE.modules.nav:StartTo("Beta-Realm"))
local fr = arrow.frame
assert(fr.point[1] == "CENTER" and fr.point[4] == 0 and fr.point[5] == 150, "Standard: ueber der Spielfigur")
fr.scripts.OnDragStart(fr)
assert(fr.moving)
fr.cx, fr.cy = 700, 250
fr.scripts.OnDragStop(fr)
assert(ONE.db.nav.arrow.x == 200 and ONE.db.nav.arrow.y == -150 and fr.point[4] == 200)
fr.scripts.OnMouseUp(fr, "RightButton")
assert(ONE.db.nav.arrow.locked == true)
fr.moving = false
fr.scripts.OnDragStart(fr)
assert(not fr.moving, "festgesetzter Pfeil darf nicht wandern")
ONE.slashCommands.navi("fest")
assert(ONE.db.nav.arrow.locked == false)
ONE.slashCommands.navi("mitte")
assert(ONE.db.nav.arrow.x == 0 and ONE.db.nav.arrow.y == 150)
ONE.slashCommands.navi("aus")
assert(not arrow.active and not fr.shown)

-- 8) Probe ohne zweiten Spieler: Zonenmitte, auch ohne ONE_Guild-Peer
playerX, playerY = .5, .8
ONE.slashCommands.navi("probe")
assert(arrow.active and arrow.title.text == "Zu Testpunkt (Zonenmitte)", tostring(arrow.title.text))
assert(arrow.distance.text == "300 m" and near(arrow.arrow.rotation, 0))
now = now + 400
arrow.frame.scripts.OnUpdate(arrow.frame, 1)
assert(arrow.active, "Probe laeuft ohne Zeitlimit, bis man sie beendet")
ONE.slashCommands.navi("aus")
assert(not arrow.active and arrow.probe == nil)
playerX, playerY = .5, .5

-- 9) Aussehen: kleiner goldener ONE-Pfeil, optional Blizzard-Pfeil
assert(arrow.arrow.texture:find("ONE_Nav", 1, true) and arrow.arrow.w == 44, "Standard: eigener Pfeil, 44 px")
ONE.slashCommands.navi("stil")
assert(arrow.styleInUse == "one", "ohne Blizzard-Atlas bleibt der ONE-Pfeil")
C_Texture = {GetAtlasInfo = function(name) return name == "Navigation-Tracked-Arrow" and {} or nil end}
ONE.slashCommands.navi("stil")
assert(arrow.styleInUse == "blizzard" and arrow.arrow.atlas == "Navigation-Tracked-Arrow")
assert(ONE.db.nav.arrow.style == "blizzard", "Stil wird gespeichert")
ONE.slashCommands.navi("stil")
assert(arrow.styleInUse == "one" and arrow.arrow.texture)
GameTooltip = {lines = {}}
function GameTooltip:SetOwner() self.lines = {} end
function GameTooltip:SetText(t) self.title = t end
function GameTooltip:AddLine(t) self.lines[#self.lines + 1] = t end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false end
arrow.frame.scripts.OnEnter(arrow.frame)
assert(GameTooltip.shown and table.concat(GameTooltip.lines, " "):find("keine Wegführung", 1, true))
arrow.frame.scripts.OnLeave(arrow.frame)
assert(not GameTooltip.shown)

-- 10) Pausiertes Modul startet nichts
ONE.db.modules = {nav = false}
assert(not ONE.modules.nav:StartTo("Beta-Realm") and not arrow.active)
ONE.db.modules = nil

-- 0.4.9c: optionaler ONE-Spielerpfeil (Minimap + Weltkarte)
local mmTex, wmTex
Minimap = {SetPlayerTexture = function(_, t) mmTex = t end}
local pin = {UnitPositionFrame = {SetPlayerPinTexture = function(_, t) wmTex = t end}}
WorldMapFrame = {EnumeratePinsByTemplate = function(_, tpl)
    assert(tpl == "GroupMembersPinTemplate")
    local done = false
    return function() if done then return nil end done = true return pin end
end, HookScript = function() end}
local PA = nav.PlayerArrow
assert(PA and not PA:Enabled(), "Standard: WoW-Pfeil")
PA:SetEnabled(true)
-- seit 0.6.2 nur Minimap; die Weltkarte (auch Karten-Addons) bleibt unberuehrt
assert(mmTex:find("ONE_Nav", 1, true) and wmTex == nil, "Weltkarte unveraendert")
PA:SetEnabled(false)
assert(mmTex == "Interface\\Minimap\\MinimapArrow", "zurueck zu Blizzard")
WorldMapFrame = nil
PA:SetEnabled(true) -- ohne Weltkarten-Schnittstelle kein Absturz
assert(PA.minimapOk)
PA:SetEnabled(false)
print("OK: 0.3.8b - Navi-Pfeil, Winkel, Reisehinweise, Flugpunkte, veraltete Positionen, Verschieben")
