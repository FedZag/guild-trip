-- Ausführen: texlua tests/test_reminder_ui_034b.lua
-- Simuliert die WoW-UI, testet die Anbindung der Modul-Unterseite an ONE Core.
local path = arg and arg[0] and arg[0]:match("^(.*)/tests/test_reminder_ui_034b.lua$") or "."
local elements = {}
local function Element(kind)
    local o = {kind = kind, visible = true, scripts = {}, text = ""}
    for _, m in ipairs({"SetSize","SetPoint","SetAllPoints","SetWidth","SetHeight","SetJustifyH",
        "SetJustifyV","SetWordWrap","SetFontString","SetFrameStrata","SetToplevel","SetMovable","EnableMouse","RegisterForDrag",
        "SetClampedToScreen","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetColorTexture",
        "SetAutoFocus","SetNumeric","SetMaxLetters","SetEnabled","SetVerticalScroll",
        "StartMoving","StopMovingOrSizing","SetScrollChild","SetTexture","SetVertexColor","ClearAllPoints",
        "SetScale","SetOrientation","SetValueStep","SetMinMaxValues","SetThumbTexture","SetValue","SetObeyStepOnDrag","RegisterEvent"}) do o[m] = function() end end
    function o:GetStringHeight() return 15 end
    function o:SetText(v) self.text = v end
    function o:GetText() return self.text end
    function o:ClearFocus() self.focus = false end
    function o:SetScript(k, fn) self.scripts[k] = fn end
    function o:HookScript(k, fn) self.scripts["hook:"..k] = fn end
    function o:CreateFontString() return Element("FontString") end
    function o:CreateTexture() return Element("Texture") end
    function o:Hide() self.visible = false end
    function o:Show() self.visible = true end
    function o:IsShown() return self.visible end
    setmetatable(o, {__index = function(_, k) if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end end})
    table.insert(elements, o)
    return o
end
CreateFrame = function(kind, name)
    local obj = Element(kind)
    obj.name = name
    return obj
end
UIParent = Element("UIParent")
UISpecialFrames = {}

local ONE = {
    version = "0.2.8-alpha",
    db = { remindersEnabled = true, toastEnabled = true, soundEnabled = true,
        loginSummaryEnabled = true, guild = {noticeHistory = {}} , modules = {} },
    moduleOrder = {}, modules = {},
    IsEnabled = function() return true end,
    Notifications = {SettingsChanged = function() end},
    Themes = {RegisterWindow = function() end, RegisterPanel = function() end,
        RegisterRule = function() end,
        StyleTree = function() end, StyleButton = function() end,
        ApplyButton = function() end, PlaySound = function() end},
    Notify = function() end,
}
ONE.Print = ONE.Print or function(_, m) ONE.printed = (ONE.printed or "") .. tostring(m) .. "\n" end
_G.ProjectONE = ONE
assert(loadfile(path .. "/src/ONE_Core/Widgets.lua"))("ONE_Core", ONE)
assert(loadfile(path .. "/src/ONE_Core/Geometry.lua"))("ONE_Core", ONE)
assert(loadfile(path .. "/src/ONE_Core/WindowScale.lua"))("ONE_Core", ONE)
assert(loadfile(path .. "/src/ONE_Core/Kit.lua"))("ONE_Core", ONE)
assert(loadfile(path .. "/src/ONE_Core/UI.lua"))("ONE_Core", ONE)
ONE.UI.BuildThemeView = function() return function() end end
ONE.UI:Initialize()
assert(ONE.UI.tabs.options and ONE.UI.activeTab == "home")

local guild = {
    Calendar = { events = {}, GetCurrentTime = function() return {year=2026,month=10,monthDay=27} end },
    Guild = {GetInfo = function() return {name="Testgilde", rank="Mitglied", members=1} end},
}
assert(loadfile(path .. "/src/ONE_Guild/Reminders.lua"))("ONE_Guild", guild)
assert(loadfile(path .. "/src/ONE_Guild/UI.lua"))("ONE_Guild", guild)
guild.UI:RegisterTabs()
assert(ONE.UI.views["guild-reminder-settings"])
-- 0.4.9: zweiter Link "Module verwalten" kommt aus dem Core
assert(#ONE.UI.optionsLinks == 4) -- Module, Teilen, Spielhilfen, Erinnerungszeiten
-- 0.6.1: Optionen -> Teilen sammelt alle Teilen-Schalter
assert(ONE.UI.views.sharing, "Seite Teilen fehlt")
local hasPosition = false
for _, o in ipairs(ONE.UI.shareOptions) do if o.id == "position" then hasPosition = true end end
assert(hasPosition, "Schalter Position fehlt unter Teilen")
local hasReminder = false
for _, link in ipairs(ONE.UI.optionsLinks) do if link.title == "Erinnerungszeiten einstellen" then hasReminder = true end end
assert(hasReminder)

local function ButtonByLabel(label)
    for _, element in ipairs(elements) do
        if element.kind == "Button" and element.text == label then return element end
    end
    error("Schaltfläche nicht gefunden: " .. label)
end
local function Click(label)
    local button = ButtonByLabel(label)
    assert(button.scripts.OnClick, label .. " ohne Klickfunktion")
    button.scripts.OnClick(button)
end
ONE.UI:Navigate("options")
-- 0.6.8: mit Symbolleiste steht die Unterseite oben als Ansicht "Erinnerungen"
Click(ONE.UI.sidebar and "Erinnerungen" or "Erinnerungszeiten einstellen")
assert(ONE.UI.activeTab == "guild-reminder-settings")
local R = guild.Reminders
Click("30 Min.")
local found = false
for _, v in ipairs(R:GetThresholds()) do if v == 30 then found = true end end
assert(found, "30 Min. Schnellwahl fehlt")
Click("30 Minuten vorher   |   Entfernen")
found = false
for _, v in ipairs(R:GetThresholds()) do if v == 30 then found = true end end
assert(not found, "Entfernen funktioniert nicht")
local field
for _, element in ipairs(elements) do
    if element.kind == "EditBox" then field = element end
end
assert(field and field.scripts.OnEnterPressed)
field:SetText("45")
field.scripts.OnEnterPressed()
found = false
for _, v in ipairs(R:GetThresholds()) do if v == 45 then found = true end end
assert(found, "Eigener Minutenwert nicht gespeichert")
Click("Standard wiederherstellen")
assert(#R:GetThresholds() == 4)
assert(R:GetThresholds()[1] == 60)
assert(ONE.UI:CanGoBack())
assert(ONE.UI:GoBack())
assert(ONE.UI.activeTab == "options")
print("OK: UI-Links, Eingabe, Schnellauswahl, Entfernen, Standard, Zurück-Navigation")
