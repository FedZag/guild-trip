-- Offline-Test 0.7.0: Gebietsbloecke im Planer – erst ein Gebiet fertig, dann das naechste;
-- gleiche Auswahl, nur andere Reihenfolge.
local root = arg[1] or "src"
-- Zwei Gebiete direkt nebeneinander: Karte 1 = Welt 1000..2000, Karte 2 = 2000..3000 (Yards)
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [1] = {5, 1, 0, 0, false, {11}, {11}, {}, false, false, 300, 0, 0, 1},  -- Karte 2, gleich hinter der Grenze
        [2] = {5, 1, 0, 0, false, {12}, {12}, {}, false, false, 300, 0, 0, 1},  -- Karte 1, etwas weiter weg
        [3] = {5, 1, 0, 0, false, {13}, {13}, {}, false, false, 300, 0, 0, 1},  -- Karte 2, tiefer drin
        [4] = {5, 1, 0, 0, false, {14}, {14}, {}, false, false, 300, 0, 0, 1},  -- Karte 1, noch weiter zurueck
    },
    n = {
        [11] = {0, 2, 20, 500},
        [12] = {0, 1, 800, 500},
        [13] = {0, 2, 270, 500},
        [14] = {0, 1, 300, 500},
    },
}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local function World(m, x, y) return 1, m * 1000 + x * 1000, y * 1000 end
local ctx = {
    me = {level = 5, class = 1, faction = "Horde", mapID = 1, x = .95, y = .5},
    done = function() return false end, inLog = function() return false end, complete = function() return false end,
    world = World, tempo = "all", speed = 7,
}
local function Maps(plan) local t = {} for _, s in ipairs(plan.steps) do t[#t + 1] = s.mapID end return table.concat(t, ",") end

-- Schleifen um Stuetzpunkte (21.11.2026): kein Zickzack ueber die Grenze (2,1,2,1) – hoechstens ein Wechsel
local zoned = assert(P:Plan(ctx))
local m = Maps(zoned)
assert(m == "1,1,2,2" or m == "2,2,1,1", "ohne Zickzack: " .. m)
-- Bloecke fuer die Anzeige
assert(#zoned.blocks == 2 and zoned.blocks[1].steps == 2 and zoned.blocks[2].steps == 2)
assert(zoned.steps[3].block == 2)
-- Weg hoechstens so lang wie "erst Karte 1, dann Karte 2" (150 + 500 + 720 + 250 = 1620 Yards)
local walk = 0
for _, s in ipairs(zoned.steps) do walk = walk + (s.walk or 0) end
assert(walk <= 1620 * P.DETOUR / 7 / 60 + .01, "kurzer Weg: " .. walk)

-- Spieltest 19.11.2026: im eigenen Gebiet ist der naechste Halt weit weg (1400 Yards),
-- gleich hinter der Grenze wartet eine Quest -> erst die nahe Quest, nicht quer durchs Gebiet laufen
GuildTripQuestDB.q = {
    [1] = {5, 1, 0, 0, false, {11}, {11}, {}, false, false, 300, 0, 0, 1},  -- Karte 2, 70 Yards
    [4] = {5, 1, 0, 0, false, {14}, {14}, {}, false, false, 300, 0, 0, 1},  -- Karte 1, 1450 Yards
}
GuildTripQuestDB.n[14] = {0, 1, .5, 500}
local far = assert(P:Plan(ctx))
assert(Maps(far):sub(1, 1) == "2", "nahe Quest hinter der Grenze zuerst: " .. Maps(far))
print("OK test_zoneblocks_109")
