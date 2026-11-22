-- Offline-Test: Ausruestungs-Quests fest in die Route einbauen (Nutzer 22.11.2026, Schalter Optionen › Leveln,
-- Standard an). Eingebaut wird nur eine ganze Reihe ab dem ersten offenen Teil, ab 10 % besser oder leerer Platz,
-- hoechstens 3 Stufen ueber dir, nirgends in einen Dungeon – und nur ohne Zickzack: jeder Halt in einem Gebiet, durch
-- das die Route ohnehin kommt (oder in dem man steht), direkt neben einem Routen-Halt desselben Gebiets, wenig Umweg.
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
local ONE = {db = {}, modules = {}, ns = {}}
_G.ProjectONE = ONE
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [1] = {10, 8, 0, 0, false, {11}, {11}, {21}, false, false, 900, 0, 0, 1},    -- Route, Gebiet 1
        [2] = {10, 8, 0, 0, false, {15}, {15}, {}, false, false, 900, 0, 0, 2},      -- Route, Gebiet 2
        [50] = {10, 8, 0, 0, false, {12}, {12}, {}, false, false, 900, 51, 0, 1},    -- Ausruestungs-Reihe Teil 1
        [51] = {10, 8, 0, 0, false, {12}, {12}, {22}, {50}, false, 900, 0, 0, 1},    -- Teil 2 (Belohnung)
        [60] = {10, 8, 0, 0, false, {31}, {31}, {}, false, false, 900, 0, 0, 3},     -- Gebiet 3: Route kommt nie hin
        [61] = {10, 8, 0, 0, false, {16}, {16}, {}, false, false, 900, 0, 0, 2},     -- Gebiet 2, neben Route-Halt
        [62] = {10, 8, 0, 0, false, {12}, {12}, {}, false, false, 900, 63, 0, 1},    -- fuehrt danach in einen Dungeon
        [63] = {12, 10, 0, 0, false, {12}, {12}, {}, {62}, false, 900, 0, 0, 77},
        [64] = {15, 8, 0, 0, false, {12}, {12}, {}, false, false, 900, 0, 0, 1},     -- 5 Stufen ueber dir
        [65] = {10, 8, 0, 0, false, {17}, {17}, {27}, false, false, 100, 0, 0, 2},   -- Gebiet 2 (Ende der Route), aber weiter Umweg
        [66] = {10, 8, 0, 0, false, {32}, {32}, {}, false, false, 900, 0, 0, 2},     -- Gebiet 2, steht aber mitten in Gebiet 1
        [70] = {8, 6, 0, 0, false, {12}, {12}, {}, false, false, 900, 71, 0, 1},     -- schon erledigt
        [71] = {10, 8, 0, 0, false, {12}, {12}, {}, {70}, false, 900, 72, 0, 1},
        [72] = {10, 8, 0, 0, false, {12}, {12}, {}, {71}, false, 900, 0, 0, 1},
    },
    n = {
        [11] = {0, 1, 100, 100}, [12] = {0, 1, 120, 100}, [21] = {0, 1, 150, 150}, [22] = {0, 1, 130, 130},
        [15] = {0, 2, 600, 600}, [16] = {0, 2, 610, 600},
        [31] = {0, 3, 120, 110},
        [17] = {0, 2, 950, 50}, [27] = {0, 2, 50, 950},
        [32] = {0, 2, 110, 120},
    },
}
GuildTripLeveling = {r = {}, i = {}, dz = {[77] = "wc"}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
local P, G = lev.Planner, lev.Guide
local function World(m, x, y) return 1, x * 10000, y * 10000 end
local route = {
    {"a1", n = 11, l = 10}, {"o1", n = 21, l = 10}, {"t1", n = 11, l = 10},
    {"a2", n = 15, l = 10}, {"t2", n = 15, l = 10},
}
GuildTripQuestRoutes = {["16:128"] = route}
local doneSet = {[70] = true}
local done = function(id) return doneSet[id] == true end
local follow = G.RouteFollow(route, 10, function() return false end)

-- 1) welche Reihen ueberhaupt in Frage kommen (G.GearChains)
local function Row(q, plus, up)
    return {slot = {name = "x"}, upgrade = up ~= false, plus = plus, now = {item = {id = q}, sources = {{kind = "q", quest = q}}}}
end
local chains = G.GearChains({Row(51, 25), Row(51, 40), Row(60, 100), Row(61, 12), Row(62, 50), Row(64, 30),
    Row(65, 20), Row(66, 20), Row(72, 20), Row(1, 50), Row(52, 5), Row(53, 80, false)}, follow, 10, done)
