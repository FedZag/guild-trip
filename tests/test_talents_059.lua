-- Offline-Test 0.6.0: Talentpunkte nach Plan setzen (halbautomatisch).
local root = arg[1] or "src"
CreateFrame = function()
    local f = {events = {}}
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.onEvent = fn end
    return f
end
local combat = false
InCombatLockdown = function() return combat end
UnitClass = function() return "Priester", "PRIEST" end
UnitLevel = function() return 20 end
C_Spell = {GetSpellInfo = function(id) local n = ({[15270] = "Willensentzug", [15275] = "Verb. Schmerz", [15260] = "Schattenfokus",
    [15273] = "Verb. Gedankenschlag", [14524] = "Zauberstab-Spez.", [14914] = "Heiliges Feuer"})[id]; return n and {name = n, iconID = id} end}
-- Schatten-Talentbaum (Ausschnitt)
local nodes = {
    [1] = {spell = 15260, x = 9080, y = 2130, ranks = 5, max = 5, canBuy = false},
    [2] = {spell = 15270, x = 10280, y = 2130, ranks = 0, max = 5, canBuy = true},
    [3] = {spell = 15275, x = 10280, y = 2730, ranks = 2, max = 2, canBuy = false},
    [4] = {spell = 15273, x = 9080, y = 2730, ranks = 4, max = 5, canBuy = true},
    [5] = {spell = 14524, x = 1620, y = 2130, ranks = 0, max = 2, canBuy = true},  -- Disziplin
    [6] = {spell = 14914, x = 5020, y = 2130, ranks = 0, max = 1, canBuy = true},  -- Heilig
    [7] = {spell = 15270, x = 102800, y = 5740, ranks = 0, max = 5, canBuy = false}, -- versteckter Doppel-Knoten
}
local free = 1
local purchases, commits, purchaseWorks = {}, 0, true
local immediate, staged = true, nil -- immediate: Forever uebernimmt sofort; sonst erst bei CommitConfig
C_ClassTalents = {GetActiveConfigID = function() return 77 end, CommitConfig = function(cfg)
    commits = commits + 1
    if staged then nodes[staged].ranks = nodes[staged].ranks + 1; free = free - 1; staged = nil end
    return cfg == 77 end}
