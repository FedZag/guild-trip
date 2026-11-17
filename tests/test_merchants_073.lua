-- Offline-Test: Haendler-Verzeichnis (einsortieren, sammeln, teilen nur mit Haekchen, filtern).
local root = arg[1] or "src"
local sent = {}
C_ChatInfo = {RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(_, msg) sent[#sent + 1] = msg return true end}
C_Timer = {After = function(_, fn) fn() end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
GetTime = function() return 1 end
UnitName = function(u) return u == "npc" and "Jeena Featherbow" or "Hordi" end
UnitFullName = function() return "Hordi", "" end
UnitFactionGroup = function() return "Horde" end
UnitGUID = function() return "Creature-0-1-2-3-3610-0000" end
IsInGuild = function() return true end
-- Angebot: Phiole, Faden, Brot, Pfeile, Rezept, Reparatur
local offer = {{3371, "Leere Phiole", 7, 11}, {2320, "Grober Faden", 7, 5}, {4540, "Zähes Trockenfleisch", 0, 5},
    {2512, "Grober Pfeil", 6, 2}, {9999, "Rezept: Etwas", 9, 6}}
GetMerchantNumItems = function() return #offer end
GetMerchantItemID = function(i) return offer[i][1] end
GetMerchantItemInfo = function(i) return offer[i][2] end
GetItemInfoInstant = function(id) for _, o in ipairs(offer) do if o[1] == id then return id, "", "", "", 0, o[3], o[4] end end end
CanMerchantRepair = function() return true end
local ONE = {db = {}}
function ONE:Print() end
local shareOpt
ONE.UI = {AddShareOption = function(_, o) if o.id == "merchants" then shareOpt = o end return true end}
_G.ProjectONE = ONE
local nav = {Travel = {PlayerMapPosition = function() return 1454, .45, .65 end}}
for _, f in ipairs({"QuestShare", "QuestGivers", "Merchants"}) do assert(loadfile(root .. "/ONE_Nav/" .. f .. ".lua"))("ONE_Nav", nav) end
local M = nav.Merchants
M:Initialize()
assert(M.Classify(3372, 7, 11) == "vial" and M.Classify(1, 0, 5) == "food" and M.Classify(1, 7, 1) == "trade")
assert(M.Classify(1, 11, 2) == "ammo" and M.Classify(1, 4, 0) == "misc" and M.Classify(1, 4, 2) == "armor")

-- 1) Haendler oeffnen -> gemerkt, ohne Haekchen nichts gesendet
M:OnShow()
local m = ONE.db.nav.merchants.c3610
assert(m and m.name == "Jeena Featherbow" and m.mapID == 1454 and m.x == .45)
for _, c in ipairs({"vial", "thread", "food", "ammo", "recipe", "repair"}) do assert(m.cats[c], c) end
assert(m.items.vial[1] == "Leere Phiole")
assert(#sent == 0, "ohne Haekchen nichts teilen")

-- 2) Filter
assert(#M:List("vial") == 1 and #M:List("weapon") == 0 and #M:List("all") == 1)
assert(M.CatText(m.cats) == "Phiolen · Faden & Farbstoffe · Essen & Trinken · Munition & Köcher · Rezepte · Reparieren", M.CatText(m.cats))

-- 3) Mit Haekchen: Nachricht ohne Gegenstandsnamen, Empfang bei anderen
shareOpt.set(true)
offer[#offer + 1] = {2901, "Spitzhacke", 7, 0}
M:OnShow()
nav.QuestShare:Flush(5)
local msg = sent[#sent]
assert(msg and msg:find("^MV|c3610|Jeena Featherbow|1454|450|650|Horde|vial,thread,trade,food,ammo,recipe,repair$"), msg)
ONE.db.nav.merchants = {}
nav.QuestShare:Receive("ONEQST1", msg, "GUILD", "Thrall")
assert(#M:List("trade") == 1 and M:List("trade")[1].name == "Jeena Featherbow")
-- andere Fraktion nicht zeigen
nav.QuestShare:Receive("ONEQST1", "MV|c99|Allianzler|1453|100|100|Alliance|vial", "GUILD", "Thrall")
assert(#M:List("vial") == 1)
print("OK test_merchants_073")
