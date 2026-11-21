-- Offline-Test: Klassen-Reisezauber in der Quest-Fuehrung (Nutzer 20.11.2026: "alles klassenspezifische, egal
-- welche Klasse was hat, muss mit eingebaut werden"): Magier-Teleports (+ Besuch beim Portallehrer),
-- Astraler Ruf als zweiter Ruhestein, Teleport Mondlichtung, Tempo durch Geisterwolf/Reisegestalt/Gepard.
local root = arg[1] or "src"
local function Fresh()
    GuildTripQuestDB = {
        q = {
            -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
            [1] = {20, 18, 0, 0, false, {11}, {11}, {}, false, false, 900, 0, 0, 1},
            [2] = {20, 18, 0, 0, false, {12}, {12}, {}, false, false, 900, 0, 0, 1},
        },
        n = {
            -- beide Quests weit weg vom Spieler (bei 3000/300), dicht an der "Stadt"
            [11] = {0, 1, 300, 30},
            [12] = {0, 1, 304, 30},
        },
    }
end
Fresh()
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local function World(m, x, y) return 1, x * 10000, y * 10000 end
local function Ctx(extra)
    local c = {
        me = {level = 20, class = 128, faction = "Horde", mapID = 1, x = .01, y = .01},
        done = function() return false end, inLog = function() return false end, complete = function() return false end,
        world = World, tempo = "all", speed = 7,
    }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local function First(plan) return plan.steps[1] end
local city = {1, 3000, 330}

-- ===== 1) Teleport statt Laufen =====
local tele = {{kind = "teleport", spell = 3567, name = "Teleportieren: Orgrimmar", place = "Orgrimmar", w = city, cd = 0, inSec = 0}}
local plan = assert(P:Plan(Ctx({ports = tele})))
local s1 = First(plan)
assert(s1.kind == "travel" and s1.via.kind == "hearth" and s1.via.port == "teleport" and s1.via.spell == 3567, "erst teleportieren")
assert(plan.steps[2].walk < 1, "danach nur kurz laufen")
local sum = 0
for _, s in ipairs(plan.steps) do sum = sum + (s.cost or 0) end
assert(math.abs(sum - plan.minutes) < .01, "Zeit stimmt mit Teleport")
-- eine Rune: hoechstens ein Teleport im Plan, auch wenn spaeter wieder etwas in der Stadt waere
do
    GuildTripQuestDB.q[3] = {20, 18, 0, 0, false, {13}, {13}, {}, false, false, 900, 0, 0, 1}
    GuildTripQuestDB.q[4] = {20, 18, 0, 0, false, {14}, {14}, {}, false, false, 900, 0, 0, 1}
    GuildTripQuestDB.n[13], GuildTripQuestDB.n[14] = {0, 1, 2, 60}, {0, 1, 302, 33}
    local one = {{kind = "teleport", name = "T", w = city, cd = 0, inSec = 0, uses = 1}}
    local cnt = 0
    for _, s in ipairs(assert(P:Plan(Ctx({ports = one}))).steps) do if s.via and s.via.port == "teleport" then cnt = cnt + 1 end end
    assert(cnt <= 1, "nur so oft wie Runen: " .. cnt)
    Fresh()
end
-- ohne Zauber: laufen
assert(First(assert(P:Plan(Ctx()))).kind ~= "travel", "ohne Teleport laufen")
-- Ziel auf anderem Kontinent: nicht
assert(First(assert(P:Plan(Ctx({ports = {{kind = "teleport", w = {0, 3000, 330}, cd = 0, inSec = 0}}})))).kind ~= "travel")

-- ===== 2) Astraler Ruf = zweiter Ruhestein (zum Heimatort) =====
local home = {1, 3000, 330, inn = 5, place = "Dorf"}
local recall = {{kind = "recall", spell = 556, name = "Astraler Ruf", bind = true, cd = 60, inSec = 0}}
-- Ruhestein auf Abklingzeit, Astraler Ruf bereit
plan = assert(P:Plan(Ctx({home = home, hearthIn = 1800, ports = recall})))
s1 = First(plan)
assert(s1.via and s1.via.port == "recall" and s1.via.place == "Dorf", "Astraler Ruf zum Heimatort")
-- ohne Heimatort: Astraler Ruf geht nicht
assert(First(assert(P:Plan(Ctx({ports = recall})))).kind ~= "travel")
-- beides bereit: einer reicht, nur ein Reiseschritt dorthin
plan = assert(P:Plan(Ctx({home = home, hearthIn = 0, ports = recall})))
local n = 0
for _, s in ipairs(plan.steps) do if s.via and s.via.kind == "hearth" then n = n + 1 end end
assert(n == 1, "nur einmal zurueck")

-- ===== 3) Portallehrer: eigener Besuch, nicht vom Klassenlehrer abgedeckt =====
do
    GuildTripQuestDB.n[11], GuildTripQuestDB.n[12] = {0, 1, 2, 1}, {0, 1, 4, 1}
    local spot = {{mapID = 1, x = .003, y = .001, name = "Thuul"}}
    local cls = {{mapID = 1, x = .003, y = .0012, name = "Pephredo"}}
    plan = assert(P:Plan(Ctx({portal = {now = 1, next = {}, spots = spot, group = "portal"}, train = {now = 2, next = {}, spots = cls}})))
    local seen = {}
    for _, s in ipairs(plan.steps) do if s.kind == "train" then seen[s.group or "class"] = s end end
    assert(seen.portal and seen.portal.name == "Thuul" and seen.portal.stopKey == "train:portal:20", "Portallehrer-Besuch")
    assert(seen.class and seen.class.name == "Pephredo" and seen.class.stopKey == "train:20", "Klassenlehrer extra")
    Fresh()
