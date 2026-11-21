-- Offline-Test: Aufstieg vorausrechnen (Nutzer 20.11.2026, wie RestedXP "toete Monster bis 2800/5000 EP"):
-- vor dem Weggehen hier Monster hauen, wenn hier mit der naechsten Stufe etwas frei wird und nur wenig fehlt;
-- Abgabe zeigt "danach Stufe X"; EP unterwegs zaehlen mit; was hier bereit ist, wird vor dem Weggehen angenommen.
local root = arg[1] or "src"
local function Fresh()
    GuildTripQuestDB = {
        q = {
            -- {stufe, mindest, volk, klasse, vorq, geber, abgabe, ziele, vorq_alle, schliesst_aus, EP, naechste, max, gebiet}
            [1] = {15, 10, 0, 0, false, {11}, {11}, {}, false, false, 1000, 0, 0, 1},  -- fertig im Log, Abgabe hier
            [2] = {16, 16, 0, 0, false, {11}, {11}, {}, false, false, 1000, 0, 0, 1},  -- ab Stufe 16, gleicher Geber
            [3] = {15, 10, 0, 0, false, {13}, {13}, {}, false, false, 1000, 0, 0, 1},  -- weit weg
        },
        n = {[11] = {0, 1, 100, 100}, [13] = {0, 1, 400, 100}},
    }
end
Fresh()
GuildTripLeveling = {r = {}, i = {}, dz = {}}
local lev = {}
assert(loadfile(root .. "/ONE_Leveling/Planner.lua"))("ONE_Leveling", lev)
local P = lev.Planner
local function World(m, x, y) return 1, x * 10000, y * 10000 end
local function Ctx(xp)
    return {me = {level = 15, xp = xp, xpMax = 14400, class = 128, faction = "Horde", mapID = 1, x = .1, y = .1},
        done = function() return false end, inLog = function(id) return id == 1 end, complete = function(id) return id == 1 end,
        world = World, tempo = "all", speed = 7}
end
local function Keys(plan) return table.concat(plan.orderKeys, " ") end
-- EP der Abgabe hier
local probe = assert(P:Plan(Ctx(0)))
local turnXP = probe.info[1].xp
-- 1) kurz vor dem Aufstieg: erst hier Monster hauen, dann abgeben (= Aufstieg), dann die neue Quest annehmen
local xp = math.floor(14400 - turnXP - 2000)
local plan = assert(P:Plan(Ctx(xp)))
local k = Keys(plan)
local g, t1, a2, a3 = k:find("grind:16"), k:find("turnin:1"), k:find("accept:2"), k:find("accept:3")
assert(g and t1 and a2 and a3 and g < t1 and t1 < a2 and a2 < a3, "hauen, abgeben, neue Quest, dann weg: " .. k)
local gs
for _, st in ipairs(plan.steps) do if st.kind == "grind" then gs = st break end end
assert(gs and gs.hub and gs.maxXP == 14400, "Hauen-Schritt mit EP-Ziel")
assert(math.abs(gs.toXP - (14400 - turnXP)) <= 2, ("bis %d / %d EP (erwartet %d)"):format(gs.toXP, gs.maxXP, 14400 - turnXP))
local ts
for _, st in ipairs(plan.steps) do for _, a in ipairs(st.actions) do if a.kind == "turnin" and a.id == 1 then ts = st end end end
assert(ts and ts.levelUp == 16, "Abgabe bringt Stufe 16")
-- 2) noch weit weg vom Aufstieg (mehr als ein Viertel Stufe): kein Hauen, normal weiter
plan = assert(P:Plan(Ctx(2000)))
for _, st in ipairs(plan.steps) do assert(not st.hub, "zu viel Hauen hier: nicht " .. Keys(plan)) end
assert(plan.orderKeys[1] == "turnin:1", "normal weiter: " .. Keys(plan))
-- 3) EP unterwegs zaehlen mit: der Plan bringt mehr EP als die Quests allein
plan = assert(P:Plan(Ctx(0)))
local quests = 0
for _, o in pairs(plan.info) do if plan.chosen[o.id] then quests = quests + o.xp end end
assert(plan.xp > quests, ("EP unterwegs: %.0f > %.0f"):format(plan.xp, quests))
-- 4) was hier bereit ist, wird vor dem Weggehen angenommen
GuildTripQuestDB.q[2][2] = 10
plan = assert(P:Plan(Ctx(0)))
k = Keys(plan)
assert(k:find("accept:2") < k:find("accept:3"), "erst hier annehmen, dann weg: " .. k)
Fresh()

-- ===== Anzeige =====
GetLocale = function() return "deDE" end
local function Stub() return setmetatable({}, {__index = function() return function() end end}) end
CreateFrame = function() return Stub() end
UIParent = Stub()
local ONE = {db = {}, modules = {}, ns = {}}
_G.ProjectONE = ONE
local L2 = {}
for _, f in ipairs({"Planner", "Guide", "Tracker"}) do assert(loadfile(root .. "/ONE_Leveling/" .. f .. ".lua"))("ONE_Leveling", L2) end
local G, Tr = L2.Guide, L2.Tracker
local grind = {kind = "grind", lvl = 16, hub = true, fromXP = 10000, toXP = 12300, maxXP = 14400, work = 4, actions = {}}
assert(G:StepText(grind):find("Monster hauen bis 12300 / 14400 EP"), G:StepText(grind))
assert(G:StepWho(grind):find("danach Stufe"))
UnitXP = function() return 11800 end
assert(Tr:NowEta(grind):find("noch 500 EP"), Tr:NowEta(grind))
local up = {kind = "turnin", nr = 11, levelUp = 16, actions = {{kind = "turnin", id = 1}}}
G.NodeName = function() return "Tonga" end
assert(Tr.NowWho(up):find("danach Stufe 16"), Tr.NowWho(up))
-- Neuplanen erst, wenn das EP-Ziel erreicht ist
G.plan = {steps = {grind}}
assert(G:Wants("PLAYER_XP_UPDATE") == false, "noch nicht erreicht")
UnitXP = function() return 12300 end
assert(G:Wants("PLAYER_XP_UPDATE") == true, "Ziel erreicht: neu planen")
print("OK test_aufstieg_141")
