-- Guild Trip Quest-Fuehrung: Monster hauen (0.7.0) – wann lohnt es sich, und wo?
-- Reine Rechnung (offline testbar). Daten: GuildTripQuestDB.m (scripts/import_mobs.lua).
--  * Lager = Haeufung von Spawnpunkten eines normalen, feindlichen Gegners.
--  * EP pro Minute je Lager: Gegner-EP fuer deine Stufe (Planner.MobXP), Kampfzeit steigt mit der
--    Gegnerstufe, duenne Lager kosten Laufzeit. Der Weg dorthin zaehlt auf eine Farm-Runde von 30 Min.
--  * "Lohnt sich": schneller als dein Plan (EP pro Minute des Plans), oder der Plan ist leer.
--    Der Plan selbst wird dadurch NICHT veraendert – es ist ein Hinweis.
local _, lev = ...
local Gr = {SESSION = 30, MAX_ABOVE = 2, MIN_CAMP = 5, BETTER = 1.1, TOP = 3}
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

-- Empfehlung (Nutzer 17.11.2026: "Monster nur, wenn es fuer den Stufenaufstieg schneller ist als Quests"):
-- Vergleich Zeit bis zur naechsten Stufe – nur Quests (Plan) gegen nur Monster hauen (je Lager).
--   worth  = mindestens ein Lager bringt dich spuerbar schneller zur naechsten Stufe
--   reason = "empty" (keine passenden Quests) | "noLevel" (Plan reicht nicht bis zur Stufe) | "faster"
--   camps  = nur die Lager, die schneller sind (beste zuerst), je mit .minutes (bis zur Stufe)
-- ctx.xpNeed = fehlende EP bis zur naechsten Stufe. Ohne diese Angabe: Vergleich der EP pro Minute.
function Gr:Advice(ctx, plan)
    local all = self:Camps(ctx)
    local need = ctx.xpNeed
    local planEPM = Gr.PlanEPM(plan)
    local questMin = Gr.QuestMinutes(plan, need)
    local empty = not plan or #(plan.steps or {}) == 0
    local out, reason = {}, nil
    for _, c in ipairs(all) do
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
    local top = {}
    for i = 1, math.min(self.TOP, #out) do top[i] = out[i] end
    if #top > 0 then reason = empty and "empty" or (need and not questMin) and "noLevel" or "faster" end
    return {worth = #top > 0, reason = reason, camps = top, planEPM = planEPM, questMinutes = questMin, need = need}
end
