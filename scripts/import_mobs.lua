-- Import: Gegner (Stufe, Spawn-Lager) aus QuestieDB (Forever) -> src/ONE_QuestDB/Mobs*.lua
-- Fuer die Farm-Empfehlung der Quest-Fuehrung und die Fundorte von Questgegnern.
--
--   git clone https://github.com/Questie/QuestieDB.git <ordner>
--   lua5.1 scripts/import_mobs.lua <ordner> [ziel=src/ONE_QuestDB]
--
-- Liest nur Datentabellen (data/Forever/foreverNpcDB.lua, Gebietszuordnung, deutsche Namen) in einer
-- leeren Umgebung – es wird kein Werkzeug aus dem QuestieDB-Ordner ausgefuehrt.
-- Erlaubnis: Questie-Team (BreakBB) am 17.11.2026, Questie/Questie#8365 – Nutzung unter GPLv3.
-- Ergebnis:
--   Mobs.lua  GuildTripQuestDB.m[npc] = {min, max, feindlich (1 Allianz, 2 Horde, 3 beide), karte, x, y, anzahl, karte, x, y, anzahl, …}
--             je Karte bis zu 3 Lager (Haeufungen von Spawnpunkten, Promille), die groessten zuerst.
--             Nur normale (keine Elite/Rare), feindliche Gegner ohne Dienste in der offenen Welt.
--   MobNames_deDE.lua / MobNames_enUS.lua  GuildTripQuestDB.mobNames[npc]
local src, dest = arg[1], arg[2] or "src/ONE_QuestDB"
assert(src, "Aufruf: lua5.1 scripts/import_mobs.lua <QuestieDB-Ordner> [Ziel]")

local commit = "?"
do
    local h = io.popen("git -C '" .. src:gsub("'", "") .. "' log -1 --format='%h %ad' --date=short 2>/dev/null")
    if h then commit = h:read("*l") or "?" h:close() end
end

local function Sandbox(file, env)
    local chunk = assert(loadfile(file))
    env = env or {}
    env.loadstring = function(s) local f = assert(loadstring(s)) setfenv(f, {}) return f end
    setfenv(chunk, env)
    return chunk(), env
end
local function LoadString(text) local f = assert(loadstring(text)) setfenv(f, {}) return f() end

-- Gegner
local npcs
do
    local DB = {}
    local loader = {ImportModule = function() return DB end, CreateModule = function() return DB end}
    Sandbox(src .. "/data/Forever/foreverNpcDB.lua", {QuestieLoader = loader})
    npcs = LoadString(DB.npcData)
end

-- Gebiet (AreaTable) -> WoW-Karte (uiMapID)
local AREA = {}
do
    local ZoneDB = {private = {}}
    local loader = {ImportModule = function() return ZoneDB end}
    Sandbox(src .. "/support/Forever/Zones/areaIdToUiMapId.lua", {QuestieLoader = loader})
    for k, v in pairs(LoadString(ZoneDB.private.areaIdToUiMapId)) do AREA[k] = v end
    for k, v in pairs(LoadString(ZoneDB.private.areaIdToUiMapIdOverride or "return {}")) do AREA[k] = v end
end
local function OpenWorld(m) return type(m) == "number" and ((m >= 1411 and m <= 1458 and m ~= 1414 and m ~= 1415) or m >= 2000) end

-- Deutsche Namen
local DE = {}
do
    local l10n = {npcNameLookup = {}}
    local loader = {ImportModule = function() return l10n end}
    Sandbox(src .. "/l10n/Forever/lookupNpcs/deDE.lua", {QuestieLoader = loader, GetLocale = function() return "deDE" end})
    local t = l10n.npcNameLookup.deDE
    if type(t) == "function" then t = t() end
    for id, v in pairs(t or {}) do DE[id] = type(v) == "table" and v[1] or v end
end

