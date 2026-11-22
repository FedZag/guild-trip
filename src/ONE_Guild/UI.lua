local _, guild = ...
local ONE = _G.ProjectONE
local function Paint(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a) end
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

-- "Was steht an": kleiner Navi-Knopf rechts in der Zeile (nur wenn der Eintrag ein Ziel hat,
-- z. B. "Angeln: Geselle jetzt lernbar" -> naechster Lehrer, der Geselle lehrt)
-- Seit 15.11.2026 ein kleiner Navi-Pfeil (wie ueberall), Ziel im Tooltip.
local function FeedNavi(row, w, h)
    local size = math.min(h or 16, 18)
    local nb = ONE.Widgets:NaviArrow(row, size, "RIGHT", -2, 0, function(self)
        if self.go then self.go() ONE.UI:Refresh() end
    end, function(self) return self.naviTip end)
    nb:Hide()
    return nb
end
local function SetFeedNavi(row, it, textW)
    local nb = row.navi
    if not nb then return end
    if it and it.navi then
        nb.go, nb.naviTip = it.navi, it.naviTip
        nb:Show()
        if row.text and row.text.SetWidth then row.text:SetWidth(textW - (nb.GetWidth and nb:GetWidth() or 50) - 6) end
    else
        nb.go, nb.naviTip = nil, nil
        nb:Hide()
        if row.text and row.text.SetWidth then row.text:SetWidth(textW) end
    end
end
local UI = {}
guild.UI = UI

local function Label(parent, text, font, x, y, width)
    local line = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    line:SetPoint("TOPLEFT", x, y)
    line:SetWidth(width or 630)
    line:SetJustifyH("LEFT")
    line:SetText(text)
    if ONE.Themes and ONE.Themes.RegisterText then
        local role=(font=="GameFontNormalSmall" or font=="GameFontNormal") and "accent"
            or (font=="GameFontHighlightSmall" and "soft" or "text")
        ONE.Themes:RegisterText(line,role)
    end
    return line
end

-- Gemeinsamer Karten-Header fuer Guild und Core; beide Themes nutzen
-- dieselben Sicherheitsabstaende zur sichtbaren Panel-Rahmenkante.
local function CardHeader(parent, title, font, width)
    local h=ONE.Geometry:CardHeader(width)
    return Label(parent,title,font,h.x,h.y,h.width)
end

local function Button(parent, text, width, x, y, click)
    return ONE.Widgets:ActionButton(parent,text,{x=x,y=y,width=width},click,"secondary","fill")
end

-- Wiederverwendbare Inhaltskarte: 2.5D-Rahmen aus dem aktiven ONE-Theme.
-- Nur passive Textur; eigene Ereignislogik und Addon-API bleiben unverändert.
local function Card(parent, x, y, width, height)
    local frame=CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(width, height)
    -- Kalendertexte liegen direkt auf dem Elternfenster und müssen VOR der Karte bleiben.
    if frame.SetFrameLevel and parent.GetFrameLevel then
        frame:SetFrameLevel(parent:GetFrameLevel())
    end
    if ONE.Themes and type(ONE.Themes.RegisterPanel)=="function" then ONE.Themes:RegisterPanel(frame) end
    return frame
end

-- ===== Datumsrechnung fuer die Monatsansicht (Mo = 1 ... So = 7, ISO-Kalenderwochen) =====
local Dates = {}
UI.Dates = Dates
Dates.months = {"Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August",
    "September", "Oktober", "November", "Dezember"}
Dates.weekdaysShort = {"Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"}
Dates.weekdaysLong = {"Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"}
local monthLengths = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local monthStart = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334}
local function IsLeap(y) return y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0) end
function Dates.DaysInMonth(y, m) return (m == 2 and IsLeap(y)) and 29 or monthLengths[m] end
function Dates.DayNumber(y, m, d)
    local p = y - 1
    return p * 365 + math.floor(p / 4) - math.floor(p / 100) + math.floor(p / 400)
        + monthStart[m] + ((m > 2 and IsLeap(y)) and 1 or 0) + d
end
function Dates.Weekday(y, m, d) return (Dates.DayNumber(y, m, d) - 1) % 7 + 1 end
function Dates.IsoWeek(y, m, d)
    local thursday = Dates.DayNumber(y, m, d) - Dates.Weekday(y, m, d) + 4
    local wy = y
    if thursday < Dates.DayNumber(y, 1, 1) then wy = y - 1
    elseif thursday > Dates.DayNumber(y, 12, 31) then wy = y + 1 end
    return math.floor((thursday - Dates.DayNumber(wy, 1, 1)) / 7) + 1, wy
end
function Dates.Shift(y, m, delta)
    local i = y * 12 + (m - 1) + delta
    return math.floor(i / 12), i % 12 + 1
end
-- 6 Wochen x 7 Tage, beginnend mit dem Montag vor (oder am) Monatsersten.
function Dates.MonthGrid(y, m)
    local first = Dates.Weekday(y, m, 1)
    local cy, cm, cd = y, m, 1
    if first > 1 then
        cy, cm = Dates.Shift(y, m, -1)
        cd = Dates.DaysInMonth(cy, cm) - first + 2
    end
    local weeks = {}
    for w = 1, 6 do
        local week = {days = {}}
        for i = 1, 7 do
            week.days[i] = {year = cy, month = cm, day = cd, weekday = i, inMonth = cy == y and cm == m}
            cd = cd + 1
            if cd > Dates.DaysInMonth(cy, cm) then cd = 1 cy, cm = Dates.Shift(cy, cm, 1) end
        end
        week.kw = Dates.IsoWeek(week.days[1].year, week.days[1].month, week.days[1].day)
        weeks[w] = week
    end
    return weeks
end
function Dates.Today(calendar)
    local now = calendar and type(calendar.GetCurrentTime) == "function" and calendar:GetCurrentTime()
    if type(now) == "table" and now.year then return {year = now.year, month = now.month, day = now.monthDay} end
    local d = (type(date) == "function" and date("*t")) or (os and os.date and os.date("*t"))
    if type(d) == "table" then return {year = d.year, month = d.month, day = d.day} end
    return {year = 2026, month = 1, day = 1}
end

-- Farben je Eintragsart (WoW-Events orange, Gilde gruen, eigene/Community blau, Resets grau)
local TYPE_COLOR = {
    HOLIDAY = {1, .62, .2}, GUILD_EVENT = {.45, .95, .45}, GUILD_ANNOUNCEMENT = {.45, .95, .45},
    PLAYER = {.55, .8, 1}, COMMUNITY_EVENT = {.55, .8, 1}, RAID_RESET = {.7, .7, .7}, GUILDTRIP = {.45, .95, .45},
}
local TYPE_NAME = {HOLIDAY = "WoW-Event", GUILD_EVENT = "Gildentermin", GUILD_ANNOUNCEMENT = "Gildenankündigung",
    PLAYER = "Eigener Termin", COMMUNITY_EVENT = "Community", RAID_RESET = "Schlachtzug-Reset", GUILDTRIP = "Gildenausflug"}
local function TypeColor(entry) return TYPE_COLOR[entry.calendarType] or {1, .82, 0} end

local function EntryTime(entry)
    local t = entry.startTime or {}
    if entry.holiday then
        if entry.sequenceType == "START" then return string.format(T("ab %02d:%02d"), t.hour or 0, t.minute or 0) end
        if entry.sequenceType == "END" and entry.endTime then
            return string.format(T("bis %02d:%02d"), entry.endTime.hour or 0, entry.endTime.minute or 0)
        end
        return "ganztags"
    end
    return string.format("%02d:%02d", t.hour or 0, t.minute or 0)
end

-- Filter (Legende unten): welche Arten im Kalender erscheinen
local TYPE_GROUP = {HOLIDAY = "holiday", GUILD_EVENT = "guild", GUILD_ANNOUNCEMENT = "guild",
    PLAYER = "own", COMMUNITY_EVENT = "own", RAID_RESET = "reset", GUILDTRIP = "guild"}
