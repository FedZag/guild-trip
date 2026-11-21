-- Offline-Test: Stufen-Sperren der Quest-Fuehrung (Spieltest 19.11.2026: mit Stufe 14 "Raptorhoerner [18]"
-- annehmen und erledigen – Vorquest einer Dungeon-Quest, sonst nichts)
local root = arg[1] or "src"
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [865] = {18, 13, 0, 0, false, {11}, {11}, {12}, false, false, 1350, 1491, 0, 17},   -- draussen, Stufe 18
        [1491] = {18, 13, 0, 0, {865}, {11}, {11}, {}, false, false, 1350, 0, 0, 718},     -- Dungeon (Wehklagen)
        [959] = {18, 14, 0, 0, false, {13}, {13}, {}, false, false, 1350, 0, 0, 718},      -- Dungeon, ohne Vorquest
        [100] = {14, 12, 0, 0, false, {14}, {14}, {15}, false, false, 900, 0, 0, 17},      -- passt
        [101] = {17, 12, 0, 0, false, {14}, {14}, {16}, false, false, 1200, 0, 0, 17},     -- 3 ueber mir
    },
    n = {
        [11] = {0, 1, 500, 500}, [12] = {0, 1, 520, 500}, [13] = {0, 1, 510, 510},
        [14] = {0, 1, 490, 500}, [15] = {0, 1, 480, 500}, [16] = {0, 1, 470, 500},
    },
}
GuildTripLeveling = {r = {}, i = {}, dz = {[718] = "wc"}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local function Plan(level)
    return P:Plan({me = {level = level, class = 1, faction = "Horde", mapID = 1, x = .5, y = .5},
        world = function(m, x, y) return 1, m * 1000 + x * 1000, y * 1000 end, tempo = "all", speed = 7,
        catalog = function(key) return key == "wc" and {min = 15} or nil end,
        entrance = function() return {1, .55, .55} end})
end
local function Has(plan, kind, id)
    for _, s in ipairs(plan.steps) do
        if s.kind == kind and (s.ids and s.ids[1] == id or id == nil) then return true end
        for _, a in ipairs(s.actions) do if a.kind == kind and a.id == id then return true end end
    end
end
local p = Plan(14)
-- Vorquest draussen (18) bei Stufe 14: nicht dabei, die Dungeon-Quest dahinter wartet
assert(not p.chosen[865], "Raptorhoerner mit 14")
assert(not p.chosen[1491] and p.info[1491].skip, "Klugheitstraenke ohne Vorquest")
-- Dungeon-Quest ohne Vorquest: annehmen auf dem Weg ja, Dungeon selbst erst ab 15
assert(Has(p, "accept", 959), "Dungeon-Quest mitnehmen")
assert(not Has(p, "dungeon"), "Wehklagen erst ab 15")
-- normale Quest 3 Stufen drueber: Ziel nicht mit 14
assert(Has(p, "obj", 100) and not Has(p, "obj", 101), "Ziel Stufe 17 nicht mit 14")
-- mit 16: alles geht
local p16 = Plan(16)
assert(p16.chosen[865] and p16.chosen[1491], "mit 16 Kette dabei")
assert(not Has(p16, "dungeon") and Has(p16, "obj", 865) and Has(p16, "obj", 101), "Dungeon selbst nicht im Guide (Dungeon-Finder), Nutzer 20.11.2026")
-- Schlafsack-Reihe: Vorrang nur, wenn "jetzt erledigen" gewaehlt (Nutzer 19.11.2026)
GuildTripQuestDB.q[79007] = {22, 14, 0, 0, false, {17}, {17}, {}, false, false, 1750, 0, 0, 1}
GuildTripQuestDB.n[17] = {0, 1, 950, 950}
local function First(p) return p.steps[1].actions[1].kind .. p.steps[1].actions[1].id end
local base = {me = {level = 14, class = 1, faction = "Horde", mapID = 1, x = .5, y = .5},
    world = function(m, x, y) return 1, m * 1000 + x * 1000, y * 1000 end, tempo = "all", speed = 7}
local later = P:Plan(base)
assert(later.chosen[79007] == "rec" and First(later) ~= "accept79007", "ohne Wahl: kein Vorrang")
base.recFirst = function(key) return key == "sleepingbag" end
local now = P:Plan(base)
-- (was direkt hier bereit ist, wird vor dem Weggehen noch angenommen – Nutzer 20.11.2026, kein Rueckweg)
local firstFar
for _, k in ipairs(now.orderKeys) do
    local id = tonumber(k:match("%d+"))
    local o = id and now.info[id]
    if not (k:match("^accept") and o and o.giver and math.abs(o.giver.w[2] - 1500) < 60 and math.abs(o.giver.w[3] - 500) < 60) then firstFar = k break end
end
assert(firstFar == "accept:79007", "jetzt: Reihe zuerst – " .. table.concat(now.orderKeys, " "))
print("OK test_questlevels_133")
