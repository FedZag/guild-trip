-- Offline-Test 0.4.9f: Kalender als Monatsraster – Kalenderwochen, WoW-Events, Tagesansicht.
local root = arg[1] or "src"
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
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetVerticalScroll(v) self.scroll = v end
    function r:GetVerticalScroll() return self.scroll end
    function r:GetStringHeight() return 40 end
    function r:GetFrameLevel() return 2 end
    function r:CreateTexture() return Region("Texture", self) end
    function r:SetTexture(t) self.texture = t end
    function r:SetColorTexture(...) self.colorTexture = {...} end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")

-- ===== 1) Datumsrechnung =====
local ONE = {db = {}, modules = {}}
function ONE:IsEnabled() return true end
local refreshed = 0
ONE.UI = {Layout = {width = 726}, Refresh = function() refreshed = refreshed + 1 end,
    RegisterBackHandler = function() end, UpdateBackButton = function() end}
_G.ProjectONE = ONE
for _, f in ipairs({"Skin.lua", "Themes.lua", "Kit.lua", "Geometry.lua", "Widgets.lua"}) do
    assert(loadfile(root .. "/ONE_Core/" .. f))("ONE_Core", ONE)
end
ONE.Themes:Initialize()
local guild = {}
function guild:OnCalendarScanned() self.scanned = true end
assert(loadfile(root .. "/ONE_Guild/Calendar.lua"))("ONE_Guild", guild)
assert(loadfile(root .. "/ONE_Guild/UI.lua"))("ONE_Guild", guild)
local D = guild.UI.Dates
assert(D.Weekday(2026, 11, 12) == 4, "12.11.2026 ist ein Donnerstag")
assert(D.Weekday(2026, 11, 1) == 7, "1.11.2026 ist ein Sonntag")
assert(D.IsoWeek(2026, 11, 12) == 46, "KW 46")
local kw, wy = D.IsoWeek(2027, 1, 1)
assert(kw == 53 and wy == 2026, "1.1.2027 gehört zu KW 53/2026")
kw, wy = D.IsoWeek(2024, 12, 30)
assert(kw == 1 and wy == 2025, "30.12.2024 gehört zu KW 1/2025")
assert(D.DaysInMonth(2028, 2) == 29 and D.DaysInMonth(2100, 2) == 28)
local grid = D.MonthGrid(2026, 11)
assert(#grid == 6 and grid[1].kw == 44)
local first = grid[1].days[1]
assert(first.day == 26 and first.month == 10 and not first.inMonth, "Raster beginnt Mo 26.10.")
assert(grid[1].days[7].day == 1 and grid[1].days[7].inMonth)
assert(grid[6].days[7].day == 6 and grid[6].days[7].month == 12)
local feb = D.MonthGrid(2027, 2) -- 1.2.2027 ist ein Montag
assert(feb[1].days[1].day == 1 and feb[1].days[1].inMonth and feb[1].kw == 5)

-- ===== 2) Einlesen: WoW-Events landen in der Monatsansicht, nicht bei Erinnerungen =====
InCombatLockdown = function() return false end
C_Timer = {After = function(_, fn) fn() end, NewTicker = function() end}
C_DateAndTime = {GetCurrentCalendarTime = function()
    return {year = 2026, month = 11, monthDay = 12, weekday = 5, hour = 10, minute = 0} end}
local holidayCalls = 0
local function T(y, m, d, h, mi) return {year = y, month = m, monthDay = d, hour = h or 0, minute = mi or 0} end
local data = {} -- [offset][day] = {events}
local function Add(offset, day, e) data[offset] = data[offset] or {}; data[offset][day] = data[offset][day] or {}; table.insert(data[offset][day], e) end
for day = 9, 15 do
    Add(0, day, {title = "Dunkelmond-Jahrmarkt", calendarType = "HOLIDAY",
        sequenceType = day == 9 and "START" or (day == 15 and "END" or "ONGOING"),
        startTime = T(2026, 11, 9, 6), endTime = T(2026, 11, 15, 23, 59)})
