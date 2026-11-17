-- Offline-Test: Beute merken (Gegner, Art, Ort) und Fundort-Text.
local root = arg[1] or "src"
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Classes/Loot.lua"))("ONE_Classes", c)
local L = c.Loot
IsInInstance = function() return false end
C_Map = {GetBestMapForUnit = function() return 1413 end, GetPlayerMapPosition = function() return {x = .5, y = .25} end,
    GetMapInfo = function() return {name = "Brachland"} end}
local guid = "Creature-0-1-2-3-3270-0000"
UnitGUID = function() return guid end
UnitName = function() return "Älteste Mystikerin" end
UnitClassification = function() return "elite" end
local loot = {{"|Hitem:15452::|h[Armschienen]|h", 15452, "INVTYPE_WRIST", 2}, {"|Hitem:2589::|h[Leinenstoff]|h", 2589, "", 1},
    {"|Hitem:9999::|h[Grau]|h", 9999, "INVTYPE_CHEST", 0}}
GetNumLootItems = function() return #loot end
GetLootSlotLink = function(i) return loot[i][1] end
GetLootSourceInfo = function() return guid, 1 end
GetItemInfoInstant = function(id) for _, l in ipairs(loot) do if l[2] == id then return id, "", "", l[3] end end end
GetItemInfo = function(link) for _, l in ipairs(loot) do if l[1] == link then return "x", link, l[4], 20, 15 end end end
assert(L:OnLoot() == 1, "nur ausruestbare, gruene Gegenstaende")
local e = ONE.db.classGuide.loot[15452]
assert(e and e.minLevel == 15 and e.slot == "INVTYPE_WRIST")
local s = e.sources.c3270
assert(s.name == "Älteste Mystikerin" and s.kind == "elite" and s.mapID == 1413 and s.count == 1)
L:OnLoot()
assert(e.sources.c3270.count == 2, "zweiter Fund zaehlt mit")
assert(L:SourceText(15452) == "Guild Trip: fällt bei Älteste Mystikerin (Elite) – Brachland", L:SourceText(15452))
-- Kiste (GameObject) ohne Ziel
guid = "GameObject-0-1-2-3-2843-0000"
UnitGUID = function() return nil end
L:OnLoot()
assert(e.sources.o2843 and e.sources.o2843.kind == "object")
-- Startpaket-Fundort
c.LootPack = {[777] = {sources = {c1 = {name = "Rak'shiri", kind = "rare", mapID = 1446, count = 1}}}}
assert(L:SourceText(777):find("Rak'shiri (Rar)", 1, true))
-- abgeschaltet: nichts merken
function ONE:FeatureOn() return false end
assert(L:OnLoot() == 0)
print("OK test_loot_081")
