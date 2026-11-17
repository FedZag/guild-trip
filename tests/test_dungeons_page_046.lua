-- Offline-Test: ONE Dungeons, Datenmodell und Seite (0.4.6b). Echte Optik nur im Spiel.
local root = arg[1] or "src"
local printed = {}
local made = {}
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}, scroll = 0}
    made[#made + 1] = r
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then
            return function() end
        end
    end})
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:SetPoint(...) self.point = {...} end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text or "" end
    function r:SetTextColor(...) self.color = {...} end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:HookScript(e, fn) self.scripts["hook:" .. e] = fn end
    function r:RegisterEvent(e) self.events = self.events or {} self.events[e] = true end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetVerticalScroll(v) self.scroll = v end
    function r:GetVerticalScroll() return self.scroll end
    function r:GetChecked() return self.checked end
    function r:SetChecked(v) self.checked = v end
    function r:GetStringHeight() return 40 end
    function r:SetTexture(t) self.texture = t end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")
GetServerTime = function() return 1 end

UnitLevel = function() return 16 end
UnitFactionGroup = function() return "Horde" end
UnitClass = function() return "Priester", "PRIEST" end
local requested = {}
local titles = {[5761] = "Erlegt das Untier"}
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return id == 5761 or id == 5726 end,
    GetLogIndexForQuestID = function(id) if id == 5725 then return 3 end end,
    GetTitleForQuestID = function(id) return titles[id] end,
    RequestLoadQuestByID = function(id) requested[#requested + 1] = id end,
}
C_LFGList = {GetActivityInfoTable = function(id)
    if id == 798 then return {fullName = "Ragefireabgrund", minLevelSuggestion = 13, maxLevelSuggestion = 18} end
    if id == 805 then return {fullName = "SM Friedhof", minLevelSuggestion = 30, maxLevelSuggestion = 38} end
    if id == 828 then return {fullName = "SM Kathedrale", minLevelSuggestion = 38, maxLevelSuggestion = 46} end
end}
local pointed
local ONE = {db = {}, modules = {}, slash = {}}
function ONE:Print() end
function ONE:IsEnabled() return true end
function ONE:RegisterSlash(n, fn) self.slash[n] = fn end
function ONE:RegisterModule(id, def) self.modules[id] = def def.Initialize(def) end
ONE.modules.nav = {PointTo = function(_, label, map, x, y) pointed = {label, map, x, y} return true end}
local tabs = {}
ONE.UI = {Layout = {width = 726}, activeTab = "dungeons", frame = UIParent,
    AddTab = function(_, id, _, builder) tabs[id] = builder(Region("Frame")) return true end,
    OpenLink = function(_, id) ONE.opened = id end}
_G.ProjectONE = ONE
for _, f in ipairs({"Themes.lua", "Kit.lua", "Geometry.lua", "Widgets.lua"}) do
    assert(loadfile(root .. "/ONE_Core/" .. f))("ONE_Core", ONE)
end
ONE.Themes:Initialize()
local d = {}
local toc = assert(io.open(root .. "/ONE_Dungeons/ONE_Dungeons.toc")):read("*a")
assert(toc:find("## OptionalDeps: ONE_Nav", 1, true))
for name in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile(root .. "/ONE_Dungeons/" .. name))("ONE_Dungeons", d) end
local M = d.Model
assert(#d.QuestData.dungeons == 25 and d.QuestData.source.license == "MIT")
local lic = io.open(root .. "/ONE_Dungeons/LICENSE_ForeverDungeonQuests.txt")
assert(lic and lic:read("*a"):find("Copyright (c) 2026 Sundee", 1, true), "Lizenztext muss beiliegen") lic:close()
-- Jeder Katalogeintrag mit Questdaten findet seine Daten
for _, entry in ipairs(d.Catalog) do
    if entry.quests then assert(M:QuestTable(entry.quests), "Questdaten fehlen fuer " .. entry.quests) end
end

-- 1) Liste fuer Horde-Priester Stufe 16
local list = M:Dungeons()
local byKey = {}
for _, x in ipairs(list) do byKey[x.key] = x end
assert(not byKey.stocks, "Allianz-Dungeon fuer Horde ausgeblendet")
assert(byKey.rfc.name == "Ragefireabgrund" and byKey.rfc.suitable and byKey.rfc.kind == "fit")
assert(byKey.sm.min == 30 and byKey.sm.max == 46 and byKey.sm.name == "Scharlachrotes Kloster", "Fluegel zusammengefasst")
assert(not byKey.scholo.suitable and byKey.scholo.kind == "hard")
assert(byKey.dalaran and not byKey.dalaran.hasData, "neuer Dungeon ohne Questdaten bleibt sichtbar")
for _, q in ipairs(byKey.dm.quests) do assert(q.classOnly ~= "PALADIN", "fremde Klassenquest ausgeblendet") end
for _, q in ipairs(byKey.rfc.quests) do assert(q.faction ~= "Alliance") end

