-- Import: Questdaten aus QuestieDB (Forever-Fassung) -> src/ONE_QuestDB (kompakt, nur was Guild Trip braucht).
-- Ersetzt den früheren pfQuest-Import (scripts/import_pfquest.lua): Forever-genau, inkl. neuer Forever-Quests.
--
--   git clone https://github.com/Questie/QuestieDB.git <ordner>
--   cd <ordner> && lua5.1 tools/export-forever.lua --include-authored   (Questies eigenes Werkzeug: führt
--       Rohdaten + alle Forever-Korrekturen zusammen -> src/corrections/Forever/combined/)
--   lua5.1 scripts/import_questiedb.lua <ordner> [ziel=src/ONE_QuestDB]
--
-- Erlaubnis: Questie-Team (BreakBB) am 17.11.2026, Questie/Questie#8365 – Nutzung unter GPLv3.
-- Die Dateien sind Datentabellen; sie werden in einer leeren Umgebung geladen (kein os/io).
-- Ergebnis (Format wie bisher, erweitert):
--   Data.lua  GuildTripQuestDB.q[id] = {stufe, mindeststufe, volk, klasse, vorquests(eine von), geber, abgabe, ziele,
--                                       vorquests(alle), schliesst_aus, EP, naechste_in_kette, hoechststufe, gebiet}
--             GuildTripQuestDB.n[nr] = {fraktion, karte, x, y, karte, x, y, …} (nr > 0 NPC, nr < 0 Objekt,
--                                       nr >= 9000000 Erkundungsort der Quest nr-9000000)
--   Names_deDE.lua / Names_enUS.lua  Questtitel und NPC-/Objektnamen
-- Koordinaten: Promille (0–1000) auf der WoW-Karte (uiMapID), schon im Forever-Rahmen.
local src, dest = arg[1], arg[2] or "src/ONE_QuestDB"
assert(src, "Aufruf: lua5.1 scripts/import_questiedb.lua <QuestieDB-Ordner> [Ziel]")
local combined = src .. "/src/corrections/Forever/combined/"

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

-- ===== Questie-Daten =====
local quests = Sandbox(combined .. "foreverQuestDB.lua")
local npcs = Sandbox(combined .. "foreverNpcDB.lua")
local objects = Sandbox(combined .. "foreverObjectDB.lua")
local items = Sandbox(combined .. "foreverItemDB.lua")

-- Gebiet (AreaTable) -> WoW-Karte (uiMapID)
local AREA = {}
do
    local ZoneDB = {private = {}}
    local loader = {ImportModule = function() return ZoneDB end}
    Sandbox(src .. "/support/Forever/Zones/areaIdToUiMapId.lua", {QuestieLoader = loader})
    for k, v in pairs(LoadString(ZoneDB.private.areaIdToUiMapId)) do AREA[k] = v end
    for k, v in pairs(LoadString(ZoneDB.private.areaIdToUiMapIdOverride or "return {}")) do AREA[k] = v end
end
-- Nur Karten der offenen Welt (Gebiete und Hauptstädte, Classic 1411–1458 + Forever-eigene ≥ 2000)
local function OpenWorld(m) return type(m) == "number" and ((m >= 1411 and m <= 1458 and m ~= 1414 and m ~= 1415) or m >= 2000) end

-- EP je Quest: gemessen (Traces) vor Classic-Tabelle
local XP = {}
do
    local QuestXP = {db = {}}
    local loader = {ImportModule = function() return QuestXP end, CreateModule = function() return QuestXP end}
    Sandbox(src .. "/support/Forever/QuestXP/xpDB-classic.lua", {QuestieLoader = loader})
    for id, v in pairs(QuestXP.db) do XP[id] = v[2] end
    QuestXP.db = {}
    Sandbox(src .. "/support/Forever/QuestXP/xpDB-traces.lua", {QuestieLoader = loader})
    for id, v in pairs(QuestXP.db) do XP[id] = v[2] end
end

