-- Offline-Test: Quest-Fuehrung mit Schleifen um Stuetzpunkte (Nutzer 21.11.2026 "bau das", nach dem Spieltest-Abend
-- 20.11.: der gierige "naechste Punkt" schickte kreuz und quer). Am Stuetzpunkt annehmen, die Ziele einer Gegend am
-- Stueck, zurueck abgeben; Quests weit ab der Runde nicht; vor dem Gebietswechsel Fertiges abgeben; Haendler nur am
-- Stuetzpunkt, wenn die Taschen (bald) voll sind; Runde im Mouseover.
local root = arg[1] or "src"
local function Fresh()
    GuildTripQuestDB = {
        q = {
            -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
            [1] = {12, 8, 0, 0, false, {11}, {11}, {21}, false, false, 1100, 0, 0, 1},   -- Stuetzpunkt, Ziel Suedost
            [2] = {12, 8, 0, 0, false, {12}, {12}, {22}, false, false, 1100, 0, 0, 1},   -- Stuetzpunkt, Ziel Suedost
            [3] = {12, 8, 0, 0, false, {13}, {11}, {23}, false, false, 1100, 0, 0, 1},   -- Stuetzpunkt, Ziel Suedost
            [4] = {12, 8, 0, 0, false, {11}, {11}, {24}, false, false, 400, 0, 0, 1},    -- Stuetzpunkt, Ziel ganz weit weg
        },
        n = {
            [11] = {0, 1, 100, 100}, [12] = {0, 1, 102, 100}, [13] = {0, 1, 100, 103},   -- Stuetzpunkt (1000, 1000 yd)
            [21] = {0, 1, 140, 130}, [22] = {0, 1, 145, 125}, [23] = {0, 1, 150, 135},   -- Gegend 500 yd weg
            [24] = {0, 1, 900, 900},                                                     -- 11000 yd weg
        },
    }
end
Fresh()
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local function World(m, x, y) return 1, (m - 1) * 10000 + x * 10000, y * 10000 end
local log, doneSet = {}, {}
local function Ctx(extra)
    local c = {me = {level = 12, class = 1, faction = "Horde", mapID = 1, x = .1, y = .1},
        done = function(id) return doneSet[id] == true end, inLog = function(id) return log[id] ~= nil end,
        complete = function(id) return log[id] == "done" end, world = World, tempo = "need", speed = 7}
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local function Order(plan)
    local t = {}
    for _, s in ipairs(plan.steps) do
        if #s.actions == 0 then t[#t + 1] = s.kind end
        for _, a in ipairs(s.actions) do t[#t + 1] = a.kind:sub(1, 1) .. a.id end
    end
    return table.concat(t, " ")
end
local function Pos(o, tok) local i = (" " .. o .. " "):find(" " .. tok .. " ", 1, true) return i end

-- 1) Eine Schleife: alle drei am Stuetzpunkt annehmen, Ziele am Stueck, dann abgeben; Quest 4 (Ziel 11000 yd weg) nicht
do
    local plan = assert(P:Plan(Ctx()))
    local o = Order(plan)
    for id = 1, 3 do assert(plan.chosen[id], "Quest " .. id .. " in der Schleife: " .. o) end
    assert(not plan.chosen[4], "einzelne Quest weit weg: nicht dabei")
    assert(plan.info[4].skip, "mit Grund ausgelassen")
    local lastAccept, firstObj, lastObj, firstTurn = 0, 1e9, 0, 1e9
    for id = 1, 3 do
        lastAccept = math.max(lastAccept, Pos(o, "a" .. id))
        firstObj, lastObj = math.min(firstObj, Pos(o, "o" .. id)), math.max(lastObj, Pos(o, "o" .. id))
        firstTurn = math.min(firstTurn, Pos(o, "t" .. id))
    end
    assert(lastAccept < firstObj and lastObj < firstTurn, "annehmen -> Ziele am Stueck -> abgeben: " .. o)
    -- alle Halte dieser Schleife tragen dieselbe Runde
    local loop
    for _, s in ipairs(plan.steps) do
        if s.kind ~= "travel" then loop = loop or s.loop assert(s.loop == loop, "eine Runde: " .. tostring(s.loop)) end
    end
    assert(loop == 1 and plan.loops[1] and plan.loops[1].epm > 0, "Runde 1 mit EP/min")
    assert(#plan.orderLoops == #plan.orderKeys, "Runde je Halt fuer den Fahrplan")
end

-- 2) Aufwaendige Quest (viele Gegner) nur, wenn sie die Schleife nicht bremst
do
    GuildTripLeveling.r = {}
    local plan = assert(P:Plan(Ctx()))
    assert(plan.chosen[1], "ohne Aufwand dabei")
