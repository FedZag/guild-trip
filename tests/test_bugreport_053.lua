-- Offline-Test 0.5.3: /trip bug – Fehler sammeln, Bericht bauen, Fenster oeffnen.
local root = arg[1] or "src"
local function Region(kind, parent, name, template)
    local r = {kind = kind, parent = parent, name = name, template = template, scripts = {}}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:HighlightText() self.highlighted = true end
    function r:CreateFontString() return Region("FontString", self) end
    function r:CreateTexture() return Region("Texture", self) end
    return r
end
CreateFrame = function(kind, name, parent, template) return Region(kind, parent, name, template) end
UIParent = Region("Frame")
UISpecialFrames = {}
GetBuildInfo = function() return "1.60.1", "12345" end
GetLocale = function() return "deDE" end
local handler
function seterrorhandler(fn) handler = fn end
function geterrorhandler() return handler end
local passedOn = 0
seterrorhandler(function() passedOn = passedOn + 1 end)

local ONE = {version = "test", modules = {}, moduleOrder = {}}
local printed = {}
function ONE:Print(m) printed[#printed + 1] = m end
function ONE:IsEnabled(id) return self.db.modules[id] ~= false end
assert(loadfile(root .. "/ONE_Core/BugReport.lua"))("ONE_Core", ONE)
local B = ONE.BugReport

-- 1) Fehler vor dem Laden der Einstellungen landen zuerst in "pending"
B:Record("lua", "Interface/AddOns/ONE_Guild/UI.lua:10: frueh")
ONE.db = {modules = {nav = false}}
B:Attach()
assert(#ONE.db.bugLog == 1 and ONE.db.bugLog[1].msg:find("frueh"), "frueher Fehler uebernommen")

-- 2) Fehlerbehandlung: nur eigene Fehler, Blizzards Behandlung laeuft weiter
geterrorhandler()("Interface/AddOns/ONE_Nav/Arrow.lua:5: kaputt")
geterrorhandler()("Interface/AddOns/OtherAddon/x.lua:1: fremd")
assert(passedOn == 2, "vorherige Fehlerbehandlung weiter aufgerufen")
assert(#ONE.db.bugLog == 2 and ONE.db.bugLog[1].msg:find("kaputt"), "eigener Fehler vorn")
geterrorhandler()("Interface/AddOns/ONE_Nav/Arrow.lua:5: kaputt")
assert(#ONE.db.bugLog == 2 and ONE.db.bugLog[1].count == 2, "gleiche Fehler zusammengefasst")

-- 3) Begrenzung
for i = 1, 20 do B:Record("lua", "ONE_Core/x.lua:" .. i .. ": viele") end
assert(#ONE.db.bugLog == B.maxEntries, "hoechstens maxEntries")
assert(#B:Record("lua", "ONE_Core/" .. string.rep("a", 2000)).msg < 700, "lange Meldung gekuerzt")

-- 4) Bericht
ONE.modules = {guild = {}, nav = {}, crafting = {error = "boom"}}
ONE.moduleOrder = {"guild", "nav", "crafting"}
local text = B:Build()
assert(text:find("Guild Trip test", 1, true) and text:find("1.60.1 (12345)", 1, true) and text:find("deDE", 1, true))
assert(text:find("guild=on, nav=paused, crafting=ERROR", 1, true), "Modulstatus")
assert(text:find("Start error crafting: boom", 1, true), "Startfehler")
B:Clear()
assert(B:Build():find("none recorded", 1, true), "leere Liste")

-- 5) Fenster und Befehl
B:Slash("")
assert(B.frame and B.frame.shown and B.frame.edit.text == B.text and B.frame.edit.highlighted, "Fenster offen, Text markiert")
assert(UISpecialFrames[1] == "GuildTripBugReport", "Esc schliesst")
B.frame.edit.scripts.OnTextChanged(B.frame.edit, true)
assert(B.frame.edit.text == B.text, "Tippen veraendert den Bericht nicht")
B:Record("lua", "ONE_Core/y.lua:1: neu")
B:Slash("leeren")
assert(#ONE.db.bugLog == 0 and printed[#printed]:find("geleert"), "leeren")
-- Speicher je Teil (fuer Bericht und /trip speicher)
local mem = {ONE_Core = 2048, ONE_Leveling = 512}
UpdateAddOnMemoryUsage = function() end
GetAddOnMemoryUsage = function(n) return mem[n] or 0 end
local line = B.MemoryLine()
assert(line == "Memory: 2.5 MB (Core 2.0, Leveling 0.5)", line)
assert(B:Build():find("Memory: 2.5 MB", 1, true), "im Bericht")
print("OK test_bugreport_053")
