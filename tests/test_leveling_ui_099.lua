-- Offline-Test: Quest-Fuehrung im Spiel (Guide, Ansicht, Kasten) mit nachgebauten Fenstern und echten Daten.
local root = arg[1] or "src"
GetLocale = function() return "deDE" end
-- Allzweck-Fenster: jede Methode geht, Texte werden gemerkt
local function Stub()
    local o = {texts = {}, shown = true}
    return setmetatable(o, {__index = function(t, k)
        if k == "SetText" then return function(self, v) self.text = v end end
        if k == "GetText" then return function(self) return self.text end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "CreateFontString" or k == "CreateTexture" then return function() return Stub() end end
        if k == "GetPoint" then return function() return "TOPRIGHT", nil, "TOPRIGHT", -5, -5 end end
        return function() end
    end})
end
CreateFrame = function() return Stub() end
UIParent = Stub()
C_Timer = {After = function(_, fn) fn() end}
local done, log = {}, {}
for id, e in pairs((function() assert(loadfile(root .. "/ONE_QuestDB/Data.lua"))() return GuildTripQuestDB.q end)()) do
    if e[1] > 0 and e[1] < 10 then done[id] = true end
end
assert(loadfile(root .. "/ONE_QuestDB/Names_deDE.lua"))()
C_QuestLog = {IsQuestFlaggedCompleted = function(id) return done[id] end,
    GetLogIndexForQuestID = function(id) return log[id] end, IsComplete = function() return false end}
UnitLevel = function() return 15 end
UnitClass = function() return "Schurke", "ROGUE" end
UnitRace = function() return "Mensch", "Human" end
UnitFactionGroup = function() return "Alliance" end
UnitXP = function() return 0 end
UnitXPMax = function() return 8000 end
IsInGroup = function() return false end
local ONE = {db = {}, modules = {}, ns = {}, features = {}}
_G.ProjectONE = ONE
function ONE:Print() end
function ONE:IsEnabled() return true end
function ONE:RegisterFeature(id, def) self.features[id] = def return true end
function ONE:RegisterModule(id, def) self.modules[id] = def return true end
-- Navi: Fake-Welt wie im Planer-Test
local pointed
ONE.ns.nav = {Travel = {PlayerMapPosition = function() return 1436, .56, .47 end,
    World = function(m, x, y) return 0, (m % 50) * 3000 + x * 3000, y * 3000 end}}
ONE.modules.nav = {PointTo = function(_, label, m, x, y) pointed = {label, m, x, y} return true end,
    DistanceTo = function() return 140 end}
