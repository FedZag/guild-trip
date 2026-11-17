-- Offline-Test: Ausruestung bewerten (besser/schlechter fuer die eigene Ausrichtung).
local root = arg[1] or "src"
local ONE = {db = {}}
_G.ProjectONE = ONE
local c = {}
assert(loadfile(root .. "/ONE_Classes/Data.lua"))("ONE_Classes", c)
assert(loadfile(root .. "/ONE_Classes/DataClasses.lua"))("ONE_Classes", c)
assert(loadfile(root .. "/ONE_Classes/Gear.lua"))("ONE_Classes", c)
local G = c.Gear
local items = {
    ["item:1"] = {ITEM_MOD_INTELLECT_SHORT = 3, RESISTANCE0_NAME = 14},       -- Federleichte Armschienen (angelegt)
    ["item:2"] = {ITEM_MOD_STAMINA_SHORT = 4, RESISTANCE0_NAME = 15},         -- Gruenzwirarmschienen der Ausdauer
    ["item:3"] = {ITEM_MOD_INTELLECT_SHORT = 4, ITEM_MOD_SPIRIT_SHORT = 3},   -- klar besser
    ["item:4"] = {ITEM_MOD_STRENGTH_SHORT = 5, RESISTANCE0_NAME = 120},       -- Platte
}
local info = {[1] = {"INVTYPE_WRIST", 4, 1}, [2] = {"INVTYPE_WRIST", 4, 1}, [3] = {"INVTYPE_WRIST", 4, 1}, [4] = {"INVTYPE_WRIST", 4, 4}}
GetItemStats = function(link) return items[link:match("item:%d+")] end
GetItemInfoInstant = function(id) local i = info[tonumber(id)] return id, "", "", i[1], 0, i[2], i[3] end
local worn = {[9] = "item:1"}
GetInventoryItemLink = function(_, slot) return worn[slot] end
local def = c.Data.classes.PRIEST
local p = {classFile = "PRIEST", spec = 3}
local build = c.Data:Build(def, 3, "solo")
assert(G:Judge("item:2", p, def, build).verdict == "worse", "Ausdauer statt Intelligenz ist fuer Schatten schlechter")
assert(G:Judge("item:3", p, def, build).verdict == "better")
assert(G:Judge("item:1", p, def, build) == nil, "das angelegte Teil selbst bekommt keine Zeile")
assert(G:Judge("item:4", p, def, build).verdict == "cannot", "Platte fuer Priester")
assert(G:Line(G:Judge("item:2", p, def, build)):find("schlechter für dich – −3 Intelligenz (dein Wert Nr. 2)", 1, true))
-- Krieger (Waffen): Staerke zaehlt, Platte darf
local wdef = c.Data.classes.WARRIOR
local wp = {classFile = "WARRIOR", spec = 1}
local wb = c.Data:Build(wdef, 1, "solo")
worn = {[9] = "item:3"}
assert(G:Judge("item:4", wp, wdef, wb).verdict == "better", "Staerke-Platte fuer Krieger besser als Intelligenz")
-- leerer Platz
worn = {}
assert(G:Judge("item:3", p, def, build).verdict == "new")
print("OK test_gear_080")
-- Rueckfall: keine Werte-Abfrage, Werte aus den Tooltip-Zeilen
GetItemStats = nil
C_TooltipInfo = {GetHyperlink = function(link)
    if link == "item:2" then return {lines = {{leftText = "Grünzwirarmschienen der Ausdauer"}, {leftText = "15 Rüstung"}, {leftText = "+4 Ausdauer"}}} end
    if link == "item:1" then return {lines = {{leftText = "Federleichte Armschienen"}, {leftText = "14 Rüstung"}, {leftText = "+3 Intelligenz"}}} end
    if link == "item:5" then return {lines = {{leftText = "Anlegen: Erhöht durch Zauber und magische Effekte zugefügten Schaden und Heilung um bis zu 12."}}} end
    return {lines = {}} end}
local st = G.Stats("item:2")
assert(st.sta == 4 and st.armor == 15, "aus dem Tooltip gelesen")
assert(G.Stats("item:5").sp == 12 or G.Stats("item:5").heal == 12, "Anlegen-Effekt erkannt")
worn = {[9] = "item:1"}
assert(G:Judge("item:2", p, def, build).verdict == "worse", "auch ohne GetItemStats: schlechter fuer Schatten")
print("OK test_gear_080 (Tooltip-Rueckfall)")
-- Verzauberung auf dem getragenen Teil: zaehlt mit, Hinweis wenn nur sie den Ausschlag gibt
C_TooltipInfo.GetInventoryItem = function(_, slot)
    if slot == 9 then return {lines = {{leftText = "Federleichte Armschienen"}, {leftText = "14 Rüstung"},
        {leftText = "+3 Intelligenz"}, {leftText = "Verzaubert: +5 Willenskraft"}}} end
end
local full, ench = G.WornStats(9, "item:1")
assert(full.spi == 5 and full.int == 3 and ench.spi == 5 and not ench.int, "Verzauberung erkannt")
items["item:6"] = nil
C_TooltipInfo.GetHyperlink = function(link)
    if link == "item:6" then return {lines = {{leftText = "+5 Intelligenz"}}} end
    return {lines = {}} end
info[6] = {"INVTYPE_WRIST", 4, 1}
local r = G:Judge("item:6", p, def, build)
assert(r.verdict == "worse" and r.enchantFlip, "ohne Verzauberung besser, mit ihr schlechter")
assert(G:Line(r):find("Verzauberung", 1, true))
print("OK test_gear_080 (Verzauberung)")
-- Warum-Zeile: Wert-Unterschiede nach Gewicht sortiert
local reasons = G.Reasons({spi = 4, sta = 2, armor = 19}, {sp = 2, armor = 14}, G.Weights(build, "caster"))
assert(reasons[1].key == "spi" and reasons[1].delta == 4, "Willenskraft zaehlt fuer Schatten am meisten")
local why = G.ReasonLine({reasons = reasons})
assert(why:find("+4 Willenskraft", 1, true) and why:find("−2 Zauberschaden", 1, true), why)
-- Eine Zeile mit dem entscheidenden Grund
local rr = {verdict = "better", reasons = reasons, rank = G.Ranks(build), spec = "Schatten"}
assert(G:Line(rr):find("besser für dich – +4 Willenskraft (dein wichtigster Wert)", 1, true), G:Line(rr))
worn = {[9] = "item:1"}
C_TooltipInfo.GetInventoryItem = nil
C_TooltipInfo.GetHyperlink = function(link)
    if link == "item:2" then return {lines = {{leftText = "+4 Ausdauer"}}} end
    if link == "item:1" then return {lines = {{leftText = "+3 Intelligenz"}}} end
    return {lines = {}} end
local line = G:Line(G:Judge("item:2", p, def, build))
assert(line:find("schlechter für dich – −3 Intelligenz (dein Wert Nr. 2)", 1, true), line)
print("OK test_gear_080 (Warum)")
