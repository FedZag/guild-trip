-- Import: Questdaten aus pfQuest (MIT, Daten aus VMaNGOS) -> src/ONE_QuestDB (kompakt, nur was Guild Trip braucht).
--
--   git clone --depth 1 https://github.com/shagu/pfQuest.git <ordner>
--   lua5.1 scripts/import_pfquest.lua <ordner> [ziel=src/ONE_QuestDB]
--
-- Die pfQuest-Dateien sind reine Datentabellen; sie werden in einer leeren Umgebung geladen
-- (kein Zugriff auf os/io). Ergebnis:
--   Data.lua         GuildTripQuestDB.q  [questID] = {stufe, mindeststufe, volk, klasse, vorquests, geber, abgabe, ziele}
--                    GuildTripQuestDB.n  [nr] = {fraktion, karte, x, y, karte, x, y, …}  (nr > 0 NPC, nr < 0 Objekt)
--   Names_deDE.lua / Names_enUS.lua   Questtitel und NPC-/Objektnamen
-- Koordinaten: Promille (0–1000) auf der WoW-Karte (uiMapID), nur Gebiete der offenen Welt.
local src, dest = arg[1], arg[2] or "src/ONE_QuestDB"
assert(src, "Aufruf: lua5.1 scripts/import_pfquest.lua <pfQuest-Ordner> [Ziel]")
local db = src .. "/db/"

-- Commit fuer THIRD_PARTY.md / Quelle
local commit = "?"
do
    local h = io.popen("git -C '" .. src:gsub("'", "") .. "' log -1 --format='%h %ad' --date=short 2>/dev/null")
    if h then commit = h:read("*l") or "?" h:close() end
end

local function Load(file)
    local env = {}
    env.pfDB = setmetatable({}, {__index = function(t, k) local v = {} rawset(t, k, v) return v end})
    local chunk = assert(loadfile(db .. file))
    setfenv(chunk, env)
    chunk()
    return env.pfDB
end

-- AreaTable-Gebiet (pfQuest) -> uiMapID (WoW-Karte, Classic)
local ZONE = {
    [14] = 1411, [215] = 1412, [17] = 1413, [36] = 1416, [45] = 1417, [3] = 1418, [4] = 1419, [85] = 1420,
    [130] = 1421, [28] = 1422, [139] = 1423, [267] = 1424, [47] = 1425, [1] = 1426, [51] = 1427, [46] = 1428,
    [12] = 1429, [41] = 1430, [10] = 1431, [38] = 1432, [44] = 1433, [33] = 1434, [8] = 1435, [40] = 1436,
    [11] = 1437, [141] = 1438, [148] = 1439, [331] = 1440, [400] = 1441, [406] = 1442, [405] = 1443, [357] = 1444,
    [15] = 1445, [440] = 1446, [16] = 1447, [361] = 1448, [490] = 1449, [493] = 1450, [1377] = 1451, [618] = 1452,
    [1519] = 1453, [1637] = 1454, [1537] = 1455, [1638] = 1456, [1657] = 1457, [1497] = 1458,
}

local quests = Load("quests.lua").quests.data
local units = Load("units.lua").units.data
local objects = Load("objects.lua").objects.data
local items = Load("items.lua").items.data
local names = {}
for _, loc in ipairs({"deDE", "enUS"}) do
    names[loc] = {
        q = Load(loc .. "/quests.lua").quests[loc],
        u = Load(loc .. "/units.lua").units[loc],
        o = Load(loc .. "/objects.lua").objects[loc],
    }
end

local FAC = {A = 1, H = 2, AH = 3, HA = 3}
local nodes, nodeLimit = {}, {}  -- nr -> {fac, coords…}; Grenze je Verwendung (Geber 5, Ziele 12)

