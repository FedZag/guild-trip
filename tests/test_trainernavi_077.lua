-- Offline-Test: "Was steht an" – Navi zum naechsten Lehrer, der die faellige Stufe lehrt.
local root = arg[1] or "src"
UnitFactionGroup = function() return "Horde" end
UnitName = function() return "Hordi" end
local ONE = {db = {}, modules = {}}
function ONE:Print() end
_G.ProjectONE = ONE
local c = {}
for _, f in ipairs({"Recipes", "Trainers"}) do assert(loadfile(root .. "/ONE_Crafting/" .. f .. ".lua"))("ONE_Crafting", c) end
local Tr = c.Trainers
Tr.seed = {
    {npc = "Stadt", kind = "profession", what = "Angeln", map = 1454, x = .5, y = .5},        -- Orgrimmar, weit weg
    {npc = "Dorf", kind = "profession", what = "Angeln", map = 1413, x = .5, y = .5},         -- Brachland, nah
    {npc = "Koch", kind = "profession", what = "Kochkunst", map = 1413, x = .5, y = .5},
}
local dist = {[1454] = 900, [1413] = 100}
ONE.modules.nav = {DistanceTo = function(_, map) return dist[map] end}
-- Faustregel: Geselle kann jeder -> der naechste; Experte nur Hauptstadt
assert(Tr:BestFor("Angeln", "Geselle").npc == "Dorf")
assert(Tr:BestFor("Angeln", "Experte").npc == "Stadt")
assert(Tr:BestFor("Bergbau", "Geselle") == nil)
-- Gemerkter Lehrer mit bekannter Stufe schlaegt die Faustregel
Tr:Store().Dorf = {npc = "Dorf", kind = "profession", what = "Angeln", map = 1413, x = .5, y = .5, teaches = {Geselle = true, Experte = true}}
assert(Tr:BestFor("Angeln", "Experte").npc == "Dorf", "sicher lehrend und naeher")
Tr:Store().Dorf.teaches = {Geselle = true}
assert(Tr:BestFor("Angeln", "Experte").npc == "Stadt", "lehrt Experte nachweislich nicht")
assert(Tr.Teaches({map = 1413}, "Geselle") == nil and Tr.Teaches({map = 1413}, "Fachmann") == false and Tr.Teaches({map = 1456}, "Fachmann") == nil)

-- Teilen: gelehrte Stufen gehen mit (9. Feld) und kommen an
local sent = {}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(_, msg) sent[#sent + 1] = msg return true end}
IsInGuild = function() return true end
C_Timer = nil
assert(loadfile(root .. "/ONE_Crafting/Share.lua"))("ONE_Crafting", c)
c.Share.IsSharing = function() return true end
c.Share:SendTrainer({npc = "Kil'hala", kind = "profession", what = "Angeln", map = 1413, x = .5, y = .5, area = "Brachland", teaches = {Experte = true, Geselle = true}})
c.Share:Flush(5)
local msg = sent[#sent]
assert(msg and msg:find("|Geselle,Experte|$"), tostring(msg))
c.Share:Receive(c.Share.prefix, msg, "GUILD", "Thrall")
assert(Tr:Store()["Kil'hala"].teaches.Experte and Tr.TeachText(Tr:Store()["Kil'hala"]) == "lehrt Geselle, Experte")
assert(Tr:Store()["Kil'hala"].weapons == nil, "Berufslehrer ohne Waffen")
-- Waffenmeister: Waffenarten gehen mit (10. Feld, sortiert) und kommen an
c.Share:SendTrainer({npc = "Ansekhwa", kind = "weapon", what = "Waffenmeister", map = 1456, x = .408, y = .626, area = "Donnerfels",
    weapons = {staff = true, gun = true, mace2 = true}})
c.Share:Flush(5)
msg = sent[#sent]
assert(msg:find("|gun,mace2,staff$"), msg)
Tr:Store().Ansekhwa = nil
c.Share:Receive(c.Share.prefix, msg, "GUILD", "Thrall")
local w = Tr:Store().Ansekhwa.weapons
assert(w and w.gun and w.mace2 and w.staff and not w.bow)
-- spaeterer Fund ohne Waffenfeld (aeltere Version) behaelt das bekannte Angebot
c.Share:Receive(c.Share.prefix, "T|Ansekhwa|weapon|Waffenmeister|1456|0.408|0.626|Donnerfels|", "GUILD", "Alt")
assert(Tr:Store().Ansekhwa.weapons.gun, "altes Angebot bleibt")
-- unsinnige Schluessel werden verworfen, Waffenfeld nur bei Waffenmeistern
c.Share:Receive(c.Share.prefix, "T|Neu|weapon|Waffenmeister|1456|0.4|0.6|Donnerfels||bow,<x>,Axt", "GUILD", "Thrall")
assert(Tr:Store().Neu.weapons.bow and not Tr:Store().Neu.weapons["<x>"] and not Tr:Store().Neu.weapons.Axt)
c.Share:Receive(c.Share.prefix, "T|Koch|profession|Kochkunst|1456|0.4|0.6|Donnerfels||bow", "GUILD", "Thrall")
assert(Tr:Store().Koch.weapons == nil)
-- Startpaket: Lehrer kommen vor der Grundliste dazu
c.TrainerPack = {Fachkraft = {kind = "profession", what = "Angeln", map = 1456, x = .1, y = .1, teaches = {Fachmann = true}}}
assert(Tr:BestFor("Angeln", "Fachmann").npc == "Fachkraft")
print("OK test_trainernavi_077")
