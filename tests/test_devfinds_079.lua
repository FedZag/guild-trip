-- Offline-Test: "Zauberdaten teilen" schickt Funde fuers Startpaket mit – ohne Spielernamen.
local root = arg[1] or "src"
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local ONE = {db = {
    nav = {merchants = {c1 = {name = "Jeena", mapID = 1454, x = .1, y = .2, cats = {vial = true}, items = {vial = {"Phiole"}}, seen = 5}},
           givers = {c2 = {name = "Gornek", mapID = 1411, x = .4, y = .6, quests = {[1] = {title = "Q", level = 1}}, seen = 3}}},
    crafting = {trainers = {Lumak = {npc = "Lumak", kind = "profession", what = "Angeln", map = 1454, x = .7, y = .3, by = "Hordi-Realm", seen = 9}}},
    dungeons = {entrances = {wc = {mapID = 1413, x = .46, y = .36, source = "self"}, rfc = {mapID = 1454, x = .5, y = .5, source = "seed"}}},
    classGuide = {classSpells = {PRIEST = {["Heilung|Rang 1"] = 18}}},
}}
_G.ProjectONE = ONE
local c = {Player = {Path = function() return nil end, SpellInfo = function() return nil end}}
assert(loadfile(root .. "/ONE_Classes/Share.lua"))("ONE_Classes", c)
local f = c.Share:CollectFinds("PRIEST")
assert(f.nav.merchants.c1.cats.vial and f.nav.merchants.c1.items == nil, "Haendler ohne Gegenstandsnamen")
assert(f.crafting.trainers.Lumak and f.crafting.trainers.Lumak.by == nil, "Lehrer ohne Finder-Namen")
assert(f.dungeons.entrances.wc and f.dungeons.entrances.rfc == nil, "nur echte Eingaenge, keine Startwerte")
assert(f.classGuide.classSpells.PRIEST["Heilung|Rang 1"] == 18)
local text = c.Share.Serialize(f)
assert(not text:find("Hordi", 1, true), "kein Spielername im Versand")
assert(c.Share.Deserialize(text).nav.givers.c2.quests[1].title == "Q", "Rundlauf")
print("OK test_devfinds_079")
