-- Guild Trip Quest-Fuehrung: Monster hauen (0.7.0) – wann lohnt es sich, und wo?
-- Reine Rechnung (offline testbar). Daten: GuildTripQuestDB.m (scripts/import_mobs.lua).
--  * Lager = Haeufung von Spawnpunkten eines normalen, feindlichen Gegners.
--  * EP pro Minute je Lager: Gegner-EP fuer deine Stufe (Planner.MobXP), Kampfzeit steigt mit der
--    Gegnerstufe, duenne Lager kosten Laufzeit. Der Weg dorthin zaehlt auf eine Farm-Runde von 30 Min.
--  * "Lohnt sich": schneller als dein Plan (EP pro Minute des Plans), oder der Plan ist leer.
--    Der Plan selbst wird dadurch NICHT veraendert – es ist ein Hinweis.
local _, lev = ...
local Gr = {SESSION = 30, MAX_ABOVE = 2, MIN_CAMP = 5, BETTER = 1.25, TOP = 3} -- BETTER: Farmen muss 25 % schneller sein
lev.Grind = Gr

local function P() return lev.Planner end

-- Sekunden je Gegner: Grundzeit, laenger bei hoeherer Stufe, Laufzeit in duennen Lagern
function Gr.KillSeconds(plvl, mlvl, count)
    local base = P().KILL_SEC * (1 + .1 * math.max(0, mlvl - plvl))
    return base + math.max(0, 12 - (count or 12)) * 1.5
end

