-- Begleitzeile am Navi-Pfeil (Companion.lua) + Glas-Pfeil: Gilde in der Naehe (nur gleicher Kontinent, bis 500 m,
-- hoechstens 3 Namen), naechster Ausflug in 7 Tagen, abschaltbar, leer = Zeile weg.
local root = arg[1] or "src"
_G.ProjectONE = {features = {}, ns = {}, modules = {}}
local ONE = _G.ProjectONE
local nav = {}
local player = {1, 1000, 1000}
nav.Travel = {
    PlayerWorld = function() return player[1], player[2], player[3] end,
    World = function(mapID, x, y) return mapID == 99 and 2 or 1, x * 10000, y * 10000 end,
    Distance = function(ax, ay, bx, by) local dx, dy = bx - ax, by - ay return math.sqrt(dx * dx + dy * dy) end,
    FormatDistance = function(y) return math.floor(y + .5) .. " m" end,
}
assert(loadfile(root .. "/ONE_Nav/Companion.lua"))("ONE_Nav", nav)
local C = nav.Companion
local peers = {}
ONE.modules.guild = {LivePeers = function() return peers end}

assert(C.Text() == nil, "nichts zu sagen: keine Zeile")
peers = {
    {name = "Mira-Forever", mapID = 1, x = .1, y = .112},   -- 120 m
    {name = "Tom", mapID = 1, x = .1, y = .134},            -- 340 m
    {name = "Weit", mapID = 1, x = .2, y = .2},             -- zu weit
    {name = "Anderswo", mapID = 99, x = .1, y = .1},        -- anderer Kontinent
}
assert(C.Text() == "Gilde in der Nähe: Mira 120 m, Tom 340 m", tostring(C.Text()))
for i = 1, 4 do peers[#peers + 1] = {name = "N" .. i, mapID = 1, x = .1, y = .1 + i / 10000} end
assert(C.Text():find("N1 1 m, N2 2 m, N3 3 m, +3", 1, true), C.Text())

-- naechster Ausflug
peers = {}
local now = 1764000000
date = os.date
local trips = {{start = now + 3600, title = "Todesminen"}, {start = now + 86400 * 2, title = "Später"}, {start = now + 86400 * 9, title = "Zu weit"}}
ONE.ns.dungeons = {Trips = {keep = 4 * 3600, Now = function() return now end, List = function() return trips end,
    Name = function(_, t) return t.title end}}
assert(C.Text() == "Ausflug: heute " .. os.date("%H:%M", now + 3600) .. " · Todesminen", C.Text())
trips = {{start = now - 600, title = "Kloster"}}
assert(C.Text() == "Ausflug: läuft · Kloster")
trips = {{start = now + 86400 * 9, title = "Zu weit"}}
assert(C.Text() == nil)

-- abschaltbar
peers = {{name = "Mira", mapID = 1, x = .1, y = .112}}
ONE.FeatureOn = function(_, id) return id ~= "nav.arrowCompanion" end
assert(C.Text() == nil)
ONE.FeatureOn = nil

-- Zeile am Pfeil: gedrosselt, leer = versteckt
local fs = {}
function fs:SetText(t) self.text = t end
function fs:SetShown(v) self.shown = v end
C.at = nil
C:Update(fs, 10)
assert(fs.text:find("Mira") and fs.shown)
peers = {}
C:Update(fs, 11)
assert(fs.text:find("Mira"), "gedrosselt (alle 3 s)")
C:Update(fs, 14)
assert(fs.text == "" and fs.shown == false)

-- Einbindung + Glas-Pfeil
local function src(p) return assert(io.open(root .. p)):read("*a") end
local arrow = src("/ONE_Nav/Arrow.lua")
assert(arrow:find("nav.Companion:Update(self.companion, Clock())", 1, true))
assert(arrow:find('compact = {hide = {hint = true, tip = true, companion = true}}', 1, true), "Kompakt ohne Begleitzeile")
assert(arrow:find("ArrowGlass.tga", 1, true) and io.open(root .. "/ONE_Nav/Textures/ArrowGlass.tga"), "Glas-Textur")
assert(src("/ONE_Nav/Page.lua"):find('{value = "glass", text = "Glas"}', 1, true))
assert(src("/ONE_Nav/ONE_Nav.toc"):find("Companion.lua", 1, true))
print("OK test_begleiter_176")
