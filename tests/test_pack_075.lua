-- Offline-Test: Startpaket (eigene Funde) wird eingemischt, eigene Funde haben Vorrang.
local root = arg[1] or "src"
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
GetTime = function() return 1 end
UnitName = function() return "Hordi" end
UnitFactionGroup = function() return "Horde" end
UnitLevel = function() return 3 end
local ONE = {db = {nav = {merchants = {c1 = {name = "Eigener", mapID = 1, x = .1, y = .1, faction = "Horde", cats = {food = true}}}}}}
function ONE:Print() end
_G.ProjectONE = ONE
local nav = {Pack = {
    merchants = {c1 = {name = "Paket", mapID = 9, x = .9, y = .9, faction = "Horde", cats = {vial = true}},
                 c2 = {name = "Jeena", mapID = 1454, x = .45, y = .65, faction = "Horde", cats = {vial = true}}},
    givers = {c3 = {name = "Gornek", mapID = 1411, x = .42, y = .68, faction = "Horde", quests = {[4641] = {title = "Bereit", level = 1}}}},
}}
C_QuestLog = {IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end}
for _, f in ipairs({"QuestGivers", "Merchants"}) do assert(loadfile(root .. "/ONE_Nav/" .. f .. ".lua"))("ONE_Nav", nav) end
local vials = nav.Merchants:List("vial")
assert(#vials == 1 and vials[1].name == "Jeena", "Paket-Haendler da")
assert(#nav.Merchants:List("food") == 1 and #nav.Merchants:List("all") == 2, "eigener Fund nicht ueberschrieben")
assert(nav.Merchants:Store().c2.pack == true and nav.Merchants:Store().c2.cats ~= nav.Pack.merchants.c2.cats, "Kopie, nicht das Paket selbst")
local av = nav.QuestGivers:Available()
assert(#av == 1 and av[1].name == "Gornek", "Paket-Questgeber da")

-- Dungeon-Eingaenge: eigener Fund > Paket > Startwert
local d = {EntrancePack = {wc = {1413, .47, .37}, sfk = {1421, .5, .6}}}
assert(loadfile(root .. "/ONE_Dungeons/Catalog.lua"))("ONE_Dungeons", d)
d.Model = {Store = function() ONE.db.dungeons = ONE.db.dungeons or {} return ONE.db.dungeons end}
assert(loadfile(root .. "/ONE_Dungeons/Entrances.lua"))("ONE_Dungeons", d)
local E = d.Entrances
assert(E:Get("wc").source == "pack" and E:Get("wc").x == .47)
assert(E:Get("rfc").source == "seed")
E:Set("wc", 1413, .46, .36, "self")
assert(E:Get("wc").source == "self")
assert(E:Set("sfk", 1421, .1, .1, "guild") and E:Get("sfk").source == "guild", "Gilde schlaegt Paket")
print("OK test_pack_075")
