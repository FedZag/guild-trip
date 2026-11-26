-- Offline-Test: Stuetzpunkt-Fuehrung (Neuanfang 26.11.2026, Hubs.lua). Harte Regeln mit erfundenen Daten:
--  * kein Gebietswechsel, solange im angefangenen Gebiet passende Quests offen sind (auch nur eine)
--  * Abstecher (man steht in Orgrimmar/einem anderen Gebiet) aendern das Gebiet nicht
--  * am Stuetzpunkt wird alles angenommen (Mindeststufe erreicht); erledigt wird nur bis 2 Stufen ueber der eigenen
--  * graue Quests, Quests ohne EP, Dungeon-Quests fallen weg; Elite bleibt ("Spaeter": 1 = ans Ende, 2 = raus)
--  * anderes Gebiet erst mit mindestens H.ZONE_MIN Quests; feste Gebietsfolge (kein "naechstes Gebiet")
--  * Hauen nur fuer ein paar tausend EP, sonst ausnahmsweise +3
--  * Reihenfolge: annehmen < Ziel < Abgabe, Folgequest erst nach Abgabe der Vorquest; Quest am Weg wird mitgenommen
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local lev = {}
-- Karten: 1411 Durotar (x 0..10000), 1413 Brachland (x 20000..), 1442 Steinkrallen (x 40000..), 1454 Orgrimmar
local OFF = {[1411] = 0, [1413] = 20000, [1442] = 40000, [1454] = 10500, [1440] = 60000}
local function World(m, x, y)
    if not OFF[m] then return nil end
    return 1, OFF[m] + x * 5000, y * 5000
end
-- Knoten: {art, karte, x‰, y‰}
local N = {
    -- Durotar: Stuetzpunkt A (um 100/100), Ziele, Einzelgeber am Weg
    [1] = {0, 1411, 100, 100}, [2] = {0, 1411, 104, 100}, [3] = {0, 1411, 100, 104},
    [11] = {0, 1411, 300, 100}, [12] = {0, 1411, 300, 140}, [13] = {0, 1411, 600, 100},
    [5] = {0, 1411, 200, 100},   -- Geber am Weg (zwischen A und den Zielen)
    [15] = {0, 1411, 310, 120},  -- Ziel der Quest am Weg (nah an Ziel 11)
    -- Durotar: zweiter Stuetzpunkt B weit weg
    [7] = {0, 1411, 900, 900}, [17] = {0, 1411, 950, 900},
    -- Brachland: Stuetzpunkt C
    [21] = {0, 1413, 500, 500}, [22] = {0, 1413, 504, 500}, [31] = {0, 1413, 600, 500},
    -- Steinkrallen: Stuetzpunkt D
    [41] = {0, 1442, 500, 500}, [42] = {0, 1442, 600, 500},
    -- Orgrimmar
    [51] = {0, 1454, 500, 500},
}
local function Q(lvl, min, giver, ender, objs, xp, extra)
    local e = {lvl, min, 0, 0, false, {giver}, {ender}, objs, false, false, xp or 1000, 0, 0, 1411}
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end
local quests = {
    -- Durotar, Stuetzpunkt A
    [101] = Q(10, 8, 1, 1, {11}),
    [102] = Q(11, 8, 2, 2, {12}),
    [103] = Q(13, 9, 3, 3, {13}),          -- Mindeststufe ok, aber 3 Stufen drueber: annehmen, nicht erledigen
    [104] = Q(14, 12, 1, 1, {13}),         -- Mindeststufe zu hoch: nicht annehmen
    [105] = Q(3, 1, 2, 2, {11}),           -- grau
    [106] = Q(10, 8, 3, 3, {12}, 0),       -- ohne EP
    [107] = Q(10, 8, 1, 1, {13}, 1000, {[14] = 999}),  -- Ziel im Dungeon
    [108] = Q(10, 8, 2, 2, {13}),          -- Elite (Rewards Art 1)
    [109] = Q(10, 8, 1, 1, {}, 1000, {[5] = {101}}),   -- Folgequest von 101 (Botengang)
    -- Quest am Weg: Geber 5 zwischen A und den Zielen, Ziel 15 nah an Ziel 11, Abgabe am Stuetzpunkt
    [110] = Q(10, 8, 5, 1, {15}),
    [111] = Q(12, 8, 1, 1, {11}),          -- 2 Stufen drueber: erledigen (Nutzer 26.11.: 2 Stufen)
    -- Durotar, Stuetzpunkt B
    [120] = Q(10, 8, 7, 7, {17}),
    -- Brachland, Stuetzpunkt C (3 Quests)
    [201] = Q(10, 8, 21, 21, {31}), [202] = Q(10, 8, 22, 22, {31}), [203] = Q(11, 8, 21, 21, {31}),
    -- Steinkrallen, Stuetzpunkt D (3 Quests, kommt in der Folge nach dem Brachland)
    [301] = Q(10, 8, 41, 41, {42}), [302] = Q(10, 8, 41, 41, {42}), [303] = Q(10, 8, 41, 41, {42}),
}
GuildTripQuestDB = {q = quests, n = N}
GuildTripLeveling = {r = {[108] = "0|5|1||"}, i = {}, dz = {[999] = "testdungeon"}, sp = {}}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Hubs.lua"))("ONE_Leveling", lev)
local P, H = lev.Planner, lev.Hubs
assert(H and H.Decide, "Hubs.lua laedt")

