-- Offline-Test: Quest-Fuehrung (ONE_Leveling Planer) mit echten Daten – Schurke (Mensch) Stufe 15 in Westfall.
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
for _, f in ipairs({"ONE_QuestDB/Data", "ONE_QuestDB/Names_deDE", "ONE_Leveling/Rewards"}) do assert(loadfile(root .. "/" .. f .. ".lua"))() end
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local Q = GuildTripQuestDB
-- EP-Regeln
assert(P.QuestXP(1000, 10, 15) == 1000 and P.QuestXP(1000, 10, 16) == 800 and P.QuestXP(1000, 10, 25) == 100)
assert(P.MobXP(15, 15) == 120 and P.MobXP(15, 5) == 0 and P.MobXP(15, 14) > 100)
-- Fake-Welt: Kalimdor = Kontinent 1, sonst 0; Karten nebeneinander
local KAL = {}
for _, m in ipairs({1411,1412,1413,1438,1439,1440,1441,1442,1443,1444,1445,1446,1447,1448,1449,1450,1451,1452,1454,1456,1457}) do KAL[m] = true end
local function World(m, x, y) return KAL[m] and 1 or 0, (m % 50) * 3000 + x * 3000, y * 3000 end
local done = {}
for id, e in pairs(Q.q) do if e[1] < 10 and e[1] > 0 then done[id] = true end end
local log = {}
local ctx = {
    me = {level = 15, class = 8, race = 1, faction = "Alliance", inGroup = false, mapID = 1436, x = .56, y = .47},
    done = function(id) return done[id] == true end,
    inLog = function(id) return log[id] ~= nil end,
    complete = function(id) return log[id] == "done" end,
    world = World, tempo = "need",
    catalog = function(key) return ({dm = {min = 17}, wc = {min = 15}, rfc = {min = 13}})[key] or {min = 99} end,
    entrance = function(key) if key == "dm" then return {1436, .425, .717} end end,
}
local plan = assert(P:Plan(ctx))
assert(#plan.steps > 5, "Plan hat Schritte")
-- Pflicht: Todesminen-Kette – Endquest 166 (Dungeon) zieht Vorquests 65 ff. nach sich
assert(plan.chosen[166] == "dungeon", "Todesminen-Quest Pflicht")
assert(plan.chosen[65] == "pre", "Vorquest der Kette Pflicht: " .. tostring(plan.chosen[65]))
assert(plan.chosen[155] == "pre", "Begleitquest der Kette Pflicht: " .. tostring(plan.chosen[155]))
-- keine Horde-Quest (Durotar)
for id in pairs(plan.chosen) do assert(Q.q[id][3] == 0 or P.Band(Q.q[id][3], 1) > 0, "nur fuer Menschen: " .. id) end
-- Reihenfolge: Annehmen vor Abgeben, Vorquest abgegeben vor Folgequest angenommen
local at = {}
for i, s in ipairs(plan.steps) do for _, a in ipairs(s.actions) do at[a.kind .. a.id] = at[a.kind .. a.id] or i end end
for id in pairs(plan.chosen) do
    if at["turnin" .. id] and at["accept" .. id] then assert(at["accept" .. id] <= at["turnin" .. id], "annehmen vor abgeben " .. id) end
end
if at["accept132"] and at["turnin65"] then assert(at["turnin65"] <= at["accept132"], "Kette in Reihenfolge") end
-- Begleitquest 155: ist die Kette bis 142 erledigt, kommt sie bald – und vor der Todesminen-Quest 166
for _, id in ipairs({65, 132, 135, 141, 142}) do done[id] = true end
local p3 = P:Plan(ctx)
local at3 = {}
for i, s in ipairs(p3.steps) do for _, a in ipairs(s.actions) do at3[a.kind .. a.id] = at3[a.kind .. a.id] or i end end
assert(at3["accept155"] and at3["turnin155"] and at3["accept166"] and at3["turnin155"] <= at3["accept166"], "Begleitquest vor der Todesminen-Quest")
for _, id in ipairs({65, 132, 135, 141, 142}) do done[id] = nil end
-- Ausgelassen hat Gruende
assert(#plan.skipped > 0)
for _, o in ipairs(plan.skipped) do assert(P.SkipText(o, plan), "Grund fehlt " .. o.id) end
-- Abwaehlen wirkt
local any
for id, why in pairs(plan.chosen) do if why == "xp" then any = id break end end
if any then
    ctx.override = {[any] = "no"}
    local p2 = P:Plan(ctx)
    assert(not p2.chosen[any] and p2.info[any].skip, "abgewählt")
    ctx.override = nil
end
-- Tempo "Gruendlich" nimmt mehr mit als "Nur das Noetigste"
local n1 = 0 for _ in pairs(plan.chosen) do n1 = n1 + 1 end
ctx.tempo = "all"
local n2 = 0 for _ in pairs(P:Plan(ctx).chosen) do n2 = n2 + 1 end
assert(n2 > n1, "gruendlich > noetigste " .. n1 .. "/" .. n2)
-- 0.7.0 Gebietsbloecke: gleiche Auswahl, nur Reihenfolge; weniger Gebietswechsel; Bloecke stimmen
for _, tempo in ipairs({"need", "all"}) do
    ctx.tempo = tempo
    ctx.zoneBlocks = false
    local flat = P:Plan(ctx)
    ctx.zoneBlocks = nil
    local zoned = P:Plan(ctx)
    for id, why in pairs(flat.chosen) do assert(zoned.chosen[id] == why, "Auswahl gleich " .. id) end
    for id in pairs(zoned.chosen) do assert(flat.chosen[id], "keine Zusatzquest " .. id) end
    local function Switches(pl) local n, last = 0 for _, st in ipairs(pl.steps) do if st.mapID and st.mapID ~= last then n, last = n + 1, st.mapID end end return n end
    assert(Switches(zoned) <= Switches(flat), tempo .. ": Wechsel " .. Switches(zoned) .. " > " .. Switches(flat))
    local count, mins = 0, 0
    for i, b in ipairs(zoned.blocks) do
        assert(b.first <= b.last and b.steps == b.last - b.first + 1)
        if i > 1 then assert(b.first == zoned.blocks[i - 1].last + 1) end
        count, mins = count + b.steps, mins + b.minutes
    end
    assert(count == #zoned.steps and math.abs(mins - zoned.minutes) < .01, "Bloecke decken den Plan ab")
end
ctx.tempo = "need"
if os.getenv("SHOW") then
    ctx.tempo = "need"
    plan = P:Plan(ctx)
    for i, s in ipairs(plan.steps) do
        local t = {}
        for _, a in ipairs(s.actions) do t[#t + 1] = a.kind .. " " .. (Q.titles[a.id] or a.id) .. " [" .. tostring(plan.chosen[a.id]) .. " " .. math.floor(plan.info[a.id].epm) .. "]" end
        print(i, s.kind, s.mapID, string.format("%.1f", s.walk or 0), s.key or "", table.concat(t, " | "))
    end
    print("min", plan.minutes, "xp", plan.xp, "grind", plan.grind)
    for i = 1, 12 do local o = plan.skipped[i] if o then print("skip", Q.titles[o.id], P.SkipText(o, plan)) end end
end
print("OK: Quest-Fuehrung Planer")
