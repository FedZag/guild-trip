-- Ausführen: texlua tests/test_reminder_settings.lua
-- Ohne WoW-Client: echte Reminder-Logik + simulierte Kalenderzeit und Ticker.
local path = arg and arg[0] and arg[0]:match("^(.*)/tests/test_reminder_settings.lua$") or "."
local ONE = {
    db = {remindersEnabled = true, guild = {noticeHistory = {}}},
    calls = {},
    IsEnabled = function() return true end,
}
function ONE:Notify(message, opts)
    table.insert(self.calls, {message = message, source = opts.source})
end
_G.ProjectONE = ONE
local nowMinutes = 999
local guild = {
    Calendar = {
        ready = true,
        events = {{key = "event-1", title = "Gildenabend"}},
        GetMinutesUntil = function() return nowMinutes end,
        GetCurrentTime = function() return {year = 2026, month = 10, monthDay = 27} end,
    },
}
local timers = {}
C_Timer = {NewTicker = function(interval, callback)
    timers[interval] = callback
end}
InCombatLockdown = function() return false end
assert(loadfile(path .. "/src/ONE_Guild/Reminders.lua"))("ONE_Guild", guild)
local r = guild.Reminders

local function eq(a, b, message)
    assert(a == b, (message or "Ungleiche Werte") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function values(expected)
    local list = r:GetThresholds()
    eq(#list, #expected, "Listengröße")
    for i, v in ipairs(expected) do eq(list[i], v, "Position " .. i) end
end

-- Migration: Keine individuellen Daten -> exakt dieselben Standardzeiten wie 0.2.7.
r:Initialize()
values({60, 15, 5, 0})
eq(#ONE.db.guild.noticeHistory, 0)
assert(timers[30] and timers[3600])

-- Alte Einstellungen nicht ueberschreiben, auch wenn Benachrichtigungen abgeschaltet.
assert(r:AddThreshold(30))
values({60, 30, 15, 5, 0})
local ok, reason = r:AddThreshold(30)
assert(not ok and reason:find("bereits"))
for _, invalid in ipairs({-1, 1441, 3.5, "30"}) do
    assert(not r:AddThreshold(invalid))
end
assert(r:AddThreshold(1440))
values({1440, 60, 30, 15, 5, 0})
assert(r:AddThreshold(2))
assert(r:AddThreshold(1))
assert(not r:AddThreshold(999)) -- max acht
values({1440, 60, 30, 15, 5, 2, 1, 0})
assert(r:RemoveThreshold(30))
assert(not r:RemoveThreshold(999))
values({1440, 60, 15, 5, 2, 1, 0})
assert(r:ResetThresholds())
values({60, 15, 5, 0})

-- Echte Reminder-Abfolge in einer simulierten Session.
nowMinutes = 31
r:Check()
eq(#ONE.calls, 0, "Keine nachgeholte 60-Minuten-Meldung bei 31 Min")
nowMinutes = 15
r:Check()
eq(#ONE.calls, 1)
assert(ONE.calls[1].message:find("15 Min", 1, true))
assert(ONE.calls[1].source == "Guild Trip Kalender")
timers[30]()
eq(#ONE.calls, 1, "Keine doppelte Meldung")
nowMinutes = 5
r:Check()
eq(#ONE.calls, 2)
nowMinutes = 0
r:Check()
eq(#ONE.calls, 3)
assert(ONE.calls[3].message:find("beginnt jetzt", 1, true))
r:Check()
eq(#ONE.calls, 3)

-- Andere individuelle Auswahl inklusive Terminbeginn deaktivieren.
ONE.db.guild.noticeHistory = {}
assert(r:SetThresholds({30, 7}))
values({30, 7})
nowMinutes = 31
r:Check()
eq(#ONE.calls, 3)
nowMinutes = 30
r:Check()
eq(#ONE.calls, 4)
nowMinutes = 29
r:Check()
eq(#ONE.calls, 4)
nowMinutes = 7
r:Check()
eq(#ONE.calls, 5)
nowMinutes = 0
r:Check()
eq(#ONE.calls, 5, "0 Minuten ist abgewählt")

-- Benachbarte Schwellen: nicht versehentlich die falsche wählen.
ONE.db.guild.noticeHistory = {}
assert(r:SetThresholds({5, 4, 0}))
nowMinutes = 5; r:Check()
nowMinutes = 4; r:Check()
eq(#ONE.calls, 7)
assert(ONE.db.guild.noticeHistory["event-1"].fired[5])
assert(ONE.db.guild.noticeHistory["event-1"].fired[4])

-- Leere Auswahl ist dauerhaft gueltig; nicht mit Standard auffüllen.
assert(r:SetThresholds({}))
values({})
nowMinutes = 0; r:Check()
eq(#ONE.calls, 7)
values({})

-- Grenzwerte in alten oder beschädigten gespeicherten Daten sanft bereinigen.
ONE.db.guild.reminderMinutes = {30, 30, -5, 1500, 0, "5", 15}
values({30, 15, 0})

print("OK: Migration, individuell gespeicherte Zeiten, Grenzwerte, Timer, keine Duplikate")
