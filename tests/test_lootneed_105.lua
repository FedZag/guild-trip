-- Offline-Test 0.7.0: Wer braucht die Beute?
local root = arg[1] or "src"
local function Region(kind, parent)
    local r = {kind = kind, parent = parent, shown = true, scripts = {}}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetText(t) self.text = t end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    return r
end
CreateFrame = function(kind, _, parent) return Region(kind, parent) end
UIParent = Region("Frame")
local now = 100
GetTime = function() return now end
UnitName = function() return "Ich" end
local inGroup = true
IsInGroup = function() return inGroup end
IsInRaid = function() return false end
local sent = {}
C_ChatInfo = {SendAddonMessage = function(prefix, msg, ch) sent[#sent + 1] = {prefix = prefix, msg = msg, ch = ch} end,
    RegisterAddonMessagePrefix = function() return true end}
GetItemInfo = function(id) return "Teil " .. id end

local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
local upgrade = {[10] = 12, [11] = 0, [12] = 100}
c.Gear = {UpgradePercent = function(_, id) return upgrade[id] end}
assert(loadfile(root .. "/ONE_Classes/LootNeed.lua"))("ONE_Classes", c)
local L = c.LootNeed
L.Changed = function(self) self:Refresh() end -- ohne Verzoegerung

-- 1) Wuerfeln: jeder bewertet selbst; Upgrade -> an die Gruppe melden
L:Seen("|cff1eff00|Hitem:10::|h[Stab]|h|r", false)
assert(#sent == 1 and sent[1].msg == "U|10|12" and sent[1].ch == "PARTY", sent[1] and sent[1].msg)
assert(L:WhoText(10) == "Ich (+12 %)")
assert(L.frame.shown and L.frame.lines[1].text:find("[Stab]", 1, true), "Fenster mit Gegenstand")
-- 2) Andere melden sich
L:Receive("ONELOOT1", "U|10|30", "PARTY", "Bob-Realm")
L:Receive("ONELOOT1", "U|10|5", "PARTY", "Gildi")
assert(L:WhoText(10) == "Bob (+30 %), Ich (+12 %), Gildi (+5 %)", L:WhoText(10))
assert(L:TooltipLine(10) == "|cff40ff40Guild Trip: Upgrade für Bob (+30 %), Ich (+12 %), Gildi (+5 %)|r")
-- 3) Kein Upgrade fuer mich: nichts senden; Platz frei
sent = {}
L:Seen("item:11", false)
assert(#sent == 0 and L:TooltipLine(11) == nil)
L:Seen("item:12", false)
assert(sent[1].msg == "U|12|100" and L:WhoText(12) == "Ich (Platz frei)")
-- 4) Beutefenster: Pluenderer fragt die Gruppe; Antwort auf Frage
sent = {}
upgrade[13] = 7
L:Seen("item:13", true)
assert(sent[1].msg == "A|13" and sent[2].msg == "U|13|7")
sent = {}
L.answered = {}
L:Receive("ONELOOT1", "A|10", "PARTY", "Bob")
assert(sent[1].msg == "U|10|12", "auf Frage antworten")
-- 5) Kaputte / eigene Nachrichten ignorieren
L:Receive("ONELOOT1", "U|10|9999", "PARTY", "Boese")
L:Receive("ONELOOT1", "Quatsch", "PARTY", "Boese")
L:Receive("ONELOOT1", "U|10|50", "PARTY", "Ich")
assert(not L:WhoText(10):find("Boese") and L.needs[10].who.Ich == 12)
-- 6) Fenster geht nach 45 s zu, Tooltip-Wissen bleibt 5 Minuten
now = now + 60
L:Refresh()
assert(not L.frame.shown and L:TooltipLine(10) ~= nil)
now = now + 300
assert(L:TooltipLine(10) == nil)
-- 7) Ohne Gruppe: nichts
inGroup = false
sent = {}
L.answered = {}
L:Seen("item:10", false)
assert(#sent == 0)
-- 8) Abgeschaltet
inGroup = true
ONE.FeatureOn = function(_, id) return id ~= "classes.lootNeed" end
L:Seen("item:10", false)
assert(#sent == 0 and L:TooltipLine(10) == nil)
print("OK test_lootneed_105")
