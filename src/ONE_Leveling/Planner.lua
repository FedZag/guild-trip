-- Guild Trip Quest-Fuehrung: Planer (0.6.9). Reine Rechnung, keine Oberflaeche – offline testbar.
-- Wertung (mit dem Nutzer abgestimmt, docs/vorschau_quest_fuehrung.html):
--  * Pflicht: Dungeon-Quests (mit allen Vorquests), Klassenquests, Vorquests von allem, was gemacht wird
--  * Lohnt: EP pro Minute ueber "nur Monster hauen" (Faktor je Tempo), Gegner-EP zaehlen mit
--  * Mehrwert: Upgrade fuer die Klasse, groessere Tasche, viel Gold – darf etwas langsamer sein
--  * Gruppe: Elite-/Gruppenquests nur in einer Gruppe (sonst "Gruppe suchen"), Dungeon-Quests immer
-- Danach Reihenfolge: annehmen -> erledigen -> abgeben, jeweils der naechste erreichbare Halt (Luftlinie x Umwegfaktor).
-- Eingabe ctx (siehe Planner:Plan), Daten: GuildTripQuestDB (ONE_QuestDB) + GuildTripLeveling (Rewards.lua).
local _, lev = ...
local P = {}
lev.Planner = P

P.TEMPO = {need = 1.3, balanced = 1.0, all = 0}  -- Faktor auf "nur Monster hauen"
P.TEMPO_ORDER = {"need", "balanced", "all"}
P.KILL_SEC = 22          -- je Gegner/Sammelaktion inkl. Erholen
P.TALK_MIN = .4          -- je Quest Annehmen + Abgeben
P.DETOUR = 1.3           -- Wegenetz im Schnitt etwas laenger als Luftlinie
P.HORIZON = 2            -- Stufen voraus planen
P.MAX_STEPS = 60
P.MAX_MINUTES = 150
P.FAR_MIN = 12           -- anderer Kontinent / unbekannter Ort
P.VALUE_SLACK = .6       -- Mehrwert-Quests duerfen so viel langsamer sein
P.UPGRADE_PCT = 10
P.BUSY_WORK = 40         -- ab hier "viel Aufwand / seltene Drops"
-- Questsorten (zoneOrSort < 0) der Klassen
P.CLASS_SORT = {[-61] = 256, [-81] = 1, [-82] = 64, [-141] = 2, [-161] = 128, [-162] = 8, [-261] = 4, [-262] = 16, [-263] = 1024}
P.FACTION_MASK = {Alliance = 77, Horde = 178}

local function Band(a, b)
    local lib = rawget(_G, "bit")
    if type(lib) == "table" and lib.band then return lib.band(a, b) end
    local r, p = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + p end
        a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
    end
    return r
end
P.Band = Band

function P.Data()
    local q, r = rawget(_G, "GuildTripQuestDB"), rawget(_G, "GuildTripLeveling")
    if type(q) ~= "table" or type(q.q) ~= "table" then return nil end
    return q, type(r) == "table" and r or {r = {}, i = {}, dz = {}}
end

-- ===== EP =====
-- Quest-EP nach Stufenabstand (Classic): bis 5 Stufen drueber voll, dann 80/60/40/20 %, ab 10 noch 10 %
function P.QuestXP(base, qlvl, plvl)
    local d = plvl - (qlvl or plvl)
    local f = d <= 5 and 1 or d == 6 and .8 or d == 7 and .6 or d == 8 and .4 or d == 9 and .2 or .1
    return math.floor((base or 0) * f / 5 + .5) * 5, f
end
-- Grauer Gegner ab diesem Abstand (Classic-Tabelle vereinfacht)
function P.GreyBelow(plvl)
    if plvl <= 5 then return 0 end
    if plvl <= 39 then return plvl - 5 - math.floor(plvl / 10) end
    return plvl - 1 - math.floor(plvl / 5)
