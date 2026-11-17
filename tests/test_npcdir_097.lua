-- Offline-Test: NPC-Verzeichnis aus der Questdatenbank (ONE_QuestDB/Services.lua) – Lehrer und Händler.
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local faction = "Horde"
UnitFactionGroup = function() return faction end
_G.ProjectONE = {db = {}, T = nil, RegisterFeature = function() end}
for _, f in ipairs({"Data", "Services", "Names_deDE", "Names_enUS"}) do assert(loadfile(root .. "/ONE_QuestDB/" .. f .. ".lua"))() end
local D = GuildTripQuestDB
assert(next(D.trainers) and next(D.vendors) and D.svcNames, "Verzeichnis geladen")

-- Lehrer: Grezz Ragefist (Kriegerlehrer, Orgrimmar) mit genauer Position
local crafting = {}
assert(loadfile(root .. "/ONE_Crafting/Trainers.lua"))("ONE_Crafting", crafting)
local Tr = crafting.Trainers
local horde = Tr.FromQuestDB("Horde")
local grezz, kinds = nil, {}
for _, e in ipairs(horde) do
    kinds[e.kind] = (kinds[e.kind] or 0) + 1
    if e.npc == "Grezz Ragefist" then grezz = e end
end
assert(grezz and grezz.kind == "class" and grezz.what == "Krieger" and grezz.map == 1454 and grezz.db, "Grezz im Verzeichnis")
assert(kinds.class > 50 and kinds.profession > 50 and (kinds.weapon or 0) > 3, "alle Arten vertreten")
-- Allianz sieht keine Horde-Lehrer
for _, e in ipairs(Tr.FromQuestDB("Alliance")) do assert(e.npc ~= "Grezz Ragefist", "Fraktion getrennt") end
-- Alle(): Verzeichnis ersetzt die ungefähre Grundliste
Tr.Store = function() return {} end
local all = Tr:All()
local found = false
for _, e in ipairs(all) do if e.npc == "Grezz Ragefist" then found = e.db end end
assert(found, "Verzeichnis in der Lehrerliste")
assert(#all > 150, "viele Lehrer statt Grundliste: " .. #all)

-- Händler: Kategorien aus dem Angebot, Reparieren aus der NPC-Funktion
local nav = {}
assert(loadfile(root .. "/ONE_Nav/Merchants.lua"))("ONE_Nav", nav)
local M = nav.Merchants
local list = M.FromQuestDB("Horde")
local count, repair, ammo = 0, 0, 0
for _, m in pairs(list) do
    count = count + 1
    if m.cats.repair then repair = repair + 1 end
    if m.cats.ammo then ammo = ammo + 1 end
    assert(m.x >= 0 and m.x <= 1 and m.y >= 0 and m.y <= 1 and m.mapID)
end
assert(count > 200 and repair > 30 and ammo > 10, ("Händler %d, Reparieren %d, Munition %d"):format(count, repair, ammo))
M.Store = function() return {} end
local filtered = M:List("repair")
assert(#filtered == repair, "Filter Reparieren")
-- Dungeon-Eingänge aus der Questdatenbank (EntranceData.lua)
local dungeons = {}
assert(loadfile(root .. "/ONE_Dungeons/EntranceData.lua"))("ONE_Dungeons", dungeons)
local n = 0
for key, e in pairs(dungeons.EntranceData) do
    n = n + 1
    assert(e[1] >= 1411 and e[2] > 0 and e[2] < 1 and e[3] > 0 and e[3] < 1, key)
end
assert(n >= 18 and dungeons.EntranceData.stocks[1] == 1453 and dungeons.EntranceData.stratud, "Eingänge vollständig")
print("OK test_npcdir_097")
