-- Offline-Test Wegenetz (ONE_Routes + ONE_Nav/Routes.lua): Suche im Netz, Folgen, Abweichen, Pfeil-Anbindung,
-- und das echte gebackene Netz (Sturmwind -> Späherkuppe).
local root = arg[1] or "src"
local function Region(kind)
    local r = {kind = kind, shown = true, scripts = {}, text = ""}
    setmetatable(r, {__index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end})
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:SetText(t) self.text = t end
    function r:SetRotation(a) self.angle = a end
    function r:CreateTexture() return Region("Texture") end
    function r:CreateFontString() return Region("FontString") end
    return r
end
CreateFrame = function(kind) return Region(kind) end
UIParent = Region("Frame")
local now = 100
GetTime = function() return now end
local printed = {}
local ONE = {db = {}, modules = {}}
_G.ProjectONE = ONE
function ONE:Print(m) printed[#printed + 1] = m end

-- 1) Kleines Netz: ein Umweg um einen "Fluss" (Luftlinie 0,0 -> 1000,0 geht nicht, Weg über eine Brücke bei y=400)
GuildTripRoutes = {R = {[1] = {
    nodes = "0 0 0 400 500 400 1000 400 1000 0 500 -300",
    edges = {
        {1, 2, 400, ""},
        {2, 3, 520, "250 20 250 -20"},   -- Zwischenpunkte (250,20) und (500,0) relativ -> (250,420), (500,400)
        {3, 4, 500, ""},
        {4, 5, 400, ""},
        {1, 6, 2000, ""},                -- teurer Umweg (Sumpf)
    },
}}}
local nav = {}
assert(loadfile(root .. "/ONE_Nav/Routes.lua"))("ONE_Nav", nav)
local R = nav.Routes
assert(R:Available())
local net = R:Net(1)
assert(net.count == 6 and #net.adj[1] == 6, "Knoten 1 hat zwei Kanten")
local route = assert(R:Find(1, 60, -40, 990, 5))
-- Weg: Start -> Knoten 1 -> 2 -> (250,420) -> 3 -> 4 -> 5 -> Ziel
local p = route.points
assert(p[2].x == 0 and p[2].y == 0 and p[3].y == 400 and p[4].x == 250 and p[4].y == 420, "Zwischenpunkte entpackt")
assert(p[#p].x == 990 and p[#p].y == 5)
assert(route.length > 1750 and route.length < 1900, route.length)
-- rückwärts: Zwischenpunkte umgedreht
local back = assert(R:Find(1, 990, 5, 60, -40))
local seen
for _, q in ipairs(back.points) do if q.x == 250 and q.y == 420 then seen = true end end
assert(seen, "Rückweg nutzt dieselbe Kante")
-- zu nah: kein Netz nötig; zu weit weg vom Netz: nichts
assert(R:Find(1, 0, 0, 50, 0) == nil)
assert(R:Find(1, 5000, 5000, 0, 0) == nil)
assert(R:Find(7, 0, 0, 1000, 0) == nil, "kein Netz für Kontinent 7")

-- 1b) Einstieg abkürzen: nicht erst zum Knoten hoch und dann zurück, sondern direkt auf den Weg
local cut = R.Shortcut({{x = 50, y = 0}, {x = 100, y = 100}, {x = 0, y = 100}, {x = 0, y = 500}}, 140, 400)
assert(#cut == 3 and cut[2].x == 0 and cut[2].y == 100 and cut[3].y == 500, "direkt auf den Weg")
local far = R.Shortcut({{x = 50, y = 0}, {x = 100, y = 100}, {x = 0, y = 100}, {x = 0, y = 500}}, 50, 400)
assert(#far == 4, "zu weit für eine Abkürzung -> Weg bleibt")

-- 2) Folgen: Punkte werden abgehakt, Restweg sinkt, Abweichen erkannt
local t, rest = R:Next(route, 60, -40)
assert(t.x == 0 and t.y == 0, "erst zum Knoten 1")
local first = rest
t, rest = R:Next(route, 0, 200)
assert(t.y == 400 and rest < first, "auf dem Weg nach Norden")
t = R:Next(route, 2, 395)
assert(t.x == 250 and t.y == 420, "Knoten 2 erreicht -> nächster Punkt")
assert(R:Next(route, 600, -200) == nil, "weit neben dem Weg -> neu planen")

-- 3) Steer: plant, folgt, plant bei bewegtem Ziel neu
local holder = {}
local sp = R:Steer(holder, 1, 10, -5, 990, 5, 1)
assert(sp and holder.route, "Route geplant")
local r1 = holder.route
R:Steer(holder, 1, 0, 100, 990, 5, 2)
assert(holder.route == r1, "gleiche Route beim Folgen")
R:Steer(holder, 1, 0, 100, 500, -280, 3)
assert(holder.route ~= r1, "Ziel woanders -> neue Route")

-- 4) Pfeil: zeigt auf die nächste Abbiegung, Entfernung = Restweg, Text "Folge dem Weg"
local px, py = 60, -40
nav.Travel = {
    PlayerWorld = function() return 1, px, py end,
    World = function(mapID, x, y) return 1, x * 1000, y * 1000 end,
    Distance = function(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end,
    FormatDistance = function(d) return tostring(math.floor(d)) end,
    Facing = function() return 0 end, ArrowAngle = function(_, _, tx, ty) return tx * 1000 + ty end,
    PlayerMapPosition = function() return 1411, px / 1000, py / 1000 end,
}
function nav.Travel.Advice(pl, tg)
    local d = nav.Travel.Distance(pl.x, pl.y, tg.x, tg.y)
    if d <= 15 then return {kind = "arrived", text = "Ihr seid am Ziel!", distance = d} end
    return {kind = "near", text = "", distance = d}
end
nav.Flights = {Nodes = function() return {} end, Known = function() return {} end}
assert(loadfile(root .. "/ONE_Nav/Arrow.lua"))("ONE_Nav", nav)
local A = nav.Arrow
A:StartPoint("Brücke", 1, .99, .005)
assert(printed[#printed]:find("folgt dem Weg"), printed[#printed])
assert(A.state.advice.routed and A.state.target.x == 0 and A.state.target.y == 0, "Pfeil zeigt erst zum Netz")
assert(tonumber(A.distance.text) > 1300, "Restweg statt Luftlinie: " .. A.distance.text)
assert(A.tip.text:find("Folge dem Weg"))
px, py = 0, 300
A:Rotate()
assert(A.state.target.y == 400, "Drehen schaltet zur nächsten Abbiegung")
-- Schalter aus -> Luftlinie
ONE.FeatureOn = function(_, id) return id ~= "nav.routes" end
A:Refresh()
assert(not A.state.advice.routed and A.state.target.x == 990, "ohne Wegenetz: Luftlinie")
ONE.FeatureOn = nil

-- 5) Punkte für Minimap/Weltkarte: gleichmäßig entlang des Wegs, nächste Abbiegung als Ring
assert(loadfile(root .. "/ONE_Nav/RouteDots.lua"))("ONE_Nav", nav)
local RD = nav.RouteDots
px, py = 0, 300
now = now + 5 -- neu planen höchstens alle 3 s
A:Refresh()
assert(RD:Route() == A.route, "Punkte folgen der Pfeil-Route")
local dots = RD.Sample(A.route, 0, 300, 20, 100)
assert(#dots > 20, "Punkte entlang des Wegs: " .. #dots)
assert(dots[1].x == 0 and dots[1].y == 320, "erster Punkt 20 Yards voraus")
local turns = 0
for _, d in ipairs(dots) do if d.turn then turns = turns + 1 end end
assert(turns == 1 and dots[5].turn and dots[5].y == 400, "genau eine Abbiegung markiert")
assert(#RD.Sample(A.route, 0, 300, 20, 7) == 7, "höchstens max Punkte")
local short = RD.Sample(A.route, 0, 300, 20, 100, 150)
assert(#short < #dots, "Reichweite begrenzt")
-- Minimap zeichnet Punkte (Spieler auf Kontinent 1)
Minimap = Region("Frame")
function Minimap:GetWidth() return 140 end
function Minimap:GetZoom() return 0 end
nav.QuestPins = {Diameter = function() return 466 end, clearRadius = 11,
    MinimapOffset = function(p, t, diameter, size) local s = size / diameter return -(t[3] - p[3]) * s, (t[2] - p[2]) * s end}
RD:RefreshMinimap()
assert(#RD.miniPool > 5 and RD.miniPool[1].shown, "Punkte auf der Minimap")
-- 0.6.8: Fussspuren (Einstellung), Standard bleibt "dots"
assert(RD:Style() == "dots", "Standard: goldene Punkte")
ONE.db = ONE.db or {}
RD:SetStyle("feet")
assert(RD:Style() == "feet" and ONE.db.nav.routeStyle == "feet")
RD:RefreshMinimap()
assert(RD.miniPool[1].shown and type(RD.miniPool[1].icon.angle) == "number", "Abdrücke zur Laufrichtung gedreht")
-- Weg nach Norden (y wächst): Zehen zeigen nach oben (Winkel 0); nach Osten -> -90°
assert(math.abs(RD.Angle(0, 5)) < 1e-9 and math.abs(RD.Angle(5, 0) + math.pi / 2) < 1e-9, "Drehwinkel")
-- Aufleuchten: eine Welle vom Spieler zum Ziel, frisch gesetzte Abdrücke hell, sonst ruhig
local bright = 0
for k = 1, 10 do if RD.FootAlpha(k, 10, 1.0) > .5 then bright = bright + 1 end end
assert(bright >= 1 and bright <= RD.trail, "nur ein Teil leuchtet: " .. bright)
assert(RD.FootAlpha(1, 10, 0) == 1, "erster Schritt beginnt hell")
RD:SetStyle("dots")
RD:RefreshMinimap()
assert(RD.miniPool[1].icon.angle == 0, "Punkte wieder ungedreht")
ONE.FeatureOn = function(_, id) return id ~= "nav.routeDots" end
RD:RefreshMinimap()
assert(not RD.miniPool[1].shown, "abschaltbar")
ONE.FeatureOn = nil
A:Stop()
assert(A.route == nil and RD:Route() == nil)
RD:RefreshMinimap()
assert(not RD.miniPool[1].shown, "nach Navi-Ende weg")

-- 6) Echtes Netz: Sturmwind-Flugmeister -> Späherkuppe (SPF misst 2386 Yards Laufweg)
GuildTripRoutes = nil
R.cache = {}
assert(loadfile(root .. "/ONE_Routes/Data.lua"))()
assert(R:Available() and GuildTripRoutes.R[0] and GuildTripRoutes.R[1], "beide Hauptkontinente gebacken")
local real = assert(R:Find(0, -8832.77, 478.62, -10628.89, 1036.68), "Weg Sturmwind -> Westfall")
assert(real.length > 1900 and real.length < 2800, "Länge plausibel: " .. real.length)
-- Orgrimmar-Flugmeister -> Wegekreuz (Brachland) auf Kalimdor
local kal = assert(R:Find(1, 1677.59, -4315.71, -441.8, -2596.08), "Weg Orgrimmar -> Wegekreuz")
assert(kal.length > 2500 and kal.length < 5500, "Länge plausibel: " .. kal.length)
print("OK test_routes_096")
-- Pfeil dreht fliessend: weich zum Zielwinkel, kuerzester Weg ueber +-pi, Start springt sofort
do
    local Sm = A.Smooth
    assert(Sm(nil, 1, .016) == 1 and Sm(0, 1, nil) == 1, "ohne Vorwert sofort")
    local a = Sm(0, 1, .016, 14)
    assert(a > 0 and a < 1, "ein Bild: ein Stueck naeher")
    local b = Sm(3.0, -3.0, .016, 14)
    assert(b > 3.0 or b < -3.0 + 1e-9, "ueber pi, nicht quer zurueck")
    local c = 0
    for _ = 1, 60 do c = Sm(c, 1, .016, 14) end
    assert(math.abs(c - 1) < .01, "nach einer Sekunde angekommen")
end