end
function P.MobXP(plvl, mlvl)
    mlvl = mlvl or plvl
    local base = plvl * 5 + 45
    if mlvl >= plvl then return base * (1 + .05 * math.min(4, mlvl - plvl)) end
    local grey = P.GreyBelow(plvl)
    if mlvl <= grey then return 0 end
    local zd = plvl < 8 and 5 or plvl < 10 and 6 or plvl < 12 and 7 or plvl < 16 and 8 or plvl < 20 and 9 or plvl < 30 and 11 or plvl < 40 and 12 or plvl < 45 and 13 or plvl < 50 and 14 or plvl < 55 and 15 or 16
    return base * math.max(0, 1 - (plvl - mlvl) / zd)
end
function P.GrindEPM(plvl) return P.MobXP(plvl, plvl) * 60 / P.KILL_SEC end

-- ===== Orte =====
-- Erster Punkt eines Knotens (bevorzugt auf Karte mapID): mapID, x, y (0..1)
function P.NodePoint(Q, nr, mapID)
    local n = Q.n and Q.n[nr]
    if not n then return nil end
    local best
    for i = 2, #n, 3 do
        if n[i] == mapID then return n[i], n[i + 1] / 1000, n[i + 2] / 1000 end
        best = best or i
    end
    if best then return n[best], n[best + 1] / 1000, n[best + 2] / 1000 end
end

-- ===== Hilfen =====
local function Fits(id, e, me, done, inLog)
    if done(id) then return false end
    local race, class = e[3], e[4]
    if race > 0 and race < 255 then
        local mine = me.race or P.FACTION_MASK[me.faction]
        if mine and Band(race, mine) == 0 then return false end
    end
    if class > 0 and me.class and Band(class, me.class) == 0 then return false end
    local sortClass = P.CLASS_SORT[e[14] or 0]
    if sortClass and me.class and sortClass ~= me.class then return false end
    if type(e[10]) == "table" then
        for _, p in ipairs(e[10]) do if done(p) or (inLog(p) and p ~= id) then return false end end
    end
    if (e[13] or 0) > 0 and me.level > e[13] then return false end
    return true
end
P.Fits = Fits

function P.IsClassQuest(e) return (e[4] or 0) > 0 or P.CLASS_SORT[e[14] or 0] ~= nil end

