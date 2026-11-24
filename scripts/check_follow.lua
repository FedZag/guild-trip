-- Gegenprobe "folgt das Spiel der Route?" (Spieltest 23.11.2026 "Raecht mein Dorf": die Route nahm an und ging
-- direkt zu den Gegnern, der Planer im Spiel schob die Gegner 120 Plaetze nach hinten – man lief quer zurueck).
-- Je Route an jedem N-ten Schritt K die Lage nachstellen wie nach Schritt K-1 (abgegeben/angenommen/Ziele erledigt bis
-- dahin, Standort = Halt K-1, Stufe der Route) und P:Plan wie im Spiel (ctx.route) rechnen. Der erste Schritt des
-- Plans muss eine Aktion von Routen-Schritt K enthalten oder an derselben Stelle liegen (<= SAME_YD), sonst ABWEICHUNG.
-- Aufruf: lua5.1 scripts/check_follow.lua <spf> [Routes.lua] [jeder N-te Schritt=20] [--hart]
local spfDir, file, every = arg[1], arg[2] or "src/ONE_Leveling/Routes.lua", tonumber(arg[3] or "") or 20
local hard = false
for i = 1, #arg do if arg[i] == "--hart" then hard = true end end
assert(spfDir, "Aufruf: lua5.1 scripts/check_follow.lua <spf> [Routes.lua] [N] [--hart]")
local SAME_YD = 300
local SKIP = tonumber(os.getenv("CF_SKIP") or "") or 0
local root = "src"
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
_G.ProjectONE = {db = {}, modules = {}, ns = {}}
for _, f in ipairs({"ONE_QuestDB/Data", "ONE_QuestDB/Names_deDE", "ONE_QuestDB/Objectives", "ONE_QuestDB/Timed", "ONE_Leveling/Rewards", "ONE_Leveling/ClassSpells"}) do
    assert(loadfile(root .. "/" .. f .. ".lua"))()
