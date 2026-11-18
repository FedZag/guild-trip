local _, classes = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- Reiter "Klasse": wenig Text, Symbole statt Saetze, alles in Karten.
-- Links die drei Aktionsleisten (Kampf / Notfall & Heilung / Hilfe) mit festen
-- Plaetzen, rechts Talentpunkt, Lehrer und Werte. Unten ein Tipp und die
-- Knoepfe "Leisten einrichten" / "Rueckgaengig".
local Page = {}
classes.Page = Page

local W, H = 726, 437
local LEFT_W, GAP = 470, 12
local RIGHT_X = LEFT_W + GAP
local RIGHT_W = W - RIGHT_X

local function Store()
    ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    return ONE.db.classGuide
end

local function Text(parent, font, x, y, width, role, text, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(T(text or ""))
    if ONE.Themes and ONE.Themes.RegisterText then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end

local function Card(parent, x, y, width, height, title)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
    if frame.SetFrameLevel and parent.GetFrameLevel then frame:SetFrameLevel(parent:GetFrameLevel()) end
    if ONE.Themes and type(ONE.Themes.RegisterPanel) == "function" then ONE.Themes:RegisterPanel(frame) end
    if title then
        frame.title = Text(frame, "GameFontNormal", 12, -10, width - 24, "accent", title)
        if ONE.Themes and ONE.Themes.PanelTitle then ONE.Themes:PanelTitle(frame, frame.title) end
    end
    return frame
end

-- Zauber-Symbol mit Blizzard-Tooltip (echte Werte des eigenen Rangs).
local function NewIcon(parent, size, labelWidth)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints(b)
    if b.tex.SetTexCoord then b.tex:SetTexCoord(.07, .93, .07, .93) end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    if hl.SetTexture then hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square") end
    if hl.SetBlendMode then hl:SetBlendMode("ADD") end
    b.key = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.key:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.macro = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.macro:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -3)
    b.label:SetWidth(labelWidth or (size + 14))
    b.label:SetJustifyH("CENTER")
    if b.label.SetWordWrap then b.label:SetWordWrap(false) end
    b:SetScript("OnEnter", function(self)
        if not self.spellID or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID) then GameTooltip:SetText(self.name or "?") end
        if self.later and GameTooltip.AddLine then GameTooltip:AddLine(T("Noch nicht gelernt – der Platz bleibt frei."), 1, .5, .5) end
        if self.macroSlot and GameTooltip.AddLine then
            GameTooltip:AddLine(T("Liegt schon als Makro auf deiner Leiste – das Makro bleibt und wird genutzt."), .4, 1, .4, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

local function SetIcon(icon, spell, label, key)
    icon.tex:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    if icon.tex.SetDesaturated then icon.tex:SetDesaturated(not spell.known) end
    if icon.SetAlpha then icon:SetAlpha(spell.known and 1 or .45) end
    icon.spellID, icon.name, icon.later = spell.spellID or spell.id, spell.name, not spell.known
    icon.label:SetText(T(label or ""))
    icon.key:SetText(key or "")
    icon.macroSlot = spell.known and spell.macroSlot or nil
    icon.macro:SetText(icon.macroSlot and "|cffffd100M|r" or "")
    icon:Show()
end

-- Eine Aktionsleiste als Karte: feste Plaetze, Ungelerntes ausgegraut.
local function BarCard(parent, y, height, size, maxSpacing)
    local card = Card(parent, 0, y, LEFT_W, height, "")
    card.icons, card.size, card.maxSpacing = {}, size, maxSpacing
    card.note = Text(card, "GameFontHighlightSmall", LEFT_W / 2, -12, LEFT_W / 2 - 12, "soft", "", "RIGHT")
    function card:Set(entries, showKeys)
        local spacing = math.min(self.maxSpacing, math.floor((LEFT_W - 24) / math.max(1, #entries)))
        for i, e in ipairs(entries) do
            local icon = self.icons[i] or NewIcon(self, self.size)
            self.icons[i] = icon
            local size = math.min(self.size, spacing - 3)
            icon:SetSize(size, size)
            icon.label:SetWidth(spacing - 2)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", self, "TOPLEFT", 12 + (i - 1) * spacing + (spacing - size) / 2 - 6, -32)
            SetIcon(icon, e, e.label, showKeys and tostring(e.pos) or nil)
        end
        for i = #entries + 1, #self.icons do self.icons[i]:Hide() end
    end
    return card
end

function Page:Build(panel)
    self.panel = panel
    if false then
        local L, R = ONE.Book:Spread()
        LEFT_W, RIGHT_X, RIGHT_W = L.width, R.x, R.width
    end
    local _, sub
    self.heading, sub = ONE.Widgets:PageHeader(panel, "", "", 290, true)
    self.sub = sub

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetSize(W, H)
    self.content = content

    -- Situation, Buff-Erinnerung und Talent-Automatik: Optionen › Klasse



    -- Zwei Ansichten: Leisten und Talente
    local bv = CreateFrame("Frame", nil, content)
    bv:SetPoint("TOPLEFT", 0, 0)
    bv:SetSize(W, H)
    self.barView = bv
    -- "Leisten automatisch aktuell halten" und "Zauberdaten teilen" stehen in den Optionen (Page:Register)
    self.treeView = self:BuildTree(content)
    self.weaponView = self:BuildWeapons(content)
    -- Umschalter rechts oben in einer Zeile mit dem Auswahlfeld (Ausrichtung);
    -- Lage je nach Klasse in Page:LayoutViews (Druide hat zusaetzlich "Gestalten")
    local inBook0 = false
    self.viewBars = ONE.Widgets:Button(content, "Leisten", 72, 24, "TOPRIGHT", -344, -6, function()
        Store().view = "bars" Page:Refresh() end)
    self.viewTree = ONE.Widgets:Button(content, "Talente", 72, 24, "TOPRIGHT", -270, -6, function()
        Store().view = "talents" Page:Refresh() end)
    -- im Buch ist die Tintenschrift breiter: "Bewaffnung" braucht dort mehr Platz
    local inBook = false
    self.viewWeapons = ONE.Widgets:Button(content, "Bewaffnung", 84, 24, "TOPRIGHT", -196, -6, function()
        Store().view = "weapons" Page:Refresh() end)
    -- Druide: Katzen- und Baerenleiste (nur sichtbar, wenn der Bauplan Gestalten hat)
    self.viewForms = ONE.Widgets:Button(content, "Gestalten", 88, 24, "TOPRIGHT", -196, -6, function()
        Store().view = "forms" Page:Refresh() end)
    -- Spielstil waehlen (nur hier, nicht doppelt in den Optionen); Vor-/Nachteile
    -- erscheinen nur beim Drueberfahren ueber einen Eintrag
    self.specPick = ONE.Kit:Dropdown(content, {point = "TOPRIGHT", x = -4, y = -6, width = 186,
        options = function() return Page:SpecOptions() end,
        get = function() return Store().spec end, set = function(v) Store().spec = v end,
        onChange = function() Page:Refresh() end})


    -- Links: drei Leisten
    self.bars = {
        BarCard(bv, -56, 108, 40, 56),
        BarCard(bv, -172, 84, 34, 64),
        BarCard(bv, -264, 84, 34, 64),
    }
    -- Ablauf als Symbolreihe: [Symbol] Stichwort › [Symbol] Stichwort …
    self.flow = Text(self.bars[1], "GameFontHighlightSmall", 12, -88, LEFT_W - 24, "soft")
    self.flowRow = {icons = {}, texts = {}}

    -- Rechts: Talent, Lehrer, Werte
    local talent = Card(bv, RIGHT_X, -56, RIGHT_W, 108, "Nächster Talentpunkt")
    self.talentIcon = NewIcon(talent, 36)
    self.talentIcon:SetPoint("TOPLEFT", talent, "TOPLEFT", 12, -36)
    self.talentName = Text(talent, "GameFontHighlight", 56, -38, RIGHT_W - 68, "text")
    -- lange Namen (z. B. „Verbessertes Schattenwort: Schmerz“) einzeilig, voller Name im Tooltip
    if self.talentName.SetWordWrap then self.talentName:SetWordWrap(false) end
    if self.talentName.SetMaxLines then self.talentName:SetMaxLines(1) end
    self.talentRank = Text(talent, "GameFontHighlightSmall", 56, -56, RIGHT_W - 68, "soft")
    self.talentNote = Text(talent, "GameFontHighlightSmall", 12, -84, RIGHT_W - 24, "soft")
    -- Einen Punkt nach Plan setzen (mit Rueckfrage); nur sichtbar, wenn ein Punkt frei ist
    self.spendButton = ONE.Widgets:Button(talent, "Nächsten Punkt setzen", 170, 22, "TOPLEFT", 12, -78,
        function() classes.Talents:AskAndSpend(function() Page:Refresh() end) end)

    local trainer = Card(bv, RIGHT_X, -172, RIGHT_W, 84, "Lehrer")
    -- Maus drueber: alle kommenden Zauber nach Stufe (vom letzten Lehrerbesuch)
    if trainer.EnableMouse then trainer:EnableMouse(true) end
    trainer:SetScript("OnEnter", function(card)
        local list = Page.trainerList
        if not GameTooltip then return end
        if not (list and #list > 0) then
            -- noch kein Lehrerbesuch: erklaeren, warum hier noch nichts steht
            GameTooltip:SetOwner(card, "ANCHOR_LEFT")
            GameTooltip:SetText(T("Lehrer"), 1, .82, 0)
            GameTooltip:AddLine(T("Welche Zauber ab welcher Stufe kommen, zeigt Forever nur im Lehrerfenster. Sprich einmal deinen Klassenlehrer an – danach steht hier, was als Nächstes dran ist."), 1, 1, 1, true)
            GameTooltip:Show()
            return
        end
        GameTooltip:SetOwner(card, "ANCHOR_LEFT")
        GameTooltip:SetText(T("Kommt beim Klassenlehrer"), 1, .82, 0)
        local shown = 0
        for _, s in ipairs(list) do
            shown = shown + 1
            if shown > 18 then GameTooltip:AddLine("…", .7, .7, .7) break end
            local rank = (type(s.rank) == "string" and s.rank ~= "") and (" (" .. s.rank .. ")") or ""
            GameTooltip:AddDoubleLine(s.name .. rank, T("Stufe %d", s.level), s.planned and 1 or .75, s.planned and 1 or .75, s.planned and 1 or .75, 1, .82, 0)
        end
        GameTooltip:AddLine(T("Weiß = in deinem Leisten-Plan."), .6, .6, .6)
        GameTooltip:Show()
    end)
    trainer:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.trainer = Text(trainer, "GameFontHighlightLarge", 12, -36, RIGHT_W - 24, "text")
    self.trainerNote = Text(trainer, "GameFontHighlightSmall", 12, -62, RIGHT_W - 24, "soft")
    if self.trainerNote.SetWordWrap then self.trainerNote:SetWordWrap(false) end

    local gear = Card(bv, RIGHT_X, -264, RIGHT_W, 84, "Werte")
    if gear.EnableMouse then gear:EnableMouse(true) end
    gear:SetScript("OnEnter", function(card)
        local prep = Page.prepInfo
        if not (GameTooltip and prep) then return end
        GameTooltip:SetOwner(card, "ANCHOR_LEFT")
        GameTooltip:SetText(T("Vorbereitung für Dungeon und Raid"), 1, .82, 0)
        GameTooltip:AddDoubleLine(T("Essen"), T(prep.food), 1, .82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("Elixier"), T(prep.elixir), 1, .82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("Trank"), T(prep.potion), 1, .82, 0, 1, 1, 1)
        GameTooltip:AddLine(T("Passend zu deiner Stufe kaufen oder herstellen lassen – die Gilde hilft (Berufe)."), .7, .7, .7, true)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    self.stats = Text(gear, "GameFontHighlight", 12, -36, RIGHT_W - 24, "text")
    self.gearNote = Text(gear, "GameFontHighlightSmall", 12, -62, RIGHT_W - 24, "soft")

    -- Nicht eingeplante Klassenzauber (bleiben im Zauberbuch, zum Ausprobieren)
    self.unusedLabel = Text(bv, "GameFontHighlightSmall", 0, -360, 200, "soft", "Im Zauberbuch, nicht eingeplant:")
    self.unused = {}
    -- Buff-Erinnerung (Zeile ueber den Leisten, nur ausserhalb des Kampfes)


    -- Unten: Tipp und Knoepfe
    self.tip = Text(bv, "GameFontHighlight", 0, -398, LEFT_W, "text")
    ONE.Widgets:Button(bv, "Leisten einrichten", 130, 24, "TOPLEFT", RIGHT_X, -392, function() Page:ApplyBars() end)
    ONE.Widgets:Button(bv, "Rückgängig", 104, 24, "TOPLEFT", RIGHT_X + 140, -392, function() Page:UndoBars() end)

    self.empty = ONE.Widgets:EmptyState(panel,
        {x = 24, y = -152, width = 678, height = 114, parentWidth = 726, parentHeight = 437},
        "Bald für deine Klasse", "Der Klassen-Ratgeber startet mit dem Priester. Weitere Klassen folgen.")
    return function() Page:Refresh() end
end

-- ===== Talentbaum =====
local TREE = {icon = 32, dx = 46, dy = 46, top = -86, gap = 40}

local function NewNode(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(TREE.icon, TREE.icon)
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
    b.border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints(b)
    if b.tex.SetTexCoord then b.tex:SetTexCoord(.07, .93, .07, .93) end
    b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.rank:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    b.order = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.order:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip or not self.talent then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetSpellByID, GameTooltip, self.talent.spell) then GameTooltip:SetText(self.talent.name or "?") end
        if GameTooltip.AddLine then
            GameTooltip:AddLine(T("Rang %d / %d", self.talent.ranks, self.talent.max), 1, .82, 0)
            if self.planText then GameTooltip:AddLine(self.planText, .4, 1, .4) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

function Page:BuildTree(parent)
    local tv = CreateFrame("Frame", nil, parent)
    tv:SetPoint("TOPLEFT", 0, 0)
    tv:SetSize(W, H)
    tv.nodes, tv.headers = {}, {}
    -- Talente setzen: Knopf (ein Punkt, Rueckfrage) und Haekchen fuer die Automatik (Standard aus)
    tv.spend = ONE.Widgets:Button(tv, "Nächsten Punkt setzen", 170, 22, "TOPLEFT", 300, -30,
        function() classes.Talents:AskAndSpend(function() Page:Refresh() end) end)

    tv.legend = Text(tv, "GameFontHighlightSmall", 0, -412, W, "soft",
        "|cff40e040Grün|r = gesetzt · |cffffd100Gold|r = nächster Punkt · Zahl oben links = Reihenfolge im Plan · grau = noch gesperrt",
        "CENTER")
    return tv
end

-- Knopfreihe: [Leisten][Talente][Waffen]([Gestalten]) [Ausrichtung]
function Page:LayoutViews(forms)
    local order = {self.viewBars, self.viewTree, self.viewWeapons}
    if forms then order[#order + 1] = self.viewForms end
    -- Buch: rechts ist nur Platz fuer die Spielstil-Auswahl – die Knoepfe stehen links
    -- unter der Ueberschrift (sonst ragt "Talente" ueber die Falz)
    local bookL = false
    local right = -196
    for i = #order, 1, -1 do
        local b = order[i]
        local w = b.GetWidth and b:GetWidth() or 72
        if b.ClearAllPoints then b:ClearAllPoints() end
        b:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", right, -6)
        right = right - w - 2
    end
end

-- Ansicht "Bewaffnung": je Waffe Stand und naechster Waffenmeister, Navi-Knopf je Zeile
function Page:BuildWeapons(parent)
    local wv = CreateFrame("Frame", nil, parent)
    wv:SetPoint("TOPLEFT", 0, 0)
    wv:SetSize(W, H)
    local bookL, bookR
    wv.book = bookL ~= nil
    local NAVI_W = 26
    -- Buch: Liste auf der linken Seite (Lehrer im Tooltip), Erklaerung rechts.
    -- Sonst: volle Breite, Erklaerung unter der Liste.
    local listX, listW = 0, W
    -- Buch: unter der Knopfzeile (Leisten | Talente | Bewaffnung) auf der linken Seite
    local listY = -44
    local listH = (H - 44 - 52)
    local nameW, stateW = 180, 180
    local columns = {
        {key = "name", title = "WAFFE", width = nameW},
        {key = "state", title = "STAND", width = stateW},
    }
    columns[#columns + 1] = {key = "trainer", title = "LEHRER", width = listW - 24 - 18 - nameW - stateW - NAVI_W}
    wv.list = ONE.Kit:List(wv, {x = listX, y = listY, width = listW, height = listH, rowHeight = 22, columns = columns,
        render = function(frame, row, cells)
            cells.name:SetText(T(row.weapon.name))
            cells.name:SetTextColor(1, .82, 0)
            cells.state:SetText(classes.Weapons.StateText(row))
            if cells.trainer then cells.trainer:SetText(classes.Weapons.TrainerText(row)) end
            -- kleiner Navi-Pfeil hinter dem Lehrer (nur wenn ein Lehrer mit Kartenposition bekannt ist)
            if not frame.navi then
                frame.navi = ONE.Widgets:NaviArrow(frame, 16, "RIGHT", -6, 0,
                    function(self) if self.row then classes.Weapons.Navi(self.row) end end,
                    function(self)
                        local e = self.row and self.row.trainer
                        if not e then return nil end
                        return T("Navi zu %s", e.npc), e.area and T(e.area) or nil
                    end)
            end
            frame.navi.row = row
            if row.trainer and row.trainer.map then frame.navi:Show() else frame.navi:Hide() end
        end,
        onEnter = function(frame, row)
            if not GameTooltip then return end
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(T(row.weapon.name))
            local e = row.trainer
            if e then
                GameTooltip:AddLine(T("Waffenmeister: %s", e.npc), 1, 1, 1)
                if e.area then GameTooltip:AddLine(T(e.area), .8, .8, .8) end
                GameTooltip:AddLine(row.sure and T("Im Spiel bestätigt.") or T("Laut Classic – in Forever noch nicht bestätigt."), .6, .6, .6, true)
            else
                GameTooltip:AddLine(classes.Weapons.TrainerText(row), 1, 1, 1, true)
            end
            GameTooltip:Show()
        end,
    })
    local infoX, infoW = 8, W - 16
    wv.info = Text(wv, "GameFontHighlightSmall", infoX + (0), (listY - listH - 8), infoW - (0), "soft")
    if wv.info.SetWordWrap then wv.info:SetWordWrap(true) end
    return wv
end

function Page:RefreshWeapons(p)
    local wv = self.weaponView
    local rows = classes.Weapons:Rows(p.classFile)
    wv.list:SetItems(rows)
    local open, unknown, guess = 0, 0, false
    for _, r in ipairs(rows) do
        if r.known == false and not r.weapon.free then open = open + 1 end
        if r.known == nil then unknown = unknown + 1 end
        if r.trainer and not r.sure then guess = true end
    end
    local parts = {}
    parts[#parts + 1] = open > 0 and T("%d Waffenarten kannst du noch beim Waffenmeister lernen.", open)
        or T("Du beherrschst alle Waffen, die deine Klasse tragen kann.")
    if unknown > 0 then parts[#parts + 1] = T("Ob du eine Waffe schon kannst, verrät das Spiel hier nicht.") end
    if guess then parts[#parts + 1] = T("* = laut Classic, in Forever noch nicht bestätigt – sprich den Waffenmeister einmal an.") end
    if wv.book then parts[#parts + 1] = T("Welcher Waffenmeister die Waffe lehrt, steht im Tooltip der Zeile.") end
    wv.info:SetText(table.concat(parts, wv.book and "\n\n" or "  ·  "))
end

-- Zeichnet alle Talentbaeume nebeneinander; Plan-Reihenfolge und naechster Punkt markiert.
function Page:RefreshTree(p, def, build)
    local tv = self.treeView
    local order, target = {}, {}
    for i, step in ipairs(build.talents or {}) do order[step[1]] = i; target[step[1]] = step[2] end
    local nextStep = classes.Player.NextTalent(p, build.talents)
    local nextSpell = p.level >= 10 and nextStep and nextStep[1] or nil
    -- Spalten je Baum
    local cols = {}
    for _, t in pairs(p.talents) do cols[t.group] = math.max(cols[t.group] or 0, t.col + 1) end
    -- Buch: kein Baum auf der Falz – Baum 1 und 2 links (etwas enger), Baum 3 rechts
    local bookL, bookR
    local book = bookL and bookR and #p.points == 3
    local dx = book and 39 or TREE.dx
    local widths, total = {}, 0
    for g = 1, #p.points do
        widths[g] = ((cols[g] or 1) - 1) * dx + TREE.icon
        total = total + widths[g] + (g > 1 and TREE.gap or 0)
    end
    local x, starts = math.floor((W - total) / 2), {}
    for g = 1, #p.points do starts[g] = x; x = x + widths[g] + TREE.gap end
    -- Ueberschriften
    for g = 1, #p.points do
        local h = tv.headers[g] or Text(tv, "GameFontNormal", 0, -60, 160, "accent", "", "CENTER")
        tv.headers[g] = h
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", tv, "TOPLEFT", starts[g] + widths[g] / 2 - 80, -60)
        local name = def.specs[g] or ("Baum " .. g)
        h:SetText((g == p.spec and "|cffffd100" or "|cffb0b0b0") .. T(name) .. " · " .. (p.points[g] or 0) .. "|r")
        h:Show()
    end
    for g = #p.points + 1, #tv.headers do tv.headers[g]:Hide() end
    -- Talente
    local list = {}
    for _, t in pairs(p.talents) do list[#list + 1] = t end
    table.sort(list, function(a, b) return a.spell < b.spell end)
    for i, t in ipairs(list) do
        local node = tv.nodes[i] or NewNode(tv)
        tv.nodes[i] = node
        node.talent = t
        node:ClearAllPoints()
        node:SetPoint("TOPLEFT", tv, "TOPLEFT", starts[t.group] + t.col * dx, TREE.top - t.row * TREE.dy)
        node.tex:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local locked = t.ranks == 0 and t.canBuy == false
        if node.tex.SetDesaturated then node.tex:SetDesaturated(locked) end
        if node.SetAlpha then node:SetAlpha(locked and .55 or 1) end
        if t.spell == nextSpell then node.border:SetColorTexture(1, .82, 0, 1)
        elseif t.ranks > 0 then node.border:SetColorTexture(.25, .85, .25, 1)
        else node.border:SetColorTexture(.12, .12, .12, 1) end
        node.rank:SetText(t.ranks .. "/" .. t.max)
        node.order:SetText(order[t.spell] and ("|cff80ff80" .. order[t.spell] .. "|r") or "")
        node.planText = order[t.spell] and T("Plan: Schritt %d, bis Rang %d", order[t.spell], target[t.spell]) or nil
        node:Show()
    end
    for i = #list + 1, #tv.nodes do tv.nodes[i]:Hide() end
    if #list == 0 then
        tv.legend:SetText(T("Keine Talente gefunden – ab Stufe 10 gibt es Talentpunkte."))
    end
end

-- ===== Ablauf als Symbolreihe =====
-- Ein Ablauf-Schritt ist durch " · " getrennt. Zahlen am Anfang ("1 Start",
-- "6 oder 5 von hinten", "1 und 2 vorher") oder nach einem Doppelpunkt
-- ("Mana knapp: 5", "nah: 7 und 8") meinen Plätze auf Leiste 1 und werden als
-- Symbol gezeigt; der Rest bleibt als kurzes Stichwort stehen.
local CONNECT = {["und"] = true, ["oder"] = true, ["and"] = true, ["or"] = true}
function Page.ParseStep(token, maxPos)
    local pos, rest = {}, token
    local function ok(n) n = tonumber(n) return n and n >= 1 and n <= (maxPos or 8) and n end
    -- Platznummern ein- oder zweistellig (Talent-Plaetze 9-11)
    local a, sep, b, tail = rest:match("^(%d%d?)%s+(%S+)%s+(%d%d?)%f[%D](.*)$")
    if a and CONNECT[sep] and ok(a) and ok(b) then
        pos, rest = {ok(a), ok(b)}, tail
    else
        local x, t = rest:match("^(%d%d?)%f[%D](.*)$")
        if x and ok(x) then pos, rest = {ok(x)}, t end
    end
    local head, c, sep2, d = rest:match("^(.-):%s*(%d%d?)%s+(%S+)%s+(%d%d?)%s*$")
    if head and CONNECT[sep2] and ok(c) and ok(d) then
        pos[#pos + 1], pos[#pos + 2], rest = ok(c), ok(d), head
    else
        local h, e = rest:match("^(.-):%s*(%d%d?)%s*$")
        if h and ok(e) then pos[#pos + 1], rest = ok(e), h end
    end
    rest = rest:gsub("^%s+", ""):gsub("%s+$", "")
    return pos, rest
end

function Page:RenderFlow(flow, bar1)
    local row = self.flowRow
    local card = self.bars[1]
    self.flow:SetText("")
    self.flowFull = flow
    -- "Vorher: Buffs ..." steht nicht in der Symbolzeile (zu lang, Symbole passen sonst nicht);
    -- der ganze Ablauf samt Vorher-Teil erscheint beim Drueberfahren ueber die Kampf-Leiste
    local before
    local head, rest = flow:match("^([^·]-)%s*·%s*(.*)$")
    if head and (head:find("^Vorher:") or head:find("^Before:")) then before, flow = head, rest end
    self.flowBefore = before
    if not card.flowTip and card.EnableMouse and card.SetScript then
        card.flowTip = true
        card:EnableMouse(true)
        card:SetScript("OnEnter", function(f)
            if not (GameTooltip and Page.flowFull and Page.flowFull ~= "") then return end
            GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("Ablauf"), 1, .82, 0)
            for part in (Page.flowFull .. " · "):gmatch("(.-)%s*·%s*") do
                if part ~= "" then GameTooltip:AddLine(part, 1, 1, 1, true) end
            end
            GameTooltip:Show()
        end)
        card:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    local x, maxX = 12, LEFT_W - 12
    local iconN, textN = 0, 0
    local maxPos = 0
    for k in pairs(bar1) do if k > maxPos then maxPos = k end end
    local function Width(fs, text)
        local w = fs.GetStringWidth and fs:GetStringWidth()
        return (type(w) == "number" and w > 0) and w or (#text * 5.5)
    end
    local function AddText(text, role)
        textN = textN + 1
        local fs = row.texts[textN] or Text(card, "GameFontHighlightSmall", 0, 0, 200, role or "soft", "")
        row.texts[textN] = fs
        fs:SetWidth(0)
        fs:SetText(text)
        local w = math.min(Width(fs, text), math.max(0, maxX - x))
        fs:SetWidth(w)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", card, "TOPLEFT", x, -90)
        fs:Show()
        x = x + w + 4
    end
    local function AddIcon(e)
        iconN = iconN + 1
        local icon = row.icons[iconN] or NewIcon(card, 16, 1)
        row.icons[iconN] = icon
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", card, "TOPLEFT", x, -87)
        SetIcon(icon, e, "")
        x = x + 16 + 3
    end
    -- Buffs vorab als kleine Symbole (nur gelernte; voller Text im Tooltip der Leiste)
    local p, def = self.player, self.def
    if before and p and def then
        local shown = 0
        for _, b in ipairs(def.buffs or {}) do
            if (not b.spec or b.spec == p.spec) and b.ids and b.ids[1] then
                local sp = p:Spell(b.ids)
                if sp.known then
                    if shown == 0 then AddText(T("Buffs:"), "accent") end
                    shown = shown + 1
                    AddIcon(sp)
                end
            end
        end
        if shown > 0 then AddText("|", "soft") end
    end
    if flow ~= "" then AddText(T("Ablauf:"), "accent") end
    -- Erst ganz versuchen; passt es nicht in die Zeile, kompakt: nur Schritte mit Symbol,
    -- Stichworte bis 10 Zeichen (der ganze Ablauf steht im Tooltip der Kampf-Leiste)
    local startX, startIcons, startTexts = x, iconN, textN
    local function Steps(compact)
        local first, cut = true, false
        for token in (flow .. " · "):gmatch("(.-)%s*·%s*") do
            if token ~= "" then
                local pos, label = Page.ParseStep(token, maxPos)
                if compact and #pos == 0 then
                    -- reiner Text-Schritt: im Kompakt-Modus weglassen
                elseif x >= maxX - 20 then
                    cut = true
                else
                    if not first then AddText("›", "accent") end
                    first = false
                    -- Tastennummer in Gold statt kleiner Symbole (die stehen groß auf der Leiste
                    -- darueber; Symbole hier wirkten ueberladen – Nutzer-Rueckmeldung 15.11.)
                    for i, n in ipairs(pos) do
                        if i > 1 then AddText("/", "soft") end
                        AddText(tostring(n), "accent")
                    end
                    if label ~= "" and (not compact or #label <= 10) then AddText(label, "text") end
                end
            end
        end
        return cut
    end
    if Steps(false) then
        x, iconN, textN = startX, startIcons, startTexts
        Steps(true)
    end
    for i = iconN + 1, #row.icons do row.icons[i]:Hide() end
    for i = textN + 1, #row.texts do row.texts[i]:Hide() end
    row.used = {icons = iconN, texts = textN}
end

-- Hat der Spieler einen Zauberstab (Fernkampfplatz 18) angelegt?
function Page:HasWand()
    if type(GetInventoryItemID) ~= "function" then return nil end
    local ok, id = pcall(GetInventoryItemID, "player", 18)
    return ok and id ~= nil
end

function Page:CurrentBuild(p, def)
    return classes.Data:Build(def, p.spec, p.situation)
end

-- Auswahl der Spielstile (Ausrichtungen) mit Vor-/Nachteilen als Tooltip je Eintrag
function Page:SpecOptions()
    local file = UnitClass and select(2, UnitClass("player"))
    local def = classes.Data.classes[file or ""] or {}
    local out = {{value = nil, text = "Spielstil: automatisch",
        tooltip = "Guild Trip wählt nach deinen Talentpunkten."}}
    for i, name in ipairs(def.specs or {}) do
        out[#out + 1] = {value = i, text = name, tooltip = def.specNotes and def.specNotes[i] or nil}
    end
    return out
end

-- Haekchen nur zeigen, wenn ein Entwickler online ist (oder es schon gesetzt ist).
function Page:RefreshShare()
    local box = self.shareCheck
    if not box then return end
    local Share = classes.Share
    if Share and (Share:DevOnline() or Share:IsEnabled()) then
        if box.Refresh then box:Refresh() end
        box:Show()
    else
        box:Hide()
    end
end

function Page:ApplyBars()
    local p, def = self.player, self.def
    if not (p and def) then return end
    local build = self:CurrentBuild(p, def)
    classes.Bars:Confirm(T("Guild Trip legt deine gelernten Zauber auf Leiste 1 bis 3.\n"
        .. "Nicht eingeplante Klassenzauber nimmt Guild Trip von den Leisten (sie bleiben im Zauberbuch). "
        .. "Makros bleiben liegen. Deine bisherige Belegung wird gemerkt und lässt sich mit „Rückgängig“ zurückholen."), function()
        local n, macros, used, removed, duplicates, moved = classes.Bars:Apply(p, build)
        ONE:Print(n > 0 and T("%d Zauber auf die Leisten gelegt.", n) or T("Die Leisten sind schon eingerichtet."))
        if moved and moved > 0 then
            ONE:Print(T("%d Makros auf den Platz ihres Zaubers verschoben.", moved))
        end
        if duplicates and duplicates > 0 then
            ONE:Print(T("%d doppelte Zauber von Leiste 1 bis 3 genommen.", duplicates))
        end
        if removed and removed > 0 then
            ONE:Print(T("%d nicht eingeplante Zauber von den Leisten genommen – sie liegen weiter im Zauberbuch.", removed))
        end
        if used and used > 0 then
            ONE:Print(used == 1 and T("1 Zauber nutzt dein vorhandenes Makro.") or T("%d Zauber nutzen dein vorhandenes Makro.", used))
        end
        if macros and macros > 0 then
            ONE:Print(macros == 1 and T("1 Platz hat ein Makro – das bleibt liegen.") or T("%d Plätze haben ein Makro – das bleibt liegen.", macros))
            -- welches Makro, und welcher Zauber dort eingeplant waere
            for _, k in ipairs(classes.Bars.keptMacros or {}) do
                ONE:Print(T("Makro „%s“ (Taste/Platz %d) bleibt – geplant wäre dort %s. Gehört sein Zauber nicht in den Plan, kannst du es selbst verschieben.", k.name, k.slot, k.spell or "?"))
            end
        end
        Page:Refresh()
    end)
end

function Page:UndoBars()
    if not classes.Bars:HasBackup() then ONE:Print(T("Es gibt keine gemerkte Belegung.")) return end
    classes.Bars:Confirm(T("Vorherige Belegung der Leisten wiederherstellen?"), function()
        local n = classes.Bars:Undo()
        ONE:Print(T("%d Plätze wiederhergestellt.", n))
        Page:Refresh()
    end)
end

function Page:Refresh()
    if not self.content then return end
    local store = Store()
    local p = classes.Player:Read(store.spec)
    local def = classes.Data.classes[p.classFile or ""]
    self.def, self.player = def, p
    if not def then
        self.content:Hide()
        self.empty:Show()
        self.heading:SetText(T("Klasse"))
        self.sub:SetText(T("Stufe %d", p.level))
        return p
    end
    self.empty:Hide()
    self.content:Show()
    if self.autoRank and self.autoRank.Refresh then self.autoRank:Refresh() end
    if self.specPick and self.specPick.Refresh then self.specPick:Refresh() end
    if self.buffCheck and self.buffCheck.Refresh then self.buffCheck:Refresh() end
    self:RefreshShare()
    local build = self:CurrentBuild(p, def)
    local showTree = store.view == "talents"
    local showWeapons = store.view == "weapons"
    local showForms = store.view == "forms" and build.forms ~= nil
    if build.forms then self.viewForms:Show() else self.viewForms:Hide() end
    self:LayoutViews(build.forms ~= nil)
    -- 0.6.8: mit Symbolleiste stehen die Ansichten oben in der Kopfzeile
    if not self.headerTried then
        self.headerTried = true
        self.headerViews = ONE.UI.SetViews and ONE.UI:SetViews("classes", {}) or false
        if self.headerViews then ONE.UI:RetireButtons(self.viewBars, self.viewTree, self.viewWeapons, self.viewForms) end
    end
    if self.headerViews then
        local function Go(key) Store().view = key Page:Refresh() end
        local items = {{key = "bars", label = "Leisten", onClick = Go}, {key = "talents", label = "Talente", onClick = Go},
            {key = "weapons", label = "Bewaffnung", onClick = Go}}
        if build.forms then items[#items + 1] = {key = "forms", label = "Gestalten", onClick = Go} end
        ONE.UI:SetViews("classes", items, showTree and "talents" or showWeapons and "weapons" or showForms and "forms" or "bars")
    end
    self.barView:Hide() self.treeView:Hide() self.weaponView:Hide()
    if showTree then self.treeView:Show() elseif showWeapons then self.weaponView:Show() else self.barView:Show() end
    -- aktiven Knopf hervorheben
    local active = showTree and self.viewTree or showWeapons and self.viewWeapons or showForms and self.viewForms or self.viewBars
    for _, b in ipairs({self.viewBars, self.viewTree, self.viewWeapons, self.viewForms}) do
        if b == active then if b.LockHighlight then b:LockHighlight() end
        elseif b.UnlockHighlight then b:UnlockHighlight() end
    end
    local specName = def.specs[p.spec] or "?"
    self.heading:SetText(T("%s · Stufe %d", T(def.name), p.level))
    local situationName = T(classes.Data.situationNames[p.situation] or "Leveln")
    self.sub:SetText(p.spent > 0 and T("%s · %s · %d Talentpunkte", T(specName), situationName, p.points[p.spec] or 0)
        or T("%s · %s", T(specName), situationName))
    if ONE.UI.SetContext then ONE.UI:SetContext("classes", (self.heading:GetText() or "") .. "  ·  " .. (self.sub:GetText() or "")) end

    if showTree then self:RefreshTree(p, def, build) end
    if showWeapons then self:RefreshWeapons(p) end

    -- Leisten
    local plan = classes.Bars:Plan(p, build)
    local shownBars = showForms and build.forms or build.bars or {}
    for i, bar in ipairs(shownBars) do
        local card = self.bars[i]
        if card then
            local entries = {}
            local lastKey = 0
            for _, e in ipairs(plan) do
                if e.bar == bar.bar then entries[#entries + 1] = e; lastKey = math.max(lastKey, e.pos) end
            end
            local form = classes.Data.formBars[bar.bar]
            card.title:SetText(form and T(bar.title) or T("Leiste %d · %s", bar.bar, T(bar.title)))
            local shown = classes.Bars:IsBarShown(bar.bar)
            card.note:SetText(shown == false and ("|cffff8060" .. T("Leiste ausgeblendet – in den Optionen einschalten") .. "|r")
                or ((bar.bar == 1 or form) and T("Tasten 1–%d", lastKey) or ""))
            card:Set(entries, bar.bar == 1 or form)
            card:Show()
        end
    end
    for i = #shownBars + 1, #self.bars do self.bars[i]:Hide() end
    local first = shownBars[1] and shownBars[1].bar or 1
    local flow = showForms and shownBars[1].flow or build.flow
    local bar1 = {}
    for _, e in ipairs(plan) do if e.bar == first then bar1[e.pos] = e end end
    -- Leiste 1 ist in Ablauf-Reihenfolge umsortiert: Platznummern im (uebersetzten) Text anpassen
    local text = flow and T(flow) or ""
    if not showForms and classes.Data.RemapFlow then text = classes.Data.RemapFlow(text, build.slotMap, build.slotFixed) end
    self:RenderFlow(text, bar1)
    -- Nicht eingeplant
    local unused = classes.Bars:Unused(p, build)
    local maxIcons = math.floor((LEFT_W - 200) / 26)
    for i, u in ipairs(unused) do
        if i > maxIcons then break end
        local icon = self.unused[i] or NewIcon(self.barView, 22, 1)
        self.unused[i] = icon
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", self.barView, "TOPLEFT", 200 + (i - 1) * 26, -355)
        SetIcon(icon, u, "")
    end
    for i = math.min(#unused, maxIcons) + 1, #self.unused do self.unused[i]:Hide() end
    if #unused > 0 then self.unusedLabel:Show() else self.unusedLabel:Hide() end

    -- Talent
    local step, t = classes.Player.NextTalent(p, build.talents)
    self.talentIcon:Hide()
    self.talentRank:SetText("")
    self.talentNote:SetText("")
    if p.level < 10 then
        self.talentName:SetText(T("Ab Stufe 10"))
    elseif not build.talents then
        self.talentName:SetText(T("Plan folgt"))
        self.talentRank:SetText(T("für %s", T(specName)))
    elseif not step then
        self.talentName:SetText(T("Plan erfüllt"))
    else
        local s = p:Spell(step[1])
        SetIcon(self.talentIcon, {id = step[1], icon = s.icon, name = s.name, known = true}, "")
        self.talentName:SetText(s.name or "?")
        self.talentRank:SetText((p.free or 0) > 0 and T("Rang %d / %d · %d frei", t.ranks, step[2], p.free)
            or T("Rang %d / %d", t.ranks, step[2]))
        self.talentNote:SetText(t.canBuy == false and T("Noch gesperrt – erst weiter oben Punkte setzen.") or "")
    end
    local canSpend = classes.Talents and classes.Talents:CanSpend(p, step, t) and p.level >= 10
    for _, button in ipairs({self.spendButton, self.treeView and self.treeView.spend}) do
        if canSpend then button:Show() else button:Hide() end
    end
    if self.treeView and self.treeView.auto and self.treeView.auto.Refresh then self.treeView.auto:Refresh() end

    -- Lehrer
    -- Was als Naechstes dran ist (gemerkt beim letzten Besuch beim Klassenlehrer)
    local now, upLevel, upList, all = classes.Trainer:Upcoming(p)
    self.trainerList = all
    if now and #now > 0 then
        self.trainer:SetText(T("Jetzt beim Lehrer"))
        self.trainerNote:SetText(classes.Trainer.Names(now, 2))
    elseif upLevel then
        self.trainer:SetText(T("Stufe %d", upLevel))
        self.trainerNote:SetText(T("Dann: %s", classes.Trainer.Names(upList, 2)))
    else
        local nextLevel = classes.Data:NextTrainerLevel(p.level)
        self.trainer:SetText(nextLevel and T("Stufe %d", nextLevel) or T("Alles gelernt"))
        self.trainerNote:SetText(nextLevel and (all and T("Dann gibt es neue Ränge.")
            or T("Nach dem nächsten Lehrerbesuch mehr.")) or "")
    end

    -- Werte
    local stats = {}
    for i, stat in ipairs(build.stats or {}) do stats[i] = T(stat) end
    self.stats:SetText(table.concat(stats, " › "))
    self.gearNote:SetText(self:HasWand() == false and ("|cffff6060" .. T("Kein Zauberstab angelegt.") .. "|r") or "")
    -- Dungeon/Raid: Essen, Elixier, Trank je Rolle (Maus drauf fuer Einzelheiten)
    local role = def.roles and def.roles[p.spec] or "caster"
    local prep = classes.Data.prep[role]
    self.prepInfo = (p.situation == "dungeon" or p.situation == "raid") and prep or nil
    if self.prepInfo and self:HasWand() ~= false then
        self.gearNote:SetText("|cff80e680" .. T("Essen, Elixier, Trank: Maus drauf") .. "|r")
    end

    -- Tipp
    -- erster passender Klassen-Tipp und passende Volks-Tipps wechseln sich ab
    -- (jede Minute), damit beides zu sehen ist, ohne die Seite voller zu machen
    local tips = {}
    -- alle passenden Klassen-Tipps (frueher nur der erste)
    for _, tip in ipairs(def.tips or {}) do
        local ok, yes = pcall(tip[1], p)
        if ok and yes then tips[#tips + 1] = tip[2] end
    end
    -- Volk: zuerst ueber UnitRace (alle Voelker, auch Allianz), sonst am Volkszauber erkannt
    local raceName, raceFile
    if type(UnitRace) == "function" then local ok, a, b = pcall(UnitRace, "player") if ok then raceName, raceFile = a, b end end
    local byRace = classes.Data.RaceTipsFor and classes.Data.RaceTipsFor(raceName, raceFile, p.classFile) or {}
    if #byRace > 0 then
        for _, text in ipairs(byRace) do tips[#tips + 1] = text end
    else
        for _, tip in ipairs(classes.Data.raceTips or {}) do
            if (not tip[3] or tip[3][p.classFile or ""]) and p:Knows(tip[1]) then tips[#tips + 1] = tip[2] end
        end
    end
    local now = type(time) == "function" and time() or 0
    local tipText = #tips > 0 and tips[math.floor(now / 60) % #tips + 1] or ""
    self.tip:SetText(tipText ~= "" and ("|cffffd100" .. T("Tipp:") .. "|r " .. T(tipText)) or "")
    -- Gestalten: Ablauf der zweiten Leiste (Baer) statt Tipp
    if showForms and shownBars[2] and shownBars[2].flow then
        self.tip:SetText("|cffffd100" .. T(shownBars[2].title) .. ":|r " .. T(shownBars[2].flow))
    end
    return p
end

function Page:Register()
    if not (ONE.UI and ONE.UI.AddTab and ONE.Kit) then return false end
    -- nur sichtbar, wenn ein Entwickler online ist (oder es schon an ist)
    if ONE.UI.AddShareOption then
        ONE.UI:AddShareOption({id = "spells", module = "classes", order = 40, label = "Zauberdaten teilen",
            tooltip = "Hilft beim Klassen-Ratgeber und Startpaket: Zauber, Talente und Funde (Lehrer, Händler, Questgeber, Eingänge) gehen ohne Namen an den Guild-Trip-Entwickler deiner Gilde.",
            get = function() return classes.Share:IsEnabled() end, set = function(on) classes.Share:SetEnabled(on) end,
            visible = function() return classes.Share:DevOnline() ~= nil or classes.Share:IsEnabled() end})
    end
    -- Optionen › Klasse (Spielstil waehlt man auf der Klassen-Seite; Buffs/Leisten sind Funktionen in Init.lua)
    if ONE.UI.AddSetting then
        local function Changed() if Page.content then Page:Refresh() end end
        ONE.UI:AddSetting({id = "classSituation", category = "classes", section = "Ratgeber", order = 10, kind = "dropdown", width = 220,
            label = "Situation",
            options = function()
                local auto = classes.Player:DetectSituation()
                local out = {{value = nil, text = T("Automatisch (%s)", T(classes.Data.situationNames[auto]))}}
                for _, key in ipairs(classes.Data.situations) do out[#out + 1] = {value = key, text = classes.Data.situationNames[key]} end
                return out
            end,
            get = function() return Store().situation end, set = function(v) Store().situation = v Changed() end})
        ONE.UI:AddSetting({id = "classTalentAuto", category = "classes", section = "Talente", order = 30, label = "Talente automatisch nach Plan setzen",
            tooltip = "Setzt freie Talentpunkte selbst nach dem Plan, einen nach dem anderen (außerhalb des Kampfes). Zurücksetzen kostet beim Lehrer Gold – deshalb standardmäßig aus.",
            get = function() return classes.Talents:AutoEnabled() end, set = function(on) classes.Talents:SetAutoEnabled(on) Changed() end})
    end
    return ONE.UI:AddTab("classes", "Klasse", function(panel) return self:Build(panel) end)
end
