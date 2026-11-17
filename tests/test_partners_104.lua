-- Offline-Test 0.7.0: Questpartner in der Naehe.
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
local combat = false
InCombatLockdown = function() return combat end
local group = {}
UnitInParty = function(n) return group[n] end
local invited, chat
C_PartyInfo = {InviteUnit = function(n) invited = n end}
ChatFrame_OpenChat = function(t) chat = t end
local notes = {}

local ONE = {db = {}, modules = {}}
function ONE:Notify(msg) notes[#notes + 1] = msg end
_G.ProjectONE = ONE
local nav = {}
-- Mein Questlog
local log = {
    {id = 1, title = "Wolfsjagd", complete = false},
    {id = 2, title = "Kräuter", complete = false},
    {id = 3, title = "Fertig", complete = true},
}
nav.Quests = {Log = function() return log end}
-- Gilde: Quest-Stand (QuestShare) und Positionen
local peers = {
    {name = "Thrall", level = 23, class = "SHAMAN", quests = {[1] = {done = false}, [2] = {done = false}, [3] = {done = false}}},
    {name = "Rehgar", level = 20, class = "WARRIOR", quests = {[1] = {done = true}}},   -- fertig: kein Partner
    {name = "Fern", level = 22, class = "MAGE", quests = {[1] = {done = false}}},        -- zu weit weg
    {name = "Stumm", level = 22, class = "MAGE", quests = {[2] = {done = false}}},       -- keine Position
}
nav.QuestShare = {Peers = function() return peers end}
local dist = {Thrall = 250, Rehgar = 50, Fern = 900}
local started
ONE.modules.guild = {LivePeers = function()
    return {{name = "Thrall-Realm", mapID = 1, x = .1, y = .1}, {name = "Rehgar-Realm", mapID = 1, x = .2, y = .2},
        {name = "Fern-Realm", mapID = 1, x = .3, y = .3}}
end}
ONE.modules.nav = {
    DistanceTo = function(_, _, x) return ({[.1] = dist.Thrall, [.2] = dist.Rehgar, [.3] = dist.Fern})[x] end,
    StartTo = function(_, name) started = name end,
}
assert(loadfile(root .. "/ONE_Nav/Partners.lua"))("ONE_Nav", nav)
local P = nav.Partners

-- 1) Nur Thrall: offen auf beiden Seiten, nah genug, mit Position
local list = P:Candidates()
assert(#list == 1 and list[1].name == "Thrall" and #list[1].quests == 2, "nur Thrall")
assert(list[1].quests[1].title == "Kräuter" and list[1].quests[2].title == "Wolfsjagd")

-- 2) Melden: Fenster mit Text, Chatzeile
local c = P:Check()
assert(c and c.name == "Thrall" and P.frame.shown)
assert(P.frame.text.text == "Thrall (23) macht 2 deiner Quests – 250 m entfernt.", P.frame.text.text)
assert(#notes == 1)
-- 3) Knoepfe
P.frame.invite.scripts.OnClick()
assert(invited == "Thrall" and not P.frame.shown)
P:Show(c) P.frame.navi.scripts.OnClick()
assert(started == "Thrall-Realm", "Navi zur Position")
P:Show(c) P.frame.whisper.scripts.OnClick()
assert(chat == "/w Thrall Hey, wir haben 2 gleiche Quests – zusammen machen?", chat)

-- 4) Nicht nochmal melden (Pause), ausser es werden mehr gemeinsame Quests
assert(P:Check() == nil, "Pause")
log[4] = {id = 4, title = "Erz", complete = false}
peers[1].quests[4] = {done = false}
c = P:Check()
assert(c and #c.quests == 3, "mehr gemeinsame Quests")
now = now + 1300
assert(P:Check() and P:Check() == nil, "nach 20 Minuten wieder, dann Pause")

-- 5) Eine gemeinsame Quest: Name im Text
peers[1].quests = {[1] = {done = false}}
P.told = {}
c = P:Check()
assert(P.frame.text.text == "Thrall (23) macht deine Quest „Wolfsjagd“ – 250 m entfernt.", P.frame.text.text)
assert(P:WhisperText(c) == "Hey, wollen wir „Wolfsjagd“ zusammen machen?")

-- 6) Schon in meiner Gruppe / im Kampf / abgeschaltet: nichts
P.told = {}
group.Thrall = true
assert(#P:Candidates() == 0)
group.Thrall = nil
combat = true
assert(P:Check() == nil)
combat = false
ONE.FeatureOn = function(_, id) return id ~= "nav.partners" end
assert(P:Check() == nil)
ONE.FeatureOn = nil
assert(P:Check() ~= nil)
print("OK test_partners_104")
