-- Orte im Chat (ONE_Nav/ChatLinks.lua): getippte Koordinaten klickbar, Kartenmarkierung mit Tooltip + Navi,
-- Umschalt+Klick auf die Weltkarte beim Tippen setzt Markierung + Link ins Feld; eigene Link-Arten im
-- Kern-Register (LinkTips) – Umschalt+Klick sendet erfundene Links nie.
local root = arg[1] or "src"
_G.ProjectONE = {features = {}, ns = {}}
local ONE = _G.ProjectONE
function ONE:Print(t) self.printed = t end
assert(loadfile(root .. "/ONE_Core/LinkTips.lua"))("ONE_Core", {})
local LT = ONE.LinkTips
local here = 1413
_G.C_Map = {GetMapInfo = function(id) return ({[1413] = {name = "Brachland"}, [1411] = {name = "Durotar"}})[id] end}
local started
local nav = {Travel = {PlayerMapPosition = function() return here end},
    Arrow = {StartPoint = function(_, label, mapID, x, y) started = {label = label, mapID = mapID, x = x, y = y} return true end}}
assert(loadfile(root .. "/ONE_Nav/ChatLinks.lua"))("ONE_Nav", nav)
local CL = nav.ChatLinks

local function coords(text)
    local out = {}
    for a, b in LT.Mark(text):gmatch("|Hgtcoord:(%d+):(%d+)|h") do out[#out + 1] = a .. "/" .. b end
    return table.concat(out, " ")
end
assert(coords("bin bei 45.2, 60.1 komm vorbei") == "452/601")
assert(coords("45,2 60,1") == "452/601", "deutsche Kommazahlen")
assert(coords("45.2 / 60.1") == "452/601")
assert(coords("45.2,60.1") == "452/601")
assert(coords("Treffpunkt (52, 30)") == "520/300")
assert(coords("Stufe 20, 30 Silber") == "", "ganze Zahlen ohne Klammern sind keine Koordinaten")
assert(coords("2 DD 60") == "")
assert(coords("1.5 2.5 und 145.2 60.1") == "15/25", "über 100 nicht, Zahlen nicht zerschnitten")
assert(coords("Version 0.8.9") == "")
-- Text bleibt derselbe, vorhandene Links unberührt
local link = "|cff0070dd|Hitem:5:::|h[Klinge 45.2 60.1]|h|r"
local m = LT.Mark(link .. " bei 45.2 60.1")
assert(m:sub(1, #link) == link and select(2, m:gsub("|Hgtcoord:", "")) == 1)
assert(LT.PlainText(LT.Mark("bei 45.2, 60.1")) == "bei 45.2, 60.1")
-- abschaltbar
ONE.FeatureOn = function(_, id) return id ~= "nav.chatCoords" end
assert(coords("45.2 60.1") == "")
ONE.FeatureOn = nil

-- Tooltip + Klick: Koordinaten im eigenen Gebiet
local tt = {rows = {}}
function tt:SetText(t) self.rows[#self.rows + 1] = t end
function tt:AddLine(t) self.rows[#self.rows + 1] = t end
function tt:Show() self.shown = true end
assert(LT.Tip(tt, "gtcoord:452:601") == true and tt.rows[1]:find("45.2, 60.1") and tt.rows[2]:find("Brachland"))
assert(LT.Open("gtcoord:452:601") and started.mapID == 1413 and math.abs(started.x - .452) < 1e-9 and started.label:find("Brachland"))
here = nil
assert(LT.Open("gtcoord:452:601") == false and ONE.printed:find("nicht verfügbar"))
here = 1413
-- Kartenmarkierung (WoW-Link): Gebiet aus dem Link, nicht das eigene
tt.rows = {}
assert(LT.Tip(tt, "worldmap:1411:4520:6010") and tt.rows[1] == "Kartenmarkierung" and tt.rows[2]:find("Durotar 45.2, 60.1"))
assert(LT.Open("worldmap:1411:4520:6010") and started.mapID == 1411 and math.abs(started.y - .601) < 1e-9)
assert(LT.IsPlain("gtcoord:1:2") and not LT.IsPlain("worldmap:1:2:3"), "Kartenmarkierung ist ein echter Link")
assert(LT.Tip(tt, "item:5") == nil and LT.Open("item:5") == nil, "WoW-Links bleiben bei WoW")

-- Umschalt+Klick auf die Karte: nur beim Tippen im Guild-Trip-Chat
local box = {text = "", focus = true}
function box:HasFocus() return self.focus end
function box:Insert(t) self.text = self.text .. t end
ONE.ns.chat = {UI = {input = box}}
assert(CL.MapClickToChat(1413, .452, .601) and box.text:find("|Hworldmap:1413:4520:6010|h", 1, true), "Link ins Feld (Rückfall ohne Spiel)")
-- mit WoW: Markierung setzen, WoWs eigenen Link nehmen
local pin
_G.UiMapPoint = {CreateFromCoordinates = function(id, x, y) return {id = id, x = x, y = y} end}
C_Map.SetUserWaypoint = function(p) pin = p end
C_Map.GetUserWaypointHyperlink = function() return "|cffffff00|Hworldmap:1413:4520:6010|h[Kartenmarkierung]|h|r" end
box.text = ""
assert(CL.MapClickToChat(1413, .452, .601) and pin.id == 1413 and box.text == C_Map.GetUserWaypointHyperlink())
box.focus = false
assert(not CL.MapClickToChat(1413, .452, .601), "ohne Tippen: Navi wie bisher")

-- Einbindung
local function src(p) return assert(io.open(root .. p)):read("*a") end
assert(src("/ONE_Nav/Waypoints.lua"):find("nav.ChatLinks.MapClickToChat(mapID, x, y)", 1, true))
assert(src("/ONE_Nav/ONE_Nav.toc"):find("ChatLinks.lua", 1, true))
assert(src("/ONE_Chat/Messenger.lua"):find("gtcoord = true, worldmap = true", 1, true), "Tooltip in Fenster/Randleiste")
print("OK test_kartenlinks_174")
