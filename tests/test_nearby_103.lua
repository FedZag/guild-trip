-- Offline-Test 0.7.0: Spieler in der Naehe buffen (Klick auf den Namen wirkt den Buff).
local root = arg[1] or "src"
local function Region(kind, parent, name, template)
    local r = {kind = kind, parent = parent, name = name, template = template, shown = true, scripts = {}, attr = {}}
    setmetatable(r, {__index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("^Get") and not k:match("^Is") then return function() end end
    end})
    function r:SetText(t) self.text = t end
    function r:SetTexture(t) self.texture = t end
    function r:SetAlpha(a) self.alpha = a end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetScript(e, fn) self.scripts[e] = fn end
    function r:SetPoint(...) self.point = {...} end
    function r:SetAttribute(k, v) self.attr[k] = v end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    function r:GetParent() return self.parent end
    function r:GetPoint() return "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 70, 400 end
    return r
end
CreateFrame = function(kind, name, parent, template) return Region(kind, parent, name, template) end
UIParent = Region("Frame")
local drivers = {}
RegisterStateDriver = function(frame, state, rule) drivers[#drivers + 1] = {frame = frame, rule = rule} end
GetTime = function() return 1000 end
local combat = false
InCombatLockdown = function() return combat end
RAID_CLASS_COLORS = {WARRIOR = {colorStr = "ffc79c6e"}, MAGE = {colorStr = "ff3fc7eb"}}

-- Ich: Priester mit Seelenstaerke Rang 1-3
local myClass = "PRIEST"
UnitClass = function(u) if u == "player" then return "x", myClass end return "x", (UNITS[u] or {}).class end
UnitLevel = function(u) if u == "player" then return 30 end return (UNITS[u] or {}).level end
local spells = {
    [1243] = "Machtwort: Seelenstärke", [1244] = "Machtwort: Seelenstärke", [1245] = "Machtwort: Seelenstärke",
    [21562] = "Gebet der Seelenstärke", [14752] = "Göttlicher Willen", [976] = "Schattenschutz",
    [20217] = "Segen der Könige", [19742] = "Segen der Weisheit", [19740] = "Segen der Macht", [19834] = "Segen der Macht",
}
local book = {1243, 1244, 1245}
Enum = {SpellBookSpellBank = {Player = 0}}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #book} end,
    GetSpellBookItemInfo = function(i) local id = book[i]; return {spellID = id, name = spells[id], iconID = id, subName = "Rang " .. i} end,
}
C_Spell = {
    GetSpellInfo = function(id) return spells[id] and {name = spells[id], iconID = id} end,
    GetSpellSubtext = function(id) return ({[1243] = "Rang 1", [1244] = "Rang 2", [1245] = "Rang 3"})[id] end,
    IsSpellInRange = function(_, u) return (UNITS[u] or {}).range end,
}
-- Einheiten in der Naehe
UNITS = {}
local function Reset()
    UNITS = {
        party1 = {name = "Bob", class = "MAGE", level = 30, range = true, auras = {}},
        nameplate1 = {name = "Fremder", class = "WARRIOR", level = 10, range = true, auras = {}},
        nameplate2 = {name = "Gebuffter", class = "WARRIOR", level = 30, range = true, auras = {{name = "Gebet der Seelenstärke", expirationTime = 3000}}},
        nameplate3 = {name = "Weitweg", class = "MAGE", level = 30, range = false, auras = {}},
        nameplate4 = {name = "Gildi", class = "MAGE", level = 20, range = true, auras = {}, guild = true},
        nameplate5 = {name = "Feind", class = "MAGE", level = 30, range = true, auras = {}, enemy = true},
        target = {name = "Fremder", class = "WARRIOR", level = 10, range = true, auras = {}},
    }
