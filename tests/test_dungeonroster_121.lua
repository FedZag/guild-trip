-- Offline-Test 0.7.2: Dungeon-Gegner und Bosse sammeln – OHNE Kampflog (Forever sperrt es fuer Addons)
local root = arg[1] or "src"
local handler
CreateFrame = function() return {RegisterEvent = function(_, ev) assert(not ev:find("COMBAT_LOG"), "kein Kampflog") end,
    SetScript = function(_, _, fn) handler = fn end} end
local units = {}
UnitGUID = function(u) return units[u] and units[u][1] end
UnitName = function(u) return units[u] and units[u][2] end
UnitExists = function(u) return units[u] ~= nil end
local secret = {}
issecretvalue = function(v) return secret[v] == true end
local ONE = {db = {}}
function ONE:RegisterSlash(n, fn) self.slash = {n, fn} end
local printed = {}
function ONE:Print(t) printed[#printed + 1] = t end
_G.ProjectONE = ONE
local dungeons = {Catalog = {{key = "krol", name = "Feste Krol'dok"}}, Recap = {}}
assert(loadfile(root .. "/ONE_Dungeons/Roster.lua"))("ONE_Dungeons", dungeons)
local R = dungeons.Roster
R:Initialize()
-- 1) ausserhalb eines Dungeons: nichts
units.nameplate1 = {"Creature-0-1-2-3-1234-00", "Wolf"}
handler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(next(R:Store()) == nil, "nur im Dungeon")
-- 2) im Dungeon: Gegner ueber Namensplakette, Ziel, Mauszeiger; Spieler nicht
dungeons.Recap.run = {key = "krol"}
units.nameplate1 = {"Creature-0-1-2-3-5001-00", "Steinwache"}
handler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
units.target = {"Creature-0-1-2-3-5002-00", "Erdrufer"}
handler(nil, "PLAYER_TARGET_CHANGED")
units.mouseover = {"Player-1-AAA", "Bob"}
handler(nil, "UPDATE_MOUSEOVER_UNIT")
local e = R:Store().krol
assert(e.npcs[5001].name == "Steinwache" and e.npcs[5002].name == "Erdrufer" and not e.npcs[5001].boss)
local count = 0 for _ in pairs(e.npcs) do count = count + 1 end
assert(count == 2, "Spieler zaehlen nicht")
-- 3) Boss ueber die Boss-Leiste, Begegnung bei Erfolg
units.boss1 = {"Creature-0-1-2-3-5100-00", "Häuptling Krol"}
handler(nil, "INSTANCE_ENCOUNTER_ENGAGE_UNIT")
assert(e.npcs[5100].boss and e.npcs[5100].name == "Häuptling Krol", "Boss erkannt")
handler(nil, "ENCOUNTER_END", 777, "Häuptling Krol", 1, 5, 1)
assert(e.bosses[777] == "Häuptling Krol")
handler(nil, "ENCOUNTER_END", 778, "Wipe", 1, 5, 0)
assert(not e.bosses[778], "fehlgeschlagen: keine Begegnung")
-- 4) geheime Werte (im Kampf): nichts anfassen
units.nameplate2 = {"Creature-0-1-2-3-5200-00", "Geheim"}
secret["Geheim"] = true
handler(nil, "NAME_PLATE_UNIT_ADDED", "nameplate2")
assert(not e.npcs[5200], "geheim: nicht merken")
-- 5) /trip dungeondaten
ONE.slash[2]()
assert(printed[1]:find("Feste Krol'dok") and printed[1]:find("3 Gegner") and printed[1]:find("1 Bosse"), printed[1])
print("OK test_dungeonroster_121")
