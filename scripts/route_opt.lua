-- Gesamt-Optimierer fuer eine fertig gerechnete Route (Neubau 23.11.2026, Nutzer: "speed-leveling heisst nicht, von
-- Ratchet 2,5 km nach Norden zu laufen um dort Samophlang zu machen und dann 2,5 km zurueck").
-- Die Nachstellung (scripts/sim_leveling.lua) entscheidet Schritt fuer Schritt und sieht nicht, dass sie spaeter
-- ohnehin wieder in denselben Bereich kommt. Hier wird die GANZE Route auf einmal betrachtet, wie man einen Leitfaden
-- von Hand ueberarbeitet:
--   * Bloecke (1-3 Schritte oder ganze Besuche eines Bereichs, bis 4 Besuche am Stueck) wandern an die Stelle der Route,
--     an der der Weg am kuerzesten wird – auch ueber andere Gebiete hinweg (z. B. erster und zweiter Besuch im
--     Nordbrachland werden einer, wenn die Stufen es erlauben).
--   * Annehmen/Abgeben gehen dabei mit: steht derselbe NPC spaeter (oder frueher) ohnehin in der Route, wird die
--     Abgabe dort erledigt (eine Abgabe "wartet" auf den naechsten Besuch).
--   * Schritte, die danach leer sind (alles schon woanders erledigt), entfallen samt Weg.
-- Harte Regeln bleiben immer: annehmen vor Ziel vor abgeben, Vorquests abgegeben vor der Folgequest, Mindeststufe beim
-- Annehmen, Ziel-Stufe (P.OBJ_AHEAD), Questlog hoechstens P.LOG_MAX. Die Stufe je Schritt wird aus den EP aller Schritte
-- davor neu gerechnet (Quest-EP sinken wie im Spiel, wenn man sie spaeter mit hoeherer Stufe abgibt).
-- Ruhestein setzen / Flugpunkt / Monster hauen bleiben in ihrer Reihenfolge (Flugpunkte gelten erst ab dort).
local M = {}

local function Dist(a, b) return math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end

-- route: Liste der Schritte aus der Nachstellung ({q = "a1 t2", w = {kont, x, y}, map, n, l, g, k, fpID, ...})
-- env: {Q, P, XP_NEED, startXP, fps = {{kont, x, y, id = }}, known0 = {[fpID] = true}, verbose, passes}
-- Rueckgabe: neue Route, Infos {saved = Minuten Weg gespart, moves, removed, xpDiff, before, after}
function M.Run(route, env)
    local Q, P, XPN = env.Q, env.P, env.XP_NEED
    local startXP = env.startXP or 0
    local function LevelAt(total)
        local lv, x = 1, total
        while lv < 60 and x >= (XPN[lv] or 1e9) do x = x - XPN[lv] lv = lv + 1 end
        return lv
    end
    local function QX(id, lvl)
        local e = Q.q[id]
        if not e then return 0 end
        local ql = (e[1] or 0) > 0 and e[1] or lvl
        return (P.QuestXP(e[11] or 0, ql, lvl))
    end

    -- Schritte -> Eintraege mit Tokens; feste EP (Monster fuer Ziele, Hauen) getrennt von den Abgabe-EP
    local E = {}
    for _, r in ipairs(route) do
        local x = {r = r, w = r.w, map = r.map, n = r.n, anchor = r.k, toks = {}}
        for k, id in (r.q or ""):gmatch("(%a)(%d+)") do x.toks[#x.toks + 1] = {k, tonumber(id)} end
        local tx = 0
        for _, t in ipairs(x.toks) do if t[1] == "t" then tx = tx + QX(t[2], r.l or 1) end end
        x.base = math.max(0, (r.g or 0) - tx)
        E[#E + 1] = x
    end
    -- ohne Ort (sollte nicht vorkommen): nicht bewegen
    local function Quest(x) return x.w and not x.anchor and #x.toks > 0 end

    -- Flugpunkte: bekannt ab dem Flugpunkt-Schritt (Reihenfolge der festen Schritte aendert sich nie)
    local knownBy = {[0] = env.known0 or {}}
    do
        local kn, ep = {}, 0
        for k in pairs(env.known0 or {}) do kn[k] = true end
        for _, x in ipairs(E) do
            if x.anchor == "fp" and x.r.fpID then
                ep = ep + 1
                local c = {}
                for k in pairs(kn) do c[k] = true end
                c[x.r.fpID] = true
                kn = c
                knownBy[ep] = c
            end
        end
    end
    local fps = env.fps or {}
    local function Walk(a, b) return Dist(a, b) * P.DETOUR / 7 / 60 end
    local nearMemo = {}
    local function NearFP(w, ep)
        local row = nearMemo[ep] if not row then row = {} nearMemo[ep] = row end
        local v = row[w]
        if v == nil then
            local kn, bd = knownBy[ep] or {}, nil
            v = false
            for _, f in ipairs(fps) do
                if kn[f.id] and f[1] == w[1] then local d = Dist(f, w) if not bd or d < bd then v, bd = f, d end end
            end
            row[w] = v
        end
        return v or nil
    end
    local memo = {}
    local function C(a, b, ep)
        if not (a and b) then return 0 end
        local m = memo[ep] if not m then m = {} memo[ep] = m end
        local row = m[a] if not row then row = {} m[a] = row end
        local v = row[b]
        if v then return v end
        if a[1] ~= b[1] then v = 10
        else
            v = Walk(a, b)
            local fa, fb = NearFP(a, ep), NearFP(b, ep)
            if fa and fb and fa ~= fb then
                local fm = Walk(a, fa) + Dist(fa, fb) * P.FLY_DETOUR / P.FLY_SPEED / 60 + P.FLY_EXTRA + Walk(fb, b)
                if fm < v * .8 then v = fm end
            end
        end
        row[b] = v
        return v
    end
    local function Epochs(o)
        local ep, out = 0, {}
        for i, x in ipairs(o) do
            if x.anchor == "fp" and x.r.fpID then ep = ep + 1 end
            out[i] = ep
        end
        return out
    end
    -- Weg der ganzen Route in Minuten. Ruhestein wie in der Nachstellung: wenn bereit (Abklingzeit P.HS_CD) und er
    -- mindestens P.HS_SAVE Minuten spart, zum zuletzt gesetzten Gasthaus; Zeit je Schritt ausser Weg ~ ENTRY_MIN.
    local ENTRY_MIN = 3
    local function WayCost(o)
        local c, ep, prev = 0, 0, nil
        local homeW, clock, ready = env.home0, 0, 0
        for _, x in ipairs(o) do
            if x.anchor == "fp" and x.r.fpID then ep = ep + 1 end
            if x.w then
                if prev then
                    local leg = C(prev, x.w, ep)
                    if homeW and clock >= ready and leg > P.HS_SAVE + P.HS_MIN then
                        local h = P.HS_MIN + (homeW[1] == x.w[1] and C(homeW, x.w, ep) or 10)
                        if h <= leg - P.HS_SAVE then leg, ready = h, clock + P.HS_CD end
                    end
                    c = c + leg
                    clock = clock + leg + ENTRY_MIN
                end
                prev = x.w
            end
            if x.anchor == "bind" and x.w then homeW = x.w end
        end
        return c
    end
    local function XPOf(x, lvl)
        local g = x.base
        for _, t in ipairs(x.toks) do if t[1] == "t" then g = g + QX(t[2], lvl) end end
        return g
    end

    -- Pruefung der ganzen Reihenfolge; bei Fehler: Art, Quest, Hilfswert
    local inRouteT = {}
    for _, x in ipairs(E) do for _, t in ipairs(x.toks) do if t[1] == "t" then inRouteT[t[2]] = true end end end
    -- noetige Stufe je Annahme/Ziel: Spielregel, aber nie mehr als in der Ausgangsroute (die Nachstellung prueft
    -- Stufen beim Schrittbeginn und mit Planer-Ausnahmen – was dort ging, geht hier auch)
    local needA, needO, origA, origT = {}, {}, {}, {}
    do
        local cum = startXP
        for _, x in ipairs(E) do
            local lvl = LevelAt(cum)
            for _, t in ipairs(x.toks) do
                local e = Q.q[t[2]] or {}
                if t[1] == "a" then needA[t[2]] = e[2] or 0 origA[t[2]] = lvl
                elseif t[1] == "o" then needO[t[2]] = math.min((e[1] or 0) - P.OBJ_AHEAD, lvl)
                else origT[t[2]] = lvl end
            end
            cum = cum + XPOf(x, lvl)
        end
    end
    -- EP bis zum Beginn einer Stufe
    local cumTo = {[1] = 0}
    for l = 2, 61 do cumTo[l] = cumTo[l - 1] + (XPN[l - 1] or 0) end
    local EARLY, LATE = env.early or tonumber(os.getenv("OPT_EARLY") or "3"), env.late or tonumber(os.getenv("OPT_LATE") or "8")
    local function Rate(lvl) return P.GrindEPM(lvl) * (P.GRIND_REAL or .7) end
    -- Pruefung der ganzen Reihenfolge. Fehlt fuer eine Annahme/ein Ziel Stufe (EP kommen durchs Umstellen spaeter),
    -- wird davor Monster gehauen – das kostet Zeit (Rueckgabe gmin) und zaehlt gegen den gesparten Weg.
    -- collect: Liste {vor Eintrag i, EP, bis Stufe} fuer die Ausgabe.
    local function Validate(o, collect)
        local pa, pt, po, pomin = {}, {}, {}, {}
        for i, x in ipairs(o) do
            for j, t in ipairs(x.toks) do
                local s = i * 100 + j
                local k, id = t[1], t[2]
                if k == "a" then if not pa[id] then pa[id] = s end
                elseif k == "t" then pt[id] = s
                else po[id] = math.max(po[id] or 0, s) if not pomin[id] then pomin[id] = s end end
            end
        end
        local cum, open, gmin = startXP + 0, 0, 0
        local glist = collect and {} or nil
        for i, x in ipairs(o) do
            local lvl = LevelAt(cum)
            -- erst die noetige Stufe fuer diesen Eintrag (Monster hauen davor)
            local need = 0
            for _, t in ipairs(x.toks) do
                local k, id = t[1], t[2]
                if k == "a" then need = math.max(need, needA[id] or 0)
                elseif k == "o" then need = math.max(need, needO[id] or 0) end
            end
            if need > lvl then
                local dx = cumTo[math.min(60, need)] - cum
                if dx > 0 then
                    gmin = gmin + dx / Rate(lvl)
                    if glist then glist[#glist + 1] = {i, dx, need} end
                    cum = cum + dx
                    lvl = LevelAt(cum)
                end
            end
            for j, t in ipairs(x.toks) do
                local s = i * 100 + j
                local k, id = t[1], t[2]
                local e = Q.q[id] or {}
                if k == "a" then
                    if origA[id] and lvl < origA[id] - EARLY then return false, "early", id end
                    if type(e[9]) == "table" then
                        for _, p in ipairs(e[9]) do
                            if inRouteT[p] and not (pt[p] and pt[p] < s) then return false, "pre", id, p end
                        end
                    end
                    if type(e[5]) == "table" and #e[5] > 0 then
                        local any, ok = false, false
                        for _, p in ipairs(e[5]) do
                            if inRouteT[p] then any = true if pt[p] and pt[p] < s then ok = true end end
                        end
                        if any and not ok then return false, "pre", id, e[5][1] end
                    end
                    if pomin[id] and pomin[id] < s then return false, "oa", id end
                    if pt[id] and pt[id] < s then return false, "oa", id end
                    open = open + 1
                    if open > P.LOG_MAX then return false, "log", id end
                elseif k == "o" then
                    if pt[id] and pt[id] < s then return false, "to", id end
                else
                    if po[id] and po[id] > s then return false, "to", id end
                    if origT[id] and lvl > origT[id] + LATE then return false, "late", id end
                    if pa[id] then open = open - 1 end
                end
            end
            cum = cum + XPOf(x, lvl)
        end
        return true, gmin, glist
    end

    -- Token einer Quest in einen anderen Eintrag beim selben NPC (oder < 80 yd am selben Ort) verschieben
    -- Quests mit Zeitlimit (Nutzer 23.11.2026, GuildTripQuestDB.timed = Sekunden): zwischen Annehmen und Abgeben
    -- hoechstens TIMED_SHARE des Limits (Weg + OBJ_MIN je Ziel + TALK_MIN je Annehmen/Abgeben, ohne Ruhestein) und
    -- kein Monster hauen dazwischen. Ueberschreitung kostet TIMED_PEN je Minute, damit der Optimierer sie aufloest.
    -- Geplant wird mit 60 % statt der geprueften 70 %: die harte Pruefung (check_route_areas.lua) waehlt Knoten und
    -- Wege etwas anders und sieht die spaeter eingefuegten Ziel-Teile – im 1. Lauf lagen 11 Zeitquests knapp darueber.
    local TIMED = Q.timed or {}
    local TIMED_SHARE, OBJ_MIN, TALK_MIN, TIMED_PEN = .6, 3, .5, 50
    local function Windows(o)
        local ep, prev, clock = 0, nil, 0
        local acc, res, at = {}, {}, {}
        for i, x in ipairs(o) do
            if x.anchor == "fp" and x.r.fpID then ep = ep + 1 end
            if x.w then
                if prev then clock = clock + C(prev, x.w, ep) end
                prev = x.w
            end
            for _, t in ipairs(x.toks) do
                local id = t[2]
                if TIMED[id] then
                    if t[1] == "a" and not acc[id] then acc[id] = clock at[id] = {i} end
                    if t[1] == "t" and acc[id] then res[id] = clock - acc[id] at[id][2] = i end
                end
                clock = clock + (t[1] == "o" and OBJ_MIN or TALK_MIN)
            end
        end
        return res, at
    end
    local function TimedOver(o)
        local res = Windows(o)
        local over = 0
        for id, m in pairs(res) do
            local lim = TIMED[id] / 60 * TIMED_SHARE
            if m > lim then over = over + (m - lim) end
        end
        return over
    end
    local function Cost(o) return WayCost(o) + TIMED_PEN * TimedOver(o) end
    local function Same(x, y)
        if not (x.w and y.w) or y.anchor or x.w[1] ~= y.w[1] then return false end
        if x.n and y.n and x.n == y.n then return true end
        return Dist(x.w, y.w) <= 80 and x.map == y.map
    end
    local function Clone(x)
        local c = {}
        for k, v in pairs(x) do c[k] = v end
        local t = {}
        for i, v in ipairs(x.toks) do t[i] = v end
        c.toks = t
        return c
    end
    local function Find(o, k, id)
        for i, x in ipairs(o) do for j, t in ipairs(x.toks) do if t[1] == k and t[2] == id then return i, j end end end
    end
    -- verschiebt Token (k,id) in einen passenden Eintrag: dir = -1 (frueher als lim) / 1 (spaeter als lim)
    local function MoveTok(o, k, id, dir, lim)
        local i, j = Find(o, k, id)
        if not i then return nil end
        local src = o[i]
        local target
        if dir < 0 then
            for q = math.min(lim - 1, #o), 1, -1 do if q ~= i and Same(src, o[q]) then target = q break end end
        else
            for q = math.max(lim + 1, 1), #o do if q ~= i and Same(src, o[q]) then target = q break end end
        end
        if not target then return nil end
        local n = {}
        for q, x in ipairs(o) do n[q] = x end
        local s2 = Clone(src)
        table.remove(s2.toks, j)
        local t2 = Clone(o[target])
        if k == "t" then table.insert(t2.toks, 1, {k, id}) else t2.toks[#t2.toks + 1] = {k, id} end
        n[i], n[target] = s2, t2
        if #s2.toks == 0 and not s2.anchor then table.remove(n, i) end
        return n
    end
    local function Pos(o, k, id, last)
        local best
        for i, x in ipairs(o) do
            for _, t in ipairs(x.toks) do
                if t[1] == k and t[2] == id then if not last then return i end best = i end
            end
        end
        return best
    end
    local function Repair(o)
        local tried = {}
        for _ = 1, 14 do
            local ok, why, id, p = Validate(o)
            if ok then return o, why end
            if why == "log" or why == "early" or why == "late" then return nil, why, id end
            local key = why .. id
            if tried[key] then return nil, "loop:" .. why, id end
            tried[key] = true
            local n
            if why == "oa" then
                -- Annahme steht hinter dem Ziel/der Abgabe: frueher beim selben NPC annehmen
                local lim = math.min(Pos(o, "o", id) or 1e9, Pos(o, "t", id) or 1e9)
                n = MoveTok(o, "a", id, -1, lim)
            elseif why == "to" then
                -- Abgabe vor dem (letzten) Ziel: spaeter beim selben NPC abgeben
                local lim = Pos(o, "o", id, true)
                n = lim and MoveTok(o, "t", id, 1, lim)
            elseif why == "pre" then
                -- Folgequest vor der Vorquest-Abgabe: spaeter annehmen (oft derselbe NPC)
                local lim = Pos(o, "t", p)
                n = lim and MoveTok(o, "a", id, 1, lim - 1)
                if not n then
                    -- oder die Vorquest frueher abgeben
                    local la = Pos(o, "a", id)
                    n = la and MoveTok(o, "t", p, -1, la + 1)
                end
            end
            if not n then return nil, "norep:" .. why, id end
            o = n
        end
        return nil, "many"
    end

    -- Reparatur nur nach hinten (fuer "spaeter"-Zuege): was zu frueh steht, wandert hinter das, wovon es abhaengt –
    -- Annehmen/Abgeben zum naechsten Besuch beim selben NPC, sonst eigener Halt direkt dahinter; Ziel-Halte als Ganzes.
    local function PutAfter(o, i, j, tok)
        -- Token tok aus Eintrag i hinter Eintrag j (j > i oder j >= i)
        local n = {}
        for q, x in ipairs(o) do n[q] = x end
        local src = n[i]
        local tgt
        -- naechster Besuch beim selben NPC, wenn er bald kommt (sonst eigener Halt, statt die Abgabe lange mitzuschleppen)
        for q = j + 1, math.min(#n, j + 40) do if q ~= i and Same(src, n[q]) then tgt = q break end end
        if not tgt and Same(src, n[j]) and j ~= i then tgt = j end
        local s2 = Clone(src)
        for k, t in ipairs(s2.toks) do if t == tok then table.remove(s2.toks, k) break end end
        if tgt then
            local c = Clone(n[tgt])
            if tok[1] == "t" and tgt ~= j then table.insert(c.toks, 1, tok) else c.toks[#c.toks + 1] = tok end
            n[tgt] = c
            n[i] = s2
        else
            local c = Clone(src)
            c.toks = {tok}
            n[i] = s2
            table.insert(n, j + 1, c)
        end
        if #n[i].toks == 0 and not n[i].anchor then table.remove(n, i) end
        return n
    end
    local function TokAt(o, k, id, last)
        local bi, bt
        for i, x in ipairs(o) do
            for _, t in ipairs(x.toks) do
                if t[1] == k and t[2] == id then if not last then return i, t end bi, bt = i, t end
            end
        end
        return bi, bt
    end
    local function RepairLater(o)
        for _ = 1, 40 do
            local ok, why, id, p = Validate(o)
            if ok then return o, why end
            local n
            if why == "pre" then
                local i, t = TokAt(o, "a", id)
                local j = TokAt(o, "t", p)
                if i and j and j >= i then n = PutAfter(o, i, j, t) end
            elseif why == "oa" then
                local ia = TokAt(o, "a", id)
                local io = TokAt(o, "o", id)
                if ia and io and io <= ia then
                    -- ganzer Ziel-Halt hinter die Annahme
                    n = {}
                    local moved = o[io]
                    for q, x in ipairs(o) do
                        if q ~= io then n[#n + 1] = x end
                        if q == ia then n[#n + 1] = moved end
                    end
                    if io == ia then n = nil end
                else
                    local it, t = TokAt(o, "t", id)
                    if ia and it and it <= ia then n = PutAfter(o, it, ia, t) end
                end
            elseif why == "to" then
                local it, t = TokAt(o, "t", id)
                local io = TokAt(o, "o", id, true)
                if it and io and io >= it then n = PutAfter(o, it, io, t) end
            end
            if not n then return nil, "later:" .. why, id end
            o = n
        end
        return nil, "many"
    end

    local order = {}
    for i, x in ipairs(E) do order[i] = x end
    local ok0, why0, id0, p0 = Validate(order)
    if not ok0 then
        -- Ausgangsroute verletzt selbst eine Regel (Nachstellung prueft anders): nichts aendern
        return route, {saved = 0, moves = 0, removed = 0, xpDiff = 0, skipped = true, why = why0, id = id0, p = p0}
    end
    -- Weg + Monster hauen (vorher/nachher gleich gerechnet); cur zaehlt zusaetzlich die Strafe fuer Zeitquests
    local before = WayCost(order) + (tonumber(why0) or 0)
    local cur = Cost(order) + (tonumber(why0) or 0)
    local moves, tokMoves = 0, 0
    local CELL = 600

    -- 1) Eintraege, die nur annehmen/abgeben, zu einem anderen Besuch beim selben NPC (frueher oder spaeter)
    local function TokenPass()
        local i = 1
        while i <= #order do
            local x = order[i]
            if Quest(x) then
                local hasObj = false
                for _, t in ipairs(x.toks) do if t[1] == "o" then hasObj = true end end
                if not hasObj then
                    local o = order
                    local okAll = true
                    -- alle Tokens wegbringen: Annahmen nach vorn, Abgaben nach hinten, sonst andersherum
                    local toks = {}
                    for _, t in ipairs(x.toks) do toks[#toks + 1] = t end
                    for _, t in ipairs(toks) do
                        local pi = Pos(o, t[1], t[2])
                        local n = pi and (MoveTok(o, t[1], t[2], t[1] == "a" and -1 or 1, pi) or MoveTok(o, t[1], t[2], t[1] == "a" and 1 or -1, pi))
                        if not n then okAll = false break end
                        o = n
                    end
                    if okAll and #o < #order then
                        local gm
                        o, gm = Repair(o)
                        if o then
                            local c = Cost(o) + gm
                            if c < cur - .05 then
                                order, cur = o, c
                                tokMoves = tokMoves + 1
                                i = i - 1
                            end
                        end
                    end
                end
            end
            i = i + 1
        end
    end

    -- OPT_DEBUG=<Token> (z. B. o867): Kandidaten fuer Bloecke mit diesem Token zeigen
    local DBG
    if os.getenv("OPT_DEBUG") then
        local want = os.getenv("OPT_DEBUG")
        DBG = function(o, a, b)
            for q = a, b do for _, t in ipairs(o[q].toks) do if t[1] .. t[2] == want then return true end end end
        end
    end
    -- naechster Ort davor/danach (Monster-hauen-Pausen ohne Ort zaehlen nicht)
    local function PrevW(o, i) for q = i, 1, -1 do if o[q] and o[q].w then return o[q].w end end end
    local function NextW(o, i) for q = i, #o do if o[q] and o[q].w then return o[q].w end end end
    -- Besuch [a..b] spaeter vor order[g]: was dazwischen davon abhaengt (Abgaben, Folgequests, deren Ziele), kommt mit.
    -- Annehmen/Abgeben gehen zum naechsten Besuch beim selben NPC nach der neuen Stelle (sonst eigener Halt dort),
    -- Ziel-Halte wandern hinter den Besuch.
    local function Closure(o, a, b, g)
        local M = {}
        local function Add(t) M[t[1] .. t[2]] = true end
        for q = a, b do for _, t in ipairs(o[q].toks) do Add(t) end end
        local function Dep(t)
            local k, id = t[1], t[2]
            if k == "t" then return M["o" .. id] or M["a" .. id] end
            if k == "o" then return M["a" .. id] end
            local e = Q.q[id] or {}
            for _, list in ipairs({type(e[9]) == "table" and e[9] or {}, type(e[5]) == "table" and e[5] or {}}) do
                for _, p in ipairs(list) do if M["t" .. p] then return true end end
            end
            -- Annahme einer Quest, deren Ziel/Abgabe schon mitwandert, ist nie abhaengig
            return false
        end
        local keep, L, T = {}, {}, {}
        for i = b + 1, g - 1 do
            local x = o[i]
            if not Quest(x) then keep[#keep + 1] = x
            else
                local dep, hasO = {}, false
                for _, t in ipairs(x.toks) do if Dep(t) then dep[#dep + 1] = t if t[1] == "o" then hasO = true end end end
                if #dep == 0 then keep[#keep + 1] = x
                elseif hasO then
                    L[#L + 1] = x
                    for _, t in ipairs(x.toks) do Add(t) end
                else
                    local rest = Clone(x)
                    rest.toks = {}
                    local isDep = {}
                    for _, t in ipairs(dep) do isDep[t] = true Add(t) end
                    for _, t in ipairs(x.toks) do if not isDep[t] then rest.toks[#rest.toks + 1] = t end end
                    if #rest.toks > 0 then keep[#keep + 1] = rest end
                    T[#T + 1] = {x, dep}
                end
            end
        end
        if #L + #T > 40 then return nil, "closure", 0 end
        local n = {}
        for i = 1, a - 1 do n[#n + 1] = o[i] end
        for _, x in ipairs(keep) do n[#n + 1] = x end
        for q = a, b do n[#n + 1] = o[q] end
        for _, x in ipairs(L) do n[#n + 1] = x end
        local after = #n
        for i = g, #o do n[#n + 1] = o[i] end
        -- Tokens zum naechsten Besuch beim selben NPC (ab der neuen Stelle), sonst eigener Halt direkt danach
        local extra = {}
        for _, td in ipairs(T) do
            local src, dep = td[1], td[2]
            local tgt
            for q = after - #L - (b - a + 1) + 1, #n do if Same(src, n[q]) then tgt = q break end end
            if tgt then
                local c = Clone(n[tgt])
                for _, t in ipairs(dep) do if t[1] == "t" then table.insert(c.toks, 1, t) else c.toks[#c.toks + 1] = t end end
                n[tgt] = c
            else
                local c = Clone(src)
                c.toks = {}
                for _, t in ipairs(dep) do c.toks[#c.toks + 1] = t end
                extra[#extra + 1] = c
            end
        end
        if #extra > 0 then
            for k = #extra, 1, -1 do table.insert(n, after + 1, extra[k]) end
        end
        return n
    end
    -- 2) Bloecke verschieben
    local function BlockPass()
        local improved = false
        local function Grid()
            local g = {}
            for i, x in ipairs(order) do
                if x.w then
                    local key = x.w[1] .. ":" .. math.floor(x.w[2] / CELL) .. ":" .. math.floor(x.w[3] / CELL)
                    local l = g[key] if not l then l = {} g[key] = l end
                    l[#l + 1] = i
                end
            end
            return g
        end
        local function Near(g, w, out)
            local cx, cy = math.floor(w[2] / CELL), math.floor(w[3] / CELL)
            for dx = -1, 1 do for dy = -1, 1 do
                local l = g[w[1] .. ":" .. (cx + dx) .. ":" .. (cy + dy)]
                if l then for _, i in ipairs(l) do out[i] = true end end
            end end
        end
        -- Besuche: Quest-Eintraege am Stueck mit Wegen <= 700 yd
        local function Runs()
            local starts, ends = {}, {}
            local s
            for i, x in ipairs(order) do
                local cont = Quest(x) and s and order[i - 1] and Quest(order[i - 1]) and order[i - 1].w[1] == x.w[1] and Dist(order[i - 1].w, x.w) <= 700
                if Quest(x) then
                    if not cont then if s then ends[#ends + 1] = i - 1 end s = i starts[#starts + 1] = i end
                else
                    if s then ends[#ends + 1] = i - 1 s = nil end
                end
            end
            if s then ends[#ends + 1] = #order end
            return starts, ends
        end
        local a = 1
        local grid, ep = Grid(), Epochs(order)
        local rs, re = Runs()
        local runAt = {}
        for k, s in ipairs(rs) do runAt[s] = k end
        while a <= #order do
            local accepted = false
            if Quest(order[a]) then
                local blocks = {}
                for len = 1, 3 do
                    local b = a + len - 1
                    local okb = b <= #order
                    for q = a, math.min(b, #order) do if not Quest(order[q]) then okb = false end end
                    if okb then blocks[#blocks + 1] = b end
                end
                local k = runAt[a]
                if k then
                    for span = 1, 4 do
                        local b = re[k + span - 1]
                        if b and b - a + 1 > 3 and b - a < 60 then
                            local okb = true
                            for q = a, b do if not Quest(order[q]) then okb = false break end end
                            if okb then blocks[#blocks + 1] = b end
                        end
                    end
                end
                for _, b in ipairs(blocks) do
                    local B1, BL = order[a], order[b]
                    local pw = PrevW(order, a - 1)
                    local nw = NextW(order, b + 1)
                    local rem = C(pw, B1.w, ep[a]) + C(BL.w, nw, ep[math.min(b + 1, #order)]) - C(pw, nw, ep[math.min(b + 1, #order)])
                    if rem > .3 then
                        local cand = {}
                        Near(grid, B1.w, cand)
                        Near(grid, BL.w, cand)
                        local list = {}
                        for i in pairs(cand) do
                            for _, g in ipairs({i, i + 1}) do
                                -- Luecke vor order[g] (g = Index in der Originalfolge), nicht im/am Block
                                if g < a or g > b + 1 then
                                    local p, n = PrevW(order, g - 1), NextW(order, g)
                                    if (not p or p[1] == B1.w[1]) and (not n or n[1] == BL.w[1]) and not list[g] then
                                        local e2 = ep[math.min(g, #order)]
                                        local add = C(p, B1.w, e2) + C(BL.w, n, e2) - C(p, n, e2)
                                        if add < rem - .3 then list[g] = rem - add end
                                    end
                                end
                            end
                        end
                        local sorted = {}
                        for g, gain in pairs(list) do sorted[#sorted + 1] = {g, gain} end
                        table.sort(sorted, function(u, v) return u[2] > v[2] end)
                        local closureTries = 0
                        for c = 1, math.min(8, #sorted) do
                            local g = sorted[c][1]
                            local n = {}
                            for i = 1, #order do
                                if i == g then for q = a, b do n[#n + 1] = order[q] end end
                                if i < a or i > b then n[#n + 1] = order[i] end
                            end
                            if g == #order + 1 then for q = a, b do n[#n + 1] = order[q] end end
                            local why, wid
                            n, why, wid = Repair(n)
                            local closure
                            if not n and g > b + 1 and sorted[c][2] >= 2 and closureTries < 2 then
                                closureTries = closureTries + 1
                                -- spaeter: alles, was zwischen alter und neuer Stelle davon abhaengt, wandert mit
                                n, why, wid = Closure(order, a, b, g)
                                if n then n, why, wid = RepairLater(n) end
                                closure = true
                            end
                            if DBG and DBG(order, a, b) then
                                print(("    DBG Block %d-%d -> vor %d (%s)%s, Schaetzung %.1f min: %s"):format(a, b, g, order[g] and (order[g].r.q or order[g].anchor) or "Ende", closure and " +mit" or "", sorted[c][2],
                                    n and ("gueltig, gespart " .. ("%.1f"):format(cur - Cost(n) - why) .. (" (Hauen %.1f)"):format(why)) or (tostring(why) .. " " .. tostring(wid))))
                            end
                            if n then
                                local cst = Cost(n) + why
                                if cst < cur - .2 then
                                    order, cur = n, cst
                                    moves = moves + 1
                                    accepted, improved = true, true
                                    break
                                end
                            end
                        end
                    end
                    if accepted then break end
                end
            end
            if accepted then
                grid, ep = Grid(), Epochs(order)
                rs, re = Runs()
                runAt = {}
                for k, s in ipairs(rs) do runAt[s] = k end
                a = math.max(1, a - 3)
            else a = a + 1 end
        end
        return improved
    end

    -- Ziele an einen anderen Ort derselben Gegner (Spieltest 23.11.2026, Orc: "Raptorhoerner" o865 stand kurz vor
    -- Ratschet beim Einzel-Raptor 3257, dieselben Raptoren 3256 stehen aber im Nordbrachland, wo die Route vorher
    -- ist – Nutzer: "Quests, deren Gegner in derselben Gegend stehen, gleich dort mit erledigen"). Reine Ziel-Schritte
    -- einer Quest duerfen an jeden Punkt ihrer Ziel-Knoten (Q.q[id][8]) wandern, an die Stelle mit kleinstem Umweg.
    local altMemo = {}
    local function Alts(id)
        local a = altMemo[id]
        if a then return a end
        a = {}
        local e = Q.q[id]
        if env.world and e and type(e[8]) == "table" then
            for _, nr in ipairs(e[8]) do
                local n = Q.n and Q.n[nr]
                for i = 2, n and #n or 0, 3 do
                    local c, wx, wy = env.world(n[i], n[i + 1] / 1000, n[i + 2] / 1000)
                    if c and #a < 60 then a[#a + 1] = {c, wx, wy, nr = nr, map = n[i]} end
                end
            end
        end
        altMemo[id] = a
        return a
    end
    local function ObjId(x)
        if not Quest(x) then return nil end
        local id
        for _, t in ipairs(x.toks) do
            if t[1] ~= "o" or (id and id ~= t[2]) then return nil end
            id = t[2]
        end
        return id
    end
    local objMoves = 0
    local function ObjPass()
        local improved = false
        local a = 1
        while a <= #order do
            local x = order[a]
            local id = ObjId(x)
            local alts = id and Alts(id) or {}
            local done = false
            if #alts > 1 then
                local ep = Epochs(order)
                local pw, nw = PrevW(order, a - 1), NextW(order, a + 1)
                local rem = C(pw, x.w, ep[a]) + C(x.w, nw, ep[math.min(a + 1, #order)]) - C(pw, nw, ep[math.min(a + 1, #order)])
                if rem > .3 then
                    -- Reihenfolge ohne den Schritt; Luecke g = vor o2[g]
                    local o2, orig = {}, {}
                    for i, y in ipairs(order) do if i ~= a then o2[#o2 + 1] = y orig[#o2] = i end end
                    local cands = {}
                    for g = 1, #o2 + 1 do
                        local p, n = PrevW(o2, g - 1), NextW(o2, g)
                        local e2 = ep[math.min(orig[g] or #order, #order)]
                        local base = (p and n) and C(p, n, e2) or 0
                        local best, bp
                        for _, pt in ipairs(alts) do
                            if (not p or p[1] == pt[1]) and (not n or n[1] == pt[1]) and (not p or Dist(p, pt) < 3000 or (n and Dist(n, pt) < 3000)) then
                                local add = C(p, pt, e2) + C(pt, n, e2) - base
                                if not best or add < best then best, bp = add, pt end
                            end
                        end
                        if best and best < rem - .3 then cands[#cands + 1] = {g, rem - best, bp} end
                    end
                    table.sort(cands, function(u, v) return u[2] > v[2] end)
                    for c = 1, math.min(8, #cands) do
                        local g, pt = cands[c][1], cands[c][3]
                        local y = Clone(x)
                        y.w, y.map, y.n = {pt[1], pt[2], pt[3]}, pt.map, pt.nr
                        local r = {}
                        for k, v in pairs(x.r) do r[k] = v end
                        r.w, r.map, r.n = y.w, y.map, y.n
                        y.r = r
                        local n = {}
                        for i = 1, #o2 do
                            if i == g then n[#n + 1] = y end
                            n[#n + 1] = o2[i]
                        end
                        if g == #o2 + 1 then n[#n + 1] = y end
                        local why
                        n, why = Repair(n)
                        if n then
                            local cst = Cost(n) + why
                            if cst < cur - .2 then
                                if env.verbose and os.getenv("OPT_DEBUG") then print(("    ZIEL o%d -> vor %d (%.1f min)"):format(id, g, cur - cst)) end
                                order, cur = n, cst
                                objMoves = objMoves + 1
                                improved, done = true, true
                                break
                            end
                        end
                    end
                end
            end
            if not done then a = a + 1 end
        end
        return improved
    end

    TokenPass()
    for pass = 1, env.passes or 6 do
        local imp = BlockPass()
        if ObjPass() then imp = true end
        TokenPass()
        if env.verbose then print(("  GESAMT Durchgang %d: Weg %.0f min (vorher %.0f), %d Verschiebungen, %d Besuche nur zum Annehmen/Abgeben gespart"):format(pass, cur, before, moves, tokMoves)) end
        if not imp then break end
    end

    -- Zeitquests, die noch zu lange offen sind: Annehmen, Ziele und Abgabe als Kette an eine Stelle (bei der Annahme,
    -- beim ersten Ziel oder vor der Abgabe – die billigste gueltige); geht keine, Quest samt Folgequests aus der Route
    local timedFixed, timedRemoved = 0, {}
    local function TimedOK(o, id)
        local res, at = Windows(o)
        if not res[id] then return not (at[id]) end
        if res[id] > TIMED[id] / 60 * TIMED_SHARE then return false end
        local ok, _, gl = Validate(o, true)
        if not ok then return false end
        for _, g in ipairs(gl or {}) do if g[1] > at[id][1] and g[1] <= at[id][2] then return false end end
        return true
    end
    local function Chain(o, id, after)
        local n, chain = {}, {}
        for _, x in ipairs(o) do
            local keep, mine = {}, {}
            for _, t in ipairs(x.toks) do if t[2] == id then mine[#mine + 1] = t else keep[#keep + 1] = t end end
            if #mine > 0 then
                local c = Clone(x)
                c.toks = mine
                if #keep > 0 then c.base = 0 end
                chain[#chain + 1] = c
            end
        end
        if after == 0 then for _, c in ipairs(chain) do n[#n + 1] = c end end
        for i, x in ipairs(o) do
            local keep = {}
            for _, t in ipairs(x.toks) do if t[2] ~= id then keep[#keep + 1] = t end end
            if #keep == #x.toks then n[#n + 1] = x
            elseif #keep > 0 then local y = Clone(x) y.toks = keep n[#n + 1] = y end
            if i == after then for _, c in ipairs(chain) do n[#n + 1] = c end end
        end
        return n
    end
    local function Drop(o, ids)
        local n = {}
        for _, x in ipairs(o) do
            local keep = {}
            for _, t in ipairs(x.toks) do if not ids[t[2]] then keep[#keep + 1] = t end end
            if #keep == #x.toks then n[#n + 1] = x
            elseif #keep > 0 then local y = Clone(x) y.toks = keep n[#n + 1] = y end
        end
        return n
    end
    -- Umstellen/Herausnehmen einer Zeitquest verschiebt andere Fenster (Repair, Hauen) – bis nichts mehr bricht
    for _ = 1, 5 do
        local changed = false
        local res = Windows(order)
        local ids = {}
        for id in pairs(res) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            if not TimedOK(order, id) then
                local ia, io, it
                for i, x in ipairs(order) do
                    for _, t in ipairs(x.toks) do
                        if t[2] == id then
                            if t[1] == "a" and not ia then ia = i end
                            if t[1] == "o" and not io then io = i end
                            if t[1] == "t" then it = i end
                        end
                    end
                end
                local best, bc
                for _, after in ipairs({ia or 0, (io or it or 1) - 1, (it or 1) - 1}) do
                    local n, why = Repair(Chain(order, id, math.max(0, after)))
                    if n and TimedOK(n, id) then
                        local c = Cost(n) + why
                        if not bc or c < bc then best, bc = n, c end
                    end
                end
                changed = true
                if best then
                    order, cur = best, bc
                    timedFixed = timedFixed + 1
                else
                    -- Quest und alles, was auf ihr aufbaut, aus der Route
                    local drop, grow = {[id] = true}, true
                    while grow do
                        grow = false
                        for _, x in ipairs(order) do
                            for _, t in ipairs(x.toks) do
                                local e = Q.q[t[2]]
                                if e and not drop[t[2]] then
                                    for _, list in ipairs({type(e[5]) == "table" and e[5] or {}, type(e[9]) == "table" and e[9] or {}}) do
                                        for _, p in ipairs(list) do if drop[p] then drop[t[2]] = true grow = true end end
                                    end
                                end
                            end
                        end
                    end
                    local n, why = Repair(Drop(order, drop))
                    if n then
                        order, cur = n, Cost(n) + why
                        for d in pairs(drop) do timedRemoved[#timedRemoved + 1] = d end
                    end
                end
            end
        end
        if not changed then break end
    end
    if os.getenv("TIMED_DEBUG") then
        local res, at = Windows(order)
        for id, m in pairs(res) do io.stderr:write(("TIMED q%d %.1f min (lim %.0f) at %d..%d\n"):format(id, m, TIMED[id] / 60, at[id][1], at[id][2])) end
        for id, a in pairs(at) do if not res[id] then io.stderr:write(("TIMED q%d nur angenommen at %d\n"):format(id, a[1])) end end
    end

    -- zurueck in Routen-Schritte: Stufe und EP je Schritt neu, gleicher NPC direkt hintereinander = ein Schritt
    local out, cum = {}, startXP
    local xpOld = 0
    for _, r in ipairs(route) do xpOld = xpOld + (r.g or 0) end
    local _, gminEnd, glist = Validate(order, true)
    local gAt, gXP = {}, 0
    for _, g in ipairs(glist or {}) do gAt[g[1]] = g end
    local lastW, lastMap
    for i, x in ipairs(order) do
        local gr = gAt[i]
        if gr then
            -- Monster hauen bis zur noetigen Stufe (wie im Spiel "Monster hauen bis X"), dort wo man gerade ist
            local lv0 = LevelAt(cum)
            out[#out + 1] = {k = "grind", to = gr[3], g = gr[2], w = lastW, map = lastMap, l = lv0, added = true}
            cum, gXP = cum + gr[2], gXP + gr[2]
        end
        if x.w then lastW, lastMap = x.w, x.map end
        local lvl = LevelAt(cum)
        local g = XPOf(x, lvl)
        local r = {}
        for k, v in pairs(x.r) do r[k] = v end
        if #x.toks > 0 then
            local parts = {}
            for _, t in ipairs(x.toks) do parts[#parts + 1] = t[1] .. t[2] end
            r.q = table.concat(parts, " ")
        else r.q = nil end
        r.g = g
        r.l = lvl -- auch Flug/Ruhestein/Hauen: Stufe an dieser Stelle der neuen Reihenfolge
        local last = out[#out]
        if last and last.q and r.q and not last.k and not r.k and last.n == r.n and last.map == r.map and last.l == r.l then
            last.q = last.q .. " " .. r.q
            last.g = (last.g or 0) + g
        elseif r.q or r.k then out[#out + 1] = r end
        cum = cum + g
    end
    local xpNew = cum - startXP - gXP
    local after = WayCost(order) + (gminEnd or 0)
    return out, {saved = before - after, moves = moves, tokMoves = tokMoves, objMoves = objMoves, removed = #route - #out, xpDiff = xpNew - xpOld,
        before = before, after = after, grindMin = gminEnd, grinds = #(glist or {}), timedFixed = timedFixed, timedRemoved = timedRemoved}
end

return M
