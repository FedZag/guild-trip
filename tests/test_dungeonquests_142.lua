-- Offline-Test: Dungeonquests in der Quest-Fuehrung (Nutzer 20.11.2026: "die [Dungeons] muessen nicht in den Guide,
-- die Quests dafuer jedoch schon" – Dungeons ueber den Dungeon-Finder; Vorquests "nur wenn du sowieso dort bist").
local root = arg[1] or "src"
local log, complete = {}, {}
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [1] = {21, 15, 0, 0, false, {11}, {11}, {}, false, false, 2000, 0, 0, 718},   -- Dungeonquest, Geber am Weg
        [2] = {18, 15, 0, 0, false, {12}, {12}, {}, false, false, 2000, 0, 0, 718},   -- Dungeonquest, Geber weit weg
        [3] = {16, 12, 0, 0, false, {11}, {13}, {}, false, false, 1, 0, 0, 17},       -- Vorquest: "sprich mit X" weit weg, allein wertlos
        [4] = {18, 15, 0, 0, {3}, {13}, {13}, {}, false, false, 2000, 0, 0, 718},     -- Dungeonquest nach der Vorquest
        [5] = {15, 10, 0, 0, false, {11}, {11}, {14}, false, false, 900, 0, 0, 17},   -- normale Quest
        [6] = {15, 10, 0, 0, false, {15}, {15}, {}, false, false, 900, 0, 0, 17},     -- normale Quest weiter weg
    },
    n = {
        [11] = {0, 1, 100, 100},   -- hier
        [12] = {0, 2, 900, 900},   -- anderes Gebiet
        [13] = {0, 2, 900, 100},   -- anderes Gebiet (z. B. Donnerfels)
        [14] = {0, 1, 110, 110},
        [15] = {0, 1, 300, 100},
    },
}
GuildTripLeveling = {r = {}, i = {}, dz = {[718] = "wc"}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local function Plan(x, y, m)
    return assert(P:Plan({me = {level = 15, class = 1, faction = "Horde", mapID = m or 1, x = x or .1, y = y or .1},
        world = function(m, x, y) return 1, (m - 1) * 2000 + x * 10000, y * 10000 end, tempo = "need", speed = 7,
        done = function() return false end, inLog = function(id) return log[id] ~= nil end,
        complete = function(id) return complete[id] == true end,
        catalog = function(key) return key == "wc" and {min = 15} or nil end,
        entrance = function() return {1, .5, .5} end}))
end
local function Has(plan, key) for _, k in ipairs(plan.orderKeys) do if k == key then return true end end return false end
local p = Plan()
-- kein Dungeon-Halt, keine Abgabe offener Dungeonquests
for _, st in ipairs(p.steps) do assert(st.kind ~= "dungeon", "kein Dungeon-Schritt") end
assert(Has(p, "accept:1"), "Dungeonquest am Weg mitnehmen")
assert(not Has(p, "turnin:1"), "Abgabe erst, wenn im Log fertig")
assert(not Has(p, "accept:2"), "Dungeonquest in anderem Gebiet: kein Umweg")
assert(not Has(p, "turnin:3"), "Vorquest-Kette in anderem Gebiet: kein Umweg")
assert(Has(p, "accept:5") and Has(p, "turnin:5"), "normale Quests wie immer")
-- Hinweis im Schritt
local hint
for _, st in ipairs(p.steps) do for _, a in ipairs(st.actions) do if a.kind == "accept" and a.id == 1 then hint = st.dungeon end end end
assert(hint == "wc", "Schritt kennt den Dungeon")
-- Schleifen um Stuetzpunkte (21.11.2026): im eigenen Gebiet nahe an der Runde (hoechstens P.CAND_R Minuten vom
-- Stuetzpunkt) ja – ganz allein am anderen Ende des Gebiets nicht (kein Umweg nur dafuer, "am Weg mitnehmen")
GuildTripQuestDB.n[16] = {0, 1, 180, 180}
GuildTripQuestDB.q[7] = {21, 15, 0, 0, false, {16}, {16}, {}, false, false, 2000, 0, 0, 718}
assert(Has(Plan(), "accept:7"), "Dungeonquest im eigenen Gebiet nahe der Runde: ja")
GuildTripQuestDB.n[16] = {0, 1, 700, 700}
assert(not Has(Plan(), "accept:7"), "Dungeonquest allein am anderen Ende des Gebiets: kein Umweg")
GuildTripQuestDB.q[7] = nil
-- steht man im anderen Gebiet beim Geber: dann ja
p = Plan(.9, .9, 2)
assert(Has(p, "accept:2"), "dort: annehmen")
-- im Log und fertig (Dungeon gelaufen): Abgabe ganz normal, auch mit Weg
log[2], complete[2] = "done", true
p = Plan()
assert(Has(p, "turnin:2"), "fertige Dungeonquest abgeben")
-- im Log, nicht fertig: keine Abgabe, kein Dungeon
log[2], complete[2] = "open", nil
p = Plan()
assert(not Has(p, "turnin:2"), "nicht fertig: nicht abgeben")
print("OK test_dungeonquests_142")
