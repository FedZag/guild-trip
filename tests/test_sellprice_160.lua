-- Offline-Test 0.8.0: Verkaufspreis im Gegenstands-Tooltip (Gesamtpruefung 23.11.2026).
local root = arg[1] or "src"
local ONE = {db = {}, features = {}}
ONE.T = function(t, ...) if select("#", ...) > 0 then return t:format(...) end return t end
function ONE:RegisterFeature(id, def) self.features[id] = def end
function ONE:FeatureOn(id) return self.features[id].get() end
assert(loadfile(root .. "/ONE_Core/Vendor.lua"))("ONE_Core", ONE)
local V = ONE.Vendor
local f = ONE.features["core.sellPrice"]
assert(f and f.get() == true, "Anzeige: Standard an")
GetCoinTextureString = function(c) return "M" .. c end
GetItemInfo = function(link)
    local price = ({["item:1"] = 125, ["item:2"] = 0})[link]
    return "Name", link, 1, 1, 1, "", "", 1, "", 1, price
end
C_Item = {GetItemLocation = function(guid) return guid == "stack" and {} or nil end, GetStackCount = function() return 20 end}
local function Tip(link, money)
    local t = {lines = {}, shownMoneyFrames = money}
    function t:GetItem() return "Name", link end
    function t:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. "=" .. r end
    function t:Show() end
    return t
end
-- 1) Einzeln
local t = Tip("item:1")
assert(V:OnTooltip(t) and t.lines[1] == "Verkaufspreis=M125", t.lines[1])
-- 2) Stapel aus der Tasche
t = Tip("item:1")
assert(V:OnTooltip(t, {guid = "stack"}) and t.lines[1]:find("^Verkaufspreis=M2500") and t.lines[1]:find("20 Stück", 1, true), t.lines[1])
-- 3) Kein Wert, unbekannter Gegenstand, WoW zeigt selbst einen Preis: nichts
assert(not V:OnTooltip(Tip("item:2")) and not V:OnTooltip(Tip("item:9")))
t = Tip("item:1", 1)
assert(not V:OnTooltip(t) and #t.lines == 0, "am Haendler nicht doppelt")
-- 4) Schalter aus
f.set(false)
assert(not V:OnTooltip(Tip("item:1")) and ONE.db.sellPrice == false)
print("OK test_sellprice_160")
