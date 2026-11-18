-- Project ONE Navigation: eigene Seite im ONE-Fenster und Kachel fuer die Startseite.
-- Links: wer gerade live teilt (mit Ort, Entfernung, Navi-Knopf).
-- Rechts: Pfeil-Einstellungen, die bisher nur als Chatbefehle existierten.
local _, nav = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Page = {}
nav.Page = Page

local function ShortName(name) return type(name) == "string" and (name:match("^[^-]+") or name) or "?" end

local function GuildModule()
    local g = ONE.modules and ONE.modules.guild
    if g and type(g.LivePeers) == "function" then return g end
end

-- Entfernung und Ort eines Mitglieds aus Sicht des Spielers (nur Luftlinie).
function Page:Describe(peer)
    local Travel = nav.Travel
    local g = GuildModule()
    local where = ""
    if g and g.DescribePeer then
        local d = g:DescribePeer(peer)
        where = d.place or d.region or d.map or ""
    end
    local pc, px, py = Travel.PlayerWorld()
    local tc, tx, ty = Travel.World(peer.mapID, peer.x, peer.y)
    local distance
    if pc and tc and pc == tc then
        distance = Travel.FormatDistance(Travel.Distance(px, py, tx, ty))
    elseif pc and tc then
        distance = T("anderer Kontinent")
    end
    return where, distance
end

local function Card(parent, x, y, w, h, title)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetSize(w, h)
    if ONE.Themes then ONE.Themes:RegisterPanel(frame) end
    local header = ONE.Geometry:CardHeader(w)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", header.x, header.y)
    label:SetWidth(header.width)
    label:SetJustifyH("LEFT")
    label:SetText(T(title))
    if ONE.Themes then ONE.Themes:RegisterText(label, "accent") if ONE.Themes.PanelTitle then ONE.Themes:PanelTitle(frame, label) end end
    return frame, header
end

-- Deutsche Klassennamen der Lehrer-Liste -> Klassenkennung
local CLASS_OF = {Krieger = "WARRIOR", ["Jäger"] = "HUNTER", Schurke = "ROGUE", Hexenmeister = "WARLOCK",
    Schamane = "SHAMAN", Magier = "MAGE", Priester = "PRIEST", Paladin = "PALADIN", Druide = "DRUID"}

-- Lehrer-Filter (Navi › Lehrer): "all", "class", "profession", "p:<Beruf>", "weapon", "other"
function Page:TrainerFilter()
    local db = ONE.db and type(ONE.db.nav) == "table" and ONE.db.nav
    return db and db.trainerFilter or "all"
end
function Page:SetTrainerFilter(value)
    if not ONE.db then return end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    ONE.db.nav.trainerFilter = value
end
function Page.TrainerMatches(filter, e)
    if filter == nil or filter == "all" then return true end
    -- "r:Experte" = Berufslehrer, die diese Stufe nachweislich lehren
    if filter:sub(1, 2) == "r:" then return e.kind == "profession" and type(e.teaches) == "table" and e.teaches[filter:sub(3)] == true end
    if filter:sub(1, 2) == "p:" then return e.kind == "profession" and e.what == filter:sub(3) end
    if filter == "other" then return e.kind ~= "class" and e.kind ~= "profession" and e.kind ~= "weapon" end
    return e.kind == filter
