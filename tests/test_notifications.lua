-- Standalone-Tests: texlua tests/test_notifications.lua
-- WoW-UI-Objekte und Timer werden nur für diesen Test simuliert.
local ONE = { db = { toastEnabled = true, soundEnabled = true }, printed = {},
    Themes = {RegisterWindow = function() end, StyleTree = function() end, RegisterText = function() end,
        RegisterRule = function() end, RegisterPanel = function() end},
    Widgets = {CloseButton = function() end} }
function ONE:Print(text) table.insert(self.printed, text) end
local frames, timers, sounds = {}, {}, {}
UIParent = {}
SOUNDKIT = { RAID_WARNING = 7 }
PlaySound = function(sound, channel) table.insert(sounds, {sound, channel}) end
C_Timer = { After = function(delay, callback) table.insert(timers, {delay, callback}) end }
local function element()
    local obj = {shown = true, scripts = {}}
    for _, k in ipairs({"SetSize", "SetPoint", "SetFrameStrata", "SetToplevel", "EnableMouse", "SetClampedToScreen", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetColorTexture", "SetWidth", "SetJustifyH", "SetJustifyV"}) do obj[k] = function() end end
    function obj:SetText(text) self.text = text end
    function obj:SetScript(ev, fn) self.scripts[ev] = fn end
    function obj:CreateTexture() return element() end
    function obj:CreateFontString() return element() end
    function obj:Show() self.shown = true end
    function obj:Hide() self.shown = false end
    return obj
end
CreateFrame = function(_, name)
    local obj = element()
    if name then frames[name] = obj end
    return obj
end
local path = arg and arg[0] and arg[0]:match("^(.*)/tests/test_notifications.lua$") or "."
local chunk = assert(loadfile(path .. "/src/ONE_Core/Notifications.lua"))
chunk("ONE_Core", ONE)
local N = ONE.Notifications
N:Initialize()
assert(frames.ProjectONENotificationWindow == N.frame)
assert(not N.frame.shown)
assert(N:Push("Raid beginnt", {source="ONE Guild"}))
assert(N.frame.shown and N.header.text == "ONE Guild" and N.message.text == "Raid beginnt")
assert(#ONE.printed == 1 and #sounds == 1 and #timers == 1)
assert(timers[1][1] == 7)
assert(N:Push("Zweiter Termin", {source="ONE Calendar", silent=true}))
assert(#N.queue == 1 and #ONE.printed == 2 and #sounds == 1)
-- Vom Nutzer vorzeitig geschlossen: nächster Hinweis startet sofort.
N:Dismiss()
assert(N.message.text == "Zweiter Termin")
assert(#timers == 2)
-- Abgelaufener Timer des ersten Hinweises darf den zweiten nicht schließen.
timers[1][2]()
assert(N.frame.shown and N.message.text == "Zweiter Termin")
timers[2][2]()
assert(not N.frame.shown and #N.queue == 0)
assert(not N:Push(nil) and #ONE.printed == 2)
-- Ausgeschaltetes Hinweisfenster: weiter Chat + ggf. Sound.
ONE.db.toastEnabled = false
N:SettingsChanged()
assert(N:Push("Nur Chat") and not N.frame.shown)
assert(#ONE.printed == 3 and #N.queue == 0)
ONE.db.soundEnabled = false
assert(N:Push("Leise", {source = "Test"}))
assert(#sounds == 2)
-- Umschalten bei geöffneter Nachricht verwirft die Warteschlange.
ONE.db.toastEnabled = true
N:Push("Ein")
N:Push("Zwei")
assert(#N.queue == 1 and N.frame.shown)
ONE.db.toastEnabled = false
N:SettingsChanged()
assert(not N.frame.shown and #N.queue == 0)
print("OK: Benachrichtigungen, Warteschlange, Timer, Ton und Einstellungen")
