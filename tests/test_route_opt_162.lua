-- Offline-Test: Gesamt-Optimierer fuer feste Routen (scripts/route_opt.lua, Neubau 23.11.2026, Nutzer: "speed-leveling
-- heisst nicht, von Ratchet 2,5 km nach Norden zu laufen um dort Samophlang zu machen und dann 2,5 km zurueck").
-- Zwei Besuche im selben fernen Bereich werden einer, Abgaben warten auf den naechsten Besuch beim selben NPC, und die
-- Spielregeln gelten immer: annehmen < Ziel < abgeben, Vorquest vor Folgequest, Mindeststufe (sonst Monster hauen davor).
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
-- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, ...}
local function Qst(xp, min, pre) return {2, min or 1, 0, 0, false, {}, {}, {1}, pre or false, false, xp or 400, 0, 0, 1} end
GuildTripQuestDB = {q = {[1] = Qst(), [2] = Qst(), [3] = Qst(), [4] = Qst(400, 1, {3}), [5] = Qst(400, 3)}, n = {}}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local opt = dofile((root:gsub("src$", "scripts")) .. "/route_opt.lua")
local Q = GuildTripQuestDB

local H, H2, F1, F2, N = {1, 0, 0}, {1, 100, 0}, {1, 3000, 0}, {1, 3060, 40}, {1, 300, 0}
local function S(q, w, n, g) return {q = q, w = w, map = 1, n = n, g = g or 0, l = 1} end
-- Ausgangsroute (so wie ein gieriger Planer sie baut): zweimal hin und her zum fernen Bereich
local route = {
    S("a1 a2", H, 11), S("o1", F1, -31, 50), S("t1", H, 11, 400),
    S("a3", H2, 13), S("o3", N, -33, 50), S("t3 a4", H2, 13, 400), S("o4", N, -34, 50), S("t4", H2, 13, 400),
    S("o2", F2, -32, 50), S("t2", H, 11, 400),
    S("a5", H2, 13), S("o5", N, -35, 50), S("t5", H2, 13, 400),
}
local out, info = opt.Run(route, {Q = Q, P = P, XP_NEED = P.XP_NEED, startXP = 0, fps = {}, known0 = {}, passes = 6})
assert(not info.skipped, "Ausgangsroute gueltig")
assert(info.saved > 5, "Weg gespart: " .. tostring(info.saved))

-- 1) der ferne Bereich nur noch einmal: o1 und o2 direkt hintereinander, kein Weg dorthin dazwischen
local at, far = {}, 0
local prevFar = false
for i, r in ipairs(out) do
    for k, id in (r.q or ""):gmatch("(%a)(%d+)") do at[k .. id] = at[k .. id] or i end
    local isFar = r.w and r.w[2] > 2000
    if isFar and not prevFar then far = far + 1 end
    prevFar = isFar
end
assert(far == 1, "ferner Bereich einmal, nicht " .. far)
assert(at.o1 and at.o2 and math.abs(at.o1 - at.o2) <= 1, "o1 und o2 am Stueck")

-- 2) Spielregeln entlang der neuen Route (EP inkl. eingefuegtem Monster hauen)
local XPN, cum = P.XP_NEED, 0
local function LevelAt(total) local lv, x = 1, total while lv < 60 and x >= XPN[lv] do x = x - XPN[lv] lv = lv + 1 end return lv end
local pos = {}
for i, r in ipairs(out) do for k, id in (r.q or ""):gmatch("(%a)(%d+)") do pos[k .. id] = i end end
for i, r in ipairs(out) do
    local lvl = LevelAt(cum)
    for k, id in (r.q or ""):gmatch("(%a)(%d+)") do
        local e = Q.q[tonumber(id)]
        if k == "a" then
            assert(lvl >= e[2], ("a%s mit Stufe %d unter Mindeststufe %d"):format(id, lvl, e[2]))
            for _, p in ipairs(type(e[9]) == "table" and e[9] or {}) do assert(pos["t" .. p] and pos["t" .. p] <= i, "Vorquest " .. p .. " vor a" .. id) end
        elseif k == "o" then assert(pos["a" .. id] <= i and pos["t" .. id] >= i, "o" .. id .. " zwischen Annehmen und Abgeben")
        else assert(pos["a" .. id] <= i and pos["o" .. id] <= i, "t" .. id .. " nach Annehmen und Ziel") end
    end
    cum = cum + (r.g or 0)
