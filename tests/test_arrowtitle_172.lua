-- Offline-Test: Ueberschrift am Navi-Pfeil (Nutzer 24.11.2026: "'zu' braucht da nicht stehen, wenn es um quests
-- geht, bei staedten 'nach' und bei spielern 'zu'"). Feste Ziele werden nicht am Bindestrich gekuerzt.
local root = arg[1] or "src"
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
GetLocale = function() return "deDE" end
local ONE = {modules = {}, ns = {}, db = {}}
_G.ProjectONE = ONE
local nav = {}
assert(loadfile(root .. "/ONE_Nav/Arrow.lua"))("ONE_Nav", nav)
local TitleOf = assert(nav.Arrow.TitleOf, "Arrow.TitleOf")
assert(TitleOf({name = "Von Hass zerfressen"}) == "Von Hass zerfressen", "Quest ohne Zusatz")
assert(TitleOf({name = "Splintertree-Posten", prefix = "Nach %s"}) == "Nach Splintertree-Posten", "Ort mit 'Nach', ungekuerzt")
assert(TitleOf({name = "Gastwirt Grosk", prefix = "Zu %s"}) == "Zu Gastwirt Grosk", "Person mit 'Zu'")
assert(TitleOf(nil, "Testheld-Realm") == "Zu Testheld", "Spieler mit 'Zu', ohne Realm")
local function Read(p) local f = assert(io.open(root .. p)) local s = f:read("*a") f:close() return s end
assert(not Read("/ONE_Nav/Arrow.lua"):find('"Zu " %.%.'), "kein festes 'Zu ' mehr vor jedem Ziel")
assert(Read("/ONE_Nav/Page.lua"):find('prefix = "Nach %%s"'), "Flugpunkte mit 'Nach'")
assert(Read("/ONE_Nav/Locale_enUS.lua"):find('EN%["Nach %%s"%]'), "englische Uebersetzung")
print("OK test_arrowtitle_172")
