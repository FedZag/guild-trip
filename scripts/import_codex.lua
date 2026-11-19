-- Importiert Bosse und Beute aus dem Addon "Dungeon Codex" (Baxter × DLDVLPR,
-- https://www.curseforge.com/wow/addons/dungeon-codex, Projekt 1715265) in das Guild-Trip-Format.
-- Das Addon steht unter GPL-2.0; der Autor hat am 19.11.2026 ausdruecklich erlaubt, die Boss- und
-- Beute-Daten in Guild Trip unter GPL-3.0-or-later zu nutzen (Wortlaut: docs/ANFRAGEN_DATEN.md, Abschnitt 3).
--
-- Uebernommen werden NUR die vier Forever-eigenen Dungeons, die der Autor selbst erfasst hat
-- (Halle der Thanen, Ruinen von Lordaeron, Ausgrabungsstaette, Dalaran). Die Classic-Dungeons in
-- Dungeon Codex stammen aus AtlasLootClassic/foreverchanges.pro und werden hier nicht uebernommen.
--
-- Aufruf (Zip von CurseForge in einen eigenen leeren Ordner laden und entpacken):
--   lua5.1 scripts/import_codex.lua <Pfad/AeonDungeonJournal> > src/ONE_Dungeons/BossData.lua
--
-- Die fremde Datei wird NICHT ausgefuehrt, nur als Text gelesen.
local dir = arg[1]
assert(dir, "Aufruf: lua5.1 scripts/import_codex.lua <Ordner AeonDungeonJournal>")

local function ReadFile(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local toc = ReadFile(dir .. "/AeonDungeonJournal.toc")
assert(toc:find("## Title: Dungeon Codex", 1, true), "Das ist nicht Dungeon Codex")
assert(toc:find("## X-License: GPL-2.0", 1, true), "Lizenz hat sich geaendert – erst pruefen")
local version = assert(toc:match("## Version: ([%w%.%-]+)"), "Version fehlt")
local data = ReadFile(dir .. "/Data.lua")

-- Codex-Schluessel -> Guild-Trip-Katalog (src/ONE_Dungeons/Catalog.lua)
local WANTED = {
    {codex = "HallOfThanes", key = "thanes"},
    {codex = "RuinsOfLordaeron", key = "ruins"},
    {codex = "ExcavationSite", key = "excavation"},
    {codex = "CityOfDalaran", key = "dalaran"},
}

local function Block(codexKey)
    local s = data:find('key = "' .. codexKey .. '"', 1, true)
    assert(s, "Dungeon fehlt in Dungeon Codex: " .. codexKey)
    local b = assert(data:find("bosses = {", s, true), "bosses fehlt: " .. codexKey)
    local e = assert(data:find("quests = {", b, true), "quests fehlt: " .. codexKey)
    return data:sub(b, e - 1)
end

local function Numbers(text)
    local list = {}
    for n in (text or ""):gmatch("%d+") do list[#list + 1] = tonumber(n) end
    return list
end

local function Boss(line)
    local npc = tonumber(line:match("npc = (%d+)"))
    if not npc then return nil end
    local b = {npc = npc}
    b.name = assert(line:match('name = "([^"]+)"'), "Bossname fehlt: " .. npc)
    b.de = line:match('deDE = "([^"]+)"')
    b.level = tonumber(line:match("[,{] level = (%d+)"))
    b.rare = line:find("rare = true", 1, true) and true or nil
    b.items = Numbers(line:match("items = {([^}]*)}"))
    assert(#b.items > 0, "Boss ohne Beute: " .. b.name)
    local drops = line:match("drops = {([^}]*)}")
    if drops then
        b.drops = {}
        for id, pct in drops:gmatch("%[(%d+)%] = ([%d%.]+)") do b.drops[tonumber(id)] = tonumber(pct) end
    end
    return b
end

local function Q(s) return string.format("%q", s) end

local out = {}
local function W(s) out[#out + 1] = s end
W("-- ERZEUGT mit scripts/import_codex.lua – nicht von Hand aendern.")
W("-- Bosse und Beute aus \"Dungeon Codex\" " .. version .. " von Baxter × DLDVLPR (CurseForge-Projekt 1715265).")
W("-- Dungeon Codex steht unter GPL-2.0; Nutzung dieser Boss-/Beute-Daten in Guild Trip unter")
W("-- GPL-3.0-or-later ausdruecklich erlaubt vom Autor am 19.11.2026 (docs/ANFRAGEN_DATEN.md, THIRD_PARTY.md).")
W("local _, dungeons = ...")
W("")
W("dungeons.BossData = {")
W("    source = {name = \"Dungeon Codex\", author = \"Baxter × DLDVLPR\", version = " .. Q(version)
    .. ", license = \"GPL-2.0, Daten mit Erlaubnis unter GPL-3.0-or-later\", url = \"https://www.curseforge.com/wow/addons/dungeon-codex\"},")
local total, items = 0, 0
for _, want in ipairs(WANTED) do
    W("    " .. want.key .. " = {")
    for line in Block(want.codex):gmatch("[^\n]+") do
        local b = Boss(line)
        if b then
            total, items = total + 1, items + #b.items
            local parts = {"npc = " .. b.npc, "name = " .. Q(b.name)}
            if b.de and b.de ~= b.name then parts[#parts + 1] = "de = " .. Q(b.de) end
            if b.level then parts[#parts + 1] = "level = " .. b.level end
            if b.rare then parts[#parts + 1] = "rare = true" end
            parts[#parts + 1] = "items = {" .. table.concat(b.items, ", ") .. "}"
            if b.drops and next(b.drops) then
                local d = {}
                for _, id in ipairs(b.items) do
                    if b.drops[id] then d[#d + 1] = "[" .. id .. "] = " .. b.drops[id] end
                end
                parts[#parts + 1] = "drops = {" .. table.concat(d, ", ") .. "}"
            end
            W("        {" .. table.concat(parts, ", ") .. "},")
        end
    end
    W("    },")
end
W("}")
io.write(table.concat(out, "\n"), "\n")
io.stderr:write(string.format("Dungeon Codex %s: %d Dungeons, %d Bosse, %d Gegenstaende\n", version, #WANTED, total, items))
