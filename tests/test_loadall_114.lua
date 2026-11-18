-- Offline-Test 0.7.0: Alle Addons wie im Spiel laden (Reihenfolge laut TOC), Kern starten, alle Module
-- initialisieren und die angemeldeten Ereignisse einmal ausloesen. Faengt Fehler, die nur im
-- Zusammenspiel auffallen (Datei braucht etwas zu frueh, Tippfehler in selten benutzten Wegen).
-- Dazu: kein Modul darf einen /trip-Befehl belegen, den der Kern schon selbst auswertet.
local root = arg[1] or "src"

-- ===== Nachgebaute Spielumgebung (grosszuegig: unbekannte Methoden tun nichts) =====
local frames, tickers = {}, {}
local function Stub(kind, name)
    local f = {kind = kind, name = name, scripts = {}, events = {}, attr = {}, shown = true, w = 100, h = 20}
    setmetatable(f, {__index = function(_, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        if k:match("^Get") then return function() return nil end end
        if k:match("^Is") or k:match("^Has") or k:match("^Can") then return function() return false end end
        return function() end
    end})
    function f:SetScript(e, fn) self.scripts[e] = fn end
    function f:GetScript(e) return self.scripts[e] end
    function f:HookScript(e, fn) self.scripts[e] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:IsEventRegistered(e) return self.events[e] == true end
    function f:CreateTexture() return Stub("Texture") end
    function f:CreateFontString() return Stub("FontString") end
    function f:CreateAnimationGroup() return Stub("AnimationGroup") end
    function f:SetAttribute(k, v) self.attr[k] = v end
    function f:GetAttribute(k) return self.attr[k] end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:SetWidth(w) self.w = w end
    function f:SetHeight(h) self.h = h end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:GetSize() return self.w, self.h end
    function f:GetScale() return 1 end
    function f:GetEffectiveScale() return 1 end
    function f:GetFrameLevel() return 1 end
    function f:GetAlpha() return 1 end
    function f:GetText() return self.text or "" end
    function f:SetText(t) self.text = t end
    function f:GetStringWidth() return 50 end
    function f:GetStringHeight() return 12 end
    function f:GetNumPoints() return 0 end
    function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    function f:GetCenter() return 0, 0 end
    function f:GetLeft() return 0 end
    function f:GetTop() return 0 end
    function f:GetRight() return 100 end
    function f:GetBottom() return 0 end
    function f:GetParent() return UIParent end
    function f:GetName() return self.name end
    function f:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
    function f:GetTextColor() return 1, 1, 1, 1 end
    function f:GetChildren() return end
    function f:GetRegions() return end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetObjectType() return kind end
    function f:GetVerticalScroll() return 0 end
    function f:GetVerticalScrollRange() return 0 end
    function f:GetValue() return 0 end
    function f:GetMinMaxValues() return 0, 1 end
    function f:GetChecked() return false end
    function f:GetFrameStrata() return "MEDIUM" end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = function(kind, name) return Stub(kind, name) end
UIParent = Stub("Frame", "UIParent")
WorldFrame = Stub("Frame", "WorldFrame")
Minimap = Stub("Frame", "Minimap")
GameTooltip = Stub("GameTooltip", "GameTooltip")
ItemRefTooltip = Stub("GameTooltip", "ItemRefTooltip")
WorldMapFrame = Stub("Frame", "WorldMapFrame")
WorldMapFrame.ScrollContainer = Stub("Frame")
WorldMapFrame.ScrollContainer.Child = Stub("Frame")
ChatFrame1 = Stub("Frame", "ChatFrame1")
DEFAULT_CHAT_FRAME = {AddMessage = function() end}
SlashCmdList = {}
UISpecialFrames = {}
RAID_CLASS_COLORS = setmetatable({}, {__index = function() return {r = 1, g = 1, b = 1, colorStr = "ffffffff"} end})
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
C_Timer = {After = function() end, NewTicker = function(sec, fn) tickers[#tickers + 1] = fn return {Cancel = function() end} end,
    NewTimer = function() return {Cancel = function() end} end}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end, SendAddonMessage = function() return true end}
GetLocale = function() return "deDE" end
GetTime = function() return 1000 end
GetServerTime = function() return 1800000000 end
time, date = os.time, os.date
UnitName = function() return "Tester" end
UnitFullName = function() return "Tester", "Realm" end
UnitClass = function() return "Priester", "PRIEST" end
UnitRace = function() return "Mensch", "Human" end
UnitLevel = function() return 20 end
UnitFactionGroup = function() return "Alliance" end
UnitXP = function() return 100 end
UnitXPMax = function() return 5000 end
UnitGUID = function() return "Player-1-0001" end
IsInGuild = function() return false end
IsInGroup = function() return false end
IsInRaid = function() return false end
InCombatLockdown = function() return false end
GetRealmName = function() return "Realm" end
issecretvalue = function() return false end
hooksecurefunc = function() end
PlaySound = function() end
SOUNDKIT = {}
Enum = setmetatable({}, {__index = function() return {} end})

-- ===== Addons in TOC-Reihenfolge laden =====
local ADDONS = {"ONE_Core", "ONE_QuestDB", "ONE_Routes", "ONE_Guild", "ONE_Nav", "ONE_Dungeons", "ONE_Crafting", "ONE_Classes", "ONE_Leveling", "ONE_Chat"}
local loaded = 0
for _, addon in ipairs(ADDONS) do
    local toc = assert(io.open(root .. "/" .. addon .. "/" .. addon .. ".toc")):read("*a")
    local ns = {}
    for name in toc:gmatch("\n([%w_/]+%.lua)") do
        local chunk = assert(loadfile(root .. "/" .. addon .. "/" .. name))
        local ok, err = pcall(chunk, addon, ns)
        assert(ok, addon .. "/" .. name .. ": " .. tostring(err))
        loaded = loaded + 1
    end
end
local ONE = _G.ProjectONE
assert(ONE and ONE.version == "0.7.0-alpha", "Kern geladen")

-- ===== Kern starten (ADDON_LOADED) =====
local errors = {}
ONE.Print = function() end
local recordOriginal = ONE.BugReport and ONE.BugReport.Record
if ONE.BugReport then ONE.BugReport.Record = function(_, where, err) errors[#errors + 1] = where .. ": " .. tostring(err) end end
for _, f in ipairs(frames) do
    if f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "ONE_Core") end
end
assert(ONE.started, "Kern gestartet")
for id, def in pairs(ONE.modules) do
    assert(not def.error, "Modul " .. id .. ": " .. tostring(def.error))
    assert(def.initialized or def.skipped, "Modul " .. id .. " nicht gestartet")
end
assert(#errors == 0, table.concat(errors, "\n"))

-- ===== Jedes angemeldete Ereignis einmal ausloesen (ohne Argumente) =====
local fired = 0
for _, f in ipairs(frames) do
    if f.scripts.OnEvent then
        for e in pairs(f.events) do
            if e ~= "ADDON_LOADED" then
                local ok, err = pcall(f.scripts.OnEvent, f, e)
                assert(ok, "Ereignis " .. e .. ": " .. tostring(err))
                fired = fired + 1
            end
        end
    end
end
-- Takte einmal laufen lassen
for _, fn in ipairs(tickers) do
    local ok, err = pcall(fn)
    assert(ok, "Takt: " .. tostring(err))
end

-- ===== /trip-Befehle: keine Doppelbelegung mit dem Kern =====
local core = {heute = 1, today = 1, modules = 1, module = 1, guild = 1, gilde = 1, map = 1, karte = 1, minimap = 1,
    klang = 1, sound = 1, bug = 1, fehler = 1, help = 1, hilfe = 1}
for name in pairs(ONE.slashCommands) do assert(not core[name], "/trip " .. name .. " ist im Kern schon belegt") end
assert(ONE.slashCommands.sos, "Hilferuf-Befehl da")
-- Alle Funktionen haben ein Modul, das es gibt
for id, def in pairs(ONE.features) do
    if def.module then assert(ONE.modules[def.module], "Funktion " .. id .. ": Modul " .. def.module .. " fehlt") end
end
if recordOriginal then ONE.BugReport.Record = recordOriginal end
print(("OK test_loadall_114 (%d Dateien, %d Module, %d Ereignisse, %d Takte)"):format(loaded, #ONE.moduleOrder, fired, #tickers))