-- Koordinaten einer Einheit/eines Objekts uebernehmen (nur bekannte Gebiete), hoechstens limit Punkte,
-- bevorzugt im Gebiet mit den meisten Punkten
local function AddNode(nr, limit)
    local src = nr > 0 and units[nr] or objects[-nr]
    if not src or type(src.coords) ~= "table" then return false end
    if nodes[nr] and (nodeLimit[nr] or 0) >= limit then return true end
    local byZone, best, bestN = {}, nil, 0
    for _, c in ipairs(src.coords) do
        local m = ZONE[c[3]]
        if m and c[1] and c[2] then
            byZone[m] = byZone[m] or {}
            table.insert(byZone[m], {math.floor(c[1] * 10 + .5), math.floor(c[2] * 10 + .5)})
            if #byZone[m] > bestN then best, bestN = m, #byZone[m] end
        end
    end
    if not best then return false end
    local out = {FAC[src.fac or ""] or 0}
    local function Take(m, list, max)
        local step = math.max(1, #list / max)
        local i = 1
        while i <= #list and max > 0 do
            local p = list[math.floor(i)]
            out[#out + 1], out[#out + 2], out[#out + 3] = m, p[1], p[2]
            i, max = i + step, max - 1
        end
    end
    Take(best, byZone[best], limit)
    -- weitere Gebiete nur mit je einem Punkt (z. B. NPC in zwei Staedten)
    for m, list in pairs(byZone) do if m ~= best then Take(m, list, 1) end end
    nodes[nr], nodeLimit[nr] = out, limit
    return true
end

local function Ids(t) -- {U = {...}, O = {...}} -> Liste (NPC +, Objekt -)
    local out = {}
    if type(t) ~= "table" then return out end
    for _, u in ipairs(t.U or {}) do out[#out + 1] = u end
    for _, o in ipairs(t.O or {}) do out[#out + 1] = -o end
    return out
end
local function Unique(list)
    local seen, out = {}, {}
    for _, v in ipairs(list) do if not seen[v] then seen[v] = true out[#out + 1] = v end end
    return out
end

-- Gegenstand -> beste Quellen (hoechste Fundchance), hoechstens 3
local function ItemSources(itemID)
    local it = items[itemID]
    if type(it) ~= "table" then return {} end
    local list = {}
    for u, chance in pairs(it.U or {}) do list[#list + 1] = {u, chance} end
    for o, chance in pairs(it.O or {}) do list[#list + 1] = {-o, chance} end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    local out = {}
    for i = 1, math.min(3, #list) do out[i] = list[i][1] end
    return out
end

local q, kept, skipped = {}, 0, 0
local ids = {}
for id in pairs(quests) do ids[#ids + 1] = id end
table.sort(ids)
for _, id in ipairs(ids) do
    local d = quests[id]
    -- Feiertags-Quests (event) und Quests ohne Geber auslassen
    local starts = Unique(Ids(d.start))
    if d.event or #starts == 0 then
        skipped = skipped + 1
    else
        local givers = {}
        for _, nr in ipairs(starts) do if AddNode(nr, 5) then givers[#givers + 1] = nr end end
        local ends = {}
        for _, nr in ipairs(Unique(Ids(d["end"]))) do if AddNode(nr, 5) then ends[#ends + 1] = nr end end
        local objs = Ids(d.obj)
        for _, item in ipairs(d.obj and d.obj.I or {}) do
            for _, nr in ipairs(ItemSources(item)) do objs[#objs + 1] = nr end
        end
        local targets = {}
        for _, nr in ipairs(Unique(objs)) do if AddNode(nr, 12) then targets[#targets + 1] = nr end end
        if #givers > 0 then
            q[id] = {d.lvl or 0, d.min or 0, d.race or 0, d.class or 0, d.pre or false, givers, ends, targets}
            kept = kept + 1
        else
            skipped = skipped + 1
        end
    end
end

-- ===== schreiben =====
local function Num(v) return tostring(v) end
local function List(t)
    if not t then return "false" end
    local parts = {}
    for i, v in ipairs(t) do parts[i] = Num(v) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function Str(s) return string.format("%q", s):gsub("\\\n", "\\n") end

local header = "-- Guild Trip Questdatenbank – automatisch erzeugt von scripts/import_pfquest.lua, NICHT von Hand aendern.\n"
    .. "-- Quelle: pfQuest von Shagu (MIT, siehe LICENSE_pfQuest.txt), Daten aus VMaNGOS; Stand " .. commit .. "\n"

local f = assert(io.open(dest .. "/Data.lua", "w"))
f:write(header)
f:write("GuildTripQuestDB = {source = " .. Str("pfQuest " .. commit) .. "}\nlocal D = GuildTripQuestDB\nD.q = {\n")
local qids = {}
for id in pairs(q) do qids[#qids + 1] = id end
table.sort(qids)
for _, id in ipairs(qids) do
    local e = q[id]
    f:write(string.format("[%d]={%d,%d,%d,%d,%s,%s,%s,%s},\n", id, e[1], e[2], e[3], e[4], List(e[5]), List(e[6]), List(e[7]), List(e[8])))
end
f:write("}\nD.n = {\n")
local nids = {}
for nr in pairs(nodes) do nids[#nids + 1] = nr end
table.sort(nids)
for _, nr in ipairs(nids) do f:write("[" .. nr .. "]=" .. List(nodes[nr]) .. ",\n") end
f:write("}\n")
f:close()

for _, loc in ipairs({"deDE", "enUS"}) do
    local n = names[loc]
    local out = assert(io.open(dest .. "/Names_" .. loc .. ".lua", "w"))
    out:write(header)
    out:write("-- Namen nur fuer die passende Spielsprache behalten (die andere Tabelle wird verworfen)\n")
    out:write("local wanted = (GetLocale and GetLocale() == \"deDE\") and \"deDE\" or \"enUS\"\n")
    out:write("if wanted ~= \"" .. loc .. "\" then return end\n")
    out:write("local D = GuildTripQuestDB\nD.titles = {\n")
    for _, id in ipairs(qids) do
        local t = n.q[id] and n.q[id].T
        if t then out:write("[" .. id .. "]=" .. Str(t) .. ",\n") end
    end
    out:write("}\nD.names = {\n")
    for _, nr in ipairs(nids) do
        local name = nr > 0 and n.u[nr] or n.o[-nr]
        if type(name) == "string" then out:write("[" .. nr .. "]=" .. Str(name) .. ",\n") end
    end
    out:write("}\n")
    out:close()
end

print(string.format("pfQuest %s: %d Quests übernommen, %d ausgelassen (Feiertag/ohne Geber/Instanz), %d Orte",
    commit, kept, skipped, #nids))
