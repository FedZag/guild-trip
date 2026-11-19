-- Guild Trip: gesammelte Dungeon-Gegner (ONE_Dungeons/Roster.lua) mit der Beute aus forever-db verbinden.
-- Liest ProjectONEDB.dungeons.roster aus der SavedVariables-Datei und item_source.jsonl/item.jsonl aus
-- forever-db (Polestar, GPL-3.0, github.com/fitzforge/polestar/tree/main/forever-db) und zeigt je Dungeon:
-- Bosse (Name in Spielsprache, Gegner-Nummer) und was sie laut forever-db fallen lassen.
-- Noch kein Datenbau: erst sehen, wie vollstaendig es ist (Nutzer 19.11.2026, "Weg 1").
--   lua5.1 scripts/report_dungeon_finds.lua <WTF/.../SavedVariables/ONE_Core.lua> <forever-db-Ordner> [nur Bosse=1]
local svFile, fdb, bossesOnly = arg[1], arg[2], arg[3] ~= "0"
assert(svFile and fdb, "Aufruf: lua5.1 scripts/report_dungeon_finds.lua <ONE_Core.lua> <forever-db> [nur Bosse=1]")
local env = {}
local chunk = assert(loadfile(svFile))
setfenv(chunk, env)
chunk()
local db = env.ProjectONEDB or {}
local roster = db.dungeons and db.dungeons.roster or {}

-- benoetigte Gegner
local want = {}
for _, e in pairs(roster) do
    for id, n in pairs(e.npcs or {}) do if not bossesOnly or n.boss then want[tonumber(id)] = true end end
end
-- Beute je Gegner (nur einfache JSON-Zeilen: {"chance":x,"id":n,"item":n,"kind":"npc"})
local drops, items = {}, {}
for line in io.lines(fdb .. "/item_source.jsonl") do
    if line:find('"kind":"npc"', 1, true) then
        local id = tonumber(line:match('"id":(%d+)'))
        if id and want[id] then
            local item = tonumber(line:match('"item":(%d+)'))
            drops[id] = drops[id] or {}
            drops[id][#drops[id] + 1] = {item = item, chance = tonumber(line:match('"chance":([%d.]+)'))}
            items[item] = true
        end
    end
end
local names = {}
for line in io.lines(fdb .. "/item.jsonl") do
    local id = tonumber(line:match('"id":(%d+)'))
    if id and items[id] then names[id] = line:match('"name":"(.-)"') end
end

local keys = {}
for k in pairs(roster) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do
    local e = roster[k]
    local ids = {}
    for id, n in pairs(e.npcs or {}) do if not bossesOnly or n.boss then ids[#ids + 1] = tonumber(id) end end
    table.sort(ids)
    print(("== %s: %d Gegner%s"):format(k, #ids, bossesOnly and " (Bosse)" or ""))
    for _, id in ipairs(ids) do
        local n = e.npcs[id] or {}
        local list = drops[id] or {}
        print(("  %s (%d)%s: %d Gegenstände"):format(n.name or "?", id, n.boss and " [Boss]" or "", #list))
        table.sort(list, function(a, b) return (a.chance or 0) > (b.chance or 0) end)
        for i = 1, math.min(8, #list) do
            local d = list[i]
            print(("    %s (%d)%s"):format(names[d.item] or "?", d.item, d.chance and (" " .. d.chance .. " %") or ""))
        end
    end
end
if #keys == 0 then print("Noch keine gesammelten Dungeon-Gegner in dieser Datei.") end
