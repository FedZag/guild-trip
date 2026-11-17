-- Importiert die Quest-Daten von "Forever Dungeon Quests" (MIT, (c) 2026 Sundee,
-- https://github.com/ImSundee/forever-dungeon-quest) in das ONE-Format.
--
-- Aufruf (Data.lua und LICENSE vorher von GitHub laden, eigener leerer Ordner):
--   lua5.1 scripts/import_fdq.lua <Pfad/Data.lua> <Pfad/LICENSE> [Commit/Datum]
--
-- Die fremde Datei wird in einer leeren Umgebung ausgefuehrt (kein io/os/require),
-- nur die Tabellen FDQ_Dungeons und FDQ_PrereqInfo werden gelesen.
local dataPath, licensePath, revision = arg[1], arg[2], arg[3] or "main"
assert(dataPath and licensePath, "Aufruf: lua5.1 scripts/import_fdq.lua <Data.lua> <LICENSE> [Stand]")

local function ReadFile(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local source = ReadFile(dataPath)
local chunk = assert(loadstring(source, "=FDQ-Data"))
local env = {}
setfenv(chunk, env)
assert(pcall(chunk))
assert(type(env.FDQ_Dungeons) == "table", "FDQ_Dungeons fehlt")

local license = ReadFile(licensePath)
assert(license:find("MIT License", 1, true), "Lizenz ist nicht MIT – Import abgebrochen")

local function Coords(text)
    if type(text) ~= "string" then return nil end
    local x, y = text:match("^%s*([%d%.]+)%s*,%s*([%d%.]+)%s*$")
    x, y = tonumber(x), tonumber(y)
    if x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
        return math.floor(x * 10 + .5) / 1000, math.floor(y * 10 + .5) / 1000
    end
end

local function Ids(id)
    if type(id) == "number" then return {id} end
    if type(id) == "table" then
        local out = {}
        for _, v in ipairs(id) do if type(v) == "number" then out[#out + 1] = v end end
        if #out > 0 then return out end
    end
end

local function Zone(location)
    if type(location) ~= "string" then return nil end
    return location:match("^([^,]+)")
end

local function Prereqs(list)
    if type(list) ~= "table" then return nil end
    local out = {}
    for _, p in ipairs(list) do
        if type(p) == "string" then
            out[#out + 1] = {name = p}
        elseif type(p) == "table" then
            out[#out + 1] = {name = p.name, ids = Ids(p.id)}
        end
    end
    return #out > 0 and out or nil
end

local dungeons = {}
local questCount = 0
for _, d in ipairs(env.FDQ_Dungeons) do
    local entry = {name = d.name, keyNote = d.keyNote, levels = d.levels, quests = {}}
    for _, q in ipairs(d.quests or {}) do
        local x, y = Coords(q.coords)
        entry.quests[#entry.quests + 1] = {
            ids = Ids(q.id), name = q.name, level = q.level, faction = q.faction,
            giver = q.giver, location = q.location, zone = Zone(q.location), x = x, y = y,
            notes = q.notes, classOnly = q.classOnly, dungeonDrop = q.dungeonDrop or nil,
            prereqs = Prereqs(q.prereqs),
        }
        questCount = questCount + 1
    end
    dungeons[#dungeons + 1] = entry
end

local prereqInfo = {}
for name, info in pairs(env.FDQ_PrereqInfo or {}) do
    if type(info) == "table" then
        local x, y = Coords(info.coords)
        prereqInfo[name] = {giver = info.giver, location = info.location, zone = Zone(info.location), x = x, y = y}
    end
end

-- Stabile, gut lesbare Lua-Ausgabe
local function Serialize(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t ~= "table" then return "nil" end
    local isList = #v > 0
    local inner = indent .. "  "
    local parts = {}
    if isList then
        for _, item in ipairs(v) do parts[#parts + 1] = inner .. Serialize(item, inner) end
    else
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. string.format("%q", tostring(k)) .. "]")
            parts[#parts + 1] = inner .. key .. " = " .. Serialize(v[k], inner)
        end
    end
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. ",\n" .. indent .. "}"
end

local out = {}
out[#out + 1] = "-- AUTOMATISCH ERZEUGT von scripts/import_fdq.lua – nicht von Hand bearbeiten."
out[#out + 1] = "-- Quest-Daten: \"Forever Dungeon Quests\" von Sundee, MIT-Lizenz (siehe LICENSE_ForeverDungeonQuests.txt)."
out[#out + 1] = "-- Quelle: https://github.com/ImSundee/forever-dungeon-quest (Stand: " .. revision .. ")"
out[#out + 1] = "local _, dungeons = ..."
out[#out + 1] = "dungeons.QuestData = " .. Serialize({
    source = {name = "Forever Dungeon Quests", author = "Sundee", license = "MIT",
        url = "https://github.com/ImSundee/forever-dungeon-quest", revision = revision},
    dungeons = dungeons, prereqInfo = prereqInfo,
})
local target = "src/ONE_Dungeons/QuestData.lua"
local f = assert(io.open(target, "wb"))
f:write(table.concat(out, "\n"), "\n")
f:close()
local lf = assert(io.open("src/ONE_Dungeons/LICENSE_ForeverDungeonQuests.txt", "wb"))
lf:write(license)
lf:close()
print(string.format("geschrieben: %s (%d Dungeons, %d Quests)", target, #dungeons, questCount))