end
Reset()
local function Get(u) return UNITS[u] end
UnitExists = function(u) return u == "player" or Get(u) ~= nil end
UnitIsPlayer = function(u) return true end
UnitIsUnit = function(a, b) return a == b end
UnitCanAssist = function(_, u) return Get(u) and not Get(u).enemy end
UnitIsDeadOrGhost = function() return false end
UnitIsConnected = function() return true end
GetUnitName = function(u) return Get(u) and Get(u).name end
UnitGUID = function(u) return Get(u) and ("Player-" .. Get(u).name) end
UnitInParty = function(u) return u:match("^party") ~= nil end
UnitInRaid = function() return nil end
IsInRaid = function() return false end
UnitIsInMyGuild = function(u) return Get(u) and Get(u).guild end
C_UnitAuras = {GetAuraDataByIndex = function(u, i) return Get(u) and Get(u).auras[i] end}
issecretvalue = function(v) return v == "GEHEIM" end

local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
for _, f in ipairs({"Data.lua", "Player.lua", "Nearby.lua"}) do assert(loadfile(root .. "/ONE_Classes/" .. f))("ONE_Classes", c) end
c.Player.maxAge = 0
local N = c.Nearby

local function Names(list) local out = {} for i, e in ipairs(list) do out[i] = e.name end return table.concat(out, ",") end

-- 1) Gruppe zuerst, dann Gilde, dann Fremde; gebuffte, ferne und feindliche fehlen; doppelt (Ziel) nur einmal
local list = N:Update()
assert(Names(list) == "Bob,Gildi,Fremder", Names(list))
assert(list[1].tag == "group" and list[2].tag == "guild" and list[3].tag == nil)
local f = N.frame
assert(f and f.title.text == "Buffen in der Nähe (3)" and drivers[1].rule == "[combat] hide; show", "Fenster + Kampf-Ausblendung")

-- 2) Klick wirkt den Buff im passenden Rang: Stufe 30 -> Rang 3, Stufe 10 -> Rang 2 (Rang 3 braucht 24-10)
local r1, r3 = f.rows[1], f.rows[3]
assert(r1.template == "SecureActionButtonTemplate" and r1.attr.type1 == "spell" and r1.attr.spell1 == 1245 and r1.attr.unit1 == "party1", "Gruppe")
assert(r3.attr.type1 == "spell" and r3.attr.spell1 == 1244 and r3.attr.unit1 == "target", "niedriger Rang fuer Stufe 10")
assert(r3.attr.type2 == nil, "nur ein Buff -> kein Rechtsklick")
assert(r1.label.text:find("Bob", 1, true) and r1.label.text:find("ff3fc7eb", 1, true) and r1.label.text:find("Gruppe", 1, true))
assert(r1.icons[1].shown and not r1.icons[2].shown)
assert(N.RankFor(N.myOffers[1], 1) == 1243 and N.RankFor(N.myOffers[1], nil) == 1245)

-- 3) Buff laeuft bald aus = fehlt; laenger = da
UNITS.party1.auras = {{name = "Machtwort: Seelenstärke", expirationTime = 1030}}
assert(Names(N:Update()) == "Bob,Gildi,Fremder")
UNITS.party1.auras = {{name = "Machtwort: Seelenstärke", expirationTime = 0}}
assert(Names(N:Update()) == "Gildi,Fremder")
-- gesperrte Buffs: unbekannt -> wird gezeigt
UNITS.party1.auras = {{name = "GEHEIM"}}
assert(Names(N:Update()) == "Bob,Gildi,Fremder")
Reset()

-- 4) Mit der Maus beruehrt (ohne Plakette): nur per Name -> Makro, Ziel zurueck
UNITS.mouseover = {name = "Wanderer", class = "MAGE", level = 40, range = true, auras = {}}
N:Remember("mouseover")
UNITS.mouseover = nil
list = N:Update()
assert(Names(list) == "Bob,Gildi,Fremder,Wanderer", Names(list))
local r4 = f.rows[4]
assert(r4.attr.type1 == "macro" and r4.attr.macrotext1 == "/targetexact Wanderer\n/cast Machtwort: Seelenstärke(Rang 3)\n/targetlasttarget", r4.attr.macrotext1)
assert(r4.alpha == .7)
GetTime = function() return 1031 end -- nach 30 Sekunden vergessen
assert(Names(N:Update()) == "Bob,Gildi,Fremder")
GetTime = function() return 1000 end

-- 5) Zwei Buffs: Linksklick erster, Rechtsklick zweiter
book = {1243, 14752}
list = N:Update()
assert(f.rows[1].attr.spell1 == 1243 and f.rows[1].attr.spell2 == 14752 and f.rows[1].attr.unit2 == "party1", "Rechtsklick = zweiter Buff")
book = {1243, 1244, 1245}