end

-- 3) Vor dem Gebietswechsel alles Fertige hier abgeben (sonst geht es spaeter extra zurueck)
do
    Fresh()
    -- fertige Quest im Log, Abgabe 3 min weg im eigenen Gebiet; in Gebiet 2 eine viel bessere Schleife
    GuildTripQuestDB.q[5] = {12, 8, 0, 0, false, {15}, {15}, {}, false, false, 900, 0, 0, 1}
    GuildTripQuestDB.n[15] = {0, 1, 880, 100}   -- 700 yd hinter mir (gut 2 min)
    for id = 6, 9 do
        GuildTripQuestDB.q[id] = {12, 8, 0, 0, false, {30}, {30}, {}, false, false, 3000, 0, 0, 2}
    end
    GuildTripQuestDB.n[30] = {0, 2, 5, 10}
    for id = 1, 4 do GuildTripQuestDB.q[id] = nil end
    log[5] = "done"
    local plan = assert(P:Plan(Ctx({me = {level = 12, class = 1, faction = "Horde", mapID = 1, x = .95, y = .1}})))
    local o = Order(plan)
    local t5, a6 = Pos(o, "t5"), Pos(o, "a6")
    assert(t5 and a6 and t5 < a6, "erst fertige Quest im Gebiet abgeben, dann wechseln: " .. o)
    log[5] = nil
end

-- 4) Haendler (Nutzer 21.11.2026): nur am Stuetzpunkt, wenn die Taschen (bald) voll sind – nie als eigener Weg
do
    Fresh()
    local vendors = {{mapID = 1, x = .101, y = .101, name = "Haendlerin", id = 77}}
    local full = assert(P:Plan(Ctx({bags = 2, vendors = vendors})))
    local o = Order(full)
    local v = Pos(o, "vendor")
    assert(v, "Taschen fast voll: Haendler im Plan: " .. o)
    assert(v < Pos(o, "o1") and v < Pos(o, "o2"), "Haendler am Stuetzpunkt vor dem Losgehen: " .. o)
    local vs
    for _, s in ipairs(full.steps) do if s.kind == "vendor" then vs = s end end
    assert(vs.name == "Haendlerin" and vs.mapID == 1 and vs.stopKey == "vendor:0", "Haendler-Schritt mit Ort und Name")
    -- genug Platz: kein Haendler
    assert(not Pos(Order(assert(P:Plan(Ctx({bags = 30, vendors = vendors})))), "vendor"), "genug Platz: kein Haendler")
    -- Haendler weit weg vom Stuetzpunkt: kein Umweg
    local far = {{mapID = 1, x = .5, y = .5, name = "weit"}}
    assert(not Pos(Order(assert(P:Plan(Ctx({bags = 1, vendors = far})))), "vendor"), "Haendler weit weg: kein Umweg")
    -- kaputte Ausruestung allein: kein Haendler (Nutzer 21.11.2026: "nur Taschen")
    assert(not Pos(Order(assert(P:Plan(Ctx({bags = 20, durability = .1, vendors = vendors})))), "vendor"), "nur Taschen")
end

-- 5) Fahrplan: Runden-Nummern bleiben beim Folgen erhalten (Anzeige "Runde 1")
do
    Fresh()
    local p1 = assert(P:Plan(Ctx()))
    local f, fl = {}, {}
    for i, k in ipairs(p1.orderKeys) do if not f[k] then f[k], fl[k] = i, p1.orderLoops[i] end end
    local p2 = assert(P:Plan(Ctx({follow = f, followLoops = fl})))
    assert(table.concat(p2.orderKeys, " ") == table.concat(p1.orderKeys, " "), "gleicher Fahrplan: " .. table.concat(p2.orderKeys, " ") .. " / " .. table.concat(p1.orderKeys, " "))
    for i = 1, #p2.orderKeys do assert(p2.orderLoops[i] == p1.orderLoops[i], "gleiche Runde je Halt") end
end

