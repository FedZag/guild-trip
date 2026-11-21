-- Offline-Test 0.7.4: Schrott beim Haendler verkaufen – neuer Client (C_Container/C_Item),
-- alter Client (GetContainerItemInfo mit vielen Werten), noch nicht geladene Preise, Standard aus.
local root = arg[1] or "src"
local printed = {}
local ONE = {db = {}, features = {}, featureOrder = {}, slashCommands = {}, slashOrder = {}}
function ONE:Print(s) printed[#printed + 1] = s end
function ONE:IsEnabled() return true end
function ONE:RegisterFeature(id, def) self.features[id] = def return true end
function ONE:FeatureOn(id) local d = self.features[id] return d and d.get() and true or false end
function ONE:RegisterSlash(name, fn) self.slashCommands[name] = fn return true end
_G.ProjectONE = ONE
local handler
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function(_, _, fn) handler = fn end} end
IsShiftKeyDown = function() return false end
CanMerchantRepair = function() return false end
local timers = {}
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function RunTimers() while #timers > 0 do table.remove(timers, 1)() end end

-- Taschen: Tasche 0 mit 4 Plaetzen
local bag = {
    [1] = {id = 100, q = 0, n = 3},            -- grau, Preis 5 -> 15
    [2] = {id = 200, q = 2, n = 1},            -- gruen, bleibt
    [3] = {id = 300, q = 0, n = 1, noValue = true}, -- grau ohne Wert
    [4] = {id = 400, q = 0, n = 1},            -- grau, Preis erst spaeter geladen
}
local prices = {[100] = 5, [200] = 99, [300] = 0, [400] = 7}
local loaded = {[100] = true, [200] = true, [300] = true}
local function Info(id)
    if not loaded[id] then return nil end
    local q = (id == 200) and 2 or 0
    return "Item" .. id, "link" .. id, q, 1, 1, "", "", 1, "", 1, prices[id]
end
local used = {}
local function Use(b, s) used[#used + 1] = b .. ":" .. s end

local function Setup(newClient)
    used, printed, timers = {}, {}, {}
    loaded = {[100] = true, [200] = true, [300] = true}
    if newClient then
        C_Container = {
            GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end,
            GetContainerItemInfo = function(b, s)
                local it = b == 0 and bag[s]
                if not it then return nil end
                return {itemID = it.id, quality = it.q, stackCount = it.n, hasNoValue = it.noValue, isLocked = false}
            end,
            UseContainerItem = Use}
        C_Item = {GetItemInfo = Info, RequestLoadItemDataByID = function(id) loaded[id] = true end}
        GetContainerItemInfo, GetContainerNumSlots, UseContainerItem, GetItemInfo = nil, nil, nil, nil
    else
        C_Container, C_Item = nil, nil
        GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end
        -- alter Client: texture, count, locked, quality, readable, lootable, link, filtered, noValue, itemID
        GetContainerItemInfo = function(b, s)
            local it = b == 0 and bag[s]
            if not it then return nil end
            return "tex", it.n, false, it.q, false, false, "link" .. it.id, false, it.noValue, it.id
        end
        UseContainerItem = Use
        GetItemInfo = Info
    end
end

assert(loadfile(root .. "/ONE_Core/Vendor.lua"))("ONE_Core", ONE)
local V = ONE.Vendor
V:Initialize()
assert(ONE.slashCommands.schrott, "Pruefbefehl /trip schrott")

for _, newClient in ipairs({true, false}) do
    local label = newClient and "neuer Client" or "alter Client"
    Setup(newClient)
    -- Standard aus: nichts verkaufen
    ONE.db.sellJunk = nil
    handler(nil, "MERCHANT_SHOW")
    RunTimers()
    assert(#used == 0, label .. ": Standard aus")
    handler(nil, "MERCHANT_CLOSED")

    -- eingeschaltet: 100 sofort bekannt, 400 erst nach Nachladen -> beide verkauft, 200/300 nicht
    ONE.db.sellJunk = true
    if not newClient then loaded[400] = true end -- alter Client: kein Nachladen, Preis direkt da
    handler(nil, "MERCHANT_SHOW")
    RunTimers()
    table.sort(used)
    assert(#used == 2 and used[1] == "0:1" and used[2] == "0:4", label .. ": verkauft " .. table.concat(used, ","))
    assert(printed[#printed]:find("2 Gegenst"), label .. ": Meldung " .. tostring(printed[#printed]))
    handler(nil, "MERCHANT_CLOSED")

    -- Haendler zu: Rest wird nicht mehr verkauft
    used, V.BATCH = {}, 1
    handler(nil, "MERCHANT_SHOW")
    handler(nil, "MERCHANT_CLOSED")
    RunTimers()
    V.BATCH = 10
    assert(#used == 1, label .. ": nach Schliessen " .. #used)

    -- Pruefbefehl laeuft und nennt Zahlen
    printed = {}
    ONE.slashCommands.schrott()
    assert(#printed == 3 and printed[1]:find("AN") and printed[3]:find("graue Gegenst%S+ 3"), label .. ": " .. table.concat(printed, " | "))
end
print("OK vendor")
