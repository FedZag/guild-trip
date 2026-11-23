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
print("OK test_route_opt_162")
