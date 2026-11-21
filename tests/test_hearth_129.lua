-- Offline-Test: Abkuerzungen der Quest-Fuehrung (Ruhestein benutzen/setzen, Geistheiler bis Stufe 10)
local root = arg[1] or "src"
local ONE = {db = {}}
_G.ProjectONE = ONE
local lev = {}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
UnitFullName = function() return "Hordi", "Realm" end
UnitFactionGroup = function() return "Horde" end
GetLocale = function() return "deDE" end
local now = 100000
GetTime = function() return now end
local px, py = 0, 0
local ghost, level, mounted = false, 13, false
UnitIsGhost = function() return ghost end
UnitLevel = function() return level end
IsMounted = function() return mounted end
local items, cdStart, cdDur = 1, 0, 0
GetItemCount = function(id) return id == 6948 and items or 0 end
GetItemCooldown = function() return cdStart, cdDur end
local bind, sub, zone = "Crossroads", "Crossroads", "Brachland"
GetBindLocation = function() return bind end
GetSubZoneText = function() return sub end
GetZoneText = function() return zone end
-- Welt = Karte * 10000 auf Kontinent 1
local corpse
ONE.ns = {nav = {
    Travel = {DETOUR = 1.3, PlayerWorld = function() return 1, px, py end,
        World = function(mapID, x, y) return 1, x * 10000, y * 10000 end},
    Waypoints = {CorpsePosition = function() if corpse then return 1, corpse[1] / 10000, corpse[2] / 10000 end end},
}}
assert(loadfile(root .. "/ONE_Leveling/Inns.lua"))("ONE_Leveling", lev)
assert(#lev.INNS > 30, "Gastwirte geladen")
-- eigene kleine Gastwirt-Liste fuer den Test
lev.INNS = {
    {1, 1, 0, 0, 2, "Innkeeper Home", "Gastwirt Heim"},
    {2, 1, 5000, 0, 1, "Innkeeper Alliance", "Gastwirt Allianz"},
    {3, 1, 5100, 0, 3, "Innkeeper Goblin", "Gastwirt Goblin"},
}
assert(loadfile(root .. "/ONE_Leveling/Hearth.lua"))("ONE_Leveling", lev)
local H = lev.Hearth

-- 1) Binden beim Gastwirt merkt den Heimatort (je Figur)
H:Bound()
local home = H:Home()
assert(home and home.inn == 1 and home.place == "Crossroads", "Heimatort gemerkt")
assert(ONE.db.leveling.home["Hordi-Realm"] == home)

-- 2) Ruhestein benutzen: Ziel nahe Heimatort, Spieler weit weg
local function Plan(...) local steps = {} for _, s in ipairs({...}) do steps[#steps + 1] = {mapID = 1, x = s[1], y = s[2]} end return {steps = steps} end
px, py = 6000, 0
local plan = Plan({.01, 0})
local lines = H:Lines(plan)
assert(lines[1] and lines[1]:find("Ruhestein nach Crossroads benutzen") and lines[1]:find("spart"), tostring(lines[1]))
-- nah am Ziel: kein Ruhestein
px, py = 200, 0
assert(#H:Lines(plan) == 0, "nah: nichts")
-- Abklingzeit: "bereit in"
px, py = 6000, 0
cdStart, cdDur = now - 3000, 3600
lines = H:Lines(plan)
assert(lines[1] and lines[1]:find("in 10 min bereit"), tostring(lines[1]))
cdStart, cdDur = now - 600, 3600
assert(#H:Lines(plan) == 0, "zu lange Abklingzeit: lohnt nicht")
cdStart, cdDur = 0, 0
items = 0
assert(#H:Lines(plan) == 0, "kein Ruhestein im Gepaeck")
items = 1

-- 3) Ruhestein neu setzen: am Gastwirt vorbei, naechste Quests dort in der Naehe
px, py = 5120, 0
local far = Plan({.52, 0}, {.53, .01}, {.51, .02}, {.52, .03})
lines = H:Lines(far)
local found
for _, l in ipairs(lines) do if l:find("Ruhestein hier setzen %(Gastwirt Goblin%)") then found = true end end
assert(found, "Hinweis zum Neu-Setzen beim nutzbaren Gastwirt (nicht Allianz): " .. table.concat(lines, " | "))
-- Quests nahe am alten Heimatort: kein Hinweis
local nearHome = Plan({.01, 0}, {.02, 0}, {.01, .01})
px, py = 5120, 0
for _, l in ipairs(H:Lines(nearHome)) do assert(not l:find("hier setzen"), l) end
-- nicht in der Naehe eines Gastwirts: kein Hinweis
px, py = 3000, 0
for _, l in ipairs(H:Lines(far)) do assert(not l:find("hier setzen"), l) end

-- 4) Geistheiler: Stufe 13 nie, bis Stufe 10 wenn schneller
ghost = true
corpse = {9000, 0}
px, py = 100, 0
local healerPlan = Plan({.02, 0})
assert(#H:Lines(healerPlan) == 0, "Stufe 13: keine Empfehlung (Krankheit)")
level = 8
lines = H:Lines(healerPlan)
assert(lines[1] and lines[1]:find("Geistheiler"), tostring(lines[1]))
-- Leiche nah am Ziel: lieber zur Leiche
corpse = {300, 0}
assert(#H:Lines(healerPlan) == 0, "Leiche liegt auf dem Weg: kein Geistheiler")
ghost = false

-- 5) Heimatort lernen ohne Binden: am Gastwirt stehen, Bindeort = dieses Gebiet
ONE.db.leveling.home = {}
px, py = 5100, 50
bind, sub = "Ratchet", "Ratchet"
H:Learn()
assert(H:Home() and H:Home().inn == 3, "gelernt beim Gastwirt Goblin")
ONE.db.leveling.home = {}
bind = "Orgrimmar"
H:Learn()
assert(H:Home() == nil, "anderer Bindeort: nichts raten")
print("OK test_hearth_129")
