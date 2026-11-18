-- Ausruestungsdaten (scripts/import_gear.py): Aufbau, Dungeon-Drops vorhanden, Stichproben.
local root = arg[1] or "src"
assert(loadfile(root .. "/ONE_Leveling/GearData.lua"))()
local G = GuildTripGear
assert(type(G.items) == "table" and type(G.src) == "table" and type(G.npcs) == "table")
local count, drops, quests, crafts = 0, 0, 0, 0
local dungeons = {}
for item, line in pairs(G.items) do
    count = count + 1
    local inv, ilvl, req, q = line:match("^(%d+) (%d+) (%d+) (%d+)")
    assert(inv and tonumber(inv) > 0, "Platz fehlt: " .. item)
    assert(tonumber(req) <= 60 and tonumber(q) <= 5)
    local src = G.src[item]
    assert(type(src) == "table" and #src > 0, "keine Herkunft: " .. item)
    for _, s in ipairs(src) do
        if s[1] == "q" then quests = quests + 1 assert(type(s[2]) == "number")
        elseif s[1] == "d" then
            drops = drops + 1
            dungeons[s[2]] = true
            assert(s[4] > 0 and s[4] <= 100, "Chance " .. item)
        elseif s[1] == "c" then crafts = crafts + 1
        else assert(s[1] == "w", "unbekannte Herkunft " .. tostring(s[1])) end
    end
end
assert(count > 3000 and drops > 1000 and quests > 1500 and crafts > 1000, ("zu wenig Daten: %d/%d/%d/%d"):format(count, drops, quests, crafts))
-- klassische Dungeons bis 60 alle mit Beute
for _, key in ipairs({"rfc", "wc", "dm", "sfk", "bfd", "stocks", "gnomer", "rfk", "sm", "rfd", "ulda", "zf", "mara", "st", "brd", "lbrs", "dme", "scholo", "stratlive"}) do
    assert(dungeons[key], "keine Beute: " .. key)
end
-- Stichproben: Smites maechtiger Hammer (Mr. Smite, Todesminen), Cookies Fleischklopfer
local function Has(item, key, npc)
    for _, s in ipairs(G.src[item] or {}) do if s[1] == "d" and s[2] == key and s[3] == npc then return true end end
end
assert(Has(7230, "dm", 646) and Has(5197, "dm", 645) and G.npcs[639] == "Edwin VanCleef")
print("OK test_geardata_121")
