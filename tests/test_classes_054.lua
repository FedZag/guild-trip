-- Offline-Test 0.5.4: Klassen-Ratgeber (Priester).
local root = arg[1] or "src"
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetText(t) self.text = t end
    function r:SetTexture(t) self.texture = t end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:SetPoint(...) self.point = {...} end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    function r:GetFrameLevel() return 1 end
    function r:SetColorTexture(...) self.color = {...} end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")

local ONE = {db = {}, modules = {}}
_G.ProjectONE = ONE
local tabs = {}
ONE.UI = {AddTab = function(_, id, title, builder) tabs[id] = {title = title, refresh = builder(Region("Frame"))} return true end,
    -- 0.6.9: Situation in Optionen › Klasse; Ausrichtung nur noch auf der Seite (nicht doppelt)
    AddSetting = function(_, o)
        assert(o.id ~= "classSpec", "Spielstil nicht doppelt in den Optionen")
        if o.id == "classSituation" then assert(o.category == "classes") ONE.sit = o end
        return true end}
ONE.Kit = {List = function(_, parent, opts)
        assert(parent, "Liste ohne Elternfenster")
        local l = Region("Frame", parent)
        function l:SetItems(items) self.items = items end
        ONE.lists = ONE.lists or {}
        ONE.lists[#ONE.lists + 1] = {list = l, opts = opts}
        return l end,
    Dropdown = function(_, parent, opts)
        assert(parent, "Auswahlfeld ohne Elternfenster")
        -- erstes Auswahlfeld = Ausrichtung (ONE.dd), zweites = Situation (ONE.sit)
        if not ONE.dd then ONE.dd = opts elseif not ONE.sit then ONE.sit = opts else ONE.pageDD = opts end
        return {frame = Region("Frame", parent)} end,
    Check = function(_, parent, opts)
        assert(parent, "Haekchen ohne Elternfenster: " .. tostring(opts.label))
        ONE.checks = ONE.checks or {}
        ONE.checks[opts.label] = opts
        if opts.label == "Leisten automatisch aktuell halten" then ONE.check = opts end
        local b = Region("CheckButton", parent)
        function b:Refresh() self.checked = opts.get() end return b end}
local buttons = {}
ONE.Widgets = {
    NaviArrow = function(_, parent, size, point, x, y, cb, tip)
        local b = Region("Button", parent); b:SetScript("OnClick", cb); b.tip = tip; return b end,
    Button = function(_, parent, text, w, h, point, x, y, cb) assert(parent, "Knopf ohne Elternfenster: " .. tostring(text)) local b = Region("Button", parent); b.text = text; b.click = cb; buttons[text] = b; return b end,
    PageHeader = function(_, parent) return Region("FontString", parent), Region("FontString", parent) end,
    EmptyState = function(_, parent) return Region("Frame", parent) end,
}
function ONE:RegisterModule(id, def) self.modules[id] = def end
local printed = {}
function ONE:Print(m) printed[#printed + 1] = m end

-- Spiel: untoter Schattenpriester, Stufe 20, Forever-API
local level = 20
UnitClass = function() return "Priester", "PRIEST" end
UnitLevel = function() return level end
local spells = {
    [8092] = "Gedankenschlag", [8102] = "Gedankenschlag", [589] = "Schattenwort: Schmerz", [970] = "Schattenwort: Schmerz",
    [2944] = "Verschlingende Seuche", [15407] = "Gedankenschinden", [5019] = "Schießen", [1243] = "Machtwort: Seelenstärke",
    [588] = "Inneres Feuer", [17] = "Machtwort: Schild", [1277324] = "Dunkles Opfer", [8122] = "Psychischer Schrei",
    [586] = "Verblassen", [15270] = "Willensentzug", [15275] = "Verb. Schmerz", [15273] = "Verb. Gedankenschlag",
    [15260] = "Schattenfokus", [14914] = "Heiliges Feuer", [139] = "Erneuerung", [2061] = "Blitzheilung",
    [15473] = "Schattengestalt", [14524] = "Zauberstab-Spezialisierung", [15286] = "Vampirumarmung",
    [585] = "Heilige Pein", [20577] = "Kannibalismus",
}
C_Spell = {GetSpellInfo = function(id) return spells[id] and {name = spells[id], iconID = id} end}
local book = {8092, 8102, 589, 970, 2944, 5019, 1243, 588, 17, 1277324, 8122, 586, 139, 14914, 585}
Enum = {SpellBookSpellBank = {Player = 0}}
-- Reiter 1 "Allgemein" (Volksfaehigkeit), Reiter 2 Klassenzauber
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(t)
        if t == 1 then return {itemIndexOffset = 0, numSpellBookItems = 1} end
        return {itemIndexOffset = 1, numSpellBookItems = #book}
    end,
    GetSpellBookItemInfo = function(i)
        local id = i == 1 and 20577 or book[i - 1]
        return {spellID = id, name = spells[id], iconID = id}
    end,
}
-- Talentbaum: Disziplin x~1000-2800, Heilig x~5000-6800, Schatten x~9000-10900
local nodes = {
    {spell = 14524, x = 1620, y = 2130, ranks = 0, max = 2, canBuy = true},
    {spell = 15260, x = 9080, y = 2130, ranks = 5, max = 5, canBuy = false},
    {spell = 15270, x = 10280, y = 2130, ranks = 0, max = 5, canBuy = true},
    {spell = 15273, x = 9080, y = 2730, ranks = 4, max = 5, canBuy = true},
    {spell = 15275, x = 10280, y = 2730, ranks = 2, max = 2, canBuy = false},
    {spell = 14914, x = 5020, y = 2130, ranks = 0, max = 1, canBuy = true},
    {spell = 15473, x = 9680, y = 5730, ranks = 0, max = 1, canBuy = false},
    {spell = 14889, x = 9280, y = 21300, ranks = 0, max = 5, canBuy = false}, -- Ausreisser (ignorieren)
}
C_ClassTalents = {GetActiveConfigID = function() return 1 end}
C_Traits = {
    GetConfigInfo = function() return {treeIDs = {9}} end,
    GetTreeNodes = function() local ids = {} for i = 1, #nodes do ids[i] = i end return ids end,
    GetNodeInfo = function(_, i) local n = nodes[i]; return {entryIDs = {i}, ranksPurchased = n.ranks, maxRanks = n.max,
        posX = n.x, posY = n.y, canPurchaseRank = n.canBuy} end,
    GetEntryInfo = function(_, e) return {definitionID = e} end,
    GetDefinitionInfo = function(d) return {spellID = nodes[d].spell} end,
}
local wand = 4567
GetInventoryItemID = function(_, slot) return slot == 18 and wand or nil end

local toc = assert(io.open(root .. "/ONE_Classes/ONE_Classes.toc")):read("*a")
assert(toc:find("## Interface: 16001", 1, true) and toc:find("## Dependencies: ONE_Core", 1, true))
local c = {}
for name in toc:gmatch("\n([%w_]+%.lua)") do assert(loadfile(root .. "/ONE_Classes/" .. name))("ONE_Classes", c) end
c.Player.maxAge = 0 -- Test aendert Zauber/Talente ohne Spielereignisse: Zwischenspeicher aus
ONE.modules.classes.Initialize(ONE.modules.classes, ONE)
assert(tabs.classes and tabs.classes.title == "Klasse", "Reiter angelegt")

-- 1) Spieler lesen
local p = c.Player:Read(nil)
assert(p.classFile == "PRIEST" and p.level == 20)
assert(p.points[1] == 0 and p.points[2] == 0 and p.points[3] == 11, "Punkte je Baum (Ausreisser ignoriert)")
assert(p.spec == 3 and p.autoSpec == 3, "Schatten erkannt")
assert(p:Spell(589).id == 970 and p:Spell(589).known, "hoechster Rang aus dem Zauberbuch")
assert(not p:Knows(15407), "Gedankenschinden noch nicht gelernt")

-- 2) Seite: Kopf und Leisten
local Page = c.Page
tabs.classes.refresh()
assert(Page.heading.text == "Priester · Stufe 20" and Page.sub.text == "Schatten · Leveln · 11 Talentpunkte", Page.sub.text)
-- Situationen: Automatisch erkennt die Instanz; Plaetze bleiben, Ablauf/Werte/Tipp aendern sich
local soloFlow = Page.flowFull
local soloBar = {}
for i, icon in ipairs(Page.bars[1].icons) do soloBar[i] = icon.spellID end
IsInInstance = function() return true, "party" end
tabs.classes.refresh()
assert(Page.sub.text == "Schatten · Dungeon · 11 Talentpunkte", Page.sub.text)
assert(Page.flowFull:find("Tank zieht zuerst", 1, true) and Page.flowFull ~= soloFlow, "Dungeon-Ablauf")
assert(Page.stats.text == "Intelligenz › Ausdauer › Willenskraft" and Page.tip.text:find("Im Dungeon", 1, true))
for i, icon in ipairs(Page.bars[1].icons) do assert(icon.spellID == soloBar[i], "Plaetze bleiben gleich") end
local opts = ONE.sit.options()
assert(opts[1].text == "Automatisch (Dungeon)" and #opts == 4)
ONE.sit.set("raid")
tabs.classes.refresh()
assert(Page.sub.text:find("Raid", 1, true) and Page.flowFull:find("Schattengestalt", 1, true))
ONE.sit.set("solo")
tabs.classes.refresh()
assert(Page.sub.text:find("Leveln", 1, true) and Page.flowFull == soloFlow, "von Hand: Leveln trotz Instanz")
ONE.sit.set(nil)
IsInInstance = function() return false end
tabs.classes.refresh()
assert(Page.sub.text:find("Leveln", 1, true))
local function BarText(card)
    local out = {}
    for _, icon in ipairs(card.icons) do
        if icon.shown then out[#out + 1] = (icon.key.text or "") .. ":" .. icon.spellID .. (icon.later and "(bald)" or "") end
    end
    return table.concat(out, ",")
end
assert(Page.bars[1].title.text == "Leiste 1 · Kampf" and Page.bars[1].note.text == "Tasten 1–8")
assert(BarText(Page.bars[1]) == "1:17,2:970,3:2944,4:8102,5:15286(bald),6:15407(bald),7:5019,8:15473(bald)", BarText(Page.bars[1]))
assert(Page.bars[2].title.text == "Leiste 2 · Notfall & Heilung" and Page.bars[3].title.text == "Leiste 3 · Hilfe")
assert(Page.bars[2].icons[1].spellID == 1277324 and Page.bars[2].icons[1].key.text == "", "Leiste 2 ohne Tastenzahl")
assert(Page.flowFull == "Vorher: Seelenstärke, Inneres Feuer, ab 40 Schattengestalt · 1 vorher · 2 · 3 · 4 · 5 · 6 Füller · Mana: 7", Page.flowFull)
-- Ablauf als Symbole: Schild (4) vorher › Gedankenschlag (1) Start › Schmerz (2) › Schinden (3) bis tot › Zauberstab (5) Mana knapp
local flowIcons = {}
for i = 1, Page.flowRow.used.icons do flowIcons[i] = Page.flowRow.icons[i].spellID end
assert(table.concat(flowIcons, ",") == "1243,588", table.concat(flowIcons, ","))
local flowTexts = {}
for i = 1, Page.flowRow.used.texts do flowTexts[i] = Page.flowRow.texts[i].text end
assert(table.concat(flowTexts, "|") == "Buffs:|||Ablauf:|1|vorher|›|2|›|3|›|4|›|5|›|6|Füller|›|7|Mana", table.concat(flowTexts, "|"))
-- Zerlegen einzelner Schritte
local P = c.Page.ParseStep
local pos, label = P("6 oder 5 von hinten", 8)
assert(pos[1] == 6 and pos[2] == 5 and label == "von hinten")
pos, label = P("nah: 7 und 8", 8)
assert(pos[1] == 7 and pos[2] == 8 and label == "nah")
pos, label = P("2 bis 3–5 Punkte", 8)
assert(#pos == 1 and pos[1] == 2 and label == "bis 3–5 Punkte", "3–5 sind keine Plaetze")
pos, label = P("Heilen: Leiste 2", 8)
assert(#pos == 0 and label == "Heilen: Leiste 2")
pos, label = P("6 unter 20 %", 8)
assert(pos[1] == 6 and label == "unter 20 %")
pos, label = P("9 zu gross", 8)
assert(#pos == 0 and label == "9 zu gross", "nur vorhandene Plaetze")
assert(Page.talentName.text == "Willensentzug" and Page.talentRank.text == "Rang 0 / 5", "naechster Talentpunkt")
assert(Page.trainer.text == "Stufe 22" and Page.stats.text == "Willenskraft › Intelligenz › Ausdauer")
assert(Page.gearNote.text == "", "Zauberstab vorhanden")
assert(Page.tip.text:find("Willensentzug zuerst"), "Tipp passt")
-- Tooltip zeigt den eigenen Rang; ausgegraute Plaetze sagen "noch nicht gelernt"
local shown, extra
GameTooltip = {SetOwner = function() end, SetSpellByID = function(_, id) shown = id end, Show = function() end,
    Hide = function() end, AddLine = function(_, t) extra = t end}
Page.bars[1].icons[2].scripts.OnEnter(Page.bars[1].icons[2])
assert(shown == 970 and extra == nil, "Tooltip mit eigenem Rang")
Page.bars[1].icons[5].scripts.OnEnter(Page.bars[1].icons[5])
assert(extra and extra:find("Noch nicht gelernt"))
-- ausgeblendete Leiste 2
MultiBarBottomLeft = {IsShown = function() return false end}
MultiBarBottomRight = {IsShown = function() return true end}
tabs.classes.refresh()
assert(Page.bars[2].note.text:find("ausgeblendet") and Page.bars[3].note.text == "")

-- Nicht eingeplant (Schatten): Heiliges Feuer, Heilige Pein; Volksfaehigkeit nicht
local un = {}
for _, icon in ipairs(Page.unused) do if icon.shown then un[#un + 1] = icon.spellID end end
table.sort(un)
assert(table.concat(un, ",") == "585,14914" and Page.unusedLabel.shown, table.concat(un, ","))

-- Haekchen "Zauberdaten teilen": nur sichtbar, wenn ein Entwickler online ist
-- (seit 0.6.1: steht nur noch in Optionen › Teilen / Spielhilfen, nicht mehr auf der Seite)
assert(Page.shareCheck == nil and Page.autoRank == nil, "Haekchen nicht mehr auf der Klassenseite")
c.Share:Receive("ONECLS1", "HELLO", "GUILD", "Entwickler-Forever")
c.Share.dev = nil
tabs.classes.refresh()

-- 2b) Talentbaum-Ansicht
buttons["Talente"].click()
assert(Page.treeView.shown and not Page.barView.shown, "Talente-Ansicht")
local byspell = {}
for _, node in ipairs(Page.treeView.nodes) do if node.shown then byspell[node.talent.spell] = node end end
local count = 0
for _ in pairs(byspell) do count = count + 1 end
assert(count == 7 and not byspell[14889], "7 Talente, Ausreisser ignoriert")
assert(byspell[15270].border.color[1] == 1 and byspell[15270].border.color[2] == .82, "naechster Punkt gold")
assert(byspell[15260].border.color[2] == .85 and byspell[15260].rank.text == "5/5", "gesetzt gruen")
assert(byspell[15270].order.text:find("1") and byspell[15270].planText == "Plan: Schritt 1, bis Rang 5")
assert(byspell[14524].order.text == "" and byspell[14524].planText == nil, "nicht im Plan")
-- Lage: Schatten-Spalten 0..2 rechts, Reihen nach y
local swp, mb = byspell[15275], byspell[15273]
assert(swp.point[4] > mb.point[4] and swp.point[5] == mb.point[5], "gleiche Reihe, Spalten nach x")
assert(byspell[15473].point[5] < swp.point[5], "Schattengestalt weiter unten")
assert(byspell[14524].point[4] < byspell[14914].point[4] and byspell[14914].point[4] < mb.point[4], "Baeume nebeneinander")
assert(Page.treeView.headers[3].text:find("Schatten · 11") and Page.treeView.headers[1].text:find("Disziplin · 0"))
local tipLine
GameTooltip.AddLine = function(_, t) tipLine = t end
byspell[15270].scripts.OnEnter(byspell[15270])
assert(shown == 15270, "Tooltip zeigt Talent")
-- 2c) Bewaffnung: Priester-Waffen in der Liste, Ansicht exklusiv
buttons["Bewaffnung"].click()
assert(Page.weaponView.shown and not Page.barView.shown and not Page.treeView.shown, "Bewaffnung-Ansicht")
local wl = Page.weaponView.list.items
assert(wl and #wl == 4 and wl[1].key == "mace1" and wl[4].key == "wand", "Priester: 4 Waffenarten")
assert(Page.weaponView.info.text and Page.weaponView.info.text ~= "")
-- Navi nur ueber den eigenen Knopf, nicht beim Klick auf die Zeile
local wlist
for _, l in ipairs(ONE.lists) do if l.list == Page.weaponView.list then wlist = l.opts end end
assert(wlist and wlist.onClick == nil, "Zeilenklick startet kein Navi")
local navTo
ONE.modules.nav = {PointTo = function(_, label, map) navTo = {label, map} return true end}
local frame = Region("Frame")
local cells = {name = Region("FontString"), state = Region("FontString"), trainer = Region("FontString")}
wlist.render(frame, {weapon = c.Weapons.byKey.staff, known = false, trainer = {npc = "Hanashi", map = 1454, x = .8, y = .2, area = "Orgrimmar, Tal der Ehre"}}, cells)
assert(frame.navi and frame.navi.shown and cells.trainer.text:find("^Hanashi  ·  Orgrimmar"), cells.trainer.text)
frame.navi.scripts.OnClick(frame.navi)
assert(navTo and navTo[1] == "Hanashi" and navTo[2] == 1454, "Navi-Knopf fuehrt zum Lehrer")
wlist.render(frame, {weapon = c.Weapons.byKey.wand, known = true}, cells)
assert(not frame.navi.shown, "ohne Lehrer kein Navi-Knopf")
ONE.modules.nav = nil
buttons["Leisten"].click()
assert(Page.barView.shown and not Page.treeView.shown and not Page.weaponView.shown)

-- 3) Leisten einrichten und zurueck
-- Makro 7 wirkt Gedankenschlag (liegt auf Platz 1), Makro 8 wirkt Schmerz und liegt auf Platz 20,
-- Makro 9 auf Platz 5 wirkt nichts Bekanntes.
local actions = {[1] = {"macro", 7}, [5] = {"macro", 9}, [20] = {"macro", 8}, [61] = {"item", 6948},
    [30] = {"spell", 14914}, [31] = {"spell", 20577}}
GetMacroSpell = function(i) return (i == 7 and 8092) or (i == 8 and 589) or nil end
local function Said(text) for i = #printed, math.max(1, #printed - 8), -1 do if printed[i]:find(text, 1, true) then return true end end end
local cursor
GetActionInfo = function(slot) local a = actions[slot]; if a then return a[1], a[2] end end
C_Spell.PickupSpell = function(id) cursor = {"spell", id} end
PickupMacro = function(id) cursor = {"macro", id} end
PickupItem = function(id) cursor = {"item", id} end
PickupAction = function(slot) cursor = actions[slot]; actions[slot] = nil end
PlaceAction = function(slot) local old = actions[slot]; actions[slot] = cursor; cursor = old end
ClearCursor = function() cursor = nil end
InCombatLockdown = function() return false end
local accepted
StaticPopupDialogs = {}
StaticPopup_Show = function(name) accepted = StaticPopupDialogs[name] end
buttons["Leisten einrichten"].click()
assert(accepted and accepted.text:find("Rückgängig"), "Rueckfrage")
accepted.OnAccept()
-- Leiste in Ablauf-Reihenfolge: 1 Schild, 2 Schmerz, 3 Seuche, 4 Gedankenschlag, 5 Umarmung (ungelernt), 6 Füller (ungelernt), 7 Zauberstab
assert(actions[1][2] == 17 and actions[2][1] == "macro" and actions[2][2] == 8 and actions[4][1] == "macro" and actions[4][2] == 7
    and actions[20] == nil and actions[6] == nil,
    "Gedankenschlag-Makro wandert von 1 auf 4, Schmerz-Makro von 20 auf 2, ungelernte Plaetze bleiben frei")
assert(Said("2 Makros auf den Platz ihres Zaubers verschoben"), "Hinweis verschoben")
assert(Said("2 Zauber nutzen dein vorhandenes Makro"), "Makros genutzt")
assert(actions[30] == nil and actions[31][2] == 20577, "nicht eingeplanter Klassenzauber weg, Volksfaehigkeit bleibt")
assert(Said("1 nicht eingeplante Zauber von den Leisten genommen"), "Hinweis aufgeraeumt")
assert(ONE.db.classGuide.backup[30].id == 14914, "aufgeraeumter Platz gesichert")
assert(actions[3][2] == 2944 and actions[5][1] == "macro" and actions[7][2] == 5019 and actions[61][2] == 1277324,
    "fremdes Makro auf dem (noch ungelernten) Umarmungs-Platz bleibt liegen")
assert(actions[49][2] == 1243, "Leiste 3")
local bk = ONE.db.classGuide.backup
assert(bk[1].kind == "macro" and bk[5] == nil and bk[2].empty and bk[20].kind == "macro" and bk[61].kind == "item" and bk[4].empty, "Sicherung")
assert(Said("auf die Leisten gelegt"))
-- zweites Einrichten ueberschreibt die Sicherung nicht
accepted.OnAccept()
assert(ONE.db.classGuide.backup[61].kind == "item" and Said("schon eingerichtet"))
-- im Kampf: nichts tun
InCombatLockdown = function() return true end
assert(c.Bars:Apply(Page.player, Page:CurrentBuild(Page.player, Page.def)) == 0)
InCombatLockdown = function() return false end
-- Rueckgaengig
buttons["Rückgängig"].click()
accepted.OnAccept()
assert(actions[1][1] == "macro" and actions[1][2] == 7 and actions[61][1] == "item" and actions[4] == nil, "wiederhergestellt")
assert(actions[2] == nil and actions[20][2] == 8, "Makro wieder auf seinem alten Platz")
assert(actions[30][2] == 14914, "aufgeraeumter Zauber zurueck")
-- Seite zeigt "M" bei Zaubern mit Makro
tabs.classes.refresh()
assert(Page.bars[1].icons[4].macro.text:find("M") and Page.bars[1].icons[2].macro.text:find("M") and Page.bars[1].icons[1].macro.text == "")
extra = nil
GameTooltip.AddLine = function(_, t) extra = t end
Page.bars[1].icons[2].scripts.OnEnter(Page.bars[1].icons[2])
assert(extra and extra:find("als Makro"), "Tooltip-Hinweis Makro")
assert(not c.Bars:HasBackup())
buttons["Rückgängig"].click()
assert(printed[#printed]:find("keine gemerkte"))

-- 3b) Neue Raenge automatisch: nur bisher hoechster Rang, nie Makros, nach dem Kampf
local R = c.Ranks
ONE.check = ONE.check or {get = function() return R:Enabled() end, set = function(on) R:SetEnabled(on) end} -- Haekchen steht in Optionen › Spielhilfen
assert(not R:Enabled() and not ONE.check.get(), "Haekchen standardmaessig aus (Nutzer 19.11.2026)")
ONE.check.set(true)
assert(R:Enabled(), "einschaltbar")
R.last = nil
R:OnSpellsChanged() -- Ausgangsstand
actions = {[1] = {"spell", 8102}, [2] = {"spell", 8092}, [3] = {"macro", 7}, [13] = {"spell", 8102}}
book[#book + 1] = 8103 -- Gedankenschlag Rang 3 gelernt
spells[8103] = "Gedankenschlag"
InCombatLockdown = function() return true end
assert(R:OnSpellsChanged() == 0 and R.waiting, "im Kampf warten")
assert(actions[1][2] == 8102)
InCombatLockdown = function() return false end
assert(R:OnCombatEnded() == 2, "nach dem Kampf getauscht")
assert(actions[1][2] == 8103 and actions[13][2] == 8103, "bisher hoechster Rang ersetzt (auch andere Leisten)")
assert(actions[2][2] == 8092 and actions[3][1] == "macro", "niedriger Rang und Makro bleiben")
assert(printed[#printed] == "Gedankenschlag: neuer Rang auf 2 Leistenplätzen.", printed[#printed])
-- Forever: "Heilige Pein" Rang 1 heisst ab Rang 2 "Goettliche Pein" -> trotzdem tauschen
spells[591] = "Göttliche Pein"
actions[40] = {"spell", 585}
book[#book + 1] = 591
assert(R:OnSpellsChanged() == 1 and actions[40][2] == 591, "Pein-Rang ueber den Namenswechsel getauscht")
-- abgeschaltet: nichts tauschen
ONE.check.set(false)
book[#book + 1] = 8104; spells[8104] = "Gedankenschlag"
assert(R:OnSpellsChanged() == 0 and actions[1][2] == 8103, "aus = kein Tausch")
ONE.check.set(true)
for i = #book, 1, -1 do if book[i] == 8103 or book[i] == 8104 or book[i] == 591 then table.remove(book, i) end end
R.last = nil

-- 3c) Wie im Spieltest (Forever): Makros melden die Zauber-Nummer ("macro", id, "spell"),
--     das Schild lag zusaetzlich neben dem Schild-Makro, Leiste 2/3 voll mit Doppelten.
GetActionInfo = function(slot) local a = actions[slot]; if a then return a[1], a[2], a[3] end end
GetActionText = function(slot) local a = actions[slot]; return a and a[4] end
GetMacroSpell = function() return nil end -- die alte Abfrage ueber die Makro-Nummer liefert nichts
actions = {
    [3] = {"macro", 17, "spell", "FG Schild"},  -- Makro fuer Machtwort: Schild
    [4] = {"spell", 17},                         -- Schild-Zauber daneben (doppelt)
    [5] = {"macro", 589, "spell", "FG Pein"},    -- Makro fuer Schmerz
    [62] = {"spell", 589},                       -- Leiste 2: Schmerz (gehoert auf Leiste 1)
    [50] = {"spell", 8092},                      -- Leiste 3: Gedankenschlag (gehoert auf Leiste 1)
    [70] = {"spell", 20577},                     -- Volksfaehigkeit bleibt
    [30] = {"spell", 589},                       -- andere Leiste (nicht Guild Trip): bleibt
}
ONE.db.classGuide.backup = {}
local placed, macros, used, removed, dups, moved = c.Bars:Apply(Page.player, Page:CurrentBuild(Page.player, Page.def))
-- Ablauf-Reihenfolge: 1 Schild, 2 Schmerz, 3 Seuche, 4 Gedankenschlag, 5/6 ungelernt frei, 7 Zauberstab
assert(actions[1][1] == "macro" and actions[1][4] == "FG Schild", "Schild-Makro auf Platz 1")
assert(actions[2][1] == "macro" and actions[2][4] == "FG Pein", "Schmerz-Makro auf Platz 2")
assert(actions[3][2] == 2944 and actions[4][2] == 8102 and actions[5] == nil and actions[6] == nil, "Seuche 3, Gedankenschlag 4, ungelernt frei")
assert(actions[7][2] == 5019, "Zauberstab bekommt seinen Platz 7")
assert(moved == 2, "zwei Makros verschoben")
assert(actions[62][2] == 8122 and actions[50][2] == 588, "Plaetze neu belegt")
assert(actions[70][2] == 20577 and actions[30][2] == 589, "Volksfaehigkeit und fremde Leisten bleiben")
assert(dups == 3 and used == 2, ("doppelt %s, Makros genutzt %s"):format(tostring(dups), tostring(used)))
-- Rueckgaengig holt alles zurueck
c.Bars:Undo()
assert(actions[4][2] == 17 and actions[62][2] == 589 and actions[50][2] == 8092 and actions[1] == nil, "zurueck")
assert(actions[3][1] == "macro" and actions[3][2] == "FG Schild" and actions[5][1] == "macro" and actions[2] == nil,
    "Makros ueber ihren Namen an den alten Platz")
-- Altes Verhalten (Makro-Nummer + GetMacroSpell) funktioniert weiter
GetMacroSpell = function(i) return i == 7 and 17 or nil end
actions = {[3] = {"macro", 7}, [4] = {"spell", 17}}
ONE.db.classGuide.backup = {}
c.Bars:Apply(Page.player, Page:CurrentBuild(Page.player, Page.def))
assert(actions[1][1] == "macro" and actions[1][2] == 7 and actions[3][2] == 2944, "auch mit Makro-Nummer erkannt und verschoben")
GetActionText, GetMacroSpell = nil, nil
-- Disziplin: Schild steht auf Leiste 1 (Platz 1, Ablauf-Reihenfolge) und Leiste 2 (Platz 61) – das
-- Makro wandert einmal auf Platz 1 und bleibt dort, auf 61 kommt kein zweiter Schild-Zauber.
GetMacroSpell = function(i) return i == 7 and 17 or nil end
actions = {[10] = {"macro", 7}}
ONE.db.classGuide.backup = {}
c.Bars:Apply(Page.player, Page:CurrentBuild(Page.player, Page.def).bars and c.Data.classes.PRIEST.build[1])
assert(actions[1][1] == "macro" and actions[10] == nil and actions[61] == nil, "Makro einmal verschoben, kein Doppel")
GetMacroSpell = nil

-- 3d) Neu gelernte, eingeplante Zauber kommen automatisch auf ihren freien Platz
local R2 = c.Ranks
GetMacroSpell, GetActionText = nil, nil
actions = {}
ONE.db.classGuide.backup = {}
ONE.db.classGuide.managed = nil
R2.last = nil
R2:OnSpellsChanged() -- Ausgangsstand merken
-- a) noch nie "Leisten einrichten" benutzt: nichts passiert
book[#book + 1] = 15407
assert(R2:OnSpellsChanged() == 0 and actions[6] == nil, "ohne Einrichten keine Automatik")
table.remove(book)
R2:OnSpellsChanged()
-- b) nach dem Einrichten: Gedankenschinden landet auf Taste 6
c.Bars:Apply(Page.player, Page:CurrentBuild(Page.player, Page.def))
assert(ONE.db.classGuide.managed == true and actions[6] == nil)
book[#book + 1] = 15407
assert(R2:OnSpellsChanged() == 1 and actions[6][2] == 15407, "neu gelernt -> Platz 6")
assert(Said("Gedankenschinden neu auf Leiste 1 gelegt (Taste 6)."), "Hinweis im Chat")
-- c) selbst wieder entfernt: kommt beim naechsten Mal nicht zurueck (nur neu Gelerntes)
actions[6] = nil
assert(R2:OnSpellsChanged() == 0 and actions[6] == nil, "bewusst entfernt bleibt weg")
table.remove(book)
R2:OnSpellsChanged()
-- d) Platz belegt oder schon auf einer anderen Leiste: nichts ueberschreiben, nichts doppeln
actions[6] = {"item", 6948}
book[#book + 1] = 15407
assert(R2:OnSpellsChanged() == 0 and actions[6][1] == "item", "belegter Platz bleibt")
table.remove(book)
R2:OnSpellsChanged()
actions[6] = nil
actions[40] = {"spell", 15407}
book[#book + 1] = 15407
assert(R2:OnSpellsChanged() == 0 and actions[6] == nil, "schon auf einer Leiste")
table.remove(book)
R2:OnSpellsChanged()
actions[40] = nil
-- e) im Kampf gelernt: erst danach
InCombatLockdown = function() return true end
book[#book + 1] = 15407
assert(R2:OnSpellsChanged() == 0 and actions[6] == nil)
InCombatLockdown = function() return false end
assert(R2:OnCombatEnded() == 1 and actions[6][2] == 15407, "nach dem Kampf gelegt")
table.remove(book)
R2:OnSpellsChanged()
-- f) Haekchen aus: nichts
actions[6] = nil
ONE.check.set(false)
book[#book + 1] = 15407
assert(R2:OnSpellsChanged() == 0 and actions[6] == nil, "Haekchen aus")
ONE.check.set(true)
table.remove(book)
R2.last = nil
actions = {}

-- 4) Gedankenschinden gelernt, Willensentzug voll, kein Zauberstab
book[#book + 1] = 15407
nodes[3].ranks = 5
wand = nil
tabs.classes.refresh()
assert(BarText(Page.bars[1]):find("6:15407,", 1, true), "Platz 6 jetzt belegt")
assert(Page.talentName.text == "Verb. Gedankenschlag" and Page.talentRank.text == "Rang 4 / 5", "Plan geht weiter")
assert(Page.gearNote.text:find("Kein Zauberstab"), "Hinweis ohne Zauberstab")
assert(Page.tip.text:find("Dunkles Opfer"), "naechster Tipp")

-- 5) Ausrichtung von Hand: Heilig -> Leiste 2 Heilung, jetzt mit Talentplan
ONE.dd.set(2)
tabs.classes.refresh()
assert(Page.sub.text:find("Heilig") and Page.bars[2].title.text == "Leiste 2 · Heilung & Notfall")
assert(Page.bars[2].icons[1].spellID == 139 and Page.talentName.text ~= "Plan folgt")
local unHoly = {}
for _, icon in ipairs(Page.unused) do if icon.shown then unHoly[#unHoly + 1] = icon.spellID end end
assert(table.concat(unHoly, ",") == "15407", "Heilig: nur Gedankenschinden nicht eingeplant (" .. table.concat(unHoly, ",") .. ")")
ONE.dd.set(nil)

-- 6) Niedrige Stufe und Lehrer
level = 8
tabs.classes.refresh()
assert(Page.talentName.text == "Ab Stufe 10" and Page.trainer.text == "Stufe 10")
assert(c.Data:NextTrainerLevel(59) == 60 and c.Data:NextTrainerLevel(60) == nil and c.Data:NextTrainerLevel(21) == 22)

-- 7) Andere Klassen haben jetzt eigene Plaene (Magier: Frost als Standard, ohne Talentplan)
UnitClass = function() return "Magier", "MAGE" end
tabs.classes.refresh()
assert(Page.content.shown and not Page.empty.shown, "Magier-Seite")
assert(Page.heading.text == "Magier · Stufe 8" and Page.sub.text:find("Frost", 1, true), Page.sub.text)
assert(Page.bars[1].title.text == "Leiste 1 · Kampf" and Page.talentName.text == "Ab Stufe 10")
-- Unbekannte Klasse: weiterhin Hinweis
UnitClass = function() return "Todesritter", "DEATHKNIGHT" end
tabs.classes.refresh()
assert(Page.empty.shown and not Page.content.shown, "Hinweis fuer unbekannte Klassen")
print("OK test_classes_054")
-- Spielstil-Auswahl auf der Klassen-Seite: Vor-/Nachteile als Tooltip je Eintrag
UnitClass = function() return "Magier", "MAGE" end
local so = Page:SpecOptions()
assert(so[1].value == nil and so[1].tooltip and #so == 4 and so[2].tooltip:find("Arkaner Zorn", 1, true), "automatisch + drei Spielstile mit Vor-/Nachteilen")
print("OK test_classes_054 (Spielstil-Auswahl)")
