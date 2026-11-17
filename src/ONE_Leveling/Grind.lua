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

-- Empfehlung: {worth = true|false, camps = {…}, planEPM, reason = "empty"|"faster"|nil}
function Gr:Advice(ctx, plan)
    local camps = self:Camps(ctx)
    local top = {}
    for i = 1, math.min(self.TOP, #camps) do top[i] = camps[i] end
    local planEPM = Gr.PlanEPM(plan)
    local best = top[1]
    local worth, reason = false, nil
    if best then
        if not planEPM then worth, reason = true, "empty"
        elseif best.score > planEPM * self.BETTER then worth, reason = true, "faster" end
    end
    return {worth = worth, reason = reason, camps = top, planEPM = planEPM}
end
