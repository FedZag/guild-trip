-- Guild Trip Dungeons: Ansicht "Ausfluege" im Reiter Dungeons.
-- Links (bzw. oben) die geplanten Ausfluege der Gilde, rechts (bzw. unten) die
-- Karte: Details und Anmeldungen – oder das Formular "Ausflug planen".
local _, dungeons = ...
local ONE = _G.ProjectONE
local function Paint(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a) end
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local TripsPage = {}
dungeons.TripsPage = TripsPage

local function Text(parent, font, x, y, width, role, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    fs:SetText(T(text or ""))
    if ONE.Themes then ONE.Themes:RegisterText(fs, role or "text") end
    return fs
end

function TripsPage:Build(panel)
    local Tr, S = dungeons.Trips, dungeons.Share
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local state = {form = false, day = 0, minutes = 20 * 60}
    local bookL, bookR

    local listW = bookL and bookL.width or W
    local cols = {
        {key = "when", title = "WANN", width = bookL and 96 or 130},
        {key = "dungeon", title = "ZIEL", width = bookL and (listW - 24 - 6 - 96 - 44) or 220},
        {key = "count", title = "DABEI", width = 44, align = "CENTER"},
    }
    if not bookL then cols[#cols + 1] = {key = "leader", title = "VON", width = W - 24 - 6 - 130 - 220 - 44 - 20} end
    local listH = bookL and (H - 54 - 8) or (22 * 6 + 22)
    local list = ONE.Kit:List(panel, {x = 0, y = -54, width = listW, height = listH, rowHeight = 22, columns = cols,
        render = function(row, trip, cells)
            local c = Tr:Counts(trip)
            cells.when:SetText(Tr:When(trip.start))
            cells.when:SetTextColor(1, 1, 1)
            cells.dungeon:SetText(Tr:Name(trip))
            cells.dungeon:SetTextColor(1, .82, 0)
            cells.count:SetText(tostring(c.yes))
            cells.count:SetTextColor(.9, .9, .9)
            if cells.leader then
                cells.leader:SetText(Tr.Short(trip.leader) .. (Tr:IsLeader(trip) and " (" .. T("du") .. ")" or ""))
                cells.leader:SetTextColor(.9, .9, .9)
            end
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                Paint(row.selection, 1, .82, 0, .14)
            end
            if state.trip == trip and not state.form then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, trip) state.trip, state.form, state.prep = trip, false, false TripsPage:Refresh() end,
    })
    local empty = Text(panel, "GameFontHighlight", 16, -98, listW - 32, "soft")
    if empty.SetWordWrap then empty:SetWordWrap(true) end

    -- Karte
    local cardTop, CW = -54 - listH - 10, W
    local card = CreateFrame("Frame", nil, panel)
    if bookL then
        cardTop, CW = -54, bookR.width
        card:SetPoint("TOPLEFT", panel, "TOPLEFT", bookR.x, cardTop)
    else
        card:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, cardTop)
    end
    card:SetSize(CW, H + cardTop)
    if ONE.Themes then ONE.Themes:RegisterPanel(card) end
    local TW = CW - 32
    local headline = Text(card, "GameFontNormal", 16, -12, TW, "accent")
    local line1 = Text(card, "GameFontHighlight", 16, -34, TW, "text")
    local line2 = Text(card, "GameFontHighlight", 16, -54, TW - 26, "soft")
    local line3 = Text(card, "GameFontHighlight", 16, -74, TW, "text")

    -- Knoepfe: zwei Reihen mit je zwei Knoepfen
    local BW = math.floor((CW - 32 - 10) / 2)
    local function Btn(label, col, rowN, fn)
        return ONE.Widgets:Button(card, label, BW, 26, "TOPLEFT", 16 + col * (BW + 10), -100 - rowN * 32, fn)
    end
    local function Selected() return state.trip and Tr:Get(state.trip.id) end
    local bYes = Btn("", 0, 0, function()
        local t = Selected() if t then Tr:SignUp(t.id, "yes") TripsPage:Refresh() end
    end)
    local bMaybe = Btn(T("Vielleicht"), 1, 0, function()
        local t = Selected() if t then Tr:SignUp(t.id, "maybe") TripsPage:Refresh() end
    end)
    local bNo = Btn(T("Abmelden"), 0, 1, function()
        local t = Selected()
        if not t then return end
        if Tr:IsLeader(t) then Tr:Cancel(t.id) state.trip = nil ONE:Print(T("Ausflug abgesagt."))
        else Tr:SignUp(t.id, "no") end
        TripsPage:Refresh()
    end)
    -- kleiner Navi-Pfeil hinter der Zeile "Treffpunkt" (wie ueberall im Addon)
    local bNavi = ONE.Widgets:NaviArrow(card, 18, "TOPRIGHT", -16, -52, function()
        local t = Selected()
        local m = t and t.meet
        local navi = ONE.modules and ONE.modules.nav
        if m and m.mapID and navi and navi.PointTo then navi:PointTo(T("Treffpunkt"), m.mapID, m.x, m.y) end
    end, function()
        local t = Selected()
        local m = t and t.meet
        return T("Navi zum Treffpunkt"), m and m.name ~= "" and m.name or nil
    end)
    local bPrep = Btn(T("Reisevorbereitung"), 1, 1, function() state.prep = true TripsPage:Refresh() end)
    local bPlan = Btn(T("Ausflug planen"), 0, 2, function() state.form = true TripsPage:Refresh() end)

    -- Reisevorbereitung: je Quest Traeger / holen / Vorquest fehlt; Klick = Navi zum Questgeber
    local prep = CreateFrame("Frame", nil, card)
    prep:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -30)
    prep:SetSize(CW, H + cardTop - 30)
    local prepInfo = Text(prep, "GameFontHighlight", 16, -4, TW, "soft")
    if prepInfo.SetWordWrap then prepInfo:SetWordWrap(true) end
    local QW = bookL and 110 or 200
    local prepList = ONE.Kit:List(prep, {x = 4, y = -44, width = CW - 8, height = H + cardTop - 30 - 44 - 40, rowHeight = 22,
        columns = {
            {key = "quest", title = "QUEST", width = QW},
            {key = "state", title = "STAND", width = CW - 8 - 24 - 6 - QW - 24},
            {key = "go", title = "", width = 22},
        },
        render = function(frame, row, cells)
            cells.quest:SetText(dungeons.Model:Title(row.quest))
            cells.quest:SetTextColor(1, .82, 0)
            cells.state:SetText(Tr:PrepText(row))
            local color = ({fetch = {1, .5, .25}, locked = {1, .35, .35}, self = {.4, .8, 1}, carried = {.5, .9, .5}})[row.state]
            cells.state:SetTextColor(color[1], color[2], color[3])
            cells.go:SetText("")
            -- kleiner Navi-Pfeil zum Questgeber (Zeilenklick startet nichts, wie ueberall)
            if not frame.navi then
                frame.navi = ONE.Widgets:NaviArrow(frame, 16, "RIGHT", -6, 0, function(self)
                    local q, M = self.row and self.row.quest, dungeons.Model
                    local mapID = q and M:MapFor(q)
                    local navi = ONE.modules and ONE.modules.nav
                    if mapID and q.x and navi and navi.PointTo then navi:PointTo(q.giver or M:Title(q), mapID, q.x, q.y) end
                end, function(self)
                    local q = self.row and self.row.quest
                    return q and T("Navi zu %s", q.giver or dungeons.Model:Title(q)) or nil, q and q.location or nil
                end)
            end
            frame.navi.row = row
            local q = row.quest
            if dungeons.Model:MapFor(q) and q.x then frame.navi:Show() else frame.navi:Hide() end
        end,
    })
    local bPrepBack = ONE.Widgets:Button(prep, T("‹ zurück"), 120, 24, "BOTTOMLEFT", 16, 8, function()
        state.prep = false TripsPage:Refresh()
    end)

    -- Teilnehmer (bis zu 8 Zeilen)
    local whoHead = Text(card, "GameFontNormalSmall", 16, -204, TW, "accent")
    local who = {}
    for i = 1, 8 do
        who[i] = Text(card, "GameFontHighlight", 16, -222 - (i - 1) * 18, TW, "text")
        -- Klickflaeche ueber der Zeile: Namens-Menue (Navi, Fluestern, Einladen …)
        local hit = CreateFrame("Button", nil, card)
        hit:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -220 - (i - 1) * 18)
        hit:SetSize(TW, 18)
        if hit.RegisterForClicks then hit:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        hit:SetScript("OnClick", function(self) if self.name and ONE.PlayerMenu then ONE.PlayerMenu:Open(self, self.name) end end)
        hit:SetScript("OnEnter", function(self)
            if not (self.name and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.name)
            GameTooltip:AddLine(T("Klick: Navi, Flüstern, Einladen …"), .8, .8, .8)
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        who[i].hit = hit
    end

    -- Termin-Fenster (TripsPlanner.lua): ueberdeckt Liste und Karte, solange es offen ist
    local planner = dungeons.TripsPlanner and dungeons.TripsPlanner:Build(panel, function(trip)
        state.form = false
        if trip then state.trip = trip end
        TripsPage:Refresh()
    end)

    local details = {line1, line2, line3, bYes, bMaybe, bNo, bNavi, whoHead}
    for _, fs in ipairs(who) do details[#details + 1] = fs details[#details + 1] = fs.hit end

    self.refresh = function()
        local trips = Tr:List()
        list:SetItems(trips)
        if TripsPage.openForm then
            state.form, state.prep, TripsPage.openForm = true, false, nil
            if planner then planner:Hide() end -- neu oeffnen = frische Werte
        end
        if TripsPage.selectId then
            for _, t in ipairs(trips) do
                if t.id == TripsPage.selectId then state.trip, state.form, state.prep = t, false, false end
            end
            TripsPage.selectId = nil
        end
        local still = false
        for _, t in ipairs(trips) do if t == state.trip then still = true end end
        if not still then state.trip = trips[1] end
        empty:SetText(#trips == 0 and T("Noch kein Ausflug geplant.\n\nPlane einen mit „Ausflug planen“: Dungeon, Tag und Uhrzeit wählen – "
            .. "die Gilde sieht ihn sofort und kann sich anmelden.") or "")

        if state.prep and state.trip and not state.form then
            for _, w in ipairs(details) do w:Hide() end
            bPlan:Hide() bPrep:Hide()
            prep:Show()
            local trip = state.trip
            local rows, unknown, members = Tr:Prep(trip)
            headline:SetText(T("Reisevorbereitung") .. "  –  " .. Tr:Name(trip))
            local info = T("Eine Quest reicht pro Gruppe: der Träger teilt sie im Dungeon. Vorquests braucht jeder selbst.")
            if #unknown > 0 then
                info = info .. "\n|cff9d9d9d" .. T("Ohne geteilten Fortschritt: %s", table.concat(unknown, ", ")) .. "|r"
            end
            prepInfo:SetText(info)
            prepList:SetItems(rows)
            if #rows == 0 and #members > 0 then prepInfo:SetText(info .. "\n|cff80e680" .. T("Alles erledigt – niemand braucht hier noch eine Quest.") .. "|r") end
            if bPrepBack.Show then bPrepBack:Show() end
            return
        end
        prep:Hide()
        -- Termin-Fenster offen: Liste und Karte ausblenden
        if state.form and planner then
            list.box:Hide() empty:Hide() card:Hide()
            if not planner:IsShown() then dungeons.TripsPlanner:Open(TripsPage.planKind) TripsPage.planKind = nil end
            return
        end
        if planner and planner:IsShown() then planner:Hide() end
        list.box:Show() empty:Show() card:Show()
        for _, w in ipairs(details) do w:Show() end
        bPlan:Show()
        -- Reisevorbereitung nur bei Dungeons (eigene Ziele haben keine Dungeon-Quests)
        if state.trip and not Tr.IsFree(state.trip) then bPrep:Show() else bPrep:Hide() end
        local trip = state.trip
        for _, fs in ipairs(who) do fs:SetText("") fs.hit.name = nil fs.hit:Hide() end
        if not trip then
            headline:SetText(T("Kein Ausflug ausgewählt"))
            line1:SetText("") line2:SetText("") line3:SetText("") whoHead:SetText("")
            bYes:Hide() bMaybe:Hide() bNo:Hide() bNavi:Hide()
            return
        end
        local c = Tr:Counts(trip)
        local leader = Tr:IsLeader(trip)
        -- Zeitraum mit Ende, wenn eine Dauer geplant ist
        local when = Tr:When(trip.start)
        if (trip.dur or 0) > 0 and type(date) == "function" then when = when .. "–" .. date("%H:%M", trip.start + trip.dur * 60) end
        headline:SetText(Tr:Name(trip) .. "  –  " .. when)
        local info = Tr:InfoText(trip)
        line1:SetText(T("Leitung: %s", Tr.Short(trip.leader)) .. (leader and " (" .. T("du") .. ")" or "")
            .. (info ~= "" and ("  ·  " .. info) or ""))
        local m = trip.meet or {}
        line2:SetText(T("Treffpunkt: %s", (m.name and m.name ~= "") and m.name or T("noch offen")))
        -- geplante Rollen: "T 1/1 · H 0/1 · DD 2/3" (zeigt, was noch fehlt), sonst Zusagen je Rolle
        local roles = Tr:RoleText(trip)
        line3:SetText((roles and (T("Zusagen: %d", c.yes) .. "  ·  " .. roles)
            or T("Zusagen: %d  (%s %d · %s %d · %s %d)", c.yes, S:RoleName("T"), c.T, S:RoleName("H"), c.H, S:RoleName("D"), c.D))
            .. (c.maybe > 0 and ("  ·  " .. T("vielleicht: %d", c.maybe)) or "")
            .. (trip.note and ("  ·  " .. trip.note) or ""))
        local mine = Tr:Mine(trip)
        local role = S:RoleName(S:Settings().role)
        bYes:Show() bMaybe:Show() bNo:Show()
        bYes:SetText(mine and mine.status == "yes" and T("Du kommst (%s)", role) or T("Ich komme (%s)", role))
        if bYes.SetEnabled then bYes:SetEnabled(not (mine and mine.status == "yes" and mine.role == S:Settings().role)) end
        if bMaybe.SetEnabled then bMaybe:SetEnabled(not (mine and mine.status == "maybe")) end
        bNo:SetText(leader and T("Ausflug absagen") or T("Abmelden"))
        if bNo.SetEnabled then bNo:SetEnabled(leader or (mine ~= nil and mine.status ~= "no")) end
        if m.mapID then bNavi:Show() else bNavi:Hide() end
        -- Ab 30 Minuten vor dem Start: Ankunftstafel (Entfernung, Ankunft) statt Rolle allein
        local people = Tr:Signups(trip)
        local board = Tr:BoardActive(trip) and m.mapID and Tr:Board(trip) or nil
        local head = #people > 0 and T("DABEI") or ""
        if board then
            head = T("ANKUNFT AM TREFFPUNKT")
            local summon = Tr:SummonList(board)
            if #summon > 0 then head = head .. "  ·  " .. T("Beschwören: %s", table.concat(summon, ", ")) end
        end
        whoHead:SetText(head)
        for i, s in ipairs(people) do
            if i > #who then break end
            local name = dungeons.Page.ClassName and dungeons.Page:ClassName(s.class, s.name) or s.name
            local text = name .. " (" .. (s.level or 0) .. ")  ·  " .. S:RoleName(s.role)
            if board and board[i] then
                local e = board[i]
                local color = ({here = "|cff80e680", away = "|cffffd100", continent = "|cffff8040"})[e.state] or "|cff9d9d9d"
                -- Rolle weglassen, damit die Zeile auch im Buch passt
                text = name .. " (" .. (s.level or 0) .. ")  ·  " .. color .. Tr:BoardText(e) .. "|r"
            end
            who[i]:SetText(s.status == "maybe" and ("|cff9d9d9d" .. text .. "  ·  " .. T("vielleicht") .. "|r") or text)
            who[i].hit.name = s.name
            who[i].hit:Show()
        end
    end
    return self.refresh
end

function TripsPage:Refresh() if self.refresh then self.refresh() end end
