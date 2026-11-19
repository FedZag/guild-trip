-- Offline-Test 19.11.2026: Bosse und Beute (BossData aus Dungeon Codex, Bosses.lua, Umschalter auf der Dungeon-Seite).
-- (Spielattrappe wie test_dungeons_page_046)
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
local B, BD = d.Bosses, d.BossData

-- 1) Daten: genau die vier Forever-Dungeons aus Dungeon Codex, mit Herkunft
assert(BD and BD.source.name == "Dungeon Codex" and BD.source.version and BD.source.license:find("GPL-3.0-or-later", 1, true))
local catalog = {}
for _, e in ipairs(d.Catalog) do catalog[e.key] = e end
local keys = 0
for key, list in pairs(BD) do
    if key ~= "source" then
        keys = keys + 1
        assert(catalog[key], "Schluessel nicht im Katalog: " .. key)
        assert(#list > 0)
        for _, b in ipairs(list) do
            assert(type(b.npc) == "number" and type(b.name) == "string" and #b.items > 0, "Boss unvollstaendig")
            for _, id in ipairs(b.items) do assert(type(id) == "number" and id > 0) end
        end
    end
end
assert(keys == 4 and B:For("thanes") and B:For("ruins") and B:For("excavation") and B:For("dalaran"))
assert(#B:For("dalaran") == 8 and #B:For("ruins") == 7)
assert(B:For("drowned") == nil and B:For("source") == nil and B:For(nil) == nil)
-- klassische Dungeons aus classic-db, jeder Katalog-Dungeon ausser den 5 neuen hat Bosse
local CD = d.BossDataClassic
assert(CD and CD.source.license == "GPL-3.0")
for _, e in ipairs(d.Catalog) do
    local list, from = B:For(e.key)
    local new = ({drowned = 1, krol = 1, alcaz = 1, blackmaw = 1, shaper = 1})[e.key]
    if new then assert(not list, "noch keine Daten: " .. e.key) else assert(list, "Bosse fehlen: " .. e.key) end
    if list and not BD[e.key] then assert(from == "BossDataClassic" and CD[e.key]) end
end
local vc = B:For("dm")[#B:For("dm")]
assert(vc.name == "Edwin VanCleef" and vc.de == "Edwin van Cleef" and vc.encounter == 167 and vc.drops[vc.items[1]] > 0)
assert(#B:For("lbrs") == 9 and #B:For("ubrs") == 5 and #B:For("dmn") == 7 and #B:For("stratud") == 6, "Fluegel getrennt")
assert(B:Credit("dm"):find("classic-db", 1, true) and B:Credit("ruins"):find("Dungeon Codex", 1, true))
-- Sieg ueber den Encounter (Roster.bosses) zaehlt auch
local keepRoster = ONE.db.dungeons.roster
ONE.db.dungeons.roster = {dm = {npcs = {}, bosses = {[167] = "Edwin VanCleef"}, runs = 1}}
assert(B:Killed("dm", vc))
ONE.db.dungeons.roster = keepRoster

-- 2) Namen: Englisch, Deutsch aus den Daten, im Spiel gesammelter Name gewinnt
local welk = B:For("ruins")[1]
ONE.Language = function() return "en" end
assert(B:Name("ruins", welk) == "Witherfang")
ONE.Language = function() return "de" end
assert(B:Name("ruins", welk) == "Welkzahn")
assert(not B:Killed("ruins", welk))
ONE.db.dungeons = ONE.db.dungeons or {}
ONE.db.dungeons.roster = {ruins = {npcs = {[welk.npc] = {name = "Welkzahn (Spiel)", n = 2, boss = true}}, bosses = {}, runs = 1}}
assert(B:Name("ruins", welk) == "Welkzahn (Spiel)" and B:Killed("ruins", welk))

-- 3) Gegenstand: Name/Qualitaet/Art aus dem Spiel, sonst Nummer und Nachladen
local loads = {}
_G.INVTYPE_HEAD = "Kopf"
C_Item = {
    RequestLoadItemDataByID = function(id) loads[#loads + 1] = id end,
    GetItemInfoInstant = function(id) return id, "Rüstung", "Leder", "INVTYPE_HEAD", 134001 end,
}
GetItemInfo = function(id) if id == 271201 then return "Welkhaube", "|cff1eff00|Hitem:271201|h[Welkhaube]|h|r", 2 end end
local it = B.Item(271201)
assert(it.name == "Welkhaube" and it.quality == 2 and it.kind == "Kopf · Leder" and it.icon == 134001)
assert(B.Colored(it) == "|cff1eff00Welkhaube|r")
local unknown = B.Item(271202)
assert(unknown.name == nil and loads[#loads] == 271202 and B.Colored(unknown):find("#271202", 1, true))

-- 4) Seite: Umschalter nur bei Dungeons mit Bossdaten, Bossliste + Beute + Nennung
M:Store().category = "all"
tabs.dungeons()
local function Find(pred) for _, r in ipairs(made) do if pred(r) then return r end end end
local function All(pred) local t = {} for _, r in ipairs(made) do if pred(r) then t[#t + 1] = r end end return t end
local dungeonRows = All(function(r) return r.kind == "Button" and r.cells and r.cells.open end)
local function Select(key)
    -- die Seite kann mehrfach gebaut sein (Buch/Fenster): Suchtext in alle Suchfelder
    local boxes = All(function(r) return r.kind == "EditBox" and r.scripts["hook:OnTextChanged"] and r.point and r.point[5] == -30 end)
    for _, box in ipairs(boxes) do box.text = key end
    boxes[#boxes].scripts["hook:OnTextChanged"]()
    for _, r in ipairs(dungeonRows) do if r.item and r.item.key == key then r.scripts.OnClick(r, "LeftButton") return true end end
end
local viewBtn = Find(function(r) return r.kind == "Button" and r.point and r.point[1] == "TOPRIGHT" and r.point[5] == -75 end)
assert(viewBtn, "Umschalter fehlt")
assert(Select("drowned"))
assert(not viewBtn.shown, "ohne Bossdaten kein Umschalter")
assert(Select("dalaran"))
assert(viewBtn.shown, "Dalaran hat Bosse")
viewBtn.scripts.OnClick(viewBtn, "LeftButton")
local bossRows = All(function(r) return r.kind == "Button" and r.cells and r.cells.name and not r.cells.open and not r.cells.tag and r.parent and r.parent.w == d.Bosses.BOSS_W end)
assert(bossRows[1].shown and bossRows[1].item == B:For("dalaran")[1], "Bossliste zeigt Dalaran")
assert(bossRows[1].cells.name.text:find("Atrexis der Grabritter", 1, true))
local lootRows = All(function(r) return r.kind == "Button" and r.cells and r.cells.item end)
assert(lootRows[1].shown and lootRows[1].item.id == B:For("dalaran")[1].items[1], "Beute des ersten Bosses")
assert(#lootRows >= 6 and #bossRows >= 8, "volle Hoehe: genug Zeilen")
assert(not lootRows[4].shown, "Atrexis hat 3 Teile")
-- anderen Boss waehlen
bossRows[8].scripts.OnClick(bossRows[8], "LeftButton")
assert(lootRows[4].shown and lootRows[4].item.id == 273103, "Schemen des Erzmagiers: 4 Teile")
-- Tooltip zeigt den echten Gegenstand
local tipLink
GameTooltip = setmetatable({SetHyperlink = function(_, l) tipLink = l end}, {__index = function() return function() end end})
lootRows[1].scripts.OnEnter(lootRows[1])
assert(tipLink == "item:" .. lootRows[1].item.id)
-- Umschalt+Klick verlinkt (nur mit echtem Link)
local linked
HandleModifiedItemClick = function(l) linked = l end
GetItemInfo = function(id) return "X", "|Hitem:" .. id .. "|h[X]|h", 3 end
lootRows[1].scripts.OnClick(lootRows[1], "LeftButton")
assert(linked and linked:find("item:" .. lootRows[1].item.id, 1, true))
-- Nennung von Dungeon Codex sichtbar, Questliste versteckt
assert(Find(function(r) return r.kind == "FontString" and type(r.text) == "string" and r.text:find("Dungeon Codex (Baxter", 1, true) end), "Nennung fehlt")
local qrow = Find(function(r) return r.kind == "Button" and r.cells and r.cells.tag end)
assert(qrow.parent and qrow.parent.shown == false, "Questliste in der Bossansicht versteckt")
-- Dungeon ohne Bossdaten: zurueck zu den Quests
assert(Select("drowned"))
assert(not viewBtn.shown and qrow.parent.shown and not bossRows[1].parent.shown)
assert(Find(function(r) return r.kind == "FontString" and type(r.text) == "string" and r.text:find("Sundee", 1, true) end))

-- 5) Import-Skript liest die Quelle nur als Text (kein loadstring/dofile auf fremde Dateien)
local script = assert(io.open("scripts/import_codex.lua")):read("*a")
assert(not script:find("loadstring(", 1, true) and not script:find("dofile(", 1, true) and not script:find("loadfile(", 1, true))
-- Boss ohne bekannte Beute: Hinweis statt leerer Liste
local view = {boss = {items = {}}, bossList = {Update = function() end}, lootList = {SetItems = function(_, it) view_items = it end}}
B.ShowLoot(view)
assert(view_items and #view_items == 1 and view_items[1].none, "Hinweis-Zeile")
-- 6) Beute mitschreiben (LOOT_OPENED) und anzeigen
local R = d.Roster
d.Recap.run = {key = "drowned"}
local roster = ONE.db.dungeons.roster or {}
ONE.db.dungeons.roster = roster
roster.drowned = {npcs = {[300001] = {name = "Tiefenkoenig", n = 1, boss = true}, [300002] = {name = "Fischer", n = 3}}, bosses = {}, runs = 1}
local slots = {
    {link = "|Hitem:280001::|h[Neuer Ring]|h", q = 3, src = {"Creature-0-1-2-3-300001-0000AAAA", 1}},
    {link = "|Hitem:280002::|h[Grauzeug]|h", q = 0, src = {"Creature-0-1-2-3-300001-0000AAAA", 1}},
    {link = "|Hitem:280003::|h[Trash-Gruenes]|h", q = 2, src = {"Creature-0-1-2-3-300002-0000BBBB", 1}},
}
GetNumLootItems = function() return #slots end
GetLootSlotLink = function(i) return slots[i].link end
GetLootSlotInfo = function(i) return 1, "x", 1, nil, slots[i].q end
GetLootSourceInfo = function(i) return unpack(slots[i].src) end
assert(R:OnLoot() == 1, "nur Boss-Beute ab gruen")
assert(R:OnLoot() == 0, "dieselbe Leiche zaehlt nur einmal")
local boss = roster.drowned.npcs[300001]
assert(boss.loot[280001] == 1 and boss.looted == 1 and not boss.loot[280002])
assert(not roster.drowned.npcs[300002].loot, "Trash wird nicht mitgeschrieben")
-- zweite Leiche (neuer Lauf)
slots[1].src = {"Creature-0-1-2-3-300001-0000CCCC", 1}
assert(R:OnLoot() == 1 and boss.loot[280001] == 2 and boss.looted == 2)
-- ohne mitgelieferte Daten: selbst gesammelte Bosse werden zur Liste
local list, from = B:For("drowned")
assert(from == "Roster" and #list == 1 and list[1].name == "Tiefenkoenig" and B:For("drowned", true) == nil)
assert(B:Credit("drowned"):find("selbst", 1, true) or B:Credit("drowned"):find("von dir", 1, true))
local loot = B:LootOf("drowned", list[1])
assert(#loot == 1 and loot[1].id == 280001 and loot[1].found == 2 and loot[1].looted == 2 and loot[1].own)
-- bei Dungeons mit Daten: Funde werden ergaenzt bzw. bei bekannten Teilen gezaehlt
local atrexis = B:For("dalaran")[1]
d.Recap.run = {key = "dalaran"}
roster.dalaran = {npcs = {}, bosses = {}, runs = 1}
slots = {{link = "|Hitem:" .. atrexis.items[1] .. "::|h[A]|h", q = 3, src = {"Creature-0-1-2-3-" .. atrexis.npc .. "-0000DDDD", 1}},
         {link = "|Hitem:280009::|h[B]|h", q = 4, src = {"Creature-0-1-2-3-" .. atrexis.npc .. "-0000DDDD", 1}}}
assert(R:OnLoot() == 2, "bekannter Boss aus den Daten zaehlt auch ohne Boss-Leiste")
local l2 = B:LootOf("dalaran", atrexis)
assert(#l2 == #atrexis.items + 1 and l2[1].found == 1 and l2[#l2].id == 280009 and l2[#l2].own)
d.Recap.run = nil
-- 7) Quest-Stufe aus der Questdatenbank statt Mindeststufe (Nutzer 19.11.2026)
GuildTripQuestDB = {q = {[92401] = {22, 15}, [5] = {20, 20}}}
local qx = {ids = {92401}, level = 15}
local lv, mn = M:Levels(qx)
assert(lv == 22 and mn == 15 and M:LevelText(qx):find("^22 ") and M:LevelText(qx):find("(15)", 1, true))
assert(select(2, M:Levels({ids = {5}, level = 9})) == nil and M:LevelText({ids = {5}}) == "20", "gleich: keine Klammer")
assert(M:Levels({ids = {123456}, level = 9}) == 9, "unbekannt: Wert der Dungeon-Daten")
GuildTripQuestDB = nil
assert(M:Levels(qx) == 15)
local script2 = assert(io.open("scripts/import_bosses_classic.py")):read("*a")
assert(not script2:find("exec(", 1, true) and not script2:find("eval(", 1, true))
print("OK: Bosse und Beute (4 Forever-Dungeons Dungeon Codex, Classic aus classic-db), Namen, Gegenstaende, Umschalter, Nennung")
