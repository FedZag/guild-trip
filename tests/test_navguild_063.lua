-- Offline-Test 0.6.1: Navi-Ziele (Gilde, Lehrer, Flugmeister) und die
-- Neuigkeiten-Liste der Gilde-Seite ("Was steht an").
local root = arg[1] or "src"
local ONE = {db = {}, modules = {}}
_G.ProjectONE = ONE

-- Navi-Seite ohne Fenster laden; Welt: x/y direkt in Metern, Spieler bei 0,0 auf Kontinent 1
local nav = {}
local started
nav.Travel = {
    World = function(mapID, x, y) if mapID == 99 then return 0, x, y end return 1, x * 1000, y * 1000 end,
    PlayerWorld = function() return 1, 0, 0 end,
    Distance = function(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end,
    FormatDistance = function(d) return math.floor(d) .. " m" end,
}
nav.Arrow = {
    Start = function(_, name) started = {"peer", name} end,
    StartPoint = function(_, label) started = {"point", label} end,
    StartWorld = function(_, label, c, x, y) started = {"world", label, c, x, y} end,
}
nav.Flights = {
    Nodes = function() return {
        [1] = {name = "Orgrimmar, Durotar", continent = 1, x = 300, y = 400},
        [2] = {name = "Crossroads, Brachland", continent = 1, x = 30, y = 40},
        [3] = {name = "Unbekannt, Irgendwo", continent = 1, x = 1, y = 1},
    } end,
    Known = function() return {[1] = true, [2] = true} end,
}
assert(loadfile(root .. "/ONE_Nav/Page.lua"))("ONE_Nav", nav)
local Page = nav.Page

-- Gilde: live teilende Mitglieder, naechste zuerst
ONE.modules.guild = {
    LivePeers = function() return {{name = "Fern-Realm", mapID = 1, x = .9, y = .9}, {name = "Nah-Realm", mapID = 1, x = .01, y = .01},
        {name = "Weg-Realm", mapID = 99, x = 1, y = 1}} end,
    DescribePeer = function() return {region = "Durotar"} end,
}
UnitName = function() return "Ich" end
local base = ONE.modules.guild.LivePeers
ONE.modules.guild.LivePeers = function() local l = base() l[#l + 1] = {name = "Ich-Realm", mapID = 1, x = 0, y = 0} return l end
local g = Page:Targets("guild")
assert(#g == 3 and g[1].name == "Nah" --[[ ohne "Ich" ]] and g[2].name == "Fern" and g[3].name == "Weg", "Gilde nach Entfernung")
assert(g[3].distText == "anderer Kontinent")
g[1].go()
assert(started[1] == "peer" and started[2] == "Nah-Realm")

-- Lehrer: nur der eigene Klassenlehrer (oben), Berufe und Waffen nach Entfernung
UnitClass = function() return "Priester", "PRIEST" end
ONE.modules.crafting = {AllTrainers = function() return {
    {npc = "Bergbau-Lehrer", kind = "profession", what = "Bergbau", map = 1, x = .1, y = .1, area = "Orgrimmar, Tal der Ehre"},
    {npc = "Priester-Lehrer", kind = "class", what = "Priester", map = 1, x = .5, y = .5},
    {npc = "Krieger-Lehrer", kind = "class", what = "Krieger", map = 1, x = .01, y = .01},
    {npc = "Ohne Ort", kind = "weapon", what = "Waffenmeister"},
} end}
local t = Page:Targets("trainers")
assert(#t == 2, "fremde Klassenlehrer und Lehrer ohne Position fehlen: " .. #t)
assert(t[1].name == "Priester-Lehrer" and t[2].name == "Bergbau-Lehrer", "eigener Klassenlehrer zuerst")
t[2].go()
assert(started[1] == "point" and started[2] == "Bergbau-Lehrer")

-- Flugmeister: nur bekannte, naechster zuerst, Pfeil ueber Weltkoordinaten
local f = Page:Targets("flights")
assert(#f == 2 and f[1].name == "Crossroads" and f[1].info == "Brachland", "Flugmeister: " .. tostring(f[1] and f[1].name))
f[1].go()
assert(started[1] == "world" and started[3] == 1 and started[4] == 30)

-- Neuigkeiten-Liste: Eintraege aller Module, sortiert, Fehler eines Moduls stoeren nicht
local UI = {feeds = {}}
local src = assert(io.open(root .. "/ONE_Core/UI.lua")):read("*a")
local feedCode = src:match("(function UI:AddFeed.-\nend\nfunction UI:FeedItems.-\nend)\n")
assert(feedCode, "AddFeed/FeedItems fehlen im Kern")
assert(loadstring("local UI = ...\n" .. feedCode))(UI)
UI:AddFeed("a", function() return {{text = "spaeter", sort = 30}, {text = "zuerst", sort = 5}} end)
UI:AddFeed("kaputt", function() error("absichtlich") end)
UI:AddFeed("b", function() return {{text = "Mitte", sort = 10}, {kein = "text"}} end)
local items = UI:FeedItems()
assert(#items == 3 and items[1].text == "zuerst" and items[2].text == "Mitte" and items[3].text == "spaeter")
print("OK test_navguild_063")
