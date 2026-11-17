local _, guild = ...
local ONE = _G.ProjectONE
-- Uebersetzung (ONE.T); ohne Sprachmodul bleibt der deutsche Text.
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end
local Reminders = {}
guild.Reminders = Reminders

-- Zeitfenster sind einstellbar. Standardwerte bleiben wie in 0.2.7.
-- Nil = noch nicht konfiguriert. Eine leere Tabelle ist eine gueltige Auswahl
-- und bedeutet: Keine Erinnerungen. Deshalb hier keine Core-Default-Mischung.
local DEFAULT_THRESHOLDS = {60, 15, 5, 0}
local MAX_THRESHOLDS = 8
local MAX_MINUTES = 1440

local function Copy(values)
    local result = {}
    for i, value in ipairs(values) do result[i] = value end
    return result
end

local function Normalize(values)
    if type(values) ~= "table" then return Copy(DEFAULT_THRESHOLDS) end
    local result, seen = {}, {}
    for _, value in pairs(values) do
        if type(value) == "number" and value == math.floor(value)
            and value >= 0 and value <= MAX_MINUTES and not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end
    table.sort(result, function(a, b) return a > b end)
    while #result > MAX_THRESHOLDS do table.remove(result) end
    return result
end

function Reminders:GetThresholds()
    local db = ONE.db and ONE.db.guild
    if not db then return Copy(DEFAULT_THRESHOLDS) end
    if db.reminderMinutes == nil then
        db.reminderMinutes = Copy(DEFAULT_THRESHOLDS)
    else
        db.reminderMinutes = Normalize(db.reminderMinutes)
    end
    return Copy(db.reminderMinutes)
end

function Reminders:SetThresholds(values)
    if not ONE.db or not ONE.db.guild or type(values) ~= "table" then return false end
    local cleaned = Normalize(values)
    if #cleaned > MAX_THRESHOLDS then return false end
    ONE.db.guild.reminderMinutes = cleaned
    return true
end

function Reminders:AddThreshold(value)
    if type(value) ~= "number" or value ~= math.floor(value)
        or value < 0 or value > MAX_MINUTES then
        return false, T("Bitte eine ganze Zahl zwischen 0 und 1440 Minuten eingeben.")
    end
    local values = self:GetThresholds()
    for _, existing in ipairs(values) do
        if existing == value then return false, T("Diese Erinnerungszeit ist bereits eingetragen.") end
    end
    if #values >= MAX_THRESHOLDS then
        return false, T("Maximal acht Erinnerungszeiten sind möglich.")
    end
    values[#values + 1] = value
    self:SetThresholds(values)
    return true
end

function Reminders:RemoveThreshold(value)
    local values = self:GetThresholds()
    for i, existing in ipairs(values) do
        if existing == value then
            table.remove(values, i)
            self:SetThresholds(values)
            return true
        end
    end
    return false
end

function Reminders:ResetThresholds()
    return self:SetThresholds(DEFAULT_THRESHOLDS)
end

-- Exakt passende Schwellen gehen vor 1 Minute verspäteten Meldungen.
-- Damit funktionieren auch selbst gewählte benachbarte Werte (z.B. 5 und 4).
local function FindStage(minutes, thresholds)
    for _, threshold in ipairs(thresholds) do
        if minutes == threshold then return threshold end
    end
    for _, threshold in ipairs(thresholds) do
        if minutes == threshold - 1 then return threshold end
    end
    return nil
end

local function TodayNumber()
    local now = guild.Calendar:GetCurrentTime()
    if not now or type(now.year) ~= "number" or type(now.month) ~= "number"
        or type(now.monthDay) ~= "number" or now.month < 1 or now.month > 12
        or now.monthDay < 1 or now.monthDay > 31 then
        return nil
    end
    local previous = now.year - 1
    local leap = (now.year % 4 == 0 and (now.year % 100 ~= 0 or now.year % 400 == 0))
    local days = {0,31,59,90,120,151,181,212,243,273,304,334}
    return previous * 365 + math.floor(previous/4) - math.floor(previous/100)
        + math.floor(previous/400) + days[now.month] + (now.month > 2 and leap and 1 or 0) + now.monthDay
end

function Reminders:CleanupHistory()
    local today = TodayNumber()
    if not today then return end
    for key, history in pairs(ONE.db.guild.noticeHistory) do
        if type(history) ~= "table" or (history.expireDay and history.expireDay < today) then
            ONE.db.guild.noticeHistory[key] = nil
        end
    end
end

function Reminders:Check()
    if not ONE:IsEnabled("guild") then return end
    if not ONE.db or not ONE.db.remindersEnabled or not guild.Calendar.ready then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local nowDay = TodayNumber()
    if not nowDay then return end

    local thresholds = self:GetThresholds()
    if #thresholds == 0 then return end
    for _, event in ipairs(guild.Calendar.events or {}) do
        local minutes = guild.Calendar:GetMinutesUntil(event)
        if minutes and minutes >= -1 and minutes <= thresholds[1] then
            -- Verpasste Termine nicht nachtraeglich als frische Erinnerung melden.
            -- Die 1-Minuten-Toleranz gleicht kurze Timerverzoegerungen aus.
            local stage = FindStage(minutes, thresholds)
            if stage ~= nil then
                local history = ONE.db.guild.noticeHistory[event.key]
                if not history then
                    history = { fired = {}, expireDay = nowDay + 15 }
                    ONE.db.guild.noticeHistory[event.key] = history
                end
                if type(history.fired) ~= "table" then history.fired = {} end
                if not history.fired[stage] then
                    history.fired[stage] = true
                    local text = minutes <= 0 and T("Termin '%s' beginnt jetzt", event.title) or T("Termin '%s' beginnt in %d Min.", event.title, minutes)
                    ONE:Notify(text, { source = T("Guild Trip Kalender") })
                end
            end
        end
    end
end

function Reminders:Initialize()
    self:GetThresholds() -- Version 0.2.7: alte Einstellungen behalten, Standard uebernehmen
    self:CleanupHistory()
    C_Timer.NewTicker(30, function() self:Check() end)
    C_Timer.NewTicker(3600, function() self:CleanupHistory() end)
end