local fallbackFilter = {}
local function Filters()
    if not ONE.db then return fallbackFilter end
    ONE.db.guild = ONE.db.guild or {}
    ONE.db.guild.calendarFilter = type(ONE.db.guild.calendarFilter) == "table" and ONE.db.guild.calendarFilter or {}
    return ONE.db.guild.calendarFilter
end
local function Visible(entry) return Filters()[TYPE_GROUP[entry.calendarType] or "own"] ~= false end

-- Symbol eines Eintrags: Blizzards Event-Bild, sonst nach Art
local TYPE_ICON = {
    GUILD_EVENT = "Interface\\Icons\\INV_Shirt_GuildTabard_01", GUILD_ANNOUNCEMENT = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
    PLAYER = "Interface\\Icons\\INV_Misc_Note_01", COMMUNITY_EVENT = "Interface\\Icons\\INV_Misc_Note_01",
    RAID_RESET = "Interface\\Icons\\INV_Misc_PocketWatch_01", HOLIDAY = "Interface\\Icons\\INV_Misc_Rune_01",
    GUILDTRIP = "Interface\\Icons\\INV_Misc_Map_01",
}
local function EntryIcon(entry) return entry.icon or TYPE_ICON[entry.calendarType] or "Interface\\Icons\\INV_Misc_QuestionMark" end

