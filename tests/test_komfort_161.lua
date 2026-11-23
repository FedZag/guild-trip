-- Offline-Test 0.8.0: Neue Komfort-Teile aus der Gesamtpruefung (23.11.2026):
-- Koordinaten, Anfragen (Duell/Einladung/Wiederbelebung/Beschwoerung), Flug-Restzeit, Meine Figuren.
local root = arg[1] or "src"
local function Stub()
    local f = {scripts = {}, events = {}}
    return setmetatable(f, {__index = function(_, k)
        if k == "SetScript" then return function(s, e, fn) s.scripts[e] = fn end end
        if k == "RegisterEvent" then return function(s, e) s.events[e] = true end end
        if k == "CreateTexture" or k == "CreateFontString" then return function() return Stub() end end
        return function() end
    end})
end
CreateFrame = function() return Stub() end
local ONE = {db = {}, features = {}, printed = {}}
ONE.T = function(t, ...) if select("#", ...) > 0 then return t:format(...) end return t end
function ONE:RegisterFeature(id, def) self.features[id] = def end
function ONE:FeatureOn(id)
    local d = self.features[id]
    if d.get then return d.get() end
    return not (self.db.features and self.db.features[id] == false)
end
function ONE:Print(m) self.printed[#self.printed + 1] = m end
function ONE:IsEnabled() return true end
_G.ProjectONE = ONE

-- ===== 1) Koordinaten =====
local nav = {}
assert(loadfile(root .. "/ONE_Nav/Coords.lua"))("ONE_Nav", nav)
local C = nav.Coords
assert(C.Format(.4523, .601) == "45.2, 60.1" and C.Format(0, .5) == nil and C.Format(1, .5) == nil)
local canvas = {GetLeft = function() return 100 end, GetTop = function() return 500 end, GetWidth = function() return 400 end,
    GetHeight = function() return 200 end, GetEffectiveScale = function() return 2 end}
GetCursorPosition = function() return 400, 800 end      -- /2 -> 200, 400: x = (200-100)/400, y = (500-400)/200
local cx, cy = C.Cursor(canvas)
assert(math.abs(cx - .25) < 1e-9 and math.abs(cy - .5) < 1e-9)
GetCursorPosition = function() return 0, 0 end
assert(C.Cursor(canvas) == nil, "ausserhalb der Karte")
assert(C.MapText("1.0, 2.0", "3.0, 4.0") == "Du: 1.0, 2.0  ·  Maus: 3.0, 4.0" and C.MapText(nil, nil) == "")
assert(ONE:FeatureOn("nav.coordsMap") == true and ONE:FeatureOn("nav.coordsMinimap") == false, "Karte an, Minimap aus")