assert(byKey.rfc.en == "Ragefire Chasm" and byKey.dalaran.en == "Dalaran")
for _, x in ipairs(list) do assert(type(x.en) == "string" and x.en ~= "", "englischer Name fehlt: " .. x.key) end
-- 2) Status und Titel
local function Find(dg, id) for _, q in ipairs(dg.quests) do for _, i in ipairs(q.ids or {}) do if i == id then return q end end end end
assert(M:Status(Find(byKey.rfc, 5761)) == "done")
assert(M:Status(Find(byKey.rfc, 5725)) == "log")
assert(M:Status(Find(byKey.rfc, 5728)) == "locked", "Vorquests fehlen")
assert(M:Status(Find(byKey.rfc, 5723)) == "open")
assert(M:Title(Find(byKey.rfc, 5761)) == "Erlegt das Untier" and M:Title(Find(byKey.rfc, 5723)) == "Testing an Enemy's Strength")
assert(byKey.rfc.done == 1)
assert(M:RequestTitles(byKey.rfc.quests) >= 3 and #requested >= 3)
titles[5723] = "Die Stärke des Feindes"
assert(M:OnQuestData(5723, true) and ONE.db.dungeons.titles[5723] == "Die Stärke des Feindes")

-- 3) Seite: Auswahl, Quest anklicken, Hinfuehren
assert(tabs.dungeons, "Seite Dungeons fehlt")
assert(d.Page and ONE.Kit.tiles.dungeons, "Kachel fehlt")
tabs.dungeons()
local rows = {}
for _, r in ipairs(made) do if r.kind == "Button" and r.cells and r.cells.open then rows[#rows + 1] = r end end
assert(rows[1].shown and rows[1].item.key == "rfc", "erster passender Dungeon ist Ragefireabgrund")
for _, r in ipairs(rows) do if r.shown and r.item then assert(r.item.suitable, "nur passende Dungeons") end end
local qrows = {}
for _, r in ipairs(made) do if r.kind == "Button" and r.cells and r.cells.tag then qrows[#qrows + 1] = r end end
local target
for _, r in ipairs(qrows) do if r.item and r.item.ids and r.item.ids[1] == 5761 then target = r end end
assert(target and target.cells.name.text == "Erlegt das Untier")
target.scripts.OnClick(target, "LeftButton")
local detailText
for _, r in ipairs(made) do if r.kind == "FontString" and type(r.text) == "string" and r.text:find("Questgeber:", 1, true) then detailText = r.text end end
assert(detailText and detailText:find("Neeru Fireblade", 1, true) and detailText:find("Orgrimmar", 1, true))
local subline
for _, r in ipairs(made) do if r.kind == "FontString" and type(r.text) == "string" and r.text:find("Ragefire Chasm", 1, true) and r.text:find("Stufe", 1, true) then subline = r.text end end
assert(subline, "englischer Name in der Kopfzeile fehlt")
local guide
-- seit 15.11.: kleiner Navi-Pfeil statt "Hinfuehren", Ziel im Tooltip
for _, r in ipairs(made) do
    if r.kind == "Button" and type(r.tip) == "function" and tostring(r.tip(r)):find("Neeru Fireblade", 1, true) then guide = r end
end
assert(guide and guide.shown)
guide.scripts.OnClick(guide)
assert(pointed and pointed[2] == 1454 and math.abs(pointed[3] - .49) < 1e-9, "Pfeil zum Questgeber in Orgrimmar")
-- Quellenangabe sichtbar
local credit = false
for _, r in ipairs(made) do if r.kind == "FontString" and type(r.text) == "string" and r.text:find("Sundee", 1, true) then credit = true end end
assert(credit, "Namensnennung fehlt")
-- Filter aus: alle Dungeons
local check
-- der Dungeon-Filter ist das Haekchen links oben (y = -56), nicht die Haekchen der Gruppen-Seite
for _, r in ipairs(made) do if r.kind == "CheckButton" and r.point and r.point[5] == -56 then check = r end end
check.checked = false
check.scripts.OnClick(check)
-- 0.6.8: im Blizzard-Aussehen ersetzt eine Auswahl mit Zaehlern das Haekchen
if M:Store().category then
    assert(d.Page.InCategory({suitable = false, min = 15}, "level") == false and d.Page.InCategory({min = 24}, "20"), "Kategorien")
    local opts = d.Page:CategoryOptions()
    assert(#opts >= 3 and opts[2].value == "all", "Auswahl mit Zaehlern")
    M:Store().category = "all"
    d.Page:Refresh()
end
local shown = 0
for _, r in ipairs(rows) do if r.shown and r.item then shown = shown + 1 end end
assert(shown == #rows, "ohne Filter ist die Liste voll")
-- Suche findet auch englische Namen
local searchBox
for _, r in ipairs(made) do if r.kind == "EditBox" and r.scripts["hook:OnTextChanged"] then searchBox = r end end
searchBox.text = "deadmines"
searchBox.scripts["hook:OnTextChanged"]()
assert(rows[1].shown and rows[1].item.key == "dm" and not rows[2].shown)
searchBox.text = ""
-- 4) Kachel
local tileBody = ONE.Kit:Stack(Region("Frame"), 0, 0, 120, 4)
tileBody.Action = function() end
local refreshTile = d.Page:Tile(Region("Frame"), tileBody)
refreshTile()
-- Termin-Fenster: oeffnen fuer jede Art, Felder fuellen sich, Ankuendigen geht nur mit Pflichtangaben
assert(d.TripsPlanner.frame, "Termin-Fenster gebaut")
for _, k in ipairs(d.Trips.kinds) do d.TripsPlanner:Open(k.key) end
d.TripsPlanner:Open("dungeon")
assert(d.TripsPlanner.state.kind == "dungeon" and d.TripsPlanner.state.key)
d.TripsPlanner:Open()
assert(d.TripsPlanner.state.kind == nil and d.TripsPlanner:Missing(d.TripsPlanner.state) ~= nil)
print("OK: 0.4.6b - Dungeons: Katalog, Lizenz, Fraktion/Klasse, Status, Titel, Seite, Hinfuehren, Kachel")