-- Alle Lager fuer dich, beste zuerst: {npc, name, min, max, mapID, x, y, count, epm, travel, score}
-- ctx wie beim Planer (me, world, speed)
function Gr:Camps(ctx)
    local Q = rawget(_G, "GuildTripQuestDB")
    if not (Q and Q.m) then return {} end
    local me = ctx.me
    local L = me.level or 1
    local mask = me.faction == "Alliance" and 1 or me.faction == "Horde" and 2 or 3
    local here
    if me.mapID and ctx.world then
        local c, x, y = ctx.world(me.mapID, me.x or .5, me.y or .5)
        if c then here = {c, x, y} end
    end
    local out = {}
    for npc, row in pairs(Q.m) do
        local minL, maxL, hostile = row[1], row[2], row[3]
        local avg = (minL + maxL) / 2
        if hostile and (hostile % 4 == 3 or hostile == mask) and avg <= L + self.MAX_ABOVE then
            local xp = P().MobXP(L, math.floor(avg + .5))
            if xp > 0 then
                for i = 4, #row, 4 do
                    local mapID, x, y, count = row[i], row[i + 1] / 1000, row[i + 2] / 1000, row[i + 3]
                    if count >= self.MIN_CAMP then
                        local travel
                        if here and ctx.world then
                            local c, wx, wy = ctx.world(mapID, x, y)
                            if c and c == here[1] then
                                local d = math.sqrt((wx - here[2]) ^ 2 + (wy - here[3]) ^ 2)
                                travel = d * P().DETOUR / (ctx.speed or 7) / 60
                            end
                        end
                        if travel and travel < self.SESSION then
                            local epm = xp * 60 / Gr.KillSeconds(L, avg, count)
                            out[#out + 1] = {npc = npc, name = Q.mobNames and Q.mobNames[npc] or ("#" .. npc),
                                min = minL, max = maxL, mapID = mapID, x = x, y = y, count = count,
                                epm = epm, travel = travel, score = epm * (self.SESSION - travel) / self.SESSION}
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.npc < b.npc end)
    -- je Gegner nur das beste Lager
    local seen, top = {}, {}
    for _, c in ipairs(out) do
        if not seen[c.npc] then seen[c.npc] = true top[#top + 1] = c end
    end
    return top
end

-- EP pro Minute dessen, was du JETZT machst: der erste Gebietsblock des Plans (ohne Dungeon-Halt).
-- nil = Plan leer
function Gr.PlanEPM(plan)
    if not plan or #plan.steps == 0 then return nil end
    local b = plan.blocks and plan.blocks[1]
    local xp, minutes = 0, 0
    if b then
        for i = b.first, b.last do
            local st = plan.steps[i]
            if st.kind ~= "dungeon" then xp, minutes = xp + (st.gain or 0), minutes + (st.cost or 0) end
        end
    else
        xp, minutes = plan.xp, plan.minutes
    end
    if minutes <= 0 then return nil end
    return xp / minutes
end

-- Minuten bis zur naechsten Stufe NUR mit Quests aus dem Plan (Schritte in Plan-Reihenfolge,
-- echte Zeit und EP je Schritt). nil = der Plan reicht nicht bis zur naechsten Stufe.
function Gr.QuestMinutes(plan, need)
    if not (plan and need and need > 0) then return nil end
    local xp, minutes = 0, 0
    for _, st in ipairs(plan.steps or {}) do
        xp, minutes = xp + (st.gain or 0), minutes + (st.cost or 0)
        if xp >= need then return minutes end
    end
    return nil
end

-- Minuten bis zur naechsten Stufe NUR mit Monster hauen in diesem Lager (Weg + Kaempfen)
function Gr.FarmMinutes(camp, need)
    if not (camp and need and need > 0 and camp.epm > 0) then return nil end
    return camp.travel + need / camp.epm
end

-- Wichtige Quests, die du im aktuellen Gebiet JETZT machen kannst (Annehmen/Erledigen/Abgeben im
-- ersten Gebietsblock): Dungeon-Ketten, Klassenquests, Vorquests, Quests mit Upgrade. Dungeon-Halte
-- selbst zaehlen nicht (dafuer braucht es eine Gruppe). Rueckgabe: Liste der Quest-Nummern.
Gr.IMPORTANT = {dungeon = true, class = true, pre = true}
function Gr.ImportantNow(plan)
    local out, seen = {}, {}
    local b = plan and plan.blocks and plan.blocks[1]
    if not b then return out end
    for i = b.first, b.last do
        local st = plan.steps[i]
        if st.kind ~= "dungeon" then
            for _, a in ipairs(st.actions or {}) do
                local o = plan.info and plan.info[a.id]
                local important = o and (Gr.IMPORTANT[o.why or ""] or false)
                for _, t in ipairs(o and o.tags or {}) do if t == "upgrade" then important = true end end
                if important and not seen[a.id] then seen[a.id] = true out[#out + 1] = a.id end
            end
        end
    end
    return out
end

-- Schaltet die naechste Stufe etwas frei? (Zauber beim Lehrer, neue Quests, Dungeon)
function Gr.HasUnlock(u)
    return u ~= nil and ((#(u.spells or {}) > 0) or (#(u.quests or {}) > 0) or (#(u.dungeons or {}) > 0))
end

-- Empfehlung (Nutzer 17.11.2026): Monster hauen NUR, wenn
--   1. im aktuellen Gebiet keine wichtige Quest mehr machbar ist (die gehen vor),
--   2. die naechste Stufe etwas freischaltet (neue Zauber, neue Quests, ein Dungeon) und
--   3. Farmen dich mindestens 25 % schneller dorthin bringt als die Quests im Plan
--      (oder die Quests gar nicht bis zur naechsten Stufe reichen).
-- Ausnahme: gar keine passenden Quests mehr ("empty") – dann ist Farmen der Weg weiter.
-- Rueckgabe: {worth, reason, camps, unlocks, level, planEPM, questMinutes, need, important}
--   reason: "empty" | "noLevel" | "faster" (lohnt) – "important" | "nothing" | nil (lohnt nicht)
-- ctx.xpNeed = fehlende EP; ctx.unlocks(stufe) -> {spells, quests, dungeons}. Ohne xpNeed: EP-pro-Minute-Vergleich.
function Gr:Advice(ctx, plan)
    local L = ctx.me and ctx.me.level or 1
    local need = ctx.xpNeed
    local planEPM = Gr.PlanEPM(plan)
    local questMin = Gr.QuestMinutes(plan, need)
    local empty = not plan or #(plan.steps or {}) == 0
    local advice = {worth = false, camps = {}, level = L + 1, planEPM = planEPM, questMinutes = questMin, need = need}
    if not empty then
        advice.important = Gr.ImportantNow(plan)
        if #advice.important > 0 then advice.reason = "important" return advice end
    end
    advice.unlocks = ctx.unlocks and ctx.unlocks(L + 1) or nil
    if not empty and not Gr.HasUnlock(advice.unlocks) then advice.reason = "nothing" return advice end
    local out = {}
    for _, c in ipairs(self:Camps(ctx)) do
        local faster
        if need and need > 0 then
            c.minutes = Gr.FarmMinutes(c, need)
            faster = empty or not questMin or (c.minutes and c.minutes * self.BETTER < questMin)
        else
            faster = empty or not planEPM or c.score > planEPM * self.BETTER
        end
        if faster then out[#out + 1] = c end
    end
    if need and need > 0 then table.sort(out, function(a, b) return a.minutes < b.minutes end) end
    for i = 1, math.min(self.TOP, #out) do advice.camps[i] = out[i] end
    if #advice.camps > 0 then
        advice.worth = true
        advice.reason = empty and "empty" or (need and not questMin) and "noLevel" or "faster"
    end
    return advice
end
