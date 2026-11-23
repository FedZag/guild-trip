-- Offline-Test: feste Route (Neubau 21.11.2026, Nutzer: "bau es wie bei RestedXP"). Im Spiel wird nichts mehr
-- umgerechnet: die vorab gerechnete Route ist der Fahrplan. Erledigtes faellt weg, zu niedrige Annehmen-Schritte
-- (man ist voraus) werden uebersprungen, fehlt die Stufe, kommt "Monster hauen bis X" vor den naechsten Schritt,
-- Quests im Log ausserhalb der Route stehen als "Nicht im Plan".
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
local ONE = {db = {}, modules = {}, ns = {}}
_G.ProjectONE = ONE
GuildTripQuestDB = {
    q = {
        -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
        [1] = {10, 8, 0, 0, false, {11}, {11}, {21}, false, false, 900, 0, 0, 1},
        [2] = {10, 8, 0, 0, false, {12}, {12}, {22}, false, false, 900, 0, 0, 1},
        [3] = {12, 12, 0, 0, false, {13}, {13}, {23}, false, false, 900, 0, 0, 1},  -- braucht Stufe 12
        [4] = {5, 3, 0, 0, false, {14}, {14}, {}, false, false, 300, 0, 0, 1},      -- weit unter der Stufe (Route sagt 5)
        [9] = {10, 8, 0, 0, false, {11}, {11}, {}, false, false, 500, 0, 0, 1},     -- im Log, nicht in der Route
        [40] = {10, 8, 0, 0, {999}, {12}, {12}, {}, false, false, 900, 0, 0, 1},  -- Vorquest 999 ohne Daten (Gegenstand-Start)
        [41] = {10, 8, 0, 0, false, {}, {12}, {22}, false, false, 900, 0, 0, 1, false, 5000}, -- Start durch Drop (Feld 16)
        [42] = {10, 8, 0, 0, false, {14}, {12}, {}, false, false, 900, 0, 0, 1, false, 6000}, -- Start durch Fund an fester Stelle
        [30] = {18, 15, 0, 0, false, {11}, {11}, {}, false, false, 900, 0, 0, 77},  -- Dungeonquest (Gebiet 77 = Dungeon)
        [31] = {16, 14, 0, 0, false, {11}, {11}, {}, false, false, 500, 30, 0, 1},  -- Vorquest dorthin (wie "Hamuul Runetotem")
        [32] = {16, 14, 0, 0, false, {11}, {11}, {}, false, false, 500, 33, 0, 1},  -- lange Weltreihe: erst spaeter im Dungeon
        [33] = {18, 14, 0, 0, {32}, {11}, {11}, {}, false, false, 500, 30, 0, 1},
    },
    n = {
        [11] = {0, 1, 100, 100}, [12] = {0, 1, 300, 100}, [13] = {0, 1, 500, 100}, [14] = {0, 1, 100, 300},
        [21] = {0, 1, 150, 150}, [22] = {0, 1, 350, 150}, [23] = {0, 1, 550, 150},
    },
}
GuildTripLeveling = {r = {}, i = {}, dz = {[77] = "wc"}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Guide.lua"))("ONE_Leveling", lev)
assert(loadfile(root .. "/ONE_Leveling/Tracker.lua"))("ONE_Leveling", lev)
local P, G, Tr = lev.Planner, lev.Guide, lev.Tracker
local function World(m, x, y) return 1, x * 10000, y * 10000 end

-- Route: zuerst 2 (obwohl 1 naeher waere), dann 1, dann 3 (Stufe 12), Quest 4 ganz am Anfang mit Stufe 5
local route = {
    {"a4", n = 14, l = 5}, {"t4", n = 14, l = 5},
    {"a2 a40", n = 12, l = 10}, {"t40", n = 12, l = 10}, {"o2", n = 22, l = 10}, {"t2", n = 12, l = 10},
    {"a1", n = 11, l = 10}, {"o1", n = 21, l = 10}, {"t1", n = 11, l = 10},
    {"a3", n = 13, l = 12}, {"o3", n = 23, l = 12}, {"t3", n = 13, l = 12},
}
GuildTripQuestRoutes = {["16:128"] = route}

-- 1) Route finden (auch fuer eine andere Klasse desselben Volks)
assert(G.Route(16, 128) == route and G.Route(16, 1) == route and G.Route(2, 1) == nil, "Route je Volk:Klasse")
do -- Forever-Paare ohne eigene Route (Spieltest 23.11.2026: Orc-Magier) – fester Ersatz, kein Zufall
    local old = GuildTripQuestRoutes
    local trollMage, orcWar, orcSham, udMage = {}, {}, {}, {}
    GuildTripQuestRoutes = {["128:128"] = trollMage, ["2:1"] = orcWar, ["2:64"] = orcSham, ["16:128"] = udMage}
    assert(G.Route(2, 128) == trollMage, "Orc-Magier -> Troll-Magier (gleiches Startgebiet)")
    assert(G.Route(2, 1024) == orcWar, "Orc-Druide -> Orc-Route mit kleinster Klassen-Maske")
    assert(G.Route(32, 128) == trollMage, "Tauren-Magier ohne Tauren-Route -> Magier derselben Fraktion (fest sortiert)")
    -- Himmelsgeborene (Volk unbekannt): Horde -> Tauren-Route (Zeppelin nach Donnerfels), sonst Orc/Troll gleiche Klasse
    local taurDru, orcRogue, elfDru, gnomeMage = {}, {}, {}, {}
    GuildTripQuestRoutes = {["32:1024"] = taurDru, ["2:8"] = orcRogue, ["8:1024"] = elfDru, ["64:128"] = gnomeMage}
    assert(G.Route(nil, 1024, "Horde") == taurDru, "Windformer-Druide -> Tauren-Druide")
    assert(G.Route(nil, 8, "Horde") == orcRogue, "Windformer-Schurke -> Orc-Schurke (Tauren haben keine)")
    assert(G.Route(nil, 1024, "Alliance") == elfDru, "Hohe-Ordnung-Druide -> Nachtelf-Druide")
    assert(G.Route(nil, 128, "Alliance") == gnomeMage, "Hohe-Ordnung-Magier -> Gnom-Magier")
    assert(G.Route(nil, 1024) == nil, "unbekanntes Volk ohne Fraktion: keine Route")
    GuildTripQuestRoutes = old
