-- Nachstellung der Quest-Fuehrung mit echten Daten (Quest-DB, Shortest-Path-Kartenrahmen, Flugpunkte, Gastwirte,
-- Lehrer): eine Figur arbeitet den Plan Schritt fuer Schritt ab, wie im Spiel (Fahrplan folgen, nach jedem Schritt
-- neu planen). Zaehlt Rueckwege, Hin-und-Her, Umsortieren und das Tempo (EP je Stunde).
--   lua5.1 scripts/sim_leveling.lua <shortest-path-forever-Ordner> [Lage|alle] [Schritte=40] [-v]
-- Lagen: siehe SCEN unten. -v zeigt jeden Schritt.
local spf = assert(arg[1], "Aufruf: lua5.1 scripts/sim_leveling.lua <spf> [Lage|alle] [Schritte] [-v]")
local want, maxSteps, verbose = arg[2] or "alle", tonumber(arg[3] or "") or 40, false
for i = 1, #arg do if arg[i] == "-v" then verbose = true end end
local root = "src"
GetLocale = function() return "deDE" end
for _, f in ipairs({"ONE_QuestDB/Data", "ONE_QuestDB/Timed", "ONE_QuestDB/Names_deDE", "ONE_QuestDB/Objectives", "ONE_QuestDB/Services", "ONE_Leveling/Rewards", "ONE_Leveling/ClassSpells"}) do
    assert(loadfile(root .. "/" .. f .. ".lua"))()
end
local lev = {}
for _, f in ipairs({"Planner", "FlightMasters", "Inns"}) do
    -- SIM_PLANNER=<Datei>: einen anderen Planer nachstellen (z. B. den alten zum Vergleich)
    local file = f == "Planner" and os.getenv("SIM_PLANNER") or (root .. "/ONE_Leveling/" .. f .. ".lua")
    assert(loadfile(file))("ONE_Leveling", lev)
end
local P = lev.Planner
-- SIM_FOLLOW=<Routes.lua>: wie im Spiel der festen Route folgen (ctx.route, Guide.RouteFollow) statt frei planen –
-- die Gegenprobe "was zeigt der Kasten?" (Nutzer 23.11.2026: "so kann man das niemandem praesentieren"). Zaehlt
-- EINZEL (Fussweg > 1500 m fuer weniger als einen Block Arbeit) und Hauen-Bloecke > P.ROUTE_GRIND_MAX.
local FOLLOW, G
if os.getenv("SIM_FOLLOW") then
    local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
    CreateFrame = CreateFrame or function() return Stub() end
    UIParent = UIParent or Stub()
    _G.ProjectONE = _G.ProjectONE or {db = {}, modules = {}, ns = {}}
    assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
    G = lev.Guide
    for k, v in (os.getenv("SIM_GSET") or ""):gmatch("([%w_]+)=([%d.e+]+)") do G[k] = tonumber(v) end
    GuildTripQuestRoutes = nil
    assert(loadfile(os.getenv("SIM_FOLLOW")))()
    FOLLOW = GuildTripQuestRoutes
