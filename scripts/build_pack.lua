-- Guild Trip: Startpaket aus EIGENEN Funden bauen (Haendler, Questgeber, Dungeon-Eingaenge).
-- Liest eine oder mehrere SavedVariables-Dateien (ONE_Core.lua, z. B. auch von Testern)
-- und schreibt feste Startlisten ins Addon:
--   src/ONE_Nav/Pack.lua             nav.Pack = {merchants = {...}, givers = {...}}
--   src/ONE_Dungeons/EntrancePack.lua dungeons.EntrancePack = {schluessel = {karte, x, y}}
-- Nur selbst gesammelte Daten (keine fremden Datenbanken), keine Spielernamen:
-- Haendler ohne Gegenstandsnamen, Eingaenge nur aus Quelle game/self/guild.
-- Bestehende Startlisten bleiben erhalten und werden ergaenzt.
-- Aufruf: lua5.1 scripts/build_pack.lua <ONE_Core.lua> [weitere ONE_Core.lua ...]
local root = (arg[0]:match("^(.*)/scripts/") or ".")

-- ONE_Core.lua (ProjectONEDB) oder ONE_Dev.lua des Entwicklers (GuildTripDevDB.guildFinds:
-- Funde, die Gildenmitglieder per "Zauberdaten teilen" geschickt haben – gleiche Form)
local function Load(path)
    local env = {}
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
    if env.ProjectONEDB then return env.ProjectONEDB end
    if env.GuildTripDevDB then return env.GuildTripDevDB.guildFinds or {} end
    return {}
end

-- vorhandene Pakete laden (damit nichts verloren geht)
local nav, dungeons = {}, {}
local crafting = {}
pcall(function() assert(loadfile(root .. "/src/ONE_Nav/Pack.lua"))("ONE_Nav", nav) end)
pcall(function() assert(loadfile(root .. "/src/ONE_Crafting/TrainerPack.lua"))("ONE_Crafting", crafting) end)
local trainers = crafting.TrainerPack or {}
local classesNS = {}
pcall(function() assert(loadfile(root .. "/src/ONE_Classes/TrainerSpellPack.lua"))("ONE_Classes", classesNS) end)
local classSpells = classesNS.TrainerSpellPack or {}
pcall(function() assert(loadfile(root .. "/src/ONE_Classes/LootPack.lua"))("ONE_Classes", classesNS) end)
local lootPack = classesNS.LootPack or {}
pcall(function() assert(loadfile(root .. "/src/ONE_Dungeons/EntrancePack.lua"))("ONE_Dungeons", dungeons) end)
local pack = nav.Pack or {merchants = {}, givers = {}}
pack.merchants, pack.givers = pack.merchants or {}, pack.givers or {}
local entrances = dungeons.EntrancePack or {}

local function Round(v) return math.floor(v * 1000 + .5) / 1000 end
local added = {merchants = 0, givers = 0, entrances = 0, trainers = 0, classSpells = 0, loot = 0}
for i = 1, #arg do
    local db = Load(arg[i])
    for key, m in pairs(db.nav and db.nav.merchants or {}) do
        if m.mapID and m.x and m.y and type(m.cats) == "table" then
            local old = pack.merchants[key]
            if not old then added.merchants = added.merchants + 1 end
            local cats = old and old.cats or {}
            for c in pairs(m.cats) do cats[c] = true end
            pack.merchants[key] = {name = m.name, mapID = m.mapID, x = Round(m.x), y = Round(m.y), faction = m.faction, cats = cats}
        end
    end
    for key, g in pairs(db.nav and db.nav.givers or {}) do
        if g.mapID and g.x and g.y and type(g.quests) == "table" then
            local old = pack.givers[key]
            if not old then added.givers = added.givers + 1 end
            local quests = old and old.quests or {}
            for qk, q in pairs(g.quests) do quests[qk] = {title = q.title, level = q.level} end
            pack.givers[key] = {name = g.name, mapID = g.mapID, x = Round(g.x), y = Round(g.y), faction = g.faction, quests = quests}
        end
    end
    -- Beute-Funde: Quellen je Gegenstand zusammenfuehren (Anzahl addieren)
    for itemID, e in pairs(db.classGuide and db.classGuide.loot or {}) do
        if type(e) == "table" and type(e.sources) == "table" then
            local p = lootPack[itemID]
            if not p then added.loot = added.loot + 1 p = {sources = {}} lootPack[itemID] = p end
            p.q, p.slot, p.minLevel, p.ilvl = e.q or p.q, e.slot or p.slot, e.minLevel or p.minLevel, e.ilvl or p.ilvl
            for k, s in pairs(e.sources) do
                local old = p.sources[k]
                p.sources[k] = {name = s.name or (old and old.name), kind = s.kind or (old and old.kind), instance = s.instance or (old and old.instance),
                    mapID = s.mapID or (old and old.mapID), x = s.x and Round(s.x) or (old and old.x), y = s.y and Round(s.y) or (old and old.y),
                    count = math.max(s.count or 1, old and old.count or 0)}
            end
        end
    end
    -- Klassenlehrer-Angebote je Klasse (Zauber|Rang -> Stufe)
    for cls, list in pairs(db.classGuide and db.classGuide.classSpells or {}) do
        classSpells[cls] = classSpells[cls] or {}
        for key, level in pairs(list) do
            if not classSpells[cls][key] then added.classSpells = added.classSpells + 1 end
            classSpells[cls][key] = level
        end
    end
    -- Lehrer (ohne Finder-Namen); gelehrte Stufen werden zusammengefuehrt
    for npc, e in pairs(db.crafting and db.crafting.trainers or {}) do
        if e.map and e.x and e.y and e.kind then
            local old = trainers[npc]
            if not old then added.trainers = added.trainers + 1 end
            local teaches = old and old.teaches
            for r, on in pairs(e.teaches or {}) do if on then teaches = teaches or {} teaches[r] = true end end
            local weapons = old and old.weapons
            for k, on in pairs(e.weapons or {}) do if on then weapons = weapons or {} weapons[k] = true end end
            -- Fraktion: gemerkt, sonst aus der Hauptstadt abgeleitet (sonst saehe die Allianz Horde-Lehrer)
            local capital = {[1454] = "Horde", [1456] = "Horde", [1458] = "Horde", [1453] = "Alliance", [1455] = "Alliance", [1457] = "Alliance"}
            trainers[npc] = {kind = e.kind, what = e.what, map = e.map, x = Round(e.x), y = Round(e.y), area = e.area,
                title = e.title, faction = e.faction or (old and old.faction) or capital[e.map], teaches = teaches,
                weapons = weapons}
        end
    end
    for key, e in pairs(db.dungeons and db.dungeons.entrances or {}) do
        if e.mapID and e.x and e.y and (e.source == "game" or e.source == "self" or e.source == "guild") then
            if not entrances[key] then added.entrances = added.entrances + 1 end
            entrances[key] = {e.mapID, Round(e.x), Round(e.y)}
        end
    end
