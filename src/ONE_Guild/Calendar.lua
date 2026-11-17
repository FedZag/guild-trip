local _, guild = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Calendar = {}
guild.Calendar = Calendar

local floor = math.floor
local function IsLeap(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local monthLengths = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local function DaysInMonth(year, month)
    if month == 2 and IsLeap(year) then return 29 end
    return monthLengths[month]
end

local monthStart = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334}
local function DayNumber(year, month, day)
    local previous = year - 1
    local days = previous * 365 + floor(previous / 4) - floor(previous / 100) + floor(previous / 400)
    return days + monthStart[month] + (month > 2 and IsLeap(year) and 1 or 0) + day
end

local function TimeMinutes(value)
    return DayNumber(value.year, value.month, value.monthDay) * 1440
        + (value.hour or 0) * 60 + (value.minute or 0)
end

local function AddDay(day)
    day.monthDay = day.monthDay + 1
    if day.monthDay > DaysInMonth(day.year, day.month) then
        day.monthDay = 1
        day.month = day.month + 1
        if day.month > 12 then
            day.month = 1
            day.year = day.year + 1
        end
    end
end

local allowedTypes = {
    PLAYER = true,
    GUILD_EVENT = true,
    GUILD_ANNOUNCEMENT = true,
    COMMUNITY_EVENT = true,
}

-- Fuer die Monatsansicht zusaetzlich: WoW-Events (Feiertage, Jahrmarkt) und Schlachtzug-Resets.
-- Erinnerungen und "Heute" nutzen weiterhin nur self.events (ohne diese Eintraege).
local monthTypes = {
    PLAYER = true,
    GUILD_EVENT = true,
    GUILD_ANNOUNCEMENT = true,
    COMMUNITY_EVENT = true,
    HOLIDAY = true,
    RAID_RESET = true,
}
Calendar.monthTypes = monthTypes

local function EventKey(event)
    local start = event.startTime
    return table.concat({
        tostring(event.eventID or "unknown"),
        tostring(event.calendarType or ""),
        string.format("%04d%02d%02d%02d%02d", start.year, start.month, start.monthDay, start.hour or 0, start.minute or 0),
        tostring(event.title),
    }, "|")
end

local function CopyTime(t)
    if type(t) ~= "table" then return nil end
    return {year = t.year, month = t.month, monthDay = t.monthDay, weekday = t.weekday,
        hour = t.hour or 0, minute = t.minute or 0}
end

local function DayKey(year, month, day)
    return string.format("%04d%02d%02d", year, month, day)
end

