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
            assert(s[4] >= 0 and s[4] <= 100, "Chance " .. item) -- 0 = Chance unbekannt
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
-- Rezept-Herkunft: Lehrer mit Ort, seltene Weltdrops, Haendler
assert(type(G.learn) == "table" and type(G.places) == "table")
local learned, trainers = 0, 0
for spell, list in pairs(G.learn) do
    learned = learned + 1
    for _, l in ipairs(list) do
        assert(({t = 1, v = 1, d = 1, w = 1, q = 1, r = 1})[l[1]], "Art " .. tostring(l[1]))
        if l[1] == "t" or l[1] == "v" or l[1] == "w" then
            local p = G.places[l[2]]
            assert(p and p[1] > 1000 and p[2] >= 0 and p[2] <= 1 and p[3] >= 0 and p[3] <= 1, "Ort fehlt fuer " .. l[2])
            if l[1] == "t" then trainers = trainers + 1 end
        end
    end
end
assert(learned > 500 and trainers > 1000, learned .. "/" .. trainers)
-- Feine Lederhandschuhe (2158): seltener Weltdrop; Zauber 2160 beim Lederverarbeitungslehrer ab 40
assert(G.learn[2158] and G.learn[2158][1][1] == "r")
local t = G.learn[2160] and G.learn[2160][1]
assert(t and t[1] == "t" and t[3] == 40)
print("OK test_geardata_121")
