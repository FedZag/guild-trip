-- Offline-Test: Quests automatisch annehmen/abgeben (ONE_Leveling/AutoQuest) + Haendler (ONE_Core/Vendor).
local root = arg[1] or "src"
local now = {}
C_Timer = {After = function(_, fn) now[#now + 1] = fn end}
local function RunTimers() local t = now now = {} for _, fn in ipairs(t) do fn() end end
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function(self, _, fn) self.fn = fn end} end
strsplit = function(sep, s) local out = {} for part in (s .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end return unpack(out) end
local shift = false
IsShiftKeyDown = function() return shift end
local printed = {}
local ONE = {db = {}, features = {}, ns = {}}
_G.ProjectONE = ONE
function ONE:Print(m) printed[#printed + 1] = m end
function ONE:IsEnabled() return true end
function ONE:RegisterFeature(id, def) self.features[id] = def return true end
function ONE:FeatureOn(id)
    local def = self.features[id]
    if def and def.get then return def.get() and true or false end
    return not (self.db.features and self.db.features[id] == false)
end
function ONE:SetFeature(id, on) local def = self.features[id] if def and def.set then def.set(on) return end self.db.features = self.db.features or {} self.db.features[id] = on end

-- ===== Quests =====
local lev = {Guide = {plan = {chosen = {[100] = "xp", [200] = "pre"}}}}
lev.Guide.DB = function() ONE.db.leveling = ONE.db.leveling or {} return ONE.db.leveling end
lev.Guide.Title = function(id) return ({[100] = "Wolfsjagd", [200] = "Briefe"})[id] or ("#" .. id) end
assert(loadfile(root .. "/ONE_Leveling/AutoQuest.lua"))("ONE_Leveling", lev)
local A = lev.AutoQuest
local log, done = {[300] = 1}, {}
C_QuestLog = {GetLogIndexForQuestID = function(id) return log[id] end, GetQuestTagInfo = function() return nil end}
local current, accepted, completed, reward, selected = 0, {}, 0, nil, nil
GetQuestID = function() return current end
GetTitleText = function() return "" end
AcceptQuest = function() accepted[#accepted + 1] = current end
IsQuestCompletable = function() return true end
CompleteQuest = function() completed = completed + 1 end
GetQuestReward = function(i) reward = i end
UnitGUID = function() return "Creature-0-0-0-0-1234-0" end
-- 0) Standard: aus
current = 100 A:OnDetail() assert(#accepted == 0, "standardmaessig aus")
ONE.db.leveling.autoQuest = true
-- 1) eingeplante Quest annehmen, andere nicht
current = 100 A:OnDetail() assert(accepted[1] == 100)
current = 999 A:OnDetail() assert(#accepted == 1, "nicht eingeplant")
-- "alle" an: nicht-graue fremde Quest ja
ONE.db.leveling.autoQuestAll = true
current = 999 A:OnDetail() assert(accepted[2] == 999)
ONE.db.leveling.autoQuestAll = nil
-- Begleitquest nie
C_QuestLog.GetQuestTagInfo = function() return {tagID = 84} end
current = 200 A:OnDetail() assert(#accepted == 2, "Begleitquest nicht automatisch")
C_QuestLog.GetQuestTagInfo = function() return nil end
-- 2) Shift: fuer das Gespraech aus, nach dem Schliessen wieder an
shift = true current = 200 A:OnDetail() shift = false
A:OnDetail() assert(#accepted == 2, "Shift haelt fuer das Gespraech")
A:Closed() RunTimers()
A:OnDetail() assert(accepted[3] == 200, "danach wieder automatisch")
-- 3) Abgeben nur aus dem eigenen Log
current = 300 A:OnProgress() assert(completed == 1)
current = 301 A:OnProgress() assert(completed == 1, "nicht im Log")
-- 4) Belohnung: eine -> abgeben; mehrere -> immer selbst waehlen (Nutzer 17.11.2026)
local choices = 1
GetNumQuestChoices = function() return choices end
current = 300 A:OnComplete() assert(reward == 1)
choices, reward = 3, nil
A:OnComplete() assert(reward == nil, "mehrere Belohnungen: der Spieler waehlt")
-- 5) Gossip: fertige Quest zuerst abgeben, dann eingeplante waehlen
local pickedActive, pickedAvail
C_GossipInfo = {
    GetActiveQuests = function() return {{questID = 300, isComplete = true}} end,
    GetAvailableQuests = function() return {{questID = 999, title = "x"}, {questID = 100, title = "Wolfsjagd"}} end,
    SelectActiveQuest = function(id) pickedActive = id end, SelectAvailableQuest = function(id) pickedAvail = id end}
A:OnGossip() assert(pickedActive == 300 and not pickedAvail)
C_GossipInfo.GetActiveQuests = function() return {} end
A:OnGossip() assert(pickedAvail == 100, "eingeplante gewaehlt")
-- 6) gesperrter NPC (Spenden/Ruf): nichts
UnitGUID = function() return "Creature-0-0-0-0-15764-0" end
pickedAvail = nil A:OnGossip() assert(not pickedAvail)
UnitGUID = function() return nil end
-- 7) abgeschaltet
ONE.db.leveling.autoQuest = false
current = 100 local before = #accepted A:OnDetail() assert(#accepted == before)