end
do -- Himmelsgeborene: nur Quests der ganzen Fraktion, keine Volks-Quests (z. B. nur Tauren)
    local sky = {sky = true, faction = "Horde"}
    assert(P.RaceOK(178, sky) and P.RaceOK(0, sky) and P.RaceOK(255, sky), "Fraktions-Quest passt")
    assert(not P.RaceOK(32, sky) and not P.RaceOK(130, sky), "Volks-Quest passt nicht")
    assert(P.RaceOK(32, {faction = "Horde"}), "ohne sky wie bisher: Fraktion reicht")
    assert(P.RaceOK(32, {race = 32, faction = "Horde"}) and not P.RaceOK(2, {race = 32, faction = "Horde"}), "bekanntes Volk")
end

-- 2) Fahrplan: Raenge in Routen-Reihenfolge; Annehmen weit unter der eigenen Stufe (voraus) faellt weg
local log = {}
local f = G.RouteFollow(route, 10, function(id) return log[id] ~= nil end)
assert(not f["accept:4"], "Stufe-5-Quest mit Stufe 10: uebersprungen")
assert(f["accept:2"] < f["obj:2"] and f["turnin:2"] < f["accept:1"] and f["accept:1"] < f["accept:3"], "Reihenfolge der Route")
-- schon angenommen: bleibt drin, auch wenn sie zu niedrig ist
log[4] = "open"
assert(G.RouteFollow(route, 10, function(id) return log[id] ~= nil end)["accept:4"], "im Log: bleibt in der Route")
log = {}

-- 3) Planer folgt der Route (nicht der kuerzesten Reihenfolge), plant nichts Eigenes dazu
local doneSet = {}
local function Ctx(level, xp)
    return {me = {level = level, xp = xp or 0, xpMax = 10000, class = 128, race = 16, faction = "Horde", mapID = 1, x = .9, y = .9},
        done = function(id) return doneSet[id] == true end, inLog = function(id) return log[id] ~= nil end,
        complete = function(id) return log[id] == "done" end, world = World, tempo = "need", speed = 7,
        route = true, flow = true, follow = G.RouteFollow(route, level, function(id) return log[id] ~= nil end)}
end
local plan = assert(P:Plan(Ctx(10)))
local keys = table.concat(plan.orderKeys, " ")
assert(plan.orderKeys[1] == "accept:2", "erster Routen-Schritt zuerst (nicht der naechste Ort): " .. keys)
assert(keys:find("accept:2.-turnin:2.-accept:1", 1), "Reihenfolge wie in der Route: " .. keys)
assert(not keys:find("accept:9", 1, true), "nichts ausserhalb der Route: " .. keys)
-- Vorquest ohne Daten (Spieltest 22.11.2026: "Chens leeres Faesschen" 821 braucht 819, Start durch einen Fund):
-- der NPC bietet die Quest nicht an, also nicht hinschicken – erst wenn 999 wirklich erledigt ist
assert(not keys:find("accept:40", 1, true), "Quest mit fehlender Vorquest nicht im Plan: " .. keys)
doneSet[999] = true
assert(table.concat(P:Plan(Ctx(10)).orderKeys, " "):find("accept:40", 1, true), "Vorquest erledigt: dann schon")
doneSet[999] = nil

