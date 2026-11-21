-- Offline-Test: Nachbesserung der Quest-Reihenfolge (Spieltest 19.11.2026: "zweimal ueber 1400 m gelaufen")
-- Gierig (immer der naechste Halt) laesst eine Quest hinter dem Spieler liegen und laeuft spaeter zurueck.
local root = arg[1] or "src"
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [1] = {5, 1, 0, 0, false, {11}, {11}, {}, false, false, 300, 0, 0, 1},  -- A: 100 Yards vor mir
        [2] = {5, 1, 0, 0, false, {12}, {12}, {}, false, false, 300, 0, 0, 1},  -- B: 200 Yards vor mir
        [3] = {5, 1, 0, 0, false, {13}, {13}, {}, false, false, 300, 0, 0, 1},  -- C: 150 Yards HINTER mir
        [4] = {5, 1, 0, 0, false, {14}, {14}, {}, false, false, 300, 0, 0, 1},  -- D: weit vorn
        -- E braucht die Vorquest D (abgegeben) – darf nie vor D angenommen werden
        [5] = {5, 1, 0, 0, {4}, {14}, {14}, {}, false, false, 300, 0, 0, 1},
    },
    n = {
        [11] = {0, 1, 600, 500},
        [12] = {0, 1, 700, 500},
        [13] = {0, 1, 350, 500},
        [14] = {0, 1, 950, 500},
    },
}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
-- Karte 1 = Welt 1000..2000 Yards
local function World(m, x, y) return 1, m * 1000 + x * 1000, y * 1000 end
local ctx = {
    me = {level = 5, class = 1, faction = "Horde", mapID = 1, x = .5, y = .5},
    done = function() return false end, inLog = function() return false end, complete = function() return false end,
    world = World, tempo = "all", speed = 7,
}
local function Walk(plan) local w = 0 for _, s in ipairs(plan.steps) do w = w + (s.walk or 0) end return w * 7 * 60 / P.DETOUR end
local function Order(plan)
    local t = {}
    for _, s in ipairs(plan.steps) do for _, a in ipairs(s.actions) do t[#t + 1] = a.kind:sub(1, 1) .. a.id end end
    return table.concat(t, " ")
end

-- Schleifen um Stuetzpunkte (21.11.2026): die Route wird als Ganzes gebaut (beste Einfuegestelle je Halt) –
-- kein Nachbessern mehr noetig. Gierig waere A, B, zurueck zu C, dann nach vorn zu D: 100+100+350+600 = 1150 yd;
-- richtig ist C (hinter mir) zuerst, dann A, B, D: 150+250+100+250 = 750 yd.
local better = assert(P:Plan(ctx))
assert(Walk(better) <= 800, ("Weg %d yd (gierig waeren 1150)"):format(Walk(better)))
assert(Order(better):sub(1, 2) == "a3", "erst die Quest hinter mir: " .. Order(better))
for id = 1, 5 do assert(better.chosen[id], "alle Quests dabei: " .. id) end
-- Bedingungen: E erst annehmen, wenn D abgegeben ist; jede Quest erst annehmen, dann abgeben
local seen = {}
for tok in Order(better):gmatch("%S+") do
    local kind, id = tok:sub(1, 1), tonumber(tok:sub(2))
    if kind == "t" then assert(seen["a" .. id], "abgeben vor annehmen: " .. Order(better)) end
    if tok == "a5" then assert(seen.t4, "E vor Abgabe von D: " .. Order(better)) end
    seen[tok] = true
end
-- Zeiten passen zur neuen Reihenfolge
local sum = 0
for _, s in ipairs(better.steps) do sum = sum + (s.cost or 0) end
assert(math.abs(sum - better.minutes) < .01, "Minuten neu berechnet")
print("OK test_order_131")
