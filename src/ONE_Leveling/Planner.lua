-- Guild Trip Quest-Fuehrung: Planer (0.6.9, Routen seit 21.11.2026 als Schleifen um Stuetzpunkte).
-- Reine Rechnung, keine Oberflaeche – offline testbar, nachstellbar mit scripts/sim_leveling.lua (echte Daten).
-- Wertung (mit dem Nutzer abgestimmt, docs/vorschau_quest_fuehrung.html):
--  * Pflicht: Dungeon-Quests (mit allen Vorquests), Klassenquests, Vorquests von allem, was gemacht wird
--  * Lohnt: EP pro Minute ueber "nur Monster hauen" (Faktor je Tempo), Gegner-EP zaehlen mit
--  * Mehrwert: Upgrade fuer die Klasse, groessere Tasche, viel Gold – darf etwas langsamer sein
--  * Gruppe: Elite-/Gruppenquests nur in einer Gruppe (sonst "Gruppe suchen"), Dungeon-Quests immer
-- Route: Schleifen um Stuetzpunkte (Questgeber nah beieinander) wie gute Leveling-Routen – am Stuetzpunkt annehmen,
-- die Ziele einer Gegend am Stueck, abgeben, wo die Abgaben sind. Jede moegliche naechste Schleife wird mit EP pro
-- Minute inkl. Anreise bewertet, die beste kommt dran; eine Quest kommt in eine Schleife, wenn sie dort mehr bringt
-- als Monster hauen (Mehrweg in der ganzen Schleife zaehlt). Siehe Abschnitt 5 in P:Plan.
-- Eingabe ctx (siehe Planner:Plan), Daten: GuildTripQuestDB (ONE_QuestDB) + GuildTripLeveling (Rewards.lua).
local _, lev = ...
local P = {}
lev.Planner = P

