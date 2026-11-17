-- Offline-Test 0.7.0: Dungeon-Rueckblick.
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
local now = 1000
GetTime = function() return now end
LOOT_ITEM = "%s erhält Beute: %s."
LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s."
local inside = true
IsInInstance = function() return inside, inside and "party" or "none" end
GetInstanceInfo = function() return "Die Todesminen" end
IsInRaid = function() return false end
local units = {player = "Ich", party1 = "Bob-Realm", party2 = "Gildi"}
local deadNow = {}
UnitExists = function(u) return units[u] ~= nil end
UnitName = function(u) return units[u] end
UnitIsDeadOrGhost = function(u) return deadNow[u] end
IsInGuild = function() return true end
local posted
SendChatMessage = function(msg, ch) posted = {msg = msg, ch = ch} end

local ONE = {db = {}}
_G.ProjectONE = ONE
local d = {}
local stamps = {d = {DM = {runs = 1}}}
d.Passport = {Mine = function() return stamps end}
d.Entrances = {Match = function(name) if name == "Die Todesminen" then return {{key = "DM"}} end return {} end}
assert(loadfile(root .. "/ONE_Dungeons/Recap.lua"))("ONE_Dungeons", d)
local R = d.Recap

local GREEN = "|cff1eff00|Hitem:1::|h[Grüner Stab]|h|r"
local BLUE = "|cff0070dd|Hitem:2::|h[Blauer Ring]|h|r"
local GREY = "|cff9d9d9d|Hitem:3::|h[Schrott]|h|r"

-- 1) Beute-Zeilen lesen
local who, link = R.ParseLoot("Bob-Realm erhält Beute: " .. GREEN .. ".")
assert(who == "Bob" and link == GREEN)
assert(R.ParseLoot("Ihr erhaltet Beute: " .. BLUE .. ".") == "Ich")
assert(R.ParseLoot("Bedarf-Wurf: 54 für " .. GREEN .. " von Bob") == nil)

-- 2) Ein Lauf: rein, Tode, Bosse, Beute, raus
deadNow.party2 = true -- tot reingekommen: zaehlt nicht
R:OnEnteringWorld()
assert(R.run and R.run.key == "DM")
deadNow.party2 = nil
R:CheckDeaths()
deadNow.party1 = true R:CheckDeaths() R:CheckDeaths() -- einmal tot = 1
deadNow.party1 = nil R:CheckDeaths()
deadNow.party1 = true R:CheckDeaths()                 -- nochmal = 2
deadNow.party1 = nil deadNow.player = true R:CheckDeaths()
deadNow.player = nil
R:OnBoss("Rhahk'Zor", true) R:OnBoss("Edwin VanCleef", true) R:OnBoss("Fehlversuch", false)
R:OnLoot("Bob-Realm erhält Beute: " .. GREEN .. ".")
R:OnLoot("Ihr erhaltet Beute: " .. BLUE .. ".")
R:OnLoot("Gildi erhält Beute: " .. GREY .. ".")
-- Neu laden im Dungeon: Lauf geht weiter
now = now + 100
R:OnEnteringWorld()
assert(#R.run.loot == 2 and R.run.deaths.Bob == 2 and R.run.deaths.Ich == 1 and R.run.deaths.Gildi == nil)
now = now + 2400 -- 41,7 Minuten
inside = false
local run = R:Finish() or R.last
R.run = nil
assert(run and run.secs == 2500)
local f = R.frame
assert(f.shown and f.title.text == "Die Todesminen – 42 Min.", f.title.text)
assert(f.body.text:find("Gruppe: Bob, Gildi, Ich", 1, true), f.body.text)
assert(f.body.text:find("Bosse: 2 (Rhahk'Zor, Edwin VanCleef)", 1, true))
assert(f.body.text:find("Tode: 3 (Bob 2, Ich 1)", 1, true))
assert(f.body.text:find(GREEN .. " → Bob", 1, true) and f.body.text:find(BLUE .. " → Ich", 1, true) and not f.body.text:find("Schrott"))
-- Erste Zeit = Bestzeit im Pass (aber "neue Bestzeit" erst, wenn es eine alte gab)
assert(stamps.d.DM.best == 2500 and not run.record)
-- 3) Gildenchat
f.post.scripts.OnClick()
assert(posted.ch == "GUILD" and posted.msg == "Guild Trip: Die Todesminen in 42 Min. – 2 Bosse, 3 Tode – Beute: " .. GREEN .. " " .. BLUE, posted.msg)
assert(not f.shown)

-- 4) Schneller: neue Bestzeit; zu kurz: kein Rueckblick
inside = true
R:OnEnteringWorld()
now = now + 1800
inside = false
R:OnEnteringWorld()
assert(R.last.record and stamps.d.DM.best == 1800 and f.title.text:find("neue Bestzeit", 1, true))
assert(R:ChatLine(R.last) == "Guild Trip: Die Todesminen in 30 Min. – 0 Bosse, 0 Tode (neue Bestzeit!)", R:ChatLine(R.last))
assert(f.body.text:find("Tode: keine – sauber!", 1, true))
f:Hide()
inside = true
R:OnEnteringWorld()
now = now + 120
inside = false
R:OnEnteringWorld()
assert(not f.shown and R.run == nil, "zu kurz")
-- 5) Abgeschaltet: Bestzeit ja, Karte nein
ONE.FeatureOn = function(_, id) return id ~= "dungeons.recap" end
inside = true R:OnEnteringWorld()
now = now + 600
inside = false R:OnEnteringWorld()
assert(not f.shown)
-- 6) Direkt von einem Dungeon in den naechsten: der erste Lauf wird abgeschlossen
ONE.FeatureOn = nil
GetInstanceInfo = function() return "Die Todesminen" end
inside = true R:OnEnteringWorld()
now = now + 900
d.Entrances.Match = function(name) return {{key = name == "Die Todesminen" and "DM" or "SFK"}} end
GetInstanceInfo = function() return "Burg Schattenfang" end
R:OnEnteringWorld()
assert(R.last and R.last.key == "DM" and R.last.secs == 900 and R.run.key == "SFK", "erster Lauf abgeschlossen")
print("OK test_recap_108")