-- Liest Vormonat, aktuellen und naechsten Monat (mehr haelt der Client nicht vor).
function Calendar:ReadMonths(now, baseMonth)
    local days, holidays = {}, {}
    self.holidayText = self.holidayText or {}
    local getHoliday = C_Calendar.GetHolidayInfo
    for delta = -1, 1 do
        local index = now.year * 12 + now.month - 1 + delta
        local year, month = floor(index / 12), index % 12 + 1
        local offset = year * 12 + month - baseMonth
        if math.abs(offset) <= 1 then
            for day = 1, DaysInMonth(year, month) do
                local list = {}
                local count = C_Calendar.GetNumDayEvents(offset, day) or 0
                for i = 1, count do
                    local event = C_Calendar.GetDayEvent(offset, day, i)
                    if event and monthTypes[event.calendarType] and type(event.title) == "string" and event.startTime then
                        local entry = {
                            title = event.title, calendarType = event.calendarType, eventID = event.eventID,
                            holiday = event.calendarType == "HOLIDAY", sequenceType = event.sequenceType,
                            startTime = CopyTime(event.startTime), endTime = CopyTime(event.endTime),
                            icon = event.iconTexture, inviteStatus = event.inviteStatus,
                        }
                        entry.key = EventKey(entry)
                        if entry.holiday then
                            if self.holidayText[entry.title] == nil and type(getHoliday) == "function" then
                                local ok, info = pcall(getHoliday, offset, day, i)
                                self.holidayText[entry.title] = ok and type(info) == "table"
                                    and type(info.description) == "string" and info.description or false
                            end
                            entry.description = self.holidayText[entry.title] or nil
                            if delta == 0 then holidays[entry.title] = true end
                        else
                            local cached = self.details and self.details[entry.key]
                            entry.description = cached and cached.description
                        end
                        list[#list + 1] = entry
                    end
                end
                if #list > 0 then
                    table.sort(list, function(a, b)
                        if a.holiday ~= b.holiday then return a.holiday end
                        local ta, tb = TimeMinutes(a.startTime), TimeMinutes(b.startTime)
                        if ta ~= tb then return ta < tb end
                        return a.title < b.title
                    end)
                    days[DayKey(year, month, day)] = list
                end
            end
        end
    end
    local holidayCount = 0
    for _ in pairs(holidays) do holidayCount = holidayCount + 1 end
    self.days = days
    self.holidayCount = holidayCount
    self.loadedMonths = {first = now.year * 12 + now.month - 1, last = now.year * 12 + now.month + 1}
end

function Calendar:GetDay(year, month, day)
    return self.days and self.days[DayKey(year, month, day)] or {}
end

function Calendar:GetCurrentTime()
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        return C_DateAndTime.GetCurrentCalendarTime()
    end
    return nil
end

function Calendar:GetMinutesUntil(entry)
    local now = self:GetCurrentTime()
    if not now or not entry or not entry.startTime then return nil end
    return TimeMinutes(entry.startTime) - TimeMinutes(now)
end

function Calendar:Scan()
    if not ONE:IsEnabled("guild") then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not (C_Calendar and C_Calendar.GetMonthInfo and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) then
        self.status = T("Die Kalender-API steht nicht zur Verfügung.")
        ONE.UI:Refresh()
        return
    end

    local now = self:GetCurrentTime()
    local base = C_Calendar.GetMonthInfo(0)
    if not now or not base then
        self.status = T("Kalenderdaten sind noch nicht verfügbar.")
        ONE.UI:Refresh()
        return
    end

    -- Der Client kann beim ersten Start auf November 2004 zeigen.
    -- Nur in diesem Sonderfall korrigieren wir das ausgewaehlte Monat.
    local baseDistance = (now.year - base.year) * 12 + now.month - base.month
    if math.abs(baseDistance) > 12 and C_Calendar.SetAbsMonth then
        C_Calendar.SetAbsMonth(now.month, now.year)
        base = C_Calendar.GetMonthInfo(0)
    end
    if not base then return end

    local cursor = { year = now.year, month = now.month, monthDay = now.monthDay }
    local results, usedKeys = {}, {}
    self.details = self.details or {}
    local baseMonth = base.year * 12 + base.month

    -- Die Abfrage durchsucht bewusst nur 14 Tage und laesst Systemereignisse aus.
    for offsetDays = 0, 13 do
        local offsetMonths = cursor.year * 12 + cursor.month - baseMonth
        if math.abs(offsetMonths) <= 24 then
            local count = C_Calendar.GetNumDayEvents(offsetMonths, cursor.monthDay) or 0
            for index = 1, count do
                local event = C_Calendar.GetDayEvent(offsetMonths, cursor.monthDay, index)
                if event and allowedTypes[event.calendarType] and event.startTime and event.title then
                    local started = TimeMinutes(event.startTime) - TimeMinutes(now)
                    if started >= -1 then
                        local start = event.startTime
                        local key = EventKey(event)
                        if not usedKeys[key] then
                            usedKeys[key] = true
                            results[#results + 1] = {
                                key = key,
                                eventID = event.eventID,
                                title = event.title,
                                calendarType = event.calendarType,
                                startTime = {
                                    year = start.year,
                                    month = start.month,
                                    monthDay = start.monthDay,
                                    hour = start.hour or 0,
                                    minute = start.minute or 0,
                                },
                                minutesUntil = started,
                                inviteStatus = event.inviteStatus,
                                -- Die ausführliche Beschreibung wird erst beim Anklicken geladen.
                                description = self.details[key] and self.details[key].description,
                            }
                        end
                    end
                end
            end
        end
        AddDay(cursor)
    end

    table.sort(results, function(a, b)
        if a.minutesUntil ~= b.minutesUntil then return a.minutesUntil < b.minutesUntil end
        return a.title < b.title
    end)
    -- Monatsansicht darf den Termin-Scan nie verhindern.
    local ok, err = pcall(self.ReadMonths, self, now, baseMonth)
    if not ok then self.days, self.monthError = {}, err end
    self.events = results
    self.ready = true
    self.status = #results == 0 and T("Keine kommenden Termine in den nächsten 14 Tagen.") or (#results == 1 and T("1 Termin gefunden.") or T("%d Termine gefunden.", #results))
    if (self.holidayCount or 0) > 0 then
        self.status = self.status .. " " .. (self.holidayCount == 1 and T("1 WoW-Event in diesem Monat.") or T("%d WoW-Events in diesem Monat.", self.holidayCount))
    end
    guild:OnCalendarScanned()
end

function Calendar:ScheduleScan()
    if not ONE:IsEnabled("guild") then return end
    if self.scanScheduled then return end
    self.scanScheduled = true
    C_Timer.After(0.6, function()
        self.scanScheduled = false
        self:Scan()
    end)
end

function Calendar:RequestRefresh()
    if not ONE:IsEnabled("guild") then return end
    if not (C_Calendar and C_Calendar.OpenCalendar) then
        self.status = T("Kalender-API nicht verfügbar.")
        ONE.UI:Refresh()
        return
    end
    if InCombatLockdown and InCombatLockdown() then return end
    C_Calendar.OpenCalendar() -- Fragt Serverdaten ab, zeigt nicht das Blizzard-Kalenderfenster.
    C_Timer.After(3, function() self:Scan() end) -- Falls das Update-Event ausbleibt.
end


-- Die Kurzansicht GetDayEvent enthält keine Beschreibung. Die Detailabfrage
-- ist absichtlich nur per Klick möglich, damit das automatische Scannen nicht
-- die Auswahl eines Kalendertermins im Blizzard-Client verändert.
function Calendar:LoadDescription(entry, callback)
    if not entry or not callback then return end
    if self.details and self.details[entry.key] then
        callback(self.details[entry.key])
        return
    end
    if not (C_Calendar and C_Calendar.OpenEvent and C_Calendar.GetEventInfo and C_Calendar.GetMonthInfo) then
        callback(nil, T("Die Kalenderdetails stehen in diesem Client nicht zur Verfügung."))
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        callback(nil, T("Bitte öffne die Termindetails nach dem Kampf."))
        return
    end
    if self.pendingDetail then
        callback(nil, T("Ein anderer Termin wird gerade geladen. Bitte versuche es erneut."))
        return
    end

    -- Ereignisindizes sind nicht dauerhaft stabil; vor dem Öffnen kontrollieren.
    local offset, foundIndex, why = self:FindIndex(entry)
    if not foundIndex then
        callback(nil, why)
        return
    end
    local time = entry.startTime

    self.detailSerial = (self.detailSerial or 0) + 1
    local serial = self.detailSerial
    self.pendingDetail = {serial=serial, entry=entry, callback=callback}
    local ok, opened = pcall(C_Calendar.OpenEvent, offset, time.monthDay, foundIndex)
    if not ok or opened == false then
        local pending = self.pendingDetail
        if pending and pending.serial == serial then
            self.pendingDetail = nil
            callback(nil, T("Die Termindetails konnten nicht geöffnet werden."))
        end
        return
    end

    -- Manche Clients liefern die Daten sofort, andere mit CALENDAR_OPEN_EVENT.
    self:ReceiveDescription()
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            local pending = self.pendingDetail
            if pending and pending.serial == serial then
                self:ReceiveDescription()
                pending = self.pendingDetail
                if pending and pending.serial == serial then
                    self.pendingDetail = nil
                    callback(nil, T("Die Beschreibung konnte nicht geladen werden."))
                end
            end
        end)
    end
