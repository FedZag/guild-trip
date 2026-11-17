-- Offline-Test: Blizzard-Termine im Addon beantworten (ohne den WoW-Kalender zu oeffnen).
local root = arg[1] or "src"
local called = {}
local opened
local events = {
    {title = "HDW Questrun", calendarType = "GUILD_EVENT", eventID = 7, inviteStatus = 7,
        startTime = {year = 2026, month = 11, monthDay = 17, hour = 18, minute = 30}},
    {title = "Mein Termin", calendarType = "PLAYER", eventID = 8, inviteStatus = 0,
        startTime = {year = 2026, month = 11, monthDay = 17, hour = 20, minute = 0}},
}
C_Calendar = {
    GetMonthInfo = function() return {year = 2026, month = 11} end,
    GetNumDayEvents = function(offset, day) return (offset == 0 and day == 17) and #events or 0 end,
    GetDayEvent = function(_, _, i) return events[i] end,
    OpenEvent = function(offset, day, index) opened = events[index] return true end,
    GetEventInfo = function() return opened and {title = opened.title} or nil end,
    EventAvailable = function() called[#called + 1] = "available" end,
    EventSignUp = function() called[#called + 1] = "signup" end,
    EventTentative = function() called[#called + 1] = "tentative" end,
    EventDecline = function() called[#called + 1] = "decline" end,
}
Calendar_Toggle = function() error("Der WoW-Kalender darf nie geoeffnet werden") end
C_Timer = {After = function(_, fn) fn() end}
local ONE = {}
_G.ProjectONE = ONE
local guild = {}
assert(loadfile(root .. "/ONE_Guild/Calendar.lua"))("ONE_Guild", guild)
local C = guild.Calendar
C.RequestRefresh = function() C.refreshed = true end

local function Copy(e) local t = {} for k, v in pairs(e) do t[k] = v end return t end
local function Answer(e, kind)
    local res
    C:Respond(e, kind, function(ok, msg) res = {ok, msg} end)
    return res
end

-- 1) Gilden-Anmeldetermin: "Zusagen" = Anmelden, Stand wird gemerkt, Kalender frisch geladen
local guildEvent = Copy(events[1])
assert(C.CanAnswer(guildEvent))
assert(C.StatusText(guildEvent) == "nicht angemeldet")
local r = Answer(guildEvent, "yes")
assert(r[1] and called[1] == "signup" and guildEvent.inviteStatus == 6 and C.refreshed, tostring(r[2]))
assert(C.StatusText(guildEvent) == "angemeldet")

-- 2) Eigener Termin: Zusagen / Vielleicht / Absagen
local mine = Copy(events[2])
assert(Answer(mine, "yes")[1] and called[2] == "available" and mine.inviteStatus == 1)
assert(Answer(mine, "maybe")[1] and called[3] == "tentative" and C.StatusText(mine) == "vielleicht")
assert(Answer(mine, "no")[1] and called[4] == "decline" and C.StatusText(mine) == "abgesagt")

-- 3) Nicht beantwortbar: Feiertag, Gildenankuendigung, Guild-Trip-Ausflug
assert(not C.CanAnswer({calendarType = "HOLIDAY"}) and not C.CanAnswer({calendarType = "GUILD_ANNOUNCEMENT"}))
assert(not C.CanAnswer({calendarType = "GUILDTRIP", trip = "x"}))
assert(Answer({calendarType = "HOLIDAY", title = "Fest"}, "yes")[1] == false)

-- 4) Termin inzwischen geaendert -> klare Meldung, nichts ausgefuehrt
local gone = Copy(events[2]) gone.title = "Weg"
local res = Answer(gone, "yes")
assert(res[1] == false and res[2]:find("verändert"), res[2])
assert(#called == 4)

-- 5) Im Kampf: nichts tun
InCombatLockdown = function() return true end
assert(Answer(mine, "yes")[1] == false and #called == 4)
print("OK test_calendar_answer_087")