end
GuildTripQuestRoutes = nil
assert(loadfile(file))()
local lev = {}
assert(loadfile(os.getenv("CF_PLANNER") or (root .. "/ONE_Leveling/Planner.lua")))("ONE_Leveling", lev)  -- CF_PLANNER = Vergleich mit anderer Fassung
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
local P, G, Q = lev.Planner, lev.Guide, GuildTripQuestDB
local spf = {}
assert(loadfile(spfDir .. "/Data/Zones.lua"))("ShortestPathForever", spf)
local Z = spf.Zones
local function World(m, mx, my) local z = Z[m] if not z then return nil end return z.map, z.maxX - my * (z.maxX - z.minX), z.maxY - mx * (z.maxY - z.minY) end
local function Dist(a, b) return math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end
local navns = {}
assert(loadfile(root .. "/ONE_Nav/Travel.lua"))("ONE_Nav", navns)
local HORDE = {[2] = true, [16] = true, [32] = true, [128] = true}
local function Deps(faction)
    local out = {}
    for _, d in ipairs(navns.Travel.departures or {}) do
        if not d.faction or d.faction == faction then
            local c, wx, wy = World(d.mapID, d.x, d.y)
            if c then out[#out + 1] = {c, wx, wy, from = d.from, to = d.to, name = d.name, mapID = d.mapID, mx = d.x, my = d.y} end
        end
    end
    return out
end
-- Lage eines Routen-Schritts: erster Spawn seines Knotens (Ziel-Teile: erster Ziel-Knoten)
local function StepPos(st)
    local nr = (type(st.p) == "table" and st.p[1]) or st.n
    local nd = nr and Q.n[nr]
    if not nd or not nd[2] then return nil end
    local c, x, y = World(nd[2], nd[3] / 1000, nd[4] / 1000)
    return c and {c, x, y, map = nd[2], mx = nd[3] / 1000, my = nd[4] / 1000}
end
local keys = {}
for k in pairs(GuildTripQuestRoutes) do if not os.getenv("CF_KEY") or os.getenv("CF_KEY") == k then keys[#keys + 1] = k end end
table.sort(keys)
local total, bad, worst = 0, 0, {}
for _, key in ipairs(keys) do
    local route = GuildTripQuestRoutes[key]
    local race, class = key:match("^(%d+):(%d+)$")
    race, class = tonumber(race), tonumber(class)
    local faction = HORDE[race] and "Horde" or "Alliance"
    local deps = Deps(faction)
    local nBad, lines = 0, {}
    for K = every, #route, every do
        local st, prev = route[K], nil
        for i = K - 1, 1, -1 do if route[i][1] and StepPos(route[i]) then prev = route[i] break end end
        local want = st and st[1] and StepPos(st)
        local from = prev and StepPos(prev)
        if want and from and from[1] == want[1] then
            local done, log = {}, {}
            -- CF_SKIP=0.2: so ein Anteil der Quests bis dahin ausgelassen (Spieler ist anders gelaufen) – dann zaehlt
            -- nur noch, wie lange der Plan in den ersten 15 Schritten hauen laesst (HAUEN > P.ROUTE_GRIND_MAX)
            local skipped = {}
            for i = 1, K - 1 do
                for k, id in (route[i][1] or ""):gmatch("(%a)(%d+)") do
                    id = tonumber(id)
                    if SKIP > 0 and k == "a" and ((id * 7919 + K) % 1000) / 1000 < SKIP then skipped[id] = true end
                    if skipped[id] then
                    elseif k == "a" then log[id] = "open" elseif k == "o" and log[id] then log[id] = "done" elseif k == "t" then done[id] = true log[id] = nil end
                end
            end
            local level = st.l or 1
            local inLog = function(id) return log[id] ~= nil end
            local isDone = function(id) return done[id] == true end
            local ctx = {me = {level = level, xp = 0, xpMax = P.XP_NEED[level] or 13000, class = class, race = race, faction = faction,
                    mapID = from.map, x = from.mx, y = from.my},
                done = isDone, inLog = inLog, complete = function(id) return log[id] == "done" end,
                world = World, tempo = "balanced", speed = 7, departures = deps, route = true, flow = true}
            ctx.follow, ctx.objNodes, ctx.missed = G.RouteFollow(route, level, inLog, nil, isDone)
            local ok, plan = pcall(P.Plan, P, ctx)
            local s1 = ok and plan and plan.steps and plan.steps[1]
            if os.getenv("CF_SHOW") == key .. "@" .. K and ok then
                for i = 1, math.min(8, #plan.steps) do
                    local s, acts = plan.steps[i], {}
                    for _, a in ipairs(s.actions or {}) do acts[#acts + 1] = a.kind:sub(1, 1) .. a.id end
                    print(("    %d %s %s %.0f,%.0f %s"):format(i, s.kind, tostring(s.mapID), (s.x or 0) * 100, (s.y or 0) * 100, table.concat(acts, " ")))
                end
                for i = K - 2, K + 4 do if route[i] then print("    route", i, route[i][1] or route[i].k, route[i].n, route[i].z) end end
                for id in st[1]:gmatch("%a(%d+)") do
                    local inf = plan.info and plan.info[tonumber(id)]
                    local rs = {}
                    for k, v in pairs(inf and inf.reasons or {}) do rs[#rs + 1] = tostring(k) .. "=" .. tostring(v) end
                    print("    info", id, inf and inf.why, inf and inf.kind, table.concat(rs, " "), "follow", ctx.follow["accept:" .. id], ctx.follow["turnin:" .. id])
                end
            end
            if SKIP > 0 and ok and plan then
                local g = 0
                for i = 1, math.min(15, #plan.steps) do if plan.steps[i].kind == "grind" then g = g + (plan.steps[i].work or plan.steps[i].minutes or 0) end end
                total = total + 1
                if g > (P.ROUTE_GRIND_MAX or 10) then
                    nBad, bad = nBad + 1, bad + 1
                    local line = ("  %s Schritt %d (St %d): %.0f min hauen"):format(key, K, level, g)
                    lines[#lines + 1] = line
                    worst[#worst + 1] = {d = g, line = line}
                end
            elseif s1 and s1.kind ~= "grind" then
                total = total + 1
                local hit = false
                for _, a in ipairs(s1.actions or {}) do
                    local letter = a.kind == "accept" and "a" or a.kind == "obj" and "o" or a.kind == "turnin" and "t" or "?"
                    if (" " .. st[1] .. " "):find(" " .. letter .. a.id .. "[ %.]") then hit = true end
                end
                local got = s1.mapID and s1.x and {World(s1.mapID, s1.x, s1.y)}
                local d = got and got[1] == want[1] and Dist(got, want) or 1e9
                if not hit and d > SAME_YD then
                    nBad, bad = nBad + 1, bad + 1
                    local acts = {}
                    for _, a in ipairs(s1.actions or {}) do acts[#acts + 1] = a.kind:sub(1, 1) .. a.id end
                    local away = got and got[1] == from[1] and Dist(from, got) or -1
                    local line = ("  %s Schritt %d (St %d): Route %q, Spiel %s %s (%.0f yd weg, %.0f yd vom Routen-Halt)"):format(key, K, level, st[1], s1.kind, table.concat(acts, " "), away, d)
                    lines[#lines + 1] = line
                    worst[#worst + 1] = {d = away, line = line}
                end
            end
        end
    end
    print(("%-8s %3d Abweichungen"):format(key, nBad))
    for i = 1, math.min(3, #lines) do print(lines[i]) end
end
table.sort(worst, function(a, b) return a.d > b.d end)
print(("SUMME %d Proben, %d Abweichungen (%.1f %%)"):format(total, bad, 100 * bad / math.max(1, total)))
print("Weiteste Abweichungen:")
for i = 1, math.min(10, #worst) do print(worst[i].line) end
