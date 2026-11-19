-- 0.7.1 Ausruestung auf deinem Weg: bestes Teil je Platz aus Quest/Dungeon/Herstellung,
-- Klassen-/Ruestungsgrenzen, Gilden-Hersteller, "haelt bis".
local root = arg[1] or "src"
local level, classFile = 15, "WARRIOR"
_G.UnitLevel = function() return level end
_G.UnitClass = function() return "Krieger", classFile end
_G.UnitFactionGroup = function() return "Horde" end
_G.GetLocale = function() return "deDE" end
_G.GetInventoryItemLink = function() return nil end
_G.GetNumGuildMembers = function() return 1 end
_G.GetGuildRosterInfo = function() return "Gildi-Forever", nil, nil, 30, nil, nil, nil, nil, true end
local ONE = { ns = {}, modules = {} }
_G.ProjectONE = ONE
function ONE:Print() end
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/GearData.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_QuestDB/Data.lua"))("ONE_QuestDB", {})
assert(loadfile(root .. "/ONE_QuestDB/Services.lua"))("ONE_QuestDB", {})
local dungeons = {}
assert(loadfile(root .. "/ONE_Dungeons/Catalog.lua"))("ONE_Dungeons", dungeons)
ONE.ns.dungeons = dungeons
local W = assert(loadfile(root .. "/ONE_Leveling/Way.lua"))("ONE_Leveling", lev)
assert(lev.Way == W and W.Data())

-- Eintrag lesen
local it = W.Item(872)
assert(it.inv == 17 and it.req == 16 and it.quality == 3 and it.stats.str == 7, "Werte gelesen")
assert(math.abs(it.stats.dps - (52 + 78) / 2 / 3.3) < .1, "Waffenschaden pro Sekunde")

-- Grenzen: Krieger unter 40 traegt Kette, aber keine Platte; Magier nur Stoff und Stab/Schwert/Dolch/Zauberstab
assert(W.MaxArmor("WARRIOR", 20) == 3 and W.MaxArmor("WARRIOR", 40) == 4)
assert(W.MaxArmor("HUNTER", 39) == 2 and W.MaxArmor("MAGE", 60) == 1)
assert(W.Usable({class = 4, sub = 3, inv = 5, stats = {}}, "WARRIOR", 20))
assert(not W.Usable({class = 4, sub = 4, inv = 5, stats = {}}, "WARRIOR", 20))
assert(not W.Usable({class = 4, sub = 2, inv = 5, stats = {}}, "MAGE", 20))
assert(W.Usable({class = 4, sub = 2, inv = 16, stats = {}}, "MAGE", 20), "Umhang zaehlt nicht als Ruestungsart")
assert(not W.Usable({class = 2, sub = 1, stats = {}}, "MAGE", 20) and W.Usable({class = 2, sub = 10, stats = {}}, "MAGE", 20))
assert(not W.Usable({class = 4, sub = 6, inv = 14, stats = {}}, "ROGUE", 20) and W.Usable({class = 4, sub = 6, inv = 14, stats = {}}, "SHAMAN", 20))
assert(not W.Usable({class = 4, sub = 0, inv = 2, classMask = 128, stats = {}}, "WARRIOR", 20), "Klassenmaske")