end
-- 3) keine Quest verloren
for _, id in ipairs({1, 2, 3, 4, 5}) do for _, k in ipairs({"a", "o", "t"}) do assert(pos[k .. id], "fehlt " .. k .. id) end end
-- 4) Ziel an einen anderen Ort derselben Gegner (Spieltest 23.11.2026, Orc "Raptorhoerner" o865: Ziel beim Einzel-
-- Raptor kurz vor Ratschet, dieselben Raptoren stehen im Nordbrachland, wo die Route vorher ist). Quest 6 hat zwei
-- Ziel-Knoten: 66 nur bei R (3000/80), 65 im Norden (0/3050). Die Route laeuft fuer o6 extra nach R.
do
    Q.q[6] = {2, 1, 0, 0, false, {}, {}, {66, 65}, false, false, 400, 0, 0, 1}
    Q.q[7] = {2, 1, 0, 0, false, {}, {}, {1}, false, false, 400, 0, 0, 1}
    Q.n[66] = {0, 1, 300, 8}
    Q.n[65] = {0, 1, 0, 305}
    local Nn, R = {1, 0, 3000}, {1, 3000, 80}
    local r2 = {
        S("a6 a7", H, 11), S("o7", Nn, -37, 50), S("t7", H, 11, 400),
        S("o6", R, 66, 50), S("t6", H, 11, 400),
    }
    local function World(m, x, y) return 1, x * 10000, y * 10000 end
    local o2, i2 = opt.Run(r2, {Q = Q, P = P, XP_NEED = P.XP_NEED, startXP = 0, fps = {}, known0 = {}, passes = 6, world = World})
    assert(not i2.skipped and (i2.objMoves or 0) >= 1, "Ziel verlegt")
    local o6, toR
    for i, r in ipairs(o2) do
        if r.q and r.q:find("o6", 1, true) then o6 = r end
        if r.w and r.w[2] > 2000 then toR = true end
    end
    assert(o6 and o6.n == 65 and o6.w[3] > 2000, "o6 im Norden bei Knoten 65")
    assert(not toR, "kein Weg mehr nach R")
    -- ohne Weltkarte (env.world) bleibt alles, wie es war
    local o3 = opt.Run(r2, {Q = Q, P = P, XP_NEED = P.XP_NEED, startXP = 0, fps = {}, known0 = {}, passes = 6})
    for _, r in ipairs(o3) do if r.q == "o6" then assert(r.n == 66, "ohne Karte: Ziel bleibt") end end
end
-- 5) Quests mit Zeitlimit (Nutzer 23.11.2026): erst annehmen, wenn sie direkt erledigt werden; zwischen Annehmen und
-- Abgeben hoechstens 70 % des Limits. Quest 9 (10 min) wird am Anfang mit 10 angenommen, dann geht es erst weit weg
-- (o10) – also 9 vorher erledigen oder spaeter annehmen. Quest 11 (1 min) ist nie zu schaffen: raus, samt Folgequest 12.
do
    local function Q2(pre) return {2, 1, 0, 0, pre or false, {}, {}, {1}, false, false, 400, 0, 0, 1} end
    Q.q[9], Q.q[10], Q.q[11], Q.q[12] = Q2(), Q2(), Q2(), Q2({11})
    Q.timed = {[9] = 600, [11] = 60}
    local r3 = {
        S("a9 a10 a11", H, 11), S("o10", F1, -40, 50), S("t10", H, 11, 400),
        S("o9", N, -39, 50), S("t9", H, 11, 400),
        S("o11", F2, -41, 50), S("t11 a12", H, 11, 400), S("o12", N, -42, 50), S("t12", H, 11, 400),
    }
    local o4, i4 = opt.Run(r3, {Q = Q, P = P, XP_NEED = P.XP_NEED, startXP = 0, fps = {}, known0 = {}, passes = 6})
    assert(not i4.skipped, "Ausgangsroute gueltig")
    local at = {}
    for i, r in ipairs(o4) do for k, id in (r.q or ""):gmatch("(%a)(%d+)") do at[k .. id] = at[k .. id] or i end end
    assert(at.a9 and at.a9 <= at.o9 and at.o9 <= at.t9, "9 vollstaendig")
    -- kein ferner Weg zwischen Annehmen und Abgeben von 9 (entweder 9 gleich erledigt oder spaeter angenommen)
    for i = at.a9, at.t9 do assert(not (o4[i].w and o4[i].w[2] > 2000), "ferner Weg waehrend Zeitquest 9") end
    assert(not (at.a11 or at.o11 or at.t11 or at.a12 or at.t12), "11 (nicht zu schaffen) und Folgequest 12 raus")
    assert(#(i4.timedRemoved or {}) == 2, "Zaehler")
    Q.timed = nil
end
-- 6) Spieltest 23.11.2026 "Raecht mein Dorf": nie nur zum Annehmen hinlaufen. Quest 13 wird angenommen und nie
-- abgegeben: ganz raus (und mit ihr der Weg zum fernen Geber F1)
do
    Q.q[13], Q.q[14] = Qst(), Qst()
    local r4 = {S("a14", H, 11), S("a13", F1, 51), S("o14", N, -44, 50), S("t14", H, 11, 400)}
    local o5, i5 = opt.Run(r4, {Q = Q, P = P, XP_NEED = P.XP_NEED, startXP = 0, fps = {}, known0 = {}, passes = 6})
    assert(not i5.skipped, "Ausgangsroute gueltig")
    for _, r in ipairs(o5) do assert(not (r.q or ""):find("13", 1, true), "13 ohne Abgabe ist raus") end
    assert(#(i5.noTurn or {}) == 1 and i5.saved > 5, "Zaehler und Weg gespart: " .. tostring(i5.saved))
end
print("OK test_route_opt_162")
