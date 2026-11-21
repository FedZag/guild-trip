-- Offline-Test: Anzeige der neuen Schritte (Lehrer, Flugpunkt, Ruhestein, Monster hauen, Abbrechen) und die
-- Spiel-Anbindung (lernbare Zauber, unbekannte Flugpunkte, Gastwirte) – Nutzer 20.11.2026
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
local function Stub()
    return setmetatable({}, {__index = function() return function() end end})
end
CreateFrame = function() return Stub() end
UIParent = Stub()
C_Timer = {After = function(_, fn) fn() end}
UnitName = function() return "Testheld" end
UnitLevel = function() return 15 end
UnitFactionGroup = function() return "Horde" end
GetItemCount = function() return 1 end
local ONE = {db = {}, modules = {}, ns = {}}
_G.ProjectONE = ONE
function ONE:Print() end
GuildTripQuestDB = {q = {[1] = {14, 10, 0, 0, false, {}, {}, {}, false, false, 500, 0, 0, 1}}, n = {}, names = {}}
GuildTripLeveling = {r = {}, i = {}, dz = {}}
ONE.ns.nav = {Travel = {PlayerMapPosition = function() return 1413, .5, .5 end, PlayerWorld = function() return 1, 0, 0 end,
    World = function(m, x, y) return 1, x * 1000, y * 1000 end, ShortName = function(n) return (n:match("^([^,]+)")) end},
    Flights = {Known = function() return {[25] = true, [23] = true} end}}
local pointed, worldPointed
ONE.modules.nav = {PointTo = function(_, label, m, x, y) pointed = {label, m, x, y} return true end, DistanceTo = function() return 100 end}
ONE.ns.nav.Arrow = {StartWorld = function(_, label, c, x, y) worldPointed = {label, c, x, y} return true end}
local lev = {}
for _, f in ipairs({"Planner", "Guide", "Inns", "FlightMasters", "Hearth", "Tracker"}) do
    assert(loadfile(root .. "/ONE_Leveling/" .. f .. ".lua"))("ONE_Leveling", lev)
end
local G, Tr, H = lev.Guide, lev.Tracker, lev.Hearth