local function Ctx(level, mapID, x, y, done, log)
    done, log = done or {}, log or {}
    return {me = {level = level, xp = 0, xpMax = P.XP_NEED[level], race = 2, class = 1, faction = "Horde", mapID = mapID, x = x, y = y},
        done = function(id) return done[id] == true end,
        inLog = function(id) return log[id] ~= nil end,
        complete = function(id) return log[id] == "done" end,
        world = World}
end
local function Only(keep)
    -- alle anderen Quests als erledigt markieren (Lage nachstellen)
    local d, set = {}, {}
    for _, id in ipairs(keep) do set[id] = true end
    for id in pairs(quests) do if not set[id] then d[id] = true end end
    return d
end
local function Rank(res, key) return res.follow[key] end

-- 1) Start in Durotar am Stuetzpunkt A, Stufe 10
local st = {}
local r = H.Decide(Ctx(10, 1411, .1, .1), st)
assert(r and r.zone == 1411, "Durotar zuerst")
for _, id in ipairs({101, 102, 103, 108}) do assert(Rank(r, "accept:" .. id), "am Stuetzpunkt annehmen: " .. id) end
assert(not Rank(r, "accept:104"), "Mindeststufe zu hoch: nicht annehmen")
assert(not Rank(r, "obj:103") and not Rank(r, "turnin:103"), "3 Stufen drueber: angenommen, nicht erledigt")
assert(Rank(r, "obj:102") and Rank(r, "turnin:102"), "1 Stufe drueber: erledigen")
assert(H.AHEAD == 2 and Rank(r, "obj:111") and Rank(r, "turnin:111"), "2 Stufen drueber: erledigen")
assert(not Rank(r, "accept:105"), "grau faellt weg")
assert(not Rank(r, "accept:106"), "ohne EP faellt weg")
assert(not Rank(r, "accept:107"), "Ziel im Dungeon faellt weg")
assert(Rank(r, "obj:108"), "Elite bleibt drin")
assert(not Rank(r, "accept:120"), "anderer Stuetzpunkt (B) nicht in dieser Runde")
-- Folgequest 109 nach Abgabe von 101
assert(Rank(r, "accept:109") and Rank(r, "accept:109") > Rank(r, "turnin:101"), "Folgequest erst nach Abgabe der Vorquest")
-- Quest am Weg (Geber zwischen Stuetzpunkt und Zielen, Ziel nah an Zielen der Runde)
assert(Rank(r, "accept:110") and Rank(r, "obj:110"), "Quest am Weg mit Ziel im selben Gebiet wird mitgenommen")
-- Reihenfolge: annehmen < Ziel < Abgabe
for id in pairs(quests) do
    local a, o, t = Rank(r, "accept:" .. id), Rank(r, "obj:" .. id), Rank(r, "turnin:" .. id)
    if a and o then assert(a < o, "annehmen vor Ziel " .. id) end
    if o and t then assert(o < t, "Ziel vor Abgabe " .. id) end
    if a and t then assert(a < t, "annehmen vor Abgabe " .. id) end