-- 6) Paladin: ein Segen je Ziel – Krieger bekommt Macht, Magier Weisheit; schon gesegnet = fehlt nicht
myClass = "PALADIN"
book = {19742, 19740, 19834}
list = N:Update()
local byName = {}
for i, e in ipairs(list) do byName[e.name] = f.rows[i] end
assert(byName.Fremder.attr.spell1 == 19834 and byName.Fremder.attr.spell2 == 19742, "Krieger: Macht zuerst")
assert(byName.Bob.attr.spell1 == 19742 and byName.Bob.attr.spell2 == 19834, "Magier: Weisheit zuerst")
UNITS.party1.auras = {{name = "Segen der Macht", expirationTime = 0}}
assert(not Names(N:Update()):find("Bob"), "hat schon einen Segen")
myClass, book = "PRIEST", {1243, 1244, 1245}
Reset()

-- 7) Klasse ohne Buffs fuer andere: nichts, Fenster leer
myClass = "WARRIOR"
assert(#N:Update() == 0 and f.alpha == 0 and not f.rows[1].shown)
myClass = "PRIEST"

-- 8) Im Kampf: nichts aendern, danach nachholen
assert(#N:Update() == 3)
combat = true
assert(N:Update() == nil and N.dirty == true)
combat = false
assert(#N:Update() == 3 and not N.dirty)

-- 9) Abschalten / Position merken
N:SetEnabled(false)
assert(#N.shown == 0 and ONE.db.classGuide.buffNearby == false and f.alpha == 0)
N:SetEnabled(true)
assert(#N.shown == 3 and f.alpha == 1)
f.scripts.OnDragStop(f)
assert(ONE.db.classGuide.nearbyPos.x == 70 and ONE.db.classGuide.nearbyPos.y == 400)

-- 10) Ein Klick: Buff sitzt -> Spieler raus; Fehlschlag -> bleibt; Buff verloren -> wieder da
Reset()
assert(Names(N:Update()) == "Bob,Gildi,Fremder")
N:OnSent("player", "Fremder", "cast-1", 1244)
assert(Names(N:Update()) == "Bob,Gildi,Fremder", "nur abgeschickt = noch drin")
N:OnSucceeded("player", "cast-1")
assert(Names(N:Update()) == "Bob,Gildi", "gebufft = raus (auch bevor der Buff sichtbar ist)")
N:OnSent("player", "Bob-Realm", "cast-2", 1245) -- Zauber scheitert: kein SUCCEEDED
assert(Names(N:Update()) == "Bob,Gildi", "Fehlschlag = bleibt")
N:OnSent("player", "Gildi", "cast-3", 2061) -- fremder Zauber (keiner meiner Buffs) zaehlt nicht
N:OnSucceeded("player", "cast-3")
assert(Names(N:Update()) == "Bob,Gildi")
-- nach der Wartezeit: Buff fehlt wieder (z. B. gestorben) -> zurueck
GetTime = function() return 1020 end
assert(Names(N:Update()) == "Bob,Gildi,Fremder", "Buff verloren = wieder da")
-- mit Buff bleibt er draussen
N:OnSent("player", "Fremder", "cast-4", 1244)
N:OnSucceeded("player", "cast-4")
UNITS.nameplate1.auras = {{name = "Machtwort: Seelenstärke", expirationTime = 2800}}
UNITS.target.auras = UNITS.nameplate1.auras
GetTime = function() return 1040 end
assert(Names(N:Update()) == "Bob,Gildi")
-- nur per Name bekannt (Buffs unbekannt): bleibt 30 Minuten draussen
UNITS.mouseover = {name = "Wanderer", class = "MAGE", level = 40, range = true, auras = {}}
N:Remember("mouseover") UNITS.mouseover = nil
N:OnSent("player", "Wanderer", "cast-5", 1245) N:OnSucceeded("player", "cast-5")
GetTime = function() return 1060 end
assert(Names(N:Update()) == "Bob,Gildi", "Wanderer raus")
GetTime = function() return 1000 end

-- 11) Automatisch erkennen: Plaketten an (unsichtbar, durchklickbar), alte Werte zurueck
local cvars = {nameplateShowFriends = "0", nameplateMaxDistance = "20"}
C_CVar = {GetCVar = function(k) return cvars[k] end, SetCVar = function(k, v) cvars[k] = v end}
local plates, clickThrough = {}, nil
C_NamePlate = {
    GetNamePlateForUnit = function(u) return plates[u] end,
    SetNamePlateFriendlyClickThrough = function(on) clickThrough = on end,
}
plates.nameplate1 = {UnitFrame = Region("Frame")}
plates.nameplate5 = {UnitFrame = Region("Frame")} -- Feind: bleibt sichtbar
N.autoOn = nil
N.done, N.seen = nil, nil
ONE.db.classGuide.nearbyCVars = nil
N:Update()
assert(cvars.nameplateShowFriends == "1" and cvars.nameplateMaxDistance == "20", "Plaketten an, Reichweite unveraendert")
assert(clickThrough == true and plates.nameplate1.UnitFrame.alpha == 0 and plates.nameplate5.UnitFrame.alpha == 1, "unsichtbar")
assert(ONE.db.classGuide.nearbyCVars.friends == "0" and ONE.db.classGuide.nearbyCVars.dist == nil)
N:Update() -- zweites Mal: alte Werte nicht ueberschreiben
assert(ONE.db.classGuide.nearbyCVars.friends == "0")
N:SetAuto(false)
assert(cvars.nameplateShowFriends == "0" and cvars.nameplateMaxDistance == "20" and clickThrough == false
    and plates.nameplate1.UnitFrame.alpha == 1 and ONE.db.classGuide.nearbyCVars == nil, "alles zurueck")
assert(Names(N:Update()) == "Bob,Gildi", "Liste bleibt trotzdem")
-- Plaketten hattest du schon an: bleiben sichtbar
cvars.nameplateShowFriends = "1"
N:SetAuto(true)
assert(cvars.nameplateShowFriends == "1" and plates.nameplate1.UnitFrame.alpha == 1 and clickThrough == false)
-- Modul aus: zurueckstellen
N:SetEnabled(false)
assert(cvars.nameplateMaxDistance == "20" and cvars.nameplateShowFriends == "1" and ONE.db.classGuide.nearbyCVars == nil)
N:SetEnabled(true)
-- 12) Maus auf der Liste: nicht umsortieren; nach erfolgreichem Buff doch
cvars.nameplateShowFriends, cvars.nameplateMaxDistance = "0", "20"
ONE.db.classGuide.nearbyCVars = nil
N.autoOn, N.done = nil, nil
Reset()
assert(Names(N:Update()) == "Bob,Gildi,Fremder")
f.IsMouseOver = function() return true end
f.IsShown = function() return true end
f.GetAlpha = function() return 1 end
UNITS.party1.auras = {{name = "Machtwort: Seelenstärke", expirationTime = 0}}
assert(Names(N:Update()) == "Bob,Gildi,Fremder", "eingefroren, solange die Maus drueber ist")
N:OnSent("player", "Gildi", "cast-9", 1245) N:OnSucceeded("player", "cast-9")
assert(Names(N:Update()) == "Fremder", "nach dem Buff aktualisiert")
f.IsMouseOver = function() return false end
-- 13) Begleiter fremder Spieler ebenfalls unsichtbar, freundliche NPCs nicht
UnitPlayerControlled = function(u) return u == "nameplate6" end
local isPlayer = UnitIsPlayer
UnitIsPlayer = function(u) return u ~= "nameplate6" and u ~= "nameplate7" end
plates.nameplate6 = {UnitFrame = Region("Frame")}
plates.nameplate7 = {UnitFrame = Region("Frame")}
UNITS.nameplate6 = {name = "Wolf", auras = {}}
UNITS.nameplate7 = {name = "Wache", auras = {}}
N:Update()
assert(plates.nameplate6.UnitFrame.alpha == 0 and plates.nameplate7.UnitFrame.alpha == 1, "Begleiter weg, NPC bleibt")
UnitIsPlayer = isPlayer
-- 14) Ausloggen: alte Einstellungen zurueck
local logout = N.events and N.events.scripts and N.events.scripts.OnEvent
assert(N.autoOn and cvars.nameplateShowFriends == "1")
N:ApplyAuto(false)
assert(cvars.nameplateShowFriends == "0" and cvars.nameplateMaxDistance == "20")
-- 15) 0.7.1: Umschalt+V heisst sichtbar/unsichtbar – technisch bleiben die Plaketten an
cvars.nameplateShowFriends = "0"
ONE.db.classGuide.nearbyCVars, ONE.db.classGuide.nearbyAuto, ONE.db.classGuide.nearbyVisible = nil, nil, nil
N.autoOn = nil
local printed = {}
ONE.Print = function(_, t) printed[#printed + 1] = t end
N:Update()
assert(N.autoOn and N.hidePlates and cvars.nameplateShowFriends == "1" and plates.nameplate1.UnitFrame.alpha == 0, "unsichtbar")
-- a) Umschalt+V (Spiel schaltet "aus") -> sichtbar, bleibt an
cvars.nameplateShowFriends = "0"
assert(N:UserToggled())
assert(cvars.nameplateShowFriends == "1" and plates.nameplate1.UnitFrame.alpha == 1 and clickThrough == false and N.autoOn, "sichtbar")
assert(ONE.db.classGuide.nearbyVisible == true and printed[#printed]:find("sichtbar", 1, true))
N:Update()
assert(plates.nameplate1.UnitFrame.alpha == 1 and N.autoOn, "bleibt sichtbar")
-- b) nochmal Umschalt+V (ueber den Abgleich, ohne Ereignis) -> wieder unsichtbar, Liste laeuft weiter
cvars.nameplateShowFriends = "0"
N:Update()
assert(cvars.nameplateShowFriends == "1" and plates.nameplate1.UnitFrame.alpha == 0 and clickThrough == true and N.autoOn, "wieder unsichtbar")
assert(ONE.db.classGuide.nearbyVisible == false and printed[#printed]:find("ausgeblendet", 1, true))
assert(Names(N:Update()) ~= "", "Liste funktioniert weiter")
-- c) eigene Aenderungen zaehlen nicht
N.ownChange = true
assert(N:UserToggled() == false)
N.ownChange = nil
-- d) Wahl wird gemerkt: sichtbar gewaehlt, ausloggen -> Plaketten bleiben an
cvars.nameplateShowFriends = "0" N:UserToggled()
assert(ONE.db.classGuide.nearbyVisible == true)
N:ApplyAuto(false)
assert(cvars.nameplateShowFriends == "1", "sichtbar gewaehlt: bleibt an")
-- unsichtbar gewaehlt: ausloggen -> wie vor Guild Trip (aus)
N:ApplyAuto(true)
cvars.nameplateShowFriends = "0" N:UserToggled()
assert(ONE.db.classGuide.nearbyVisible == false)
N:ApplyAuto(false)
assert(cvars.nameplateShowFriends == "0", "unsichtbar gewaehlt: beim Ausloggen aus")
-- Einloggen: Wahl gilt wieder
N:ApplyAuto(true)
assert(N.hidePlates and cvars.nameplateShowFriends == "1")
-- 16) Namensplaketten-Addon aktiv: nichts anfassen
N:ApplyAuto(false)
ONE.db.classGuide.nearbyAuto, ONE.db.classGuide.nearbyVisible = nil, nil
ONE.db.classGuide.nearbyCVars = nil
cvars.nameplateShowFriends = "0"
N.autoOn = nil
C_AddOns = {IsAddOnLoaded = function(name) return name == "Plater" end}
N:Update()
assert(cvars.nameplateShowFriends == "0" and not N.hidePlates and ONE.db.classGuide.nearbyCVars == nil, "Plater: nichts verstellt")
C_AddOns = nil
-- 17) Aus 0.7.0 gemerkte Reichweite wird beim Zurueckstellen noch korrigiert
ONE.db.classGuide.nearbyCVars = {friends = "0", dist = "20"}
cvars.nameplateMaxDistance = "40"
N.autoOn = true
N:ApplyAuto(false)
assert(cvars.nameplateMaxDistance == "20" and ONE.db.classGuide.nearbyCVars == nil)
print("OK test_nearby_103")