-- Belohnung bewerten: Liste {kind = "upgrade"|"bag"|"gold", text, pct, item}
function P.Value(qid, rew, R, ctx, plvl)
    local out = {}
    if not rew then return out end
    local money = rew[1] or 0
    if money >= plvl * 1000 then out[#out + 1] = {kind = "gold", money = money} end
    local best
    for _, list in ipairs({rew[4] or {}, rew[5] or {}}) do
        for _, item in ipairs(list) do
            local it = R.i and R.i[item]
            if it and it[5] == 1 and (it[7] or 0) > (ctx.smallestBag or 99) then
                out[#out + 1] = {kind = "bag", item = item, slots = it[7]}
            end
            local pct = ctx.judge and ctx.judge(item)
            if pct and pct >= P.UPGRADE_PCT and (not best or pct > best.pct) then best = {kind = "upgrade", item = item, pct = pct} end
        end
    end
    if best then out[#out + 1] = best end
    return out
end

-- ===== Plan =====
-- ctx = {me = {level, class (Maske), race (Maske|nil), faction, inGroup, mapID, x, y},
--        done(id), inLog(id), complete(id), world(mapID, x, y) -> kontinent, wx, wy,
--        judge(itemID) -> Prozent|nil, smallestBag, tempo, override = {[id] = "yes"|"no"}, dungeonName(key), catalog(key)}
function P:Plan(ctx)
    local Q, R = P.Data()
    if not Q then return nil end
    local me = ctx.me
    local L = me.level or 1
    local done = ctx.done or function() return false end
    local inLog = ctx.inLog or function() return false end
    local complete = ctx.complete or function() return false end
    local override = ctx.override or {}
    local factor = P.TEMPO[ctx.tempo or "need"] or P.TEMPO.need
    local grind = P.GrindEPM(L)
    local rewards, dz = R.r or {}, R.dz or {}

    -- Weltposition je Knoten (gemerkt fuer diesen Durchlauf)
    local wcache = {}
    local pc, px, py
    if me.mapID and ctx.world then pc, px, py = ctx.world(me.mapID, me.x or .5, me.y or .5) end
    local function World(nr, mapID, x, y)
        local key = nr or (mapID .. ":" .. x .. ":" .. y)
        local w = wcache[key]
        if w == nil then
            if nr then mapID, x, y = P.NodePoint(Q, nr, me.mapID) end
            local c, wx, wy
            if mapID and ctx.world then c, wx, wy = ctx.world(mapID, x, y) end
            w = c and {c, wx, wy, mapID, x, y} or false
            wcache[key] = w
        end
        return w or nil
    end
    local function Minutes(a, b)
        if not (a and b) or a[1] ~= b[1] then return P.FAR_MIN end
        local d = math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
        return d * P.DETOUR / (ctx.speed or 7) / 60, d
    end
    local here = pc and {pc, px, py} or nil
    -- naechster Punkt aus einer Knotenliste (zum Bezugspunkt)
    local function Nearest(list, ref)
        local best, bm
        for _, nr in ipairs(list or {}) do
            local w = World(nr)
            if w then
                local m = ref and Minutes(ref, w) or 0
                if not bm or m < bm then best, bm = {nr = nr, w = w}, m end
            end
        end
        return best
    end
    local function DungeonOf(e) return dz[e[14] or 0] end

    -- 1) Kandidaten: passt zu mir, Stufe im Planungsfenster
    local cand = {}
    for id, e in pairs(Q.q) do
        local log = inLog(id)
        -- Dungeon-Quests: Questsufe liegt oft hoeher (Ziel im Dungeon) – die Mindeststufe zaehlt
        local lvlOK = (e[1] or 0) <= L + P.HORIZON + 1 or (dz[e[14] or 0] ~= nil)
        if log or (Fits(id, e, me, done, inLog) and (e[2] or 0) <= L + P.HORIZON and lvlOK) then
            cand[id] = true
        end
    end
    -- 2) bewerten
    local info = {}
    local function Rate(id)
        local e, rew = Q.q[id], rewards[id]
        local qlvl = e[1] > 0 and e[1] or L
        local xp, f = P.QuestXP(e[11] or 0, qlvl, L)
        local work = rew and rew[2] or 0
        local kind = rew and rew[3] or 0
        local dungeon = DungeonOf(e)
        if dungeon then kind = kind - kind % 4 + (kind % 2) + 2 end
        local mobXP = P.MobXP(L, math.min(qlvl, L + 2))
        local giver = Nearest(e[6], here)
        local target = Nearest(e[8], giver and giver.w or here)
        local ender = Nearest(e[7], target and target.w or giver and giver.w)
        local travel = 0
        if giver and target then travel = travel + Minutes(giver.w, target.w) end
        if target and ender then travel = travel + Minutes(target.w, ender.w)
        elseif giver and ender then travel = travel + Minutes(giver.w, ender.w) end
        if not giver then travel = travel + P.FAR_MIN end
        local minutes = P.TALK_MIN + travel + work * P.KILL_SEC / 60
        local totalXP = xp + (dungeon and 0 or work * mobXP)
        local o = {id = id, e = e, xp = xp, xpFactor = f, work = work, kind = kind, dungeon = dungeon,
            mobXP = mobXP, travel = travel, minutes = minutes, totalXP = totalXP,
            giver = giver, target = target, ender = ender, log = inLog(id), complete = complete(id),
            class = P.IsClassQuest(e), reasons = {}, tags = {}}
        o.value = P.Value(id, rew, R, ctx, L)
        o.epm = totalXP / math.max(.5, minutes)
        info[id] = o
        return o
    end
    for id in pairs(cand) do Rate(id) end
    -- Buendeln: Quests mit Zielen nahe beieinander teilen sich den Weg
    local list = {}
    for _, o in pairs(info) do if o.target then list[#list + 1] = o end end
    for _, o in ipairs(list) do
        local near = 0
        for _, b in ipairs(list) do
            if b ~= o and b.target.w[1] == o.target.w[1] then
                local _, d = Minutes(o.target.w, b.target.w)
                if d and d < 200 then near = near + 1 end
            end
        end
        o.near = near
        if near > 0 then
            o.travel = o.travel / (1 + near)
            o.minutes = P.TALK_MIN + o.travel + o.work * P.KILL_SEC / 60
        end
    end
    for _, o in pairs(info) do o.epm = o.totalXP / math.max(.5, o.minutes) end

    -- 3) entscheiden
    local chosen = {}
    local function Choose(o, why)
        if chosen[o.id] then return end
        chosen[o.id] = why
    end
    for id, o in pairs(info) do
        local e = o.e
        local isGroup = o.kind % 2 == 1 or math.floor(o.kind / 16) % 2 == 1
        local raidOrPvp = math.floor(o.kind / 4) % 2 == 1 or math.floor(o.kind / 8) % 2 == 1
        local cat = o.dungeon and ctx.catalog and ctx.catalog(o.dungeon)
        o.group = isGroup or o.dungeon ~= nil
        if override[id] == "no" then
            o.skip = "Von dir abgewählt."
        elseif override[id] == "yes" then
            Choose(o, "yes")
        elseif raidOrPvp then
            o.skip = "Schlachtzug/PvP – nicht für schnelles Leveln."
        elseif o.dungeon and (not cat or (cat.min or 0) <= L + P.HORIZON) then
            Choose(o, "dungeon")
        elseif o.dungeon then
            o.skip = "Dungeon kommt erst später."
        elseif o.class then
            Choose(o, "class")
        elseif o.log and o.complete then
            Choose(o, "log")
        elseif o.xpFactor <= .2 then
            o.skip = "Grau – kaum noch EP."
        elseif isGroup and not me.inGroup then
            o.skip = "Elite/Gruppe – nur mit Gruppe."
        elseif o.work >= P.BUSY_WORK and #o.value == 0 then
            o.skip = "Viel Aufwand (seltene Drops oder viele Gegner)."
        elseif not o.giver and not o.log then
            o.skip = "Ort unbekannt."
        elseif here and o.giver and o.giver.w[1] ~= here[1] and not o.log then
            o.skip = "Anderer Kontinent."
        elseif o.epm >= grind * factor then
            Choose(o, "xp")
        elseif #o.value > 0 and o.epm >= grind * factor * P.VALUE_SLACK then
            Choose(o, "value")
        elseif o.log then
            Choose(o, "log")
        else
            o.skip = "Zu langsam: %d EP/min (lohnt ab ~%d)."
        end
    end
    -- 4) Vorquests aller gewaehlten Quests (Kette rueckwaerts) werden Pflicht; fehlt eine, faellt die Quest raus
    local function Pre(e)
        local out = {}
        if type(e[9]) == "table" then for _, p in ipairs(e[9]) do out[#out + 1] = {p} end end
        if type(e[5]) == "table" and #e[5] > 0 then out[#out + 1] = e[5] end -- eine von
        return out
    end
    local resolving = {}
    local function Resolve(id)
        if done(id) or inLog(id) then return true end
        if resolving[id] ~= nil then return resolving[id] end
        resolving[id] = false
        local e = Q.q[id]
        if not (e and Fits(id, e, me, done, inLog)) or override[id] == "no" then return false end
        if (e[2] or 0) > L + P.HORIZON then return false end
        for _, group in ipairs(Pre(e)) do
            local ok = false
            for _, p in ipairs(group) do
                -- Vorquest ohne Daten (z. B. Begleitquest): nicht planbar, Kette trotzdem behalten
                if done(p) or not Q.q[p] then ok = true break end
            end
            if not ok then
                for _, p in ipairs(group) do
                    if Resolve(p) then
                        if not chosen[p] then
                            info[p] = info[p] or Rate(p)
                            chosen[p] = "pre"
                            info[p].preFor = id
                            info[p].skip = nil
                        end
                        ok = true
                        break
                    end
                end
            end
            if not ok then return false end
        end
        resolving[id] = true
        return true
    end
    local ids = {}
    for id in pairs(chosen) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if not Resolve(id) then
            chosen[id] = nil
            info[id].skip = "Vorquest fehlt noch."
        end
    end
    -- Gruende/Zeichen
    for id, why in pairs(chosen) do
        local o = info[id]
        o.why = why
        if why == "dungeon" then o.tags[#o.tags + 1] = "dungeon" end
        if why == "class" then o.tags[#o.tags + 1] = "class" end
        if why == "pre" then o.tags[#o.tags + 1] = "pre" end
        if why == "xp" or (o.epm >= grind * factor and factor > 0) then o.tags[#o.tags + 1] = "xp" end
        for _, v in ipairs(o.value) do if v.kind == "upgrade" or v.kind == "bag" then o.tags[#o.tags + 1] = "upgrade" break end end
        if o.group then o.tags[#o.tags + 1] = "group" end
    end

    -- 5) Halte: annehmen, erledigen, abgeben
    local stops, byDungeon = {}, {}
    for id in pairs(chosen) do
        local o = info[id]
        if not o.log then
            if o.giver then stops[#stops + 1] = {kind = "accept", id = id, w = o.giver.w, nr = o.giver.nr} end
        end
        if not (o.log and o.complete) then
            if o.dungeon then
                local d = byDungeon[o.dungeon]
                if not d then
                    local pos = ctx.entrance and ctx.entrance(o.dungeon)
                    local w = pos and World(nil, pos[1], pos[2], pos[3])
                    d = {kind = "dungeon", key = o.dungeon, ids = {}, w = w}
                    byDungeon[o.dungeon] = d
                    stops[#stops + 1] = d
                end
                d.ids[#d.ids + 1] = id
            elseif o.target and (#(o.e[8] or {}) > 0) then
                stops[#stops + 1] = {kind = "obj", id = id, w = o.target.w, nr = o.target.nr}
            end
        end
        if o.ender then stops[#stops + 1] = {kind = "turnin", id = id, w = o.ender.w, nr = o.ender.nr} end
    end
    -- Bedingungen: angenommen (im Plan oder im Log) vor Erledigen/Abgeben, Vorquest abgegeben vor Annehmen
    local accepted, finished, turned = {}, {}, {}
    for id in pairs(chosen) do
        if info[id].log then accepted[id] = true end
        if info[id].log and info[id].complete then finished[id] = true end
    end
    local function Ready(s)
        if s.kind == "accept" then
            for _, group in ipairs(Pre(Q.q[s.id])) do
                local ok = false
                for _, p in ipairs(group) do if done(p) or turned[p] or not Q.q[p] then ok = true break end end
                if not ok then return false end
            end
            return true
        elseif s.kind == "obj" then
            return accepted[s.id]
        elseif s.kind == "dungeon" then
            for _, id in ipairs(s.ids) do if not accepted[id] then return false end end
            return true
        else -- Abgabe
            if not accepted[s.id] then return false end
            local o = info[s.id]
            if finished[s.id] then return true end
            -- ohne Erledigen-Halt (z. B. Botengang) gleich abgebbar
            for _, t in ipairs(stops) do
                if not t.used and ((t.kind == "obj" and t.id == s.id) or (t.kind == "dungeon" and t.idsSet and t.idsSet[s.id])) then return false end
            end
            return o ~= nil
        end
    end
    for _, s in ipairs(stops) do
        if s.kind == "dungeon" then s.idsSet = {} for _, id in ipairs(s.ids) do s.idsSet[id] = true end end
    end
    local order, pos, minutes, xpSum = {}, here, 0, 0
    local prefer = ctx.prefer
    while #order < P.MAX_STEPS and minutes < P.MAX_MINUTES do
        local best, bm
        for _, s in ipairs(stops) do
            if not s.used and Ready(s) then
                local m = s.w and pos and Minutes(pos, s.w) or (s.w and 0) or P.FAR_MIN
                if s.kind == "dungeon" then m = m + 1 end
                -- Reihenfolge ruhig halten: der bisherige erste Schritt bleibt, solange er nicht deutlich weiter weg ist
                if prefer and #order == 0 and prefer == P.StopKey(s) then m = m * .5 end
                if not bm or m < bm then best, bm = s, m end
            end
        end
        if not best then break end
        best.used = true
        best.walk = bm
        order[#order + 1] = best
        minutes = minutes + bm
        if best.w then pos = best.w end
        if best.kind == "accept" then accepted[best.id] = true
        elseif best.kind == "obj" then
            finished[best.id] = true
            local o = info[best.id]
            minutes = minutes + o.work * P.KILL_SEC / 60
            xpSum = xpSum + o.work * o.mobXP
        elseif best.kind == "dungeon" then
            for _, id in ipairs(best.ids) do finished[id] = true end
            minutes = minutes + 45
        else
            turned[best.id] = true
            finished[best.id] = true
            xpSum = xpSum + info[best.id].xp
            minutes = minutes + P.TALK_MIN
        end
    end
    local left = {}
    for _, s in ipairs(stops) do if not s.used then left[#left + 1] = s end end
    -- 6) Schritte: aufeinanderfolgende Halte am selben NPC zusammenfassen
    local steps = {}
    for _, s in ipairs(order) do
        local last = steps[#steps]
        if last and s.nr and last.nr == s.nr and s.kind ~= "obj" and last.kind ~= "obj" and s.kind ~= "dungeon" then
            last.actions[#last.actions + 1] = {kind = s.kind, id = s.id}
        else
            local w = s.w
            steps[#steps + 1] = {kind = s.kind, nr = s.nr, key = s.key, ids = s.ids, mapID = w and w[4], x = w and w[5], y = w and w[6],
                walk = s.walk, actions = s.kind == "dungeon" and {} or {{kind = s.kind, id = s.id}}, stopKey = P.StopKey(s)}
        end
    end
    -- Ausgelassen (nur mit Grund, sortiert nach EP)
    local skipped = {}
    for _, o in pairs(info) do
        if not chosen[o.id] and o.skip and not o.log then skipped[#skipped + 1] = o end
    end
    table.sort(skipped, function(a, b) if a.totalXP ~= b.totalXP then return a.totalXP > b.totalXP end return a.id < b.id end)
    return {steps = steps, info = info, chosen = chosen, skipped = skipped, minutes = minutes, xp = xpSum, left = left,
        grind = grind, factor = factor, level = L}
end

function P.StopKey(s)
    if s.kind == "dungeon" then return "d:" .. tostring(s.key) end
    return s.kind .. ":" .. tostring(s.id)
end

-- Text fuer "ausgelassen" mit Zahlen
function P.SkipText(o, plan, tr)
    if not o.skip then return nil end
    tr = tr or function(text, ...) if select("#", ...) > 0 then return text:format(...) end return text end
    if o.skip:find("%%d") then return tr(o.skip, math.floor(o.epm + .5), math.floor(plan.grind * math.max(plan.factor, .01) + .5)) end
    return tr(o.skip)
end