end
-- keine Quest ueber Stufe + 2 erledigt
for key in pairs(r.follow) do
    local kind, id = key:match("^(%a+):(%d+)$")
    if kind == "obj" or kind == "turnin" then
        assert(quests[tonumber(id)][1] <= 10 + 2, "zu hoch im Fahrplan: " .. key)
    end
end
assert(st.zone == 1411 and st.hub, "Gebiet und Stuetzpunkt gemerkt")

-- 2) Abstecher: Spieler in Orgrimmar / im Brachland, Gebiet bleibt Durotar (dort ist noch etwas offen)
local st2 = {zone = 1411}
r = H.Decide(Ctx(10, 1454, .5, .5), st2)
assert(r.zone == 1411, "Abstecher nach Orgrimmar aendert das Gebiet nicht")
r = H.Decide(Ctx(10, 1413, .5, .5), st2)
assert(r.zone == 1411, "im Brachland stehen aendert das angefangene Gebiet nicht")

-- 3) im Gebiet nur noch EINE passende Quest (120 am Stuetzpunkt B), Brachland hat 3: trotzdem bleiben
local d = Only({120, 201, 202, 203, 301, 302, 303})
local st3 = {zone = 1411}
r = H.Decide(Ctx(10, 1411, .1, .1, d), st3)
assert(r.zone == 1411 and Rank(r, "accept:120"), "eine passende Quest im Gebiet: nicht wechseln")
-- 4) Durotar leer -> erstes Gebiet der Folge mit >= ZONE_MIN (Brachland), nicht das naechstgelegene
d[120] = true
r = H.Decide(Ctx(10, 1442, .5, .5, d), {zone = 1411})
assert(r.zone == 1413, "feste Folge: Brachland vor Steinkrallen, auch wenn man in Steinkrallen steht")
-- 5) Brachland mit nur 2 Quests: Folge geht weiter zu Steinkrallen (keine Reise fuer zu wenig)
d[203] = true
r = H.Decide(Ctx(10, 1411, .1, .1, d), {zone = 1411})
assert(H.ZONE_MIN == 3 and r.zone == 1442, "zu wenig im Brachland: Steinkrallen (" .. tostring(r.zone) .. ")")
-- ... aber wer schon im Brachland questet, bleibt fuer die 2
r = H.Decide(Ctx(10, 1413, .5, .5, d), {zone = 1413})
assert(r.zone == 1413, "angefangenes Gebiet mit 2 Quests: bleiben")

-- 5b) schon verlassenes Brachland mit 3 Quests: erst ab H.REVISIT_MIN zurueck -> weiter nach Steinkrallen
local d5 = Only({201, 202, 203, 301, 302, 303})
r = H.Decide(Ctx(10, 1411, .1, .1, d5), {zone = 1411, left = {[1413] = 9}})
assert(H.REVISIT_MIN > 3 and r.zone == 1442, "kein Hin und Her: verlassenes Gebiet erst mit mehr Quests")
r = H.Decide(Ctx(10, 1411, .1, .1, d5), {zone = 1411})
assert(r.zone == 1413, "nicht verlassen: Brachland mit 3 Quests")

-- 5c) gerade aus dem Brachland gekommen: nicht gleich wieder hin (kein A -> B -> A -> B), wenn Steinkrallen passt
r = H.Decide(Ctx(10, 1411, .1, .1, d5), {zone = 1411, from = 1413})
assert(r.zone == 1442, "kein Hin und Her: nicht zurueck, woher man kam")
-- ... gibt es sonst nichts, dann doch
local d6 = Only({201, 202, 203})
r = H.Decide(Ctx(10, 1411, .1, .1, d6), {zone = 1411, from = 1413})
assert(r.zone == 1413, "sonst nichts: doch zurueck")

-- 6) Elite "Spaeter": 1 = Ziel/Abgabe ans Ende, 2 = raus
r = H.Decide(Ctx(10, 1411, .1, .1), {}, {[108] = 1})
local maxR = 0
for _, v in pairs(r.follow) do if v > maxR then maxR = v end end
assert(Rank(r, "turnin:108") == maxR, "Spaeter 1: Abgabe ganz am Ende")
for key, v in pairs(r.follow) do
    if not key:find(":108$") and not key:find("^accept") then assert(v < Rank(r, "obj:108"), "Spaeter 1: Ziel nach allen anderen") end