end

-- Lua-Text schreiben (sortiert, damit Aenderungen im Git gut lesbar sind)
local function Str(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) == "boolean" or type(v) == "number" then return tostring(v) end
    return "nil"
end
local function Key(k) return type(k) == "number" and ("[" .. k .. "]") or (k:match("^[%a_][%w_]*$") and k or ("[" .. string.format("%q", k) .. "]")) end
local function Dump(t, indent)
    indent = indent or ""
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local isList = #t > 0
    local parts = {}
    for _, k in ipairs(keys) do
        local v = t[k]
        local text = type(v) == "table" and Dump(v, indent .. "    ") or Str(v)
        parts[#parts + 1] = (isList and "" or (Key(k) .. " = ")) .. text
    end
    if #parts == 0 then return "{}" end
    local one = "{" .. table.concat(parts, ", ") .. "}"
    if #one < 100 then return one end
    return "{\n" .. indent .. "    " .. table.concat(parts, ",\n" .. indent .. "    ") .. ",\n" .. indent .. "}"
end
local head = "-- Guild Trip Startpaket – ERZEUGT von scripts/build_pack.lua, nicht von Hand aendern.\n"
    .. "-- Nur selbst gesammelte Funde der Guild-Trip-Spieler (keine fremden Datenbanken, keine Spielernamen).\n"
local f = assert(io.open(root .. "/src/ONE_Nav/Pack.lua", "w"))
f:write(head, "local _, nav = ...\nnav.Pack = ", Dump(pack), "\n")
f:close()
f = assert(io.open(root .. "/src/ONE_Crafting/TrainerPack.lua", "w"))
f:write(head, "local _, crafting = ...\ncrafting.TrainerPack = ", Dump(trainers), "\n")
f:close()
f = assert(io.open(root .. "/src/ONE_Classes/TrainerSpellPack.lua", "w"))
f:write(head, "-- [\"Zauber|Rang\"] = Stufe je Klasse (Klassenlehrer)\nlocal _, classes = ...\nclasses.TrainerSpellPack = ", Dump(classSpells), "\n")
f:close()
f = assert(io.open(root .. "/src/ONE_Classes/LootPack.lua", "w"))
f:write(head, "-- [itemID] = {slot, minLevel, sources = {[gegner] = {name, kind, instance, mapID, x, y, count}}}\nlocal _, classes = ...\nclasses.LootPack = ", Dump(lootPack), "\n")
f:close()
f = assert(io.open(root .. "/src/ONE_Dungeons/EntrancePack.lua", "w"))
f:write(head, "-- schluessel = {uiMapID, x, y}\nlocal _, dungeons = ...\ndungeons.EntrancePack = ", Dump(entrances), "\n")
f:close()
local function N(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
print(("Startpaket: %d Händler (+%d), %d Questgeber (+%d), %d Eingänge (+%d), %d Lehrer (+%d), Klassenlehrer-Zauber +%d, Beute-Gegenstände +%d"):format(
    N(pack.merchants), added.merchants, N(pack.givers), added.givers, N(entrances), added.entrances, N(trainers), added.trainers, added.classSpells, added.loot))