-- Plan: Krieger Stufe 15
local ctx = W:Context()
assert(ctx.weights and ctx.weights.str, "Grundgewichte ohne Klassenmodul")
local plan = W:Plan(ctx)
assert(#plan == #W.SLOTS)
local kinds, filled = {}, 0
for _, row in ipairs(plan) do
    if row.now then
        filled = filled + 1
        local item = row.now.item
        assert(W.ReqLevel(item) <= level, row.slot.key .. " ueber deiner Stufe")
        assert(W.Usable(item, "WARRIOR", level), row.slot.key .. " nicht tragbar")
        for _, s in ipairs(row.now.sources) do kinds[s.kind] = true assert(s.sure) end
        if row.holdsTo then assert(row.holdsTo > level) end
        if row.next then assert(W.ReqLevel(row.next.item) > level and W.ReqLevel(row.next.item) <= level + W.HORIZON) end
    end
end
assert(filled >= 10, "fast jeder Platz gefuellt: " .. filled)
assert(kinds.d, "Dungeon-Beute wird vorgeschlagen")
assert(kinds.q, "Quest-Belohnungen werden vorgeschlagen")
-- Nutzer-Wunsch: auf Stufe 15 keine Quest-Belohnung als Bestes, wenn ein Dungeon klar Besseres hat
for _, row in ipairs(plan) do
    if row.now and row.now.sources[1].kind == "q" then
        for id in pairs(W.Data().items) do
            local o = W.Item(id)
            if o and W.SlotOf(o) == row.slot and W.Usable(o, "WARRIOR", level) and W.ReqLevel(o) <= level and o.score > row.now.item.score then
                local ok = false
                for _, s in ipairs(W:Sources(id, ctx)) do
                    if s.kind == "d" and s.sure and (not s.min or s.min <= level + 2) then ok = true end
                end
                assert(not ok, "Dungeon-Teil " .. id .. " ist besser als die Quest-Belohnung fuer " .. row.slot.key)
            end
        end
    end
end

-- Magier: nur Stoff, passende Waffen
classFile = "MAGE"
for _, row in ipairs(W:Plan(W:Context())) do
    if row.now then
        local i = row.now.item
        if i.class == 4 and i.inv ~= 16 then assert(not (i.sub >= 2 and i.sub <= 4), "Magier ohne Leder/Kette/Platte") end
        if i.class == 2 then assert(i.sub == 7 or i.sub == 10 or i.sub == 15 or i.sub == 19, "Magier-Waffe " .. i.sub) end
    end
end

-- Herstellung: Gildenmitglied kann das Rezept (Zauber), online zuerst; Anfrage-Text
local craftItem, craftSpell
for id, list in pairs(W.Data().src) do
    for _, s in ipairs(list) do
        if s[1] == "c" and s[2] == "Tailoring" then
            -- ein Rezept, das ein Horde-Lehrer beibringt
            for _, l in ipairs(W.Data().learn[s[4]] or {}) do
                if l[1] == "t" and W.NpcFits(l[2], "Horde") then craftItem, craftSpell = id, s[4] end
            end
        end
    end
    if craftItem then break end
end
assert(craftItem)
ONE.ns.crafting = {
    Recipes = {Catalog = function() return {{recipeID = craftSpell, itemID = craftItem, crafters = {{name = "Gildi-Forever", skill = 150}}}} end},
    Trainers = {MyProfessions = function() return {} end},
}
local c
for _, s in ipairs(W:Sources(craftItem, {faction = "Horde", level = 15})) do if s.kind == "c" then c = s end end
assert(c and c.status == "guild" and c.guild[1].online and c.prof == "Schneiderei", "Gilde kann es herstellen")
assert(W.SourceText(c):find("Gildi", 1, true))
-- eigener Beruf mit zu wenig Fertigkeit: "bald selbst" mit Lehrer
ONE.ns.crafting.Recipes.Catalog = function() return {} end
ONE.ns.crafting.Trainers.MyProfessions = function() return {Schneiderei = {skill = 1, max = 75}} end
for _, s in ipairs(W:Sources(craftItem, {faction = "Horde", level = 15})) do if s.kind == "c" then c = s end end
assert(c.status == "soon" or c.status == "learn", c.status)
assert(c.learn[1].kind == "t" and W.LearnText(c.learn[1]):find("Lehrer", 1, true), "Lehrer zuerst")
-- selbst gelernt
ONE.ns.crafting.Recipes.Catalog = function() return {{recipeID = craftSpell, crafters = {{name = "Ich", me = true}}}} end
for _, s in ipairs(W:Sources(craftItem, {faction = "Horde", level = 15})) do if s.kind == "c" then c = s end end
assert(c.status == "self")

-- Lehrer der falschen Fraktion fallen weg
local q = rawget(_G, "GuildTripQuestDB")
local hordeOnly, allyOnly
for npc, t in pairs(q.trainers) do
    if t[6] == 2 then hordeOnly = npc elseif t[6] == 1 then allyOnly = npc end
end
assert(W.NpcFits(hordeOnly, "Horde") and not W.NpcFits(hordeOnly, "Alliance") and not W.NpcFits(allyOnly, "Horde"))
assert(W.Money(12345) == "1 G 23 S" and W.Money(250) == "2 S" and W.Money(7) == "7 K")
-- Nutzer 19.11.2026: Halle der Thanen (Eingang bei Eisenschmiede) nicht fuer die Horde vorschlagen,
-- Ruinen von Lordaeron (vor Unterstadt) nicht fuer die Allianz
assert(W.EnemyDungeon("thanes", "Horde") and not W.EnemyDungeon("thanes", "Alliance"))
assert(W.EnemyDungeon("ruins", "Alliance") and not W.EnemyDungeon("ruins", "Horde"))
assert(not W.EnemyDungeon("dm", "Horde") and not W.EnemyDungeon("thanes", nil))
local function HasDungeon(id, faction, key)
    for _, s in ipairs(W:Sources(id, {faction = faction, level = 15})) do if s.kind == "d" and s.dungeon == key then return true end end
end
assert(not HasDungeon(270227, "Horde", "thanes") and HasDungeon(270227, "Alliance", "thanes"), "Thanen-Beute nur fuer Allianz")
print("OK test_way_124")