-- Deutsche Namen
local DE = {q = {}, u = {}, o = {}}
do
    local l10n = {questLookup = {}, npcNameLookup = {}, objectLookup = {}}
    local loader = {ImportModule = function() return l10n end}
    local env = {QuestieLoader = loader, GetLocale = function() return "deDE" end}
    local function Fetch(file)
        local e = {}
        for k, v in pairs(env) do e[k] = v end
        local ret = Sandbox(file, e)
        return ret
    end
    Fetch(src .. "/l10n/Forever/lookupQuests/deDE.lua")
    Fetch(src .. "/l10n/Forever/lookupNpcs/deDE.lua")
    local objRet = Fetch(src .. "/l10n/Forever/lookupObjects/deDE.lua")
    local function Get(t) if type(t) == "function" then return t() end return t end
    for id, v in pairs(Get(l10n.questLookup.deDE) or {}) do DE.q[id] = type(v) == "table" and v[1] or v end
    for id, v in pairs(Get(l10n.npcNameLookup.deDE) or {}) do DE.u[id] = type(v) == "table" and v[1] or v end
    local objs = Get(l10n.objectLookup.deDE) or (type(objRet) == "table" and objRet) or {}
    for id, v in pairs(objs) do DE.o[id] = type(v) == "table" and v[1] or v end
end

-- ===== Orte =====
local FAC = {A = 1, H = 2, AH = 3, HA = 3}
local nodes, nodeLimit = {}, {}
-- Punkte je Karte sammeln (Spawns {[gebiet] = {{x,y},…}})
local function ByMap(spawns)
    local byMap, best, bestN = {}, nil, 0
    for area, list in pairs(spawns or {}) do
        local m = AREA[area]
        if OpenWorld(m) and type(list) == "table" then
            for _, c in ipairs(list) do
                if type(c) == "table" and c[1] and c[2] and c[1] >= 0 and c[2] >= 0 and c[1] <= 100 and c[2] <= 100 then
                    byMap[m] = byMap[m] or {}
                    table.insert(byMap[m], {math.floor(c[1] * 10 + .5), math.floor(c[2] * 10 + .5)})
                    if #byMap[m] > bestN then best, bestN = m, #byMap[m] end
                end
            end
        end
    end
    return byMap, best