local by = {}
for _, c in ipairs(chains) do by[c[#c]] = table.concat(c, ",") end
assert(by[51] == "50,51", "ganze Reihe ab dem ersten offenen Teil: " .. tostring(by[51]))
assert(by[72] == "71,72", "erledigter Teil faellt vorne weg: " .. tostring(by[72]))
assert(not by[62], "Reihe fuehrt danach in einen Dungeon: nicht einbauen")
assert(not by[64], "mehr als 3 Stufen ueber dir: nicht einbauen")
assert(not by[1], "schon in der Route: nichts doppelt")
assert(not by[52] and not by[53], "unter 10 % oder keine Verbesserung: nicht einbauen")
local n51 = 0
for _, c in ipairs(chains) do if c[#c] == 51 then n51 = n51 + 1 end end
assert(n51 == 1, "dieselbe Reihe fuer zwei Plaetze nur einmal")

-- 2) Planer: was passt, kommt ohne Zickzack hinein
local function Ctx(gear)
    return {me = {level = 10, xp = 0, xpMax = 10000, class = 128, race = 16, faction = "Horde", mapID = 1, x = .1, y = .1},
        done = done, inLog = function() return false end, complete = function() return false end, world = World,
        tempo = "need", speed = 7, route = true, flow = true, follow = G.RouteFollow(route, 10, function() return false end),
        gear = gear}
end
local base = assert(P:Plan(Ctx(nil)))
local bk = " " .. table.concat(base.orderKeys, " ") .. " "
assert(not bk:find(":5[01] ") and not bk:find(":61 "), "ohne Schalter: nichts eingebaut: " .. bk)

local plan = assert(P:Plan(Ctx(chains)))
local list = plan.orderKeys
local keys = " " .. table.concat(list, " ") .. " "
local function At(k) for i, v in ipairs(list) do if v == k then return i end end end
assert(At("accept:50") and At("turnin:50") and At("accept:51") and At("turnin:51"), "Reihe 50/51 eingebaut: " .. keys)
assert(At("accept:50") < At("turnin:50") and At("turnin:50") < At("accept:51") and At("accept:51") < At("turnin:51"),
    "Reihe in der richtigen Reihenfolge: " .. keys)
assert(At("turnin:51") < At("accept:2"), "Reihe in Gebiet 1 bevor die Route nach Gebiet 2 geht: " .. keys)
assert(At("accept:61") and At("accept:61") > At("turnin:1"), "Gebiet 2 neben den Routen-Halten in Gebiet 2: " .. keys)
assert(not keys:find(":60 "), "Gebiet 3 (Route kommt nie hin): nicht eingebaut: " .. keys)
assert(not keys:find(":65 "), "weiter Umweg im selben Gebiet: nicht eingebaut: " .. keys)
assert(not keys:find(":66 "), "Halt aus Gebiet 2 mitten in Gebiet 1 (Zickzack): nicht eingebaut: " .. keys)
assert(plan.gearIn[50] and plan.gearIn[51] and plan.gearIn[61] and not plan.gearIn[60], "gearIn nennt die Eingebauten")
-- Routen-Reihenfolge bleibt
assert(At("accept:1") < At("turnin:1") and At("turnin:1") < At("accept:2") and At("accept:2") < At("turnin:2"), "Route bleibt: " .. keys)
-- jeder eingebaute Halt liegt neben einem Halt desselben Gebiets (harte Pruefung gegen Zickzack)
local zoneOf = {}
for id, e in pairs(GuildTripQuestDB.q) do zoneOf[id] = e[14] end
for i, k in ipairs(list) do
    local id = tonumber(k:match(":(%d+)$"))
    if plan.gearIn[id] then
        local zp = list[i - 1] and zoneOf[tonumber(list[i - 1]:match(":(%d+)$"))] or 1
        local zn = list[i + 1] and zoneOf[tonumber(list[i + 1]:match(":(%d+)$"))]
        assert(zp == zoneOf[id] or zn == zoneOf[id], "eingebauter Halt " .. k .. " neben demselben Gebiet: " .. keys)
    end
end

-- 3) Eingebaute erscheinen nicht mehr als "Besser fuer dich"
local gh = G.GearHints({Row(51, 25), Row(60, 100)}, follow, plan.gearIn)
assert(#gh == 1 and gh[1].src.quest == 60, "Hinweis nur fuer nicht Eingebautes: " .. #gh)

-- 4) Schalter: Standard an, aus = nichts einbauen
assert(G:GearOn() == true, "Ausruestungs-Quests einbauen: Standard an")
ONE.db.leveling.gearQuests = false
assert(G:GearOn() == false, "Schalter aus")
print("OK test_gearroute_156")