end
-- Auswahl: feste Arten + jeder bekannte Beruf einzeln
function Page:TrainerFilterOptions()
    local out = {{value = "all", text = "Alle Lehrer"}, {value = "class", text = "Klassenlehrer"},
        {value = "weapon", text = "Waffenlehrer"}, {value = "profession", text = "Berufe: alle"}}
    local crafting = ONE.modules and ONE.modules.crafting
    local seen, profs, other = {}, {}, false
    for _, e in ipairs(crafting and crafting.AllTrainers and crafting:AllTrainers() or {}) do
        if e.kind == "profession" and e.what and not seen[e.what] then seen[e.what] = true profs[#profs + 1] = e.what end
        if e.kind ~= "class" and e.kind ~= "profession" and e.kind ~= "weapon" then other = true end
    end
    table.sort(profs, function(a, b) return T(a) < T(b) end)
    for _, prof in ipairs(profs) do out[#out + 1] = {value = "p:" .. prof, text = "› " .. T(prof)} end
    for _, rank in ipairs({"Geselle", "Experte", "Fachmann"}) do
        out[#out + 1] = {value = "r:" .. rank, text = T("Lehrt %s (bekannt)", T(rank))}
    end
    if other then out[#out + 1] = {value = "other", text = "Sonstige"} end
    return out
end

-- Entfernung (Zahl) und Text zu einem Ziel in Weltkoordinaten
local function Distance(tc, tx, ty)
    local Travel = nav.Travel
    local pc, px, py = Travel.PlayerWorld()
    if not (pc and tc) then return nil, "" end
    if pc ~= tc then return nil, T("anderer Kontinent") end
    local d = Travel.Distance(px, py, tx, ty)
    return d, Travel.FormatDistance(d)
end

local function SortByDistance(items)
    table.sort(items, function(a, b)
        if (a.first and 1 or 0) ~= (b.first and 1 or 0) then return a.first end
        if a.dist and b.dist then return a.dist < b.dist end
        if a.dist or b.dist then return a.dist ~= nil end
        return a.name < b.name
    end)
    return items
end

-- Ziele je Ansicht: {name, info, distText, dist, go = function()}
function Page:Targets(view)
    local items = {}
    if view == "guild" then
        local g = GuildModule()
        local me = type(UnitName) == "function" and UnitName("player") or nil
        for _, peer in ipairs(g and g:LivePeers() or {}) do
          -- sich selbst nicht als Ziel anbieten
          if not (me and (peer.name or ""):match("^[^%s%-]+") == me) then
            local where = self:Describe(peer)
            local dist, text = Distance(nav.Travel.World(peer.mapID, peer.x, peer.y))
            items[#items + 1] = {name = ShortName(peer.name), info = where, dist = dist, distText = text, member = peer.name,
                go = function() nav.Arrow:Start(peer.name) end}
          end
        end
    elseif view == "trainers" then
        local crafting = ONE.modules and ONE.modules.crafting
        local myClass = type(UnitClass) == "function" and select(2, UnitClass("player")) or nil
        local filter = self:TrainerFilter()
        for _, e in ipairs(crafting and crafting.AllTrainers and crafting:AllTrainers() or {}) do
            local cls = e.kind == "class" and CLASS_OF[e.what]
            if e.map and e.x and e.y and (e.kind ~= "class" or cls == myClass) and Page.TrainerMatches(filter, e) then
                local dist, text = Distance(nav.Travel.World(e.map, e.x, e.y))
                local crafting = ONE.modules and ONE.modules.crafting
                local teach = crafting and crafting.TeachText and crafting.TeachText(e) or ""
                items[#items + 1] = {name = e.npc, info = T(e.what or "") .. (teach ~= "" and (" · " .. teach) or "") .. (e.area and (" · " .. T(e.area)) or ""),
                    dist = dist, distText = text, first = cls and true or false,
                    go = function() nav.Arrow:StartPoint(e.npc, e.map, e.x, e.y, {service = true}) end}
            end
        end
    elseif view == "merchants" then
        local M = nav.Merchants
        for _, m in ipairs(M and M:List(M:Filter()) or {}) do
            local dist, text = Distance(nav.Travel.World(m.mapID, m.x, m.y))
            items[#items + 1] = {name = m.name, info = M.CatText(m.cats, 3), dist = dist, distText = text, merchant = m,
                go = function() nav.Arrow:StartPoint(m.name, m.mapID, m.x, m.y, {service = true}) end}
        end
    elseif view == "flights" then
        local nodes, known = nav.Flights:Nodes(), nav.Flights:Known()
        for id, node in pairs(nodes) do
            if known[id] and node.continent and node.x and node.y then
                local dist, text = Distance(node.continent, node.x, node.y)
                local short = node.name:match("^([^,]+)") or node.name
                items[#items + 1] = {name = short, info = node.name:match(",%s*(.+)$") or "",
                    dist = dist, distText = text,
                    go = function() nav.Arrow:StartWorld(short, node.continent, node.x, node.y, {service = true}) end}
            end
        end
    end
    return SortByDistance(items)
end

local EMPTY = {
    guild = {"Gerade teilt niemand seine Position.",
        "Positionen erscheinen, wenn Mitglieder mit Guild Trip „Position teilen“ einschalten (Optionen › Teilen)."},
    trainers = {"Keine Lehrer bekannt.", "Das Lehrer-Verzeichnis kommt aus dem Modul Berufe. Oben rechts lässt sich wählen, welche Lehrer gezeigt werden."},
    merchants = {"Noch keine Händler bekannt.", "Guild Trip merkt sich jeden Händler, den du öffnest – mit Ort und Angebot. Mit „Händler-Funde teilen“ (Optionen › Teilen) füllt die Gilde das Verzeichnis gemeinsam."},
    flights = {"Noch keine Flugpunkte gemerkt.", "Öffne einmal eine Flugkarte beim Flugmeister, dann kennt Guild Trip deine Flugpunkte."},
}

function Page:Build(panel)
    local W = ONE.UI.Layout.width
    local H = ONE.Geometry.tokens.contentHeight
    self.view = self.view or "guild"
    local bookL, bookR
    local LX, LW, LY = 0, W, 0          -- Zielauswahl (Reiter + Liste)

    -- Oben: aktuelles Ziel mit Entfernung und Reisetipp
    local top = Card(panel, 0, 0, W, 92, "AKTUELLES ZIEL")
    local icon = top:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("TOPLEFT", top, "TOPLEFT", 16, -40)
    icon:SetTexture("Interface\\AddOns\\ONE_Nav\\Textures\\Arrow")
    if icon.SetVertexColor then icon:SetVertexColor(1, .82, 0) end
    local textW = (W - 66 - 150)
    local goal = ONE.Kit:Stack(top, 66, -40, textW, 0):Text("", "body", "accent")
    local tip = ONE.Kit:Stack(top, 66, -60, textW, 0):Text("", "small", "soft", nil)
    local stop = ONE.Widgets:Button(top, T("Navi beenden"), 130, 26, "TOPRIGHT",
        -14, -44, function()
        nav.Arrow:Stop(T("Navi beendet.")) ONE.UI:Refresh()
    end, "primary")

    -- Umschalter: Gilde | Lehrer | Flugmeister
    local tabs = {}
    local tabY = -102
    local function Tab(id, x, width)
        -- Buch: vier Reiter muessen auf die rechte Seite passen
        tabs[id] = ONE.Widgets:Button(panel, "", width, 24, "TOPLEFT", x, tabY, function()
            Page.view = id ONE.UI:Refresh()
        end)
    end
    Tab("guild", 0, 120)
    Tab("trainers", 126, 110)
    Tab("flights", 242, 120)
    Tab("merchants", 368, 100)
    -- 0.6.8: mit Symbolleiste stehen die Zielarten oben in der Kopfzeile
    local headerViews = ONE.UI.SetViews and ONE.UI:SetViews("nav", {}) or false
    if headerViews then ONE.UI:RetireButtons(tabs.guild, tabs.trainers, tabs.flights, tabs.merchants) end

    -- Lehrer-Art (nur in der Ansicht Lehrer): im Buch links unter dem Ziel, sonst rechts neben den Reitern
    local trainerFilter = ONE.Kit:Dropdown(panel, {point = "TOPLEFT", x = (W - 200), y = (tabY - 2),
        width = 200,
        options = function() return Page:TrainerFilterOptions() end,
        get = function() return Page:TrainerFilter() end, set = function(v) Page:SetTrainerFilter(v) end,
        onChange = function() ONE.UI:Refresh() end})

    -- Haendler-Angebot (nur in der Ansicht Haendler), gleicher Platz wie die Lehrer-Auswahl
    local merchantFilter = ONE.Kit:Dropdown(panel, {point = "TOPLEFT", x = (W - 200), y = (tabY - 2),
        width = 200,
        options = function() return nav.Merchants:FilterOptions() end,
        get = function() return nav.Merchants:Filter() end, set = function(v) nav.Merchants:SetFilter(v) end,
        onChange = function() ONE.UI:Refresh() end})

    local listY = -134
    local listH = (H - 134 - 8)
    local NAMEW, DISTW = 200, 110
    local list = ONE.Kit:List(panel, {x = LX, y = listY, width = LW, height = listH, rowHeight = 24,
        columns = {
            {key = "name", title = "ZIEL", width = NAMEW, indent = 8},
            {key = "info", title = "WO", width = math.max(4, LW - 24 - NAMEW - DISTW - 36 - 24)},
            {key = "dist", title = "ENTFERNUNG", width = DISTW, align = "RIGHT"},
            {key = "go", title = "", width = 36, align = "CENTER"},
        },
        render = function(row, it, cells)
            cells.name:SetText(it.name)
            cells.name:SetTextColor(1, .82, 0)
            cells.info:SetText((it.info or ""))
            cells.info:SetTextColor(.85, .85, .85)
            cells.dist:SetText(it.distText or "")
            -- kleiner Navi-Pfeil; nur er startet das Navi (Zeilenklick nicht mehr, Nutzer-Wunsch)
            cells.go:SetText("")
            if not row.navi then
                row.navi = ONE.Widgets:NaviArrow(row, 16, "CENTER", 0, 0, function(self)
                    if self.item and self.item.go then self.item.go() ONE.UI:Refresh() end
                end, function(self) return self.item and T("Navi zu %s", self.item.name) or nil end)
                if row.navi.ClearAllPoints then row.navi:ClearAllPoints() end
                row.navi:SetPoint("CENTER", cells.go, "CENTER", 0, 0)
            end
            row.navi.item = it
            if it.go then row.navi:Show() else row.navi:Hide() end
        end,
        -- Gildenmitglied: Klick oeffnet das Namens-Menue (Navi, Fluestern, Einladen …)
        onClick = function(row, it)
            if it.member and ONE.PlayerMenu then ONE.PlayerMenu:Open(row, it.member) end
        end,
        onEnter = function(row, it)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(it.name)
            if it.info and it.info ~= "" then GameTooltip:AddLine(it.info, 1, 1, 1) end
            local m = it.merchant
            if m then
                GameTooltip:AddLine(nav.Merchants.CatText(m.cats), .9, .9, .9, true)
                for _, c in ipairs(nav.Merchants.CATEGORIES) do
                    local list = m.items and m.items[c[1]]
                    if list and #list > 0 and c[1] ~= "misc" then
                        GameTooltip:AddLine(T(c[2]) .. ": " .. table.concat(list, ", "), .7, .7, .7, true)
                    end
                end
            end
            GameTooltip:AddLine(T("Grüner Pfeil: Navi dorthin"), .4, 1, .6)
            if it.member then GameTooltip:AddLine(T("Klick: Navi, Flüstern, Einladen …"), .8, .8, .8) end
            GameTooltip:Show()
        end,
    })
    local empty = ONE.Kit:Stack(panel, LX + 12, -170, LW - 24, 4)
    local emptyTitle = empty:Text("", "body", "text")
    local emptyHint = empty:Text("", "small", "soft", 3)

    -- Pfeil-Einstellungen stehen in Optionen › Navi (Page:Register)

    return function()
        local arrow = nav.Arrow
        if arrow.active then
            local s = arrow.state or {}
            local adv = s.advice or {}
            local dist = adv.distance and nav.Travel.FormatDistance(adv.distance) or ""
            goal:SetText(T("Zu %s", ShortName(arrow.target)) .. (dist ~= "" and ("  ·  " .. dist) or ""))
            tip:SetText(T(adv.text or "") .. (adv.tip and ("  ·  " .. adv.tip) or ""))
            stop:Show()
            icon:SetAlpha(1)
        else
            goal:SetText(T("Kein Navi aktiv."))
            tip:SetText(T("Wähle unten ein Ziel – der Pfeil zeigt die Richtung, keine Straßen."))
            stop:Hide()
            icon:SetAlpha(.35)
        end
        local g = GuildModule()
        local counts = {guild = g and #g:LivePeers() or 0}
        tabs.guild:SetText(T("Gilde (%d)", counts.guild))
        tabs.trainers:SetText(T("Lehrer"))
        tabs.flights:SetText(T("Flugmeister"))
        tabs.merchants:SetText(T("Händler"))
        local merchantsOn = not ONE.FeatureOn or ONE:FeatureOn("nav.merchants")
        if merchantsOn then tabs.merchants:Show() else tabs.merchants:Hide() if self.view == "merchants" then self.view = "guild" end end
        if merchantFilter.frame then
            if self.view == "merchants" then merchantFilter.frame:Show() merchantFilter:Refresh() else merchantFilter.frame:Hide() end
        end
        if headerViews then
            local function Go(key) Page.view = key ONE.UI:Refresh() end
            local items = {{key = "guild", label = T("Gilde (%d)", counts.guild), onClick = Go},
                {key = "trainers", label = "Lehrer", onClick = Go}, {key = "flights", label = "Flugmeister", onClick = Go}}
            if merchantsOn then items[#items + 1] = {key = "merchants", label = "Händler", onClick = Go} end
            ONE.UI:SetViews("nav", items, self.view)
        end
        for id, b in pairs(tabs) do
            if id == self.view then if b.LockHighlight then b:LockHighlight() end
            elseif b.UnlockHighlight then b:UnlockHighlight() end
        end
        if trainerFilter.frame then
            if self.view == "trainers" then trainerFilter.frame:Show() trainerFilter:Refresh() else trainerFilter.frame:Hide() end
        end
        local items = self:Targets(self.view)
        list:SetItems(items)
        if #items == 0 then
            local e = EMPTY[self.view]
            emptyTitle:SetText(T(e[1]))
            emptyHint:SetText(T(e[2]))
            if self.view == "guild" and not g then emptyTitle:SetText(T("Das Gildenmodul ist nicht installiert.")) end
            if self.view == "merchants" and nav.Merchants:Filter() ~= "all" and next(nav.Merchants:Store()) then
                emptyTitle:SetText(T("Kein Händler mit diesem Angebot bekannt."))
                emptyHint:SetText(T("Oben rechts eine andere Gruppe wählen. Jeder Händler, den du (oder die Gilde) öffnest, kommt dazu."))
            end
            if self.view == "trainers" and self:TrainerFilter() ~= "all" then
                emptyTitle:SetText(T("Keine passenden Lehrer bekannt."))
                emptyHint:SetText(T("Oben rechts eine andere Lehrer-Art wählen. Neue Lehrer merkt sich Guild Trip, sobald du einen ansprichst."))
            end
            emptyTitle:Show() emptyHint:Show()
        else
            emptyTitle:Hide() emptyHint:Hide()
        end
    end
end

-- Kachel: wie viele Mitglieder live teilen, Sprung zur Navi-Seite.
local function NaviTile(card, body)
    local count = body:Text("", "body", "text")
    local hint = body:Text(T("Pfeil und Reisetipp zu Mitgliedern"), "small", "soft")
    body:Action(T("Navi öffnen"), function() ONE.UI:OpenLink("nav") end)
    return function()
        local g = GuildModule()
        local n = g and #g:LivePeers() or 0
        count:SetText(n == 1 and T("1 Mitglied live") or T("%d Mitglieder live", n))
        hint:SetText(nav.Arrow.active and T("Aktiv: zu %s", ShortName(nav.Arrow.target)) or T("Pfeil und Reisetipp zu Mitgliedern"))
    end
end

function Page:Register()
    if not (ONE.UI and ONE.UI.AddTab and ONE.Kit) then return false end
    ONE.Kit:RegisterTile("navi", {title = "NAVI", order = 30, build = NaviTile})
    -- Optionen › Navi (die Funktionen "nav.*" aus Init.lua stehen dort mit)
    if ONE.UI.AddSetting then
        local opt = function(o) o.category = "nav" ONE.UI:AddSetting(o) end
        opt({id = "navStyle", section = "Pfeil", order = 10, kind = "dropdown", width = 200, label = "Aussehen des Pfeils",
            options = function()
                return {{value = "one", text = "Guild Trip (gold)"}, {value = "blizzard", text = "Blizzard"}}
            end,
            get = function() return nav.Arrow:Settings().style == "blizzard" and "blizzard" or "one" end,
            set = function(v) nav.Arrow:Create() nav.Arrow:SetStyle(v) end})
        -- Weg auf Minimap/Weltkarte: goldene Punkte (Standard) oder Fussspuren
        opt({id = "navRouteStyle", section = "Weg", order = 22, kind = "dropdown", width = 200, label = "Weg zeigen als",
            options = function()
                return {{value = "dots", text = "Goldene Punkte"}, {value = "feet", text = "Fußspuren"}}
            end,
            get = function() return nav.RouteDots and nav.RouteDots:Style() or "dots" end,
            set = function(v) if nav.RouteDots then nav.RouteDots:SetStyle(v) end end})
        opt({id = "navLock", section = "Pfeil", order = 11, label = "Festsetzen", tooltip = "Der Pfeil lässt sich dann nicht mehr verschieben.",
            get = function() return nav.Arrow:Settings().locked end,
            set = function(on) nav.Arrow:Create() nav.Arrow:SetLocked(on) end})
        opt({id = "navPlayer", section = "Pfeil", order = 12, label = "Goldener Spielerpfeil",
            tooltip = "Ersetzt dein Spieler-Symbol auf der Minimap durch den goldenen Guild-Trip-Pfeil. Die große Karte behält ihren eigenen Pfeil.",
            get = function() return nav.PlayerArrow:Enabled() end, set = function(on) nav.PlayerArrow:SetEnabled(on) end})
        opt({id = "navReset", section = "Pfeil", order = 13, kind = "button", label = "Pfeil über die Figur setzen",
            onClick = function() nav.Arrow:Create() nav.Arrow:ResetPosition() end})
    end
    return ONE.UI:AddTab("nav", T("Navi"), function(panel) return self:Build(panel) end)
end