-- Lager: Spawnpunkte einer Karte gierig haeufen (Radius in Promille), groesste zuerst
local RADIUS, MIN_CAMP, MAX_CAMPS = 45, 4, 3
local function Camps(points)
    local left, camps = {}, {}
    for i, p in ipairs(points) do left[i] = p end
    while #left >= MIN_CAMP and #camps < MAX_CAMPS do
        local best, bestN
        for _, p in ipairs(left) do
            local n = 0
            for _, q in ipairs(left) do
                if (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 <= RADIUS * RADIUS then n = n + 1 end
            end
            if not bestN or n > bestN then best, bestN = p, n end
        end
        if bestN < MIN_CAMP then break end
        local sx, sy, keep = 0, 0, {}
        local members = 0
        for _, q in ipairs(left) do
            if (best[1] - q[1]) ^ 2 + (best[2] - q[2]) ^ 2 <= RADIUS * RADIUS then
                sx, sy, members = sx + q[1], sy + q[2], members + 1
            else
                keep[#keep + 1] = q
            end
        end
        camps[#camps + 1] = {math.floor(sx / members + .5), math.floor(sy / members + .5), members}
        left = keep
    end
    return camps
end

local KEYS = {name = 1, minLevelHealth = 2, minLevel = 4, maxLevel = 5, rank = 6, spawns = 7, friendly = 13, npcFlags = 15, factionID = 12}
local CRITTER = {[31] = true, [188] = true}
local out, names, count = {}, {}, 0
for id, n in pairs(npcs) do
    local name, minL, maxL = n[KEYS.name], n[KEYS.minLevel], n[KEYS.maxLevel]
    local ok = type(name) == "string" and type(minL) == "number" and type(maxL) == "number"
        and minL >= 1 and maxL <= 63 and (n[KEYS.rank] or 0) == 0 and (n[KEYS.npcFlags] or 0) == 0
        and not CRITTER[n[KEYS.factionID] or 0] and (n[KEYS.minLevelHealth] or 0) > 20
        and not name:find("[%[%(]") and not name:find("Trigger") and not name:find("DND")
    local friendly = n[KEYS.friendly]
    local hostile = (friendly == nil or friendly == "") and 3 or (friendly == "A" and 2) or (friendly == "H" and 1) or 0
    if ok and hostile > 0 and type(n[KEYS.spawns]) == "table" then
        local byMap = {}
        for area, list in pairs(n[KEYS.spawns]) do
            local m = AREA[area]
            if OpenWorld(m) and type(list) == "table" then
                for _, c in ipairs(list) do
                    if type(c) == "table" and c[1] and c[2] and c[1] >= 0 and c[2] >= 0 and c[1] <= 100 and c[2] <= 100 then
                        byMap[m] = byMap[m] or {}
                        table.insert(byMap[m], {math.floor(c[1] * 10 + .5), math.floor(c[2] * 10 + .5)})
                    end
                end
            end
        end
        local row = {minL, maxL, hostile}
        local maps = {}
        for m in pairs(byMap) do maps[#maps + 1] = m end
        table.sort(maps)
        for _, m in ipairs(maps) do
            for _, camp in ipairs(Camps(byMap[m])) do
                row[#row + 1], row[#row + 2], row[#row + 3], row[#row + 4] = m, camp[1], camp[2], camp[3]
            end
        end
        if #row > 3 then
            out[id] = row
            names[id] = {de = DE[id] or name, en = name}
            count = count + 1
        end
    end
end

local ids = {}
for id in pairs(out) do ids[#ids + 1] = id end
table.sort(ids)
local function Str(s) return string.format("%q", s):gsub("\\\n", "\\n") end
local head = "-- Guild Trip Gegnerdaten – automatisch erzeugt von scripts/import_mobs.lua, NICHT von Hand aendern.\n"
    .. "-- Quelle: QuestieDB (Forever) vom Questie-Team, GPLv3 mit Erlaubnis (Questie/Questie#8365); Stand " .. commit .. "\n"
do
    local f = assert(io.open(dest .. "/Mobs.lua", "w"))
    f:write(head)
    f:write("-- m[npc] = {min, max, feindlich (1 Allianz, 2 Horde, 3 beide), karte, x, y, anzahl, …} (x/y in Promille)\n")
    f:write("GuildTripQuestDB = GuildTripQuestDB or {}\nGuildTripQuestDB.m = {\n")
    for _, id in ipairs(ids) do f:write("[" .. id .. "]={" .. table.concat(out[id], ",") .. "},\n") end
    f:write("}\n")
    f:close()
end
for _, loc in ipairs({"deDE", "enUS"}) do
    local f = assert(io.open(dest .. "/MobNames_" .. loc .. ".lua", "w"))
    f:write(head)
    f:write("local wanted = (GetLocale and GetLocale() == \"deDE\") and \"deDE\" or \"enUS\"\n")
    f:write("if wanted ~= \"" .. loc .. "\" then return end\n")
    f:write("GuildTripQuestDB.mobNames = {\n")
    for _, id in ipairs(ids) do f:write("[" .. id .. "]=" .. Str(loc == "deDE" and names[id].de or names[id].en) .. ",\n") end
    f:write("}\n")
    f:close()
end
print(("Gegner: %d (Stand %s)"):format(count, commit))
