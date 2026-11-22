-- Eine Spielerlage gegen die feste Route nachstellen (Neubau Quest-Fuehrung, 22.11.2026): was zeigt der Guide als
-- naechste Schritte? Nutzt Routes.lua + Planner wie im Spiel (ctx.route), mit Zeppelinen/Schiffen aus ONE_Nav.
-- Aufruf: lua5.1 scripts/route_lage.lua <spf> <Volksmaske> <Klassenmaske> <Fraktion> <Stufe> <Karte> <x> <y>
--         [erledigt-unter-Stufe] [Log-IDs mit Komma, "+" = fertig, z. B. 5726+,356,1960] [Schritte]
-- Beispiel (Spieltest 21.11.): lua5.1 scripts/route_lage.lua <spf> 16 128 Horde 15 1458 .85 .10 13 5726+,356,354,1960
local spfDir, race, class, faction, level, map, x, y, doneBelow, logArg, nSteps = ...
assert(spfDir and race and class and faction and level and map and x and y, "Aufruf: siehe Kopf der Datei")
race, class, level, map, x, y = tonumber(race), tonumber(class), tonumber(level), tonumber(map), tonumber(x), tonumber(y)
doneBelow, nSteps = tonumber(doneBelow or level - 2), tonumber(nSteps or 30)
local root = "src"
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
_G.ProjectONE = {db = {}, modules = {}, ns = {}}
for _, f in ipairs({"ONE_QuestDB/Data", "ONE_QuestDB/Names_deDE", "ONE_Leveling/Rewards", "ONE_Leveling/ClassSpells", "ONE_Leveling/Routes"}) do
    assert(loadfile(root .. "/" .. f .. ".lua"))()
end
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
local P, G = lev.Planner, lev.Guide
local spf = {}
assert(loadfile(spfDir .. "/Data/Zones.lua"))("ShortestPathForever", spf)
local Z = spf.Zones
local function World(m, mx, my) local z = Z[m] if not z then return nil end return z.map, z.maxX - my * (z.maxX - z.minX), z.maxY - mx * (z.maxY - z.minY) end
local navns = {}
assert(loadfile(root .. "/ONE_Nav/Travel.lua"))("ONE_Nav", navns)
local departures = {}
for _, d in ipairs(navns.Travel.departures or {}) do
    if not d.faction or d.faction == faction then
        local c, wx, wy = World(d.mapID, d.x, d.y)
        if c then departures[#departures + 1] = {c, wx, wy, from = d.from, to = d.to, name = d.name, mapID = d.mapID, mx = d.x, my = d.y} end
    end
end
local log = {}
for part in (logArg or ""):gmatch("[^,]+") do
    local id, plus = part:match("^(%d+)(%+?)$")
    if id then log[tonumber(id)] = plus == "+" and "done" or "open" end
end
local done = {}
local past = {level = doneBelow, class = class, race = race, faction = faction}
local never = function() return false end
for id, e in pairs(GuildTripQuestDB.q) do
    if (e[1] or 0) > 0 and e[1] < doneBelow and not log[id] and P.Fits(id, e, past, never, never) then done[id] = true end
end
local route = assert(G.Route(race, class), "keine Route fuer " .. race .. ":" .. class)
local inLog = function(id) return log[id] ~= nil end
local ctx = {me = {level = level, xp = 0, xpMax = P.XP_NEED[level] or 13000, class = class, race = race, faction = faction, mapID = map, x = x, y = y},
    done = function(id) return done[id] == true end, inLog = inLog, complete = function(id) return log[id] == "done" end,
    world = World, tempo = "need", speed = 7, departures = departures, route = true, flow = true,
    follow = G.RouteFollow(route, level, inLog)}
local c0 = os.clock()
local plan = assert(P:Plan(ctx))
print(("Planen: %.0f ms, %d Schritte"):format((os.clock() - c0) * 1000, #plan.steps))
local titles = GuildTripQuestDB.titles or {}
local function ZN(m) local z = Z[m] return z and (z.name or tostring(m)) or tostring(m) end
for i = 1, math.min(nSteps, #plan.steps) do
    local s = plan.steps[i]
    local acts = {}
    for _, a in ipairs(s.actions or {}) do acts[#acts + 1] = a.kind:sub(1, 1) .. " " .. tostring(titles[a.id] or a.id) end
    print(("%3d %-7s %-6s %-9s %s%s"):format(i, s.kind, tostring(s.mapID or ""), s.x and ("%.0f,%.0f"):format(s.x * 100, s.y * 100) or "", s.kind == "grind" and ("bis Stufe " .. tostring(s.lvl) .. " ") or "", table.concat(acts, ", ")))
end
