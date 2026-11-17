-- Offline-Test: eigene Klaenge (Glocke, Ausflug) – Wahl, Ersatz durch Raid-Warnung, Dateien vorhanden.
local root = arg[1] or "src"
local played, fileWorks = {}, true
PlaySoundFile = function(path, channel) played[#played + 1] = {file = path, channel = channel} return fileWorks end
SOUNDKIT = {RAID_WARNING = 8959}
PlaySound = function(id, channel) played[#played + 1] = {kit = id, channel = channel} return true end
local ONE = {db = {soundEnabled = true}}
function ONE:Print() end
assert(loadfile(root .. "/ONE_Core/Sound.lua"))("ONE_Core", ONE)
local S = ONE.Sound

-- 1) Hinweis -> Glocke, Ausflug -> eigenes Signal, Unbekanntes -> Glocke; immer Kanal Master
assert(S:PlayAlert("notify") and played[1].file:find("Glocke%.ogg$") and played[1].channel == "Master")
assert(S:PlayAlert("trip") and played[2].file:find("Ausflug%.ogg$"))
assert(S:PlayAlert("gibtsnicht") and played[3].file:find("Glocke%.ogg$"))

-- 2) Datei laesst sich nicht spielen -> Raid-Warnung als Ersatz
fileWorks = false
played = {}
assert(S:PlayAlert("notify") and played[2] and played[2].kit == 8959, "Ersatzton")

-- 3) Dateien liegen im Addon (Pfad im Spiel = Interface\AddOns\ONE_Core\Sounds\…)
for _, a in ipairs(S.alerts) do
    local name = a.file:match("([^\\]+)$")
    local f = io.open(root .. "/ONE_Core/Sounds/" .. name, "rb")
    assert(f, "Klangdatei fehlt: " .. name)
    assert(f:read(4) == "OggS", name .. " ist keine OGG-Datei")
    f:close()
    assert(a.file:find("^Interface\\AddOns\\ONE_Core\\Sounds\\"), a.file)
end

-- 4) Benachrichtigung nutzt den gewuenschten Klang, silent bleibt still
fileWorks = true
local function Element()
    local o = {scripts = {}}
    return setmetatable(o, {__index = function(_, k)
        if k == "CreateTexture" or k == "CreateFontString" then return function() return Element() end end
        if k == "SetScript" then return function(self, e, fn) self.scripts[e] = fn end end
        return function() end
    end})
end
CreateFrame = function() return Element() end
UIParent = {}
C_Timer = {After = function() end}
ONE.Themes = setmetatable({}, {__index = function() return function() end end})
ONE.Widgets = {CloseButton = function() end}
assert(loadfile(root .. "/ONE_Core/Notifications.lua"))("ONE_Core", ONE)
ONE.Notifications:Initialize()
played = {}
ONE.Notifications:Push("Ausflug beginnt", {sound = "trip"})
assert(#played == 1 and played[1].file:find("Ausflug%.ogg$"))
ONE.Notifications:Push("Leise", {silent = true})
assert(#played == 1)
ONE.db.soundEnabled = false
ONE.Notifications:Push("Ton aus")
assert(#played == 1)
-- Chat-Klaenge: dezent ueber die Effekt-Lautstaerke (SFX)
played = {}
assert(S:PlayAlert("chatWhisper") and played[1].file:find("ChatWhisper%.ogg$") and played[1].channel == "SFX")
print("OK test_sounds_084")
