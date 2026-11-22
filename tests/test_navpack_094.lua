-- Offline-Test Navi-Paket: Ankunft + Farbwechsel, Abstecher mit Rueckweg, Leichenlauf, Wegpunkte, Polestar.
local root = arg[1] or "src"
local function Region(kind)
    local r = {kind = kind, shown = true, scripts = {}, text = ""}
    setmetatable(r, {__index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end})
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:HookScript(e, fn) self.scripts[e] = fn end
    function r:SetText(t) self.text = t end
    function r:SetVertexColor(a, b, c) self.color = {a, b, c} end
    function r:CreateTexture() return Region("Texture") end
    function r:CreateFontString() return Region("FontString") end
    return r
end
CreateFrame = function(kind) return Region(kind) end
UIParent = Region("Frame")
local now = 100
GetTime = function() return now end
local printed = {}
local ONE = {db = {}, slashes = {}, modules = {}}
_G.ProjectONE = ONE
function ONE:Print(m) printed[#printed + 1] = m end
function ONE:IsEnabled() return true end
function ONE:RegisterSlash(n, fn) self.slashes[n] = fn return true end
local played = 0
ONE.Sound = {Play = function() played = played + 1 end, PlayAlert = function(_, key) played = played + 1 ONE.lastAlert = key end}
-- Spieler steht in Weltkoordinaten (px, py); Karte = Welt 1:1 (Kontinent 1)
local px, py = 0, 0
local nav = {}
nav.Travel = {
    PlayerWorld = function() return 1, px, py end,
    World = function(mapID, x, y) return 1, x * 1000, y * 1000 end,
    Distance = function(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end,
    FormatDistance = function(d) return tostring(math.floor(d)) end,
    Facing = function() return 0 end, ArrowAngle = function() return 0 end,
    PlayerMapPosition = function() return 1411, px / 1000, py / 1000 end,
}
function nav.Travel.Advice(p, t)
    local d = nav.Travel.Distance(p.x, p.y, t.x, t.y)
    if d <= 15 then return {kind = "arrived", text = "Ihr seid am Ziel!", distance = d} end
    return {kind = "near", text = "", distance = d}
end
nav.Flights = {Nodes = function() return {} end, Known = function() return {} end}
assert(loadfile(root .. "/ONE_Nav/Arrow.lua"))("ONE_Nav", nav)
assert(loadfile(root .. "/ONE_Nav/Waypoints.lua"))("ONE_Nav", nav)
local A, W = nav.Arrow, nav.Waypoints

-- 1) Farbe: weit weg weiss, kurz vor dem Ziel gruen
local r, g, b = A.NearColor(500) assert(r == 1 and g == 1 and b == 1)
r, g, b = A.NearColor(10) assert(r < .5 and g == 1, "fast gruen")

-- 2) Questziel bei (500, 0); Haendler-Abstecher bei (100, 0) -> nach dem Einkauf zurueck
A:StartPoint("Quest", 1, .5, 0)
assert(A.active and A.probe.name == "Quest")
A:StartPoint("Händler", 1, .1, 0, {service = true})
assert(A.resume and A.resume.name == "Quest", "altes Ziel gemerkt")
A:Refresh()
assert(A.tip.text:find("Danach weiter zu Quest"), A.tip.text)
px = 100 A:Refresh()
assert(A.arrivedAt and played == 1 and printed[#printed]:find("Angekommen"), "Ankunft gemeldet")
assert(ONE.lastAlert == "arriveService", "Haendler: neutraler Ankunftsklang")
px = 110 A:Refresh()
assert(A.probe.name == "Händler", "beim Haendler noch nicht zurueck")
px = 140 A:Refresh()
assert(A.probe.name == "Quest" and not A.resume, "nach dem Weggehen zurueck zur Quest")

-- 3) Festes Ziel ohne Rueckweg: nach Ankunft eine Weile stehen, dann aus
px = 500 A:Refresh()
assert(A.active and A.arrivedAt)
now = now + 20 A:Refresh()
assert(not A.active, "nach der Ankunft beendet")

-- 4) Leichenlauf: Tod bei (300,0) waehrend Navi zur Quest, als Geist Pfeil zur Leiche, wiederbelebt -> Quest
ONE.FeatureOn = function() return true end
UnitIsGhost = function() return true end
A:StartPoint("Quest", 1, .9, 0)
px = 300 W:OnDeath()
px = 0 W:OnGhost()
assert(A.probe.corpse and A.probe.name == "Deine Leiche" and A.resume.name == "Quest")
px = 300 A:Refresh()
assert(A.active and A.probe.corpse, "an der Leiche bleibt der Pfeil, bis man lebt")
W:OnAlive()
assert(A.probe.name == "Quest", "nach dem Wiederbeleben weiter zur Quest")

