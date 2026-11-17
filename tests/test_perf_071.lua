-- Offline-Test: teure Abfragen nur bei Bedarf (Zwischenspeicher Player, Nachladen je Gegenstand einmal).
local root = arg[1] or "src"
local clock = 10
GetTime = function() return clock end
local handler
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function(_, _, fn) handler = fn end} end
UnitClass = function() return "Druide", "DRUID" end
UnitLevel = function() return 17 end
local ONE = {db = {}}
function ONE:Print() end
_G.ProjectONE = ONE
local c = {}
for _, f in ipairs({"Data.lua", "Player.lua"}) do assert(loadfile(root .. "/ONE_Classes/" .. f))("ONE_Classes", c) end
local P = c.Player
local reads = 0
P.KnownSpells = function() reads = reads + 1 return {} end
P.Talents = function() return {} end
P.FreePoints = function() return 0 end
P:Read() P:Read() P:Read()
assert(reads == 1, "Zauberbuch nur einmal lesen: " .. reads)
assert(handler, "Ereignisse leeren den Speicher")
handler() P:Read()
assert(reads == 2, "nach Ereignis neu lesen")
clock = clock + 31 P:Read()
assert(reads == 3, "spaetestens nach 30 s neu lesen")

-- Berufe: Gegenstandsdaten je Gegenstand nur einmal anfordern
local requested = 0
C_Item = {GetItemNameByID = function() return nil end, RequestLoadItemDataByID = function() requested = requested + 1 end}
local cr = {}
assert(loadfile(root .. "/ONE_Crafting/Recipes.lua"))("ONE_Crafting", cr)
for _ = 1, 5 do cr.Recipes:ItemName(4711) end
cr.Recipes:ItemName(4712)
assert(requested == 2, "Nachladen je Gegenstand einmal: " .. requested)
print("OK test_perf_071")