-- ===== 2) Anfragen =====
assert(loadfile(root .. "/ONE_Core/Comfort.lua"))("ONE_Core", ONE)
local K = ONE.Comfort
for _, f in ipairs(K.FEATURES) do assert(ONE:FeatureOn(f[1]) == false, f[1] .. ": Standard aus") end
GetNumGuildMembers = function() return 1 end
GetGuildRosterInfo = function() return "Gildi-Testrealm" end
C_FriendList = {GetNumFriends = function() return 1 end, GetFriendInfoByIndex = function() return {name = "Freundin"} end}
BNGetNumFriends = function() return 1 end
C_BattleNet = {GetFriendAccountInfo = function() return {gameAccountInfo = {characterName = "Bnetty"}} end}
assert(K.IsKnown("Gildi") and K.IsKnown("Freundin-Realm") and K.IsKnown("Bnetty") and not K.IsKnown("Fremder"))
local calls = {}
CancelDuel = function() calls[#calls + 1] = "duel" end
DeclineGroup = function() calls[#calls + 1] = "decline" end
AcceptResurrect = function() calls[#calls + 1] = "res" end
C_SummonInfo = {ConfirmSummon = function() calls[#calls + 1] = "summon" end}
assert(not K:OnEvent("DUEL_REQUESTED", "Fremder") and #calls == 0, "aus: nichts")
for _, f in ipairs(K.FEATURES) do ONE.features[f[1]].set(true) end
assert(not K:OnEvent("DUEL_REQUESTED", "Gildi"), "Gilde darf")
assert(K:OnEvent("DUEL_REQUESTED", "Fremder") and calls[1] == "duel")
assert(K:OnEvent("PARTY_INVITE_REQUEST", "Fremder") and calls[2] == "decline")
assert(not K:OnEvent("PARTY_INVITE_REQUEST", "Freundin"))
UnitAffectingCombat = function(u) return u == "Kaempfer" end
assert(not K:OnEvent("RESURRECT_REQUEST", "Kaempfer"), "Helfer im Kampf: nicht annehmen")
assert(K:OnEvent("RESURRECT_REQUEST", "Heiler") and calls[3] == "res")
InCombatLockdown = function() return true end
assert(not K:OnEvent("CONFIRM_SUMMON"), "im Kampf keine Beschwoerung")
InCombatLockdown = function() return false end
assert(K:OnEvent("CONFIRM_SUMMON") and calls[4] == "summon")
assert(#ONE.printed == 2, "Ablehnen meldet sich im Chat")

-- ===== 3) Flug-Restzeit =====
local now = 1000
GetTime = function() return now end
local store = {nodes = {[1] = {continent = 1, x = 0, y = 0}, [2] = {continent = 1, x = 3000, y = 0}}}
nav.Flights = {Store = function() return store end, Nodes = function() return store.nodes end}
nav.Travel = {Distance = function(ax, ay, bx, by) return math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) end,
    FLY_DETOUR = 1.15, FLY_SPEED = 30, FLY_EXTRA = .7}
assert(loadfile(root .. "/ONE_Nav/FlightTimer.lua"))("ONE_Nav", nav)
local F = nav.FlightTimer
local dur, guess = F:Duration(1, 2)
assert(guess == true and dur == math.floor(3000 * 1.15 / 30 + 42 + .5), tostring(dur))
GetTaxiMapID = function() return 1414 end
C_TaxiMap = {GetAllTaxiNodes = function() return {{nodeID = 1, state = 0, name = "Start"}, {nodeID = 2, slotIndex = 5, name = "Ratschet, Brachland"}} end}
F:OnTake(5)
assert(F.flight and F.flight.name == "Ratschet" and F.flight.from == 1 and F.flight.to == 2)
F:Started()
now = now + 60
assert(F:Text() == "Flug nach Ratschet – noch ~" .. F.Clock(dur - 60), F:Text())
now = now + 40
assert(F:Landed() == 100 and F:Times()["1>2"] == 100, "echte Zeit gemerkt")
dur, guess = F:Duration(1, 2)
assert(dur == 100 and guess == false)
F:OnTake(5) F:Started() now = now + 2
assert(F:Landed() == nil and F:Times()["1>2"] == 100, "abgebrochener Flug (2 s) zaehlt nicht")
assert(F.Clock(83) == "1:23")
-- Landung per Takt (Spielbild 23.11.2026: Balken blieb nach der Landung stehen)
local flying = true
UnitOnTaxi = function() return flying end
F:OnTake(5) F:Started()
now = now + 1
flying = false
assert(F:Tick() == "flying", "gleich nach dem Abflug noch nicht landen")
now = now + 90
flying = true
assert(F:Tick() == "flying" and F.flight)
flying = false
assert(F:Tick() == "landed" and F.flight == nil and F:Times()["1>2"] == 91, tostring(F:Times()["1>2"]))
-- ohne UnitOnTaxi: Notausgang nach erwarteter Zeit + 2 min, ohne Zeit zu merken
UnitOnTaxi = nil
F:OnTake(5) F:Started()
now = now + 91 + 121
assert(F:Tick() == "timeout" and F.flight == nil and F:Times()["1>2"] == 91)

-- ===== 4) Meine Figuren =====
GetRealmName = function() return "Testrealm" end
UnitName = function() return "Testheld" end
UnitClass = function() return "Magier", "MAGE" end
UnitLevel = function() return 20 end
GetMoney = function() return 12345 end
UnitXP, UnitXPMax = function() return 100 end, function() return 10000 end
GetXPExhaustion = function() return 1000 end
IsResting = function() return true end
GetZoneText = function() return "Tirisfal" end
time = function() return 100000 end
C_Container = {GetContainerNumSlots = function(bag) return bag == 0 and 2 or (bag == -1 and 1 or 0) end,
    GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return {itemID = 2589, stackCount = 10} end
        if bag == -1 then return {itemID = 2589, stackCount = 5} end
    end}
assert(loadfile(root .. "/ONE_Core/Alts.lua"))("ONE_Core", ONE)
local A = ONE.Alts
assert(ONE:FeatureOn("core.altCounts"), "Anzeige: Standard an")
A:Update("bags")
assert(A:CountText(2589) == nil, "nur eigene Tasche: keine Zeile")
A:Update("bank")
local parts, total = A:CountText(2589)
assert(parts and total == 15 and parts[1] == "Testheld 15 (Tasche 10, Bank 5)", parts and parts[1])
ONE.db.alts.Testrealm.Zweiter = {class = "WARRIOR", level = 30, money = 5, bags = {[2589] = 3}, max = 20000, rested = 0, seen = 100000 - 8 * 3600, resting = true}
parts, total = A:CountText(2589)
assert(total == 18 and #parts == 2)
assert(A:TotalMoney() == 12350)
-- Erholt offline: Gasthaus 5 % je 8 h, draussen ein Viertel, hoechstens 150 %
assert(A.RestedNow(ONE.db.alts.Testrealm.Zweiter, 100000) == 1000)
ONE.db.alts.Testrealm.Zweiter.resting = false
assert(A.RestedNow(ONE.db.alts.Testrealm.Zweiter, 100000) == 250)
assert(A.RestedNow({level = 20, max = 100, rested = 0, seen = 0, resting = true}, 1e9) == 150)
assert(A.List and A:List()[1].name == "Testheld", "eigene Figur zuerst")
assert(not A:Remove("Testheld") and A:Remove("Zweiter") and #A:List() == 1)
local tip = {lines = {}}
function tip:GetItem() return "Leinenstoff", "item:2589" end
function tip:AddLine(t) self.lines[#self.lines + 1] = t end
assert(A:OnTooltip(tip) and tip.lines[1] == "Deine Figuren:" and tip.lines[2]:find("Testheld 15", 1, true))
print("OK test_komfort_161")