P.TEMPO = {need = 1.3, balanced = 1.0, all = 0}  -- Faktor auf "nur Monster hauen"
P.TEMPO_ORDER = {"need", "balanced", "all"}
P.ROUTE_TEMPO = "balanced"  -- feste Route: Schwelle fuer selbst angenommene Quests (Einbauen ab halber Monster-EP/min)
-- Auswahl stabil halten (Spieltest 20.11.2026: in Ratchet nach Crossroads geschickt, in Crossroads nach Ratchet):
-- schon gewaehlte Quests bleiben bis 80 % der Schwelle, neu dazukommende brauchen 115 % – ausser ihr Geber
-- steht gleich nebenan (hoechstens P.NEW_HERE Minuten).
P.KEEP_SLACK = .8
-- Fester Fahrplan (Nutzer 20.11.2026: "ich moechte doch einfach nur, dass man so schnell wie moeglich levelt" –
-- nach zwei Fluegen umsonst Ratchet <-> Crossroads): ctx.follow = {[StopKey] = Rang} aus dem letzten Plan.
-- Die alten Halte kommen in alter Reihenfolge dran; Neues nur, wenn es direkt hier ist (hoechstens P.FOLLOW_HERE
-- Minuten und naeher als der naechste alte Halt) – z. B. eine neue Quest beim Geber, an dem man gerade steht.
-- Alles andere Neue kommt nach den alten Halten. Frisch geplant wird nur bei echten Aenderungen (Guide).
P.FOLLOW_HERE = 1
-- ... und nur Kurzes (Annehmen, Abgeben, Ruhestein): Monster/Gegenstaende fuer eine Quest bleiben in ihrer Runde
-- (Spieltest 21.11.2026: Orgrimmar -> Zeppelin, am Turm ploetzlich "Verborgene Feinde" am Schaedelfels)
P.OBJ_TOGETHER = .5      -- Quest-Ziele so dicht beieinander (Minuten zu Fuss): zusammen in einem Schritt
P.FOLLOW_WORK = 3        -- Nachstellung 21.11.2026: 1 -> 16 Rueckwege, 3 -> 11 (Insignie am Schaedelfels ~2 min: mitnehmen)
-- Dungeonquests (Nutzer 20.11.2026: "die [Dungeons] muessen nicht in den Guide, die Quests dafuer jedoch schon" –
-- Dungeons laeuft man ueber den Dungeon-Finder): kein Dungeon-Halt mehr. Annehmen und Vorquest-Ketten nur im
-- Gebiet, in dem man gerade ist, oder direkt am Weg (hoechstens P.BYWAY_NEAR Minuten zu Fuss) – kein Umweg in
-- ein anderes Gebiet ("nur wenn du sowieso dort bist"). Abgeben normal, sobald die Quest im Log fertig ist.
P.BYWAY_NEAR = 1.5
-- Aufstieg vorausrechnen (Nutzer 20.11.2026, wie RestedXP "toete Monster bis 2800/5000 EP"):
P.WALK_XP = .15          -- zu Fuss unterwegs bekommt man nebenbei so viel der "nur Monster hauen"-EP/min
P.HUB_NEAR = 1           -- so nah (Minuten) gilt ein Geber als "hier"
P.GRIND_SHARE = .25      -- hoechstens so viel einer Stufe hier Monster hauen, damit hier Neues frei wird
P.NEW_SLACK = 1.15
P.NEW_HERE = 1
P.KILL_SEC = 22          -- je Gegner/Sammelaktion inkl. Erholen
P.GRIND_REAL = .7        -- reines Monster hauen schafft im Schnitt nur so viel davon (Wege zwischen Gegnern, Pausen)
P.TALK_MIN = .4          -- je Quest Annehmen + Abgeben
P.DETOUR = 1.3           -- Wegenetz im Schnitt etwas laenger als Luftlinie
P.HORIZON = 2            -- Stufen voraus planen
-- Schleifen um Stuetzpunkte (Nutzer 21.11.2026): Stuetzpunkt = bereite Halte hoechstens P.HUB_R yd beieinander;
-- in eine Schleife kommen Quests mit einem Halt hoechstens P.CAND_R Minuten vom Stuetzpunkt; eine Schleife
-- dauert hoechstens etwa P.LOOP_MAX Minuten; je Durchlauf werden die P.SEEDS naechsten Stuetzpunkte (und je
-- Gebiet der naechste) verglichen. Fremdes Gebiet muss P.ZONE_HYST mehr bringen (kein Hin und Her bei Gleichstand).
P.HUB_R = 150
P.CAND_R = 4
P.LOOP_MAX = 40
P.SEEDS = 8
P.ZONE_HYST = .2
P.FAR_LOOP = 5           -- Schleife mit so viel Anreise (oder anderer Kontinent): ...
P.STAY_MIN = 3           -- ... gibt es dort danach weniger als so viele Quests, zaehlt die Rueckreise mit
P.ZONE_BACK = 3          -- verlassenes Gebiet: Schleifen dort zaehlen nur ein Viertel (Reste nur, wenn man ohnehin
P.ZONE_BACK_LVL = 2      -- zurueckkommt) – bis man so viele Stufen weiter ist (dann gibt es dort Neues)
P.CONT_HYST = .3         -- anderer Kontinent muss so viel mehr bringen
P.CLASS_NEAR = 5         -- Klassenquest in eine Schleife, wenn sie hoechstens so viele Minuten mehr kostet
P.CLASS_BONUS = 1.5      -- Schleife mit Klassenquest gilt als so viel besser (nur Reihen mit Zauber am Ende, s. u.)
P.FLOW_HYST = 1          -- feste Gebietsfolge: anderes Gebiet erst, wenn es doppelt so viel bringt (kein Pendeln)
P.FLOW_MIN_QUESTS = 2    -- feste Gebietsfolge: in ein anderes Gebiet/eine Stadt erst fuer so viele Quests
P.FLOW_FAR = 6           -- feste Gebietsfolge: Halt in anderem Gebiet so weit weg (min) gehoert nicht in die Runde
P.ROUTE_GRIND_MIN = 3    -- feste Route: Monster hauen erst ab so vielen Minuten als eigener Schritt
-- feste Route: Spaeteres genau hier nur vorziehen, wenn es in den naechsten so vielen Routen-Plaetzen kommt (Spieltest
-- 22.11.2026: kurz nach Crossroads zum Einkaufen geflogen – Guide schwenkte auf die Crossroads-Quests um, gemeint war
-- nur Einkaufen und zurueck nach Ratchet)
P.ROUTE_PULL = 3
-- feste Route: Ausruestungs-Quests (ctx.gear, Nutzer 22.11.2026 "ja, gib ihr den auftrag so"): eine ganze Reihe kommt
-- nur hinein, wenn jeder Halt in einem Gebiet liegt, durch das die Route ohnehin kommt (oder in dem man steht), direkt
-- neben einem Routen-Halt desselben Gebiets eingereiht wird und die Reihe hoechstens so viele Minuten mehr kostet,
-- als ihre EP wert sind (kein Zickzack fuer ein Teil)
P.GEAR_EXTRA = 6
P.PREACCEPT_LOOPS = 3     -- am Stuetzpunkt gleich die Annahmen fuer so viele weitere Runden von dort
P.FLOW_ACTIVE = 1        -- feste Gebietsfolge: hoechstens so viele Gebiete gleichzeitig
P.FLOW_SLACK = .5        -- feste Gebietsfolge: Quests dort lohnen schon ab halber Schwelle
P.CHAIN_LOOK = 8         -- so weit in einer Klassenquest-Reihe nach Zauber/Verbesserung schauen
P.CHAIN_SHARE = .5       -- so viel der EP der Folgequest zaehlt fuer die Vorquest
P.LOG_MAX = 35           -- Questlog: hoechstens so viele Quests gleichzeitig  -- Forever: Questlog 40 (Spielbild 21.11.2026 "Quests: 9/40"), etwas Luft
P.GRIND_HUB_MAX = 10     -- hoechstens so viele Minuten Monster hauen, damit am Stuetzpunkt Neues frei wird
-- Haendler (Nutzer 21.11.2026): nur am Stuetzpunkt (hoechstens P.VENDOR_NEAR Minuten vom Weg), wenn hoechstens
-- P.BAG_LOW Taschenplaetze frei sind (oder nach der Schleife nur noch P.BAG_SOON; je P.LOOT_PER_SLOT Gegner etwa
-- ein Platz)
P.VENDOR_NEAR = 1
P.VENDOR_MIN = .5
P.BAG_LOW = 4
P.DUNGEON_NEAR = 1       -- Hinweis Dungeon-(Vor-)Quest nur bei hoechstens so viel Umweg (Minuten)
P.MISSED_NEAR = 1        -- Hinweis verpasste fruehere Annahme (Guide.RouteFollow) nur bei hoechstens so viel Umweg (Minuten)
P.DUNGEON_RUN = 60       -- feste Route: so lange dauert ein Dungeon-Lauf (Minuten, wie in scripts/sim_leveling.lua)
P.MISSED_PULL = 5        -- statt langem Hauen: verpasste Annahmen bis so viele Minuten entfernt zurueck in die Route
P.ROUTE_GRIND_MAX = 10   -- feste Route: laenger hauen nur, wenn in der Route sonst nichts geht (Nutzer: ~10 min Hauen ok)
P.ROUTE_SKIP_AHEAD = 30  -- ... und nur Quest-Schritte so viele Plaetze voraus vorziehen
P.BAG_SOON = 1
P.LOOT_PER_SLOT = 8
-- Quest-Ziele draussen erst angehen, wenn die Queststufe hoechstens so viel ueber deiner (Plan-)Stufe liegt
-- (Spieltest 19.11.2026: mit 14 "Raptorhoerner [18]" erledigen – Gegner zu stark)
P.OBJ_AHEAD = 2
-- feste Route (Gebiets-Schleife, 24.11.2026): in Stufenluecken stehen Quests bis 3 ueber der eigenen Stufe in der Route
-- (scripts/build_loop.lua AHEAD_GAP) – deren Ziele duerfen dann auch dran sein
P.ROUTE_OBJ_AHEAD = 3
P.MAX_STEPS = 60
P.MAX_MINUTES = 150
P.FAR_MIN = 12           -- anderer Kontinent / unbekannter Ort
P.AREA_MAX = 40          -- Spawnpunkte je Quest-Ziel fuer Pfeil/Entfernung (Zielgebiet)
P.VALUE_SLACK = .6       -- Mehrwert-Quests duerfen so viel langsamer sein
P.UPGRADE_PCT = 10
P.BUSY_WORK = 40         -- ab hier "viel Aufwand / seltene Drops"
P.FLY_SPEED = 30         -- Flugtier, Yards je Sekunde (Classic ~ 30)
P.FLY_EXTRA = .7         -- Minuten fuer Flugmeister ansprechen, Auf-/Absteigen
P.FLY_DETOUR = 1.15      -- Flugrouten sind keine Luftlinie
P.BOAT_MIN = 6           -- Warten + Ueberfahrt Schiff/Zeppelin (Minuten)
P.UNKNOWN_TRIP = 30      -- anderer Kontinent ohne bekannte Verbindung (z. B. neue Forever-Gebiete)
-- Vor dem Gebietswechsel fertige Abgaben im eigenen Gebiet abgeben, wenn sie hoechstens so viele Minuten Umweg
-- kosten (Spieltest 20.11.2026: mit 2 offenen Abgaben im Brachland nach Orgrimmar geschickt)
P.ZONE_FINISH = 6
P.CITY = {[1454] = true, [1456] = true, [1458] = true, [1453] = true, [1455] = true, [1457] = true}
-- Hinein/hinaus in eine Hauptstadt kostet mehr als die Luftlinie (Aufzuege, Ringe, Treppen; Spieltest 21.11.2026:
-- "fuer die Abgabe muesste ich direkt nach Undercity, die Wege darin sind recht langwierig"), Minuten je Richtung
P.CITY_IN = {[1458] = 2, [1456] = 1.5, [1455] = 1, [1453] = 1, [1454] = .5, [1457] = .5}
-- Sehr empfohlene Reihen (Schlafsack) mit "jetzt erledigen" haben Vorrang: eigene Schleife, kommt zuerst
-- (Nutzer 19.11.2026: "gerade diese wichtige Questreihe soll Prioritaet haben", loggt meist draussen aus)
-- Wie bei handgeschriebenen Leveling-Routen (Nutzer 20.11.2026: "wenn ich schon in der Naehe eines Lehrers bin,
-- warum nicht gleich neue Skills lernen?"; RestedXP-Vergleich – nur die Idee, eigene Logik):
-- Lehrer: neue Zauber lernen, wenn ein Lehrer nahe am Weg liegt (je Stufe Rueckstand dringlicher)
P.TRAIN_MIN = 1.5
P.TRAIN_NEAR = 3         -- Umweg zum Lehrer in einer Schleife (Minuten), je 2 Stufen Rueckstand das Doppelte
P.TRAIN_FAR = 10         -- weiter weg (Minuten, Flug mitgerechnet) nur bei grossem Rueckstand
P.TRAIN_BEHIND = 4       -- so viele Stufen Rueckstand: dann auch weit
-- Flugpunkt abholen, wenn man (fast) vorbeikommt
P.FP_MIN = .5
P.FP_NEAR = 1.5          -- nur zu Fuss so nah, ca. 500 yd (nicht ins hoehere Nachbargebiet, kein Flug/Ruhestein dorthin)
-- Ruhestein benutzen (25 s), wenn es mindestens so viel spart; danach 60 min Abklingzeit
P.HS_MIN = .5
P.HS_SAVE = 3
P.HS_CD = 60
-- Ruhestein setzen beim Gastwirt am Weg, wenn die naechsten Halte viel naeher liegen als der Heimatort
P.BIND_PASS = 250
P.BIND_AHEAD = 8
P.BIND_BETTER = 600
P.BIND_MAX_AREA = 1200
P.BIND_NEAR = 5          -- so viele der naechsten Halte muessen nahe am Gastwirt liegen
P.BIND_LONG = 20         -- und von so vielen Halten danach mindestens 2/3 naeher am neuen als am alten Ort
P.BIND_MIN = .5
-- Nichts mehr annehmbar (Stufe fehlt): "bis Stufe X Monster hauen" – hoechstens so viele Minuten
P.GRIND_MAX = 90
-- Fortschritt im Questlog (Nutzer 20.11.2026): nur der Rest zaehlt als Aufwand; ab so viel erledigt nie
-- "Abbrechen lohnt" – ausser die Quest bringt kaum noch EP (grau)
P.ABANDON_KEEP = .7
P.IMPROVE_PASSES = 3
-- Questsorten (zoneOrSort < 0) der Klassen
P.CLASS_SORT = {[-61] = 256, [-81] = 1, [-82] = 64, [-141] = 2, [-161] = 128, [-162] = 8, [-261] = 4, [-262] = 16, [-263] = 1024}
P.FACTION_MASK = {Alliance = 77, Horde = 178}
-- Feste Gebietsfolge je Volk (Neubau 21.11.2026, wie ein geschriebener Leitfaden: "bau es wie bei RestedXP"):
-- {Gebiet, ab Stufe, bis Stufe}. Startstrecke je Volk, ab P.FLOW.common[Volk] die gemeinsame Folge der Fraktion.
-- Stufen aus den Forever-Gebietsdaten (SPF Data/Zones.lua low/high), Riverglades = Forever-Gebiet.
P.FLOW = {
    start = {
        [16] = {{1420, 1, 11}, {1421, 10, 16}},               -- Untote: Tirisfal, Silberwald
        [2] = {{1411, 1, 11}}, [128] = {{1411, 1, 11}},       -- Orcs/Trolle: Durotar
        [32] = {{1412, 1, 11}},                               -- Tauren: Mulgore
        [1] = {{1429, 1, 11}, {1436, 10, 17}},                -- Menschen: Elwynn, Westfall
        [4] = {{1426, 1, 11}, {1432, 10, 17}}, [64] = {{1426, 1, 11}, {1432, 10, 17}},  -- Zwerge/Gnome: Dun Morogh, Loch Modan
        [8] = {{1438, 1, 11}, {1439, 10, 20}},                -- Nachtelfen: Teldrassil, Dunkelkueste
    },
    common = {[16] = 16, [2] = 10, [128] = 10, [32] = 10, [1] = 16, [4] = 16, [64] = 16, [8] = 19},
    tail = {{1440, 21, 28}, {1424, 24, 31}, {1441, 26, 33}, {1443, 30, 37}, {1417, 30, 38}, {1434, 33, 43},
        {1445, 36, 43}, {2548, 36, 44}, {1418, 38, 45}, {1435, 37, 44}, {1446, 42, 49}, {1444, 42, 49}, {1425, 44, 51},
        {1427, 45, 50}, {1447, 47, 54}, {1448, 48, 55}, {1449, 49, 55}, {1419, 49, 55}, {1428, 51, 58}, {1422, 52, 59},
        {1452, 54, 61}, {1423, 55, 61}, {1451, 56, 61}},
    -- zweite Gebiete fuer alle Voelker der Fraktion (Nachstellung 21.11.2026: Zwerg mit 17 hatte nur Rotkamm)
    Horde = {{1413, 10, 23}, {1421, 10, 20}, {1442, 19, 25}},
    Alliance = {{1436, 10, 17}, {1432, 10, 17}, {1439, 10, 20}, {1433, 15, 21}, {1437, 20, 26}, {1431, 21, 29}, {1442, 21, 26}},
}
-- Hauptstadt gehoert zu diesen Gebieten (neue Quests dort nur, wenn eines davon dran ist)
P.CITY_NEAR = {[1454] = {1411, 1413}, [1456] = {1412, 1413}, [1458] = {1420, 1421}, [1453] = {1429, 1436, 1433, 1431},
    [1455] = {1426, 1432, 1437}, [1457] = {1438, 1439}}
-- Gastwirte in Hauptstaedten: dort nie "Ruhestein setzen" (Spieltest 21.11.2026: Unterstadt fuer einen Abstecher)
P.CITY_INNS = {[6929] = true, [6741] = true, [6746] = true, [6740] = true, [5111] = true, [6735] = true}
-- Stufenfenster je Gebiet aus den echten Quests (Nutzer 21.11.2026: "da gibt es Quests, die nicht fuer meine Stufe
-- geeignet sind … dann woanders leveln und spaeter dort weitermachen"): Queststufen der passenden Quests (Geber im
-- Gebiet) nach Luecken > P.REVISIT_GAP in Abschnitte teilen; Abschnitt mit >= P.REVISIT_MIN Quests = eigener
-- Besuch, kleinere Reste haengen am naechsten Abschnitt (oder fallen weg, wenn zu weit). Ab = erste Stufe - 1
-- (nicht vor der Startstufe aus P.FLOW), bis = letzte Stufe + 2.
P.REVISIT_GAP = 3
P.REVISIT_MIN = 6
P.REVISIT_DENSE = 2
local flowCache = {}
function P.FlowWindows(race, faction)
    local key = (race or 0) .. ":" .. (faction or "")
    if flowCache[key] then return flowCache[key] end
    local st = P.FLOW.start[race or 0]
    if not st then return nil end
    local list = {}
    for _, f in ipairs(st) do list[#list + 1] = {f[1], f[2], f[3], start = true} end
    local common = P.FLOW.common[race] or 99
    for _, f in ipairs(P.FLOW[faction] or {}) do list[#list + 1] = {f[1], math.max(f[2], common), f[3]} end
    for _, f in ipairs(P.FLOW.tail) do list[#list + 1] = {f[1], math.max(f[2], common), f[3]} end
    local Q = P.Data()
    local out = {}
    for _, f in ipairs(list) do
        local z, lvls = f[1], {}
        if Q then
            local me = {level = 60, race = race, faction = faction}
            local no = function() return false end
            for id, e in pairs(Q.q) do
                local g = Q.n[(type(e[6]) == "table" and e[6][1]) or 0]
                local ql = e[1] or 0
                if g and g[2] == z and ql > 0 and (e[4] or 0) == 0 and P.Fits(id, e, me, no, no) then lvls[#lvls + 1] = ql end
            end
        end
        -- nach Dichte teilen: Stufen mit < P.REVISIT_DENSE Quests sind "duenn"; P.REVISIT_GAP duenne Stufen am Stueck
        -- trennen zwei Abschnitte (einzelne Ausreisser verbinden sonst alles zu einem Block)
        local per, maxL = {}, 0
        for _, l in ipairs(lvls) do per[l] = (per[l] or 0) + 1 if l > maxL then maxL = l end end
        local parts, cur, thin = {}, nil, 0
        for l = 1, maxL do
            local n = per[l] or 0
            if n >= P.REVISIT_DENSE then
                if cur and thin < P.REVISIT_GAP then cur.hi = l cur.n = cur.n + n
                else cur = {lo = l, hi = l, n = n} parts[#parts + 1] = cur end
                thin = 0
            else
                thin = thin + 1
                if cur and thin < P.REVISIT_GAP then cur.n = cur.n + n end
            end
        end
        -- kleine Abschnitte an den Nachbarn haengen, wenn nah genug; sonst weglassen
        local keep = {}
        for i, p in ipairs(parts) do
            if p.n >= P.REVISIT_MIN or #parts == 1 then keep[#keep + 1] = p
            elseif keep[#keep] and p.lo - keep[#keep].hi <= P.REVISIT_GAP * 2 then keep[#keep].hi, keep[#keep].n = p.hi, keep[#keep].n + p.n
            elseif parts[i + 1] and parts[i + 1].lo - p.hi <= P.REVISIT_GAP * 2 then parts[i + 1].lo, parts[i + 1].n = p.lo, parts[i + 1].n + p.n end
        end
        if #keep == 0 then keep = {{lo = f[2], hi = f[3] - 2, n = 0}} end
        for _, p in ipairs(keep) do
            -- ab: aus den Daten (2 Stufen vor der ersten Quest); nur das Startgebiet beginnt bei seiner Startstufe
            local from = math.max(f.start and f[2] or common, p.lo - 2)
            if f.start and p == keep[1] then from = f[2] end
            if p.hi + 2 > from then out[#out + 1] = {z, from, p.hi + 2, n = p.n} end
        end
    end
    flowCache[key] = out
    return out
end
-- darf man mit Stufe lvl in Gebiet z questen? (nil = keine Folge bekannt -> alles erlaubt)
function P.FlowAllowed(race, faction, z, lvl)
    local win = P.FlowWindows(race, faction)
    if not win or not z then return nil end
    if P.CITY_NEAR[z] then
        for _, nz in ipairs(P.CITY_NEAR[z]) do if P.FlowAllowed(race, faction, nz, lvl) then return true end end
        return false
    end
    for _, f in ipairs(win) do if f[1] == z and lvl >= f[2] and lvl < f[3] then return true end end
    return false
end

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
-- Quest beginnt mit einem Gegenstand von Gegnern (Feld 16 = Gegenstand, keine Fundstelle als Geber): nicht planbar
function P.IsDrop(e) return e and e[16] and not (type(e[6]) == "table" and #e[6] > 0) or false end

-- Dungeonquest oder Teil einer Reihe, die in einen Dungeon fuehrt (Vorquest unterwegs, z. B. "Hamuul Runetotem"
-- -> Hoehle des Wehklagens). Nutzer 22.11.2026: so eine Quest nie als "Nicht im Plan" zum Abbrechen anbieten –
-- man sammelt sie fuer den Dungeon, und Dungeons stehen absichtlich nicht im Guide.
local dungeonNext -- Quest -> Quests, die sie als Vorquest brauchen (einmal gebaut)
function P.IsDungeonChain(id)
    local Q, R = P.Data()
    if not (Q and id) then return false end
    local dz = R.dz or {}
    if not dungeonNext then
        dungeonNext = {}
        for qid, e in pairs(Q.q) do
            for _, list in ipairs({type(e[9]) == "table" and e[9] or {}, type(e[5]) == "table" and e[5] or {}}) do
                for _, p in ipairs(list) do
                    dungeonNext[p] = dungeonNext[p] or {}
                    table.insert(dungeonNext[p], qid)
                end
            end
        end
    end
    -- nur die Quest selbst und ihr direkter Nachfolger: lange Weltreihen, die irgendwann in einem Dungeon enden
    -- (z. B. "Patrouille zur Rueckendeckung" in Tirisfal), bleiben normale Quests
    local e = Q.q[id]
    if not e then return false end
    if dz[e[14] or 0] then return dz[e[14]] end
    local nexts = {}
    if (e[12] or 0) > 0 then nexts[1] = e[12] end
    for _, nx in ipairs(dungeonNext[id] or {}) do nexts[#nexts + 1] = nx end
    for _, nx in ipairs(nexts) do
        local ne = Q.q[nx]
        if ne and dz[ne[14] or 0] then return dz[ne[14]] end
    end
    return false
end
-- Geber von Dungeon-Quests und Vorquests dorthin je Karte: {{id, nr}} (einmal gebaut; Hinweis "am Weg")
local dungeonGivers
function P.DungeonGivers(mapID)
    local Q = P.Data()
    if not (Q and mapID) then return {} end
    if not dungeonGivers then
        dungeonGivers = {}
        for id, e in pairs(Q.q) do
            if type(e[6]) == "table" and #e[6] > 0 and P.IsDungeonChain(id) then
                for _, nr in ipairs(e[6]) do
                    local n = Q.n and Q.n[nr]
                    for i = 2, n and #n or 0, 3 do
                        local m = n[i]
                        dungeonGivers[m] = dungeonGivers[m] or {}
                        table.insert(dungeonGivers[m], {id, nr})
                    end
                end
            end
        end
    end
    return dungeonGivers[mapID] or {}
end

function P.Data()
    local q, r = rawget(_G, "GuildTripQuestDB"), rawget(_G, "GuildTripLeveling")
    if type(q) ~= "table" or type(q.q) ~= "table" then return nil end
    return q, type(r) == "table" and r or {r = {}, i = {}, dz = {}}
end

-- ===== Belohnungsdaten (kompakt als Text, Rewards.lua) =====
local function Nums(text)
    local out = {}
    for v in (text or ""):gmatch("[^,]+") do out[#out + 1] = tonumber(v) end
    return #out > 0 and out or false
end
-- Quest: {kupfer, aufwand, art, {feste}|false, {auswahl}|false} oder nil
function P.Rew(R, id)
    local s = R and R.r and R.r[id]
    if type(s) ~= "string" then return s end
    local m, w, k, f, c = s:match("^(%d+)|(%d+)|(%d+)|([^|]*)|([^|]*)$")
    if not m then return nil end
    return {tonumber(m), tonumber(w), tonumber(k), Nums(f), Nums(c)}
end
-- Gegenstand: {platz, qualitaet, stufe, mindeststufe, klasse, unterklasse, taschenplaetze, verkauf, klassenmaske, {werte}|false}
function P.Item(R, id)
    local s = R and R.i and R.i[id]
    if type(s) ~= "string" then return s end
    local out, k = {}, 0
    for part in (s .. "|"):gmatch("([^|]*)|") do
        k = k + 1
        out[k] = k < 10 and (tonumber(part) or 0) or Nums(part)
    end
    return out
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

-- EP bis zur naechsten Stufe (Classic-Tabelle; aktuelle Stufe liest der Kasten aus dem Spiel)
P.XP_NEED = {400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400, 16000,
    17700, 19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400, 50800, 54500,
    58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, 95800, 101000, 106300, 111800, 117500, 123200, 129100,
    135100, 141200, 147500, 153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800}

-- EP bis zur Stufe target (nach gain schon gesammelten EP); 0 = schon erreicht
function P.XPTo(level, xp, max, gain, target)
    local need = (max - xp) - gain
    local lvl = level
    while lvl + 1 < target do
        lvl = lvl + 1
        need = need + (P.XP_NEED[lvl] or 0)
    end
    if target <= level then return 0 end
    return math.max(0, need)
end

-- Stufe nach gain EP: level, xp (bisher in dieser Stufe), max (noetig fuer diese Stufe)
function P.LevelAfter(level, xp, max, gain)
    while level < 60 and xp + gain >= max do
        gain = gain - (max - xp)
        level, xp = level + 1, 0
        max = P.XP_NEED[level] or max
    end
    return level
end

-- ===== Reisezeit: zu Fuss, mit Flug oder mit Schiff/Zeppelin =====
-- a, b = {kontinent, x, y} (Welt-Yards); net = {speed, flights = {{c, x, y, name}}, departures = {{from, to, c, x, y, name}}}
-- Ergebnis: Minuten, Weg (nil = zu Fuss; {kind = "flight", from = Knoten, to = Knoten} | {kind = "boat", dep = Abfahrt, rest = Weg})
local function Dist(a, b) return math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end
local function NearestOn(list, c, p)
    local best, bd
    for _, n in ipairs(list or {}) do
        if n[1] == c then
            local d = Dist(n, p)
            if not bd or d < bd then best, bd = n, d end
        end
    end
    return best, bd
end
function P.Travel(a, b, net)
    net = net or {}
    local speed = net.speed or 7
    if not (a and b) then return P.FAR_MIN end
    local function Walk(x, y) return Dist(x, y) * P.DETOUR / speed / 60 end
    if a[1] == b[1] then
        local walk = Walk(a, b)
        local fa, da = NearestOn(net.flights, a[1], a)
        local fb, db = NearestOn(net.flights, b[1], b)
        if fa and fb and fa ~= fb then
            local fly = da * P.DETOUR / speed / 60 + Dist(fa, fb) * P.FLY_DETOUR / P.FLY_SPEED / 60 + P.FLY_EXTRA + db * P.DETOUR / speed / 60
            if fly < walk * .8 then return fly, {kind = "flight", from = fa, to = fb} end
        end
        return walk
    end
    -- anderer Kontinent: zur naechsten Abfahrt, drueben vom Ankunftsort (naechste Abfahrt zurueck) weiter
    -- Abfahrt nach Gesamtweg: hin + drueben vom Ankunftsort weiter (22.11.2026: nicht einfach die naechste –
    -- Brachland -> Unterstadt ging sonst per Schiff nach Beutebucht und 18 km zu Fuss)
    local best, bm, bestScore
    for _, d in ipairs(net.departures or {}) do
        if d.from == a[1] and d.to == b[1] and d[1] == a[1] then
            local m = Walk(a, d)
            local score = m
            if d.arrive and d.arrive[1] == b[1] then score = m + P.Travel(d.arrive, b, net) end
            if not bestScore or score < bestScore then best, bm, bestScore = d, m, score end
        end
    end
    if not best then return P.UNKNOWN_TRIP end
    if best.arrive and best.arrive[1] == b[1] then
        local rest, via = P.Travel(best.arrive, b, net)
        return bm + P.BOAT_MIN + rest, {kind = "boat", dep = best, rest = via}
    end
    local back = {}
    for _, d in ipairs(net.departures) do if d.from == b[1] and d.to == a[1] then back[#back + 1] = d end end
    local arrive = NearestOn(back, b[1], b)
    if not arrive then return bm + P.BOAT_MIN + P.FAR_MIN / 2, {kind = "boat", dep = best} end
    local rest, via = P.Travel(arrive, b, net)
    return bm + P.BOAT_MIN + rest, {kind = "boat", dep = best, rest = via}
end

-- ===== Hilfen =====
-- Volk passt? Neue Forever-Voelker (Himmelsgeborene, me.sky) stehen in keiner alten Volks-Maske: fuer sie gelten nur
-- Quests der ganzen Fraktion, Quests nur fuer einzelne Voelker (z. B. nur Tauren) nicht.
function P.RaceOK(race, me)
    if not race or race <= 0 or race >= 255 then return true end
    if me.race then return Band(race, me.race) ~= 0 end
    local fm = P.FACTION_MASK[me.faction]
    if not fm then return true end
    if me.sky then return Band(race, fm) == fm end
    return Band(race, fm) ~= 0
end
local function Fits(id, e, me, done, inLog)
    if done(id) then return false end
    local race, class = e[3], e[4]
    if not P.RaceOK(race, me) then return false end
    if class > 0 and me.class and Band(class, me.class) == 0 then return false end
    local sortClass = P.CLASS_SORT[e[14] or 0]
    if sortClass and me.class and sortClass ~= me.class then return false end
    if type(e[10]) == "table" then
        for _, p in ipairs(e[10]) do if done(p) or (inLog(p) and p ~= id) then return false end end
    end
    if (e[13] or 0) > 0 and me.level > e[13] then return false end
    -- Beruf noetig (Spieltest 21.11.2026: Kamari "Bestien des Donnergrats" nur fuer Lederverarbeiter): nur, wenn man
    -- den Beruf mit dem Mindestwert hat; Berufe unbekannt -> nicht
    local sk = e[15]
    if type(sk) == "table" and sk[1] and not ((me.skills or {})[sk[1]] and me.skills[sk[1]] >= (sk[2] or 1)) then return false end
    return true
end
P.Fits = Fits

-- Sehr empfohlene Questreihen: kein Muss, aber wegen der Belohnung vorgeschlagen, sobald die Startstufe
-- erreicht ist – auch wenn EP/Weg sonst nicht lohnen (Nutzer 19.11.2026: "nicht Pflicht, eher sehr empfohlen weil …").
-- hints: Hinweis je Quest (Gefahr auf dem Weg), faction = nur fuer diese Fraktion.
P.RECOMMENDED = {
    {key = "sleepingbag", min = 14, reason = "Schlafsack – dauerhaft mehr EP beim Rasten",
        quests = {79007, 79008, 79192, 79980, 79974, 79975, 79976},
        hints = {
            [79192] = {"Steinkrallengebirge: umkämpftes Gebiet"},
            [79980] = {"Steinkrallengebirge: umkämpftes Gebiet"},
            [79974] = {"Loch Modan: Allianz-Gebiet – Wachen und Allianz-Spieler", faction = "Horde"},
            [79975] = {"Arathihochland: umkämpftes Gebiet, Gegner um Stufe 30 auf dem Weg"},
            [79976] = {"Arathihochland: umkämpftes Gebiet, Gegner um Stufe 30 auf dem Weg"},
        }},
}
function P.RecOf(id)
    if not P.recIndex then
        P.recIndex = {}
        for _, c in ipairs(P.RECOMMENDED) do for _, q in ipairs(c.quests) do P.recIndex[q] = c end end
    end
    return P.recIndex[id]
end
-- Hinweis zur Gefahr fuer eine Quest (faction: "Horde"/"Alliance" des Spielers)
function P.RecHint(id, faction)
    local c = P.RecOf(id)
    local h = c and c.hints and c.hints[id]
    if not h or (h.faction and h.faction ~= faction) then return nil end
    return h[1]
end

-- Klassenquest: fuer eine oder wenige Klassen. "Alle ausser Hexenmeister" (z. B. 792, Stufe 4) ist keine
-- (Spieltest 20.11.2026: Stufe-4-Quest in Durotar als KLASSE nie grau, Umweg mit Stufe 15)
P.CLASS_MAX = 4
function P.IsClassQuest(e)
    local mask, bits = e[4] or 0, 0
    while mask > 0 do bits = bits + mask % 2 mask = math.floor(mask / 2) end
    return (bits > 0 and bits <= P.CLASS_MAX) or P.CLASS_SORT[e[14] or 0] ~= nil
end

-- Belohnung bewerten: Liste {kind = "upgrade"|"bag"|"gold", text, pct, item}
function P.Value(qid, rew, R, ctx, plvl)
    local out = {}
    if not rew then return out end
    local money = rew[1] or 0
    if money >= plvl * 1000 then out[#out + 1] = {kind = "gold", money = money} end
    local best
    for _, list in ipairs({rew[4] or {}, rew[5] or {}}) do
        for _, item in ipairs(list) do
            local it = P.Item(R, item)
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
    -- Vergleichswert "nur Monster hauen" so, wie es im Spiel wirklich laeuft (Laufen zwischen Gegnern, Pausen,
    -- besetzte Gegner) – P.GrindEPM allein waere zu guenstig: bei Stufe 12 lohnte fast keine Quest (Nachstellung 21.11.)
    local grind = P.GrindEPM(L) * P.GRIND_REAL
    local function GrindRate(lvl) return math.max(1, P.GrindEPM(lvl) * P.GRIND_REAL) end
    local dz = R.dz or {}

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
    local function CityIn(a, b)
        if a[4] == b[4] then return 0 end
        return (P.CITY_IN[a[4]] or 0) + (P.CITY_IN[b[4]] or 0)
    end
    local function Minutes(a, b)
        if not (a and b) or a[1] ~= b[1] then return P.FAR_MIN end
        local d = math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
        return d * P.DETOUR / (ctx.speed or 7) / 60 + CityIn(a, b), d
    end
    -- Reisezeit mit Flug/Schiff (gemerkt je Punktepaar)
    local net = {speed = ctx.speed or 7, flights = ctx.flights, departures = ctx.departures}
    local tcache = setmetatable({}, {__mode = "k"})
    local function Trip(a, b)
        if not (a and b) then return P.FAR_MIN end
        local row = tcache[a]
        if not row then row = setmetatable({}, {__mode = "k"}) tcache[a] = row end
        local r = row[b]
        if not r then
            local m, via = P.Travel(a, b, net)
            -- zu Fuss in/aus der Stadt (Flug/Ruhestein/Schiff: Ankunft ist meist am Rand, gilt fuer das Ziel genauso)
            r = {m + CityIn(a, b), via}
            row[b] = r
        end
        return r[1], r[2]
    end
    local here = pc and {pc, px, py, me.mapID} or nil
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
    -- Ziel-Knoten einer Quest: im Log nur die der noch offenen Ziele (ctx.targets, Spieltest 22.11.2026: "Chens leeres
    -- Faesschen" – Loewen und Nieren fertig, die Donnerechsen leben weiter noerdlich; der Guide schickte ins alte
    -- Gebiet). Ohne Zuordnung oder nicht im Log: alle Ziele der Quest (e[8]).
    -- Feste Route mit Ziel-Teilen (ctx.objNodes, Guide.RouteFollow): nur die Ziele des geltenden Teils
    local openCache = {}
    local function Targets(id)
        local t = openCache[id]
        if t == nil then
            t = false
            if ctx.targets and inLog(id) then
                local ok, r = pcall(ctx.targets, id)
                if ok and type(r) == "table" and #r > 0 then t = r end
            end
            local part = ctx.objNodes and ctx.objNodes[id]
            if type(part) == "table" and #part > 0 then
                local set, cut = {}, {}
                for _, nr in ipairs(part) do set[nr] = true end
                for _, nr in ipairs(t or (Q.q[id] or {})[8] or {}) do if set[nr] then cut[#cut + 1] = nr end end
                if #cut > 0 then t = cut end
            end
            openCache[id] = t
        end
        return t or (Q.q[id] or {})[8] or {}
    end

    -- 1) Kandidaten: passt zu mir, Stufe im Planungsfenster
    local cand = {}
    for id, e in pairs(Q.q) do
        local log = inLog(id)
        -- Dungeon-Quests: Questsufe liegt oft hoeher (Ziel im Dungeon) – die Mindeststufe zaehlt
        local lvlOK = (e[1] or 0) <= L + P.HORIZON + 1 or (dz[e[14] or 0] ~= nil)
        local rec = P.RecOf(id)
        -- Start durch einen Gegenstand von Gegnern (P.IsDrop, Nutzer 22.11.2026): nicht planbar, erst wenn im Log
        if log or (not P.IsDrop(e) and Fits(id, e, me, done, inLog) and ((rec and L >= rec.min) or ((e[2] or 0) <= L + P.HORIZON and lvlOK))) then
            cand[id] = true
        end
    end
    -- 2) bewerten
    local info = {}
    local function Rate(id)
        local e, rew = Q.q[id], P.Rew(R, id)
        local qlvl = e[1] > 0 and e[1] or L
        -- gemessene Grund-EP (XPLog, echte Abgaben) vor der Schaetzung aus der Datenbank
        local base = (ctx.measured and ctx.measured[id]) or e[11] or 0
        local xp, f = P.QuestXP(base, qlvl, L)
        local work = rew and rew[2] or 0
        -- gemessene Sammelzeit (WorkLog, echte Spielzeit inkl. Pech beim Droppen) vor der Schaetzung
        local wm = ctx.workMinutes and ctx.workMinutes[id]
        if wm then work = wm * 60 / P.KILL_SEC end
        -- schon angefangen: nur der Rest kostet Zeit (z. B. 12/15 Armschienen)
        local done01 = 0
        if inLog(id) and ctx.progress then
            local have, need = ctx.progress(id)
            if type(have) == "number" and type(need) == "number" and need > 0 then
                done01 = math.max(0, math.min(1, have / need))
                work = work * (1 - done01)
            end
        end
        local kind = rew and rew[3] or 0
        local dungeon = DungeonOf(e)
        if dungeon then kind = kind - kind % 4 + (kind % 2) + 2 end
        local mobXP = P.MobXP(L, math.min(qlvl, L + 2))
        local giver = Nearest(e[6], here)
        local target = Nearest(Targets(id), giver and giver.w or here)
        local ender = Nearest(e[7], target and target.w or giver and giver.w)
        local travel = 0
        if giver and target then travel = travel + Trip(giver.w, target.w) end
        if target and ender then travel = travel + Trip(target.w, ender.w)
        elseif giver and ender then travel = travel + Trip(giver.w, ender.w) end
        -- erste Anreise (vom Spieler) zaehlt mit: weit weg = teurer, Flug macht es billiger
        if giver and here and not inLog(id) then travel = travel + math.min(P.FAR_MIN, (Trip(here, giver.w))) * .5 end
        if not giver then travel = travel + P.FAR_MIN end
        local minutes = P.TALK_MIN + travel + work * P.KILL_SEC / 60
        local totalXP = xp + (dungeon and 0 or work * mobXP)
        local o = {id = id, e = e, xp = xp, xpFactor = f, work = work, kind = kind, dungeon = dungeon,
            mobXP = mobXP, travel = travel, minutes = minutes, totalXP = totalXP,
            giver = giver, target = target, ender = ender, log = inLog(id), complete = complete(id),
            class = P.IsClassQuest(e), rec = P.RecOf(id), reasons = {}, tags = {}, progress = done01}
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
    local prev = ctx.prevChosen
    local function Choose(o, why)
        if chosen[o.id] then return end
        chosen[o.id] = why
    end
    -- Klassenquests nach dem, was am Ende der Reihe herauskommt (Nutzer 21.11.2026: "wie wichtig ist die
    -- Klassenquest gerade und ist die Belohnung sinnvoll fuers weitere Questen?"): Zauber/Faehigkeit (R.sp aus
    -- cmangos RewSpell) = immer und bevorzugt; Gegenstand, der eine Verbesserung ist = wie Mehrwert; sonst nach EP
    -- wie jede andere Quest (vorher: jede Klassenquest bevorzugt, z. B. "Meldung bei Anastasia" fuer eine Robe).
    for id, o in pairs(info) do
        if o.class then
            local spell, value, cid, n = nil, false, id, 0
            while cid and cid > 0 and n < P.CHAIN_LOOK do
                if R and R.sp and R.sp[cid] then spell = R.sp[cid] break end
                if not value then
                    local rew = P.Rew(R, cid)
                    if ctx.judge then
                        local ok, v = pcall(P.Value, cid, rew, R, ctx, L)
                        for _, x in ipairs(ok and v or {}) do if x.kind == "upgrade" then value = true end end
                    else
                        -- ohne Ausruestungsdaten (Routen vorab rechnen): Klassen-Belohnung ab gruen fuer diese Klasse
                        -- und Stufe zaehlt als Verbesserung (Magier-Robe der Anastasia-Reihe, Nutzer 21.11.2026)
                        for _, list in ipairs({rew and rew[4] or {}, rew and rew[5] or {}}) do
                            for _, item in ipairs(list) do
                                local it = P.Item(R, item)
                                local cls = it and it[9] or 0
                                if it and (it[2] or 0) >= 2 and (it[4] or 0) <= L + 5 and (cls == 0 or not me.class or Band(cls, me.class) > 0) then value = true end
                            end
                        end
                    end
                end
                cid, n = (Q.q[cid] or {})[12], n + 1
            end
            o.spell = spell
            if not spell then o.class, o.classValue = false, value end
        end
    end
    local follow0 = ctx.route and ctx.follow or nil
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
        elseif ctx.route and follow0 and (follow0["accept:" .. id] or follow0["obj:" .. id] or follow0["turnin:" .. id])
            and not raidOrPvp and (e[1] or 0) > 0 and not (not o.log and (e[12] or 0) > 0 and (done(e[12]) or inLog(e[12]))) then
            -- Gebiets-Schleife (Nutzer 24.11.2026): die Route enthaelt alle Quests der Gebiete, auch Elite ("Gruppe",
            -- mit "Spaeter"-Knopf) – im Spiel nicht mehr nach EP oder Aufwand aussortieren
            Choose(o, "route")
        elseif o.rec and L >= o.rec.min then
            Choose(o, "rec")
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
        elseif ctx.flow and not o.log and not o.class and o.giver and o.ender and o.giver.w and o.ender.w and o.giver.w[1] ~= o.ender.w[1] then
            -- feste Gebietsfolge: Quest fuehrt auf einen anderen Kontinent (Forever-Reihe "… and that note you found":
            -- Brachland -> Westfall) – nie fuer eine einzelne Quest so weit (Nutzer 21.11.2026)
            o.skip = "Abgabe auf einem anderen Kontinent."
        elseif not o.log and (e[12] or 0) > 0 and (done(e[12]) or inLog(e[12])) then
            -- Hinweis-Quest einer Reihe, deren naechster Teil schon angenommen oder erledigt ist (Nachstellung
            -- 22.11.2026: "Meldung bei Anastasia", obwohl der Alchimistenladen schon im Log war)
            o.skip = "Folgequest schon angenommen."
        elseif (e[1] or 0) == 0 and not o.log then
            -- ohne Queststufe: Sonder-/Systemquests (z. B. "Your Reward has Arrived!" bei allen Gastwirten, Nachstellung
            -- 21.11.2026: Route schickte durch alle Hauptstaedte)
            o.skip = "Ohne Queststufe (Sonderquest)."
        elseif o.xpFactor <= .2 then
            o.skip = "Grau – kaum noch EP."
        elseif isGroup and not me.inGroup then
            o.skip = "Elite/Gruppe – nur mit Gruppe."
        elseif o.work >= P.BUSY_WORK and #o.value == 0 and not o.classValue then
            o.skip = "Viel Aufwand (seltene Drops oder viele Gegner)."
        elseif not o.giver and not o.log then
            o.skip = "Ort unbekannt."
        elseif here and o.giver and o.giver.w[1] ~= here[1] and not o.log and (function()
                -- nur wirklich ohne Verbindung (oder ueber eine Stunde) – lange Reisen sperren keine ganzen Gebiete
                -- (Nachstellung 22.11.2026: aus Riverglades waren Tanaris/Feralas "unerreichbar" -> Stunden Leerlauf)
                local m, via = Trip(here, o.giver.w)
                return (m >= P.UNKNOWN_TRIP and not via) or m >= P.UNKNOWN_TRIP * 2
            end)() then
            -- anderer Kontinent ohne bekannte Verbindung; mit Schiff/Zeppelin zaehlt die Route (Nachstellung 21.11.2026:
            -- in Tirisfal war das Brachland unsichtbar -> Westfall und Monster hauen)
            o.skip = "Anderer Kontinent."
        elseif o.log then
            Choose(o, "log")
        else
            -- lohnt sie sich? Entscheidet die Route: nur in einer guten Schleife (5)
            o.pool = true
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
        if not (e and Fits(id, e, me, done, inLog)) or override[id] == "no" or P.IsDrop(e) then return false end
        if (e[2] or 0) > L + P.HORIZON then return false end
        -- Vorquest draussen in der Welt mit zu hoher Queststufe: Kette wartet (kommt mit hoeherer Stufe von selbst)
        -- (sehr empfohlene Reihen ausgenommen: Sucharbeit ohne Kaempfe, z. B. Schlafsack)
        if (e[1] or 0) > L + P.HORIZON + 1 and not dz[e[14] or 0] and not P.RecOf(id) then return false end
        for _, group in ipairs(Pre(e)) do
            local ok = false
            for _, p in ipairs(group) do
                -- Vorquest ohne Daten (meist Start durch ein gefundenes Gegenstueck, z. B. "Chens leeres Faesschen"
                -- 819): nicht planbar – die Folgequest gibt es erst, wenn sie wirklich erledigt ist (Spieltest
                -- 22.11.2026: Braumeister Drohn bot 821 nicht an, der Guide schickte trotzdem hin)
                if done(p) then ok = true break end
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
    -- 5) Route: Schleifen um Stuetzpunkte (Nutzer 21.11.2026 "bau das", nach dem Spieltest-Abend 20.11.: der gierige
    -- "naechste lohnende Punkt" schickte kreuz und quer). Wie gute Leveling-Routen: am Stuetzpunkt annehmen, die
    -- Ziele einer Gegend am Stueck, abgeben, wo die Abgaben sind (meist wieder am Stuetzpunkt, sonst am naechsten
    -- auf dem Weg). Jede moegliche naechste Schleife wird mit EP pro Minute inkl. Anreise bewertet, die beste kommt
    -- dran. Eine Quest kommt in die Schleife, wenn sie dort mehr bringt als Monster hauen (Tempo-Faktor) – einzelne
    -- weit weg nicht. Bringt ein anderes Gebiet mehr, zieht man weiter; Reste nur, wenn man ohnehin zurueckkommt.
    -- Dungeonquest oder Vorquest-Kette einer Dungeonquest: nur am Weg
    local function ForDungeon(id)
        local seen = {}
        while id and not seen[id] do
            seen[id] = true
            local o = info[id]
            if not o then return nil end
            if o.dungeon then return o.dungeon end
            if chosen[id] ~= "pre" then return nil end
            id = o.preFor
        end
    end
    -- Sehr empfohlene Reihe mit Vorrang? Nur wenn der Spieler "jetzt machen" gewaehlt hat
    -- (Nutzer 19.11.2026: "einfach fragen, ob er weiter speed-leveln oder die Reihe jetzt erledigen mag")
    local function Prio(id)
        local o = id and info[id]
        return o and o.rec and ctx.recFirst and ctx.recFirst(o.rec.key) and true or false
    end
    -- Folgequest zaehlt mit: ein Teil ihrer EP gehoert zur Vorquest (sonst bliebe eine gute Reihe am Anfang liegen)
    for _, o in pairs(info) do
        local nx = o.e[12]
        local n = nx and nx > 0 and info[nx]
        if n and not done(nx) then o.chainXP = P.CHAIN_SHARE * n.xp end
    end
    local stops, jobs = {}, {}
    local function AddJob(id)
        local o = info[id]
        local dkey = chosen[id] and ForDungeon(id) or nil
        o.forDungeon = dkey
        -- Dungeonquests und sehr empfohlene Reihen (ohne "jetzt machen"): nur am Weg
        -- (vom Route-Bau ausgewaehlte Dungeon-Quests, override "yes": gezielt abholen, nicht nur am Weg)
        local byway = (dkey ~= nil and override[id] ~= "yes") or (o.rec ~= nil and not Prio(id) and override[id] ~= "yes")
        -- fertig im Log (Dungeon gelaufen): Abgabe ganz normal, auch mit Weg
        local j = {id = id, o = o, byway = byway and not (o.log and o.complete), pool = not chosen[id],
            force = override[id] == "yes" or Prio(id), class = chosen[id] == "class"}
        o.job = j
        if not o.log and o.giver then
            j.a = {kind = "accept", id = id, w = o.giver.w, nr = o.giver.nr, byway = byway}
            stops[#stops + 1] = j.a
        end
        if not (o.log and o.complete) and not o.dungeon and o.target and #(o.e[8] or {}) > 0 then
            j.t = {kind = "obj", id = id, w = o.target.w, nr = o.target.nr, byway = byway}
            stops[#stops + 1] = j.t
        end
        if o.ender and (not o.dungeon or (o.log and o.complete)) then
            j.e = {kind = "turnin", id = id, w = o.ender.w, nr = o.ender.nr, byway = byway and not (o.log and o.complete)}
            stops[#stops + 1] = j.e
        end
        if j.a or j.t or j.e then jobs[#jobs + 1] = j end
        for _, s in ipairs({j.a or false, j.t or false, j.e or false}) do if s then s.job = j end end
    end
    do
        local ids = {}
        for id, o in pairs(info) do if chosen[id] or o.pool then ids[#ids + 1] = id end end
        table.sort(ids)
        for _, id in ipairs(ids) do AddJob(id) end
    end
    -- feste Route: Dungeon-Laeufe der Route (Nutzer 23.11.2026 "Dungeon-Quests einbauen") – ein Halt am Eingang, solange
    -- Quests dieses Dungeons im Log offen sind; danach (Quests fertig) plant er die Abgaben wie sonst
    if ctx.route and ctx.routeDungeons then
        for _, d in ipairs(ctx.routeDungeons) do
            local open = {}
            for _, id in ipairs(d.ids or {}) do if inLog(id) and not (ctx.complete and ctx.complete(id)) then open[#open + 1] = id end end
            local w = #open > 0 and d.m and d.x and World(nil, d.m, d.x / 1000, d.y / 1000)
            if w then stops[#stops + 1] = {kind = "dungeon", key = d.key, ids = open, w = w} end
        end
    end
    -- Bedingungen: angenommen (im Plan oder im Log) vor Erledigen/Abgeben, Vorquest abgegeben vor Annehmen
    local accepted, finished, turned = {}, {}, {}
    for id, o in pairs(info) do
        if o.log then accepted[id] = true end
        if o.log and o.complete then finished[id] = true end
    end
    -- Stufe im Plan (nach den bis hier gesammelten EP): Quests erst annehmen, wenn die Mindeststufe erreicht ist
    -- (Spieltest 19.11.2026: "annehmen bei Ebru" mit Stufe 13, Quest ab 14 – Ausrufezeichen noch grau)
    local xpSum, xpExtra = 0, 0
    local function PlanLevel()
        if (me.xpMax or 0) <= 0 then return L end
        return P.LevelAfter(L, me.xp or 0, me.xpMax, xpSum + xpExtra)
    end
    local function PreReady(s)
        for _, group in ipairs(Pre(Q.q[s.id])) do
            local ok = false
            for _, p in ipairs(group) do if done(p) or turned[p] then ok = true break end end
            if not ok then return false end
        end
        return true
    end
    local function Ready(s)
        if s.kind == "accept" then
            if ((Q.q[s.id] or {})[2] or 0) > PlanLevel() then return false end
            return PreReady(s)
        elseif s.kind == "obj" then
            if ((Q.q[s.id] or {})[1] or 0) > PlanLevel() + (ctx.route and P.ROUTE_OBJ_AHEAD or P.OBJ_AHEAD) then return false end
            return accepted[s.id]
        elseif s.kind == "train" then
            return PlanLevel() >= s.lvl
        elseif s.kind == "fp" or s.kind == "vendor" or s.kind == "dungeon" then
            return true
        else -- Abgabe
            if not accepted[s.id] then return false end
            if finished[s.id] then return true end
            local j = s.job
            return not (j and j.t and not j.t.used)
        end
    end
    -- Zusatz-Halte (freiwillig, "opt"): Lehrer, Flugpunkte, Haendler – kommen nur dran, wenn sie nahe am Weg liegen
    local function Spots(list)
        local out = {}
        for _, t in ipairs(list or {}) do
            local w = t.w or (t.mapID and World(nil, t.mapID, t.x, t.y))
            if w then out[#out + 1] = {w = w, name = t.name, mapID = t.mapID, x = t.x, y = t.y, id = t.id} end
        end
        return out
    end
    -- Klassenlehrer und (Magier) Portallehrer fuer die Teleports – getrennte Besuche (group)
    for _, tr in ipairs({ctx.train or false, ctx.portal or false}) do
        local spots = tr and Spots(tr.spots) or {}
        if #spots > 0 then
            local g = tr.group
            if (tr.now or 0) > 0 and not ctx.flow then stops[#stops + 1] = {kind = "train", group = g, lvl = L, n = tr.now, spots = spots, opt = true} end
            local lvls = {}
            for lvl in pairs(tr.next or {}) do if lvl > L and lvl <= L + P.HORIZON then lvls[#lvls + 1] = lvl end end
            table.sort(lvls)
            for _, lvl in ipairs(ctx.flow and {} or lvls) do stops[#stops + 1] = {kind = "train", group = g, lvl = lvl, n = tr.next[lvl], spots = spots, opt = true} end
        end
    end
    for _, f in ipairs(ctx.fpSpots or {}) do
        if here and f[1] == here[1] then
            stops[#stops + 1] = {kind = "fp", id = f.id, w = {f[1], f[2], f[3]}, name = f.name, opt = true}
        end
    end
    -- Haendler (Nutzer 21.11.2026: "planst du einen haendler zum reparieren und verkaufen mit ein, falls das
    -- inventar zu voll ist?"): nur am Stuetzpunkt, nie als eigener Weg; nur ein Hinweis, nichts automatisch
    -- (nur Taschen; Reparieren merkt sich der Spieler selbst – Nutzer 21.11.2026)
    local vendorNeed = ctx.vendors and ctx.bags and ctx.bags <= P.BAG_LOW
    local vendorStop
    if ctx.vendors and (vendorNeed or ctx.bags) then
        local spots = Spots(ctx.vendors)
        if #spots > 0 then
            vendorStop = {kind = "vendor", id = 0, spots = spots, opt = true}
            stops[#stops + 1] = vendorStop
        end
    end
    -- Ruhestein und Klassen-Reisezauber (Astraler Ruf, Teleports): Ziel und ab wann (Planminuten) bereit.
    -- Alle als Reiseweg via.kind = "hearth"; via.port sagt welcher (Nutzer 20.11.2026: alles Klassenspezifische)
    local function NewPorts()
        local list = {}
        local home = ctx.home
        if home then
            list[#list + 1] = {port = "hearth", w = home, place = home.place, at = ctx.hearthIn and ctx.hearthIn / 60 or nil, cd = P.HS_CD, bind = true}
        end
        for _, p in ipairs(ctx.ports or {}) do
            local w = p.bind and home or p.w
            if w then
                list[#list + 1] = {port = p.kind, w = w, place = p.bind and home.place or p.place, name = p.name, spell = p.spell,
                    at = (p.inSec or 0) / 60, cd = p.cd or 0, bind = p.bind, uses = p.uses}
            end
        end
        for i, p in ipairs(list) do p.i = i end
        return list
    end
    local hs = NewPorts()
    local function Reach(from, w, now, ports)
        if not w then return P.FAR_MIN end
        if not from then return 0 end
        local walk, via = Trip(from, w)
        local best = walk
        for _, p in ipairs(ports) do
            if p.at and now >= p.at and p.w[1] == w[1] then
                local m = P.HS_MIN + Minutes(p.w, w)
                if m <= walk - P.HS_SAVE and m < best then
                    best, via = m, {kind = "hearth", port = p.port, name = p.name, spell = p.spell, place = p.place,
                        bind = p.bind, save = walk - m, i = p.i}
                end
            end
        end
        return best, via
    end
    local function Used(ports, via, at)
        local p = via and via.kind == "hearth" and ports[via.i]
        if p then
            p.at = at + p.cd
            -- Teleportrunen im Gepaeck: so oft wie Runen da sind
            if p.uses then p.uses = p.uses - 1 if p.uses <= 0 then p.at = nil end end
        end
    end
    local order, pos, minutes = {}, here, 0
    local zone = me.mapID
    local loopNo, loops = 0, {}
    -- Zeit fuer die vorrangige Reihe zaehlt nicht zum Plan-Budget (sonst blieben dahinter keine Quests)
    local recMinutes = 0
    -- Einen Halt ausfuehren (im Plan): Zeit, EP, Zustand
    -- haben zwei Quests ein gemeinsames Ziel (Gegner, Gegenstand, Objekt)?
    local targetSet = {}
    local function SameTargets(a, b)
        local function Set(id)
            if not targetSet[id] then
                local t = {}
                for _, n in ipairs(Targets(id)) do t[n] = true end
                targetSet[id] = t
            end
            return targetSet[id]
        end
        local sa = Set(a)
        for n in pairs(Set(b)) do if sa[n] then return true end end
        return false
    end
    local Commit
    function Commit(s, walk, via, spot)
        if spot then s.w, s.name = spot.w, spot.name end
        s.used, s.walk, s.via = true, walk, via
        s.loop = loopNo
        local before, xpBefore = minutes, xpSum
        minutes = minutes + walk
        if not via and walk > 0 and walk < P.FAR_MIN then xpSum = xpSum + walk * P.WALK_XP * P.GrindEPM(PlanLevel()) end
        order[#order + 1] = s
        if s.w then pos = s.w zone = s.w[4] or zone end
        Used(hs, via, minutes)
        if s.kind == "accept" then accepted[s.id] = true
        elseif s.kind == "train" then
            minutes = minutes + P.TRAIN_MIN
            -- deckt alle Lehrer-Halte bis zur aktuellen Stufe im Plan ab
            for _, t in ipairs(stops) do
                if t.kind == "train" and t.group == s.group and not t.used and t.lvl <= PlanLevel() then t.used, t.covered = true, true end
            end
        elseif s.kind == "fp" then
            minutes = minutes + P.FP_MIN
        elseif s.kind == "vendor" then
            minutes = minutes + P.VENDOR_MIN
        elseif s.kind == "grind" then
            minutes = minutes + s.work
            xpSum = xpSum + s.xp
        elseif s.kind == "dungeon" then
            -- Dungeon-Lauf (feste Route): ~P.DUNGEON_RUN Minuten, Monster-EP wie Hauen; die Quests sind danach fertig
            minutes = minutes + P.DUNGEON_RUN
            xpSum = xpSum + P.DUNGEON_RUN * GrindRate(PlanLevel())
            for _, id in ipairs(s.ids or {}) do finished[id] = true end
        elseif s.kind == "obj" then
            finished[s.id] = true
            local o = info[s.id]
            minutes = minutes + o.work * P.KILL_SEC / 60
            xpSum = xpSum + o.work * o.mobXP
        else
            turned[s.id] = true
            finished[s.id] = true
            xpSum = xpSum + info[s.id].xp
            minutes = minutes + P.TALK_MIN
        end
        -- echte Zeit dieses Halts
        s.cost = minutes - before
        if Prio(s.id) then recMinutes = recMinutes + s.cost end
        s.gain = xpSum - xpBefore
        -- Ziele mit denselben Gegnern/Gegenstaenden gleich mit (Spieltest 21.11.2026 Tirisfal: "Remnants of War" und
        -- "The Cult of the Damned" brauchen dieselben Gegner – geplant war Ziel A, abgeben, wieder raus fuer B)
        if s.kind == "obj" then
            for _, t in ipairs(stops) do
                if t.kind == "obj" and not t.used and t ~= s and Ready(t) then
                    -- ... oder Ziele ganz dicht daneben (Nutzer: "da liegen 3 Quests ganz dicht nebeneinander und
                    -- trotzdem werden sie nicht zusammen gemacht")
                    local gap = (s.w and t.w and s.w[1] == t.w[1]) and Minutes(s.w, t.w) or nil
                    if SameTargets(s.id, t.id) or (gap and gap <= P.OBJ_TOGETHER) then
                        t.partner = true
                        Commit(t, gap or 0, nil)
                    end
                end
            end
        end
    end

    -- B) Schleifen
    local thr = grind * factor
    local function Leg(a, b)
        if not (a and b) then return 0 end
        return (Trip(a, b))
    end
    -- Weg einer Folge ab Startpunkt (Minuten, nur Wege)
    local function PathCost(origin, seq)
        local c, prev = 0, origin
        for _, nd in ipairs(seq) do c = c + Leg(prev, nd.w) prev = nd.w end
        return c
    end
    -- beste Einfuegestelle fuer einen Punkt ab Index lo (1 .. #seq+1): Mehrweg, Stelle
    local function BestSpot(origin, seq, w, lo)
        local bd, bk
        for k = math.max(1, lo), #seq + 1 do
            local a = k == 1 and origin or seq[k - 1].w
            local b = seq[k] and seq[k].w
            local d = Leg(a, w) + (b and (Leg(w, b) - Leg(a, b)) or 0)
            if not bd or d < bd then bd, bk = d, k end
        end
        return bd or 0, bk or 1
    end
    -- Position eines Halts in der Folge
    local function IndexOf(seq, s)
        for k, nd in ipairs(seq) do if nd.s == s then return k end end
    end
    -- Was eine Quest in dieser Schleife noch braucht (Annehmen, Ziel, Abgabe) und ab welcher Stelle
    local function Needs(j, seq)
        local nodes = {}
        local lo = 1
        local acc = accepted[j.id]
        if j.a and not j.a.used then
            local e = Q.q[j.id] or {}
            if (e[2] or 0) > PlanLevel() then return nil end
            for _, group in ipairs(Pre(e)) do
                local ok, at = false, nil
                for _, p in ipairs(group) do
                    if done(p) or turned[p] then ok = true break end
                end
                if not ok then
                    for _, p in ipairs(group) do
                        local pj = info[p] and info[p].job
                        local k = pj and pj.e and IndexOf(seq, pj.e)
                        if k and (not at or k < at) then at = k end
                    end
                    if not at then return nil end
                    lo = math.max(lo, at + 1)
                end
            end
            nodes[#nodes + 1] = j.a
            acc = true
        end
        if not acc then return nil end
        if j.t and not j.t.used and not finished[j.id] then
            if ((Q.q[j.id] or {})[1] or 0) > PlanLevel() + P.OBJ_AHEAD then return nil end
            nodes[#nodes + 1] = j.t
        end
        if j.e and not j.e.used then nodes[#nodes + 1] = j.e end
        if #nodes == 0 then return nil end
        return nodes, lo
    end
    -- Quest probeweise einfuegen: neue Folge, Mehrzeit, EP
    local function TryJob(j, origin, seq)
        local nodes, lo = Needs(j, seq)
        if not nodes then return nil end
        local s2 = {}
        for k, nd in ipairs(seq) do s2[k] = nd end
        local dt, xp = 0, 0
        for _, s in ipairs(nodes) do
            local d, k = BestSpot(origin, s2, s.w, lo)
            table.insert(s2, k, {s = s, w = s.w})
            dt = dt + d
            lo = k + 1
            if s.kind == "obj" then
                dt = dt + j.o.work * P.KILL_SEC / 60
                xp = xp + j.o.work * j.o.mobXP
            elseif s.kind == "turnin" then
                xp = xp + j.o.xp + (j.o.chainXP or 0)
                dt = dt + P.TALK_MIN / 2
            else dt = dt + P.TALK_MIN / 2 end
        end
        return s2, math.max(.2, dt), xp, nodes
    end
    -- Schwelle je Quest (EP/min): schon gewaehlt bzw. im Log etwas weniger, neu etwas mehr, Mehrwert weniger
    local relaxed = false   -- feste Gebietsfolge, nichts ueber der Schwelle: die beste vorhandene Runde nehmen
    local function Need(j)
        if relaxed then return 0 end
        local need = thr
        if j.o.log or (prev and prev[j.id]) then need = need * P.KEEP_SLACK
        elseif prev and not (j.a and here and j.a.w[1] == here[1] and Minutes(here, j.a.w) <= P.NEW_HERE) then
            need = need * P.NEW_SLACK
        end
        if #j.o.value > 0 or j.o.classValue then need = need * P.VALUE_SLACK end
        -- feste Gebietsfolge: im Gebiet, das dran ist, lohnt Questen mehr als die Rechnung sagt (sonst Leerlauf)
        if ctx.flow then need = need * P.FLOW_SLACK end
        return need
    end
    -- Neue Quest genau hier waehrend man dem Fahrplan folgt: annehmen, wenn sie sich lohnt und ihr Ziel und ihre
    -- Abgabe in der Gegend liegen (sonst kaeme man dafuer extra wieder her)
    local function HereOK(j)
        local a = j.a
        if not a then return false end
        if j.force or j.class then return true end
        if j.t and not (j.t.w[1] == a.w[1] and Minutes(a.w, j.t.w) <= P.CAND_R) then return false end
        if not (j.e and j.e.w[1] == a.w[1] and Minutes(a.w, j.e.w) <= P.CAND_R) then return false end
        local s2, dt, gx = TryJob(j, a.w, {})
        return s2 ~= nil and gx / dt >= thr * P.NEW_SLACK
    end
    -- A) Fester Fahrplan: die alten Halte in alter Reihenfolge (der bereite mit kleinstem Rang); Neues nur direkt
    -- hier (hoechstens P.FOLLOW_HERE Minuten, naeher als der alte Halt, keine neue Annahme). Alles andere Neue
    -- kommt in Schleifen danach.
    local follow = ctx.follow
    -- A0) Neu im Log, ohne dass der Plan es vorsah (selbst angenommen; beim letzten Plan noch nicht im Log,
    -- ctx.prevLog; was der Plan fuer eine spaetere Runde vorab annahm, bleibt dort): Ziel und Abgabe einmal dort in den Fahrplan
    -- einreihen, wo sie am wenigsten Umweg kosten – dann stehen sie fest und kippen den Plan unterwegs nicht um
    -- (Spieltest 21.11.2026: "Verborgene Feinde" angenommen, erst nach Tirisfal geplant, am Zeppelinturm vorgezogen).
    -- Nur einmal: wer schon im Log war und nicht hineinpasste, bleibt fuer die Runden danach (sonst kippt es beim
    -- Vorbeilaufen doch wieder).
    -- feste Route (Nutzer 22.11.2026): Quests im Log, die nicht zur Route gehoeren (gedroppte Quest-Gegenstaende,
    -- selbst angenommene), kommen genauso hinein, wenn sie gut in den Plan passen – sonst "Nicht im Plan"
    local flNew
    -- Rang zwischen den Nachbarn fuer neu eingereihte Halte (mehrere Neue in derselben Luecke gleichmaessig verteilt)
    local function Rank(s2, f2, fl, flNew)
        local i = 1
        while i <= #s2 do
            if s2[i].k then i = i + 1
            else
                local a = i
                while s2[i] and not s2[i].k do i = i + 1 end
                local lo = s2[a - 1] and s2[a - 1].k or (s2[i] and s2[i].k or 1) - 1
                local hi = s2[i] and s2[i].k or lo + 1
                local nb = s2[i] or s2[a - 1]
                for m = a, i - 1 do
                    s2[m].k = lo + (hi - lo) * (m - a + 1) / (i - a + 1)
                    local key = P.StopKey(s2[m].s)
                    f2[key] = s2[m].k
                    flNew[key] = nb and fl[P.StopKey(nb.s)] or nil
                end
            end
        end
    end
    local gearIn = {}
    if follow then
        local seq = {}
        for _, s in ipairs(stops) do
            local k = follow[P.StopKey(s)]
            local w = s.w or (s.spots and s.spots[1] and s.spots[1].w)
            if k and not s.used and w then seq[#seq + 1] = {s = s, w = w, k = k} end
        end
        table.sort(seq, function(a, b) return a.k < b.k end)
        if #seq > 0 then
            local f2 = {}
            for k, v in pairs(follow) do f2[k] = v end
            local fl = ctx.followLoops or {}
            flNew = {}
            for k, v in pairs(fl) do flNew[k] = v end
            for _, j in ipairs(jobs) do
                -- (Route: jedes Mal neu pruefen – die Route selbst kippt nicht, sie steht fest)
                local open = j.e and not j.e.used and j.e.w and inLog(j.id) and not j.byway
                    and (ctx.route or not (ctx.prevLog and ctx.prevLog[j.id])) and not follow["accept:" .. j.id]
                for _, s in ipairs({j.a, j.t, j.e}) do if s and not s.used and f2[P.StopKey(s)] then open = false end end
                if open then
                    local s2, dt, gx = TryJob(j, pos, seq)
                    if s2 and gx / dt >= Need(j) then
                        Rank(s2, f2, fl, flNew)
                        seq = s2
                    end
                end
            end
            -- Ausruestungs-Quests (P.GEAR_EXTRA): ctx.gear = {{Quest-IDs einer Reihe ab dem ersten offenen Teil}, …}
            if ctx.gear and ctx.route then
                local zones = {}
                if pos and pos[4] then zones[pos[4]] = true end
                for _, nd in ipairs(seq) do if nd.w[4] then zones[nd.w[4]] = true end end
                for _, chain in ipairs(ctx.gear) do
                    local try, extra, gain, ok = seq, 0, 0, #chain > 0
                    for _, id in ipairs(chain) do
                        local j = info[id] and info[id].job
                        if not ok or not j or j.byway or inLog(id) then ok = false break end
                        for _, s in ipairs({j.a or false, j.t or false, j.e or false}) do
                            if s and not s.used and (f2[P.StopKey(s)] or not (s.w and zones[s.w[4]])) then ok = false end
                        end
                        if not ok then break end
                        local s2, dt, gx = TryJob(j, pos, try)
                        if not s2 then ok = false break end
                        try, extra, gain = s2, extra + dt, gain + gx
                    end
                    -- jeder neue Halt direkt neben einem Routen-Halt (oder dem Standort) im selben Gebiet
                    if ok then
                        for m, nd in ipairs(try) do
                            if not nd.k then
                                local a, b = m - 1, m + 1
                                while try[a] and not try[a].k do a = a - 1 end
                                while try[b] and not try[b].k do b = b + 1 end
                                local wa = a >= 1 and try[a].w or (a == 0 and pos) or nil
                                local wb = try[b] and try[b].w
                                if not ((wa and wa[4] == nd.w[4]) or (wb and wb[4] == nd.w[4])) then ok = false break end
                            end
                        end
                    end
                    if ok and extra - gain / math.max(1, thr) <= P.GEAR_EXTRA then
                        Rank(try, f2, fl, flNew)
                        seq = try
                        for _, id in ipairs(chain) do gearIn[id] = true end
                    end
                end
            end
            follow = f2
        end
    end
    local routeSkip, routeList, routeAt, missedBack, gatesDone = {}, nil, 1, false, {}
    if follow then
        local fl = flNew or ctx.followLoops or {}
        local base
        while #order < P.MAX_STEPS do
            -- feste Route (ctx.route, Neubau 21.11.2026): fehlt fuer den naechsten Schritt der Route die Stufe, erst
            -- "Monster hauen bis Stufe X" (wie ein geschriebener Leitfaden) – nicht in der Route vorspringen
            -- strikt der Reihe nach (Spieltest-Nachstellung 21.11.2026: sonst sprang er an einen spaeteren, schon
            -- moeglichen Schritt – Westfall, Pestlaender): der naechste Routen-Halt, der noch nicht geht, wird
            -- entweder durch Monster hauen moeglich (fehlende Stufe) oder uebersprungen (Vorquest fehlt, Quest nicht
            -- angenommen – der Spieler ist anders gelaufen)
            -- Spieltest 23.11.2026 ("Bis Stufe 20 Monster hauen – ca. 147 min", Nutzer: "das geht so nicht"): weicht der
            -- Spielstand von der Route ab (weniger EP), wird nicht lange gehauen. Mehr als P.ROUTE_GRIND_MAX Minuten:
            -- 1) verpasste Annahmen (Guide.RouteFollow) in der Naehe (<= P.MISSED_PULL Minuten) zurueck in den Fahrplan,
            -- 2) sonst diesen Schritt vorerst auslassen, wenn ein spaeterer Routen-Schritt schon geht; erst wenn in der
            -- Route nichts mehr geht, hauen.
            if ctx.route then
                if not routeList then
                    routeList = {}
                    for _, s in ipairs(stops) do
                        local k = follow[P.StopKey(s)]
                        if k then routeList[#routeList + 1] = {s = s, k = k} end
                    end
                    table.sort(routeList, function(a, b) return a.k < b.k end)
                    routeAt = 1
                end
                while true do
                    while routeList[routeAt] and (routeList[routeAt].s.used or routeSkip[routeList[routeAt].s]) do routeAt = routeAt + 1 end
                    local lo = routeList[routeAt] and routeList[routeAt].s
                    -- Hauen, das die Route an dieser Stelle vorsieht (ctx.routeGates): wie geplant, damit kein Rueckstand
                    -- entsteht, der spaeter einen langen Block braucht
                    local gate = lo and ctx.routeGates and ctx.routeGates[P.StopKey(lo)]
                    if gate and not gatesDone[gate] and gate > PlanLevel() and (me.xpMax or 0) > 0 then
                        gatesDone[gate] = true
                        local gneed = P.XPTo(L, me.xp or 0, me.xpMax, xpSum, gate)
                        if gneed > 0 then Commit({kind = "grind", lvl = gate, xp = gneed, work = gneed / GrindRate(PlanLevel()), w = pos, opt = true, planned = true}, 0, nil) end
                    end
                    if not lo or Ready(lo) then break end
                    local lv = lo.kind == "accept" and (Q.q[lo.id] or {})[2]
                    local need = lv and lv > PlanLevel() and (me.xpMax or 0) > 0 and P.XPTo(L, me.xp or 0, me.xpMax, xpSum, lv) or 0
                    local long = need > 0 and need / GrindRate(PlanLevel()) > P.ROUTE_GRIND_MAX
                    local later = false
                    if long and not missedBack and ctx.missed and pos then
                        missedBack = true
                        local added = false
                        for _, m in ipairs(ctx.missed) do
                            local w = m.rank and not follow["accept:" .. m.id] and World(m.n)
                            if w and w[1] == pos[1] and Minutes(pos, w) <= P.MISSED_PULL then
                                follow["accept:" .. m.id] = m.rank
                                added = true
                            end
                        end
                        if added then
                            routeList = {}
                            for _, s in ipairs(stops) do
                                local k = follow[P.StopKey(s)]
                                if k then routeList[#routeList + 1] = {s = s, k = k} end
                            end
                            table.sort(routeList, function(a, b) return a.k < b.k end)
                            routeAt = 1
                            later = true
                        end
                    end
                    -- nur Quest-Schritte der naechsten P.ROUTE_SKIP_AHEAD Plaetze in der Naehe (<= P.MISSED_PULL Minuten) –
                    -- nie z. B. ferne Flugpunkte vorziehen (Nachstellung 23.11.2026: Flugpunkt-Rundreise mit Stufe 27)
                    if long and not later then
                        for q = routeAt + 1, #routeList do
                            local s = routeList[q].s
                            if routeList[q].k > routeList[routeAt].k + P.ROUTE_SKIP_AHEAD then break end
                            if s.job and not s.used and not routeSkip[s] and Ready(s) and s.w and pos and s.w[1] == pos[1]
                                and Minutes(pos, s.w) <= P.MISSED_PULL then later = true break end
                        end
                        if later then routeSkip[lo] = true end
                    end
                    if later then
                        -- (verpasste zurueck oder spaeterer Schritt geht): weiter ohne Hauen
                    elseif need > 0 then
                        Commit({kind = "grind", lvl = lv, xp = need, work = need / GrindRate(PlanLevel()), w = pos, opt = true}, 0, nil)
                        if not Ready(lo) then routeSkip[lo] = true end
                    else
                        routeSkip[lo] = true
                    end
                end
            end
            local best, bRank, bWalk, bVia, bSpot
            local near, nWalk, nVia
            for _, s in ipairs(stops) do
                if not s.used and not routeSkip[s] and Ready(s) then
                    local k = follow[P.StopKey(s)]
                    if k and (not bRank or k < bRank) then best, bRank = s, k end
                end
            end
            if not best then break end
            -- (Vorausschau im Gebiet P.ROUTE_AHEAD entfernt 23.11.2026: die Route ist jetzt als Ganzes optimiert
            -- (scripts/route_opt.lua) – Spieltest "Raecht mein Dorf": Ziele 200 m hinter der Grenze im Steinkrallen-
            -- gebirge wurden 120 Plaetze nach hinten geschoben, man lief quer durchs Brachland zurueck)
            if best.spots then
                for _, sp in ipairs(best.spots) do
                    local wk, vi = Reach(pos, sp.w, minutes, hs)
                    if not bSpot or wk < bWalk then bWalk, bVia, bSpot = wk, vi, sp end
                end
            else
                bWalk, bVia = Reach(pos, best.w, minutes, hs)
            end
            local atHere = here and pos and pos[1] == here[1] and Minutes(here, pos) <= .3
            for _, s in ipairs(stops) do
                local k = follow[P.StopKey(s)]
                -- spaeterer alter Halt genau da, wo man jetzt steht (z. B. Quest schon frei, weil man schneller
                -- aufgestiegen ist; nur am echten Standort, sonst wuerde die gekuerzte Runde umsortiert) oder
                -- Neues hier (keine neue Annahme): gleich mitnehmen statt spaeter extra herkommen
                local j = s.job
                local quick = s.kind ~= "obj" or (j and j.o.work * P.KILL_SEC / 60 <= P.FOLLOW_WORK)
                if not s.used and s.w and not s.opt and quick and Ready(s) and s ~= best and j
                    and ((k and k > bRank and atHere and Minutes(here, s.w) <= P.FOLLOW_HERE and (not ctx.route or k <= bRank + P.ROUTE_PULL))
                        or (not k and not ctx.route and not s.byway and (s.kind ~= "accept" or HereOK(j)))) then
                    if k or not j.pool or chosen[j.id] or s.kind == "accept" then
                        local wk, vi = Reach(pos, s.w, minutes, hs)
                        if not vi and wk <= P.FOLLOW_HERE and wk < bWalk and (not near or wk < nWalk) then near, nWalk, nVia = s, wk, vi end
                    end
                end
            end
            local old = fl[P.StopKey(best)]
            if old and not base then base = old - 1 end
            if old then loopNo = math.max(loopNo, old - base) end
            -- am Weg vorgezogen: Grund im Mouseover, bis der Halt erledigt ist (ctx.onWay vom letzten Plan)
            if near then near.onWay = true Commit(near, nWalk, nVia)
            else
                if ctx.onWay and ctx.onWay[P.StopKey(best)] then best.onWay = true end
                Commit(best, bWalk, bVia, bSpot)
            end
            if best.job and best.job.pool then chosen[best.id] = chosen[best.id] or "xp" end
            if near and near.job and near.job.pool then chosen[near.id] = chosen[near.id] or "xp" end
        end
    end

    -- Darf die Quest in diese Schleife? (Klassen-/Dungeon-/Vorrang-Regeln) – nil = nicht, true = immer, false = nach EP
    local function Allowed(j, nodes, dt, seed)
        if j.force then return true end
        if j.byway then
            for _, s in ipairs(nodes) do if s.w[4] ~= seed.w[4] then return dt <= P.BYWAY_NEAR or nil end end
            return true
        end
        if j.class then return (dt <= P.CLASS_NEAR or seed.class == j) or nil end
        -- Klassen-Reihe mit Verbesserung am Ende (Robe): mit kleinem Umweg immer, sonst nach EP
        if j.o.classValue and dt <= P.CLASS_NEAR then return true end
        return false
    end
    -- Mehrzeit und EP einer Quest in einer fertigen Folge (was ihr Herausnehmen sparen wuerde)
    local function Without(seq, j)
        local s2 = {}
        for _, nd in ipairs(seq) do if not (nd.s.job == j) then s2[#s2 + 1] = nd end end
        return s2
    end
    local function Extra(j)
        local dt, xp = 0, 0
        if j.t and not j.t.used then dt, xp = dt + j.o.work * P.KILL_SEC / 60, xp + j.o.work * j.o.mobXP end
        if j.e and not j.e.used then xp = xp + j.o.xp + (j.o.chainXP or 0) end
        if j.a and not j.a.used then dt = dt + P.TALK_MIN / 2 end
        if j.e and not j.e.used then dt = dt + P.TALK_MIN / 2 end
        return dt, xp
    end
    -- Schleife ab einem Stuetzpunkt: erst alle passenden Quests (die besten zuerst) einfuegen, dann die
    -- herausnehmen, die die Schleife langsamer machen als Monster hauen (Mehrweg in der ganzen Schleife zaehlt –
    -- so lohnen Quests mit Zielen nah beieinander gemeinsam, einzelne weit weg nicht)
    local function Build(seed, cands)
        local origin = seed.w
        -- Reihe mit Vorrang ("jetzt erledigen"): eine eigene Schleife nur mit ihr – sie kommt zuerst dran
        local only = {}
        for _, j in ipairs(cands) do if Prio(j.id) then only[#only + 1] = j end end
        if #only > 0 then cands = only end
        local seq, inc, keep = {}, {}, {}
        local log = 0
        for id in pairs(accepted) do if not turned[id] then log = log + 1 end end
        local time = 0
        while time < P.LOOP_MAX do
            local best, bScore, bSeq, bDt
            for _, j in ipairs(cands) do
                if not inc[j] then
                    local s2, dt, gx, nodes = TryJob(j, origin, seq)
                    if s2 then
                        local allow = Allowed(j, nodes, dt, seed)
                        if nodes[1].kind == "accept" and log >= P.LOG_MAX then allow = nil end
                        if allow ~= nil then
                            local r = gx / dt
                            j.o.loopEPM = math.max(j.o.loopEPM or 0, r)
                            local score = allow and 1e9 - dt or r
                            if not bScore or score > bScore then best, bScore, bSeq, bDt = j, score, s2, dt end
                            if allow then keep[j] = true end
                        end
                    end
                end
            end
            if not best then break end
            inc[best], seq, time = true, bSeq, time + bDt
            if best.a and not best.a.used then log = log + 1 end
        end
        -- herausnehmen, was die Schleife bremst (die schlechteste zuerst, dann neu rechnen)
        local function Cost(q) return PathCost(origin, q) end
        while true do
            local base = Cost(seq)
            local worst, wr, wseq
            for j in pairs(inc) do
                if not keep[j] then
                    local s2 = Without(seq, j)
                    -- haengt etwas anderes an dieser Quest (Folgequest in derselben Schleife)? Dann bleibt sie
                    local need = true
                    for _, nd in ipairs(s2) do
                        local oj = nd.s.job
                        if oj and oj ~= j and nd.s.kind == "accept" and not PreReady(nd.s) then
                            for _, group in ipairs(Pre(Q.q[oj.id])) do for _, p in ipairs(group) do if p == j.id then need = false end end end
                        end
                    end
                    if need then
                        local dt, xp = Extra(j)
                        dt = math.max(.2, dt + base - Cost(s2))
                        local r = xp / dt
                        j.o.loopEPM = r
                        if r < Need(j) and (not wr or r < wr) then worst, wr, wseq = j, r, s2 end
                    end
                end
            end
            if not worst then break end
            inc[worst], seq = nil, wseq
        end
        if #seq == 0 then return nil end
        -- echte Zeit ab dem Spieler: Anreise (mit Flug/Ruhestein) + Wege + Arbeit
        local first, via = Reach(pos, seq[1].w, minutes, hs)
        local walkMin = PathCost(seq[1].w, seq)
        local work, xp, works = 0, 0, 0
        local hasClass, prio = false, false
        for j in pairs(inc) do
            local dt, gx = Extra(j)
            work, xp = work + dt, xp + gx
            if j.t and not j.t.used then works = works + j.o.work end
            if j.class then hasClass = true end
            if j.force then prio = true end
        end
        local total = math.max(.5, first + walkMin + work)
        -- weit weg (Flug/Schiff) und dort gibt es danach nicht genug zum Bleiben: die Rueckreise zaehlt mit
        -- (Nachstellung 21.11.2026: Schiff nach Silberwald fuer zwei Abgaben und gleich wieder zurueck)
        local z = seed.w[4]
        if pos and (first > P.FAR_LOOP or seq[1].w[1] ~= pos[1]) then
            local rest = 0
            for _, j in ipairs(jobs) do
                if not inc[j] and not j.byway and (not j.e or not j.e.used) then
                    local s = (j.a and not j.a.used) and j.a or j.t or j.e
                    if s and s.w and s.w[4] == z and (s ~= j.a or Ready(s)) then rest = rest + 1 end
                end
            end
            if rest < P.STAY_MIN then total = total + (Trip(seq[#seq].w, pos)) end
        end
        local gain = xp + (walkMin + (via and 0 or first)) * P.WALK_XP * P.GrindEPM(PlanLevel())
        return {seq = seq, inc = inc, minutes = total, xp = gain, epm = gain / total, class = hasClass, prio = prio,
            works = works, seed = seed}
    end
    -- Stuetzpunkte: bereite Halte, nah beieinander gesammelt (hoechstens P.HUB_R yd)
    -- feste Gebietsfolge: hoechstens P.FLOW_ACTIVE Gebiete gleichzeitig – die ersten in der Folge, deren Fenster zur
    -- Stufe passt und in denen noch genug bereit ist (Nachstellung 21.11.2026: ab 30 pendelte er zwischen sechs Gebieten)
    local activeAt, active
    local zoneFit = {}   -- bereite, zur Stufe passende Quests je Gebiet (aus ActiveZones)
    local function ActiveZones()
        local lvl = PlanLevel()
        if activeAt == lvl and active then return active end
        -- je Gebiet: bereite Annehmen-Halte, deren Queststufe zur Stufe passt (L-3 .. L+2) – dort ist man richtig
        local fit = {}
        zoneFit = fit
        for _, s in ipairs(stops) do
            local j = s.job
            if j and s.kind == "accept" and not s.used and s.w and s.w[4] and not j.byway and Ready(s) then
                local ql = (Q.q[s.id] or {})[1] or 0
                if ql >= lvl - 3 and ql <= lvl + 2 then fit[s.w[4]] = (fit[s.w[4]] or 0) + 1 end
            end
        end
        local cand, order = {}, 0
        for _, f in ipairs(P.FlowWindows(me.race, me.faction) or {}) do
            local z = f[1]
            order = order + 1
            if not cand[z] and lvl >= f[2] and lvl < f[3] then cand[z] = {z = z, n = fit[z] or 0, o = order} end
        end
        local list = {}
        for _, c in pairs(cand) do list[#list + 1] = c end
        -- das Gebiet, in dem man gerade ist, bleibt, solange dort noch genug passt (kein Pendeln)
        table.sort(list, function(a, b)
            local ah, bh = a.z == zone and a.n >= P.FLOW_MIN_QUESTS, b.z == zone and b.n >= P.FLOW_MIN_QUESTS
            if ah ~= bh then return ah end
            if a.n ~= b.n then return a.n > b.n end
            return a.o < b.o
        end)
        active = {}
        for i = 1, math.min(P.FLOW_ACTIVE, #list) do
            if list[i].n >= P.FLOW_MIN_QUESTS or i == 1 then active[list[i].z] = true end
        end
        activeAt = lvl
        return active
    end
    local wide = false   -- notfalls (nichts in den aktiven Gebieten): alle Gebiete, deren Fenster passt
    local function InFlow(z)
        if not ctx.flow or not z or not P.FLOW.start[me.race or 0] then return true end
        if wide then return P.FlowAllowed(me.race, me.faction, z, PlanLevel()) ~= false end
        local act = ActiveZones()
        if P.CITY_NEAR[z] then
            for _, nz in ipairs(P.CITY_NEAR[z]) do if act[nz] then return true end end
            return false
        end
        return act[z] == true
    end
    local function Seeds()
        activeAt = nil
        local list = {}
        for _, s in ipairs(stops) do
            local j = s.job
            -- feste Gebietsfolge (ctx.flow): Stuetzpunkte nur in den Gebieten, die zur Stufe dran sind (Hauptstaedte
            -- immer: Klassenquests, Reisen) – kein Springen zwischen Gebieten, wie in einem geschriebenen Leitfaden
            local z = s.w and s.w[4]
            -- angenommene Quests in einem anderen Gebiet warten, bis hier nichts mehr ist (Nutzer 21.11.2026: "Abgaben
            -- im anderen Gebiet erst, wenn das aktuelle fertig ist"; Pruefung 22.11.: Pendeln zwischen 4 Gebieten)
            local inFlow = not ctx.flow or not z or (j and (j.class or j.force or (accepted[j.id] and wide))) or InFlow(z)
            if inFlow and j and not s.used and s.w and not j.byway and Ready(s) and (not j.pool or s.kind ~= "turnin" or accepted[j.id]) then
                local hit
                for _, c in ipairs(list) do
                    if c.w[1] == s.w[1] and Dist(c.w, s.w) <= P.HUB_R then hit = c break end
                end
                if not hit then hit = {w = s.w, n = 0, jobs = {}} list[#list + 1] = hit end
                hit.n = hit.n + 1
                if j.class then hit.class = j end
                hit.jobs[j] = true
            end
        end
        for _, c in ipairs(list) do c.travel = (Reach(pos, c.w, minutes, hs)) end
        table.sort(list, function(a, b) if a.travel ~= b.travel then return a.travel < b.travel end return a.n > b.n end)
        local out, zones = {}, {}
        -- auch genau hier (z. B. Dungeonquest beim Geber, an dem man steht: "nur wenn du sowieso dort bist")
        if pos then out[1] = {w = pos, n = 0, jobs = {}, travel = 0} end
        for i, c in ipairs(list) do
            local z = c.w[4] or 0
            if i <= P.SEEDS or c.class or (not zones[z] and #out < P.SEEDS * 2) then out[#out + 1] = c zones[z] = true end
        end
        return out
    end
    -- Quests fuer eine Schleife: alle mit einem offenen Halt nahe am Stuetzpunkt (oder schon im Log)
    local function Cands(seed)
        local out = {}
        for _, j in ipairs(jobs) do
            local take = seed.jobs[j]
            if not take then
                for _, s in ipairs({j.a or false, j.t or false, j.e or false}) do
                    if s and not s.used and s.w and s.w[1] == seed.w[1] and Minutes(seed.w, s.w) <= P.CAND_R then take = true break end
                end
            end
            -- feste Gebietsfolge: neue Quests nur, wenn alle ihre Orte in Gebieten liegen, die gerade dran sind
            -- (Hauptstaedte zaehlen mit); schon angenommene und Pflicht-Klassenquests immer
            if take and ctx.flow and not j.class and not j.force then
                for _, s in ipairs({j.a or false, j.t or false, j.e or false}) do
                    local z = s and not s.used and s.w and s.w[4]
                    if z and not accepted[j.id] and not InFlow(z) then take = false break end
                    -- ein Halt weit weg in einem anderen Gebiet/einer Stadt (z. B. Abgabe in Donnerfels): nicht in diese
                    -- Runde – das kommt dran, wenn man ohnehin dort ist (Nutzer: "nie fuer eine einzelne Quest")
                    -- Hauptstaedte nur ueber eigene Runden dort (mit mehreren Quests), sonst je ein Abstecher pro Abgabe
                    -- die eigene Hauptstadt des Gebiets (Unterstadt fuer Tirisfal/Silberwald) zaehlt wie das Gebiet
                    -- (Nachstellung 22.11.2026: Materialsammlung aus Unterstadt mit Zielen im Silberwald fiel ganz weg)
                    local own = false
                    if z and P.CITY_NEAR[z] then for _, nz in ipairs(P.CITY_NEAR[z]) do if nz == seed.w[4] then own = true end end end
                    if not own and seed.w[4] and P.CITY_NEAR[seed.w[4]] and z then
                        for _, nz in ipairs(P.CITY_NEAR[seed.w[4]]) do if nz == z then own = true end end
                    end
                    if z and z ~= seed.w[4] and not own and (P.CITY[z] or s.w[1] ~= seed.w[1] or (Trip(seed.w, s.w)) > P.FLOW_FAR) then take = false break end
                end
            end
            if take and not (j.e and j.e.used) then out[#out + 1] = j end
        end
        return out
    end
    -- Reihenfolge der gewaehlten Schleife kuerzen: Stuecke aus 1-3 Halten an eine bessere Stelle schieben, solange
    -- alle Bedingungen gelten (annehmen vor erledigen vor abgeben, Vorquest abgegeben vor Folgequest)
    local function Valid(seq)
        local at = {}
        for k, nd in ipairs(seq) do at[nd.s] = k end
        for k, nd in ipairs(seq) do
            local s, j = nd.s, nd.s.job
            if j then
                if (s.kind == "obj" or s.kind == "turnin") and j.a and at[j.a] and at[j.a] > k then return false end
                if s.kind == "turnin" and j.t and at[j.t] and at[j.t] > k then return false end
                if s.kind == "accept" then
                    for _, group in ipairs(Pre(Q.q[j.id])) do
                        local ok = false
                        for _, p in ipairs(group) do
                            if done(p) or turned[p] then ok = true break end
                            local pj = info[p] and info[p].job
                            local pk = pj and pj.e and at[pj.e]
                            if pk and pk < k then ok = true break end
                        end
                        if not ok then return false end
                    end
                end
            end
        end
        return true
    end
    local function Improve(origin, seq)
        for _ = 1, P.IMPROVE_PASSES do
            local better = false
            for len = 1, 3 do
                local i = 1
                while i + len - 1 <= #seq do
                    local moved = false
                    local base = PathCost(origin, seq)
                    local rest, part = {}, {}
                    for k, nd in ipairs(seq) do if k >= i and k < i + len then part[#part + 1] = nd else rest[#rest + 1] = nd end end
                    for j = 0, #rest do
                        if j ~= i - 1 then
                            local try = {}
                            for k = 1, j do try[#try + 1] = rest[k] end
                            for _, nd in ipairs(part) do try[#try + 1] = nd end
                            for k = j + 1, #rest do try[#try + 1] = rest[k] end
                            if PathCost(origin, try) < base - .05 and Valid(try) then
                                for k = 1, #try do seq[k] = try[k] end
                                better, moved = true, true
                                break
                            end
                        end
                    end
                    if not moved then i = i + 1 end
                end
            end
            if not better then break end
        end
    end
    -- Freiwillige Halte in die gewaehlte Schleife: Lehrer, Flugpunkt, Haendler
    local function AddOpt(L1)
        local seq = L1.seq
        local origin = pos
        -- Stufe im Plan nach jedem Halt der Schleife (Lehrer erst nach dem Aufstieg)
        local lvlAt, cum = {[0] = PlanLevel()}, 0
        for k, nd in ipairs(seq) do
            local o = nd.s.id and info[nd.s.id]
            if o and nd.s.kind == "obj" then cum = cum + o.work * o.mobXP
            elseif o and nd.s.kind == "turnin" then cum = cum + o.xp end
            lvlAt[k] = (me.xpMax or 0) > 0 and P.LevelAfter(L, me.xp or 0, me.xpMax, xpSum + xpExtra + cum) or L
        end
        local endLvl = lvlAt[#seq]
        -- Klassenlehrer: Bonus je Stufe Rueckstand, weit weg nur bei grossem Rueckstand
        local groups = {}
        for _, s in ipairs(stops) do
            if s.kind == "train" and not s.used and s.lvl <= endLvl and (not groups[s.group or ""] or s.lvl < groups[s.group or ""].lvl) then
                groups[s.group or ""] = s
            end
        end
        for _, s in pairs(groups) do
            local behind = math.max(0, endLvl - s.lvl)
            local lo = 1
            while lo <= #seq and lvlAt[lo - 1] < s.lvl do lo = lo + 1 end
            local bd, bk, bsp
            for _, sp in ipairs(s.spots) do
                local d, k = BestSpot(origin, seq, sp.w, lo)
                if not bd or d < bd then bd, bk, bsp = d, k, sp end
            end
            -- "wenn ich schon in der Naehe eines Lehrers bin" (Nutzer 20.11.2026): Umweg hoechstens P.TRAIN_NEAR Minuten,
            -- je 2 Stufen Rueckstand mehr; ab P.TRAIN_BEHIND Stufen auch weit (Nachstellung 21.11.: 2 km zum Lehrer)
            if bd and (bd <= math.min(P.TRAIN_FAR, P.TRAIN_NEAR * (1 + behind / 2)) or behind >= P.TRAIN_BEHIND) then
                table.insert(seq, bk, {s = s, w = bsp.w, spot = bsp})
            end
        end
        for _, s in ipairs(stops) do
            if s.kind == "fp" and not s.used then
                local d, k = BestSpot(origin, seq, s.w, 1)
                local a = k == 1 and origin or seq[k - 1].w
                if d <= P.FP_NEAR * 2 and a and Minutes(a, s.w) <= P.FP_NEAR then table.insert(seq, k, {s = s, w = s.w}) end
            end
        end
        -- Haendler: Tasche (bald) voll oder Ausruestung kaputt – am Stuetzpunkt vor dem Losgehen
        if vendorStop and not vendorStop.used then
            local soon = vendorNeed or (ctx.bags and ctx.bags - (L1.works or 0) / P.LOOT_PER_SLOT <= P.BAG_SOON)
            if soon then
                local bd, bk, bsp
                for _, sp in ipairs(vendorStop.spots) do
                    local d, k = BestSpot(origin, seq, sp.w, 1)
                    local a = k == 1 and origin or seq[k - 1].w
                    if a and Minutes(a, sp.w) <= P.VENDOR_NEAR and (not bd or d < bd) then bd, bk, bsp = d, k, sp end
                end
                if bd and bd <= P.VENDOR_NEAR * 2 then table.insert(seq, bk, {s = vendorStop, w = bsp.w, spot = bsp}) end
            end
        end
    end
    -- Am Stuetzpunkt gleich alles Lohnende mitnehmen (Nutzer: "am Stuetzpunkt alles Noetige in einem Rutsch"):
    -- Quests, deren Geber hier steht (hoechstens P.HUB_NEAR Minuten von einem Annehmen/Abgeben der Schleife) und die
    -- sich fuer sich lohnen, werden schon jetzt angenommen – die naechste Schleife spart den Weg zurueck zum Geber
    local function PreAccept(L1)
        local seq = L1.seq
        -- die naechste Schleife vom selben Stuetzpunkt vorausrechnen: deren Quests mit Geber hier gleich mitnehmen
        -- (bis P.PREACCEPT_LOOPS Runden voraus: sonst kam er fuer die Annahmen der uebernaechsten Runde extra zurueck,
        -- Nachstellung 22.11.2026: ~25 Rueckwege je 10 Stufen)
        local nextJobs = {}
        do
            local cands = {}
            for _, j in ipairs(Cands(L1.seed)) do if not L1.inc[j] then cands[#cands + 1] = j end end
            for _ = 1, P.PREACCEPT_LOOPS do
                local L2 = #cands > 0 and Build({w = L1.seed.w, n = 0, jobs = {}}, cands) or nil
                if not L2 then break end
                local rest = {}
                for j in pairs(L2.inc) do nextJobs[j] = true end
                for _, j in ipairs(cands) do if not L2.inc[j] then rest[#rest + 1] = j end end
                cands = rest
            end
        end
        local log = 0
        for id in pairs(accepted) do if not turned[id] then log = log + 1 end end
        for _, nd in ipairs(seq) do if nd.s.kind == "accept" then log = log + 1 end end
        local start = pos
        for _, j in ipairs(jobs) do
            if log >= P.LOG_MAX then break end
            local a = j.a
            -- Dungeonquests/empfohlene Reihen: annehmen, wenn man ohnehin beim Geber ist ("nur wenn du sowieso dort
            -- bist") – am Startpunkt der Schleife oder an einem ihrer Stuetzpunkt-Halte
            if a and j.byway and not a.used and not L1.inc[j] and Ready(a) then
                local at
                if start and start[1] == a.w[1] and Minutes(start, a.w) <= P.HUB_NEAR then at = 0 end
                for k, nd in ipairs(seq) do
                    if at then break end
                    if (nd.s.kind == "accept" or nd.s.kind == "turnin") and nd.w[1] == a.w[1] and Minutes(nd.w, a.w) <= P.HUB_NEAR then at = k end
                end
                if at then
                    table.insert(seq, at + 1, {s = a, w = a.w})
                    L1.inc[j] = true
                    log = log + 1
                end
            end
            -- nur mit Ziel hier in der Gegend (kein Botengang in eine andere Richtung: der bliebe im Log liegen)
            local near = a and j.t and not j.t.used and j.t.w[1] == a.w[1] and Minutes(a.w, j.t.w) <= P.CAND_R
                and j.e and j.e.w[1] == a.w[1] and Minutes(a.w, j.e.w) <= P.CAND_R
            if a and near and not a.used and not L1.inc[j] and not j.byway and Ready(a) then
                local at
                for k, nd in ipairs(seq) do
                    if (nd.s.kind == "accept" or nd.s.kind == "turnin") and nd.w[1] == a.w[1] and Minutes(nd.w, a.w) <= P.HUB_NEAR then at = k break end
                end
                if at then
                    local s2, dt, gx = TryJob(j, a.w, {})
                    if s2 and (j.class or nextJobs[j] or gx / dt >= Need(j)) then
                        table.insert(seq, at + 1, {s = a, w = a.w})
                        L1.inc[j] = true
                        log = log + 1
                    end
                end
            end
        end
    end
    local function Chosen(j)
        if j.pool and not chosen[j.id] then
            chosen[j.id] = (#j.o.value > 0 and (j.o.loopEPM or 0) < thr) and "value" or "xp"
        end
    end
    local startWork
    -- verlassene Gebiete (Hauptstaedte zaehlen nicht: kurz fuer Lehrer/Klassenquest hin und zurueck ist normal)
    local leftZones, lastZone = {}, (me.mapID and not P.CITY[me.mapID]) and me.mapID or nil
    -- nur so weit planen, wie die Quests reichen (Planungsfenster bis Stufe L + P.HORIZON) – sonst plant er mit
    -- Lueckenfuellern weiter, und der feste Fahrplan haelt sie fest (Nachstellung 21.11.2026: Stufe 4 nach Mulgore)
    while not ctx.route and #order < P.MAX_STEPS and minutes - recMinutes < P.MAX_MINUTES and PlanLevel() < L + P.HORIZON do
        local best, bScore
        local curZone = zone
        for pass = 1, ctx.flow and 3 or 1 do
        relaxed = pass >= 2
        wide = pass == 3
        if pass >= 2 and best then break end
        for _, seed in ipairs(Seeds()) do
            local cc = Cands(seed)
            local L1 = Build(seed, cc)
            -- feste Gebietsfolge: nie fuer eine einzelne Quest in ein anderes Gebiet/eine Stadt (Nutzer 21.11.2026);
            -- solche Abgaben warten, bis man ohnehin dort ist
            if L1 and ctx.flow and seed.w[4] and seed.w[4] ~= curZone and not L1.class then
                local there = {}
                local n = 0
                for _, nd in ipairs(L1.seq) do
                    local j = nd.s.job
                    if j and nd.w[4] == seed.w[4] and not there[j] then there[j] = true n = n + 1 end
                end
                -- das Gebiet hat insgesamt genug zu tun (die naechsten Runden dort holen den Rest): dann ist es kein
                -- Abstecher fuer eine einzelne Quest
                if n < P.FLOW_MIN_QUESTS and (zoneFit[seed.w[4]] or 0) < P.FLOW_MIN_QUESTS then L1 = nil end
            end
            if L1 then
                local sc = L1.epm
                local z = seed.w[4]
                if z and z ~= curZone then sc = sc / (1 + (ctx.flow and P.FLOW_HYST or P.ZONE_HYST)) end
                -- verlassenes Gebiet: nur zurueck, wenn es dort deutlich mehr gibt (keine Reste-Rueckwege)
                if z and leftZones[z] and PlanLevel() < leftZones[z] + P.ZONE_BACK_LVL then sc = sc / (1 + P.ZONE_BACK) end
                -- anderer Kontinent: muss noch etwas mehr bringen (Schiff/Zeppelin, Warten)
                if pos and seed.w[1] ~= pos[1] then sc = sc / (1 + P.CONT_HYST) end
                if L1.class then sc = sc * P.CLASS_BONUS end
                if L1.prio then sc = sc + 1e6 end
                if not bScore or sc > bScore then best, bScore = L1, sc L1.pass = pass end
            end
        end
        end
        relaxed, wide = false, false
        -- Aufstieg vorausrechnen (Nutzer 20.11.2026, wie RestedXP "Monster hauen bis X / Y EP"): fehlt nur wenig bis
        -- zur naechsten Stufe und wird damit hier im Gebiet etwas frei, lohnt das oft mehr als weggehen. Hoechstens
        -- 1/4 Stufe; bis P.GRIND_HUB_MAX Minuten auch mehr, wenn man sonst das Gebiet verlassen muesste.
        local grindStop
        if pos and (me.xpMax or 0) > 0 and PlanLevel() < 60 and curZone and not P.CITY[curZone] then
            local baseLvl = PlanLevel()
            local nextLvl = baseLvl + 1
            local pre = 0
            for _, j in ipairs(jobs) do
                if j.e and not j.e.used and finished[j.id] and Minutes(pos, j.e.w) <= P.HUB_NEAR then pre = pre + j.o.xp end
            end
            local need = P.XPTo(L, me.xp or 0, me.xpMax, xpSum + pre, nextLvl)
            local size = P.XP_NEED[baseLvl] or me.xpMax
            local gm = need / GrindRate(baseLvl)
            local leaving = not best or (best.seed.w[4] ~= curZone)
            if need > 0 and gm <= P.GRIND_HUB_MAX and (need <= size * P.GRIND_SHARE or leaving) then
                xpExtra = need
                for _, seed in ipairs(Seeds()) do
                    if seed.w[4] == curZone then
                        local L2 = Build(seed, Cands(seed))
                        local gated = false
                        if L2 then
                            for j in pairs(L2.inc) do
                                if j.a and not j.a.used and ((Q.q[j.id] or {})[2] or 0) > baseLvl then gated = true end
                            end
                        end
                        if gated then
                            local sc = (L2.xp + need) / (L2.minutes + gm)
                            if not bScore or sc > bScore then
                                best, bScore = L2, sc
                                grindStop = {kind = "grind", lvl = nextLvl, xp = need, work = gm, w = pos, opt = true, hub = true}
                            end
                        end
                    end
                end
                xpExtra = 0
            end
        end
        -- Vor dem Gebietswechsel alles Fertige hier abgeben (Entwurf 21.11.2026), sonst geht es spaeter extra zurueck
        local leavingTo = best and best.seed.w[4]
        if best and pos and curZone and leavingTo ~= curZone and not P.CITY[curZone] and not grindStop then
            local seq, any = {}, false
            for _, j in ipairs(jobs) do
                local e = j.e
                if e and not e.used and not e.finTried and e.w[4] == curZone and Ready(e) and finished[j.id] then
                    e.finTried = true
                    local s2, dt = TryJob(j, pos, seq)
                    if s2 and dt <= P.ZONE_FINISH then seq, any = s2, true end
                end
            end
            if any then
                loopNo = loopNo + 1
                loops[loopNo] = {n = loopNo, w = pos, mapID = curZone, finish = true}
                for _, nd in ipairs(seq) do
                    if not nd.s.used then
                        local walk, via = Reach(pos, nd.w, minutes, hs)
                        Commit(nd.s, walk, via)
                    end
                end
                best = nil
            end
        end
        if best == nil and leavingTo then
            -- (nach dem Abgeben neu waehlen)
        elseif not best then
            -- Nichts mehr bereit, weil die Stufe fehlt: hier Monster hauen bis zur noetigen Stufe
            local target
            if (me.xpMax or 0) > 0 and pos then
                for _, s in ipairs(stops) do
                    local j = s.job
                    if not s.used and j and not j.byway and not j.pool then
                        local lv
                        if s.kind == "accept" then lv = (Q.q[s.id] or {})[2]
                        elseif s.kind == "obj" then lv = ((Q.q[s.id] or {})[1] or 0) - P.OBJ_AHEAD end
                        if lv and lv > PlanLevel() and (not target or lv < target) then target = lv end
                    end
                end
            end
            if not target then break end
            local need = P.XPTo(L, me.xp or 0, me.xpMax, xpSum, target)
            local m = need / GrindRate(PlanLevel())
            if m > P.GRIND_MAX then break end
            loopNo = loopNo + 1
            local g = {kind = "grind", lvl = target, xp = need, work = m, w = pos, opt = true}
            stops[#stops + 1] = g
            Commit(g, 0, nil)
        else
            loopNo = loopNo + 1
            if not startWork and best.seed.w[4] and not P.CITY[best.seed.w[4]] then startWork = best.seed.w[4] end
            local z = best.seed.w[4]
            if z and not P.CITY[z] then
                if lastZone and z ~= lastZone then leftZones[lastZone] = PlanLevel() end
                leftZones[z], lastZone = nil, z
            end
            loops[loopNo] = {n = loopNo, w = best.seed.w, mapID = best.seed.w[4], minutes = best.minutes, xp = best.xp, epm = best.epm, pass = best.pass}
            if grindStop then
                stops[#stops + 1] = grindStop
                Commit(grindStop, 0, nil)
            end
            Improve(pos, best.seq)
            AddOpt(best)
            PreAccept(best)
            for j in pairs(best.inc) do Chosen(j) end
            -- in Reihenfolge ausfuehren; ist ein Halt (noch) nicht bereit, kommt der naechste bereite zuerst
            local list = best.seq
            while #list > 0 do
                local k = 1
                -- schon mit erledigt (gleiche Gegner wie ein Ziel davor)
                while k <= #list do
                    if list[k].s.used then table.remove(list, k) else k = k + 1 end
                end
                k = 1
                while k <= #list and not Ready(list[k].s) do k = k + 1 end
                if k > #list then break end
                local nd = table.remove(list, k)
                local walk, via = Reach(pos, nd.w, minutes, hs)
                Commit(nd.s, walk, via, nd.spot)
            end
        end
    end
    -- Quests aus dem Fahrplan, die schon dran waren, zaehlen als gewaehlt
    for _, s in ipairs(order) do if s.job then Chosen(s.job) end end
    -- nicht gewaehlte Quests: Grund
    for _, j in ipairs(jobs) do
        local o = j.o
        if j.pool and not chosen[j.id] then
            if o.loopEPM then o.epm = o.loopEPM end
            o.skip = o.loopEPM and o.loopEPM < thr * (prev and P.NEW_SLACK or 1) and "Zu langsam: %d EP/min (lohnt ab ~%d)."
                or "Liegt abseits – anderswo gibt es gerade mehr EP."
        end
    end
    -- Gruende/Zeichen
    for id, why in pairs(chosen) do
        local o = info[id]
        o.why = why
        if why == "dungeon" then o.tags[#o.tags + 1] = "dungeon" end
        if why == "class" then o.tags[#o.tags + 1] = "class" end
        if why == "pre" and not o.rec then o.tags[#o.tags + 1] = "pre" end
        if o.rec then o.tags[#o.tags + 1] = "rec" end
        if why == "xp" or (o.epm >= grind * factor and factor > 0) then o.tags[#o.tags + 1] = "xp" end
        for _, v in ipairs(o.value) do if v.kind == "upgrade" or v.kind == "bag" then o.tags[#o.tags + 1] = "upgrade" break end end
        if o.group then o.tags[#o.tags + 1] = "group" end
    end
    if not startWork and zone and not P.CITY[zone] then startWork = zone end
    if startWork and P.CITY[startWork] then startWork = nil end
    -- 5c) Ruhestein setzen: beim Gastwirt am Weg, wenn die naechsten Halte viel naeher liegen als der Heimatort
    -- nur mit bekanntem Heimatort (Spieltest 21.11.2026: Heimatort unbekannt -> "Ruhestein setzen" in Orgrimmar,
    -- obwohl er in Crossroads stand)
    if ctx.inns and ctx.home and #order > 3 then
        local home = ctx.home
        local function D(a, b) return math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end
        -- auch gleich hier (i = 0): sonst rutscht der Halt bei jedem Neuplanen einen Schritt nach hinten und kommt
        -- nie dran (Nachstellung 21.11.2026)
        for i = 0, #order do
            local s = i == 0 and {w = here, kind = "here"} or order[i]
            if s.w and s.kind ~= "grind" and s.kind ~= "bind" then
                local inn, d
                for _, n in ipairs(ctx.inns) do
                    if n[1] == s.w[1] then
                        local dd = D(n, s.w)
                        if not d or dd < d then inn, d = n, dd end
                    end
                end
                if inn and d <= P.BIND_PASS and not (home and home.inn == inn.id) and not P.CITY_INNS[inn.id] then
                    local n, ax, ay = 0, 0, 0
                    for k = i + 1, math.min(#order, i + P.BIND_AHEAD) do
                        local w = order[k].w
                        if w and w[1] == inn[1] and D(inn, w) <= P.BIND_MAX_AREA then n, ax, ay = n + 1, ax + w[2], ay + w[3] end
                    end
                    if n >= P.BIND_NEAR then
                        local area = {inn[1], ax / n, ay / n}
                        local toArea = D(inn, area)
                        -- Halte auf einem anderen Kontinent zaehlen als "nicht naeher" (Nachstellung 21.11.2026:
                        -- Ruhestein in Orgrimmar, gleich danach Zeppelin nach Tirisfal und dort wieder setzen)
                        local closer, total = 0, 0
                        for k = i + 1, math.min(#order, i + P.BIND_LONG) do
                            local w = order[k].w
                            if w then
                                total = total + 1
                                if w[1] == inn[1] and (home[1] ~= inn[1] or D(inn, w) < D(home, w)) then closer = closer + 1 end
                            end
                        end
                        local lasting = total == 0 or closer * 3 >= total * 2
                        if lasting and toArea <= P.BIND_MAX_AREA and (not home or home[1] ~= inn[1] or D(home, area) >= toArea + P.BIND_BETTER) then
                            local walk = Minutes(s.w, inn)
                            local b = {kind = "bind", w = {inn[1], inn[2], inn[3]}, inn = inn.id, name = inn.name, opt = true,
                                walk = walk, cost = walk + P.BIND_MIN, gain = 0, used = true}
                            table.insert(order, i + 1, b)
                            minutes = minutes + b.cost
                            -- spaeter geplante Ruhestein-Reisen gingen noch zum alten Ort: dann lieber laufen
                            local prev = b.w
                            for k = i + 2, #order do
                                local o2 = order[k]
                                if o2.via and o2.via.bind and o2.w then
                                    local wk, vi = Trip(prev, o2.w)
                                    minutes = minutes + wk - (o2.walk or 0)
                                    o2.cost = (o2.cost or 0) + wk - (o2.walk or 0)
                                    o2.walk, o2.via = wk, vi
                                end
                                if o2.w then prev = o2.w end
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    -- Monster hauen fuer den Aufstieg VOR die Abgaben am selben Ort: dann bringt die Abgabe den Aufstieg
    -- (Anzeige wie RestedXP "bis 2800 / 5000 EP")
    for i = #order, 1, -1 do
        local g = order[i]
        if g.kind == "grind" and g.hub then
            local j = i
            while j > 1 do
                local t = order[j - 1]
                if t.kind ~= "turnin" or t.via or not t.w or Minutes(t.w, g.w) > P.HUB_NEAR then break end
                j = j - 1
            end
            if j < i then
                table.remove(order, i)
                local first = order[j]
                g.w, g.walk, g.cost = first.w, first.walk, (g.cost or 0) + (first.walk or 0)
                first.cost, first.walk = (first.cost or 0) - (first.walk or 0), 0
                table.insert(order, j, g)
            end
        end
    end
    -- Aufstieg je Halt (Anzeige "-> Stufe X") und EP-Stand fuer "Monster hauen bis X / Y EP"
    if (me.xpMax or 0) > 0 then
        local lv, x, mx = L, me.xp or 0, me.xpMax
        for _, s in ipairs(order) do
            if s.kind == "grind" then s.fromXP, s.maxXP = math.floor(x), mx end
            x = x + (s.gain or 0)
            while lv < 60 and x >= mx do
                x, lv = x - mx, lv + 1
                mx = P.XP_NEED[lv] or mx
                s.levelUp = lv
            end
            if s.kind == "grind" then s.toXP = math.floor(s.fromXP + (s.xp or 0) + .5) end
        end
    end
    -- Quests im Log, die nicht mehr lohnen: zum Abbrechen vorschlagen (nur Hinweis, nie automatisch)
    local abandon = {}
    for id, o in pairs(info) do
        local nearlyDone = (o.progress or 0) >= P.ABANDON_KEEP and o.xpFactor > .2
        if o.log and not chosen[id] and o.skip and override[id] ~= "no" and o.skip ~= "Dungeon kommt erst später." and not nearlyDone then
            abandon[#abandon + 1] = o
        end
    end
    table.sort(abandon, function(a, b) return a.id < b.id end)
    local left = {}
    for _, s in ipairs(stops) do
        if not s.used and not s.opt and not (s.job and s.job.pool and not chosen[s.id]) then left[#left + 1] = s end
    end
    -- 6) Schritte: aufeinanderfolgende Halte am selben NPC zusammenfassen
    local onWay = {}
    local steps = {}
    for _, s in ipairs(order) do
        -- Reise-Schritt davor: zum Flugmeister bzw. zur Abfahrt (Navi dorthin, Welt-Koordinaten)
        if s.via then
            local v = s.via
            local first = v.kind == "flight" and v.from or v.dep
            steps[#steps + 1] = {kind = "travel", via = v, world = first and {first[1], first[2], first[3]}, walk = v.kind == "hearth" and s.walk or nil,
                mapID = first and first.mapID, x = first and first.mx, y = first and first.my,
                actions = {}, stopKey = "t:" .. P.StopKey(s)}
        end
        local last = steps[#steps]
        -- feste Route: winziges "Monster hauen" (unter P.ROUTE_GRIND_MIN Minuten) nicht anzeigen – das ergibt sich
        -- unterwegs von selbst (Nachstellung 22.11.2026: "bis Stufe 2" als 4. Schritt)
        local silent = ctx.route and s.kind == "grind" and (s.work or 0) < P.ROUTE_GRIND_MIN
        if silent then
            -- nichts
        elseif s.kind == "train" or s.kind == "fp" or s.kind == "grind" or s.kind == "bind" or s.kind == "vendor" then
            local w = s.w or {}
            steps[#steps + 1] = {kind = s.kind, group = s.group, name = s.name, lvl = s.lvl, n = s.n, xp = s.xp, work = s.work, inn = s.inn,
                fpID = s.kind == "fp" and s.id or nil,
                fromXP = s.fromXP, toXP = s.toXP, maxXP = s.maxXP, hub = s.hub,
                world = s.kind ~= "grind" and w[1] and {w[1], w[2], w[3]} or nil,
                mapID = w[4] or (s.kind == "grind" and me.mapID or nil), x = s.kind ~= "grind" and w[5] or nil, y = s.kind ~= "grind" and w[6] or nil,
                walk = s.walk, actions = {}, stopKey = P.StopKey(s), cost = 0, gain = 0}
        elseif last and s.nr and last.nr == s.nr and s.kind ~= "obj" and last.kind ~= "obj" and s.kind ~= "dungeon" then
            last.actions[#last.actions + 1] = {kind = s.kind, id = s.id}
        elseif last and s.kind == "obj" and s.partner and last.kind == "obj" and not s.via then
            -- gleiche Gegner: ein Schritt, beide Ziele im Kasten
            last.actions[#last.actions + 1] = {kind = s.kind, id = s.id}
            if Q.q[s.id] and #(last.area or {}) < P.AREA_MAX then
                last.area = last.area or {}
                for _, nr in ipairs(Targets(s.id)) do
                    local a = World(nr)
                    if a and #last.area < P.AREA_MAX then last.area[#last.area + 1] = {a[1], a[2], a[3]} end
                end
            end
        else
            local w = s.w
            -- Quest-Ziel = Gebiet: alle Spawnpunkte (Weltkoordinaten), damit Pfeil und Entfernung den naechsten nehmen
            local area
            if s.kind == "obj" and Q.q[s.id] then
                area = {}
                for _, nr in ipairs(Targets(s.id)) do
                    local a = World(nr)
                    if a then area[#area + 1] = {a[1], a[2], a[3]} end
                    if #area >= P.AREA_MAX then break end
                end
                if #area == 0 then area = nil end
            end
            -- pos = Weltposition des Halts (Kontinent, x, y) – fuer die Gegend-Buendel im Kasten (23.11.2026)
            steps[#steps + 1] = {kind = s.kind, nr = s.nr, key = s.key, ids = s.ids, mapID = w and w[4], x = w and w[5], y = w and w[6],
                pos = w and w[1] and {w[1], w[2], w[3]} or nil, area = area, walk = s.walk, actions = s.kind == "dungeon" and {} or {{kind = s.kind, id = s.id}}, stopKey = P.StopKey(s), cost = 0, gain = 0}
        end
        if not silent and steps[#steps] then
            steps[#steps].loop = steps[#steps].loop or s.loop
            if s.onWay then steps[#steps].onWay = true onWay[P.StopKey(s)] = true end
            steps[#steps].cost = steps[#steps].cost + (s.cost or 0)
            steps[#steps].gain = steps[#steps].gain + (s.gain or 0)
            if s.levelUp then steps[#steps].levelUp = math.max(steps[#steps].levelUp or 0, s.levelUp) end
            local so = s.id and info[s.id]
            if so and so.forDungeon and s.kind == "accept" then steps[#steps].dungeon = so.forDungeon end
        end
    end
    -- Gebietsbloecke fuer die Anzeige: {mapID, first, last, steps, minutes}
    local blocks = {}
    for i, st in ipairs(steps) do
        local b = blocks[#blocks]
        local m = st.mapID or (b and b.mapID)
        if not b or (m and m ~= b.mapID) then
            b = {mapID = m, first = i, steps = 0, minutes = 0}
            blocks[#blocks + 1] = b
        end
        b.last, b.steps, b.minutes = i, b.steps + 1, b.minutes + (st.cost or 0)
        b.xp = (b.xp or 0) + (st.gain or 0)
        st.block = #blocks
    end
    -- Ausgelassen (nur mit Grund, sortiert nach EP)
    local skipped = {}
    for _, o in pairs(info) do
        if not chosen[o.id] and o.skip and not o.log then skipped[#skipped + 1] = o end
    end
    table.sort(skipped, function(a, b) if a.totalXP ~= b.totalXP then return a.totalXP > b.totalXP end return a.id < b.id end)
    local orderKeys = {}
    local orderLoops = {}
    for _, s in ipairs(order) do orderKeys[#orderKeys + 1] = P.StopKey(s) orderLoops[#orderLoops + 1] = s.loop or 0 end
    local logSeen = {}
    for id, o in pairs(info) do if o.log then logSeen[id] = true end end
    -- feste Route: Taschen (fast) voll -> Haendler mit dem kleinsten Umweg auf dem Weg zum naechsten Schritt
    -- (Nutzer 23.11.2026: "volle Taschen beruecksichtigen"). Nur Hinweis, kein Routen-Schritt. Bis P.BAG_LOW freie
    -- Plaetze immer; davor (ctx.vendors gibt es ab G.VENDOR_BAGS) nur, wenn er praktisch am Weg liegt (P.VENDOR_NEAR)
    local vendorHint, dungeonHint, missedHint
    -- Umweg ueber Punkt w auf dem Weg zum naechsten Schritt (ohne naechsten Schritt: hin und zurueck)
    local nextW
    if ctx.route and here then
        for _, st in ipairs(steps) do
            nextW = st.mapID and st.x and World(nil, st.mapID, st.x, st.y)
            if nextW then break end
        end
    end
    local direct = nextW and nextW[1] == here[1] and Minutes(here, nextW)
    local function Detour(w)
        if direct and w[1] == here[1] then return Minutes(here, w) + Minutes(w, nextW) - direct end
        return 2 * Minutes(here, w)
    end
    if ctx.route and ctx.vendors and ctx.bags and here then
        local best, bd
        for _, sp in ipairs(Spots(ctx.vendors)) do
            local d = Detour(sp.w)
            if not bd or d < bd then best, bd = sp, d end
        end
        if best and (ctx.bags <= P.BAG_LOW or bd <= P.VENDOR_NEAR) then
            vendorHint = {name = best.name, mapID = best.mapID, x = best.x, y = best.y, id = best.id, detour = math.max(0, bd),
                free = ctx.bags, kind = ctx.bags <= 0 and "full" or ctx.bags <= P.BAG_LOW and "low" or "way"}
        end
    end
    -- feste Route: Dungeon-Quest oder Vorquest dorthin, deren Geber am Weg zum naechsten Schritt steht (Nutzer
    -- 23.11.2026: "den Hinweis bau mal"). Nur Hinweis, nie Routen-Schritt – Dungeons stehen absichtlich nicht im Guide.
    -- Nur annehmbare (Stufe, Vorquests, Volk/Klasse), nicht grau, nicht im Log, Umweg hoechstens P.DUNGEON_NEAR
    if ctx.route and here and me.mapID then
        local seen = {}
        for _, g in ipairs(P.DungeonGivers(me.mapID)) do
            local id, nr = g[1], g[2]
            local e = Q.q[id]
            local ok = e and not seen[id] and not inLog(id) and not (follow and follow["accept:" .. id])
                and (e[2] or 0) <= L and (e[1] or 0) >= P.GreyBelow(L) and Fits(id, e, me, done, inLog) and not P.IsDrop(e)
            if ok and type(e[9]) == "table" then for _, p in ipairs(e[9]) do if not done(p) then ok = false end end end
            if ok and type(e[5]) == "table" and #e[5] > 0 then
                local any = false
                for _, p in ipairs(e[5]) do if done(p) then any = true end end
                ok = any
            end
            local w = ok and World(nr)
            if w then
                seen[id] = true
                local d = Detour(w)
                if d <= P.DUNGEON_NEAR then
                    if not dungeonHint or d < dungeonHint.detour - .1 then
                        local m, x, y = w[4], w[5], w[6]
                        dungeonHint = {id = id, dungeon = P.IsDungeonChain(id), mapID = m, x = x, y = y, detour = math.max(0, d), more = dungeonHint and (dungeonHint.more + 1) or 0}
                    else dungeonHint.more = dungeonHint.more + 1 end
                end
            end
        end
    end
    -- feste Route: frueher ausgelassene Annahme, deren Geber am Weg steht (Nutzer 23.11.2026 "Ja, bauen") – nicht
    -- zurueckschicken, nur Hinweis. ctx.missed kommt aus Guide.RouteFollow (Rest der Quest liegt noch vor einem)
    if ctx.route and here and ctx.missed then
        for _, m in ipairs(ctx.missed) do
            local id = m.ahead ~= false and m.id
            local e = Q.q[id]
            local ok = e and not inLog(id) and not done(id) and (e[2] or 0) <= L and (e[1] or 0) >= P.GreyBelow(L)
                and Fits(id, e, me, done, inLog) and not (follow and follow["accept:" .. id])
            local w = ok and World(m.n)
            if w then
                local d = Detour(w)
                if d <= P.MISSED_NEAR then
                    if not missedHint or d < missedHint.detour - .1 then
                        missedHint = {id = id, mapID = w[4], x = w[5], y = w[6], detour = math.max(0, d), more = missedHint and (missedHint.more + 1) or 0}
                    else missedHint.more = missedHint.more + 1 end
                end
            end
        end
    end
    return {vendorHint = vendorHint, dungeonHint = dungeonHint, missedHint = missedHint, onWay = onWay, gearIn = gearIn, logSeen = logSeen, workZone = startWork, orderKeys = orderKeys, orderLoops = orderLoops, loops = loops, steps = steps, blocks = blocks, info = info, chosen = chosen, skipped = skipped, minutes = minutes, xp = xpSum, left = left, abandon = abandon,
        grind = grind, factor = factor, level = L}
end

-- ===== Gebietsuebersicht (0.7.0) – NUR Anzeige, aendert den Plan nicht =====
-- Je Gebiet (Karte des Questgebers): wie viele Quests fuer dich es gibt, wie viele erledigt sind,
-- und fuer jede offene: im Plan / im Log / ausgelassen (mit Grund) / gesperrt / spaeter.
-- Rueckgabe: {{mapID, total, done, plan, open, locked, low, quests = {{id, status, level, minLevel}}}, …}
-- status: "log" | "plan" | "skip" | "later" | "locked"
local STATUS_ORDER = {log = 1, plan = 2, skip = 3, later = 4, locked = 5}
function P:Zones(ctx, plan)
    local Q = P.Data()
    if not (Q and plan) then return {} end
    local me = ctx.me
    local L = me.level or 1
    local done = ctx.done or function() return false end
    local inLog = ctx.inLog or function() return false end
    local grey = P.GreyBelow(L)
    local zones, byMap = {}, {}
    for id, e in pairs(Q.q) do
        -- nur, was fuer Volk/Klasse ueberhaupt in Frage kommt
        local race, class = e[3], e[4]
        local ok = true
        if not P.RaceOK(race, me) then ok = false end
        if class > 0 and me.class and Band(class, me.class) == 0 then ok = false end
        local sortClass = P.CLASS_SORT[e[14] or 0]
        if sortClass and me.class and sortClass ~= me.class then ok = false end
        local giver = e[6] and e[6][1] or (e[7] and e[7][1])
        local mapID = ok and giver and P.NodePoint(Q, giver, nil)
        if mapID then
            local z = byMap[mapID]
            if not z then
                z = {mapID = mapID, total = 0, done = 0, plan = 0, open = 0, locked = 0, low = 0, quests = {}}
                byMap[mapID] = z
                zones[#zones + 1] = z
            end
            z.total = z.total + 1
            if done(id) then
                z.done = z.done + 1
            else
                local qlvl = e[1] > 0 and e[1] or L
                local status
                if inLog(id) then status = "log"
                elseif plan.chosen[id] then status = "plan"
                elseif plan.info[id] and plan.info[id].skip then status = "skip"
                elseif qlvl <= grey and qlvl > 0 then z.low = z.low + 1
                elseif not Fits(id, e, me, done, inLog) then status = "locked"
                elseif (e[2] or 0) > L then status = "locked"
                else status = "later" end
                -- weit ueber deiner Stufe: nicht auflisten (sonst ist die Liste endlos)
                if (status == "locked" or status == "later") and math.max(e[2] or 0, qlvl - 2) > L + 5 then status = nil end
                if status then
                    if status == "plan" or status == "log" then z.plan = z.plan + 1
                    elseif status == "locked" then z.locked = z.locked + 1
                    else z.open = z.open + 1 end
                    z.quests[#z.quests + 1] = {id = id, status = status, level = qlvl, minLevel = e[2] or 0}
                end
            end
        end
    end
    -- Gebiete ohne offene Quests fuer dich weglassen; aktuelles Gebiet zuerst, dann mit Plan, dann mit offenen
    local out = {}
    for _, z in ipairs(zones) do
        if z.plan + z.open > 0 or (z.mapID == me.mapID and #z.quests > 0) then
            table.sort(z.quests, function(a, b)
                if a.status ~= b.status then return STATUS_ORDER[a.status] < STATUS_ORDER[b.status] end
                if a.level ~= b.level then return a.level < b.level end
                return a.id < b.id
            end)
            out[#out + 1] = z
        end
    end
    table.sort(out, function(a, b)
        local ha, hb = a.mapID == me.mapID, b.mapID == me.mapID
        if ha ~= hb then return ha end
        if a.plan ~= b.plan then return a.plan > b.plan end
        if a.open ~= b.open then return a.open > b.open end
        return a.mapID < b.mapID
    end)
    return out
end

function P.StopKey(s)
    if s.kind == "dungeon" then return "d:" .. tostring(s.key) end
    if s.kind == "train" and s.group then return "train:" .. s.group .. ":" .. tostring(s.lvl) end
    if s.kind == "train" or s.kind == "grind" then return s.kind .. ":" .. tostring(s.lvl) end
    if s.kind == "bind" then return "bind:" .. tostring(s.inn) end
    return s.kind .. ":" .. tostring(s.id)
end

-- Text fuer "ausgelassen" mit Zahlen
function P.SkipText(o, plan, tr)
    if not o.skip then return nil end
    tr = tr or function(text, ...) if select("#", ...) > 0 then return text:format(...) end return text end
    if o.skip:find("%%d") then return tr(o.skip, math.floor(o.epm + .5), math.floor(plan.grind * math.max(plan.factor, .01) + .5)) end
    return tr(o.skip)
end
