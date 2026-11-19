-- Offline-Test: Quest-Symbole – Lage auf Weltkarte/Kontinent und Minimap (auch gedreht).
local root = arg[1] or "src"
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
GetTime = function() return 1 end
Enum = {UIMapType = {Continent = 2, Zone = 3}}
local log = {{questID = 1, title = "Mitte", level = 10}, {questID = 2, title = "Rand", level = 10, isComplete = true}}
C_QuestLog = {GetNumQuestLogEntries = function() return #log end, GetInfo = function(i) return log[i] end,
    GetQuestObjectives = function() return {} end,
    GetQuestsOnMap = function(map) if map == 10 then return {{questID = 1, x = .5, y = .5}, {questID = 2, x = .01, y = .5}} end return {} end}
C_Map = {GetBestMapForUnit = function() return 10 end,
    GetMapInfo = function(id) if id == 10 then return {parentMapID = 1} end if id == 1 then return {parentMapID = 0} end end,
    GetMapRectOnMap = function(id, on) if id == 10 and on == 1 then return .2, .6, .1, .5 end end}
local ONE = {db = {}}
function ONE:IsEnabled() return true end
_G.ProjectONE = ONE
local nav = {}
for _, f in ipairs({"Quests", "QuestShare", "QuestPins"}) do assert(loadfile(root .. "/ONE_Nav/" .. f .. ".lua"))("ONE_Nav", nav) end
local P = nav.QuestPins
local function Near(a, b) return math.abs(a - b) < 1e-6 end

-- 1) Standard an, Randpunkte nicht, Gildenort fuellt Luecke
assert(P:Settings().map == true and P:Settings().minimap == true)
nav.QuestShare.peers.Thrall = {name = "Thrall", seen = 1, quests = {[2] = {done = true, mapID = 10, x = .3, y = .7}}}
local pts = P:Points()
assert(#pts == 2, #pts)
local byId = {}
for _, p in ipairs(pts) do byId[p.q.id] = p end
assert(byId[1].x == .5 and not byId[1].from)
assert(byId[2].from == "Thrall" and byId[2].x == .3, "Randpunkt durch Gildenort ersetzt")

-- 2) Weltkarte: gleiche Karte direkt, Kontinent ueber das Rechteck, fremde Karte gar nicht
local x, y = P.OnMap(10, .5, .5, 10) assert(x == .5 and y == .5)
x, y = P.OnMap(10, .5, .5, 1) assert(Near(x, .4) and Near(y, .3), x .. " " .. y)
assert(P.OnMap(10, .5, .5, 99) == nil)