-- ===== lernbare Zauber =====
ONE.ns.crafting = {Trainers = {All = function() return {
    {npc = "Pephredo", kind = "class", what = "Magier", map = 1454, x = .388, y = .856},
    {npc = "Ur'kyo", kind = "class", what = "Priester", map = 1454, x = .356, y = .878},
    {npc = "Lumak", kind = "profession", what = "Angeln", map = 1454, x = .699, y = .292},
} end}}
-- ohne Besuch: die letzte gerade Stufe (14) gilt als offen, 16 kommt
local t = assert(G.TrainInfo("MAGE", 15, "Testheld"))
assert(t.now == 1 and t.next[16] == 1 and #t.spots == 1 and t.spots[1].name == "Pephredo", "Magier-Lehrer, Stufe 14 offen")
assert(G.TrainInfo("MAGE", 14, "Testheld").now == 1)
-- Besuch aus aelterer Version (ohne Stufe, leere Liste – so in Testhelds Daten): gilt als gelernt
ONE.db.classGuide = {upcoming = {Testheld = {class = "MAGE", list = {}}}}
t = G.TrainInfo("MAGE", 15, "Testheld")
assert(t.now == 0 and t.next[16] == 1, "alter Besuch ohne Stufe: nichts offen")
assert(G.TrainInfo("MAGE", 16, "Testheld").now == 0, "mit 16 ohne neuen Besuch unbekannt: gilt als gelernt")
-- Besuch mit 14 gemerkt (ohne Liste): mit 15 nichts offen, 16 kommt
ONE.db.classGuide = {upcoming = {Testheld = {class = "MAGE", list = {}, level = 14}}}
t = G.TrainInfo("MAGE", 15, "Testheld")
assert(t.now == 0 and t.next[16] == 1, "beim Lehrer gewesen")
-- Besuch mit Liste der kommenden Zauber: genau
ONE.db.classGuide.upcoming.Testheld.list = {{name = "Frostnova", level = 16}, {name = "Feuerball", level = 16}, {name = "Blinzeln", level = 20}}
t = G.TrainInfo("MAGE", 16, "Testheld")
assert(t.now == 2 and t.next[17] == nil and t.next[18] == nil, "genau aus der Liste")
-- andere Klasse gemerkt (Name doppelt): Regel statt fremder Liste
ONE.db.classGuide.upcoming.Testheld.class = "PRIEST"
assert(G.TrainInfo("MAGE", 16, "Testheld").now == 1)
assert(G.TrainInfo("WARLOCK", 16, "Testheld") == nil, "kein Hexenmeister-Lehrer bekannt: nichts")
assert(G.TrainInfo(nil, 16) == nil and G.TrainInfo("MAGE", 1) == nil)
-- Portal-Lehrer (Thuul, Orgrimmar) sind keine Magierlehrer (Spieltest 20.11.2026)
GuildTripQuestDB.trainers = nil
assert(loadfile(root .. "/ONE_QuestDB/Services.lua"))()
for _, id in ipairs({2485, 2489, 2492, 4165, 5957, 5958}) do
    assert(GuildTripQuestDB.trainers[id][1] == "other", "Portal-Lehrer " .. id)
end
assert(GuildTripQuestDB.trainers[5882][1] == "class" and GuildTripQuestDB.trainers[5885][2] == "Magier", "echte Magierlehrer bleiben")

-- ===== Flugpunkte und Gastwirte =====
local fps = G.UnknownFlights("Horde")
local ids = {}
for _, f in ipairs(fps) do ids[f.id] = f end
assert(not ids[23] and not ids[25], "bekannte nicht")
assert(ids[80] and ids[80].name:find("Ratchet"), "Ratschet (beide Fraktionen) dabei")
for _, f in ipairs(lev.FLIGHTMASTERS) do
    if f[5] == 1 then assert(not ids[f[1]], "Allianz-Flugpunkt nicht fuer Horde: " .. f[6]) end
end
assert(#G.UnknownFlights("?") == 0)
local inns = assert(G.InnList())
local sawXR = false
for _, n in ipairs(inns) do if n.id == 3934 then sawXR = true end assert(n[1] and n[2] and n[3]) end
assert(sawXR, "Crossroads-Gastwirt dabei")
-- Heimatort + Ruhestein
assert(G.HearthState() == nil, "ohne Heimatort nichts")
ONE.db.leveling = {home = {Testheld = {1, -407, -2645.5, inn = 3934, place = "Crossroads"}}}
local home, inSec = G.HearthState()
assert(home and home.place == "Crossroads" and inSec == 0, "bereit")
GetItemCount = function() return 0 end
-- (21.11.2026: Heimatort bleibt bekannt – sonst wuerde "Ruhestein setzen" immer wieder vorgeschlagen; nur keine Reise)
local h2, in2 = G.HearthState()
assert(h2 and h2.place == "Crossroads" and in2 == nil, "kein Ruhestein im Gepaeck: Ort ja, Reise nein")
GetItemCount = function() return 1 end

-- ===== Texte =====
local steps = {
    train = {kind = "train", name = "Pephredo", lvl = 14, mapID = 1454, x = .388, y = .856, world = {1, 1, 1}, actions = {}},
    fp = {kind = "fp", name = "Ratchet, The Barrens", world = {1, 10, 20}, actions = {}},
    grind = {kind = "grind", lvl = 16, work = 12.4, mapID = 1413, actions = {}},
    bind = {kind = "bind", name = "Gastwirt Boorand", world = {1, 30, 40}, actions = {}},
    hs = {kind = "travel", via = {kind = "hearth", place = "Crossroads", save = 7.6}, walk = 1.2, actions = {}},
}
assert(G:StepText(steps.train):find("Neue Zauber lernen"))
assert(G:StepWho(steps.train):find("Pephredo"))
assert(G:StepText(steps.fp):find("Flugpunkt Ratchet holen"), G:StepText(steps.fp))
assert(G:StepText(steps.grind):find("Bis Stufe 16 Monster hauen"))
assert(G:StepWho(steps.grind):find("12 min") and G:StepWho(steps.grind):find("Stufe 16"))
assert(G:StepText(steps.bind):find("Ruhestein setzen: Gastwirt Boorand"))
assert(G:StepText(steps.hs):find("Ruhestein nach Crossroads benutzen"))
assert(G:StepWho(steps.hs):find("spart ca. 8 min"))
for k, st in pairs(steps) do
    assert(Tr.NowTitle(st) == G:StepText(st, false, true), "Kasten-Titel " .. k)
    assert(type(Tr.NowWho(st)) == "string", "zweite Zeile " .. k)
end
assert(Tr:NowEta(steps.hs):find("Ruhestein"), Tr:NowEta(steps.hs))
assert(Tr:NowEta(steps.grind):find("12 min"))
-- Navi: Lehrer per Karte, Flugpunkt/Gastwirt per Welt, Monster hauen gar nicht
assert(G:Navi(steps.train) and pointed[1] == "Pephredo" and pointed[2] == 1454)
assert(G:Navi(steps.fp) and worldPointed[1] == "Flugmeister" and worldPointed[3] == 10)
assert(G:Navi(steps.bind) and worldPointed[1] == "Gastwirt Boorand")
pointed = nil
assert(not G:Navi(steps.grind) and pointed == nil)
G.DB = function() return {tracker = true} end
assert(G:AutoNavi({steps = {steps.grind}}) == false)

-- ===== Kasten: Abbrechen-Hinweis, kein doppelter Ruhestein-Hinweis =====
G.Title = function(id) return "Quest " .. id end
G.RecQuestion = function() return nil end
G.ToNextLevel = function() return nil end
local plan = {steps = {steps.train, steps.fp}, blocks = {}, abandon = {{id = 7, skip = "Grau – kaum noch EP."}, {id = 8}, {id = 9}}, info = {}}
local rows = Tr:Rows(plan)
local found
for _, r in ipairs(rows) do if r.text and r.text:find("Abbrechen lohnt") then found = r end end
assert(found and found.text:find("Quest 7, Quest 8") and found.text:find("%(%+1%)") and found.tip, "Abbrechen-Zeile mit Tipp")
plan.abandon = {}
for _, r in ipairs(Tr:Rows(plan)) do assert(not (r.text and r.text:find("Abbrechen lohnt"))) end
-- Ruhestein schon als Schritt geplant: Hearth zeigt keinen zweiten Hinweis
lev.Hearth.UseAdvice = function() return 9, "Crossroads" end
assert(#H:Lines({steps = {steps.hs, steps.train}}) == 0, "geplant: kein Doppel")
assert(#H:Lines({steps = {steps.train, steps.fp}}) == 1, "nicht geplant: Hinweis wie bisher")
-- ===== Abbrechen per Klick: nur nach Rueckfrage =====
do
    local removed = {}
    C_QuestLog = {SetSelectedQuest = function(id) removed.sel = id end, SetAbandonQuest = function() end,
        AbandonQuest = function() removed[#removed + 1] = removed.sel end}
    StaticPopupDialogs, StaticPopup_Show = nil, nil
    assert(G:AskAbandon({7}) == false and #removed == 0, "ohne Rueckfrage-Fenster nie abbrechen")
    local shown
    StaticPopupDialogs = {}
    StaticPopup_Show = function(name) shown = name end
    local plan2 = {steps = {steps.train}, blocks = {}, abandon = {{id = 7}, {id = 8}, {id = 9}}, info = {}}
    local row
    for _, r in ipairs(Tr:Rows(plan2)) do if r.text and r.text:find("Abbrechen lohnt") then row = r end end
    assert(row and row.click and row.tip:find("Rückfrage"), "Zeile klickbar mit Hinweis")
    row.click()
    local d = StaticPopupDialogs.GUILDTRIP_ABANDON
    assert(shown == "GUILDTRIP_ABANDON" and d.text:find("3 Quests abbrechen") and d.text:find("Quest 9"), "fragt erst, nennt alle")
    assert(#removed == 0, "vor dem Ja passiert nichts")
    d.OnAccept()
    assert(#removed == 3 and removed[1] == 7 and removed[3] == 9, "nach Ja alle drei abgebrochen")
    assert(G:AskAbandon({}) == false)
end
-- ===== nach Flug/Ruhestein weit weg vom Planungsort: neu planen =====
do
    local px, py = 0, 0
    ONE.ns.nav.Travel.PlayerWorld = function() return 1, px, py end
    UnitOnTaxi = function() return false end
    G.planAt = G.PlayerWorldPos()
    assert(not G:MovedAway(), "am Planungsort")
    px = 300
    assert(not G:MovedAway(), "300 yd: noch nicht")
    px = 1200
    assert(G:MovedAway(), "1200 yd (Ratchet -> Crossroads): neu planen")
    UnitOnTaxi = function() return true end
    assert(not G:MovedAway(), "waehrend des Flugs nicht")
    UnitOnTaxi = nil
end
print("OK test_routine_ui_136")