-- 5a) Fahrplan unterwegs: Monster fuer eine Quest, die schon im Log war, ziehen den Plan nicht um (Spieltest
-- 21.11.2026: Orgrimmar -> Zeppelin, am Turm ploetzlich "Verborgene Feinde"); kurzes Abgeben am Weg schon; neu
-- angenommen: einmal an der guenstigsten Stelle in den Fahrplan, danach fest
do
    Fresh()
    local Q = GuildTripQuestDB
    Q.q[5] = {12, 8, 0, 0, false, {11}, {11}, {26}, false, false, 900, 0, 0, 1}   -- im Log, Monster gleich hier
    Q.q[6] = {12, 8, 0, 0, false, {11}, {14}, {}, false, false, 900, 0, 0, 1}     -- im Log fertig, Abgabe gleich hier
    Q.n[26], Q.n[14] = {0, 1, 305, 705}, {0, 1, 302, 701}
    GuildTripLeveling.r[5] = "0|12|0||"
    log = {[4] = "open", [5] = "open"}
    local follow, fl = {["obj:4"] = 1, ["turnin:4"] = 2}, {["obj:4"] = 1, ["turnin:4"] = 1}
    local function At(prevLog)
        local c = Ctx({follow = follow, followLoops = fl, prevLog = prevLog})
        c.me.x, c.me.y = .3, .7
        return assert(P:Plan(c))
    end
    local p = At({[4] = true, [5] = true})
    assert(p.orderKeys[1] == "obj:4", "Monster am Weg (schon im Log): alter Plan bleibt, nicht " .. tostring(p.orderKeys[1]))
    log[6] = "done"
    p = At({[4] = true, [5] = true, [6] = true})
    assert(p.orderKeys[1] == "turnin:6", "Abgabe direkt am Weg: mitnehmen, nicht " .. tostring(p.orderKeys[1]))
    assert(p.orderKeys[2] == "obj:4", "danach weiter wie geplant: " .. table.concat(p.orderKeys, " "))
    assert(p.steps[1].onWay and not p.steps[2].onWay, "am Weg vorgezogen: markiert (Grund im Mouseover)")
    -- naechste Planung (jetzt steht es im Fahrplan): Markierung bleibt, bis es erledigt ist
    do
        local f3, fl3 = {}, {}
        for i, k in ipairs(p.orderKeys) do if not f3[k] then f3[k], fl3[k] = i, p.orderLoops[i] end end
        local c = Ctx({follow = f3, followLoops = fl3, prevLog = {[4] = true, [5] = true, [6] = true}, onWay = p.onWay})
        c.me.x, c.me.y = .3, .7
        local p3 = assert(P:Plan(c))
        assert(p3.orderKeys[1] == "turnin:6" and p3.steps[1].onWay, "Markierung bleibt")
    end
    log[6] = nil
    -- gerade angenommen: gleich hier einreihen (kostet hier kaum Umweg), danach steht es im Fahrplan
    p = At({[4] = true})
    assert(p.orderKeys[1] == "obj:5", "neu im Log, Ziel hier: gleich einreihen: " .. table.concat(p.orderKeys, " "))
    local f2 = {}
    for i, k in ipairs(p.orderKeys) do if not f2[k] then f2[k] = i end end
    assert(f2["turnin:5"] and f2["turnin:5"] > f2["obj:5"], "Abgabe auch im Fahrplan")
    GuildTripLeveling.r[5] = nil
    log = {}
end

-- 5c) Gleiche Gegner fuer zwei Quests: ein Schritt mit beiden Zielen, danach zusammen abgeben (Spieltest 21.11.2026
-- Tirisfal: "Remnants of War" und "The Cult of the Damned" – geplant war A, abgeben, wieder raus fuer B)
do
    Fresh()
    GuildTripQuestDB.q[7] = {12, 8, 0, 0, false, {11}, {11}, {21}, false, false, 1100, 0, 0, 1}
    local plan = assert(P:Plan(Ctx()))
    local both
    for _, st in ipairs(plan.steps) do
        if st.kind == "obj" then
            local ids = {}
            for _, a in ipairs(st.actions) do ids[a.id] = true end
            if ids[1] and ids[7] then both = true end
            assert(not (ids[1] or ids[7]) or (ids[1] and ids[7]), "Quest 1 und 7 nicht getrennt: " .. Order(plan))
        end
    end
    assert(both, "ein Schritt mit beiden Zielen: " .. Order(plan))
    Fresh()
end