end
Add(0, 13, {eventID = 7, title = "Gildenabend", calendarType = "GUILD_EVENT", startTime = T(2026, 11, 13, 19, 30)})
Add(0, 13, {title = "Systemmeldung", calendarType = "SYSTEM", startTime = T(2026, 11, 13, 0)})
Add(1, 24, {title = "Winterhauchfest", calendarType = "HOLIDAY", sequenceType = "START", startTime = T(2026, 12, 24, 6)})
Add(-1, 31, {title = "Schlotternächte", calendarType = "HOLIDAY", sequenceType = "END", startTime = T(2026, 10, 18, 6)})
C_Calendar = {
    GetMonthInfo = function(o) return {year = 2026, month = 11 + (o or 0)} end,
    GetNumDayEvents = function(o, d) return data[o] and data[o][d] and #data[o][d] or 0 end,
    GetDayEvent = function(o, d, i) return data[o][d][i] end,
    GetHolidayInfo = function(o, d, i)
        holidayCalls = holidayCalls + 1
        return {name = data[o][d][i].title, description = "Beschreibung " .. data[o][d][i].title}
    end,
}
local C = guild.Calendar
C.details = {}
C:Scan()
assert(guild.scanned)
assert(#C.events == 1 and C.events[1].title == "Gildenabend", "Erinnerungen nur für echte Termine")
local d13 = C:GetDay(2026, 11, 13)
assert(#d13 == 2 and d13[1].holiday and d13[1].title == "Dunkelmond-Jahrmarkt", "WoW-Event zuerst")
assert(d13[2].title == "Gildenabend" and d13[2].key == C.events[1].key, "Termin-Schlüssel passt zur Detailabfrage")
assert(d13[1].description == "Beschreibung Dunkelmond-Jahrmarkt")
assert(#C:GetDay(2026, 12, 24) == 1 and #C:GetDay(2026, 10, 31) == 1, "Vor- und Folgemonat eingelesen")
assert(#C:GetDay(2026, 11, 20) == 0)
assert(holidayCalls == 3, "Feiertagstext nur einmal je Event geladen: " .. holidayCalls)
assert(C.status:find("1 WoW%-Event"), C.status)

-- ===== 3) Ansicht =====
local panel = Region("Frame")
local refresh = guild.UI:BuildCalendar(panel)
refresh()
local function FindText(t) for _, r in ipairs(made) do if r.text == t then return r end end end
assert(FindText("November 2026"), "Monatsname fehlt")
assert(FindText("KW") and FindText("46") and FindText("44"), "Kalenderwochen fehlen")
assert(FindText("Donnerstag, 12. November"), "Tagesansicht zeigt heute")
assert(FindText("KW 46 · heute"))
local orange
for _, r in ipairs(made) do
    if r.kind == "FontString" and r.text == "Dunkelmond-Jahrmarkt" and r.color and r.color[1] == 1 and r.color[2] == .62 then orange = true end
end
assert(orange, "WoW-Event steht orange im Raster")
assert(FindText("Fr 13.11. 19:30  Gildenabend"), "Demnächst fehlt")
-- 0.6.1: Symbole statt Text, Streifen fuer laufende Events, Hinweise in "Demnaechst"
local function Cell(day)
    for _, r in ipairs(made) do
        if r.kind == "Button" and r.date and r.date.day == day and r.date.month == 11 then return r end
    end
end
local function ShownIcons(cell) local out = {} for _, ic in ipairs(cell.icons) do if ic.shown then out[#out + 1] = ic.texture end end return out end
local c9, c10, c13 = Cell(9), Cell(10), Cell(13)
assert(#ShownIcons(c9) == 1 and c9.span.shown, "Beginn des Jahrmarkts: Symbol und Streifen")
assert(#ShownIcons(c10) == 0 and c10.span.shown, "Tage dazwischen: nur Streifen")
local i13 = ShownIcons(c13)
assert(#i13 == 1 and i13[1]:find("GuildTabard", 1, true) and c13.span.shown, "Gildentermin mit Gilden-Symbol, Jahrmarkt nur als Streifen")
assert(not Cell(20).span.shown and #ShownIcons(Cell(20)) == 0, "leerer Tag")
local endet
for _, r in ipairs(made) do if r.kind == "FontString" and type(r.text) == "string" and r.text:find("Dunkelmond%-Jahrmarkt endet So") then endet = true end end
assert(endet, "Demnaechst: Jahrmarkt endet am Sonntag")
-- Filter: WoW-Events aus -> kein Streifen, kein Symbol; Gildentermin bleibt
ONE.db = ONE.db or {}
ONE.db.guild = ONE.db.guild or {}
ONE.db.guild.calendarFilter = {holiday = false}
refresh()
assert(not c9.span.shown and #ShownIcons(c9) == 0 and #ShownIcons(c13) == 1, "Filter WoW-Events")
ONE.db.guild.calendarFilter = {}
refresh()
-- Tag anklicken
local cell13
for _, r in ipairs(made) do
    if r.kind == "Button" and r.date and r.date.day == 13 and r.date.month == 11 then cell13 = r end
end
cell13.scripts.OnClick(cell13)
assert(FindText("Freitag, 13. November"))
-- Monat wechseln: bis zum naechsten Monat, nicht weiter
local nextButton
for _, r in ipairs(made) do if r.kind == "Button" and r.text == ">" then nextButton = r end end
assert(nextButton, "Weiter-Knopf fehlt")
nextButton.scripts.OnClick()
assert(FindText("Dezember 2026") and FindText("Dienstag, 1. Dezember"))
assert(not nextButton.shown, "Weiter erst wieder, wenn das Spiel Daten liefert")
nextButton.scripts.OnClick()
assert(not FindText("Januar 2027"))
-- Gildenausfluege erscheinen als Eintraege (Art GUILDTRIP, Klick oeffnet den Ausflug)
date = date or os.date
local start = os.time({year = 2026, month = 11, day = 20, hour = 20, min = 30, sec = 0})
local opened
ONE.modules.dungeons = {
    CalendarTrips = function() return {{id = "t1", name = "Höhlen des Wehklagens", start = start, leader = "Thrall",
        coming = 3, mine = "yes", meet = "Brachland", mapID = 1413, x = .5, y = .5}} end,
    OpenTrip = function(_, id) opened = id end,
}
local trips = guild.UI.TripEntries()
assert(#trips == 1 and trips[1].calendarType == "GUILDTRIP" and trips[1].trip == "t1")
local st = trips[1].startTime
assert(st.year == 2026 and st.month == 11 and st.monthDay == 20 and st.hour == 20 and st.minute == 30)
assert(trips[1].title == "Ausflug: Höhlen des Wehklagens", trips[1].title)
assert(trips[1].description:find("Thrall") and trips[1].description:find("du kommst"), trips[1].description)
assert(#C:GetDay(2026, 11, 20) == 0, "Ausfluege stehen nicht in den Blizzard-Terminen (keine doppelten Erinnerungen)")
ONE.modules.dungeons = nil
assert(#guild.UI.TripEntries() == 0)
print("OK: 0.4.9f - Kalender: Monatsraster, KW, WoW-Events, Tagesansicht, Monatswechsel")