-- 4b) Geist-Zustand kommt verspaetet (Spieltest 19.11.2026): CheckGhost holt den Leichenpfeil nach, nur einmal
A:Stop() W:OnAlive()
UnitIsGhost = function() return false end
A:StartPoint("Quest", 1, .9, 0)
px = 300 W:OnDeath()
px = 0 W:CheckGhost()
assert(A.probe.name == "Quest", "noch nicht Geist: nichts tun")
UnitIsGhost = function() return true end
W:CheckGhost()
assert(A.probe.corpse, "Geist erkannt: Pfeil zur Leiche")
W:CheckGhost()
assert(A.resume and A.resume.name == "Quest", "nicht doppelt starten, Rückweg zur Quest bleibt")
A:Stop()
W:CheckGhost()
assert(not A.active, "vom Spieler geschlossen: nicht wieder aufdrängen")
W:OnAlive()
UnitIsGhost = function() return false end

-- 5) Polestar laeuft: kein automatischer Leichenpfeil
C_AddOns = {IsAddOnLoaded = function(n) return n == "Polestar" end}
assert(W.OtherNavAddon() == "Polestar" and not W.AutoAllowed())
A:Stop()
W:OnDeath() W:OnGhost()
assert(not A.active, "mit Polestar kein Auto-Start")
C_AddOns = nil

-- 6) Wegpunkt-Text lesen
local x, y, zone = W.Parse("45.2 60.1")
assert(math.abs(x - .452) < 1e-6 and math.abs(y - .601) < 1e-6 and zone == nil)
x, y, zone = W.Parse("Brachland 45,2 60,1")
assert(math.abs(x - .452) < 1e-6 and zone == "Brachland")
x, y, zone = W.Parse("45.2, 60.1 Brachland")
assert(zone == "Brachland")
assert(W.Parse("hallo") == nil and W.Parse("120 5") == nil)
assert(W:Way("33 44") and A.probe.mapID == 1411 and math.abs(A.probe.x - .33) < 1e-6)
-- 7) Klick auf ?/… in der Zielverfolgung: Navi zur Quest, doppelte Meldung innerhalb 1 s ignoriert
local navied = 0
nav.Quests = {Log = function() return {{id = 42, title = "Brennende Schatten"}} end, Navi = function(_, q) navied = navied + 1 return q.id == 42 end}
assert(W:TrackerNavi(42) and navied == 1)
assert(not W:TrackerNavi(42) and navied == 1, "kein Doppelstart")
now = now + 5
assert(W:TrackerNavi(42) and navied == 2)
assert(not W:TrackerNavi(0) and not W:TrackerNavi(99))
-- 8) Wegenetz 2 (19.11.2026): auch mit installiertem Shortest Path Forever fuehrt Guild Trip selbst
local calls = {}
ShortestPathForever = {API = {version = 2,
    Navigate = function() calls[#calls + 1] = "nav" return true end,
    Cancel = function() calls[#calls + 1] = "cancel" return true end,
    Ended = function() end}}
px, py = 0, 0
A:StartPoint("Quest", 1, .5, 0)
assert(not A.delegated and #calls == 0, "keine Weitergabe an SPF")
A:Stop()
assert(#calls == 0)
ShortestPathForever = nil
print("OK test_navpack_094")
