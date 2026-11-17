-- Offline-Test 0.7.0: Monster hauen – wann lohnt es sich, und wo?
local root = arg[1] or "src"
GuildTripQuestDB = {q = {}, n = {},
    m = {
        -- {min, max, feindlich, karte, x, y, anzahl, ...}
        [100] = {15, 16, 3, 1, 500, 500, 20},             -- dichtes Lager, passende Stufe, nah
        [101] = {15, 15, 3, 1, 900, 900, 5},              -- duennes Lager
        [102] = {25, 26, 3, 1, 500, 500, 30},             -- viel zu hoch
        [103] = {5, 6, 3, 1, 500, 500, 30},               -- grau (0 EP)
        [104] = {15, 16, 1, 1, 500, 500, 30},             -- nur fuer die Allianz feindlich
        [105] = {15, 16, 3, 2, 500, 500, 30},             -- anderer Kontinent
        [106] = {15, 16, 3, 1, 520, 500, 3, 1, 100, 100, 9}, -- zu kleines Lager, zweites zaehlt
    },
    mobNames = {[100] = "Gnoll", [101] = "Wolf"},
}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Grind.lua"))("ONE_Leveling", lev)
local P, Gr = lev.Planner, lev.Grind
-- Karte 1 auf Kontinent 1 (1000 x 1000 Yards), Karte 2 auf Kontinent 2
local function World(m, x, y) return m, x * 1000, y * 1000 end
local ctx = {me = {level = 15, faction = "Horde", mapID = 1, x = .5, y = .45}, world = World, speed = 7}

-- 1) Lager: passend, feindlich, gleicher Kontinent, nicht grau/zu hoch; je Gegner das beste
local camps = Gr:Camps(ctx)
local names = {}
for _, c in ipairs(camps) do names[#names + 1] = c.npc end
table.sort(names)
assert(table.concat(names, ",") == "100,101,106", table.concat(names, ","))
assert(camps[1].npc == 100 and camps[1].name == "Gnoll", "dichtes nahes Lager zuerst")
local wolf
for _, c in ipairs(camps) do if c.npc == 101 then wolf = c end if c.npc == 106 then assert(c.x == .1 and c.count == 9) end end
assert(wolf.epm < camps[1].epm, "duennes Lager langsamer")
assert(math.abs(camps[1].epm - P.MobXP(15, 16) * 60 / Gr.KillSeconds(15, 15.5, 20)) < .01)
-- Allianz sieht auch 104
ctx.me.faction = "Alliance"
local found
for _, c in ipairs(Gr:Camps(ctx)) do if c.npc == 104 then found = true end end
assert(found)
ctx.me.faction = "Horde"

-- 2) Empfehlung: leerer Plan -> lohnt; schneller Plan -> nicht; langsamer Plan -> lohnt
local a = Gr:Advice(ctx, {steps = {}, minutes = 0, xp = 0})
assert(a.worth and a.reason == "empty" and #a.camps == 3)
local function Plan(xp, minutes)
    return {steps = {{kind = "turnin", gain = xp, cost = minutes}}, blocks = {{first = 1, last = 1}}, xp = xp, minutes = minutes}
end
a = Gr:Advice(ctx, Plan(100000, 10))
assert(not a.worth and a.planEPM == 10000)
a = Gr:Advice(ctx, Plan(100, 10))
assert(a.worth and a.reason == "faster" and a.planEPM == 10)
-- Dungeon-Halt zaehlt nicht zum Plan-Tempo
local pl = {steps = {{kind = "turnin", gain = 600, cost = 2}, {kind = "dungeon", gain = 0, cost = 45}}, blocks = {{first = 1, last = 2}}, xp = 600, minutes = 47}
assert(Gr.PlanEPM(pl) == 300)
-- 2b) Regel (Nutzer): Monster nur, wenn es schneller zur naechsten Stufe bringt als die Quests
local best = Gr:Camps(ctx)[1]
ctx.xpNeed = 3000
local farmMin = Gr.FarmMinutes(best, 3000)
assert(math.abs(farmMin - (best.travel + 3000 / best.epm)) < .001)
-- Quests: 3 Schritte, Stufe nach dem zweiten erreicht
local function Steps(list)
    local steps = {}
    for i, g in ipairs(list) do steps[i] = {kind = "turnin", gain = g[1], cost = g[2]} end
    return {steps = steps, blocks = {{first = 1, last = #steps}}}
end
local fast = Steps({{2000, 3}, {1500, 4}, {500, 1}})          -- Stufe in 7 Min.
assert(Gr.QuestMinutes(fast, 3000) == 7)
a = Gr:Advice(ctx, fast)
assert(not a.worth and #a.camps == 0 and a.questMinutes == 7, "Quests schneller: kein Farm-Hinweis")
local slow = Steps({{500, 20}, {500, 20}, {2500, 30}})        -- Stufe erst nach 70 Min.
a = Gr:Advice(ctx, slow)
assert(a.worth and a.reason == "faster" and a.questMinutes == 70 and a.camps[1].minutes < 70 / Gr.BETTER, "Farmen schneller")
for i = 2, #a.camps do assert(a.camps[i].minutes >= a.camps[i - 1].minutes, "schnellstes Lager zuerst") end
-- Plan reicht nicht bis zur Stufe
a = Gr:Advice(ctx, Steps({{500, 5}}))
assert(a.worth and a.reason == "noLevel" and a.questMinutes == nil)
-- knapp: nur 5 % schneller ist nicht "spuerbar"
local same = Steps({{3000, farmMin * 1.05}})
assert(not Gr:Advice(ctx, same).worth, "knapp schneller reicht nicht")
ctx.xpNeed = nil

-- 3) Ohne Gegnerdaten: nichts, kein Fehler
local m = GuildTripQuestDB.m
GuildTripQuestDB.m = nil
a = Gr:Advice(ctx, Plan(100, 10))
assert(not a.worth and #a.camps == 0)
GuildTripQuestDB.m = m
print("OK test_grind_111")
