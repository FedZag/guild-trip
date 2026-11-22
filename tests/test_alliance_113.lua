-- Offline-Test 0.7.0: Allianz-tauglich – die fraktionsabhaengigen Teile mit einem Allianz-Charakter.
local root = arg[1] or "src"
local faction = "Alliance"
UnitFactionGroup = function() return faction end
GetLocale = function() return "deDE" end
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local ONE = {db = {}, modules = {}}
function ONE:Print() end
_G.ProjectONE = ONE
for _, f in ipairs({"ONE_QuestDB/Data", "ONE_QuestDB/Services", "ONE_QuestDB/Names_deDE"}) do assert(loadfile(root .. "/" .. f .. ".lua"))() end

-- 1) Lehrer aus der Datenbank: Allianz bekommt Sturmwind/Eisenschmiede/Darnassus, keine Horde-Lehrer
local crafting = {}
assert(loadfile(root .. "/ONE_Crafting/Trainers.lua"))("ONE_Crafting", crafting)
local Tr = crafting.Trainers
local ally, horde = Tr.FromQuestDB("Alliance"), Tr.FromQuestDB("Horde")
local cities = {}
for _, e in ipairs(ally) do cities[e.map] = true assert(e.map ~= 1454 and e.map ~= 1456 and e.map ~= 1458, "kein Horde-Lehrer") end
assert(#ally > 50 and cities[1453] and cities[1455] and cities[1457], "Allianz-Hauptstaedte")
for _, e in ipairs(horde) do assert(e.map ~= 1453 and e.map ~= 1455 and e.map ~= 1457, "kein Allianz-Lehrer fuer die Horde") end

-- 2) Haendler aus der Datenbank
local nav = {}
ONE.T = nil
assert(loadfile(root .. "/ONE_Nav/Merchants.lua"))("ONE_Nav", nav)
local n = 0
for _, m in pairs(nav.Merchants.FromQuestDB("Alliance")) do n = n + 1 assert(m.mapID ~= 1454, "kein Orgrimmar-Haendler") end
assert(n > 100, "Allianz-Haendler " .. n)

-- 3) Reiseetappen: Schiff statt Zeppelin
assert(loadfile(root .. "/ONE_Nav/Travel.lua"))("ONE_Nav", nav)
local Travel = nav.Travel
Travel.World = function(mapID, x, y)
    local kal = {[1439] = true, [1445] = true, [1413] = true, [1411] = true}
    return kal[mapID] and 1 or 0, x * 1000 + mapID, y * 1000
end
local leg = Travel.Departure({continent = 1, x = 1439 + 300, y = 400}, {continent = 0})
assert(leg and leg.name:find("^Schiff ab Auberdine"), leg and leg.name)
faction = "Horde"
leg = Travel.Departure({continent = 1, x = 1411 + 500, y = 130}, {continent = 0})
assert(leg and leg.name:find("^Zeppelin ab Orgrimmar"), leg and leg.name)
-- 3b) Abfahrt nach Gesamtweg (22.11.2026): Brachland -> Unterstadt nicht per Schiff nach Beutebucht
Travel.World = function(mapID, x, y)
    local P = {[1411] = {1, 1500, -4400}, [1413] = {1, -900, -3700}, [1420] = {0, 2050, 300}, [1434] = {0, -12400, 200}}
    local p = P[mapID] or {0, 0, 0}
    return p[1], p[2], p[3]
end
for _, d in ipairs(Travel.departures) do d.world, d.arriveWorld = nil, nil end
-- Spieler im Brachland naeher an Ratschet als an Orgrimmar, Ziel Unterstadt
leg = Travel.Departure({continent = 1, x = -700, y = -3500}, {continent = 0, x = 1800, y = 200})
assert(leg and leg.name == "Zeppelin ab Orgrimmar nach Unterstadt", leg and leg.name)
-- Ziel Schlingendorntal (Beutebucht nah): dann das Schiff
leg = Travel.Departure({continent = 1, x = -700, y = -3500}, {continent = 0, x = -12000, y = 300})
assert(leg and leg.name == "Schiff ab Ratchet nach Beutebucht", leg and leg.name)
faction = "Alliance"

-- 4) Gildenausflug: Treffpunkt Hauptstadt = Sturmwind
local dungeons = {}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end, SendAddonMessage = function() return true end}
C_Timer = {After = function(_, fn) fn() end, NewTicker = function() return {} end}
for _, f in ipairs({"QuestData", "Catalog", "Model", "Share", "Trips"}) do assert(loadfile(root .. "/ONE_Dungeons/" .. f .. ".lua"))("ONE_Dungeons", dungeons) end
local meet = dungeons.Trips:MeetFor("capital")
assert(meet.mapID == 1453, "Sturmwind")
-- Das Verlies ist Allianz-Dungeon
local stocks
for _, d in ipairs(dungeons.Catalog or {}) do if d.key == "stocks" then stocks = d end end
assert(not stocks or stocks.faction == "Alliance")

-- 5) Volksfaehigkeiten: Allianz-Voelker bekommen ihren Platz (Zwerg: Steingestalt, Notfall-Leiste)
local classes = {}
assert(loadfile(root .. "/ONE_Classes/Data.lua"))("ONE_Classes", classes)
local slots = classes.Data.raceSlots
local function Has(list, id) for _, v in ipairs(list) do if v == id then return true end end end
assert(Has(slots[2][1], 20594) and Has(slots[2][1], 20589) and Has(slots[2][1], 59752), "Zwerg, Gnom, Mensch")
assert(Has(slots[3][1], 20580) and Has(slots[3][1], 20600), "Nachtelf, Mensch")
-- erkannt ueber den Namen: ein Zwerg mit "Steingestalt" im Zauberbuch
local spells = {[20594] = "Steingestalt"}
C_Spell = {GetSpellInfo = function(id) return spells[id] and {name = spells[id], iconID = 1} end}
UnitClass = function() return "Krieger", "WARRIOR" end
UnitLevel = function() return 20 end
Enum = {SpellBookSpellBank = {Player = 0}}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = 1} end,
    GetSpellBookItemInfo = function() return {spellID = 1299999, name = "Steingestalt", iconID = 1} end, -- neue Forever-Nummer
}
assert(loadfile(root .. "/ONE_Classes/Player.lua"))("ONE_Classes", classes)
classes.Player.maxAge = 0
local p = classes.Player:Read()
local s = p:Spell(slots[2][1])
assert(s.known and s.name == "Steingestalt" and s.id == 1299999, "Steingestalt erkannt (Forever-Nummer)")

-- 6) Quest-Fuehrung: Fraktionsmaske
local lev = {}
for _, f in ipairs({"ONE_Leveling/Rewards"}) do assert(loadfile(root .. "/" .. f .. ".lua"))() end
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(lev.Planner.FACTION_MASK.Alliance == 1 + 4 + 8 + 64)
print("OK test_alliance_113")