end

-- Monats-Versatz und Index eines Eintrags im Blizzard-Kalender (Indizes aendern sich!)
function Calendar:FindIndex(entry)
    local month = C_Calendar and C_Calendar.GetMonthInfo and C_Calendar.GetMonthInfo(0)
    if not month then return nil, nil, T("Die Kalenderdaten sind noch nicht verfügbar.") end
    local time = entry.startTime
    local offset = (time.year - month.year) * 12 + time.month - month.month
    local count = C_Calendar.GetNumDayEvents and C_Calendar.GetNumDayEvents(offset, time.monthDay) or 0
    for index = 1, count do
        local candidate = C_Calendar.GetDayEvent(offset, time.monthDay, index)
        if candidate and candidate.title == entry.title and candidate.calendarType == entry.calendarType
            and candidate.startTime and TimeMinutes(candidate.startTime) == TimeMinutes(time)
            and (not entry.eventID or candidate.eventID == entry.eventID) then
            return offset, index
        end
    end
    return offset, nil, T("Termin wurde verändert. Bitte aktualisiere den Kalender.")
end

-- ===== Zu-/Absagen fuer Blizzard-Termine (15.11.2026) =====
-- Enum.CalendarStatus: 0 eingeladen, 1 zugesagt, 2 abgesagt, 3 bestaetigt, 4 raus,
-- 5 Ersatz, 6 angemeldet, 7 nicht angemeldet, 8 vielleicht
Calendar.statusText = {[0] = "eingeladen", [1] = "zugesagt", [2] = "abgesagt", [3] = "bestätigt", [4] = "abgemeldet",
    [5] = "Ersatz", [6] = "angemeldet", [7] = "nicht angemeldet", [8] = "vielleicht"}