end

-- ===== 4) Spiel-Anbindung (Guide) =====
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
C_Timer = {After = function(_, fn) fn() end}
UnitName = function() return "Testheld" end
local ONE = {db = {}, modules = {}, ns = {}}
_G.ProjectONE = ONE
function ONE:Print() end
local L2 = {}
for _, f in ipairs({"Planner", "Guide", "Teleports", "Tracker"}) do
    assert(loadfile(root .. "/ONE_Leveling/" .. f .. ".lua"))("ONE_Leveling", L2)
end
local G, Tr = L2.Guide, L2.Tracker
local known = {[3567] = true, [3563] = true}
IsPlayerSpell = function(id) return known[id] == true end
GetSpellInfo = function(id) return id == 3567 and "Teleportieren: Orgrimmar" or ("Zauber " .. id) end
local runes = 1
GetItemCount = function(item) return item == 17031 and runes or 0 end
GetTime = function() return 1000 end
GetSpellCooldown = function() return 0, 0 end
local ports = G.Ports("MAGE", "Horde")
assert(#ports == 2, "zwei gelernte Horde-Teleports")
for _, p in ipairs(ports) do
    assert(p.kind == "teleport" and p.w and p.w[1] and p.inSec == 0 and p.uses == 1)
    if p.spell == 3567 then assert(p.name == "Teleportieren: Orgrimmar" and p.w[1] == 1 and math.abs(p.w[2] - 1469.9) < 1) end
end
runes = 0
assert(#G.Ports("MAGE", "Horde") == 0, "ohne Teleportrune nicht nutzbar")
runes = 1
assert(#G.Ports("MAGE", "Alliance") == 0, "Allianz-Teleports nicht gelernt")
assert(#G.Ports("PRIEST", "Horde") == 0)
-- Astraler Ruf mit Abklingzeit
known[556] = true
GetSpellCooldown = function(id) if id == 556 then return 900, 600 end return 0, 0 end
ports = G.Ports("SHAMAN", "Horde")
assert(#ports == 1 and ports[1].kind == "recall" and ports[1].bind and ports[1].w == nil and ports[1].inSec == 500, "Astraler Ruf, noch 500 s")
GetSpellCooldown = function() return 1000, 1.5 end
assert(G.SpellReadyIn(556) == 0, "globale Abklingzeit zaehlt nicht")
-- Druide: Mondlichtung ohne Rune
known[18960] = true
ports = G.Ports("DRUID", "Alliance")
assert(#ports == 1 and ports[1].place == "Mondlichtung")
-- Portallehrer: Thuul aus der Lehrerliste (other/Portale), ungelernte Teleports bis Stufe+2
ONE.ns.crafting = {Trainers = {All = function() return {
    {npc = "Thuul", kind = "other", what = "Portale", map = 1454, x = .387, y = .854},
    {npc = "Pephredo", kind = "class", what = "Magier", map = 1454, x = .388, y = .856},
} end}}
known = {}
local pi = assert(G.PortalInfo("MAGE", 20, "Horde"))
assert(pi.now == 2 and pi.group == "portal" and #pi.spots == 1 and pi.spots[1].name == "Thuul", "Org + UC lernbar bei Thuul")
pi = assert(G.PortalInfo("MAGE", 28, "Horde"))
assert(pi.now == 2 and pi.next[30] == 1, "Donnerfels kommt mit 30")
known = {[3567] = true, [3563] = true, [3566] = true}
assert(G.PortalInfo("MAGE", 30, "Horde") == nil, "alles gelernt")
assert(G.PortalInfo("WARRIOR", 30, "Horde") == nil)
-- Tempo
IsMounted = function() return false end
known = {}
assert(G.Speed("SHAMAN") == 7)
known[2645] = true
assert(math.abs(G.Speed("SHAMAN") - 9.8) < .01, "Geisterwolf")
assert(G.Speed("MAGE") == 7, "fremder Tempo-Zauber zaehlt nicht")
IsMounted = function() return true end
assert(G.Speed("MAGE") == 11)
-- Texte
local tp = {kind = "travel", via = {kind = "hearth", port = "teleport", name = "Teleportieren: Orgrimmar", spell = 3567, save = 9}, walk = .6, actions = {}}
assert(G.TravelText(tp.via):find("Teleportieren: Orgrimmar benutzen"), G.TravelText(tp.via))
assert(G:StepWho(tp):find("spart ca. 9 min"))
assert(Tr:NowEta(tp):find("mit Teleportieren: Orgrimmar"), Tr:NowEta(tp))
local rc = {kind = "hearth", port = "recall", name = "Astraler Ruf", place = "Crossroads"}
assert(G.TravelText(rc):find("Astraler Ruf nach Crossroads benutzen"))
assert(G.TravelText({kind = "hearth", place = "Crossroads"}):find("Ruhestein nach Crossroads"), "Ruhestein wie bisher")
local learn = {kind = "train", group = "portal", name = "Thuul", lvl = 20, actions = {}}
assert(G:StepText(learn):find("Teleport lernen") and G:StepWho(learn):find("Portallehrer Thuul"))
print("OK test_classtravel_137")