-- 3) Minimap: 100 Yards noerdlich -> oben; 100 Yards westlich -> links; zu weit -> nil
local me = {1, 1000, 2000}
local sx, sy = P.MinimapOffset(me, {1, 1100, 2000}, 400, 140, nil)
assert(Near(sx, 0) and Near(sy, 35), sx .. " " .. sy)
sx, sy = P.MinimapOffset(me, {1, 1000, 2100}, 400, 140, nil)
assert(Near(sx, -35) and Near(sy, 0))
assert(P.MinimapOffset(me, {1, 1300, 2000}, 400, 140, nil) == nil, "ausserhalb")
assert(P.MinimapOffset(me, {2, 1000, 2000}, 400, 140, nil) == nil, "anderer Kontinent")
-- gedrehte Minimap, Blick nach Westen: Ziel im Westen liegt oben
sx, sy = P.MinimapOffset(me, {1, 1000, 2100}, 400, 140, math.pi / 2)
assert(Near(sx, 0) and Near(sy, 35), sx .. " " .. sy)
assert(P.OUTDOOR[1] > P.OUTDOOR[6] and #P.INDOOR == 6)

-- 4) RefreshMinimap wirklich zeichnen (Fehler 15.11.: "world and f()" lieferte nur sx, sy war nil)
local function Obj()
    local o = {points = {}}
    return setmetatable(o, {__index = function(_, k)
        if k == "CreateTexture" then return function() return Obj() end end
        if k == "SetPoint" then return function(self, ...) self.points[#self.points + 1] = {...} end end
        if k == "GetWidth" then return function() return 140 end end
        if k == "GetZoom" or k == "GetFrameLevel" then return function() return 0 end end
        return function() end
    end})
end
CreateFrame = function() return Obj() end
GetCVar = function() return "0" end
_G.Minimap = Obj()
nav.Travel = {PlayerWorld = function() return 1, 1000, 2000 end,
    World = function(map, px, py) if map == 10 then return 1, 1000 + (px - .5) * 200, 2000 + (py - .5) * 200 end end,
    Facing = function() return 0 end}
-- Ziel-Ringe gibt es auf der Minimap nicht mehr (18.11.2026) – nur Questgeber-"!"
P.points = {{mapID = 10, x = .5, y = .3, q = {id = 9, title = "Ziel"}}}
P.worldCache = nil
P:RefreshMinimap()
assert(not P.miniPool[1], "kein Ziel-Ring auf der Minimap")
local function G0(id, y) return {mapID = 10, x = .5, y = y, giver = {name = "G" .. id, quests = {{id = id, title = "Q" .. id}}}} end
P.points = {G0(1, .1), G0(3, .5)}
P.worldCache = nil
P:RefreshMinimap()
assert(P.miniPool[1] and P.miniPool[1].points[1], "Symbol gezeichnet")
assert(type(P.miniPool[1].points[1][4]) == "number" and type(P.miniPool[1].points[1][5]) == "number", "beide Koordinaten")
assert(not P.miniPool[2], "Punkt unter dem Spielerpfeil bleibt frei")

-- 5) 0.7.1: Questgeber auf der Minimap nur aus dem Plan, hoechstens 3, die naechsten zuerst
local function Giver(id, y) return {mapID = 10, x = .5, y = y, giver = {name = "G" .. id, quests = {{id = id, title = "Q" .. id}}}} end
P.points = {Giver(101, .70), Giver(102, .30), Giver(103, .20), Giver(104, .15), Giver(105, .25), {mapID = 10, x = .5, y = .1, q = {id = 1, title = "Ziel"}}}
P.worldCache = nil
local function Shown()
    local n, givers = 0, 0
    for _, pin in ipairs(P.miniPool) do
        if pin.shownState ~= false and pin.point then n = n + 1 if pin.point.giver then givers = givers + 1 end end
    end
    return n, givers
end
for _, pin in ipairs(P.miniPool) do pin.Hide = function(self) self.shownState = false end pin.Show = function(self) self.shownState = true end end
local mt = getmetatable(Obj())
CreateFrame = function()
    local o = Obj()
    o.Hide = function(self) self.shownState = false end
    o.Show = function(self) self.shownState = true end
    return o
end
-- Plan laesst 102, 103, 104, 105 annehmen (101 nicht)
ONE.ns = {leveling = {Guide = {plan = {steps = {{actions = {{kind = "accept", id = 102}, {kind = "accept", id = 103}}},
    {actions = {{kind = "accept", id = 104}, {kind = "accept", id = 105}, {kind = "turnin", id = 101}}}}}}}}
P:RefreshMinimap()
local planned = {}
for _, pin in ipairs(P.miniPool) do
    if pin.shownState and pin.point and pin.point.giver then planned[pin.point.giver.quests[1].id] = true end
end
local count = 0 for _ in pairs(planned) do count = count + 1 end
assert(count == 3, "hoechstens 3 Questgeber, waren " .. count)
assert(not planned[101], "nicht im Plan -> nur Weltkarte")
assert(planned[105] and planned[102] and planned[103] and not planned[104], "die naechsten zuerst")
local goal = false
for _, pin in ipairs(P.miniPool) do if pin.shownState and pin.point and pin.point.q then goal = true end end
assert(not goal, "keine Ziel-Ringe auf der Minimap (18.11.2026)")
-- Schalter "Alle Questgeber": alle 5
ONE.FeatureOn = function(_, id) return id == "nav.giversMinimapAll" end
P:RefreshMinimap()
local all = 0
for _, pin in ipairs(P.miniPool) do if pin.shownState and pin.point and pin.point.giver then all = all + 1 end end
assert(all == 5, "Schalter an: alle Questgeber")
ONE.FeatureOn = nil
print("OK test_questpins_068")