end
r = H.Decide(Ctx(10, 1411, .1, .1), {}, {[108] = 2})
assert(not Rank(r, "accept:108") and not Rank(r, "obj:108"), "Spaeter 2: raus")

-- 7) Stufenluecke: nirgends etwas bis +2. Wenige EP fehlen -> kurz hauen; sonst ausnahmsweise +3
local onlyHigh = Only({103})
r = H.Decide(Ctx(10, 1411, .1, .1, onlyHigh, {[103] = "open"}), {zone = 1411})
-- 103 (Stufe 13) mit Stufe 10: bis Stufe 11 fehlen mehr als 3000 EP -> nicht hauen, +3 erlaubt
assert(r.zone == 1411 and r.ahead == 3 and Rank(r, "obj:103") and not r.grindTo, "grosse Luecke: +3 statt ganze Stufe hauen")
local c = Ctx(10, 1411, .1, .1, onlyHigh, {[103] = "open"})
c.me.xp = c.me.xpMax - 1500
r = H.Decide(c, {zone = 1411})
assert(r.grindTo == 11 and r.ahead == 2 and Rank(r, "obj:103") and next(r.gates), "kleine Luecke (1500 EP): kurz hauen bis 11")
assert(r.waiting and not r.waiting[103], "103 ist im Plan")

-- 7b) Botengang mit Abgabe in der Stadt, letzter Stuetzpunkt auf einem anderen Kontinent (Spielnachstellung Zwerg,
-- Hinterland -> Sturmwind, 26.11.2026: Fuehrung stand still): Abgabe trotzdem planen
quests[204] = Q(43, 38, 21, 51, {})
r = H.Decide(Ctx(51, 1411, .9, .9, Only({204}), {[204] = "done"}), {zone = 1413, anchor = {2, 100, 100}})
assert(r.zone == 1413 and Rank(r, "turnin:204"), "Abgabe in der Stadt geplant, auch wenn der letzte Stuetzpunkt woanders lag")
quests[204] = nil

-- 7c) Dungeon-Quest im Log (Ziel laut Daten draussen im Gebiet): nie Arbeit, haelt das Gebiet nicht fest
-- (Spieltest 26.11.2026: sechs Quests der Hoehle des Wehklagens im Log, Fuehrung blieb leer im Brachland)
r = H.Decide(Ctx(10, 1411, .1, .1, Only({107, 201, 202, 203}), {[107] = "open"}), {zone = 1411})
assert(r.zone == 1413 and not Rank(r, "obj:107") and r.waiting[107] == "dungeon", "Dungeon-Quest im Log: weiter ins Brachland")
-- fertig (Gruppe war im Dungeon): Abgabe draussen wird geplant
r = H.Decide(Ctx(10, 1411, .1, .1, Only({107}), {[107] = "done"}), {zone = 1411})
assert(Rank(r, "turnin:107"), "fertige Dungeon-Quest: Abgabe planen")
-- Abgabe in einem anderen Gebiet: Grund "turnin", nicht "naechste Runde" (Brief an Jin'Zil)
quests[204] = Q(10, 8, 1, 41, {})
r = H.Decide(Ctx(10, 1411, .1, .1, Only({204, 101}), {[204] = "done"}), {zone = 1411})
assert(r.waiting[204] == "turnin", "Abgabe woanders: Grund turnin (" .. tostring(r.waiting[204]) .. ")")
quests[204] = nil

-- 8) wartende Quests: zu hoch im Log = "high" (kein "Nicht im Plan")
r = H.Decide(Ctx(10, 1411, .1, .1, nil, {[103] = "open"}), {zone = 1411})
assert(r.waiting[103] == "high", "zu hoch im Log wartet")

-- 9) Reihenfolge-Optimierer: kuerzer als die naive Reihenfolge, Bedingungen gehalten
local stops = {}
for i = 1, 12 do
    local x = (i * 7919) % 1000
    stops[#stops + 1] = {key = "s" .. i, kind = "obj", w = {1, x, (i * 104729) % 1000}, pre = i > 1 and {"s1"} or {}}
end
local path = H.Order2(stops, {1, 0, 0})
assert(#path == 12 and path[1].key == "s1", "Bedingung s1 zuerst")
assert(H.PathLength(path, {1, 0, 0}) < H.PathLength(stops, {1, 0, 0}), "optimierte Schleife kuerzer")

print("OK test_hubs_178")