-- 5b) Beruf noetig (Spieltest 21.11.2026: Kamari "Bestien des Donnergrats" nur fuer Lederverarbeiter)
do
    local e = {10, 6, 178, 0, false, {11}, {11}, {}, false, false, 840, 0, 0, 14, {165, 1}}
    local never = function() return false end
    assert(not P.Fits(1, e, {level = 15, faction = "Horde"}, never, never), "Berufe unbekannt: nicht")
    assert(not P.Fits(1, e, {level = 15, faction = "Horde", skills = {[197] = 50}}, never, never), "anderer Beruf: nicht")
    assert(P.Fits(1, e, {level = 15, faction = "Horde", skills = {[165] = 1}}, never, never), "Lederverarbeiter: ja")
    e[15] = {165, 50}
    assert(not P.Fits(1, e, {level = 15, faction = "Horde", skills = {[165] = 20}}, never, never), "Wert zu klein: nicht")
end

-- 6) Kasten: nur der naechste Schritt; Erklaerung (Runde, Ziele, Abgabe) nur im Mouseover
do
    GetLocale = function() return "deDE" end
    local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
    CreateFrame = function() return Stub() end
    UIParent = Stub()
    local ONE = {db = {}, modules = {}, ns = {}}
    _G.ProjectONE = ONE
    local L2 = {}
    assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", L2)
    assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", L2)
    assert(loadfile(root .. "/ONE_Leveling/Tracker.lua"))("ONE_Leveling", L2)
    local G, Tr = L2.Guide, L2.Tracker
    Fresh()
    local plan = assert(L2.Planner:Plan(Ctx()))
    local tip = Tr.StepTip(plan, 1)
    assert(tip and tip:find("Runde 1: noch 3 Ziele, dann 3 Abgaben", 1, true), "Mouseover zeigt die Runde: " .. tostring(tip))
    -- im Kasten (zweite Zeile) steht keine Erklaerung
    local who = Tr.NowWho(plan.steps[1]) or ""
    assert(not who:find("Runde"), "Erklaerung nur im Mouseover: " .. who)
    -- Haendler-Text
    local vs = {kind = "vendor", name = "Haendlerin", actions = {}}
    assert(G:StepText(vs):find("Händler: Taschen leeren", 1, true) and G:StepWho(vs):find("Haendlerin"))
    assert(Tr.StepTip({steps = {vs}}, 1):find("Verkaufen machst du selbst"), "nichts automatisch")
    assert(Tr.StepTip({steps = {{kind = "turnin", onWay = true, actions = {}}}}, 1):find("Liegt am Weg"), "Grund: am Weg")
    -- mehrere Quests an einem Ort (wie RestedXP): je Teilziel eine Zeile, Quest rechts, kein grosser Titel;
    -- mehrere Abgaben beim selben NPC: "Abgeben bei X", Quests darunter (Nutzer 21.11.2026 "bau das")
    do
        GuildTripQuestDB.names = {[11] = "Dillinger"}
        local objs0 = Tr.Objectives
        Tr.Objectives = function(id)
            if id == 1 then return {{text = "Kristalle: 3/8"}} end
            return {{text = "Kultisten: 2/6"}, {text = "Akolythen: 4/4", done = true}}
        end
        local o = {kind = "obj", actions = {{kind = "obj", id = 1}, {kind = "obj", id = 2}}, mapID = 1, x = .1, y = .1}
        local t = {kind = "turnin", nr = 11, actions = {{kind = "turnin", id = 1}, {kind = "turnin", id = 2}}, mapID = 1, x = .1, y = .1}
        local rows = Tr:Rows({steps = {o, t}})
        local n2, big, nextTitle, nextWho = 0, false, nil, nil
        for k, r in ipairs(rows) do
            if r.kind == "obj2" then
                n2 = n2 + 1
                assert(r.right and r.nav and r.nav.qid, "Quest rechts, Zeile gehoert zu einer Quest")
                assert(#Tr.QuestIDs(r.nav) == 1, "Rechtsklick waehlt nur diese Quest ab")
            end
            if r.kind == "now" then big = true end
            if r.kind == "nxTitle" then nextTitle, nextWho = r.text, rows[k + 1] and rows[k + 1].text end
        end
        assert(n2 == 3 and not big, "drei Teilziel-Zeilen, kein grosser Titel")
        assert(nextTitle and nextTitle:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):find("Dillinger: abgeben", 1, true), "NPC zuerst, dann abgeben: " .. tostring(nextTitle))
        assert(nextWho and not nextWho:find("Dillinger", 1, true), "darunter die Quests: " .. tostring(nextWho))
        Tr.Objectives = objs0
        GuildTripQuestDB.names = nil
    end
    -- Fahrplan mit Runden wird gemerkt
    assert(G.FollowLoops(plan)[plan.orderKeys[1]] == 1)
    -- alter Fahrplan (ohne Runden, vom gierigen Planer) wird nach dem Update nicht weitergefahren
    ONE.db.leveling = {follow = {["?"] = {keys = {"accept:4"}, t = 0}}}
    G.DB = function() return ONE.db.leveling end
    G.Available = function() return true end
    G.Context = function() local c = Ctx() c.override = ONE.db.leveling.override return c end
    G.plan, G.fresh = nil, false
    local seen
    local plan0 = L2.Planner.Plan
    L2.Planner.Plan = function(self, c) seen = c.follow return plan0(self, c) end
    assert(G:Replan(true) and seen == nil, "alter Fahrplan (ohne Runden) wird nicht weitergefahren")
    ONE.db.leveling.follow["?"] = {keys = {"accept:3", "accept:1"}, loops = {1, 1}, t = 0}
    G.plan = nil
    assert(G:Replan(true) and seen and seen["accept:3"] == 1, "neuer Fahrplan (mit Runden) wird weitergefahren")
    L2.Planner.Plan = plan0
    -- Abwaehlen direkt im Kasten (Nutzer 21.11.2026): Rechtsklick -> Rueckfrage, erst nach Ja abgewaehlt
    assert(#Tr.QuestIDs({step = plan.steps[1]}) > 0 and #Tr.QuestIDs({qid = 7}) == 1 and #Tr.QuestIDs(nil) == 0)
    local shown
    StaticPopupDialogs, StaticPopup_Show = {}, function(name) shown = name end
    ONE.db.leveling.override = {}
    local id1 = plan.steps[1].actions[1].id
    assert(G:AskSkip({id1, id1}) and shown == "GUILDTRIP_SKIP", "Rueckfrage")
    assert(ONE.db.leveling.override[id1] == nil, "ohne Ja nichts abgewaehlt")
    assert(StaticPopupDialogs.GUILDTRIP_SKIP.text:find("Quest abwählen?", 1, true), "eine Quest (doppelt gezaehlt nur einmal)")
    StaticPopupDialogs.GUILDTRIP_SKIP.OnAccept()
    assert(ONE.db.leveling.override[id1] == "no" and G.plan and not G.plan.chosen[id1], "nach Ja abgewaehlt und neu geplant")
    StaticPopupDialogs, StaticPopup_Show = nil, nil
    assert(G:AskSkip({id1}) == false, "ohne Rueckfrage-Fenster nie abwaehlen")
    ONE.db.leveling.override = {}
    -- Ruhestein gesetzt, aber keine Spielmeldung / kein Ruhestein unter der bekannten Nummer (Spieltest 21.11.2026:
    -- "Ruhestein setzen" blieb stehen): Bindeort = Ort hier -> gilt als gebunden, Heimatort bekannt
    assert(loadfile(root .. "/ONE_Leveling/Inns.lua"))("ONE_Leveling", L2)
    assert(loadfile(root .. "/ONE_Leveling/Hearth.lua"))("ONE_Leveling", L2)
    local inn = L2.INNS[1]
    ONE.ns.nav = {Travel = {PlayerWorld = function() return inn[2], inn[3] + 5, inn[4] end}}
    UnitName = function() return "Testheld" end
    GetBindLocation = function() return "Testdorf" end
    GetSubZoneText = function() return "Testdorf" end
    GetItemCount = function() return 0 end
    local home, cd = G.HearthState()
    assert(home and home.inn == inn[1] and home.place == "Testdorf" and cd == nil, "gebunden erkannt, ohne Ruhestein-Reise")
    GetBindLocation, GetSubZoneText, GetItemCount, UnitName = nil, nil, nil, nil
    -- freie Taschenplaetze aus dem Spiel (nur Zahlen, Fehler egal)
    C_Container = {GetContainerNumFreeSlots = function(bag) if bag == 0 then return 3, 0 elseif bag == 1 then return 5, 8 end return 0, 0 end}
    assert(G.FreeBagSlots() == 3, "Spezialtaschen (Munition, Seelen) zaehlen nicht")
    C_Container = nil
    -- Berufe aus der Fertigkeitenliste (Kopfzeilen zaehlen nicht)
    GetNumSkillLines = function() return 3 end
    GetSkillLineInfo = function(i)
        if i == 1 then return "Berufe", true end
        if i == 2 then return "Lederverarbeitung", false, false, 42 end
        return "Kürschnerei", false, false, 30
    end
    local sk = G.Skills()
    assert(sk[165] == 42 and sk[393] == 30, "Berufe erkannt")
    GetNumSkillLines, GetSkillLineInfo = nil, nil
end
print("OK test_schleifen_144")