C_Traits = {
    GetConfigInfo = function() return {treeIDs = {5}} end,
    GetTreeNodes = function() return {7, 1, 2, 3, 4, 5, 6} end,
    GetNodeInfo = function(_, id) local n = nodes[id]; return {entryIDs = {id * 10}, ranksPurchased = n.ranks, maxRanks = n.max,
        posX = n.x, posY = n.y, canPurchaseRank = n.canBuy and free > 0} end,
    GetEntryInfo = function(_, e) return {definitionID = e} end,
    GetDefinitionInfo = function(d) return {spellID = nodes[d / 10].spell} end,
    GetTreeCurrencyInfo = function() return {{quantity = free}} end,
    PurchaseRank = function(cfg, node)
        purchases[#purchases + 1] = {cfg, node}
        if not purchaseWorks then return false end
        if immediate then
            nodes[node].ranks = nodes[node].ranks + 1
            free = free - 1
        else
            staged = node
        end
        return true
    end,
}
local ONE = {db = {}}
_G.ProjectONE = ONE
local printed = {}
function ONE:Print(m) printed[#printed + 1] = m end
local alerts = {}
ONE.MinimapButton = {SetAlert = function(_, id, text) alerts[id] = text end, ClearAlert = function(_, id) alerts[id] = nil end}
local confirmed
local c = {}
for _, f in ipairs({"Data.lua", "Player.lua", "Talents.lua"}) do assert(loadfile(root .. "/ONE_Classes/" .. f))("ONE_Classes", c) end
c.Player.maxAge = 0 -- Test aendert Zauber/Talente ohne Spielereignisse: Zwischenspeicher aus
assert(c.Player:Talents()[15270].node == 2, "versteckter Doppel-Knoten ausserhalb des Baums wird ignoriert")
c.Bars = {Confirm = function(_, text, ok) confirmed = text ok() end}
local Tl = c.Talents

-- 1) Freier Punkt: Hinweis im Chat und am Minimap-Knopf, nicht doppelt
local p, step, t = Tl:Next()
assert(p.free == 1 and step[1] == 15270 and t.node == 2, "naechster Schritt: Willensentzug")
Tl:Check()
assert(printed[#printed]:find("Talentpunkt frei: Willensentzug (Rang 1/5)", 1, true) and alerts.talent, "Hinweis")
local n = #printed
Tl:Check()
assert(#printed == n and #purchases == 0, "kein doppelter Hinweis, nichts automatisch gesetzt")

-- 2) Knopf: Rueckfrage, dann genau ein Punkt
Tl:AskAndSpend()
assert(confirmed:find("Willensentzug (Rang 0 › 1)", 1, true) and confirmed:find("Gold", 1, true), "Rueckfrage nennt Talent und Kosten")
assert(#purchases == 1 and purchases[1][1] == 77 and purchases[1][2] == 2 and commits == 0 and nodes[2].ranks == 1,
    "Forever uebernimmt sofort: keine Bestaetigung hinterher")
assert(printed[#printed]:find("Talentpunkt gesetzt: Willensentzug (Rang 1)", 1, true))
-- 3) Kein freier Punkt mehr: Hinweis verschwindet, Knopf meldet "keiner frei"
Tl:Check()
assert(alerts.talent == nil)
assert(Tl:AskAndSpend() == false and printed[#printed]:find("keinen freien Talentpunkt", 1, true))

-- 4) Automatik (Standard aus) setzt bei freiem Punkt selbst
assert(not Tl:AutoEnabled())
free = 2
Tl:SetAutoEnabled(true)
assert(#purchases == 2 and nodes[2].ranks == 2, "Automatik setzt einen Punkt")
Tl:Check()
assert(#purchases == 3 and nodes[2].ranks == 3 and free == 0, "naechster Punkt bei der naechsten Rueckmeldung")
Tl:SetAutoEnabled(false)

-- 5) Im Kampf: warten
free = 1
combat = true
Tl:Check()
assert(Tl.waiting and #purchases == 3)
combat = false

-- 5b) Spiel uebernimmt erst nach Bestaetigung (neues Talentsystem): dann wird bestaetigt
immediate = false
free = 1
local before = commits
Tl:AskAndSpend()
assert(commits == before + 1 and nodes[2].ranks == 4, "vorgemerkt -> bestaetigt")
free = 1
Tl:AskAndSpend()
assert(commits == before + 2 and nodes[2].ranks == 5)
immediate = true
-- Knoten, der (noch) nicht kaufbar ist: kein Knopf
free = 1
local p3, s3, t3 = Tl:Next()
assert(s3[1] ~= 15270, "Willensentzug fertig – naechster Schritt")
assert(not Tl:CanSpend(p3, s3, t3) == (t3.canBuy ~= true), "nur kaufbare Knoten")

-- 5c) Ohne ConfigHasStagedChanges (wie offenbar in Forever): Rang ist sofort gestiegen -> keine Bestaetigung
C_Traits.ConfigHasStagedChanges = nil
nodes[4].ranks = 4
free = 1
local beforeCommits = commits
local ok = Tl:Spend(select(3, Tl:Next()))
assert(ok and commits == beforeCommits, "Rang gestiegen: keine Bestaetigung")

-- 6) Forever sperrt das Setzen: einmal sagen, danach nur anzeigen
purchaseWorks = false
free = 1
nodes[4].ranks = 3 -- noch ein offener Schritt im Plan
Tl:AskAndSpend()
assert(printed[#printed]:find("Forever lässt Guild Trip keine Talentpunkte setzen", 1, true) and Tl.blocked)
local p2, s2, t2 = Tl:Next()
assert(not Tl:CanSpend(p2, s2, t2), "gesperrt: kein Knopf mehr")
n = #printed
Tl:Check()
assert(#printed == n, "gesperrt: kein weiterer Hinweis")
print("OK test_talents_059")