-- Gildenausfluege (ONE_Dungeons) als Kalendereintraege; Klick oeffnet den Ausflug.
-- Nur zur Anzeige – sie stehen nicht in Calendar.events, damit die Termin-
-- Erinnerungen nicht doppelt zu den Ausflugs-Erinnerungen kommen.
local STATUS_TEXT = {yes = "du kommst", maybe = "du kommst vielleicht"}
function UI.TripEntries()
    local dm = ONE.modules and ONE.modules.dungeons
    if not (dm and dm.CalendarTrips and type(date) == "function") then return {} end
    local ok, trips = pcall(dm.CalendarTrips, dm)
    if not ok or type(trips) ~= "table" then return {} end
    local out = {}
    for _, t in ipairs(trips) do
        local d = date("*t", t.start)
        local info = {T("Leitung: %s", t.leader or "?"), t.roles or T("Zusagen: %d", t.coming or 0)}
        if t.info and t.info ~= "" then table.insert(info, 1, t.info) end
        if t.note then info[#info + 1] = t.note end
        if t.meet and t.meet ~= "" then info[#info + 1] = T("Treffpunkt: %s", t.meet) end
        if STATUS_TEXT[t.mine] then info[#info + 1] = T(STATUS_TEXT[t.mine]) end
        out[#out + 1] = {title = T("Ausflug: %s", t.name or "?"), calendarType = "GUILDTRIP", trip = t.id, tripData = t,
            startTime = {year = d.year, month = d.month, monthDay = d.day, hour = d.hour, minute = d.min},
            description = table.concat(info, " · ")}
    end
    return out
end
local function OpenTrip(entry)
    local dm = ONE.modules and ONE.modules.dungeons
    if dm and dm.OpenTrip then dm:OpenTrip(entry.trip) end
end

local function GetDay(y, m, d, all)
    local C = guild.Calendar
    local list = (C and type(C.GetDay) == "function" and C:GetDay(y, m, d)) or {}
    local trips = {}
    for _, e in ipairs(UI.TripEntries()) do
        local t = e.startTime
        if t.year == y and t.month == m and t.monthDay == d then trips[#trips + 1] = e end
    end
    if #trips > 0 then
        local merged = {}
        for _, e in ipairs(list) do merged[#merged + 1] = e end
        for _, e in ipairs(trips) do merged[#merged + 1] = e end
        list = merged
    end
    if all then return list end
    local out = {}
    for _, e in ipairs(list) do if Visible(e) then out[#out + 1] = e end end
    return out
end

function UI:BuildCalendar(panel)
    local W=ONE.UI.Layout.width
    -- Zwei Ansichten: Monatsuebersicht und Detailseite eines Eintrags.
    local list = CreateFrame("Frame", nil, panel)
    list:SetAllPoints(panel)
    local detail = CreateFrame("Frame", nil, panel)
    detail:SetAllPoints(panel)
    detail:Hide()

    -- Buch: wie gehabt. Sonst (15.11.2026, Nutzer-Kritik): keine zweite Ueberschrift
    -- (der Reiter heisst schon "Kalender"), alles 52 px hoeher, breitere rechte Spalte
    -- mit Tag, "Demnaechst" und "Was steht an", unten eine saubere Filter-/Knopfzeile.
    local UP = 52
    Card(list, 0, -4, W, 354)

    local today = Dates.Today(guild.Calendar)
    local view = {year = today.year, month = today.month}
    local selected = {year = today.year, month = today.month, day = today.day}
    local selectedEvent, selectedDetails, selectedError
    local showingDetails = false
    local refreshView

    local function OpenEvent(event)
        if event.trip then return OpenTrip(event) end
        selectedEvent, selectedDetails, selectedError = event, nil, nil
        showingDetails = true
        refreshView()
        ONE.UI:UpdateBackButton()
        if event.holiday or event.description then
            selectedDetails = {description = event.description or "", creator = ""}
            refreshView()
            return
        end
        if type(guild.Calendar.LoadDescription) ~= "function" then return end
        guild.Calendar:LoadDescription(event, function(details, err)
            if selectedEvent ~= event then return end
            selectedDetails, selectedError = details, err
            refreshView()
        end)
    end
    -- "Was steht an": Termin direkt in der Detailansicht oeffnen
    UI.OpenCalendarEvent = OpenEvent

    -- Raster-Masse: KW-Spalte + 7 Tagesspalten links, Tagesansicht rechts.
    local GX, KWW, CW, CH, TOP = 8, 26, 62, 39, -108
    if UP > 0 then CW, CH, TOP = 54, 46, -108 + UP end
    -- Buch: Monatsraster auf der linken Seite, Tagesansicht auf der rechten
    local ICON, STEP = 14, 16
    local gridRight = GX + KWW + 7 * CW
    local RX = gridRight + 12
    local RW = W - RX - 10

    -- Monat wechseln (der Client haelt Vormonat bis naechsten Monat vor).
    local function Move(delta)
        local y, m = Dates.Shift(view.year, view.month, delta)
        local now = Dates.Today(guild.Calendar)
        local distance = (y * 12 + m) - (now.year * 12 + now.month)
        if math.abs(distance) > 1 then return end
        view.year, view.month = y, m
        if selected.year ~= y or selected.month ~= m then
            selected.year, selected.month = y, m
            selected.day = (y == now.year and m == now.month) and now.day or 1
        end
        refreshView()
    end
    local prev = ONE.Widgets:Button(list, "<", 26, 22, "TOPLEFT", GX, -63 + UP, function() Move(-1) end)
    local nextButton = ONE.Widgets:Button(list, ">", 26, 22, "TOPLEFT", gridRight - 26, -63 + UP, function() Move(1) end)
    ONE.Widgets:Button(list, T("Heute"), 64, 22, "TOPLEFT", gridRight - 26 - 6 - 64, -63 + UP, function()
        local now = Dates.Today(guild.Calendar)
        view.year, view.month = now.year, now.month
        selected.year, selected.month, selected.day = now.year, now.month, now.day
        refreshView()
    end)
    local monthLabel = Label(list, "", "GameFontNormalLarge", GX + 34, -66 + UP, gridRight - GX - 34 - 100)
    monthLabel:SetJustifyH("LEFT")

    -- Kopfzeile: KW, Mo ... So
    local kwHead = Label(list, "KW", "GameFontDisableSmall", GX, -92 + UP, KWW)
    kwHead:SetJustifyH("CENTER")
    for i, name in ipairs(Dates.weekdaysShort) do
        name = T(name)
        local head = Label(list, name, "GameFontNormalSmall", GX + KWW + (i - 1) * CW, -92 + UP, CW - 2)
        head:SetJustifyH("CENTER")
        if i >= 6 then head:SetTextColor(.85, .7, .45) end
    end

    local kwLabels, cells = {}, {}
    for w = 1, 6 do
        local y = TOP - (w - 1) * CH
        local kw = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        kw:SetPoint("TOPLEFT", list, "TOPLEFT", GX, y - math.floor(CH / 2) + 6)
        kw:SetWidth(KWW)
        kw:SetJustifyH("CENTER")
        kwLabels[w] = kw
        cells[w] = {}
        for i = 1, 7 do
            local cell = CreateFrame("Button", nil, list)
            cell:SetPoint("TOPLEFT", list, "TOPLEFT", GX + KWW + (i - 1) * CW, y)
            cell:SetSize(CW - 2, CH - 2)
            cell.bg = cell:CreateTexture(nil, "BACKGROUND")
            cell.bg:SetAllPoints(cell)
            cell.mark = cell:CreateTexture(nil, "BORDER")
            cell.mark:SetAllPoints(cell)
            Paint(cell.mark, 1, .82, 0, .16)
            cell.todayLine = cell:CreateTexture(nil, "ARTWORK")
            cell.todayLine:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 0)
            cell.todayLine:SetSize(CW - 2, 2)
            Paint(cell.todayLine, 1, .82, 0, .9)
            cell.num = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cell.num:SetPoint("TOPLEFT", cell, "TOPLEFT", 4, -3)
            cell.num:SetWidth(CW - 10)
            cell.num:SetJustifyH("LEFT")
            -- bis zu drei Symbole (Gildentermine zuerst), "+n" fuer mehr
            cell.icons = {}
            for l = 1, 3 do
                local icon = cell:CreateTexture(nil, "ARTWORK")
                icon:SetSize(ICON, ICON)
                icon:SetPoint("TOPLEFT", cell, "TOPLEFT", 3 + (l - 1) * STEP, -17)
                if icon.SetTexCoord then icon:SetTexCoord(.07, .93, .07, .93) end
                cell.icons[l] = icon
            end
            cell.more = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            -- "+n" rechts oben neben der Tageszahl (hinter den Symbolen waere es zu eng)
            cell.more:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -3, -3)
            -- duenner Streifen: an diesem Tag laeuft ein WoW-Event
            cell.span = cell:CreateTexture(nil, "ARTWORK")
            cell.span:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 0, 0)
            cell.span:SetSize(CW - 2, 3)
            cell:SetScript("OnClick", function(self)
                local d = self.date
                if not d then return end
                selected.year, selected.month, selected.day = d.year, d.month, d.day
                if not d.inMonth then
                    local now = Dates.Today(guild.Calendar)
                    if math.abs((d.year * 12 + d.month) - (now.year * 12 + now.month)) <= 1 then
                        view.year, view.month = d.year, d.month
                    end
                end
                refreshView()
            end)
            cell:SetScript("OnEnter", function(self)
                local d = self.date
                if not (d and GameTooltip) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(string.format("%s, %d. %s %d", T(Dates.weekdaysLong[d.weekday]), d.day,
                    T(Dates.months[d.month]), d.year))
                GameTooltip:AddLine(T("Kalenderwoche %d", Dates.IsoWeek(d.year, d.month, d.day)), .8, .8, .8)
                for _, e in ipairs(GetDay(d.year, d.month, d.day)) do
                    local c = TypeColor(e)
                    GameTooltip:AddLine("|T" .. tostring(EntryIcon(e)) .. ":14|t " .. T(EntryTime(e)) .. "  " .. e.title, c[1], c[2], c[3])
                end
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            cells[w][i] = cell
        end
    end

    -- Rechte Spalte: ausgewaehlter Tag und "Demnaechst"
    -- Buch: rechts oben "Was steht an" (von der Gilde-Seite), darunter der Tag
    local D = UP
    local feedRows = {}
    -- "Was steht an": im Buch rechts oben, sonst unten in der rechten Spalte
    local feedTop = -284
    do
        local head = Label(list, T("Was steht an"), "GameFontNormalSmall", RX, feedTop, RW)
        for i = 1, 3 do
            local b = CreateFrame("Button", nil, list)
            b:SetSize(RW, 16)
            b:SetPoint("TOPLEFT", list, "TOPLEFT", RX, feedTop - (16) - (i - 1) * 17)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetSize(14, 14)
            b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
            if b.icon.SetTexCoord then b.icon:SetTexCoord(.07, .93, .07, .93) end
            b.text = Label(b, "", "GameFontHighlightSmall", 20, -1, RW - 20)
            if ONE.Fit then ONE.Fit:Line(b.text, b) end
            -- Eintrag mit eigener Oeffnen-Funktion (Termin, Ausflug) direkt dorthin, sonst Seite
            b:SetScript("OnClick", function(self) if self.open then self.open() elseif self.link then ONE.UI:OpenLink(self.link) end end)
            b.navi = FeedNavi(b, 46, 16)
            feedRows[i] = b
        end
    end
    local dayTitle = Label(list, "", "GameFontNormal", RX, -66 + D, RW)
    local daySub = Label(list, "", "GameFontHighlightSmall", RX, -84 + D - (0), RW)
    local dayEntries = {}
    local TIMEW = 64
    local dayList = ONE.Kit:List(list, {x = RX, y = -102 + D - (0), width = RW, height = 124, rowHeight = 30,
        columns = {
            {key = "time", title = "ZEIT", width = TIMEW},
            {key = "title", title = "EINTRAG", width = RW - 24 - 6 - TIMEW - 12, indent = 20},
        },
        render = function(row, entry, c)
            if not row.icon then
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(16, 16)
                row.icon:SetPoint("LEFT", row, "LEFT", TIMEW + 6, 0)
                if row.icon.SetTexCoord then row.icon:SetTexCoord(.07, .93, .07, .93) end
            end
            row.icon:SetTexture(EntryIcon(entry))
            -- lange Namen duerfen auf zwei Zeilen umbrechen
            if c.title.SetWordWrap then c.title:SetWordWrap(true) end
            if c.title.SetMaxLines then c.title:SetMaxLines(2) end
            c.time:SetText(T(EntryTime(entry)))
            c.time:SetTextColor(.8, .8, .8)
            c.title:SetText(entry.title)
            local col = TypeColor(entry)
            c.title:SetTextColor(col[1], col[2], col[3])
        end,
        onClick = function(_, entry) OpenEvent(entry) end,
        onEnter = function(row, entry)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.title)
            GameTooltip:AddLine(T(TYPE_NAME[entry.calendarType] or "Termin"), .8, .8, .8)
            if entry.trip then
                GameTooltip:AddLine(entry.description or "", 1, 1, 1, true)
                GameTooltip:AddLine(T("Klicken: Ausflug öffnen (anmelden, Reisevorbereitung)"), .8, .8, .8)
            else
                GameTooltip:AddLine(T("Klicken für die Beschreibung"), .8, .8, .8)
            end
            GameTooltip:Show()
        end,
    })
    local empty=ONE.Widgets:EmptyState(list,
        {x=RX,y=-124+D,width=RW,height=100,parentWidth=W,parentHeight=ONE.Geometry.tokens.contentHeight},
        T("Kein Eintrag"),
        T("An diesem Tag steht nichts im Kalender."))
    Label(list, T("Demnächst"), "GameFontNormalSmall", RX, -196, RW)
    local upcoming = {}
    for i = 1, 4 do upcoming[i] = Label(list, "", "GameFontHighlightSmall", RX, (-196) - i * 16, RW) end
    for _, line in ipairs(upcoming) do if ONE.Fit then ONE.Fit:Line(line) end end

    -- Eigene Aktionszeile unter der Karte: Status und Schaltflaeche
    -- duerfen nicht uebereinander liegen. Die rechte Kante folgt dem Raster.
    local inset=ONE.Geometry.tokens.panelStrokeInset
    local refreshRegion={x=inset,y=-353,width=W-2*inset}
    local FOOT = -366
    -- Filter = Legende: Haekchen mit Farbe je Art
    local filterDefs = {
        {key = "holiday", label = "WoW-Events", color = TYPE_COLOR.HOLIDAY},
        {key = "guild", label = "Gilde", color = TYPE_COLOR.GUILD_EVENT},
        {key = "own", label = "Eigene", color = TYPE_COLOR.PLAYER},
        {key = "reset", label = "Resets", color = TYPE_COLOR.RAID_RESET},
    }
    local filterChecks = {}
    for i, f in ipairs(filterDefs) do
        -- feste Abstaende je Beschriftung, damit "WoW-Events" nicht ins naechste Haekchen laeuft
        local FX = {0, 124, 210, 300}
        local fx = refreshRegion.x + FX[i]
        local fy = FOOT
        local box = ONE.Kit:Check(list, {point = "TOPLEFT", x = fx, y = fy, label = f.label,
            get = function() return Filters()[f.key] ~= false end,
            set = function(on) Filters()[f.key] = on and true or false end,
            onChange = function() refreshView() end})
        if box.label and box.label.SetTextColor then box.label:SetTextColor(f.color[1], f.color[2], f.color[3]) end
        filterChecks[#filterChecks + 1] = box
    end
    -- Termine entstehen nur im Addon (Nutzer-Wunsch 15.11.2026): "Termin erstellen" oeffnet
    -- das Formular fuer einen Gildenausflug (eigenes Ziel vorgewaehlt). Der WoW-Kalender
    -- wird nie geoeffnet.
    local FBW = 150
    local createButton = ONE.Widgets:Button(list, T("Termin erstellen"), FBW, 24, "TOPLEFT",
        (W - inset - 2 * FBW - 8), FOOT, function()
        local dm = ONE.modules and ONE.modules.dungeons
        if dm and dm.PlanTrip then dm:PlanTrip()
        else ONE:Print(T("Termine planst du mit dem Modul Dungeons (Optionen › Dungeons).")) end
    end)
    local refreshButton
    refreshButton = ONE.Widgets:Button(list, T("Jetzt aktualisieren"), FBW, 24, "TOPLEFT", W - inset - FBW, FOOT, function()
        guild.Calendar:RequestRefresh()
    end)
    -- Status (z. B. "6 WoW-Events in diesem Monat") nur noch im Tooltip
    if refreshButton and refreshButton.SetScript then
        refreshButton:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(guild.Calendar.status or T("Kalender wird geladen ..."))
            GameTooltip:Show()
        end)
        refreshButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end

    ONE.Widgets:ActionButton(detail,T("Zurück zur Übersicht"),{x=0,y=-3,width=W},function()
        showingDetails, selectedEvent = false, nil
        refreshView()
        ONE.UI:UpdateBackButton()
    end,"secondary","toolbar","left")
    local detailTitle = Label(detail, "", "GameFontNormalLarge", 0, -50, W)
    local detailDate = Label(detail, "", "GameFontHighlightSmall", 0, -81, W)
    Label(detail, T("Beschreibung"), "GameFontNormal", 0, -117, W)
    Card(detail,0,-141,W,211)

    -- Scrollbarer Beschreibungstext, damit auch lange Gildentermine passen.
    local scroll = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -162)
    scroll:SetSize(W-56, 175)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(W-80, 175)
    scroll:SetScrollChild(child)
    local description = Label(child, "", "GameFontHighlight", 0, 0, W-86)
    description:SetJustifyV("TOP")

    -- Antworten (15.11.2026): Zusagen / Vielleicht / Absagen direkt hier statt im WoW-Kalender
    -- Buch: oben auf der rechten Seite (nicht ueber die Falz); sonst unter der Beschreibung
    -- eigener Stand links neben den Antwort-Knoepfen
    -- (fehlte bis 0.7.0 ausserhalb des Buchs -> Lua-Fehler beim Oeffnen eines Termins)
    local answerLine = Label(detail, "", "GameFontHighlightSmall", 12, -369, W - 3 * 128 - 24)
        or Label(detail, "", "GameFontHighlight", 0, -368, W - 3 * 128 - 8)
    local answerButtons = {}
    local function Answer(kind)
        local event = selectedEvent
        if not event then return end
        guild.Calendar:Respond(event, kind, function(ok, msg)
            if not ok and msg then ONE:Print(msg) end
            refreshView()
        end)
    end
    for i, a in ipairs({{"yes", "Zusagen"}, {"maybe", "Vielleicht"}, {"no", "Absagen"}}) do
        local ax = (W - (4 - i) * 128)
        local ay = -364
        answerButtons[i] = ONE.Widgets:Button(detail, T(a[2]), 120, 24, "TOPLEFT", ax, ay,
            function() Answer(a[1]) end, a[1] == "yes" and "primary" or nil)
    end

    local function RefreshDetail()
        local event = selectedEvent
        if not event then
            detailTitle:SetText(T("Termin nicht mehr vorhanden"))
            detailDate:SetText(T("Bitte zur Übersicht zurückkehren."))
            description:SetText("")
        else
            local t = event.startTime
            detailTitle:SetText(event.title)
            if event.holiday then
                local e = event.endTime
                detailDate:SetText(string.format(T("WoW-Event · %02d.%02d.%04d, %02d:%02d Uhr"), t.monthDay, t.month, t.year, t.hour, t.minute)
                    .. (e and string.format(T(" bis %02d.%02d.%04d, %02d:%02d Uhr"), e.monthDay, e.month, e.year, e.hour, e.minute) or ""))
            else
                detailDate:SetText(string.format(T("%s · %02d.%02d.%04d um %02d:%02d Uhr"),
                    T(TYPE_NAME[event.calendarType] or "Termin"), t.monthDay, t.month, t.year, t.hour, t.minute))
            end
            local content
            if selectedError then
                content = selectedError
            elseif selectedDetails then
                local body = selectedDetails.description or ""
                content = body ~= "" and body or T("Für diesen Eintrag wurde keine Beschreibung hinterlegt.")
                if (selectedDetails.creator or "") ~= "" then
                    content = content .. "\n\n" .. T("Erstellt von: %s", selectedDetails.creator)
                end
            else
                content = T("Beschreibung wird geladen ...")
            end
            description:SetText(content)
        end
        local canAnswer = event and guild.Calendar.CanAnswer and guild.Calendar.CanAnswer(event)
        for _, b in ipairs(answerButtons) do if canAnswer then b:Show() else b:Hide() end end
        local status = canAnswer and guild.Calendar.StatusText(event)
        answerLine:SetText(canAnswer and (status and T("Dein Stand: %s", status) or T("Noch nicht geantwortet")) or "")
        local height = math.max(186, (description:GetStringHeight() or 0) + 10)
        child:SetHeight(height)
        scroll:SetVerticalScroll(0)
    end

    local function RefreshMonth()
        local now = Dates.Today(guild.Calendar)
        local distance = (view.year * 12 + view.month) - (now.year * 12 + now.month)
        if math.abs(distance) > 1 then
            view.year, view.month = now.year, now.month
            selected.year, selected.month, selected.day = now.year, now.month, now.day
        end
        monthLabel:SetText(T(Dates.months[view.month]) .. " " .. view.year)
        if distance <= -1 then prev:Hide() else prev:Show() end
        if distance >= 1 then nextButton:Hide() else nextButton:Show() end
        local weeks = Dates.MonthGrid(view.year, view.month)
        for w, week in ipairs(weeks) do
            kwLabels[w]:SetText(tostring(week.kw))
            for i, d in ipairs(week.days) do
                local cell = cells[w][i]
                cell.date = d
                local isToday = d.year == now.year and d.month == now.month and d.day == now.day
                local isSelected = d.year == selected.year and d.month == selected.month and d.day == selected.day
                cell.num:SetText(tostring(d.day))
                if isToday then cell.num:SetTextColor(1, .82, 0)
                elseif d.inMonth then cell.num:SetTextColor(1, 1, 1)
                else cell.num:SetTextColor(.45, .45, .45) end
                local shade = d.inMonth and (i >= 6 and .07 or .045) or .015
                Paint(cell.bg, 1, 1, 1, shade)
                if isSelected then cell.mark:Show() else cell.mark:Hide() end
                if isToday then cell.todayLine:Show() else cell.todayLine:Hide() end
                local entries = GetDay(d.year, d.month, d.day)
                -- Symbole: Gildentermine, eigene, Resets und Beginn/Ende von WoW-Events;
                -- an Tagen dazwischen nur der Streifen
                local shown, running = {}, false
                for _, e in ipairs(entries) do
                    if e.holiday then running = true end
                    if not e.holiday or e.sequenceType ~= "ONGOING" then
                        if e.holiday then table.insert(shown, e) else table.insert(shown, 1, e) end
                    end
                end
                local dim = d.inMonth and 1 or .45
                for l, icon in ipairs(cell.icons) do
                    local e = shown[l]
                    if e then
                        icon:SetTexture(EntryIcon(e))
                        if icon.SetVertexColor then icon:SetVertexColor(dim, dim, dim) end
                        icon:Show()
                    else
                        icon:Hide()
                    end
                end
                cell.more:SetText(#shown > 3 and ("+" .. (#shown - 3)) or "")
                if running then
                    local c = TYPE_COLOR.HOLIDAY
                    cell.span:SetColorTexture(c[1], c[2], c[3], d.inMonth and .8 or .35)
                    cell.span:Show()
                else
                    cell.span:Hide()
                end
            end
        end

        -- Tagesansicht
        local sy, sm, sd = selected.year, selected.month, selected.day
        local wd = Dates.Weekday(sy, sm, sd)
        dayTitle:SetText(string.format("%s, %d. %s", T(Dates.weekdaysLong[wd]), sd, T(Dates.months[sm])))
        local isToday = sy == now.year and sm == now.month and sd == now.day
        daySub:SetText(isToday and T("KW %d · heute", Dates.IsoWeek(sy, sm, sd)) or T("KW %d", Dates.IsoWeek(sy, sm, sd)))
        dayEntries = GetDay(sy, sm, sd)
        dayList:SetItems(dayEntries)
        if #dayEntries == 0 then empty:Show() else empty:Hide() end

        -- Demnaechst: Gildentermine (14 Tage) und Beginn/Ende von WoW-Events (7 Tage)
        local items = {}
        if Filters().guild ~= false or Filters().own ~= false then
            for _, e in ipairs(guild.Calendar.events or {}) do
                local t = e.startTime
                local ewd = (t.year and Dates.Weekday(t.year, t.month, t.monthDay)) or nil
                items[#items + 1] = {sort = Dates.DayNumber(t.year or now.year, t.month, t.monthDay) * 10000 + (t.hour or 0) * 100 + (t.minute or 0),
                    text = string.format("%s %02d.%02d. %02d:%02d  %s", ewd and T(Dates.weekdaysShort[ewd]) or "",
                        t.monthDay, t.month, t.hour or 0, t.minute or 0, e.title)}
            end
        end
        if Filters().guild ~= false then
            for _, e in ipairs(UI.TripEntries()) do
                local t = e.startTime
                local ewd = Dates.Weekday(t.year, t.month, t.monthDay)
                items[#items + 1] = {sort = Dates.DayNumber(t.year, t.month, t.monthDay) * 10000 + t.hour * 100 + t.minute,
                    text = string.format("%s %02d.%02d. %02d:%02d  |cff73f273%s|r", T(Dates.weekdaysShort[ewd]),
                        t.monthDay, t.month, t.hour, t.minute, e.title)}
            end
        end
        if Filters().holiday ~= false then
            local base = Dates.DayNumber(now.year, now.month, now.day)
            for offset = 0, 7 do
                local y, m, dd = now.year, now.month, now.day + offset
                while dd > Dates.DaysInMonth(y, m) do dd = dd - Dates.DaysInMonth(y, m); y, m = Dates.Shift(y, m, 1) end
                for _, e in ipairs(GetDay(y, m, dd, true)) do
                    local word = e.holiday and ((e.sequenceType == "START" and offset > 0 and "beginnt")
                        or (e.sequenceType == "END" and "endet"))
                    if word then
                        local when = offset == 0 and T("heute") or offset == 1 and T("morgen")
                            or T(Dates.weekdaysShort[Dates.Weekday(y, m, dd)])
                        items[#items + 1] = {sort = (base + offset) * 10000 + 1,
                            text = "|cffff9e33" .. (word == "beginnt" and T("%s beginnt %s", e.title, when)
                                or T("%s endet %s", e.title, when)) .. "|r"}
                    end
                end
            end
        end
        table.sort(items, function(a, b) return a.sort < b.sort end)
        for i, line in ipairs(upcoming) do
            local it = items[i]
            if it then
                line:SetText(it.text)
            elseif i == 1 then
                line:SetText(T("Keine Gildentermine in den nächsten 14 Tagen."))
            else
                line:SetText("")
            end
        end
        for _, box in ipairs(filterChecks) do if box.Refresh then box:Refresh() end end
        if #feedRows > 0 then
            local feed = ONE.UI.FeedItems and ONE.UI:FeedItems() or {}
            for i, row in ipairs(feedRows) do
                local it = feed[i]
                if it then
                    row.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                    row.icon:Show()
                    row.text:SetText(it.text)
                    row.link, row.open = it.link, it.open
                    SetFeedNavi(row, it, RW - 20)
                elseif i == 1 then
                    row.icon:Hide()
                    row.text:SetText(T("Gerade steht nichts an."))
                    row.link, row.open = nil, nil
                    SetFeedNavi(row, nil, RW - 20)
                else
                    row.icon:Hide() row.text:SetText("") row.link, row.open = nil, nil
                    SetFeedNavi(row, nil, RW - 20)
                end
            end
        end
    end

    refreshView = function()
        if showingDetails then
            list:Hide()
            detail:Show()
            RefreshDetail()
            return
        end
        detail:Hide()
        list:Show()
        RefreshMonth()
    end
    ONE.UI:RegisterBackHandler("calendar", function()
        return showingDetails
    end, function()
        showingDetails, selectedEvent = false, nil
        refreshView()
    end)
    return refreshView
end

-- Klassensymbol aus Blizzards Klassen-Atlas (falls vorhanden)
local CLASS_ATLAS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local function SetClassIcon(tex, class)
    local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if c then
        tex:SetTexture(CLASS_ATLAS)
        if tex.SetTexCoord then tex:SetTexCoord(c[1], c[2], c[3], c[4]) end
        tex:Show()
    else
        tex:Hide()
    end
end
UI.SetClassIcon = SetClassIcon

local function GuildMotd()
    if type(GetGuildRosterMOTD) ~= "function" then return "" end
    local ok, text = pcall(GetGuildRosterMOTD)
    return ok and type(text) == "string" and text or ""
end

-- Gildenuebersicht: Kopf mit Zahlen und Nachricht des Tages, links wer online
-- ist (Klasse, Stufe, Gebiet, Navi-Pfeil), rechts was in der Gilde los ist.
function UI:BuildGuild(panel)
    local W=ONE.UI.Layout.width
    local H=ONE.Geometry.tokens.contentHeight
    local title=Label(panel,"","GameFontNormalLarge",0,-4,W)
    local facts=Label(panel,"","GameFontHighlight",0,-30,W)
    local motd=Label(panel,"","GameFontHighlightSmall",0,-50,W)
    if ONE.Fit then ONE.Fit:Line(motd) end

    local LW=446
    local RX,RW=LW+12,W-LW-12
    local NAMEW=150
    -- 0.6.8 Symbolleiste: Gildenname + Zahlen stehen in der Kopfzeile, Seite rueckt hoch,
    -- die Karten bekommen die frei gewordene Hoehe
    local lift=0
    local sidebar=ONE.UI.LiftPage and ONE.UI:LiftPage(panel,46)
    if sidebar then
        lift=46
        ONE.UI:RetireButtons(title,facts)
        ONE.UI:SetViews("guild",{{key="guild",label="Übersicht"},{key="guild-members",label="Mitglieder"}},"guild")
        for _,it in ipairs(ONE.UI.viewSets.guild.items) do
            it.onClick=function(key)
                if key=="guild-members" and guild.Roster then guild.Roster:Request() end
                ONE.UI:Navigate(key)
            end
        end
    end
    local cardY,cardH=-72,H-72-40+lift
    -- Links: Jetzt online
    local left=Card(panel,0,cardY,LW,cardH)
    local onlineTitle=CardHeader(left,"","GameFontNormal",LW)
    local listOpts={x=10,y=-44,width=LW-20,height=cardH-54,rowHeight=24,
        columns={
            {key="name",title="NAME",width=NAMEW,indent=22},
            {key="level",title="STUFE",width=38,align="CENTER"},
            {key="zone",title="GEBIET",width=LW-20-24-NAMEW-38-44-24},
            {key="live",title="NAVI",width=44,align="CENTER"},
        },
        render=function(row,m,cells)
            if not row.classIcon then
                row.classIcon=row:CreateTexture(nil,"ARTWORK")
                row.classIcon:SetSize(18,18)
                row.classIcon:SetPoint("LEFT",row,"LEFT",4,0)
            end
            -- Buch: rechte Seite hat nur Gebiet/Navi, dort kein Klassensymbol
            if cells.name then SetClassIcon(row.classIcon,m.class) row.classIcon:Show() else row.classIcon:Hide() end
            if cells.name then
                cells.name:SetText(m.name:match("^[^-]+") or m.name)
                local r,g,b=UI.ClassColor(m.class)
                cells.name:SetTextColor(r,g,b)
            end
            if cells.level then cells.level:SetText(m.level>0 and m.level or "") end
            if cells.zone then
                cells.zone:SetText(m.zone~="" and m.zone or "–")
                cells.zone:SetTextColor(.85,.85,.85)
            end
            if cells.live then
                -- kleiner Navi-Pfeil (Klick nur auf den Pfeil startet das Navi)
                local live=guild.Pins and guild.Pins:GetPeer(m.name)
                cells.live:SetText("")
                if not row.navi then
                    row.navi=ONE.Widgets:NaviArrow(row,16,"CENTER",0,0,function(self)
                        local navi=ONE.modules and ONE.modules.nav
                        if self.member and navi and navi.StartTo then navi:StartTo(self.member) ONE.UI:Refresh() end
                    end,function(self) return T("Navi zu %s",(self.member or ""):match("^[^-]+") or "") end)
                    if row.navi.ClearAllPoints then row.navi:ClearAllPoints() end
                    row.navi:SetPoint("CENTER",cells.live,"CENTER",0,0)
                end
                row.navi.member=m.name
                if live then row.navi:Show() else row.navi:Hide() end
            end
        end,
        -- Klick (links oder rechts) auf ein Mitglied: Namens-Menue (Navi, Fluestern, Einladen …)
        onClick=function(row,m)
            if ONE.PlayerMenu then ONE.PlayerMenu:Open(row,m.name,{online=m.online~=false}) end
        end,
        onEnter=function(row,m)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
            GameTooltip:SetText(m.name:match("^[^-]+") or m.name)
            GameTooltip:AddLine(m.level.." "..m.classLabel.." · "..m.rank,1,1,1)
            if guild.Pins and guild.Pins:GetPeer(m.name) then
                GameTooltip:AddLine(T("Pfeil: Navi zu diesem Mitglied"),.4,1,.6)
            end
            GameTooltip:AddLine(T("Klick: Navi, Flüstern, Einladen …"),.8,.8,.8)
            GameTooltip:Show()
        end,
    }
    -- Buch: wie ein Kassenbuch ueber beide Seiten – links Name und Stufe, rechts auf
    -- gleicher Hoehe Gebiet und Navi; beide Listen scrollen gemeinsam
    local list2
    local list=ONE.Kit:List(left,listOpts)
    local noneOnline=Label(left,"","GameFontHighlightSmall",22,-76,LW-44)

    -- Rechts: Was steht an (im Buch auf der Kalenderseite)
    local right=Card(panel,RX,cardY,RW,cardH)
    CardHeader(right,T("IN DER GILDE LOS"),"GameFontNormal",RW)
    local feedRows={}
    for i=1,7 do
        local b=CreateFrame("Button",nil,right)
        b:SetSize(RW-32,36)
        b:SetPoint("TOPLEFT",right,"TOPLEFT",16,-48-(i-1)*38)
        b.icon=b:CreateTexture(nil,"ARTWORK")
        b.icon:SetSize(24,24)
        b.icon:SetPoint("LEFT",b,"LEFT",0,0)
        if b.icon.SetTexCoord then b.icon:SetTexCoord(.07,.93,.07,.93) end
        b.text=Label(b,"","GameFontHighlightSmall",30,-2,RW-32-30)
        if b.text.SetMaxLines then b.text:SetMaxLines(2) end
        if b.SetHighlightTexture then pcall(b.SetHighlightTexture,b,"Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD") end
        b:SetScript("OnClick",function(self) if self.open then self.open() elseif self.link then ONE.UI:OpenLink(self.link) end end)
        b.navi=FeedNavi(b,56,22)
        feedRows[i]=b
    end
    local quiet=Label(right,T("Gerade steht nichts an. Gildentermine, Gruppengesuche und fällige Lehrerbesuche erscheinen hier."),
        "GameFontHighlightSmall",16,-50,RW-32)

    -- Unten: schmale Knopfleiste und Haekchen fuer die Position
    local by=-(H-30)-lift
    ONE.Widgets:Button(panel,T("Weltkarte"),130,24,"TOPLEFT",0,by,function()
        if guild.Pins then guild.Pins:OpenMap() end
    end)
    local allMembers=ONE.Widgets:Button(panel,T("Alle Mitglieder"),140,24,"TOPLEFT",136,by,function()
        if guild.Roster then guild.Roster:Request() end
        ONE.UI:Navigate("guild-members")
    end)
    -- mit Symbolleiste ist "Mitglieder" eine Ansicht oben; Gildenfenster rueckt nach
    if sidebar then ONE.UI:RetireButtons(allMembers) end
    ONE.Widgets:Button(panel,T("Gildenfenster"),140,24,"TOPLEFT",(sidebar and 136 or 282),by,function()
        if guild.Roster then guild.Roster:OpenNativeGuildUI() end
    end)
    -- "Meine Position teilen" steht in Optionen › Teilen

    return function()
        local info = guild.Guild:GetInfo()
        local online = guild.Roster and guild.Roster:OnlineCount() or 0
        local live = guild.Presence and #guild.Presence:ActivePeers() or 0
        title:SetText(info.name ~= "" and info.name or T("Keine Gilde"))
        local parts = {}
        if info.rank ~= "" then parts[#parts+1] = info.rank end
        parts[#parts+1] = T("%s Mitglieder", tostring(info.members or "–"))
        parts[#parts+1] = T("%d online", online)
        if live > 0 then parts[#parts+1] = T("%d teilen Position", live) end
        facts:SetText(table.concat(parts, "  ·  "))
        if sidebar then ONE.UI:SetContext("guild", (info.name ~= "" and (info.name .. "  ·  ") or "") .. table.concat(parts, "  ·  ")) end
        local m = GuildMotd()
        motd:SetText(m ~= "" and ("„" .. m .. "“") or "")
        -- Online-Liste: wer Position teilt zuerst, dann nach Name
        local items = {}
        for _, member in ipairs(guild.Roster and guild.Roster:Members() or {}) do
            if member.online then items[#items+1] = member end
        end
        local function Live(x) return guild.Pins and guild.Pins:GetPeer(x.name) and 1 or 0 end
        table.sort(items, function(a, b)
            local la, lb = Live(a), Live(b)
            if la ~= lb then return la > lb end
            return string.lower(a.name) < string.lower(b.name)
        end)
        onlineTitle:SetText(T("JETZT ONLINE (%d)", #items))
        if list2 then
            list:SetItems(items)
            list2:SetItems(items)
        else
            list:SetItems(items)
        end
        noneOnline:SetText(#items == 0 and T("Gerade ist niemand aus der Gilde online.") or "")
        -- Neuigkeiten
        local feed = ONE.UI.FeedItems and ONE.UI:FeedItems() or {}
        for i, row in ipairs(feedRows) do
            local it = feed[i]
            if it then
                row.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.text:SetText(it.text)
                row.link, row.open = it.link, it.open
                SetFeedNavi(row, it, RW - 32 - 30)
                row:Show()
            else
                SetFeedNavi(row, nil, RW - 32 - 30)
                row:Hide()
            end
        end
        if #feed == 0 then quiet:Show() else quiet:Hide() end
    end
end

-- Eigene Unterseite statt einer weiteren Registerkarte: uebersichtliche Zentrale.

-- Komplettes Gildenverzeichnis: echte Serverdaten, keine Demo-Zeilen.
function UI.ClassColor(class)
    if C_ClassColor and type(C_ClassColor.GetClassColor)=="function" and class and class~="" then
        local ok,color=pcall(C_ClassColor.GetClassColor,class)
        if ok and color and color.GetRGB then return color:GetRGB() end
    end
    local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r,c.g,c.b end
    return 1,1,1
end

-- Mitgliederverzeichnis: Tabelle mit Spalten, Suche, "nur online", Sortierung
-- per Klick auf die Spaltenkoepfe und Scrollleiste statt Blaettern.
function UI:BuildGuildMembers(panel)
    local W=ONE.UI.Layout.width
    local title=Label(panel,T("Gildenmitglieder"),"GameFontNormalLarge",0,-4,W)
    local summary=Label(panel,"","GameFontHighlightSmall",0,-30,W)
    -- 0.6.8 Symbolleiste: Titel/Zahlen in der Kopfzeile, Seite rueckt hoch, Liste wird laenger
    local lift=0
    if ONE.UI.LiftPage and ONE.UI:LiftPage(panel,46) then lift=46 ONE.UI:RetireButtons(title,summary) end
    -- Werkzeugleiste: Suche, Filter, Blizzard-Verwaltung
    local okSearch,search=pcall(CreateFrame,"EditBox",nil,panel,"SearchBoxTemplate")
    if not okSearch or not search then
        search=CreateFrame("EditBox",nil,panel)
        if search.SetFontObject and GameFontHighlight then search:SetFontObject(GameFontHighlight) end
    end
    search:SetSize(220,22)
    search:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-54)
    search:SetAutoFocus(false)
    local onlineOnly=false
    local okCheck,check=pcall(CreateFrame,"CheckButton",nil,panel,"UICheckButtonTemplate")
    if not okCheck or not check then check=CreateFrame("CheckButton",nil,panel) end
    check:SetSize(24,24)
    check:SetPoint("TOPLEFT",panel,"TOPLEFT",240,-53)
    local checkLabel=Label(panel,T("Nur online"),"GameFontHighlight",268,-58,110)
    ONE.Widgets:Button(panel,"Blizzard-Gildenverwaltung",210,24,"TOPRIGHT",0,-53,function()
        if guild.Roster then guild.Roster:OpenNativeGuildUI() end
    end)
    local sortKey,ascending="name",true
    local list
    list=ONE.Kit:List(panel,{x=0,y=-88,width=W,height=437-88-4+lift,rowHeight=22,
        columns={
            {key="name",title="NAME",width=186,indent=16},
            {key="level",title="STUFE",width=44,align="CENTER"},
            {key="class",title="KLASSE",width=104},
            {key="rank",title="RANG",width=112},
            {key="zone",title="GEBIET",width=W-24-6-186-44-104-112-40},
        },
        render=function(row,m,cells)
            if not row.dot then
                row.dot=row:CreateTexture(nil,"ARTWORK")
                row.dot:SetSize(10,10)
                row.dot:SetPoint("LEFT",row,"LEFT",6,0)
            end
            local ok=pcall(row.dot.SetTexture,row.dot,m.online and "Interface\\FriendsFrame\\StatusIcon-Online"
                or "Interface\\FriendsFrame\\StatusIcon-Offline")
            if not ok then row.dot:SetColorTexture(m.online and .3 or .4,m.online and .9 or .4,m.online and .4 or .4,1) end
            cells.name:SetText(m.name:match("^[^-]+") or m.name)
            cells.level:SetText(m.level>0 and m.level or "")
            cells.class:SetText(m.classLabel)
            cells.rank:SetText(m.rank)
            cells.zone:SetText(m.online and (m.zone~="" and m.zone or "–") or "offline")
            local r,g,b=UI.ClassColor(m.class)
            local dim=m.online and 1 or .55
            cells.name:SetTextColor(r*dim,g*dim,b*dim)
            for _,key in ipairs({"level","class","rank","zone"}) do
                local c=m.online and .95 or .55
                cells[key]:SetTextColor(c,c,c)
            end
        end,
        onSort=function(key,asc) sortKey,ascending=key,asc ONE.UI:Refresh() end,
        onEnter=function(row,m)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
            GameTooltip:SetText(m.name:match("^[^-]+") or m.name)
            GameTooltip:AddLine(m.level.." "..m.classLabel.." · "..m.rank,1,1,1)
            GameTooltip:AddLine(m.online and T("Online · %s", m.zone~="" and m.zone or T("Ort unbekannt")) or T("Offline"),.8,.8,.8)
            local peer=guild.Pins and guild.Pins:GetPeer(m.name)
            if peer then GameTooltip:AddLine(T("Guild Trip: Live-Position geteilt"),.4,1,.6) end
            GameTooltip:AddLine(T("Klick: Navi, Flüstern, Einladen …"),.8,.8,.8)
            GameTooltip:Show()
        end,
        onClick=function(row,m)
            if ONE.PlayerMenu then ONE.PlayerMenu:Open(row,m.name,{online=m.online}) end
        end,
    })
    local function Changed() ONE.UI:Refresh() end
    if search.HookScript then search:HookScript("OnTextChanged",Changed) end
    check:SetScript("OnClick",function(self)
        onlineOnly=self.GetChecked and self:GetChecked() and true or false
        Changed()
    end)
    local function Value(m,key)
        if key=="level" then return m.level or 0 end
        return string.lower(tostring(m[key=="class" and "classLabel" or key] or ""))
    end
    return function()
        local all=guild.Roster:Members()
        local query=string.lower(search.GetText and search:GetText() or "")
        local items,online={},0
        for _,m in ipairs(all) do
            if m.online then online=online+1 end
            local hay=string.lower(m.name.." "..m.zone.." "..m.classLabel.." "..m.rank)
            if (not onlineOnly or m.online) and (query=="" or hay:find(query,1,true)) then
                items[#items+1]=m
            end
        end
        table.sort(items,function(a,b)
            if sortKey=="name" and a.online~=b.online then return a.online end
            local va,vb=Value(a,sortKey),Value(b,sortKey)
            if va==vb then return string.lower(a.name)<string.lower(b.name) end
            if ascending then return va<vb else return va>vb end
        end)
        list:SetItems(items)
        summary:SetText((query~="" or onlineOnly) and T("%d Mitglieder · %d online · %d angezeigt", #all, online, #items)
            or T("%d Mitglieder · %d online", #all, online))
        if lift>0 then ONE.UI:SetContext("guild-members", summary:GetText()) end
    end
end

-- Erinnerungszeiten: Baustein in Optionen › Erinnerungen (0.6.9, frueher eigene Unterseite)
function UI:BuildReminderSettings(panel, W)
    W = W or 520
    -- schmal (Buch-Aussehen, 286 breit): Schnellauswahl und "Standard" je in eigener Zeile
    local narrow = W < 420
    local d1 = narrow and -24 or 0
    local d2 = d1 + (narrow and -30 or 0)
    Label(panel, T("Wähle bis zu acht Zeitpunkte (0 = Terminbeginn, maximal 1440 Minuten)."), "GameFontHighlightSmall", 4, -2, W - 8)
    local feedback = Label(panel, "", "GameFontHighlightSmall", 4, narrow and (-124 + d2 - 8 * 30 - 26) or -298, W - 8)
    local refreshView
    local function AddValue(value)
        local success, err = guild.Reminders:AddThreshold(value)
        feedback:SetText(success and T("Erinnerung bei %d Minuten hinzugefügt.", value) or T(err or T("Ungültige Eingabe.")))
        refreshView()
        return success
    end

    Label(panel, T("Schnellauswahl:"), "GameFontHighlight", 4, -30, 110)
    local quickCols = narrow and ONE.Geometry:Columns(W, {1, 1, 1, 1, 1}, 4, 0) or ONE.Geometry:Columns(W - 116, {1, 1, 1, 1, 1}, 6, 116)
    for i, minutes in ipairs({60, 30, 15, 5, 0}) do
        Button(panel, tostring(minutes) .. (narrow and "" or " Min."), quickCols[i].width, quickCols[i].x, -24 + d1 + (narrow and -22 or 0), function()
            AddValue(minutes)
        end)
    end

    Label(panel, T("Eigene Minuten:"), "GameFontHighlight", 4, -66 + d1, 110)
    local entry = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    entry:SetSize(70, 26)
    entry:SetPoint("TOPLEFT", 122, -60 + d1)
    entry:SetAutoFocus(false)
    entry:SetNumeric(true)
    entry:SetMaxLetters(4)
    local function ApplyEntry()
        local raw = entry:GetText() or ""
        local number = tonumber(raw)
        if raw == "" or not number then
            feedback:SetText(T("Bitte eine Minutenanzahl eingeben."))
            return
        end
        if AddValue(number) then
            entry:SetText("")
            entry:ClearFocus()
        end
    end
    entry:SetScript("OnEnterPressed", ApplyEntry)
    entry:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    Button(panel, T("Hinzufügen"), narrow and W - 200 or 110, 200, -59 + d1, ApplyEntry)
    Button(panel, T("Standard wiederherstellen"), narrow and W or math.max(150, W - 318), narrow and 0 or 316, narrow and -89 + d1 or -59, function()
        guild.Reminders:ResetThresholds()
        feedback:SetText(T("Standardzeiten (60, 15, 5, 0) wiederhergestellt."))
        refreshView()
    end)

    Label(panel, T("Aktive Erinnerungen (anklicken zum Entfernen):"), "GameFontHighlight", 4, -102 + d2, W - 8)
    local rows = {}
    local thresholdCols = narrow and {{x = 0, width = W}, {x = 0, width = W}} or ONE.Geometry:Columns(W, {1, 1}, 10)
    for i = 1, 8 do
        local col = thresholdCols[(i - 1) % 2 + 1]
        rows[i] = Button(panel, "", col.width, col.x, -124 + d2 - (narrow and (i - 1) * 30 or math.floor((i - 1) / 2) * 36), function()
            local active = guild.Reminders:GetThresholds()
            local value = active[i]
            if value ~= nil then
                guild.Reminders:RemoveThreshold(value)
                feedback:SetText(T("Erinnerung bei %d Minuten entfernt.", value))
                refreshView()
            end
        end)
    end
    local summary = Label(panel, "", "GameFontHighlightSmall", 4, narrow and -124 + d2 - 8 * 30 - 4 or -276, W - 8)
    refreshView = function()
        local values = guild.Reminders:GetThresholds()
        for i, button in ipairs(rows) do
            local value = values[i]
            if value ~= nil then
                local display = value == 0 and T("Zum Terminbeginn") or T("%d Minuten vorher", value)
                button:SetText(display .. "   |   " .. T("Entfernen"))
                button:Show()
            else
                button:Hide()
            end
        end
        summary:SetText(#values == 0 and T("Keine Zeiten ausgewählt: Es werden keine Kalendererinnerungen gesendet.")
            or T("Aktiv: %d von 8 möglichen Erinnerungszeiten.", #values))
    end
    return refreshView, narrow and (124 - d2 + 8 * 30 + 50) or 318
end

-- Kachel fuer die ONE-Startseite: Gildenname, wer online ist, wer live teilt.
local function GuildTile(card, body)
    local name = body:Text("", "body", "text")
    local status = body:Text("", "small", "soft")
    body:Action(T("Gildenübersicht"), function()
        if not ONE.UI:OpenLink("guild") then ONE:Print(T("Das Gildenmodul ist nicht installiert.")) end
    end)
    return function()
        if IsInGuild and IsInGuild() then
            local guildName = (GetGuildInfo and GetGuildInfo("player")) or nil
            name:SetText(guildName or T("Gildeninformationen werden geladen ..."))
            local online = guild.Roster and guild.Roster:OnlineCount() or 0
            local live = guild.Presence and #guild.Presence:ActivePeers() or 0
            status:SetText(T("%d online · %d mit Live-Position", online, live))
        else
            name:SetText(T("Noch keine Gilde"))
            status:SetText(T("Hier erscheinen deine Gildendaten."))
        end
    end
end

function UI:RegisterTabs()
    if ONE.UI and ONE.UI.AddFeed then
        ONE.UI:AddFeed("calendar", function()
            local now = guild.Calendar:GetCurrentTime()
            if not now then return {} end
            local today = Dates.DayNumber(now.year, now.month, now.monthDay)
            local out = {}
            for _, e in ipairs(guild.Calendar.events or {}) do
                local t = e.startTime or {}
                local day = t.month and Dates.DayNumber(t.year or now.year, t.month, t.monthDay) or nil
                if day and day >= today and day - today <= 7 then
                    local when = day == today and T("heute") or day == today + 1 and T("morgen")
                        or T(Dates.weekdaysShort[Dates.Weekday(t.year or now.year, t.month, t.monthDay)])
                    out[#out + 1] = {icon = e.icon or "Interface\\Icons\\INV_Misc_PocketWatch_01", link = "calendar",
                        open = function()
                            ONE.UI:OpenLink("calendar")
                            if UI.OpenCalendarEvent then UI.OpenCalendarEvent(e) end
                        end,
                        sort = 10 + (day - today) / 10, text = string.format("%s %02d:%02d  %s", when, t.hour or 0, t.minute or 0, e.title or "")}
                end
            end
            -- Gildenausfluege der naechsten 7 Tage, mit Navi zum Treffpunkt
            for _, e in ipairs(UI.TripEntries()) do
                local t, trip = e.startTime, e.tripData
                local day = Dates.DayNumber(t.year, t.month, t.monthDay)
                if day >= today and day - today <= 7 then
                    local when = day == today and T("heute") or day == today + 1 and T("morgen")
                        or T(Dates.weekdaysShort[Dates.Weekday(t.year, t.month, t.monthDay)])
                    local item = {icon = TYPE_ICON.GUILDTRIP, link = "trips", open = function() OpenTrip(e) end, sort = 10 + (day - today) / 10,
                        text = string.format("%s %02d:%02d  %s", when, t.hour, t.minute, e.title)}
                    local nav = ONE.modules and ONE.modules.nav
                    if trip.mapID and nav and nav.PointTo then
                        item.navi = function() nav:PointTo(T("Treffpunkt"), trip.mapID, trip.x, trip.y) end
                        item.naviTip = T("Navi zum Treffpunkt: %s", trip.meet or "")
                    end
                    out[#out + 1] = item
                end
            end
            return out
        end)
    end
    if ONE.UI and ONE.UI.AddShareOption then
        ONE.UI:AddShareOption({id = "position", module = "guild", order = 10, label = "Position mit Gilde teilen",
            tooltip = "Gildenmitglieder mit Guild Trip sehen dich live auf der Karte und können sich zu dir führen lassen. Kein Verlauf wird gespeichert.",
            get = function() return guild.Presence and guild.Presence:IsSharing() or false end,
            set = function(on) if guild.Presence then guild.Presence:SetSharing(on) end end})
    end
    if ONE.Kit and ONE.Kit.RegisterTile then
        ONE.Kit:RegisterTile("gilde", {title = "GILDE", order = 20, build = GuildTile})
    end
    ONE.UI:AddTab("guild", T("Gilde"), function(panel) return self:BuildGuild(panel) end)
    ONE.UI:AddTab("calendar", T("Kalender"), function(panel) return self:BuildCalendar(panel) end)
    ONE.UI:RegisterView("guild-members", function(panel) return self:BuildGuildMembers(panel) end)
    if ONE.UI.AddSetting then
        ONE.UI:AddSetting({id = "reminderTimes", category = "reminders", section = "Gildentermine", kind = "custom", order = 11,
            module = "guild", visible = function() return ONE.db.remindersEnabled and true or false end,
            build = function(row, w) return self:BuildReminderSettings(row, w) end})
    end
end