-- Auf welche Termine kann man antworten? (Gildenankuendigung, Feiertag, Reset: nein)
Calendar.answerTypes = {PLAYER = true, GUILD_EVENT = true, COMMUNITY_EVENT = true}
function Calendar.CanAnswer(entry)
    return entry and Calendar.answerTypes[entry.calendarType] and not entry.trip and true or false
end
function Calendar.StatusText(entry)
    local s = entry and entry.inviteStatus
    return s and Calendar.statusText[s] and T(Calendar.statusText[s]) or nil
end

-- answer: "yes" | "maybe" | "no". Oeffnet den Termin im Client und antwortet dort.
-- callback(ok, meldung)
function Calendar:Respond(entry, answer, callback)
    callback = callback or function() end
    if not Calendar.CanAnswer(entry) then return callback(false, T("Auf diesen Eintrag kann man nicht antworten.")) end
    if not (C_Calendar and C_Calendar.OpenEvent) then return callback(false, T("Die Kalenderdetails stehen in diesem Client nicht zur Verfügung.")) end
    if InCombatLockdown and InCombatLockdown() then return callback(false, T("Bitte nach dem Kampf.")) end
    local offset, index, why = self:FindIndex(entry)
    if not index then return callback(false, why) end
    local ok = pcall(C_Calendar.OpenEvent, offset, entry.startTime.monthDay, index)
    if not ok then return callback(false, T("Die Termindetails konnten nicht geöffnet werden.")) end
    local function Act()
        local info = C_Calendar.GetEventInfo and C_Calendar.GetEventInfo()
        if not info or info.title ~= entry.title then return callback(false, T("Die Termindetails konnten nicht geöffnet werden.")) end
        -- Gilden-Anmeldetermine: Anmelden statt Zusagen
        local signup = entry.calendarType == "GUILD_EVENT" and type(C_Calendar.EventSignUp) == "function"
            and (entry.inviteStatus == nil or entry.inviteStatus == 7 or entry.inviteStatus == 4)
        local fn = answer == "yes" and (signup and C_Calendar.EventSignUp or C_Calendar.EventAvailable)
            or answer == "maybe" and C_Calendar.EventTentative or answer == "no" and C_Calendar.EventDecline
        if type(fn) ~= "function" then return callback(false, T("Das kann dieser Client nicht.")) end
        local done = pcall(fn)
        if not done then return callback(false, T("Antworten ging gerade nicht – bitte gleich noch einmal versuchen.")) end
        entry.inviteStatus = answer == "yes" and (signup and 6 or 1) or answer == "maybe" and 8 or 2
        if C_Timer and C_Timer.After then C_Timer.After(1, function() self:RequestRefresh() end) end
        callback(true)
    end
    -- manche Clients brauchen einen Moment (CALENDAR_OPEN_EVENT)
    if C_Timer and C_Timer.After then C_Timer.After(.3, Act) else Act() end
end

function Calendar:ReceiveDescription()
    local pending = self.pendingDetail
    if not pending then return end
    local info = C_Calendar.GetEventInfo()
    if not info or info.title ~= pending.entry.title then return end
    -- Zur Sicherheit Datum und Uhrzeit des offenen Termins abgleichen.
    if info.time and TimeMinutes(info.time) ~= TimeMinutes(pending.entry.startTime) then return end
    local details = {
        description = type(info.description) == "string" and info.description or "",
        creator = type(info.creator) == "string" and info.creator or "",
    }
    self.details = self.details or {}
    self.details[pending.entry.key] = details
    self.pendingDetail = nil
    pending.callback(details)
end

function Calendar:Initialize()
    self.events = {}
    self.details = {}
    self.status = T("Kalender wird geladen ...")
    self.ready = false
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
    frame:RegisterEvent("CALENDAR_UPDATE_GUILD_EVENTS")
    frame:RegisterEvent("CALENDAR_NEW_EVENT")
    frame:RegisterEvent("CALENDAR_OPEN_EVENT")
    frame:SetScript("OnEvent", function(_, event)
        if event == "CALENDAR_OPEN_EVENT" then
            self:ReceiveDescription()
        else
            self:ScheduleScan()
        end
    end)

    -- Ein Kalenderaufruf beim Ladebildschirm liefert laut API noch keine Daten.
    local world = CreateFrame("Frame")
    world:RegisterEvent("PLAYER_ENTERING_WORLD")
    world:SetScript("OnEvent", function()
        C_Timer.After(6, function() self:RequestRefresh() end)
    end)
    C_Timer.NewTicker(180, function() self:RequestRefresh() end)
end
