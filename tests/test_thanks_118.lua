-- Offline-Test 0.7.2: Danke fuer Buffs mit WoW-eigenen Emotes (Nutzer 19.11.2026: automatisch, oeffentlich)
local root = arg[1] or "src"
local clock = 100
GetTime = function() return clock end
UnitGUID = function(u) return u == "player" and "Player-1-AAA" or nil end
local inParty = {}
UnitInParty = function(n) return inParty[n] end
UnitInRaid = function() return nil end
local combat = false
InCombatLockdown = function() return combat end
local timers = {}
C_Timer = {After = function(s, fn) timers[#timers + 1] = {at = clock + s, fn = fn} end}
local function Run()
    local i = 1
    while i <= #timers do
        local t = timers[i]
        if t.at <= clock then table.remove(timers, i) t.fn() else i = i + 1 end
    end
end
local emotes, chat = {}, 0
C_ChatInfo = {PerformEmote = function(token, target) emotes[#emotes + 1] = {token, target} return true end}
local oldUsed = false
DoEmote = function() oldUsed = true end
SendChatMessage = function() chat = chat + 1 end
local handler
local units = {}   -- sourceUnit -> {guid, name}
UnitGUID = function(u) if u == "player" then return "Player-1-AAA" end return units[u] and units[u][1] end
UnitName = function(u) return units[u] and units[u][2] end
local secret = {}
issecretvalue = function(v) return secret[v] == true end
CreateFrame = function() return {RegisterEvent = function() end, RegisterUnitEvent = function() end, SetScript = function(_, _, fn) handler = fn end} end
local ONE = {}
function ONE:FeatureOn(id) return not (self.off and self.off[id]) end
_G.ProjectONE = ONE
local classes = {}
assert(loadfile(root .. "/ONE_Classes/Thanks.lua"))("ONE_Classes", classes)
local Th = classes.Thanks
Th:Initialize()
Th.ready = true   -- Schutzpause nach dem Einloggen ueberspringen (C_Timer im Test)
-- neuer Buff auf mir (UNIT_AURA, wie Forever es meldet); target ~= Spieler: geht mich nichts an
local n = 0
local function Buff(src, guid, sub, target, aura)
    n = n + 1
    local unit = "nameplate" .. n
    units[unit] = {guid or ("Player-1-" .. src), src}
    handler(nil, "UNIT_AURA", target and "party1" or "player",
        {isFullUpdate = false, addedAuras = {{sourceUnit = unit, isHelpful = aura ~= "DEBUFF", spellId = 1459, auraInstanceID = n}}})
end
local known = {THANK = true, BOW = true, CHEER = true, WAVE = true}

-- 1) Zwei Buffs derselben Person kurz hintereinander = ein Emote an sie (ohne Realm)
Buff("Bodra-Realm")
Buff("Bodra-Realm", nil, "SPELL_AURA_REFRESH")
assert(#emotes == 0, "erst sammeln")
clock = clock + 5 Run()
assert(#emotes == 1 and emotes[1][2] == "Bodra" and known[emotes[1][1]], "ein WoW-Emote an Bodra")
assert(chat == 0 and not oldUsed, "nie eigener Text, nie das gesperrte DoEmote")
-- 2) Gleiche Person gleich wieder: nichts (15 min Pause)
Buff("Bodra-Realm")
clock = clock + 5 Run()
assert(#emotes == 1, "nicht nochmal so bald")
-- 3) Gruppe, eigene Buffs, NPCs, Schwaechungen, Buffs auf andere: nichts
inParty["Gruppi"] = true
Buff("Gruppi")
Buff("Ich", "Player-1-AAA")
Buff("Wache", "Creature-0-1")
Buff("Fremd", nil, nil, nil, "DEBUFF")
Buff("Fremd", nil, nil, "Player-1-ANDERER")
clock = clock + 30 Run()
assert(#emotes == 1, "keiner davon")
-- 4) Im Kampf: Forever verbirgt dann Auren -> der Buff wird ausgelassen, nicht nachgeholt
combat = true
Buff("Kira")
clock = clock + 5 Run()
combat = false
handler(nil, "PLAYER_REGEN_ENABLED")
assert(#emotes == 1, "im Kampf: kein Danke")
-- 5) Zwei Fremde kurz nacheinander: zweites mit Abstand (kein Spam)
Buff("Anna")
clock = clock + 5 Run()
assert(#emotes == 2 and emotes[2][2] == "Anna")
-- 6) Zu spaet nach dem Kampf: verfaellt
combat = true
Buff("Spaet")
clock = clock + 5 Run()
clock = clock + 120
combat = false
handler(nil, "PLAYER_REGEN_ENABLED")
assert(#emotes == 2, "nach langem Kampf kein verspaetetes Danke")
-- 7) Abgeschaltet: nichts
ONE.off = {["classes.thanks"] = true}
Buff("Bert")
clock = clock + 30 Run()
assert(#emotes == 2, "Schalter aus")
-- 7b) im Kampf geheime Werte: nichts anfassen, kein Fehler
combat = false
local unit = "nameplate999"
units[unit] = {"Player-1-Geheim", "Geheim"}
secret["Geheim"] = true
handler(nil, "UNIT_AURA", "player", {isFullUpdate = false, addedAuras = {{sourceUnit = unit, isHelpful = true, spellId = 1, auraInstanceID = 999}}})
ONE.off = nil
clock = clock + 30 Run()
assert(#emotes == 2, "geheimer Name: kein Danke")
-- 7c) volle Aktualisierung (Einloggen/Zonen): kein Danke
handler(nil, "UNIT_AURA", "player", {isFullUpdate = true})
assert(#emotes == 2)
-- 8) nie ohne Namen (sonst ginge das Emote an das aktuelle Ziel)
assert(not Th:Emote(nil) and not Th:Emote(""))
print("OK test_thanks_118")
