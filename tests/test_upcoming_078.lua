-- Offline-Test: Klassenlehrer – kommende Zauber merken und "Stufe X: ..." anzeigen.
local root = arg[1] or "src"
UnitName = function() return "Hordi" end
local ONE = {db = {}}
function ONE:Print() end
_G.ProjectONE = ONE
local c = {Player = {SpellInfo = function(id) return "S" .. id end, Path = function() return nil end}}
c.Data = {AllBars = function() return {} end, Ids = function(id) return {id} end}
assert(loadfile(root .. "/ONE_Classes/Trainer.lua"))("ONE_Classes", c)
local Tr = c.Trainer
local p = {classFile = "PRIEST", level = 17}
local services = {
    {name = "Erneuerung", rank = "Rang 3", kind = "unavailable", level = 18},
    {name = "Gedankenschlag", rank = "Rang 2", kind = "unavailable", level = 20},
    {name = "Heilung", rank = "Rang 1", kind = "unavailable", level = 18},
    {name = "Schild", rank = "Rang 2", kind = "available", level = 12},
    {name = "Alt", rank = "Rang 1", kind = "unavailable", level = 10},
}
Tr:Remember(services, p, {Heilung = {tier = 1, pos = 2}})
local now, lvl, list, all = Tr:Upcoming(p)
assert(#now == 0 and lvl == 18 and #list == 2 and list[1].name == "Heilung", "eingeplant zuerst")
assert(#all == 3, "nur kuenftige, nicht verfuegbare")
assert(Tr.Names(list, 2) == "Heilung (Rang 1), Erneuerung (Rang 3)", Tr.Names(list, 2))
assert(Tr.Names(all, 1) == "Heilung (Rang 1), +2")
-- Stufe 18 erreicht: jetzt lernbar, naechste Stufe 20
p.level = 18
now, lvl, list = Tr:Upcoming(p)
assert(#now == 2 and lvl == 20 and list[1].name == "Gedankenschlag")
-- andere Klasse (Twink gleichen Namens?) -> nichts
assert(Tr:Upcoming({classFile = "MAGE", level = 18}) == nil)
-- Klassenweit: anderer Priester ohne eigenen Besuch nutzt die gemerkte Liste (ohne "jetzt")
UnitName = function() return "Twink" end
now, lvl, list = Tr:Upcoming({classFile = "PRIEST", level = 15})
assert(#now == 0 and lvl == 18 and #list >= 2, "Twink sieht Stufe 18 aus der Klassenliste")
-- Startpaket: Klasse ohne eigenen Besuch
c.TrainerSpellPack = {WARRIOR = {["Hinrichten|Rang 1"] = 24, ["Spott|"] = 10}}
now, lvl, list = Tr:Upcoming({classFile = "WARRIOR", level = 20})
assert(lvl == 24 and list[1].name == "Hinrichten" and list[1].rank == "Rang 1", "aus dem Startpaket")
assert(Tr:Upcoming({classFile = "WARRIOR", level = 30}) == nil, "nichts mehr offen")
print("OK test_upcoming_078")