-- 3b) Quest-Drops (Nutzer 22.11.2026: "einbauen, wenn man sie sammelt und aktiviert, wenn es gut in den Plan passt"):
-- nicht im Log -> nie geplant; im Log -> passend eingebaut (Ziel bei Quest 2, Abgabe bei NPC 12) und nicht "Nicht im Plan"
assert(not keys:find(":41", 1, true), "Drop-Quest ohne Gegenstand nicht im Plan: " .. keys)
log[41] = "open"
local pd = assert(P:Plan(Ctx(10)))
local kd = table.concat(pd.orderKeys, " ")
assert(kd:find("obj:41", 1, true) and kd:find("turnin:41", 1, true), "Drop-Quest im Log eingebaut: " .. kd)
assert(kd:find("accept:2", 1, true) < kd:find("obj:41", 1, true), "an passender Stelle, nicht vor allem anderen: " .. kd)
assert(#G.OffRoute(G.RouteFollow(route, 10), {41}, pd) == 0, "eingebaut = nicht 'Nicht im Plan'")
assert(#G.OffRoute(G.RouteFollow(route, 10), {41}) == 1, "ohne Plan schon")
log[41] = nil
assert(P.IsDrop(GuildTripQuestDB.q[41]) and not P.IsDrop(GuildTripQuestDB.q[42]) and not P.IsDrop(GuildTripQuestDB.q[1]), "Drop vs. Fundstelle")
G.NodeName = function(nr) return nr == 14 and "Chens leeres Fässchen" or "NPC" end
local who = Tr.NowWhoBase({kind = "accept", nr = 14, actions = {{kind = "accept", id = 42}}})
assert(who == "Chens leeres Fässchen aufheben, im Rucksack anklicken", "Text fuer Fundstelle: " .. tostring(who))
local normal = Tr.NowWhoBase({kind = "accept", nr = 14, actions = {{kind = "accept", id = 1}}})
assert(normal:find("|c%x%x%x%x%x%x%x%xChens leeres Fässchen|r$"), "Questgeber farbig: " .. normal)
assert(normal:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") == "annehmen bei Chens leeres Fässchen", "normal")

-- 3c) Standort beim NPC eines viel spaeteren Routen-Halts (Spieltest 22.11.2026: zum Einkaufen kurz nach Crossroads,
-- Guide schwenkte auf die Quests dort um): Reihenfolge bleibt, nichts von weit hinten vorziehen
do
    local c = Ctx(10)
    c.me.x, c.me.y = .1, .1   -- genau bei NPC 11 (Quest 1, kommt in der Route erst nach Quest 2)
    local k3 = table.concat(P:Plan(c).orderKeys, " ")
    assert(k3:find("^accept:2"), "Route bleibt bei ihrem naechsten Schritt: " .. k3)
end

-- 4) Stufe fehlt fuer den naechsten Routen-Schritt: erst Monster hauen bis 12, dann weiter in der Route
doneSet = {[1] = true, [2] = true, [4] = true}
local plan2 = assert(P:Plan(Ctx(11, 9000)))
assert(plan2.steps[1].kind == "grind" and plan2.steps[1].lvl == 12, "erst Monster hauen bis Stufe 12: " .. tostring(plan2.steps[1].kind))
local after = plan2.steps[2] and plan2.steps[2].actions and plan2.steps[2].actions[1]
assert(after and after.kind == "accept" and after.id == 3, "danach der naechste Routen-Schritt")
doneSet = {}

-- 5) Quests im Log, die nicht zur Route gehoeren
local off = G.OffRoute(G.RouteFollow(route, 10), {1, 9})
assert(#off == 1 and off[1].id == 9, "nur Quest 9 ist nicht im Plan")
-- Dungeonquests und ihre direkte Vorquest nie "Nicht im Plan" (Nutzer 22.11.2026, Spieltest: "Hamuul Runetotem, Devi…"),
-- eine lange Weltreihe, die erst viel spaeter in einen Dungeon fuehrt, schon
off = G.OffRoute(G.RouteFollow(route, 10), {9, 30, 31, 32})
assert(#off == 2 and off[1].id == 9 and off[2].id == 32, "Dungeonquest + Vorquest nicht als 'Nicht im Plan': " .. #off)
off = G.OffRoute(G.RouteFollow(route, 10), {1, 9})
-- Kasten zeigt sie als eigene Zeile
G.DB = function() return {} end
local rows = Tr:Rows({steps = plan.steps, offRoute = off})
local hit
local iLabel, iNext
for i, r in ipairs(rows) do
    if r.off == 9 then hit = r end
    if r.text == "NICHT IM PLAN" then iLabel = i end
    if r.text == "ALS NÄCHSTES" then iNext = i end
end
assert(hit and hit.click and hit.menu, "Zeile 'Nicht im Plan': Klick + Rechtsklick-Menue")
-- eigener Abschnitt ganz unten (Nutzer 23.11.2026), nach ALS NAECHSTES
assert(iLabel and (not iNext or iLabel > iNext) and rows[#rows].off, "NICHT IM PLAN ganz unten")
do -- alle Quests einzeln, ab 7 mit "(+n)"
    local many = {}
    for k = 1, 8 do many[k] = {id = 100 + k} end
    local n, plus = 0, nil
    for _, r in ipairs(Tr:Rows({steps = plan.steps, offRoute = many})) do
        if r.off then n = n + 1 end
        if r.text and r.text:find("(+3)", 1, true) then plus = r end
    end
    assert(n == 5 and plus, "5 Quests + (+3): " .. n)
    local three = {}
    for k = 1, 6 do three[k] = {id = 100 + k} end
    n = 0
    for _, r in ipairs(Tr:Rows({steps = plan.steps, offRoute = three})) do if r.off then n = n + 1 end end
    assert(n == 6, "6 Quests: alle zeigen statt (+1)")
end
-- Abstecher (Nutzer 22.11.2026): Klick = Navi zur Quest, danach zurueck zum Plan; Abbrechen nur ueber Menue mit Rueckfrage
do
    ONE.Print = ONE.Print or function() end
    local A = {active = true, target = nil}
    local navTo = {}
    local oldNs = ONE.ns.nav
    ONE.ns.nav = {Arrow = A, Quests = {Navi = function(_, q) navTo[#navTo + 1] = (q.complete and "abgabe:" or "ziel:") .. q.id
        A.target, A.active = q.title .. (q.complete and " (Abgabe)" or ""), true return true end}}
    local inLog, complete = {[9] = true}, {}
    C_QuestLog = {GetLogIndexForQuestID = function(id) return inLog[id] and 1 or nil end, IsComplete = function(id) return complete[id] == true end}
    local asked, guideNavi = 0, nil
    local oldAsk, oldNavi = G.AskAbandon, G.Navi
    G.AskAbandon = function() asked = asked + 1 return true end
    G.Navi = function(_, step) guideNavi = step A.target = "Plan" return true end
    -- Rueckfrage zuerst (Nutzer 22.11.2026), erst "Ja" startet den Abstecher
    StaticPopupDialogs, StaticPopup_Show = {}, function() end
    hit.click()
    assert(#navTo == 0 and StaticPopupDialogs.GUILDTRIP_DETOUR, "erst Rueckfrage, noch kein Navi")
    StaticPopupDialogs.GUILDTRIP_DETOUR.OnAccept()
    StaticPopupDialogs, StaticPopup_Show = nil, nil
    assert(navTo[1] == "ziel:9" and Tr.detour and Tr.detour.id == 9 and asked == 0, "Klick: Abstecher, kein Abbrechen")
    assert(Tr:CheckDetour({steps = plan.steps}) == nil, "laeuft noch")
    complete[9] = true
    assert(Tr:CheckDetour({steps = plan.steps}) == "turnin" and navTo[2] == "abgabe:9", "fertig -> zur Abgabe")
    inLog[9] = nil
    assert(Tr:CheckDetour({steps = plan.steps}) == "back" and guideNavi == plan.steps[1] and not Tr.detour, "abgegeben -> zurueck zum Plan")
    -- anderes Ziel selbst gewaehlt: Abstecher vergessen, Plan nicht anfassen
    inLog[9], complete[9], guideNavi = true, nil, nil
    Tr:Detour(9)
    A.target = "Wegpunkt"
    Tr:CheckDetour({steps = plan.steps})
    assert(not Tr.detour and guideNavi == nil, "eigenes Ziel bleibt")
    -- ohne Menue: Abbrechen nur mit Rueckfrage (AskAbandon zeigt die Frage)
    MenuUtil = nil
    Tr:OffMenu({}, {9})
    assert(asked == 1, "Abbrechen geht ueber die Rueckfrage")
    G.AskAbandon, G.Navi, ONE.ns.nav, C_QuestLog = oldAsk, oldNavi, oldNs, nil
end
-- Teilziele der aktuellen Quest stehen direkt unter der Quest, der Hinweis erst danach (Nutzer 22.11.2026)
do
    local oldObj = Tr.Objectives
    Tr.Objectives = function() return {{text = "Kanonier getoetet: 0/6"}} end
    local r2 = Tr:Rows({steps = {{kind = "obj", nr = 1, mapID = 1, x = .5, y = .5, actions = {{kind = "obj", id = 1}}}}, offRoute = off})
    local iObj, iOff
    for i, r in ipairs(r2) do
        if r.kind == "obj" then iObj = iObj or i end
        if r.off then iOff = i end
    end
    Tr.Objectives = oldObj
    assert(iObj and iOff and iObj < iOff, "Teilziele vor 'Nicht im Plan'")
end
-- bessere Ausruestung aus Quests ausserhalb der Route: Hinweis (Nutzer 22.11.2026), Route bleibt gleich
do
    local function Row(q, plus, up) return {slot = {name = "Waffe"}, upgrade = up ~= false, plus = plus,
        now = {item = {id = 100 + q}, sources = {{kind = "q", quest = q}}}} end
    local gh = G.GearHints({Row(5730, 100), Row(852, 50), Row(7, 5), Row(8, 80, false),
        {slot = {name = "Hals"}}, {slot = {name = "Kopf"}, upgrade = true, plus = 100, now = {item = {id = 1}, sources = {{kind = "c"}}}}},
        {["accept:852"] = 1})
    assert(#gh == 1 and gh[1].src.quest == 5730, "nur Quests, nicht in der Route, ab 10 % besser: " .. #gh)
    local r3 = Tr:Rows({steps = plan.steps, gearHint = gh})
    local h
    for _, r in ipairs(r3) do if r.text and r.text:find("Besser für dich", 1, true) then h = r end end
    assert(h and h.click and h.tip, "Hinweis 'Besser für dich' mit Navi")
end
-- neue Zauber beim Lehrer: nur Hinweis-Zeile (Nutzer: "nur als Info bei Stufenaufstieg, nicht Teil der Route")
rows = Tr:Rows({steps = plan.steps, trainHint = {n = 2, spots = {{mapID = 1, x = .1, y = .1, name = "Lehrer"}}}})
hit = nil
for _, r in ipairs(rows) do if r.text and r.text:find("Neue Zauber beim Lehrer", 1, true) then hit = r end end
assert(hit and hit.click, "Hinweis 'Neue Zauber beim Lehrer' mit Navi")
for _, s in ipairs(plan.steps) do assert(s.kind ~= "train", "Lehrer ist kein Routen-Schritt") end
-- Taschen fast voll: Haendler als Hinweis
rows = Tr:Rows({steps = plan.steps, vendorHint = {mapID = 1, x = .2, y = .2, name = "Haendlerin"}})
hit = nil
for _, r in ipairs(rows) do if r.text and r.text:find("Händler: Haendlerin", 1, true) then hit = r end end
assert(hit and hit.click, "Hinweis Haendler mit Navi")
-- Taschen (Nutzer 23.11.2026: "volle Taschen beruecksichtigen"): der Haendler mit dem kleinsten Umweg zum naechsten
-- Schritt (accept:2 bei .3/.1), nicht der naechste zum Spieler (.9/.9); bei 5-8 freien Plaetzen nur, wenn er am Weg liegt
do
    local onWay = {mapID = 1, x = .6, y = .5, name = "AmWeg", id = 1}
    local behind = {mapID = 1, x = .95, y = .95, name = "Hinten", id = 2}
    local function VCtx(bags, vendors) local c = Ctx(10) c.bags, c.vendors = bags, vendors return c end
    local vh = assert(P:Plan(VCtx(6, {behind, onWay}))).vendorHint
    assert(vh and vh.name == "AmWeg" and vh.kind == "way" and vh.detour < 1, "Haendler am Weg, nicht der naechste hinten")
    assert(not P:Plan(VCtx(6, {behind})).vendorHint, "6 frei, Haendler nur mit Umweg: kein Hinweis")
    vh = P:Plan(VCtx(3, {behind})).vendorHint
    assert(vh and vh.name == "Hinten" and vh.kind == "low" and vh.detour >= 1, "fast voll: auch mit Umweg")
    vh = P:Plan(VCtx(0, {behind, onWay})).vendorHint
    assert(vh and vh.name == "AmWeg" and vh.kind == "full", "voll")
    assert(not P:Plan(Ctx(10)).vendorHint, "ohne Haendlerliste (genug Platz) kein Hinweis")
    local function Text(h)
        for _, r in ipairs(Tr:Rows({steps = plan.steps, vendorHint = h})) do if r.text and r.text:find("Händler", 1, true) then return r.text end end
    end
    assert(Text({name = "X", kind = "way", detour = 0}):find("Händler am Weg: X", 1, true), "Text am Weg")
    assert(Text({name = "X", kind = "full", detour = 2.4}):find("Taschen voll – Händler: X (+2 min)", 1, true), "Text voll mit Umweg")
end
-- Dungeon-Quest/Vorquest am Weg (Nutzer 23.11.2026): nur Hinweis. Geber 11 steht bei .1/.1; 31 = Vorquest zu
-- Dungeonquest 30 (ab 14), 30 selbst erst ab 15, 32 = lange Weltreihe (kein Hinweis), 33 braucht 32
do
    local function DCtx(level, x, y) local c = Ctx(level) c.me.x, c.me.y = x, y return c end
    assert(not P:Plan(DCtx(12, .1, .1)).dungeonHint, "Stufe zu niedrig: kein Hinweis")
    local dh = P:Plan(DCtx(14, .1, .1)).dungeonHint
    assert(dh and dh.id == 31 and dh.dungeon == "wc" and dh.detour < 1, "Vorquest zum Dungeon am Weg")
    assert(not P:Plan(DCtx(14, .9, .9)).dungeonHint, "Geber weit vom Weg: kein Hinweis")
    log[31] = "open"
    assert(not P:Plan(DCtx(14, .1, .1)).dungeonHint, "schon im Log: kein Hinweis")
    log[31] = nil
    dh = P:Plan(DCtx(15, .1, .1)).dungeonHint
    assert(dh and (dh.id == 31 or dh.id == 30) and dh.more == 1, "ab 15 beide (eine Zeile, +1)")
    local hit
    for _, r in ipairs(Tr:Rows({steps = plan.steps, dungeonHint = dh})) do if r.text and r.text:find("Dungeon-Quest am Weg", 1, true) then hit = r end end
    assert(hit and hit.click and hit.text:find("(+1)", 1, true), "Zeile mit Navi")
end
-- Verpasste fruehere Annahmen (Nutzer 23.11.2026 "Ja, bauen"): wer weiter ist, wird nicht zurueckgeschickt
do
    local r2 = {
        {"a50", n = 11, l = 10}, {"a51", n = 12, l = 10}, {"t51", n = 12, l = 10},
        {"a60", n = 13, l = 10}, {"a61", n = 14, l = 10}, {"a62", n = 22, l = 10}, {"a63", n = 22, l = 10}, {"a64", n = 23, l = 10},
        {"o50", n = 21, l = 10}, {"t50", n = 11, l = 10},
    }
    local dn, lg = {}, {}
    local function InLog(id) return lg[id] ~= nil end
    local function Done(id) return dn[id] == true end
    local f2, _, missed = G.RouteFollow(r2, 10, InLog, nil, Done)
    assert(f2["accept:50"] and f2["accept:51"] and #missed == 0, "am Anfang: nichts verpasst")
    dn[60], dn[62], dn[63] = true, true, true
    f2, _, missed = G.RouteFollow(r2, 10, InLog, nil, Done)
    assert(f2["accept:50"] and #missed == 0, "zwei Geber voraus (Doppelbesuch bei 22 zaehlt einmal): noch nicht verpasst")
    dn[61] = true
    f2, _, missed = G.RouteFollow(r2, 10, InLog, nil, Done)
    assert(not f2["accept:50"] and not f2["accept:51"], "weiter in der Route: fruehere Annahmen fallen weg")
    assert(#missed == 1 and missed[1].id == 50 and missed[1].n == 11, "nur 50 (Rest liegt noch vor einem) als verpasst")
    assert(f2["turnin:50"], "Abgabe bleibt im Fahrplan")
    lg[50] = "open"
    f2, _, missed = G.RouteFollow(r2, 10, InLog, nil, Done)
    assert(f2["accept:50"] and #missed == 0, "schon angenommen: bleibt drin")
    assert(G.RouteFollow(r2, 10, InLog, nil, nil)["accept:51"], "ohne done wie bisher")
    -- Planer: Hinweis nur, wenn der Geber am Weg steht (Quest 1, Geber 11 bei .1/.1)
    local function MCtx(x, y) local c = Ctx(10) c.me.x, c.me.y = x, y c.missed = {{id = 1, n = 11}} return c end
    local mh = P:Plan(MCtx(.1, .1)).missedHint
    assert(mh and mh.id == 1 and mh.detour < 1, "Geber am Weg: Hinweis")
    assert(not P:Plan(MCtx(.9, .9)).missedHint, "Geber weit weg: kein Hinweis")
    local hit
    for _, r in ipairs(Tr:Rows({steps = plan.steps, missedHint = mh})) do if r.text and r.text:find("früher ausgelassen", 1, true) then hit = r end end
    assert(hit and hit.click, "Zeile mit Navi")
end
print("OK test_route_145")

-- 6) die erzeugte Routen-Datei (falls vorhanden): laedt, jede Route hat Schritte bis in hohe Stufen, Stufen steigen
do
  -- eine Route, die schnellste (Nutzer 22.11.2026: keine Tempo-Wahl mehr)
  for _, spec in ipairs({{"Routes", ""}}) do
    local fn = loadfile(root .. "/ONE_Leveling/" .. spec[1] .. ".lua")
    assert(fn or spec[2] == "", spec[1] .. ".lua fehlt")
    if fn then
        GuildTripQuestRoutes = nil
        fn()
        local n, nParts = 0, 0
        for key, r in pairs(GuildTripQuestRoutes) do
            n = n + 1
            assert(key:match("^%d+:%d+" .. spec[2] .. "$"), "Schluessel Volk:Klasse" .. spec[2] .. " " .. key)
            assert(#r > 200, "Route " .. key .. " hat Schritte")
            local last = 0
            for _, st in ipairs(r) do
                assert((st.l or 0) >= last - 1, "Stufen steigen in " .. key)
                last = math.max(last, st.l or 0)
            end
            assert(last >= 50, "Route " .. key .. " reicht bis mindestens Stufe 50 (" .. last .. ")")
            -- Ziel-Teile (Ziele in mehreren Gebieten): je Teil Knoten, alle Teile da, zwischen Annehmen und Abgeben,
            -- kein ungeteilter Ziel-Schritt daneben
            local acc, turn, plain, partsOf = {}, {}, {}, {}
            for i, st in ipairs(r) do
                for k, id, part in (st[1] or ""):gmatch("(%a)(%d+)%.?(%d*)") do
                    id = tonumber(id)
                    if k == "a" then acc[id] = acc[id] or i
                    elseif k == "t" then turn[id] = turn[id] or i
                    elseif k == "o" and part ~= "" then
                        assert(type(st.p) == "table" and #st.p > 0, key .. ": Ziel-Teil o" .. id .. "." .. part .. " ohne Knoten")
                        partsOf[id] = partsOf[id] or {}
                        partsOf[id][tonumber(part)] = i
                    elseif k == "o" then plain[id] = true end
                end
            end
            for id, list in pairs(partsOf) do
                nParts = nParts + 1
                assert(not plain[id], key .. ": Quest " .. id .. " geteilt und ungeteilt")
                for pn = 1, #list do
                    local at = assert(list[pn], key .. ": Quest " .. id .. " Teil " .. pn .. " fehlt")
                    assert(not acc[id] or acc[id] < at, key .. ": Teil von " .. id .. " vor dem Annehmen")
                    assert(not turn[id] or at < turn[id], key .. ": Teil von " .. id .. " nach dem Abgeben")
                end
            end
        end
        assert(n >= 46, "alle Volk-Klasse-Kombinationen: " .. n)
        print(("  %s: %d geteilte Ziel-Schritte"):format(spec[1], nParts))
    end
  end
end
print("OK test_route_145 (Routen-Datei)")
-- Buendel (Nutzer 23.11.2026): Quests in derselben Gegend direkt danach stehen mit in JETZT (Name, Ziel,
-- Fortschritt), ohne eigenen Weg/Zeit; eine Zeitangabe fuer alle; ALS NAECHSTES beginnt danach
do
    local oldObj = Tr.Objectives
    Tr.Objectives = function(id) return {{text = "Ziel von " .. id .. ": 0/5"}} end
    local function St(id, x, kind) return {kind = kind or "obj", nr = 1, mapID = 1, x = .5, y = .5, pos = {1, x, 0},
        actions = {{kind = kind or "obj", id = id}}} end
    local steps = {St(1, 0), St(2, 100), St(3, 300), St(1, 320), St(4, 2000)}
    local b = Tr.Bundle({steps = steps})
    assert(#b == 2 and b[1] == steps[2] and b[2] == steps[3], "nahe Quests gebuendelt, dieselbe Quest nicht doppelt: " .. #b)
    do -- weit weg: nicht gebuendelt; eine spaetere nahe Quest im Log schon (seit 23.11.2026)
        local sx = {St(1, 0), St(2, 900), St(3, 10)}
        local bx, ix = Tr.Bundle({steps = sx})
        assert(#bx == 1 and bx[1] == sx[3] and not ix[2], "fern nein, nah ja: " .. #bx)
    end
    assert(#Tr.Bundle({steps = {St(1, 0), St(2, 10, "turnin")}}) == 0, "nur Ziele toeten/sammeln")
    -- Spieltest 23.11.2026: Abgabe in der Gegend zwischen zwei Zielen beendet das Buendel nicht
    local withTurnin = {St(1, 0), St(1, 50, "turnin"), St(2, 100)}
    local b2, i2 = Tr.Bundle({steps = withTurnin})
    assert(#b2 == 1 and b2[1] == withTurnin[3] and i2[3] and not i2[2], "Ziel hinter der Abgabe gebuendelt")
    -- zwei Besuche beim selben Questgeber, dazwischen ein gebuendeltes Ziel: unter ALS NAECHSTES eine Zeile
    do
        local function At(kind, id, nr, x) local t = St(id, x, kind) t.nr = nr return t end
        local plan7 = {steps = {St(1, 0), At("turnin", 6, 77, 60), St(2, 100), At("turnin", 7, 77, 60), At("turnin", 8, 88, 3000)}, info = {}}
        local titles = {}
        for _, r in ipairs(Tr:Rows(plan7)) do if r.kind == "nxTitle" then titles[#titles + 1] = r.nav.step end end
        assert(#titles == 2 and #titles[1].actions == 2 and titles[1].nr == 77 and titles[2].nr == 88,
            "Walton zweimal -> eine Zeile: " .. #titles)
        assert(#plan7.steps[2].actions == 1, "Plan selbst bleibt unveraendert")
    end
    -- spaeter geplante Quest im Log, deren Gegner hier stehen: mit in JETZT (Spieltest 23.11.2026 "Raptorhoerner");
    -- auch wenn gerade eine Abgabe dran ist. Erst spaeter angenommen: nicht.
    do
        local far = St(9, 5000) far.area = {{1, 5000, 0}, {1, 120, 30}}
        local later = St(8, 5000) later.area = {{1, 100, 0}}
        local pl = {steps = {St(1, 0, "turnin"), St(5, 4000, "turnin"), far, St(8, 4500, "accept"), later}}
        local bb, ii = Tr.Bundle(pl)
        assert(#bb == 1 and bb[1] == far and ii[3], "Raptoren hier: mit in JETZT, auch bei Abgabe zuerst: " .. #bb)
    end
    -- Quest, die erst noch angenommen wird, nicht in JETZT
    local acc = {St(1, 0), St(2, 50, "accept"), St(2, 100)}
    assert(#Tr.Bundle({steps = acc}) == 0, "noch nicht angenommen: nicht gebuendelt")
    local plan6 = {steps = {St(1, 0), St(1, 50, "turnin"), St(2, 100), St(5, 3000)}, info = {}}
    local firstNext
    for _, r in ipairs(Tr:Rows(plan6)) do if r.kind == "nxTitle" and not firstNext then firstNext = r.nav.step end end
    assert(firstNext == withTurnin[2] or firstNext == plan6.steps[2], "Abgabe bleibt unter ALS NAECHSTES")
    local plan5 = {steps = {St(1, 0), St(2, 100), St(3, 300), St(5, 2000)},
        info = {[1] = {work = 6}, [2] = {work = 6}, [3] = {work = 6}}}
    local r5 = Tr:Rows(plan5)
    local nowTitles, objs, eta, nextHas2 = 0, 0, nil, false
    for _, r in ipairs(r5) do
        if r.kind == "now" then nowTitles = nowTitles + 1 end
        if r.kind == "obj" then objs = objs + 1 end
        if r.kind == "eta" then eta = r.text end
        if r.kind == "nxTitle" and r.nav and r.nav.step == plan5.steps[2] then nextHas2 = true end
    end
    assert(nowTitles == 3 and objs == 3, "drei Quests gross in JETZT, je mit Fortschritt: " .. nowTitles .. "/" .. objs)
    assert(eta and eta:find("für alle 3 Quests", 1, true), "eine Zeit fuer alle: " .. tostring(eta))
    assert(not nextHas2, "gebuendelte Quest nicht nochmal unter ALS NAECHSTES")
    Tr.Objectives = oldObj
end
-- echte Plan-Schritte tragen ihre Weltposition (sonst greift das Buendel im Spiel nie – Spieltest 23.11.2026)
do
    local nObj, nPos = 0, 0
    for _, st in ipairs(plan.steps) do
        if st.kind == "obj" then nObj = nObj + 1 if st.pos and st.pos[2] then nPos = nPos + 1 end end
    end
    assert(nObj > 0 and nPos == nObj, "Ziel-Schritte mit pos: " .. nPos .. "/" .. nObj)
end
-- Zeitquests (Nutzer 23.11.2026): Schritt der Quest mit der wenigsten Restzeit kommt nach vorn, Restzeit im Kasten
do
    local function S(kind, id) return {kind = kind, actions = {{kind = kind, id = id}}} end
    local pl = {steps = {S("obj", 1), S("turnin", 2), S("obj", 7), S("turnin", 7)}}
    assert(G.TimedFirst(pl, {[7] = 600, [2] = 900}) and pl.steps[1].actions[1].id == 7 and pl.steps[1].kind == "obj"
        and pl.timed.id == 7 and #pl.steps == 4, "Zeitquest zuerst (Ziel vor Abgabe)")
    local pl2 = {steps = {S("obj", 1)}}
    assert(not G.TimedFirst(pl2, {}) and pl2.steps[1].actions[1].id == 1, "ohne Zeitquest bleibt alles")
    local t = Tr.TimerText(S("obj", 7), {[7] = 725})
    assert(t and t:find("noch 12 min", 1, true) and t:find("ffd100", 1, true), "Restzeit gold: " .. tostring(t))
    t = Tr.TimerText(S("obj", 7), {[7] = 45})
    assert(t and t:find("noch 45 s", 1, true) and t:find("ff3030", 1, true), "unter 5 min rot: " .. tostring(t))
    assert(Tr.TimerText(S("obj", 1), {[7] = 45}) == nil, "andere Quest: nichts")
    assert(GuildTripQuestDB.timed == nil or type(GuildTripQuestDB.timed) == "table")
end
do -- Hinweis auf fehlende Questdaten (Zephras und andere neue Forever-Gebiete), auch in Unterkarten
    local oldMap = C_Map
    C_Map = {GetMapInfo = function(m) return ({[9001] = {parentMapID = 2521}, [2521] = {parentMapID = 947}})[m] end}
    assert(Tr.NoDataHint(9001, "Horde"):find("Donnerfels"), "Unterkarte von Zephras, Horde: Zeppelin")
    assert(Tr.NoDataHint(2521, "Alliance"):find("Luftschiff"), "Zephras, Allianz: Luftschiff")
    assert(Tr.NoDataHint(2548, "Horde"):find("dieses Gebiet"), "anderes Gebiet ohne Daten")
    assert(Tr.NoDataHint(1411, "Horde") == nil and Tr.NoDataHint(nil, "Horde") == nil, "Durotar: kein Hinweis")
    C_Map = oldMap
end
print("ok keine Daten")
