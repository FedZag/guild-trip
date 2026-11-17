-- Offline-Test: Questdatenbank (ONE_QuestDB aus QuestieDB Forever) – Geber fuer mich, Filter, Orte, Klick in der Zielverfolgung.
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local done, log = {}, {}
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return done[id] == true end,
    GetLogIndexForQuestID = function(id) return log[id] end,
}
local me = {race = "Orc", class = "WARRIOR", level = 1, faction = "Horde"}
UnitRace = function() return me.race, me.race end
UnitClass = function() return me.class, me.class end
UnitLevel = function() return me.level end
UnitFactionGroup = function() return me.faction end
local ONE = {db = {}}
_G.ProjectONE = ONE
for _, f in ipairs({"Data", "Names_deDE", "Names_enUS"}) do assert(loadfile(root .. "/ONE_QuestDB/" .. f .. ".lua"))() end
assert(GuildTripQuestDB.titles[4641] == "Euer Platz in der Welt", "deutsche Titel geladen")
local nav = {}
assert(loadfile(root .. "/ONE_Nav/QuestDB.lua"))("ONE_Nav", nav)
local Q = nav.QuestDB
assert(Q:Available())
local function Has(list, qid)
    for _, g in ipairs(list) do for _, q in ipairs(g.quests) do if q.id == qid then return g end end end
end
-- 1) Ork Stufe 1 im Tal der Pruefungen (Durotar 1411): erste Quest bei Kaltunk
local g = Has(Q:Givers({1411}), 4641)
assert(g and g.key == "c10176" and g.mapID == 1411 and math.abs(g.x - .433) < .01 and g.name ~= "", "Kaltunk mit Quest")
-- Vorquest: Nordhain (Mensch) – 7 „Säuberung im Koboldlager“ erst nach 783
me.race, me.faction = "Human", "Alliance"
assert(Has(Q:Givers({1429}), 783) and not Has(Q:Givers({1429}), 7), "Vorquest fehlt")
done[783] = true
assert(Has(Q:Givers({1429}), 7) and not Has(Q:Givers({1429}), 783), "erledigt weg, Folgequest da")
-- im Log: nicht mehr anbieten
log[7] = 3
assert(not Has(Q:Givers({1429}), 7))
log[7] = nil
me.race, me.faction = "Orc", "Horde"
-- Neue Felder: alle Vorquests, schließt aus, Höchststufe (am Datensatz geprüft)
local probe = {1, 1, 0, 0, false, {}, {}, {}, {111, 112}, {113}, 0, 0, 5, 0}
assert(not Q.Fits(99999, probe, Q.Player()), "nicht alle Vorquests")
done[111], done[112] = true, true
assert(Q.Fits(99999, probe, Q.Player()), "alle Vorquests erledigt")
log[113] = 1
assert(not Q.Fits(99999, probe, Q.Player()), "ausschließende Quest im Log")
log[113] = nil
me.level = 6
assert(not Q.Fits(99999, probe, Q.Player()), "über der Höchststufe")
me.level = 1
-- 2) Menschen sehen keine Horde-Geber
me.race, me.faction = "Human", "Alliance"
assert(not Has(Q:Givers({1411}), 4641), "Allianz sieht keine Horde-NPCs")
-- 3) Neues Volk (Forever) ohne Bitmaske: Fraktion entscheidet
me.race, me.faction = "Skyborne", "Horde"
assert(Has(Q:Givers({1411}), 4641))
-- 4) Stufe: zu hohe Quests nicht
me.race, me.level = "Orc", 1
local high = false
for _, gg in ipairs(Q:Givers({1413})) do for _, q in ipairs(gg.quests) do if q.level > 3 then high = true end end end
assert(not high, "Brachland-Quests fuer Stufe 1 ausgeblendet")
-- 5) Ort fuer eine Quest im Log: offen -> Ziel, fertig -> Abgabe
local open = Q:Location({id = 788, complete = false}, 1411)
assert(open and open.mapID == 1411 and open.db)
local finished = Q:Location({id = 788, complete = true}, 1411)
assert(finished and math.abs(finished.x - .421) < .01, "Abgabe bei Gornek")
-- 6) Bitmaske
assert(Q.Band(178, 2) == 2 and Q.Band(77, 2) == 0)
print("OK test_questdb_095")
