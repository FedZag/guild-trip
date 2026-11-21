-- Offline-Test: Quest-Fuehrung (ONE_Leveling Planer) mit echten Daten – Schurke (Mensch) Stufe 15 in Westfall.
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
for _, f in ipairs({"ONE_QuestDB/Data", "ONE_QuestDB/Names_deDE", "ONE_Leveling/Rewards"}) do assert(loadfile(root .. "/" .. f .. ".lua"))() end
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local Q = GuildTripQuestDB
-- Belohnungsdaten kompakt (Text) – Lesen bei Bedarf
do
    local R = GuildTripLeveling
    assert(type(R.r[166]) == "string" and type(R.i[2074]) == "string", "als Text gespeichert")
    local r = P.Rew(R, 166)
    assert(r[1] == 0 and r[3] == 2 and r[4] == false and #r[5] == 3 and r[5][1] == 6087, "Quest 166 gelesen")
    local it = P.Item(R, 2074)
    assert(it[3] == 19 and it[5] == 2 and it[6] == 7 and it[10] == false, "Gegenstand gelesen")
    assert(P.Rew(R, -1) == nil and P.Item(R, -1) == nil)
end
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
-- Sehr empfohlene Reihe (Schlafsack): ab 14 dabei, nur die eigene Fraktion, nicht Pflicht, mit Warnhinweis
do
    assert(plan.chosen[79008] == "rec", "Allianz-Start der Schlafsack-Reihe empfohlen: " .. tostring(plan.chosen[79008]))
    assert(plan.chosen[79007] == nil, "Horde-Start nicht für Allianz")
    assert(plan.chosen[79976] == "rec", "Ende der Reihe (Arathi, anderer Kontinent egal) empfohlen")
    local tagged = false
    for _, t in ipairs(plan.info[79976].tags) do if t == "rec" then tagged = true end end
    assert(tagged, "Zeichen EMPFOHLEN")
    assert(P.RecHint(79974, "Horde") and P.RecHint(79974, "Alliance") == nil, "Loch Modan nur für Horde heikel")
    assert(P.RecHint(79975, "Alliance"):find("Arathi"))
    local low = {}
    for k, v in pairs(ctx) do low[k] = v end
    low.me = {}
    for k, v in pairs(ctx.me) do low.me[k] = v end
    low.me.level = 12
    assert(P:Plan(low).chosen[79008] == nil, "unter Stufe 14 noch nicht")
    local skip = {}
    for k, v in pairs(ctx) do skip[k] = v end
    skip.override = {[79008] = "no"}
    local ps = P:Plan(skip)
    assert(ps.chosen[79008] == nil and ps.chosen[79976] == nil, "abwählbar: ohne Start fällt die Reihe raus")
end
-- Mindeststufe: nichts annehmen, was man noch nicht annehmen kann (Spieltest 19.11.2026, Ebru mit Stufe 13)
do
    local c2 = {}
    for k, v in pairs(ctx) do c2[k] = v end
    c2.me = {}
    for k, v in pairs(ctx.me) do c2.me[k] = v end
    c2.me.xp, c2.me.xpMax = 0, 1e9 -- im Plan keine neue Stufe
    local p2 = P:Plan(c2)
    local accepts = 0
    for _, st in ipairs(p2.steps) do
        for _, a in ipairs(st.actions) do
            if a.kind == "accept" then
                accepts = accepts + 1
                assert((Q.q[a.id][2] or 0) <= c2.me.level, "zu frueh angenommen: " .. a.id .. " ab " .. tostring(Q.q[a.id][2]))
            end
        end
    end
    assert(accepts > 0, "es wird trotzdem etwas angenommen")
    -- mit EP im Plan: hoehere Quests kommen spaeter, nach dem Stufenaufstieg
    c2.me.xp, c2.me.xpMax = 11000, 11400
    -- (Schleifen 21.11.2026: ob dann Quests der naechsten Stufe drankommen, entscheidet die Route – geprueft wird,
    -- dass nie etwas vor der im Plan erreichten Stufe angenommen wird und der Aufstieg im Plan steht)
    local p3, lvl, ups = P:Plan(c2), c2.me.level, 0
    for _, st in ipairs(p3.steps) do
        for _, a in ipairs(st.actions) do
            if a.kind == "accept" then assert((Q.q[a.id][2] or 0) <= lvl, "vor dem Aufstieg angenommen: " .. a.id) end
        end
        if st.levelUp then lvl, ups = st.levelUp, ups + 1 end
    end
    assert(ups > 0, "Aufstieg im Plan")
end
-- Quest-Ziele tragen ihr Gebiet (Spawnpunkte, Weltkoordinaten) fuer Pfeil und Entfernung
do
    local objs, withArea = 0, 0
    for _, st in ipairs(plan.steps) do
        if st.kind == "obj" then
            objs = objs + 1
            if st.area then
                withArea = withArea + 1
                assert(#st.area <= P.AREA_MAX and type(st.area[1][1]) == "number" and type(st.area[1][2]) == "number")
            end
        end
    end
    assert(objs > 0 and withArea > 0, "Ziel-Schritte mit Gebiet: " .. withArea .. "/" .. objs)
end
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
-- (Begleitquest ist Stufe 18: Ziel erst ab Stufe 16 – Spieltest 19.11.2026, P.OBJ_AHEAD)
for _, id in ipairs({65, 132, 135, 141, 142}) do done[id] = true end
ctx.me.level = 16
local p3 = P:Plan(ctx)
ctx.me.level = 15
do -- mit 15 noch nicht: Begleitquest (18) zu stark
    local p15 = P:Plan(ctx)
    for _, s in ipairs(p15.steps) do for _, a in ipairs(s.actions) do assert(not (a.kind == "obj" and a.id == 155), "155 mit 15") end end
end
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
-- 0.7.0 Gebietsuebersicht: nur Anzeige – Plan unveraendert, aktuelles Gebiet zuerst, Plan-Quests als "plan"
do
    local pl = P:Plan(ctx)
    local before = {}
    for id, why in pairs(pl.chosen) do before[id] = why end
    local zones = P:Zones(ctx, pl)
    assert(#zones > 0 and zones[1].mapID == 1436, "Westfall zuerst")
    for id, why in pairs(before) do assert(pl.chosen[id] == why) end
    local seen = {}
    for _, z in ipairs(zones) do
        assert(z.done <= z.total)
        for _, q in ipairs(z.quests) do
            seen[q.id] = q.status
            if q.status == "plan" then assert(pl.chosen[q.id], "plan " .. q.id) end
            if q.status == "skip" then assert(not pl.chosen[q.id] and pl.info[q.id].skip) end
            assert(not done[q.id], "erledigt nicht in der Liste")
        end
    end
    for id in pairs(pl.chosen) do
        if seen[id] then assert(seen[id] == "plan", "im Plan: " .. id .. " " .. seen[id]) end
    end
end
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
-- Reisezeit: zu Fuss, Flug, Schiff
do
    local A, B = {0, 0, 0}, {0, 6000, 0}         -- 6000 Yards auseinander
    local walk = P.Travel(A, B, {speed = 7})
    assert(math.abs(walk - 6000 * P.DETOUR / 7 / 60) < .01, "zu Fuss")
    local net = {speed = 7, flights = {{0, 100, 0, name = "Ort A"}, {0, 5900, 0, name = "Ort B"}}}
    local fly, via = P.Travel(A, B, net)
    assert(via and via.kind == "flight" and via.from.name == "Ort A" and via.to.name == "Ort B" and fly < walk / 3, "Flug lohnt")
    local near, via2 = P.Travel(A, {0, 300, 0}, net)
    assert(not via2, "kurze Strecke: laufen")
    net.departures = {{0, 500, 0, from = 0, to = 1, name = "Schiff ab Menethil"}, {1, 0, 0, from = 1, to = 0, name = "Schiff ab Auberdine"}}
    local boat, via3 = P.Travel(A, {1, 200, 0}, net)
    assert(via3 and via3.kind == "boat" and via3.dep.name == "Schiff ab Menethil" and boat < P.FAR_MIN + P.BOAT_MIN, "Schiff")
    assert(P.Travel(A, {5, 0, 0}, net) == P.UNKNOWN_TRIP, "ohne Verbindung: teure Pauschale")
end
-- Im Plan: weit entfernter Halt (Klassenquest in Sturmwind) -> eigener Schritt "Fliegen"
do
    local SW = 1453
    -- realistischere Lage: Sturmwind ~4000 Yards von Westfall, Kalimdor/Forever-Gebiete eigene Kontinente
    local oldWorld = ctx.world
    ctx.world = function(m, x, y)
        if m == 1436 then return 0, x * 3000, y * 3000 end
        if m == SW then return 0, 4000 + x * 1000, y * 1000 end
        if KAL[m] then return 1, x * 3000, y * 3000 end
        return 9, m * 10 + x * 3000, y * 3000
    end
    local cw, wx, wy = ctx.world(1436, .56, .47)
    local sc, sx, sy = ctx.world(SW, .5, .5)
    ctx.flights = {{cw, wx, wy, name = "Späherkuppe, Westfall"}, {sc, sx, sy, name = "Sturmwind, Elwynn"}}
    ctx.tempo, ctx.override = "need", nil
    for _, id in ipairs({65, 132, 135, 141, 142}) do done[id] = nil end
    local pf = P:Plan(ctx)
    -- Frueher: Flug nach Sturmwind fuer die Dungeonquest 2040 (Gnomeregan). Seit 20.11.2026 nimmt der Guide
    -- Dungeonquests nur am Weg mit (Nutzer: Dungeons laufen ueber den Dungeon-Finder) – kein Flug dafuer.
    -- (Ein Flug fuer eine Runde mit normalen Quests ist erlaubt.)
    for i, st in ipairs(pf.steps) do
        if st.kind == "travel" then
            local nx = pf.steps[i + 1]
            local onlyDungeon = nx and #nx.actions > 0
            for _, a in ipairs(nx and nx.actions or {}) do if not (pf.info[a.id] and pf.info[a.id].forDungeon) then onlyDungeon = false end end
            assert(not onlyDungeon, "kein Flug nur fuer eine Dungeonquest: " .. tostring(nx and nx.stopKey))
        end
    end
    assert(pf.info[2040] and pf.info[2040].forDungeon, "2040 ist Dungeonquest")
    ctx.flights, ctx.world = nil, oldWorld
end
-- gemessene Quest-EP (XPLog) ersetzt die Schaetzung aus der Datenbank (19.11.2026)
do
    local base = P:Plan(ctx)
    local id, o = next(base.info)
    ctx.measured = {[id] = 12345}
    local m = P:Plan(ctx).info[id]
    assert(m and m.xp ~= o.xp and m.xp == P.QuestXP(12345, o.e[1] > 0 and o.e[1] or ctx.me.level, ctx.me.level), "gemessene EP zaehlt")
    ctx.measured = nil
end
print("OK: Quest-Fuehrung Planer")
