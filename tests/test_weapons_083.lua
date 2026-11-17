-- Offline-Test: Waffenkunde – Klasse -> Waffen, beherrscht, naechster Waffenmeister, Erfassung, Navi.
local root = arg[1] or "src"
local known = {[1303007] = true} -- Zweihandaexte (Forever-Nummer)
IsPlayerSpell = function(id) return known[id] == true end
local ONE = {db = {}}
_G.ProjectONE = ONE
local trainers = {
    {npc = "Sayoc", kind = "weapon", map = 1454, x = .815, y = .196, area = "Orgrimmar"},
    {npc = "Ansekhwa", kind = "weapon", map = 1456, x = .408, y = .626, area = "Donnerfels"},
    {npc = "Archibald", kind = "weapon", map = 1458, x = .574, y = .328, area = "Unterstadt"},
    {npc = "Grezz Ragefist", kind = "class", map = 1454, x = .8, y = .3},
}
local dist = {[1454] = 300, [1456] = 2000} -- Unterstadt: anderer Kontinent (nil)
local pointed
ONE.modules = {
    crafting = {AllTrainers = function() return trainers end},
    nav = {DistanceTo = function(_, map) return dist[map] end,
        PointTo = function(_, label, map, x, y) pointed = {label, map, x, y} return true end},
}
local c = {}
assert(loadfile(root .. "/ONE_Classes/Weapons.lua"))("ONE_Classes", c)
local Wp = c.Weapons

-- 1) Alle Klassen haben Waffen, alle Schluessel existieren
for cls, list in pairs(Wp.byClass) do
    assert(#list >= 4, cls)
    for _, k in ipairs(list) do assert(Wp.byKey[k], cls .. " " .. k) end
end
for npc, list in pairs(Wp.seedTeaches) do for _, k in ipairs(list) do assert(Wp.byKey[k], npc .. " " .. k) end end

-- 2) Krieger: Zweihandaexte bekannt, Stangenwaffen nicht; Lehrer nach Classic-Stand
local rows = Wp:Rows("WARRIOR")
local by = {}
for _, r in ipairs(rows) do by[r.key] = r end
assert(by.axe2.known == true and by.polearm.known == false)
assert(by.bow.trainer.npc == "Sayoc" and not by.bow.sure, "naechster nach Classic: Sayoc")
assert(by.mace2.trainer.npc == "Ansekhwa")
assert(by.polearm.trainer.npc == "Archibald", "auch ohne Entfernung (anderer Kontinent)")
assert(not by.wand, "Krieger: keine Zauberstaebe")
assert(Wp.TrainerText(by.bow) == "Sayoc  ·  Orgrimmar |cff9d9d9d*|r", Wp.TrainerText(by.bow))

-- 3) Im Spiel erfasstes Angebot gewinnt: Ansekhwa lehrt in Forever auch Bogen -> sicher und vorn
trainers[2].weapons = {bow = true, gun = true}
by = {}
for _, r in ipairs(Wp:Rows("WARRIOR")) do by[r.key] = r end
assert(by.bow.trainer.npc == "Ansekhwa" and by.bow.sure, "bestaetigt schlaegt Classic-Angabe trotz groesserer Entfernung")
assert(by.mace2.trainer == nil, "erfasst ohne Zweihandstreitkolben -> Ansekhwa faellt weg, sonst lehrt sie hier niemand")
trainers[2].weapons = nil

-- 4) Magier: Zauberstab braucht keinen Lehrer; Navi startet beim Klick
by = {}
for _, r in ipairs(Wp:Rows("MAGE")) do by[r.key] = r end
assert(by.wand.weapon.free and not by.wand.trainer and Wp.TrainerText(by.wand) == "kein Lehrer nötig")
assert(Wp.Navi(by.dagger) and pointed[1] == "Sayoc" and pointed[2] == 1454)
assert(Wp.Navi(by.wand) == false)

-- 5) Ohne Spiel-API: Stand unbekannt
IsPlayerSpell = nil
assert(Wp.Known(Wp.byKey.axe2) == nil)

-- 6) Erfassung beim Waffenmeister (ONE_Crafting): Angebot -> Waffenarten
local crafting = {}
assert(loadfile(root .. "/ONE_Crafting/Trainers.lua"))("ONE_Crafting", crafting)
local w = crafting.Trainers.WeaponsFrom({"Zweihandäxte", "Bogen", "Stäbe", "Zauberstäbe", "Two-Handed Maces", "Wurfwaffe"})
assert(w.axe2 and w.bow and w.staff and w.mace2 and w.thrown, "erkannt")
assert(not w.wand and not w.axe1, "Zauberstaebe sind keine Staebe, Zweihand nicht Einhand")
assert(crafting.Trainers.WeaponsFrom({"Erste Hilfe"}) == nil)
print("OK test_weapons_083")