ONE.ns.dungeons = {Catalog = {{key = "dm", name = "Todesminen", min = 17}}, Entrances = {Get = function() return {mapID = 1436, x = .425, y = .717} end}}
-- Bausteine der Oberflaeche
local lists = {}
ONE.Widgets = {Button = function() return Stub() end, NaviArrow = function() return Stub() end}
ONE.Kit = {List = function(_, _, opts) local l = {box = Stub(), opts = opts} function l:SetItems(items) self.items = items end lists[#lists + 1] = l return l end}
ONE.UI = {Refresh = function() end}
local lev = {}
for _, f in ipairs({"Rewards", "Planner", "Guide", "Page", "Tracker", "Settings", "AutoQuest", "Init"}) do assert(loadfile(root .. "/ONE_Leveling/" .. f .. ".lua"))("ONE_Leveling", lev) end
assert(ONE.modules.leveling and ONE.modules.leveling:OwnsQuestTab())
ONE.modules.leveling.Initialize()
local G, Tr = lev.Guide, lev.Tracker
local plan = assert(G.plan, "beim Start geplant")
-- Navi folgt der Fuehrung von selbst (Kasten an), aber nicht, wenn abgeschaltet oder Kasten aus
assert(pointed and pointed[2] == plan.steps[1].mapID, "Pfeil zeigt von selbst zum ersten Schritt")
pointed, G.autoKey = nil, nil
G:DB().autoNavi = false G:Replan()
assert(not pointed, "abgeschaltet")
G:DB().autoNavi = nil G:DB().tracker = false G.autoKey = nil G:Replan()
assert(not pointed, "nur wenn die Fuehrung benutzt wird")
G:DB().tracker = true G:Replan()
assert(pointed, "wieder an")
-- Schritte nennen den Questgeber
local named = false
for _, st in ipairs(G.plan.steps) do
    if st.kind == "accept" and G.NodeName(st.nr) and G:StepText(st):find(G.NodeName(st.nr), 1, true) then named = true break end
end
assert(named, "Questgeber im Schritt")
assert(#plan.steps > 5 and plan.chosen[166] == "dungeon")
-- Kasten: Liste Jetzt / Danach / Dann
local f = Tr.frame
local function Shown()
    local out = {}
    for _, fs in ipairs(Tr.lines) do if fs.shown then out[#out + 1] = fs.text end end
    return out
end
local rows = Shown()
assert(f.shown and rows[1] == "JETZT" and rows[2]:find("annehmen") and not rows[2]:find("bei ", 1, true) and rows[3]:find("^bei "), "jetzt gross, darunter bei wem")
assert(rows[5] == "NOCH ANNEHMEN" and rows[6]:find("AvailableQuestIcon"), "danach: noch annehmen")
assert(f.dist.text == "140 m")
local function Steps() local n = 0 for _, fs in ipairs(Tr.lines) do if fs.shown and fs.text and fs.text:find("AvailableQuestIcon") then n = n + 1 end end return n end
-- Hoehe bestimmt die Zahl der Schritte (Stub-Fenster liefert keine Groesse -> gemerkte Hoehe zaehlt)
local n0 = Steps()
assert(n0 >= 3, "Standardhoehe zeigt mehrere Schritte: " .. n0)
G:DB().trackerHeight = 500 Tr:Update(G.plan)
local n1 = Steps()
G:DB().trackerHeight = 120 Tr:Update(G.plan)
local n2 = Steps()
assert(n1 > n0 and n2 < n0 and n2 >= 2, "groesser gezogen = mehr Schritte " .. n0 .. "/" .. n1 .. "/" .. n2)
G:DB().trackerHeight = nil Tr:Update(G.plan)
-- Schriftgroesse in Grenzen
assert(Tr:SetScale(5) == Tr.MAX_SCALE and Tr:SetScale(.1) == Tr.MIN_SCALE and Tr:SetScale(1.23) == 1.25)
lev.Settings:Set("trackerScale", 1.3) assert(G:DB().trackerScale == 1.3)
-- 0.6.9: Einstellungen in Optionen › Leveln (keine Ansicht im Reiter mehr); Zahnrad springt dorthin
local registered, openedCat = {}, nil
ONE.UI.AddSetting = function(_, o) registered[o.id] = o return true end
ONE.UI.OpenOptions = function(_, cat) openedCat = cat return true end
assert(lev.Settings:Register())
for _, id in ipairs({"levTempo", "levTempoHint", "lev.tracker", "lev.trackerBare", "lev.replaceBlizzard", "lev.autoNavi",
    "lev.autoQuest", "lev.autoQuestAll", "levScale", "levSizeHint", "levReset"}) do
    assert(registered[id] and registered[id].category == "leveling" and registered[id].module == "leveling", id)
end
assert(registered["lev.autoQuestAll"].indent == 1, "Unterpunkt eingerueckt")
assert(registered.levTempo.kind == "radio" and #registered.levTempo.options() == 3)
registered.levTempo.set("all") assert(G:DB().tempo == "all" and registered.levTempo.get() == "all")
assert(registered.levTempoHint.label():find("Alles außer grauen", 1, true))
registered["lev.autoQuest"].set(true) assert(G:DB().autoQuest == true and registered["lev.autoQuest"].get())
registered["lev.autoQuest"].set(false)
-- Schrift A−/A+ und Zuruecksetzen
local row = Stub()
local refreshScale, h = registered.levScale.build(row, 500)
assert(h and h > 0) refreshScale()
G:DB().trackerScale = 1.4 registered.levReset.onClick()
assert(G:DB().trackerScale == nil, "Kasten zurueckgesetzt")
lev.Settings:Open()
assert(openedCat == "leveling", "Zahnrad: Optionen › Leveln")
lev.Settings:Set("tempo", "balanced") assert(G:DB().tempo == "balanced")
lev.Settings:Set("tempo", "need")
-- WoW-Questliste ersetzen: umhaengen, Log-Quests im Kasten, zuruecksetzen
local parent = {}
ObjectiveTrackerFrame = {p = parent, SetParent = function(self, p) self.p = p end, GetParent = function(self) return self.p end}
log[99001] = 1
C_QuestLog.GetNumQuestLogEntries = function() return 1 end
C_QuestLog.GetInfo = function() return {questID = 99001, title = "Testquest"} end
C_QuestLog.GetQuestObjectives = function() return {{text = "Eber: 2/5", numFulfilled = 2, numRequired = 5}} end
lev.Settings:Set("replaceBlizzard", true)
assert(ObjectiveTrackerFrame.p ~= parent, "WoW-Liste ausgeblendet")
local all = table.concat(Shown(), "\n")
local rights = {}
for _, fs in ipairs(Tr.rights) do if fs.shown then rights[#rights + 1] = fs.text end end
assert(all:find("DEINE QUESTS %(1%)") and all:find("Testquest") and table.concat(rights, " "):find("2/5"), all)
-- nicht eingeplante Quest: grau, Tooltip mit Grund, Klick = Navi
local hit
for i, fs in ipairs(Tr.lines) do if fs.shown and fs.text and fs.text:find("Testquest") then hit = Tr.hits[i] end end
assert(hit and hit.tip and hit.tip:find("Nicht eingeplant") and hit.nav.qid == 99001)
-- einklappen
Tr.toggle.__click = true
G:DB().trackerLogOpen = false Tr:Update(G.plan)
all = table.concat(Shown(), "\n")
assert(all:find("+ DEINE QUESTS") and not all:find("Testquest"), "eingeklappt")
G:DB().trackerLogOpen = nil
lev.Settings:Set("replaceBlizzard", false)
assert(ObjectiveTrackerFrame.p == parent, "WoW-Liste zurück")
log[99001] = nil
-- nur Text: Rahmen weg, beim Drueberfahren da
lev.Settings:Set("trackerBare", true)
assert(not f.bg.shown)
Tr:Frame(true) assert(f.bg.shown)
Tr:Frame(false) assert(not f.bg.shown)
lev.Settings:Set("tracker", false)
assert(not f.shown, "Kasten abschaltbar")
lev.Settings:Set("tracker", true)
assert(f.shown)
-- Navi zum Schritt
G:Navi(plan.steps[1])
assert(pointed and pointed[2] == 1436)
-- Ansicht Fuehrung
local mode = "guide"
local refresh = lev.Page:Build(Stub(), 726, 437, function() return mode end)
refresh()
local items = lists[#lists].items
assert(items[1].header and items[2].step and items[2].current, "Gebiet als Kopf, dann aktueller Schritt")
-- Warum? fuer die Todesminen-Quest
local rows, verdict = G:Why(166)
assert(#rows >= 2 and verdict:find("Todesminen"), verdict)
-- Ausgelassen-Ansicht hat Gruende
mode = "skipped"
refresh()
items = lists[#lists].items
assert(#items > 0 and items[1].text:find("|cff9d9d9d"))
-- Abwaehlen / Tempo
local xpQuest
for id, why in pairs(G.plan.chosen) do if why == "xp" then xpQuest = id break end end
assert(xpQuest)
G:SetOverride(xpQuest, "no")
assert(not G.plan.chosen[xpQuest])
G:SetOverride(xpQuest, nil)
assert(G:CycleTempo() == "balanced" and G:CycleTempo() == "all" and G:CycleTempo() == "need")
-- Reiter "Leveln": drei Ansichten (Plan | Ausgelassen | Questlog), Questlog eingebettet (ONE_Nav)
ONE.UI.Layout = {width = 726}
ONE.Geometry = {tokens = {contentHeight = 437}}
ONE.Widgets.PageHeader = function() return Stub(), Stub() end
local logBuilt, logRefreshed, ctx = nil, 0, nil
ONE.ns.nav.Quests = {Build = function(_, panel, embedded) logBuilt = embedded return function() logRefreshed = logRefreshed + 1 end end}
ONE.UI.SetContext = function(_, id, text) ctx = {id, text} end
local tab = lev.Page:BuildTab(Stub())
assert(logBuilt == true, "Questlog ohne eigene Kopfzeile eingebettet")
assert(#lev.Page.VIEWS == 3, "keine Ansicht Einstellungen mehr")
for _, v in ipairs({"guide", "skipped", "log"}) do
    G:DB().view = v
    tab()
    assert(ctx[1] == "leveling", v)
end
assert(logRefreshed == 1 and ctx[2] == "Questlog")
G:DB().view = "settings" tab() assert(ctx[2] == "Plan", "alte Ansicht Einstellungen -> Plan")
G:DB().view = "unsinn" tab() assert(ctx[2] == "Plan", "unbekannte Ansicht -> Plan")
print("OK: Quest-Fuehrung im Spiel")