end
local function Put(nr, fac, byMap, best, limit)
    if not best then return false end
    local out = {fac}
    local function Take(m, list, max)
        local step = math.max(1, #list / max)
        local i = 1
        while i <= #list and max > 0 do
            local p = list[math.floor(i)]
            out[#out + 1], out[#out + 2], out[#out + 3] = m, p[1], p[2]
            i, max = i + step, max - 1
        end
    end
    Take(best, byMap[best], limit)
    for m, list in pairs(byMap) do if m ~= best then Take(m, list, 1) end end
    nodes[nr], nodeLimit[nr] = out, limit
    return true
end
local function AddNode(nr, limit)
    if nodes[nr] and (nodeLimit[nr] or 0) >= limit then return true end
    if nr > 0 then
        local u = npcs[nr]
        if type(u) ~= "table" then return false end
        local byMap, best = ByMap(u[7])
        if not best then byMap, best = ByMap(u[8]) end -- nur Laufwege bekannt
        return Put(nr, FAC[u[13] or ""] or 0, byMap, best, limit)
    end
    local o = objects[-nr]
    if type(o) ~= "table" then return false end
    local byMap, best = ByMap(o[4])
    return Put(nr, 0, byMap, best, limit)
end
local function Unique(list)
    local seen, out = {}, {}
    for _, v in ipairs(list) do if not seen[v] then seen[v] = true out[#out + 1] = v end end
    return out
end
local function Starters(t) -- {creature, object, item}
    local out = {}
    if type(t) ~= "table" then return out end
    for _, u in ipairs(t[1] or {}) do out[#out + 1] = u end
    for _, o in ipairs(t[2] or {}) do out[#out + 1] = -o end
    return out
end
-- Gegenstand -> Quellen (Monster/Objekte, die ihn fallen lassen), höchstens 3
local function ItemSources(itemID)
    local it = items[itemID]
    if type(it) ~= "table" then return {} end
    local out = {}
    for _, u in ipairs(it[2] or {}) do if #out < 3 then out[#out + 1] = u end end
    for _, o in ipairs(it[3] or {}) do if #out < 3 then out[#out + 1] = -o end end
    return out
end
local function Race(mask)
    if type(mask) ~= "number" or mask <= 0 then return 0 end
    local low = mask % 4294967296 % 256
    if low == 255 then return 0 end
    return low
end
local function List(t)
    if type(t) ~= "table" or #t == 0 then return false end
    return t
end

-- ===== Quests =====
local q, kept, skipped = {}, 0, 0
local ids = {}
for id in pairs(quests) do ids[#ids + 1] = id end
table.sort(ids)
local TRIGGER = 9000000
-- Questarten (zoneOrSort < 0) der Feiertage und Weltereignisse (Classic QuestSort)
local HOLIDAY = {[-22] = true, [-41] = true, [-364] = true, [-365] = true, [-366] = true, [-368] = true, [-369] = true,
    [-370] = true, [-374] = true, [-375] = true, [-376] = true, [-1001] = true, [-1002] = true, [-1003] = true, [-1005] = true}
for _, id in ipairs(ids) do
    local d = quests[id]
    local starts = Unique(Starters(d[2]))
    -- Feiertage/Weltereignisse (an der Questart erkannt) und Quests ohne Geber (nur Gegenstand) auslassen.
    -- NICHT specialFlags 2: das heisst bei Questie "wird durch ein Ereignis abgeschlossen" (Begleit- und
    -- Erkundungsquests wie 155 "Die Bruderschaft der Defias") – bis 17.11.2026 fielen so 188 normale Quests weg.
    if HOLIDAY[d[17] or 0] or #starts == 0 then
        skipped = skipped + 1
    else
        local givers = {}
        for _, nr in ipairs(starts) do if AddNode(nr, 5) then givers[#givers + 1] = nr end end
        local ends = {}
        for _, nr in ipairs(Unique(Starters(d[3]))) do if AddNode(nr, 5) then ends[#ends + 1] = nr end end
        local objs, obj = {}, d[10] or {}
        for _, c in ipairs(obj[1] or {}) do objs[#objs + 1] = c[1] end
        for _, o in ipairs(obj[2] or {}) do objs[#objs + 1] = -o[1] end
        for _, it in ipairs(obj[3] or {}) do for _, nr in ipairs(ItemSources(it[1])) do objs[#objs + 1] = nr end end
        for _, kc in ipairs(obj[5] or {}) do
            local list = type(kc[1]) == "table" and kc[1] or {}
            objs[#objs + 1] = kc[2] or list[1]
        end
        local targets = {}
        for _, nr in ipairs(Unique(objs)) do if nr and AddNode(nr, 12) then targets[#targets + 1] = nr end end
        -- Erkundungsziel (triggerEnd = {text, {[gebiet] = {{x,y}}}})
        local trig = d[9]
        if type(trig) == "table" and type(trig[2]) == "table" then
            local byMap, best = ByMap(trig[2])
            if Put(TRIGGER + id, 0, byMap, best, 3) then targets[#targets + 1] = TRIGGER + id end
        end
        if #givers > 0 then
            q[id] = {d[5] or 0, d[4] or 0, Race(d[6]), d[7] or 0, List(d[13]), givers, ends, targets,
                List(d[12]), List(d[16]), XP[id] or 0, d[22] or 0, d[32] or 0, d[17] or 0}
            kept = kept + 1
        else
            skipped = skipped + 1
        end
    end
end

-- ===== schreiben =====
local function Num(v) return tostring(v) end
local function L(t)
    if not t then return "false" end
    local parts = {}
    for i, v in ipairs(t) do parts[i] = Num(v) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function Str(s) return (string.format("%q", s):gsub("\\\n", "\\n")) end

local header = "-- Guild Trip Questdatenbank – automatisch erzeugt von scripts/import_questiedb.lua, NICHT von Hand aendern.\n"
    .. "-- Quelle: QuestieDB (Forever) vom Questie-Team, GPLv3 mit Erlaubnis (Questie/Questie#8365); Stand " .. commit .. "\n"

local f = assert(io.open(dest .. "/Data.lua", "w"))
f:write(header)
f:write("GuildTripQuestDB = {source = " .. Str("QuestieDB " .. commit) .. "}\nlocal D = GuildTripQuestDB\nD.q = {\n")
local qids = {}
for id in pairs(q) do qids[#qids + 1] = id end
table.sort(qids)
for _, id in ipairs(qids) do
    local e = q[id]
    f:write(string.format("[%d]={%d,%d,%d,%d,%s,%s,%s,%s,%s,%s,%d,%d,%d,%d},\n", id, e[1], e[2], e[3], e[4],
        L(e[5]), L(e[6]), L(e[7]), L(e[8]), L(e[9]), L(e[10]), e[11], e[12], e[13], e[14]))
end
f:write("}\nD.n = {\n")
local nids = {}
for nr in pairs(nodes) do nids[#nids + 1] = nr end
table.sort(nids)
for _, nr in ipairs(nids) do f:write("[" .. nr .. "]=" .. L(nodes[nr]) .. ",\n") end
f:write("}\n")
f:close()

for _, loc in ipairs({"deDE", "enUS"}) do
    local out = assert(io.open(dest .. "/Names_" .. loc .. ".lua", "w"))
    out:write(header)
    out:write("-- Namen nur fuer die passende Spielsprache behalten (die andere Tabelle wird verworfen)\n")
    out:write("local wanted = (GetLocale and GetLocale() == \"deDE\") and \"deDE\" or \"enUS\"\n")
    out:write("if wanted ~= \"" .. loc .. "\" then return end\n")
    out:write("local D = GuildTripQuestDB\nD.titles = {\n")
    for _, id in ipairs(qids) do
        local t = loc == "deDE" and DE.q[id] or quests[id][1]
        if type(t) == "string" then out:write("[" .. id .. "]=" .. Str(t) .. ",\n") end
    end
    out:write("}\nD.names = {\n")
    for _, nr in ipairs(nids) do
        local name
        if nr >= TRIGGER then name = nil
        elseif nr > 0 then name = loc == "deDE" and DE.u[nr] or (npcs[nr] and npcs[nr][1])
        else name = loc == "deDE" and DE.o[-nr] or (objects[-nr] and objects[-nr][1]) end
        if loc == "deDE" and type(name) ~= "string" then
            name = nr > 0 and npcs[nr] and npcs[nr][1] or (nr < 0 and objects[-nr] and objects[-nr][1]) or nil
        end
        if type(name) == "string" then out:write("[" .. nr .. "]=" .. Str(name) .. ",\n") end
    end
    out:write("}\n")
    out:close()
end

-- ===== NPC-Verzeichnis: Lehrer, Händler (Services.lua) =====
-- Welcher Lehrer was lehrt: Shortest Path Forever Data/Services.lua (aus classic-db, GPL), optional 3. Argument.
local spf = arg[3]
local CLASS = {[1] = "Krieger", [2] = "Paladin", [3] = "Jäger", [4] = "Schurke", [5] = "Priester", [7] = "Schamane",
    [8] = "Magier", [9] = "Hexenmeister", [11] = "Druide"}
local PROF = {[171] = "Alchemie", [164] = "Schmiedekunst", [333] = "Verzauberkunst", [202] = "Ingenieurskunst",
    [182] = "Kräuterkunde", [186] = "Bergbau", [393] = "Kürschnerei", [165] = "Lederverarbeitung", [197] = "Schneiderei",
    [185] = "Kochkunst", [129] = "Erste Hilfe", [356] = "Angeln"}
local SUB_CLASS = {warrior = "Krieger", paladin = "Paladin", hunter = "Jäger", rogue = "Schurke", priest = "Priester",
    shaman = "Schamane", mage = "Magier", warlock = "Hexenmeister", druid = "Druide"}
local SUB_PROF = {alchemist = "Alchemie", alchemy = "Alchemie", blacksmith = "Schmiedekunst", enchant = "Verzauberkunst",
    engineer = "Ingenieurskunst", herbalis = "Kräuterkunde", mining = "Bergbau", miner = "Bergbau", skinn = "Kürschnerei",
    leatherwork = "Lederverarbeitung", tailor = "Schneiderei", cook = "Kochkunst", chef = "Kochkunst",
    ["first aid"] = "Erste Hilfe", fishing = "Angeln", fisherman = "Angeln"}
local classOf, profOf = {}, {}
if spf then
    local ns = {}
    local chunk = assert(loadfile(spf .. "/Data/Services.lua"))
    setfenv(chunk, {})
    chunk("ShortestPathForever", ns)
    classOf, profOf = ns.ClassTrainers or {}, ns.ProfessionTrainers or {}
end
-- Händler-Angebot: Gegenstand.vendors umdrehen, Kategorien wie Merchants.Classify (Classic-Gegenstandsklassen)
local VIAL = {[3371] = 1, [3372] = 1, [8925] = 1, [18256] = 1}
local THREAD = {[2320] = 1, [2321] = 1, [4291] = 1, [8343] = 1, [14341] = 1, [2324] = 1, [2604] = 1, [2605] = 1,
    [4340] = 1, [4341] = 1, [4342] = 1, [6260] = 1, [6261] = 1, [10290] = 1}
local function Cat(itemID, cls, sub)
    if VIAL[itemID] then return "vial" end
    if THREAD[itemID] then return "thread" end
    if cls == 0 then return sub == 5 and "food" or "misc" end
    if cls == 1 then return "bag" end
    if cls == 2 then return "weapon" end
    if cls == 4 then return sub == 0 and "misc" or "armor" end
    if cls == 5 then return "reagent" end
    if cls == 6 or cls == 11 then return "ammo" end
    if cls == 7 then return "trade" end
    if cls == 9 then return "recipe" end
    return "misc"
end
local sells = {}
for itemID, it in pairs(items) do
    for _, v in ipairs(type(it) == "table" and it[14] or {}) do
        sells[v] = sells[v] or {}
        sells[v][Cat(itemID, it[12], it[13])] = true
    end
end
local function Spot(u)
    local byMap, best = ByMap(u[7])
    if not best then return end
    local p = byMap[best][1]
    return best, p[1], p[2]
end
local trainers, vendors = {}, {}
local nT, nV = 0, 0
local npcIds = {}
for id in pairs(npcs) do npcIds[#npcIds + 1] = id end
table.sort(npcIds)
for _, id in ipairs(npcIds) do
    local u = npcs[id]
    local flags = type(u) == "table" and u[15] or 0
    if flags > 0 then
        local fac = FAC[u[13] or ""] or 0
        local trainer = flags % 32 >= 16
        local vendor = flags % 8 >= 4
        local repair = flags % 32768 >= 16384
        if trainer or vendor or repair then
            local m, x, y = Spot(u)
            if m then
                if trainer then
                    local kind, what
                    if classOf[id] and CLASS[classOf[id]] then kind, what = "class", CLASS[classOf[id]]
                    elseif profOf[id] and PROF[profOf[id]] then kind, what = "profession", PROF[profOf[id]]
                    elseif (u[14] or ""):find("Weapon Master") then kind, what = "weapon", "Waffenmeister"
                    else kind, what = "other", u[14] or "" end
                    -- Rückfall: Titel des NPCs („Shaman Trainer“, „Junior Mining Trainer“, „Alchemist“ …)
                    if kind == "other" then
                        local sub = (u[14] or ""):lower()
                        for word, cls in pairs(SUB_CLASS) do
                            if sub:find(word .. " trainer", 1, true) then kind, what = "class", cls end
                        end
                        if kind == "other" and not sub:find("pet trainer", 1, true) then
                            for word, prof in pairs(SUB_PROF) do
                                if sub:find(word, 1, true) then kind, what = "profession", prof end
                            end
                        end
                    end
                    trainers[#trainers + 1] = string.format("[%d]={%q,%q,%d,%d,%d,%d}", id, kind, what, m, x, y, fac)
                    nT = nT + 1
                end
                if vendor or repair then
                    local cats = {}
                    for c in pairs(sells[id] or {}) do cats[#cats + 1] = c end
                    if repair then cats[#cats + 1] = "repair" end
                    table.sort(cats)
                    if #cats > 0 then
                        vendors[#vendors + 1] = string.format("[%d]={%d,%d,%d,%d,%q}", id, m, x, y, fac, table.concat(cats, " "))
                        nV = nV + 1
                    end
                end
            end
        end
    end
end
do
    local out = assert(io.open(dest .. "/Services.lua", "w"))
    out:write(header)
    out:write("-- NPC-Verzeichnis: Lehrer [npc]={art, was, karte, x‰, y‰, fraktion}; Händler [npc]={karte, x‰, y‰, fraktion,\n")
    out:write("-- \"kategorien\"}. Lehrer-Art aus Shortest Path Forever Data/Services.lua (classic-db, GPL). Fraktion 1 A, 2 H, 3 beide.\n")
    out:write("local D = GuildTripQuestDB\nD.trainers = {\n" .. table.concat(trainers, ",\n") .. "}\n")
    out:write("D.vendors = {\n" .. table.concat(vendors, ",\n") .. "}\n")
    out:write("D.npcNames = setmetatable({}, {__index = function(_, k) return D.names and D.names[k] end})\n")
    out:close()
end
-- Namen der Lehrer/Händler mit in die Namensdateien (falls nicht schon als Questgeber drin)
for _, loc in ipairs({"deDE", "enUS"}) do
    local out = assert(io.open(dest .. "/Names_" .. loc .. ".lua", "a"))
    out:write("D.svcNames = {\n")
    for _, list in ipairs({trainers, vendors}) do
        for _, line in ipairs(list) do
            local id = tonumber(line:match("^%[(%d+)%]"))
            local name = loc == "deDE" and DE.u[id] or nil
            name = name or (npcs[id] and npcs[id][1])
            if type(name) == "string" then out:write("[" .. id .. "]=" .. Str(name) .. ",\n") end
        end
    end
    out:write("}\n")
    out:close()
end
print(string.format("NPC-Verzeichnis: %d Lehrer, %d Händler%s", nT, nV, spf and "" or " (ohne SPF: Lehrer-Art unbekannt)"))

print(string.format("QuestieDB %s: %d Quests übernommen, %d ausgelassen (Ereignis/ohne Geber/Instanz), %d Orte",
    commit, kept, skipped, #nids))