-- ===== Haendler =====
ONE.RegisterFeature = ONE.RegisterFeature
assert(loadfile(root .. "/ONE_Core/Vendor.lua"))("ONE_Core", ONE)
local V = ONE.Vendor
local repairCost, money, repaired, guildPaid = 1234, 100000, 0, false
CanMerchantRepair = function() return true end
GetRepairAllCost = function() return repairCost, repairCost > 0 end
GetMoney = function() return money end
RepairAllItems = function(guild) if guild then guildPaid = true end repaired = repaired + 1 repairCost = 0 end
CanGuildBankRepair = function() return false end
-- Taschen: 15 graue, 1 ohne Wert, 1 weiss
local bags = {}
for i = 1, 15 do bags[i] = {quality = 0, itemID = 500 + i, stackCount = 2} end
bags[16] = {quality = 0, itemID = 600, hasNoValue = true}
bags[17] = {quality = 1, itemID = 700}
local sold = {}
C_Container = {GetContainerNumSlots = function(bag) return bag == 0 and 17 or 0 end,
    GetContainerItemInfo = function(_, slot) return bags[slot] end,
    UseContainerItem = function(_, slot) sold[#sold + 1] = slot end}
GetItemInfo = function(id) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, (id == 600 and 0) or 5 end
printed = {}
V:OnMerchant()
assert(repaired == 0 and #sold == 0, "standardmaessig aus")
ONE:SetFeature("core.autoRepair", true) ONE:SetFeature("core.sellJunk", true)
V:OnMerchant()
assert(repaired == 1 and printed[1]:find("Repariert"), "repariert")
assert(#sold == V.BATCH, "erste Portion")
RunTimers()
assert(#sold == 15 and printed[#printed]:find("15") , "alle grauen verkauft, Rest bleibt")
-- Haendler zu: Rest bleibt liegen
sold = {} V.open = false
V:SellJunk() assert(#sold == 0)
-- Shift beim Oeffnen: nichts
repairCost = 50 shift = true V:OnMerchant() shift = false
assert(repaired == 1 and #sold == 0)
-- zu wenig Geld
money = 10 printed = {} V:OnMerchant() assert(repaired == 1 and printed[1]:find("so viel Geld"))
-- Gildengeld zuerst
money = 100000 CanGuildBankRepair = function() return true end
ONE.features["core.autoRepairGuild"].set(true)
V:OnMerchant() assert(guildPaid and printed[#printed - 1]:find("Gildengeld") or printed[#printed]:find("Gildengeld"))
-- abgeschaltet
ONE:SetFeature("core.autoRepair", false) ONE:SetFeature("core.sellJunk", false)
repairCost = 99 sold = {} local r0 = repaired
V:OnMerchant() assert(repaired == r0 and #sold == 0)
print("OK: Auto-Quests + Haendler")
