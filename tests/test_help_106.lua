-- Offline-Test 0.7.0: Hilferuf an die Gilde.
local root = arg[1] or "src"
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetText(t) self.text = t end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")
local now = 100
GetTime = function() return now end
UnitLevel = function() return 23 end
local inGuild = true
IsInGuild = function() return inGuild end
local sent = {}
C_ChatInfo = {SendAddonMessage = function(_, msg, ch) sent[#sent + 1] = {msg = msg, ch = ch} end,
    RegisterAddonMessagePrefix = function() return true end}
local chat
ChatFrame_OpenChat = function(t) chat = t end
local printed, notes = {}, {}

local ONE = {db = {}, modules = {}}
function ONE:Print(t) printed[#printed + 1] = t end
function ONE:Notify(t) notes[#notes + 1] = t end
_G.ProjectONE = ONE
assert(loadfile(root .. "/ONE_Core/PlayerMenu.lua"))("ONE_Core", ONE) -- ONE:Whisper
local pointed
local dist = 420
ONE.modules.nav = {
    DistanceTo = function() return dist end,
    PointTo = function(_, label, map, x, y) pointed = {label = label, map = map, x = x, y = y} return true end,
}
local myPos = {1411, 4512, 6001}
local guild = {Presence = {
    Location = function() return myPos[1], myPos[2], myPos[3] end,
    IsMe = function(_, s) return s == "Ich" or s == "Ich-Realm" end,
}}
assert(loadfile(root .. "/ONE_Guild/Help.lua"))("ONE_Guild", guild)
local H = guild.Help

-- 1) Rufen: Position + Stufe + Text an die Gilde
assert(H:Slash("  Elite | am Wegkreuz  ") == true)
assert(sent[1].msg == "H|1411|4512|6001|23|Elite   am Wegkreuz" and sent[1].ch == "GUILD", sent[1].msg)
-- 2) Nicht doppelt innerhalb einer Minute
assert(H:Call("") == nil and #sent == 1)
-- 3) Antwort "Ich komme!" kommt an (einmal je Helfer)
H:Receive("ONEHELP1", "HC", "GUILD", "Thrall-Realm")
H:Receive("ONEHELP1", "HC", "GUILD", "Thrall-Realm")
assert(#notes == 1 and notes[1] == "Thrall kommt dir zu Hilfe!")
-- 4) Beenden
assert(H:Slash("aus") == true and sent[2].msg == "HX")
-- 5) Ohne Position (Dungeon) / ohne Gilde: kein Ruf
now = now + 100
myPos = {}
assert(select(2, H:Call("")) == "position")
inGuild = false
assert(select(2, H:Call("")) == "guild")
inGuild = true

-- 6) Empfangen: Fenster mit Text, "Ich komme!" -> Navi + HC
sent = {}
H:Receive("ONEHELP1", "H|1411|5000|2500|19|Hilfe, Leiche weit weg", "GUILD", "Bob-Realm")
assert(H.frame.shown and H.frame.text.text == "Bob (19) braucht Hilfe – 420 m entfernt.\n|cffffffff„Hilfe, Leiche weit weg“|r", H.frame.text.text)
assert(#notes == 2)
H.frame.go.scripts.OnClick()
assert(pointed.label == "Hilferuf: Bob" and pointed.map == 1411 and pointed.x == .5 and pointed.y == .25)
assert(sent[1].msg == "HC" and not H.frame.shown)
-- 7) Flüstern
H:Receive("ONEHELP1", "H|1411|5000|2500|19|", "GUILD", "Bob-Realm")
assert(H.frame.text.text == "Bob (19) braucht Hilfe – 420 m entfernt.")
H.frame.whisper.scripts.OnClick()
assert(chat == "/w Bob-Realm ")
-- 8) Rufer meldet "erledigt": Fenster zu
H:Receive("ONEHELP1", "H|1411|5000|2500|19|", "GUILD", "Bob-Realm")
H:Receive("ONEHELP1", "HX", "GUILD", "Bob-Realm")
assert(not H.frame.shown and H.calls.Bob == nil)
-- 9) Anderer Kontinent / eigener Ruf / kaputt / abgeschaltet: nichts
dist = nil
H:Receive("ONEHELP1", "H|1411|5000|2500|19|x", "GUILD", "Fern")
assert(not H.frame.shown)
dist = 100
H:Receive("ONEHELP1", "H|1411|5000|2500|19|x", "GUILD", "Ich-Realm")
H:Receive("ONEHELP1", "H|1411|99999|2500|19|x", "GUILD", "Boese")
H:Receive("ONEHELP1", "H|1411|5000|2500|19|x", "WHISPER", "Boese")
assert(not H.frame.shown)
ONE.FeatureOn = function(_, id) return id ~= "guild.help" end
H:Receive("ONEHELP1", "H|1411|5000|2500|19|x", "GUILD", "Bob")
assert(not H.frame.shown)
-- 10) Taste
assert(type(_G.GuildTripHelp_Call) == "function" and _G.BINDING_NAME_GUILDTRIPHELP_CALL == "Hilferuf an die Gilde")
print("OK test_help_106")
