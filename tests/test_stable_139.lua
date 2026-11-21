-- Offline-Test: Quest-Auswahl bleibt stabil (Spieltest 20.11.2026: in Ratchet nach Crossroads geschickt, in
-- Crossroads nach Ratchet) und nach einem Flug im selben Gebiet wird neu geplant.
local root = arg[1] or "src"
GuildTripQuestDB = {
    q = {[1] = {15, 10, 0, 0, false, {11}, {11}, {}, false, false, 1000, 0, 0, 1}},
    n = {[11] = {0, 1, 600, 100}},  -- Geber 6000 yd weg
}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local function World(m, x, y) return 1, x * 10000, y * 10000 end
local function Ctx(prev)
    return {me = {level = 15, class = 128, faction = "Horde", mapID = 1, x = 0, y = .01},
        done = function() return false end, inLog = function() return false end, complete = function() return false end,
        world = World, tempo = "need", speed = 7, prevChosen = prev}
end
-- EP so einstellen, dass die Quest bei 90 % bzw. 110 % der Schwelle liegt (Schleifen 21.11.2026: gemessen wird
-- die EP/min der Quest in ihrer Schleife, loopEPM – ohne die Anreise zum Stuetzpunkt)
local function Tune(ratio)
    GuildTripQuestDB.q[1][11] = 1000
    local p = assert(P:Plan(Ctx()))
    local need = p.grind * p.factor
    local base = 1000
    for _ = 1, 30 do
        GuildTripQuestDB.q[1][11] = base
        local q = assert(P:Plan(Ctx())).info[1]
        base = base * (need * ratio / q.loopEPM)
    end
    GuildTripQuestDB.q[1][11] = base
    local q = assert(P:Plan(Ctx())).info[1]
    assert(math.abs(q.loopEPM / need - ratio) < .05, ("Einstellen %.2f"):format(q.loopEPM / need))  -- EP werden gerundet
end
Tune(.9)
assert(assert(P:Plan(Ctx())).chosen[1] == nil, "90 %: ohne Vorgeschichte nicht")
assert(assert(P:Plan(Ctx({[1] = "xp"}))).chosen[1] == "xp", "90 %: war gewaehlt -> bleibt")
Tune(1.08)
assert(assert(P:Plan(Ctx())).chosen[1] == "xp", "108 %: erster Plan nimmt sie")
assert(assert(P:Plan(Ctx({}))).chosen[1] == nil, "108 %: kommt nicht spaeter ploetzlich dazu (Geber weit weg)")
-- Geber gleich nebenan: normal
GuildTripQuestDB.n[11] = {0, 1, 0, 12}
Tune(1.05)
assert(assert(P:Plan(Ctx({}))).chosen[1] == "xp", "Geber nebenan: normale Schwelle")
print("OK test_stable_139")