end
-- SIM_SET="NAME=Wert,NAME=Wert": Planer-Werte probeweise aendern (z. B. SIM_SET=FOLLOW_WORK=3)
for k, v in (os.getenv("SIM_SET") or ""):gmatch("([%w_]+)=([%d.]+)") do P[k] = tonumber(v) end
-- SIM_SCEN="Fraktion,Volk,KLASSE,Karte,x,y,HeimKarte,hx,hy": eigene Lage (Schluessel "custom", fuer build_routes.sh)
local customScen
do
    local v = os.getenv("SIM_SCEN")
    if v then
        local f = {}
        for x in v:gmatch("[^,]+") do f[#f + 1] = x end
        customScen = {key = "custom", fac = f[1], race = f[2], class = f[3], level = 1, map = tonumber(f[4]), x = tonumber(f[5]),
            y = tonumber(f[6]), home = {tonumber(f[7]), tonumber(f[8]), tonumber(f[9])}, doneBelow = 0,
            tempo = os.getenv("SIM_TEMPO")}  -- SIM_TEMPO = need/balanced/all (Optionen › Leveln, eigene Route je Stufe)
    end
end
local Q = GuildTripQuestDB
-- Dungeons (Nutzer 23.11.2026 "Dungeon-Quests einbauen"): Stufen aus dem Katalog, Eingaenge aus EntranceData
local DG = {}
assert(loadfile(root .. "/ONE_Dungeons/Catalog.lua"))("ONE_Dungeons", DG)
assert(loadfile(root .. "/ONE_Dungeons/EntranceData.lua"))("ONE_Dungeons", DG)
local CAT = {}
for _, c in ipairs(DG.Catalog or {}) do CAT[c.key] = c end
local DUNGEONS = os.getenv("SIM_NODUNGEONS") == nil
local spfns = {}
assert(loadfile(spf .. "/Data/Zones.lua"))("ShortestPathForever", spfns)
local Z = spfns.Zones
local navns = {}
do
    -- nur die Abfahrten (Schiffe/Zeppeline) aus Travel.lua
    local ok = pcall(function() assert(loadfile(root .. "/ONE_Nav/Travel.lua"))("ONE_Nav", navns) end)
    assert(ok and navns.Travel and navns.Travel.departures, "Travel.lua laden")
end

-- Kartenanteil -> Kontinent, Welt-X (Nord), Welt-Y (West) – wie C_Map.GetWorldPosFromMapPos
local function World(m, x, y)
    local z = Z[m]
    if not z then return nil end
    return z.map, z.maxX - y * (z.maxX - z.minX), z.maxY - x * (z.maxY - z.minY)
end
-- Welt -> Karte (Gebiet, dessen Rahmen den Punkt enthaelt; kleinster Rahmen gewinnt)
local function MapOf(c, wx, wy, hint)
    local best, score
    for m, z in pairs(Z) do
        if z.map == c and wx >= z.minX and wx <= z.maxX and wy >= z.minY and wy <= z.maxY then
            local u, v = (z.maxY - wy) / (z.maxY - z.minY), (z.maxX - wx) / (z.maxX - z.minX)
            if m == hint then return m, u, v end
            -- Rahmen ueberlappen: der Rahmen, in dessen Mitte der Punkt am ehesten liegt (Staedte bevorzugt klein)
            local sc = math.max(math.abs(u - .5), math.abs(v - .5))
            if z.city then sc = sc - .2 end
            if not score or sc < score then best, score = m, sc end
        end
    end
    if not best then return nil end
    local z = Z[best]
    return best, (z.maxY - wy) / (z.maxY - z.minY), (z.maxX - wx) / (z.maxX - z.minX)
end
local NAMES = {[1411] = "Durotar", [1412] = "Mulgore", [1413] = "Brachland", [1420] = "Tirisfal", [1421] = "Silberwald",
    [1424] = "Hügelland", [1426] = "Dun Morogh", [1429] = "Elwynn", [1431] = "Dämmerwald", [1432] = "Loch Modan",
    [1433] = "Rotkamm", [1436] = "Westfall", [1437] = "Sumpfland", [1438] = "Teldrassil", [1439] = "Dunkelküste",
    [1440] = "Eschental", [1441] = "Tausend Nadeln", [1442] = "Steinkrallen", [1443] = "Desolace", [1445] = "Düstermarschen",
    [1453] = "Sturmwind", [1454] = "Orgrimmar", [1455] = "Eisenschmiede", [1456] = "Donnerfels", [1457] = "Darnassus",
    [1458] = "Unterstadt", [1434] = "Schlingendorn", [1417] = "Arathi", [1416] = "Alterac"}
local function ZoneName(m) return NAMES[m] or tostring(m) end

local CLASS = {WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024}
local CLASS_DE = {WARRIOR = "Krieger", PALADIN = "Paladin", HUNTER = "Jäger", ROGUE = "Schurke", PRIEST = "Priester",
    SHAMAN = "Schamane", MAGE = "Magier", WARLOCK = "Hexenmeister", DRUID = "Druide"}
local RACE = {Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Undead = 16, Tauren = 32, Gnome = 64, Troll = 128}

-- Lagen: Fraktion, Volk, Klasse, Stufe, Ort, Heimatort (Karte, x, y), "erledigt bis Queststufe"
local SCEN = {
    {key = "h-durotar-1", fac = "Horde", race = "Orc", class = "WARRIOR", level = 1, map = 1411, x = .436, y = .689, home = {1411, .519, .416}, doneBelow = 0},
    {key = "h-barrens-12", fac = "Horde", race = "Orc", class = "MAGE", level = 12, map = 1413, x = .517, y = .302, home = {1413, .520, .297}, doneBelow = 10},
    {key = "h-barrens-15", fac = "Horde", race = "Troll", class = "MAGE", level = 15, map = 1413, x = .627, y = .372, home = {1413, .520, .297}, doneBelow = 13},
    {key = "h-barrens-20", fac = "Horde", race = "Tauren", class = "WARRIOR", level = 20, map = 1413, x = .449, y = .591, home = {1413, .520, .297}, doneBelow = 18},
    {key = "h-orgrimmar-12", fac = "Horde", race = "Orc", class = "WARRIOR", level = 12, map = 1454, x = .52, y = .62, home = {1413, .520, .297}, doneBelow = 11, log = {5726}},
    {key = "h-mid-30", fac = "Horde", race = "Undead", class = "MAGE", level = 30, map = 1441, x = .461, y = .510, home = {1441, .461, .510}, doneBelow = 28},
    {key = "a-mid-30", fac = "Alliance", race = "Human", class = "WARRIOR", level = 30, map = 1424, x = .51, y = .59, home = {1431, .738, .444}, doneBelow = 28},
    {key = "h-mid-45", fac = "Horde", race = "Orc", class = "HUNTER", level = 45, map = 1446, x = .515, y = .28, home = {1446, .517, .275}, doneBelow = 43},
    {key = "a-mid-45", fac = "Alliance", race = "Dwarf", class = "PRIEST", level = 45, map = 1446, x = .52, y = .29, home = {1446, .525, .29}, doneBelow = 43},
    {key = "h-mulgore-6", fac = "Horde", race = "Tauren", class = "DRUID", level = 6, map = 1412, x = .469, y = .602, home = {1412, .469, .602}, doneBelow = 4},
    {key = "h-silverpine-12", fac = "Horde", race = "Undead", class = "PRIEST", level = 12, map = 1421, x = .435, y = .412, home = {1421, .432, .415}, doneBelow = 10},
    {key = "h-stonetalon-22", fac = "Horde", race = "Orc", class = "HUNTER", level = 22, map = 1442, x = .454, y = .594, home = {1413, .520, .297}, doneBelow = 20},
    {key = "h-needles-27", fac = "Horde", race = "Troll", class = "SHAMAN", level = 27, map = 1441, x = .461, y = .510, home = {1413, .520, .297}, doneBelow = 25},
    {key = "h-mulgore-1", fac = "Horde", race = "Tauren", class = "HUNTER", level = 1, map = 1412, x = .449, y = .772, home = {1412, .469, .602}, doneBelow = 0},
    {key = "h-tirisfal-mage-1", fac = "Horde", race = "Undead", class = "MAGE", level = 1, map = 1420, x = .303, y = .713, home = {1420, .612, .526}, doneBelow = 0},
    {key = "h-tirisfal-1", fac = "Horde", race = "Undead", class = "WARLOCK", level = 1, map = 1420, x = .303, y = .713, home = {1420, .612, .526}, doneBelow = 0},
    {key = "a-elwynn-1", fac = "Alliance", race = "Human", class = "PALADIN", level = 1, map = 1429, x = .484, y = .418, home = {1429, .437, .658}, doneBelow = 0},
    {key = "a-dunmorogh-1", fac = "Alliance", race = "Dwarf", class = "PALADIN", level = 1, map = 1426, x = .297, y = .717, home = {1426, .474, .524}, doneBelow = 0},
    {key = "a-teldrassil-1", fac = "Alliance", race = "NightElf", class = "WARRIOR", level = 1, map = 1438, x = .587, y = .424, home = {1438, .556, .598}, doneBelow = 0},
    {key = "a-elwynn-6", fac = "Alliance", race = "Human", class = "WARRIOR", level = 6, map = 1429, x = .421, y = .655, home = {1429, .437, .658}, doneBelow = 5},
    {key = "a-westfall-12", fac = "Alliance", race = "Human", class = "ROGUE", level = 12, map = 1436, x = .560, y = .470, home = {1436, .526, .536}, doneBelow = 10},
    {key = "a-darkshore-14", fac = "Alliance", race = "NightElf", class = "HUNTER", level = 14, map = 1439, x = .370, y = .440, home = {1439, .370, .440}, doneBelow = 12},
    {key = "a-lochmodan-14", fac = "Alliance", race = "Dwarf", class = "PRIEST", level = 14, map = 1432, x = .350, y = .480, home = {1432, .350, .480}, doneBelow = 12},
    {key = "a-redridge-18", fac = "Alliance", race = "Human", class = "MAGE", level = 18, map = 1433, x = .270, y = .450, home = {1433, .270, .450}, doneBelow = 16},
    {key = "a-duskwood-24", fac = "Alliance", race = "Gnome", class = "WARLOCK", level = 24, map = 1431, x = .735, y = .460, home = {1431, .735, .460}, doneBelow = 22},
    {key = "a-ashenvale-22", fac = "Alliance", race = "NightElf", class = "DRUID", level = 22, map = 1440, x = .369, y = .496, home = {1440, .369, .496}, doneBelow = 20},
}

local function Dist(a, b) return math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end
local XP_NEED = P.XP_NEED

local function Run(sc)
    local me = {level = sc.level, xp = 0, xpMax = XP_NEED[sc.level], class = CLASS[sc.class], race = RACE[sc.race],
        faction = sc.fac, inGroup = false, mapID = sc.map, x = sc.x, y = sc.y}
    local mask = P.FACTION_MASK[sc.fac]
    local done, log = {}, {}
    -- "erledigt": Quests unter der Stufe (eigene Fraktion), wie bei einer Figur, die bisher normal gelevelt hat
    if sc.doneBelow > 0 then
        local past = {level = sc.doneBelow, class = me.class, race = me.race, faction = me.faction}
        local never = function() return false end
        for id, e in pairs(Q.q) do
            if (e[1] or 0) > 0 and e[1] < sc.doneBelow and P.Fits(id, e, past, never, never) then done[id] = true end
        end
    end
    local facN = sc.fac == "Alliance" and 1 or 2
    local function Mine(f) return f % (facN * 2) >= facN end
    local known = {}  -- Flugpunkte: im Startgebiet + Gebiete unter der Stufe bekannt
    for _, f in ipairs(lev.FLIGHTMASTERS) do
        local z = Z[f[7] or 0]
        if Mine(f[5]) and z and ((z.low or 99) < math.max(2, sc.level - 4) or f[7] == sc.map or (z.city)) then known[f[1]] = true end
    end
    local known0 = {}
    for k in pairs(known) do known0[k] = true end
    local hc, hx, hy = World(sc.home[1], sc.home[2], sc.home[3])
    local inns = {}
    for _, inn in ipairs(lev.INNS) do if Mine(inn[5]) then inns[#inns + 1] = {inn[2], inn[3], inn[4], id = inn[1], name = inn[7]} end end
    local home = {hc, hx, hy, place = "Heim", map = sc.home[1]}
    do local bd for _, n in ipairs(inns) do if n[1] == hc and (not bd or Dist(n, home) < bd) then bd, home.inn = Dist(n, home), n.id end end end
    local spots, portal = {}, nil
    for npc, t in pairs(Q.trainers) do
        if t[1] == "class" and t[2] == CLASS_DE[sc.class] and Mine(t[6]) then spots[#spots + 1] = {mapID = t[3], x = t[4] / 1000, y = t[5] / 1000, name = npc} end
    end
    local trainedAt = sc.level - sc.level % 2
    local departures = {}
    for _, d in ipairs(navns.Travel.departures) do
        if not d.faction or d.faction == sc.fac then
            local c, wx, wy = World(d.mapID, d.x, d.y)
            if c then departures[#departures + 1] = {c, wx, wy, from = d.from, to = d.to, name = d.name, mapID = d.mapID, mx = d.x, my = d.y} end
        end
    end
    local t, hearthAt = 0, 0  -- Minuten
    local plan, workZone
    local stats = {steps = 0, minutes = 0, xp = 0, walkYd = 0, flights = 0, hearths = 0, returns = 0, pingpong = 0,
        reorder = 0, zones = {}, grind = 0, grindMin = 0, lines = {}, logMax = 0, startLevel = sc.level, quests = 0}
    local visits = {}      -- {w, step, kind}
    local hubTrail = {}    -- grobe Orte (> 1500 yd Spruenge)
    local oldKeys, executed, levelAt = nil, {}, {}
    local visit
    local curZ, leftAt = nil, {}
    local traced
    local acceptedAt, objAt, doneAt = {}, {}, {}
    -- schon im Questlog (Nachstellung eines Spieltests)
    for _, id in ipairs(sc.log or {}) do log[id] = "open" acceptedAt[id] = 0 end
    local function CouldAt(a, m)
        local e = Q.q[a.id]
        if a.kind == "accept" then
            if (e[2] or 0) > (levelAt[m] or 0) then return false end
            local function Was(p) return (doneAt[p] and doneAt[p] < m) or (done[p] and not doneAt[p]) end
            if type(e[9]) == "table" then for _, p in ipairs(e[9]) do if not Was(p) then return false end end end
            if type(e[5]) == "table" and #e[5] > 0 then
                local ok = false
                for _, p in ipairs(e[5]) do if Was(p) then ok = true end end
                if not ok then return false end
            end
            return true
        elseif a.kind == "obj" then return acceptedAt[a.id] ~= nil and acceptedAt[a.id] < m
        elseif a.kind == "turnin" then return objAt[a.id] ~= nil and objAt[a.id] < m end
        return false
    end
    local function Pos() local c, wx, wy = World(me.mapID, me.x, me.y) return {c, wx, wy} end
    local function MoveTo(w, mapHint)
        local m, x, y = MapOf(w[1], w[2], w[3], mapHint)
        if m then me.mapID, me.x, me.y = m, x, y end
    end
    local function AddXP(n)
        stats.xp = stats.xp + n
        me.xp = me.xp + n
        while me.level < 60 and me.xp >= me.xpMax do
            me.xp = me.xp - me.xpMax
            me.level = me.level + 1
            me.xpMax = XP_NEED[me.level] or me.xpMax
        end
        -- Spielzeit bis 60 (Vergleich vorher/nachher, 23.11.2026)
        if me.level >= 60 and not stats.t60 then stats.t60 = t end
    end
    local function Ctx()
        local flights, fp = {}, {}
        for _, f in ipairs(lev.FLIGHTMASTERS) do
            if Mine(f[5]) then
                if known[f[1]] then flights[#flights + 1] = {f[2], f[3], f[4], name = f[6]}
                else fp[#fp + 1] = {f[2], f[3], f[4], id = f[1], name = f[6]} end
            end
        end
        local now, nxt = 0, {}
        for lvl = 2, math.min(60, me.level + 2), 2 do
            if lvl > trainedAt then if lvl <= me.level then now = now + 1 else nxt[lvl] = 1 end end
        end
        local ctx = {
            me = me,
            done = function(id) return done[id] == true end,
            inLog = function(id) return log[id] ~= nil end,
            complete = function(id) return log[id] == "done" end,
            world = World, tempo = sc.tempo or "need", speed = 7,
            override = DunOverride and DunOverride() or nil,
            catalog = function(key)
                local c = CAT[key]
                if not DUNGEONS or not c or (c.faction and c.faction ~= sc.fac) or not DG.EntranceData[key] then return {min = 99} end
                return c
            end,
            flights = flights, departures = departures, fpSpots = fp,
            train = #spots > 0 and {now = now, next = nxt, spots = spots} or nil,
            home = home, hearthIn = math.max(0, hearthAt - t) * 60, inns = inns,
            workZone = workZone,
            prevChosen = plan and plan.chosen or nil,
            prevLog = plan and plan.logSeen or nil,
            flow = os.getenv("SIM_FLOW") ~= nil or nil,
            prefer = plan and plan.steps[1] and plan.steps[1].stopKey,
        }
        if FOLLOW then
            local route = FOLLOW[(me.race or 0) .. ":" .. (me.class or 0)] or G.Route(me.race, me.class)
            if route then
                ctx.route, ctx.flow, ctx.tempo = true, true, P.ROUTE_TEMPO
                ctx.follow, ctx.objNodes, ctx.missed, ctx.routeGates, ctx.routeDungeons = G.RouteFollow(route, me.level, ctx.inLog, nil, ctx.done, nil, ctx.complete)
                if os.getenv("FOLLOW_DBG") and tonumber(os.getenv("FOLLOW_DBG")) == stepNo then
                    local list = {}
                    for k, r in pairs(ctx.follow) do list[#list + 1] = {k = k, r = r} end
                    table.sort(list, function(a, b) return a.r < b.r end)
                    local shown = 0
                    print("  DBG missed", #ctx.missed)
                    for _, x in ipairs(list) do
                        local id = tonumber(x.k:match(":(%d+)$") or "")
                        if id and not done[id] and not (x.k:match("^accept") and log[id]) and not (x.k:match("^obj") and log[id] == "done") then
                            print(("  DBG %6.1f %s log=%s lvl=%s min=%s"):format(x.r, x.k, tostring(log[id]), tostring(Q.q[id] and Q.q[id][1]), tostring(Q.q[id] and Q.q[id][2])))
                            shown = shown + 1
                            if shown >= 25 then break end
                        end
                    end
                end
                return ctx
            end
        end
        if plan and plan.orderKeys then
            local f = {}
            for i, k in ipairs(plan.orderKeys) do if not f[k] then f[k] = i end end
            ctx.follow = f
        end
        return ctx
    end
    local function Line(s) if verbose then print(s) end stats.lines[#stats.lines + 1] = s end
    local einzel
    -- Dungeon-Lauf (Nutzer 23.11.2026: "Dungeon-Quests einbauen"): sind Quests fuer einen Dungeon im Log und passt die
    -- Stufe (ab Mindeststufe + P_DUN_FROM, hoechstens Hoechststufe - 2), geht es zum Eingang; dort werden die Quests
    -- angenommen, deren Geber am Eingang stehen (<= 400 yd), der Lauf dauert DUN_MIN Minuten und bringt Monster-EP wie
    -- Hauen; danach sind die Dungeon-Quests im Log erledigt (Abgabe plant der Planer wie sonst). Jeder Dungeon einmal.
    local DUN_MIN, DUN_FROM, DUN_XP = 60, 2, 1.0
    local dunDone = {}
    local DZ = GuildTripLeveling.dz or {}
    -- Dungeon-Quests gezielt abholen: steht ein Dungeon an (Stufe ab Mindeststufe - 1 bis Hoechststufe - 3, noch nicht
    -- gelaufen), werden seine Quests "ja" fuer den Planer (override), wenn ihr Geber auf dem Kontinent des Eingangs
    -- hoechstens DUN_GIVER_YD davon entfernt steht
    local DUN_GIVER_YD = 6000
    local ovCache, ovLevel
    function DunOverride()
        if not DUNGEONS or FOLLOW then return nil end   -- im Spiel (Folgen) gibt es keine solche Auswahl
        local cnt = 0
        for _ in pairs(log) do cnt = cnt + 1 end
        local room = (P.LOG_MAX or 35) - 6 - cnt   -- Platz im Questlog lassen
        if ovLevel == me.level and ovCache and room >= 0 then return ovCache end
        local ov = {}
        if room <= 0 then ovCache, ovLevel = ov, me.level return ov end
        local isDone = function(q) return done[q] == true end
        local isLog = function(q) return log[q] ~= nil end
        for key, c in pairs(CAT) do
            local ent = DG.EntranceData[key]
            if ent and not dunDone[key] and not (c.faction and c.faction ~= sc.fac) and me.level >= c.min - 1 and me.level <= c.max - 3 then
                local w = {World(ent[1], ent[2], ent[3])}
                for id, e in pairs(Q.q) do
                    if DZ[e[14] or 0] == key and not done[id] and (e[2] or 0) <= me.level + 2 and P.Fits(id, e, me, isDone, isLog) then
                        local g = e[6] and e[6][1] and Q.n[e[6][1]]
                        local gw = g and g[2] and {World(g[2], g[3] / 1000, g[4] / 1000)}
                        if gw and w[1] and gw[1] == w[1] and Dist(gw, w) <= DUN_GIVER_YD and room > 0 then ov[id] = "yes" room = room - 1 end
                    end
                end
            end
        end
        ovCache, ovLevel = ov, me.level
        return ov
    end
    function DungeonRuns(n)
        local byKey = {}
        for id, v in pairs(log) do
            local e = Q.q[id]
            local key = e and DZ[e[14] or 0]
            if key and v == "open" then byKey[key] = byKey[key] or {} table.insert(byKey[key], id) end
        end
        for key, ids in pairs(byKey) do
            local c, ent = CAT[key], DG.EntranceData[key]
            local ok = c and ent and not dunDone[key] and not (c.faction and c.faction ~= sc.fac)
            if ok and me.level > c.max then
                for _, id in ipairs(ids) do log[id] = nil end   -- zu spaet: aufgeben
                ok = false
            end
            if ok and me.level >= math.min(c.min + DUN_FROM, c.max - 2) then
                dunDone[key] = true
                ovCache = nil
                local w = {World(ent[1], ent[2], ent[3])}
                local from = Pos()
                if w[1] then
                    if w[1] == from[1] then t = t + math.min(Dist(from, w) * P.DETOUR / 7 / 60, 15) else t = t + 25 end
                    MoveTo(w, ent[1])
                end
                -- Quests am Eingang gleich mitnehmen
                local toks = {}
                for id, e in pairs(Q.q) do
                    if DZ[e[14] or 0] == key and not log[id] and not done[id] and (e[2] or 0) <= me.level and P.Fits(id, e, me, function(q) return done[q] == true end, function(q) return log[q] ~= nil end) then
                        local pre = true
                        if type(e[5]) == "table" and #e[5] > 0 then pre = false for _, p in ipairs(e[5]) do if done[p] then pre = true end end end
                        if type(e[9]) == "table" then for _, p in ipairs(e[9]) do if not done[p] then pre = false end end end
                        local g = e[6] and e[6][1] and Q.n[e[6][1]]
                        local gw = g and g[2] and {World(g[2], g[3] / 1000, g[4] / 1000)}
                        if pre and gw and gw[1] == w[1] and Dist(gw, w) <= 400 then
                            log[id] = "open" toks[#toks + 1] = "a" .. id ids[#ids + 1] = id acceptedAt[id] = n
                        end
                    end
                end
                for _, id in ipairs(ids) do toks[#toks + 1] = "o" .. id log[id] = "done" objAt[id] = n end
                local x0 = stats.xp
                t = t + DUN_MIN
                AddXP(DUN_MIN * P.GrindEPM(me.level) * (P.GRIND_REAL or .7) * DUN_XP)
                stats.dungeons = (stats.dungeons or 0) + 1
                if stats.route then
                    stats.route[#stats.route + 1] = {k = "dungeon", key = key, q = table.concat(toks, " "), l = me.level, step = n,
                        w = w[1] and w or nil, map = ent[1], m = ent[1], x = math.floor(ent[2] * 1000 + .5), y = math.floor(ent[3] * 1000 + .5),
                        min = DUN_MIN, g = stats.xp - x0}
                end
                Line(("%3d %6.1f min  St %2d  DUNGEON %s (%d Quests: %s)"):format(n, t, me.level, c.name or key, #ids, table.concat(toks, " ")))
            end
        end
    end
    stepNo = 0
    local lastHub
    for n = 1, maxSteps do
        stepNo = n
        local ctx = Ctx()
        PLANNER_DEBUG = os.getenv("SIM_DUMP") and tonumber(os.getenv("SIM_DUMP")) == n and (tonumber(os.getenv("SIM_DBG") or "1")) or nil
        local c0 = os.clock()
        plan = P:Plan(ctx)
        local dt = os.clock() - c0
        stats.planMax = math.max(stats.planMax or 0, dt)
        stats.planSum, stats.planN = (stats.planSum or 0) + dt, (stats.planN or 0) + 1
        if not plan or #plan.steps == 0 then
            -- nichts geplant: 10 min Monster hauen (wie ein Spieler, der wartet) und weiter
            local g = 10 * P.GrindEPM(me.level) * (P.GRIND_REAL or .7)
            t = t + 10
            AddXP(g)
            stats.idle = (stats.idle or 0) + 10
            -- in der Route vermerken (nicht ausgeliefert): die Stufe danach rechnet scripts/route_opt.lua mit
            if stats.route then stats.route[#stats.route + 1] = {k = "idle", g = g, l = me.level, step = n, map = me.mapID} end
            Line(("%3d %6.1f min  St %2d  (nichts geplant: 10 min Monster hauen)"):format(n, t, me.level))
            plan = nil
        else
        workZone = plan.workZone
        if os.getenv("SIM_DUMP") and tonumber(os.getenv("SIM_DUMP")) == n then
            for i, l in ipairs(plan.loops or {}) do print(("  Schleife %d: %s %.1f min %d EP  %.0f EP/min"):format(i, ZoneName(l.mapID), l.minutes, l.xp, l.epm)) end
            for i, k in ipairs(plan.orderKeys) do io.write(k, "@", plan.orderLoops[i], " ") end print()
            print("  Schwelle", plan.grind * plan.factor)
        end
        local tr = os.getenv("SIM_TRACE")
        if tr then
            local has = false
            for _, k in ipairs(plan.orderKeys) do if k == tr then has = true end end
            if has and not traced then
                traced = true
                print(("  [Schritt %d] erstmals im Plan: %s"):format(n, tr))
                for i, k in ipairs(plan.orderKeys) do io.write(k, "@", plan.orderLoops[i], " ") end print()
            end
        end
        local st = plan.steps[1]
        -- Umsortiert: der neue erste Halt stand im alten Plan, ist aber nicht der naechste offene alte Halt
        if oldKeys then
            local expect
            for _, k in ipairs(oldKeys) do if not executed[k] then expect = k break end end
            local first = plan.orderKeys[1]
            local inOld = false
            for _, k in ipairs(oldKeys) do if k == first then inOld = true end end
            -- etwas, das genau hier bereit ist, gleich mitnehmen, ist kein Umsortieren
            local fw
            if st.mapID and st.x then fw = {World(st.mapID, st.x, st.y)} elseif st.area then fw = st.area[1] end
            local pw = Pos()
            local here = fw and fw[1] == pw[1] and Dist(fw, pw) <= 350
            if first and expect and first ~= expect and inOld and not here then
                stats.reorder = stats.reorder + 1
                Line("      (umsortiert: erwartet " .. expect .. ", jetzt " .. first .. ")")
            end
        end
        oldKeys, executed = plan.orderKeys, {}
        levelAt[n] = me.level
        local from = Pos()
        -- Kippt der Plan unterwegs? (Spieltest 21.11.2026: Orgrimmar -> Zeppelin, am Turm ploetzlich "Verborgene
        -- Feinde"). Das Spiel plant alle G.MOVED_YARDS neu (mit festem Fahrplan) – hier alle 400 yd nachstellen.
        local function Kipp(dest)
            if os.getenv("SIM_NOKIPP") or not (dest and dest[1] == from[1]) then return end
            local d = Dist(from, dest)
            if d < 500 then return end
            local sm, sx, sy = me.mapID, me.x, me.y
            local expect = plan.orderKeys[1]
            for f = 400, d - 100, 400 do
                MoveTo({from[1], from[2] + (dest[2] - from[2]) * f / d, from[3] + (dest[3] - from[3]) * f / d})
                local p2 = P:Plan(Ctx())
                local k = p2 and p2.orderKeys[1]
                if k ~= expect then
                    stats.flip = (stats.flip or 0) + 1
                    Line(("      !! KIPPT UNTERWEGS nach %d yd: erwartet %s, jetzt %s"):format(f, tostring(expect), tostring(k)))
                    break
                end
            end
            me.mapID, me.x, me.y = sm, sx, sy
        end
        if st.kind == "travel" then
            local v = st.via
            local dw = v.kind == "flight" and v.from or v.dep
            if dw and dw[1] then Kipp(dw) end
        else
            local tw
            if st.area then
                local bd
                for _, a in ipairs(st.area) do if a[1] == from[1] and (not bd or Dist(a, from) < bd) then tw, bd = a, Dist(a, from) end end
            elseif st.mapID and st.x then tw = {World(st.mapID, st.x, st.y)} end
            if tw then Kipp(tw) end
        end
        local desc
        local lvlBefore = me.level
        local xpBefore = stats.xp
        -- Route aufzeichnen (Neubau 21.11.2026: feste Route statt Live-Planer): je ausgefuehrtem Schritt Art,
        -- Quests ("a12 t13"), NPC, erwartete Stufe; Reisen nicht (die Wegfuehrung findet den Weg selbst)
        if st.kind ~= "travel" then
            stats.route = stats.route or {}
            local r = {l = me.level, step = n}
            if #st.actions > 0 then
                local acts = {}
                for _, a in ipairs(st.actions) do acts[#acts + 1] = a.kind:sub(1, 1) .. a.id end
                r.q = table.concat(acts, " ")
                r.n = st.nr
            else
                r.k = st.kind
                if st.kind == "bind" then r.inn = st.inn
                elseif st.kind == "grind" then r.to = st.lvl
                elseif st.kind == "fp" then
                    r.fp = st.fpID
                    if st.mapID and st.x then r.m, r.x, r.y = st.mapID, math.floor(st.x * 1000 + .5), math.floor(st.y * 1000 + .5) end
                end
            end
            if r.q or r.k == "bind" or r.k == "grind" or r.k == "fp" then stats.route[#stats.route + 1] = r end
        end
        if st.kind == "travel" then
            if einzel then
                if einzel.n < 2 and not einzel.obj then
                    stats.einzel = (stats.einzel or 0) + 1
                    Line(("      !! EINZEL: %.0f m zu Fuss fuer %s (St %d)"):format(einzel.d * .9144, einzel.what, einzel.l))
                end
                einzel = nil
            end
            -- Reise + der Halt danach als ein Schritt
            local nx = plan.steps[2]
            local v = st.via
            local tw
            if nx then
                if nx.mapID and nx.x then tw = {World(nx.mapID, nx.x, nx.y)}
                elseif nx.area then tw = nx.area[1] end
            end
            if v.kind == "hearth" then
                stats.hearths = stats.hearths + 1
                hearthAt = t + 60
                t = t + P.HS_MIN
                MoveTo(home, home.map)
                desc = "Ruhestein/Port"
            elseif v.kind == "flight" then
                stats.flights = stats.flights + 1
                t = t + Dist(from, v.from) * P.DETOUR / 7 / 60 + Dist(v.from, v.to) * P.FLY_DETOUR / P.FLY_SPEED / 60 + P.FLY_EXTRA
                stats.walkYd = stats.walkYd + Dist(from, v.from)
                local zm
                for _, f in ipairs(lev.FLIGHTMASTERS) do if f[2] == v.to[1] and Dist({f[2], f[3], f[4]}, v.to) < 30 then zm = f[7] end end
                MoveTo(v.to, zm)
                desc = "Flug " .. (v.from.name or "?") .. " -> " .. (v.to.name or "?")
            else
                t = t + P.BOAT_MIN + 3
                if tw then MoveTo(tw) end
                desc = "Schiff"
            end
            Line(("%3d %6.1f min  St %2d  %-12s  %s"):format(n, t, me.level, ZoneName(me.mapID), desc))
            -- naechster Durchlauf plant vom Ankunftsort
        else
            -- Ziel des Schritts
            local tw
            if st.kind == "grind" then tw = from
            elseif st.area then
                local bd
                for _, a in ipairs(st.area) do if a[1] == from[1] and (not bd or Dist(a, from) < bd) then tw, bd = a, Dist(a, from) end end
                tw = tw or st.area[1]
            elseif st.mapID and st.x then tw = {World(st.mapID, st.x, st.y)}
            elseif st.world then tw = st.world end
            -- EINZEL: offener langer Fussweg – Arbeit am Ziel (dieser + folgende Halte < 300 yd) zaehlen
            if einzel and tw and tw[1] and (tw[1] ~= einzel.w[1] or Dist(tw, einzel.w) > 300) then
                if einzel.n < 2 and not einzel.obj then
                    stats.einzel = (stats.einzel or 0) + 1
                    Line(("      !! EINZEL: %.0f m zu Fuss fuer %s (St %d)"):format(einzel.d * .9144, einzel.what, einzel.l))
                end
                einzel = nil
            end
            if st.kind == "grind" and (st.work or 0) > (P.ROUTE_GRIND_MAX or 10) then
                stats.grindLong = (stats.grindLong or 0) + 1
                stats.grindMax = math.max(stats.grindMax or 0, st.work)
                Line(("      !! HAUEN: %.0f min am Stueck (St %d)"):format(st.work, me.level))
            end
            if tw and tw[1] then
                local d = tw[1] == from[1] and Dist(from, tw) or 0
                if d > 1640 and #st.actions > 0 then
                    local what = {}
                    for _, a in ipairs(st.actions) do what[#what + 1] = a.kind:sub(1, 1) .. a.id end
                    einzel = {w = tw, d = d, n = 0, obj = false, l = me.level, what = table.concat(what, " ")}
                end
                if einzel then
                    for _, a in ipairs(st.actions) do einzel.n = einzel.n + 1 if a.kind == "obj" then einzel.obj = true end end
                end
                stats.walkYd = stats.walkYd + d
                t = t + d * P.DETOUR / 7 / 60
                local m0 = me.mapID
                MoveTo(tw, st.mapID)
                -- Hauptstadt hinein/hinaus (Aufzuege, Ringe) wie im Planer
                if m0 ~= me.mapID then t = t + (P.CITY_IN[m0] or 0) + (P.CITY_IN[me.mapID] or 0) end
            end
            -- Rueckweg: hier schon einmal gewesen (danach > 1000 yd weg) und haette ALLES dieses Besuchs schon damals
            -- erledigen koennen (kommt man ohnehin fuer etwas Neues zurueck, ist Mitnehmen kein Rueckweg)
            local here0 = Pos()
            if visit and (visit.w[1] ~= here0[1] or Dist(visit.w, here0) > 250) then
                if visit.all and visit.ret then
                    stats.returns = stats.returns + 1
                    Line("      !! RÜCKWEG: an diesem Ort ging schon früher alles (" .. visit.ret .. ")")
                end
                visit = nil
            end
            local ret
            for i = #visits, 1, -1 do
                local v = visits[i]
                if v.w[1] == here0[1] and Dist(v.w, here0) < 250 then
                    local far = 0
                    for j = i + 1, #visits do if visits[j].w[1] == here0[1] then far = math.max(far, Dist(visits[j].w, here0)) else far = 1e9 end end
                    if far > 1000 then ret = v end
                    break
                end
            end
            if not visit then visit = {w = here0, all = true, ret = nil, earlier = ret} end
            for _, a in ipairs(st.actions) do
                if visit.earlier and CouldAt(a, visit.earlier.n) then visit.ret = a.kind .. " " .. a.id
                else visit.all = false end
            end
            if #st.actions == 0 then visit.all = false end
            local acts = {}
            for _, a in ipairs(st.actions) do
                executed[a.kind .. ":" .. a.id] = true
                if a.kind == "accept" then acceptedAt[a.id] = n if #(Q.q[a.id][8] or {}) == 0 then objAt[a.id] = n end
                elseif a.kind == "obj" then objAt[a.id] = n
                elseif a.kind == "turnin" then doneAt[a.id] = n end
                local e = Q.q[a.id]
                if a.kind == "accept" then
                    log[a.id] = (#(e[8] or {}) == 0) and "done" or "open"
                    t = t + .2
                elseif a.kind == "obj" then
                    local o = plan.info[a.id]
                    local work = o and o.work or 0
                    t = t + work * P.KILL_SEC / 60
                    AddXP(work * (o and o.mobXP or 0))
                    log[a.id] = "done"
                elseif a.kind == "turnin" then
                    local qlvl = e[1] > 0 and e[1] or me.level
                    AddXP((P.QuestXP(e[11] or 0, qlvl, me.level)))
                    done[a.id], log[a.id] = true, nil
                    stats.quests = stats.quests + 1
                    t = t + .2
                end
                acts[#acts + 1] = a.kind:sub(1, 1) .. a.id
            end
            if st.kind == "grind" then
                t = t + (st.work or 0)
                AddXP(st.xp or 0)
                stats.grind, stats.grindMin = stats.grind + 1, stats.grindMin + (st.work or 0)
                acts[#acts + 1] = ("Monster hauen %d EP (%.0f min)"):format(st.xp or 0, st.work or 0)
            elseif st.kind == "dungeon" then
                for _, id in ipairs(st.ids or {}) do if log[id] then log[id] = "done" objAt[id] = n end end
                t = t + 60
                AddXP(60 * P.GrindEPM(me.level) * (P.GRIND_REAL or .7))
                stats.dungeons = (stats.dungeons or 0) + 1
                acts[#acts + 1] = "Dungeon " .. tostring(st.key)
            elseif st.kind == "train" then trainedAt = me.level t = t + P.TRAIN_MIN acts[#acts + 1] = "Lehrer"
            elseif st.kind == "fp" then
                for _, f in ipairs(lev.FLIGHTMASTERS) do
                    if tw and f[2] == tw[1] and Dist({f[2], f[3], f[4]}, tw) < 60 then
                        known[f[1]] = true
                        local lr = stats.route and stats.route[#stats.route]
                        if lr and lr.step == n then lr.fpID = f[1] end
                    end
                end
                acts[#acts + 1] = "Flugpunkt"
            elseif st.kind == "bind" then
                for _, inn in ipairs(inns) do if inn.id == st.inn then home = {inn[1], inn[2], inn[3], inn = inn.id, place = inn.name} end end
                acts[#acts + 1] = "Ruhestein setzen"
            elseif st.kind == "vendor" then
                acts[#acts + 1] = "Händler"
                t = t + .5
            end
            if st.stopKey then executed[st.stopKey] = true end
            local here = Pos()
            do local lr = stats.route and stats.route[#stats.route] if lr and lr.step == n then lr.w, lr.map, lr.g = here, me.mapID, stats.xp - xpBefore end end
            local isHubWork = true
            local mark = ""

            -- Hin und Her zwischen groben Orten: A -> B -> A, A/B > 1500 yd auseinander, in B kaum etwas getan
            local spot = {here[1], here[2], here[3], n = n, t = t}
            local last = hubTrail[#hubTrail]
            if not last or last[1] ~= here[1] or Dist(last, here) > 1500 then
                local prev = hubTrail[#hubTrail - 1]
                if prev and last and prev[1] == here[1] and Dist(prev, here) < 400 and (t - last.t) < 6 then
                    stats.pingpong = stats.pingpong + 1
                    mark = mark .. "  !! HIN-UND-HER"
                end
                hubTrail[#hubTrail + 1] = spot
            else last.t = t end
            visits[#visits + 1] = {w = here, n = n, hub = isHubWork}
            local zn = ZoneName(me.mapID)
            stats.zones[zn] = (stats.zones[zn] or 0) + 1
            -- HARTE PRUEFUNGEN (Spielmeldungen 21.11.2026): Besuch eines Gebiets/einer Stadt fuer nur eine Quest
            -- (Grenzorte < 800 yd vom vorigen Gebiet zaehlen nicht), Ruhestein in der Hauptstadt
            do
                local seg = stats.seg
                if not seg or seg.map ~= me.mapID then
                    if seg and seg.n <= 1 and seg.far and not seg.spell then
                        local city = Z[seg.map] and Z[seg.map].city
                        stats.hard = (stats.hard or 0) + 1
                        Line(("      !! PRUEFUNG: %s nur fuer %s (%s)"):format(ZoneName(seg.map), seg.what or "?", city and "Stadt" or "Gebiet"))
                    end
                    local far = not seg or not seg.last or seg.last[1] ~= here[1] or Dist(seg.last, here) > 800
                    seg = {map = me.mapID, n = 0, ids = {}, far = far}
                    stats.seg = seg
                end
                for _, a in ipairs(st.actions) do
                    if not seg.ids[a.id] then seg.ids[a.id] = true seg.n = seg.n + 1 seg.what = a.kind .. " " .. a.id end
                    if (GuildTripLeveling.sp or {})[a.id] then seg.spell = true end
                end
                if st.kind == "grind" or st.kind == "bind" or st.kind == "fp" then seg.n = seg.n + 1 end
                seg.last = here
                if st.kind == "bind" and Z[me.mapID] and Z[me.mapID].city then
                    stats.hard = (stats.hard or 0) + 1
                    Line("      !! PRUEFUNG: Ruhestein in der Hauptstadt")
                end
            end
            -- Gebietswechsel (ohne Hauptstaedte) und Rueckkehr in ein Gebiet, das man vor < 3 Stufen verlassen hat
            -- (nur Annehmen/Abgeben zaehlt: Questgeber stehen im Gebiet; Ziele liegen oft an der Grenze)
            local gz = (st.kind == "accept" or st.kind == "turnin") and st.mapID
            if gz and not (Z[gz] and Z[gz].city) then
                if curZ and curZ ~= gz then
                    stats.switches = (stats.switches or 0) + 1
                    leftAt[curZ] = me.level
                    if leftAt[gz] and me.level < leftAt[gz] + 3 then
                        stats.zoneBack = (stats.zoneBack or 0) + 1
                        mark = mark .. "  !! ZURÜCK INS GEBIET"
                    end
                end
                curZ = gz
            end
            local lp = st.loop and plan.loops and plan.loops[st.loop]
            if lp and lp.pass and lp.pass > 1 then mark = mark .. (lp.pass == 3 and "  [weit]" or "  [schwach]") end
            Line(("%3d %6.1f min  St %2d  %-12s  %-6s %5d yd  %s%s%s"):format(n, t, me.level, zn, st.kind,
                tw and tw[1] == from[1] and math.floor(Dist(from, tw)) or 0, table.concat(acts, " "),
                me.level > lvlBefore and ("  -> Stufe " .. me.level) or "", mark))
        end
        end
        if DUNGEONS and not FOLLOW then DungeonRuns(n) end
        local cnt = 0 for _ in pairs(log) do cnt = cnt + 1 end
        stats.logMax = math.max(stats.logMax, cnt)
        stats.steps = n
        -- mit 60 ist die Route fertig (danach geplante Schritte braucht niemand)
        if me.level >= 60 then break end
    end
    stats.minutes = t
    stats.level, stats.xpLeft = me.level, me.xp
    -- Route nachpolieren (wie ein Leitfaden von Hand, 22.11.2026): kommt die Route an einen Ort nur zurueck, um
    -- Quests anzunehmen, die dort schon beim frueheren Besuch moeglich waren, wandern die Annahmen nach vorn
    do
        local route = stats.route or {}
        local moved = 0
        for i = 2, #route do
            local r = route[i]
            if r.q and r.w and not r.q:find("[ot]") then
                local keep = {}
                for id in r.q:gmatch("a(%d+)") do
                    id = tonumber(id)
                    local target
                    -- nur innerhalb desselben Aufenthalts im Gebiet (kein Gebietswechsel dazwischen), sonst nimmt
                    -- man an und reist weg (Nachstellung 22.11.2026: Eschental -> Daemmerwald)
                    local from = i
                    while from > 1 and route[from - 1].map == r.map do from = from - 1 end
                    for j = from, i - 1 do
                        local e = route[j]
                        if e.q and e.w and e.w[1] == r.w[1] and Dist(e.w, r.w) <= 80 and CouldAt({kind = "accept", id = id}, e.step) then
                            target = e break
                        end
                    end
                    if target then target.q = target.q .. " a" .. id moved = moved + 1
                    else keep[#keep + 1] = "a" .. id end
                end
                r.q = #keep > 0 and table.concat(keep, " ") or nil
            end
        end
        local out = {}
        for _, r in ipairs(route) do if r.q or r.k then out[#out + 1] = r end end
        stats.route = out
        stats.moved = moved
        -- uebrig: Besuche nur zum Annehmen an einem Ort, an dem man schon war (Annahme dort vorher nicht moeglich)
        local rest = 0
        for i, r in ipairs(out) do
            if r.q and r.w and not r.q:find("[ot]") then
                for j = 1, i - 1 do
                    local e = out[j]
                    if e.w and e.w[1] == r.w[1] and Dist(e.w, r.w) <= 80 and i - j > 3 then rest = rest + 1 break end
                end
            end
        end
        stats.revisit = rest
        -- Questlog entlang der polierten Route: hoechstens wie viele gleichzeitig?
        local open, maxLog = {}, 0
        local cnt = 0
        for _, r in ipairs(out) do
            for k, id in (r.q or ""):gmatch("(%a)(%d+)") do
                id = tonumber(id)
                if k == "a" and not open[id] then open[id] = true cnt = cnt + 1
                elseif k == "t" and open[id] then open[id] = nil cnt = cnt - 1 end
            end
            if cnt > maxLog then maxLog = cnt end
        end
        stats.routeLog = maxLog
        if verbose then print("  NACHPOLIERT: " .. moved .. " Annahmen nach vorn, Rest-Besuche nur zum Annehmen " .. rest .. ", Log hoechstens " .. stats.routeLog) end
    end

    -- Ganze Route auf einmal ueberarbeiten (Neubau 23.11.2026, scripts/route_opt.lua): Bloecke und ganze Besuche eines
    -- Bereichs wandern an die Stelle mit dem kuerzesten Weg, Annehmen/Abgeben gehen zum naechsten Besuch beim selben
    -- NPC mit, leere Schritte entfallen. Harte Regeln wie im Spiel (annehmen < Ziel < abgeben, Vorquests, Stufen, Log).
    -- Ersparte Wegzeit zaehlt in "bis60". SIM_NOOPT=1 schaltet es ab (Vergleich).
    -- SIM_RAW=<datei>: Route vor dem Ueberarbeiten speichern (zum Nachrechnen mit scripts/route_opt.lua)
    if os.getenv("SIM_RAW") then
        local fh = assert(io.open(os.getenv("SIM_RAW"), "w"))
        local function V(v)
            if type(v) == "table" then local p = {} for _, x in ipairs(v) do p[#p + 1] = V(x) end return "{" .. table.concat(p, ",") .. "}" end
            return type(v) == "string" and ("%q"):format(v) or tostring(v)
        end
        fh:write("return {sc = {level = ", sc.level, "}, home0 = {", table.concat({World(sc.home[1], sc.home[2], sc.home[3])}, ","), "}, known0 = {")
        for k in pairs(known0) do fh:write("[", k, "]=true,") end
        fh:write("}, route = {\n")
        for _, r in ipairs(stats.route or {}) do
            local p = {}
            for k, v in pairs(r) do p[#p + 1] = k .. "=" .. V(v) end
            fh:write("{", table.concat(p, ","), "},\n")
        end
        fh:write("}}\n")
        fh:close()
    end
    if not os.getenv("SIM_NOOPT") then
        local fps = {}
        for _, f in ipairs(lev.FLIGHTMASTERS) do if Mine(f[5]) then fps[#fps + 1] = {f[2], f[3], f[4], id = f[1]} end end
        local startXP = 0
        for l = 1, sc.level - 1 do startXP = startXP + (XP_NEED[l] or 0) end
        local opt = dofile(root:gsub("src$", "scripts") .. "/route_opt.lua")
        local c0 = os.clock()
        local out, info = opt.Run(stats.route or {}, {Q = Q, P = P, XP_NEED = XP_NEED, startXP = startXP, fps = fps,
            known0 = known0, home0 = {World(sc.home[1], sc.home[2], sc.home[3])}, world = World, verbose = verbose, passes = tonumber(os.getenv("SIM_OPT_PASSES") or "6")})
        stats.route = out
        stats.optSaved, stats.optMoves = info.saved, info.moves
        -- weniger EP (Quests spaeter mit hoeherer Stufe abgegeben): fehlende EP am Ende mit Monster hauen
        local extra = info.xpDiff < 0 and -info.xpDiff / (P.GrindEPM(59) * (P.GRIND_REAL or .7)) or 0
        stats.optExtra = extra
        if stats.t60 then stats.t60 = stats.t60 - info.saved + extra end
        io.stderr:write(("  GESAMT: %d Verschiebungen, %d Ziele verlegt, Zeitquests %d umgestellt/%d raus, %d ohne Abgabe raus, %d Besuche gespart, %d Schritte weniger, %.0f min Weg gespart, EP %+d (%.0f min Hauen), %.0f s%s")
            :format(info.moves, info.objMoves or 0, info.timedFixed or 0, #(info.timedRemoved or {}), #(info.noTurn or {}), info.tokMoves or 0, info.removed or 0, info.saved, info.xpDiff or 0, extra, os.clock() - c0, info.skipped and (" (Ausgangsroute ungueltig, unveraendert: " .. tostring(info.why) .. " q" .. tostring(info.id) .. " " .. tostring(info.p) .. ")") or "") .. "\n")
    end
    -- Ziele in mehreren Gebieten (Spieltest 22.11.2026, "Chens leeres Faesschen": Loewen und Ebenenschreiter im
    -- Norden, Donnerechsen im Sueden – wie ein Leitfaden je Gebiet einen eigenen Schritt): jede Zielgruppe der Quest
    -- (Gegner/Gegenstand/Objekt) bekommt zwischen Annehmen und Abgeben die Stelle der Route, die ueber ihren naechsten
    -- Spawnpunkt am wenigsten Umweg kostet. Landen alle an derselben Stelle, bleibt es ein Schritt "o821"; sonst je
    -- Stelle ein Teil "o821.1", "o821.2" … mit p = seinen Ziel-Knoten (im Spiel gilt der erste Teil mit offenen
    -- Zielen, Guide.RouteFollow). Weit verteilte Gegner (Loewen ueberall im Brachland) kommen dorthin, wo man ohnehin ist.
    do
        local route = stats.route or {}
        local function Points(nodes)
            local pts = {}
            for _, nr in ipairs(nodes) do
                local nd = Q.n and Q.n[nr]
                for i = 2, #(nd or {}), 3 do
                    local c, x, y = World(nd[i], nd[i + 1] / 1000, nd[i + 2] / 1000)
                    if c then pts[#pts + 1] = {c, x, y, m = nd[i], nr = nr} end
                end
            end
            return pts
        end
        local function Groups(id)
            local od = Q.obj and Q.obj[id]
            if not od then return nil end
            local groups = {}
            for _, kind in ipairs({"m", "i", "o"}) do
                for _, g in ipairs(od[kind] or {}) do
                    if #g > 0 then
                        local pts = Points(g)
                        if #pts == 0 then return nil end
                        groups[#groups + 1] = {nodes = g, pts = pts}
                    end
                end
            end
            return #groups >= 2 and groups or nil
        end
        local function Has(r, k, id) return r.q and (" " .. r.q .. " "):find(" " .. k .. id .. " ", 1, true) end
        -- beste Stelle k (Einfuegen vor route[k]) in ia+1 .. it fuer eine Gruppe, ohne den Halt bei skip
        -- Einfuegestellen k innerhalb des Fensters einer anderen Zeitquest (Annehmen < k <= Abgeben) sind tabu – der
        -- Optimierer hat dieses Fenster knapp geplant (harte Pruefung ZEIT)
        local function TimedInside(id)
            local bad, open = {}, {}
            for j, x in ipairs(route) do
                for k, t in (x.q or ""):gmatch("(%a)(%d+)") do
                    t = tonumber(t)
                    if t ~= id and Q.timed and Q.timed[t] then
                        if k == "a" and not open[t] then open[t] = j end
                        if k == "t" and open[t] then for q = open[t] + 1, j do bad[q] = true end open[t] = nil end
                    end
                end
            end
            return bad
        end
        local function Best(g, ia, it, skip, bad)
            local bd, bk, bp
            for k = ia + 1, it do
                local a
                if not bad[k] then
                    for q = k - 1, 1, -1 do if q ~= skip and route[q].w then a = route[q].w break end end
                end
                local nb = k
                if nb == skip then nb = nb + 1 end
                local b = route[nb] and route[nb].w
                if a then
                    for _, p in ipairs(g.pts) do
                        if p[1] == a[1] then
                            local d = Dist(a, p) + ((b and b[1] == p[1]) and (Dist(p, b) - Dist(a, b)) or 0)
                            if not bd or d < bd - 1 then bd, bk, bp = d, k, p end
                        end
                    end
                end
            end
            return bk, bp
        end
        local split = 0
        local i = 1
        while i <= #route do
            local r = route[i]
            local did = false
            for id in (r.q or ""):gmatch("o(%d+)") do
                id = tonumber(id)
                local groups = not did and r.k ~= "dungeon" and Has(r, "o", id) and Groups(id)
                if groups then
                    local ia, it = 0, #route + 1
                    for k = i, 1, -1 do if Has(route[k], "a", id) then ia = k break end end
                    for k = i, #route do if Has(route[k], "t", id) then it = k break end end
                    -- je Gruppe die beste Stelle; der eigene Ziel-Halt (i) zaehlt nicht als Nachbar
                    local slots, order = {}, {}
                    local bad = TimedInside(id)
                    for _, g in ipairs(groups) do
                        local k, p = Best(g, math.max(ia, 0), it, i, bad)
                        if not k then slots = nil break end
                        -- an der Stelle des alten Ziel-Halts (direkt davor/danach) = dort bleiben
                        if k == i or k == i + 1 then k = i end
                        if not slots[k] then slots[k] = {nodes = {}, p = p} order[#order + 1] = k end
                        for _, nr in ipairs(g.nodes) do slots[k].nodes[#slots[k].nodes + 1] = nr end
                    end
                    if slots and #order >= 2 then
                        local toks = {}
                        for tok in r.q:gmatch("%S+") do if tok ~= "o" .. id then toks[#toks + 1] = tok end end
                        table.sort(order)
                        -- Teile dicht beieinander (MERGE_YD) sind ein Schritt: an die fruehere Stelle
                        local MERGE_YD = 600
                        local m = 2
                        while m <= #order do
                            local into
                            for q = 1, m - 1 do
                                local pa, pb = slots[order[q]].p, slots[order[m]].p
                                if pa[1] == pb[1] and Dist(pa, pb) <= MERGE_YD then into = order[q] break end
                            end
                            if into then
                                for _, nr in ipairs(slots[order[m]].nodes) do table.insert(slots[into].nodes, nr) end
                                slots[order[m]] = nil
                                table.remove(order, m)
                            else m = m + 1 end
                        end
                        -- Teile in Routen-Reihenfolge nummerieren, von hinten einfuegen (Indizes bleiben gueltig)
                        local entries = {}
                        if #order >= 2 then split = split + 1 did = true else order = {} end
                        for pn, k in ipairs(order) do
                            local sl = slots[k]
                            entries[pn] = {k = k, e = {q = ("o%d.%d"):format(id, pn), n = sl.p.nr, l = (route[k - 1] or r).l,
                                map = sl.p.m, w = {sl.p[1], sl.p[2], sl.p[3]}, p = sl.nodes}}
                        end
                        if #order > 0 then r.q = #toks > 0 and table.concat(toks, " ") or nil end
                        for pn = #entries, 1, -1 do
                            local en = entries[pn]
                            -- Halt hat noch andere Quests: eigener Schritt danach – gibt man dort aber diese Quest ab, davor
                            local before = en.k == i and #toks > 0 and Has(r, "t", id)
                            if en.k == i and #toks > 0 and not before then en.k = i + 1 end
                            if before then
                                table.insert(route, i, en.e)
                                i = i + 1
                            elseif en.k == i then
                                -- am alten Halt: ihn selbst zum Teil machen (Lage/Knoten des Teils)
                                r.q = r.q and (r.q .. " " .. en.e.q) or en.e.q
                                r.p, r.n, r.map, r.w = en.e.p, en.e.n, en.e.map, en.e.w
                            else
                                table.insert(route, en.k, en.e)
                                if en.k <= i then i = i + 1 end
                            end
                        end
                    end
                end
            end
            if not route[i].q and not route[i].k then table.remove(route, i) else i = i + 1 end
        end
        stats.route = route
        if verbose then print("  ZIELE GETEILT: " .. split .. " Quests mit Zielen in mehreren Gebieten") end
    end
    -- SIM_RECORD=<datei>: aufgezeichnete Route als Lua-Tabelle schreiben (scripts/build_routes.sh)
    if os.getenv("SIM_RECORD") then
        local fh = assert(io.open(os.getenv("SIM_RECORD"), "w"))
        fh:write("return {\n")
        for _, r in ipairs(stats.route or {}) do
            local parts = {}
            if r.q then parts[#parts + 1] = ("%q"):format(r.q) end
            r.z = r.map
            r.fp = r.fp or r.fpID
            if r.k == "idle" then parts = nil end   -- (nach scripts/route_opt.lua: als "grind" mit Minuten)
            for _, k in ipairs(parts and {"k", "key", "n", "l", "z", "inn", "fp", "to", "min", "m", "x", "y"} or {}) do
                if r[k] ~= nil then parts[#parts + 1] = k .. "=" .. (type(r[k]) == "string" and ("%q"):format(r[k]) or tostring(r[k])) end
            end
            if parts then
                if r.p then parts[#parts + 1] = "p={" .. table.concat(r.p, ",") .. "}" end
                fh:write("{", table.concat(parts, ","), "},\n")
            end
        end
        fh:write("}\n")
        fh:close()
    end
    -- PRUEFUNG "gute Quest ausgelassen" (Nutzer 21.11.2026: "wichtig ist nur, dass keine guten Quests ausgelassen
    -- werden"): passt zu Volk/Klasse, Stufe <= erreichte Stufe - 3, keine Gruppe/Dungeon/Beruf, Gebiet wurde besucht,
    -- Vorquests erledigt, lohnt bei ihrer Stufe (EP/min >= Monster hauen) – aber nie angenommen
    do
        local visited = {}
        for zn in pairs(stats.zones) do visited[zn] = true end
        local miss = {}
        local R = GuildTripLeveling
        for id, e in pairs(Q.q) do
            local ql = e[1] or 0
            if ql > 0 and ql <= me.level - 3 and not done[id] and not acceptedAt[id] and type(e[7]) == "table" and e[7][1] then
                local past = {level = math.max(ql, e[2] or 1), class = me.class, race = me.race, faction = me.faction}
                local ok = P.Fits(id, e, past, function(p) return done[p] == true end, function() return false end)
                -- Vorquests erledigt (eine von e[5], alle von e[9]) – sonst kam man gar nicht an die Quest
                if ok and type(e[5]) == "table" and #e[5] > 0 then
                    local any = false
                    for _, p in ipairs(e[5]) do if done[p] then any = true end end
                    ok = any
                end
                if ok and type(e[9]) == "table" then for _, p in ipairs(e[9]) do if not done[p] then ok = false end end end
                local rew = P.Rew(R, id)
                local kind = rew and rew[3] or 0
                local work = rew and rew[2] or 0
                if ok and kind == 0 and not e[15] then
                    local zoneOf
                    local g = Q.n[(e[6] or {})[1] or 0]
                    if g then zoneOf = ZoneName(g[2]) end
                    local xp = P.QuestXP(e[11] or 0, ql, ql)
                    local mins = 2 + work * P.KILL_SEC / 60
                    -- Wege der Quest selbst: Geber -> Ziel -> Abgabe (Botengaenge in eine andere Stadt sind nicht "gut")
                    local function W(nr) local n = Q.n[nr or 0] if n then local c, x, y = World(n[2], n[3] / 1000, n[4] / 1000) if c then return {c, x, y} end end end
                    local a, t, b = W((e[6] or {})[1]), W((e[8] or {})[1]), W((e[7] or {})[1])
                    local path, prev = 0, a
                    for _, w in ipairs({t or false, b or false}) do
                        if w and prev then path = path + (w[1] == prev[1] and Dist(prev, w) * P.DETOUR / 7 / 60 or 15) prev = w end
                    end
                    mins = mins + path
                    if zoneOf and visited[zoneOf] and xp / mins >= P.GrindEPM(ql) then
                        miss[#miss + 1] = ("%d(St%d %s %.0fEP/min)"):format(id, ql, zoneOf, xp / mins)
                    end
                end
            end
        end
        stats.missed = #miss
        table.sort(miss)
        stats.missList = miss
        if verbose then print("  AUSGELASSEN (" .. #miss .. "): " .. table.concat(miss, " ")) end
    end
    return stats
end

if customScen then SCEN[#SCEN + 1] = customScen end
local total = {returns = 0, pingpong = 0, reorder = 0}
local t0 = os.clock()
for _, sc in ipairs(SCEN) do
    if want == "alle" or want == sc.key or sc.key:find(want, 1, true) then
        if verbose then print("== " .. sc.key) end
        local s = Run(sc)
        local zl = {}
        for z, c in pairs(s.zones) do zl[#zl + 1] = z .. " " .. c end
        table.sort(zl)
        print(("%-17s %3d Schr. %5.0f min  bis60 %s  St %d->%d  %6d EP/h  %3d Quests  Rückweg %d  Hin-Her %d  Umsort. %d  Kippt %d  PRUEF %d  Ausgel. %d  Flüge %d  RS %d  Hauen %d (%.0f min, >10: %d, max %.0f)  Einzel %d  Log max %d  Leer %d min  Gebietswechsel %d (zurück %d)  Planen Ø %d ms max %d ms | %s")
            :format(sc.key, s.steps, s.minutes, s.t60 and ("%.0f"):format(s.t60) or "-", s.startLevel, s.level, math.floor(s.xp / math.max(1, s.minutes) * 60), s.quests,
                s.returns, s.pingpong, s.reorder, s.flip or 0, s.hard or 0, s.missed or 0, s.flights, s.hearths, s.grind, s.grindMin, s.grindLong or 0, s.grindMax or 0, s.einzel or 0, s.logMax, s.idle or 0, s.switches or 0, s.zoneBack or 0, (s.planSum or 0) / math.max(1, s.planN or 1) * 1000, (s.planMax or 0) * 1000, table.concat(zl, ", ")))
        total.returns, total.pingpong, total.reorder = total.returns + s.returns, total.pingpong + s.pingpong, total.reorder + s.reorder
        total.flip = (total.flip or 0) + (s.flip or 0)
    end
end
print(("SUMME Rückwege %d, Hin-und-Her %d, Umsortiert %d, Kippt unterwegs %d  (%.0f s)"):format(total.returns, total.pingpong, total.reorder, total.flip or 0, os.clock() - t0))
