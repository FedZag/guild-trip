-- Guild Trip: beim Haendler automatisch reparieren und Schrott (graue Gegenstaende) verkaufen (0.6.9).
-- Vorbild wie bei Leatrix Plus & Co.: Shift beim Oeffnen = diesmal nichts tun; verkauft wird in kleinen
-- Portionen mit Pause (der Server verwirft sonst Verkaeufe), nur solange das Haendlerfenster offen ist;
-- Gegenstaende ohne Verkaufswert bleiben liegen. Reparieren wahlweise aus der Gildenbank.
local _, ONE = ...
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local V = {BATCH = 10, PAUSE = .3}
ONE.Vendor = V

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j, k end
end

if ONE.RegisterFeature then
    -- Standard aus (Nutzer 17.11.2026): erst auf Wunsch einschalten
    ONE:RegisterFeature("core.autoRepair", {label = "Beim Händler automatisch reparieren",
        tooltip = "Repariert alles, sobald du einen Händler mit Reparatur öffnest. Shift beim Öffnen = diesmal nicht.",
        get = function() return ONE.db and ONE.db.autoRepair == true end,
        set = function(on) if ONE.db then ONE.db.autoRepair = on and true or false end end})
    ONE:RegisterFeature("core.autoRepairGuild", {label = "… dabei zuerst das Gildengeld nutzen",
        tooltip = "Wenn deine Gilde dir Reparaturen bezahlt, zuerst aus der Gildenbank.",
        get = function() return ONE.db and ONE.db.autoRepairGuild == true end,
        set = function(on) if ONE.db then ONE.db.autoRepairGuild = on and true or false end end})
    ONE:RegisterFeature("core.sellJunk", {label = "Beim Händler Schrott verkaufen",
        tooltip = "Verkauft alle grauen Gegenstände beim Händler. Shift beim Öffnen = diesmal nicht.",
        get = function() return ONE.db and ONE.db.sellJunk == true end,
        set = function(on) if ONE.db then ONE.db.sellJunk = on and true or false end end})
end

function V.Money(copper)
    local fn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or rawget(_G, "GetCoinTextureString")
    local s = fn and Try(fn, copper)
    if s then return s end
    local g, si, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    return (g > 0 and (g .. "g ") or "") .. ((g > 0 or si > 0) and (si .. "s ") or "") .. c .. "c"
end

function V:Repair()
    if not ONE:FeatureOn("core.autoRepair") or not Try(CanMerchantRepair) then return 0 end
    local cost, can = Try(GetRepairAllCost)
    if not (can and cost and cost > 0) then return 0 end
    if ONE:FeatureOn("core.autoRepairGuild") and Try(CanGuildBankRepair) then
        Try(RepairAllItems, true)
        local left = Try(GetRepairAllCost) or 0
        if left == 0 then ONE:Print(T("Repariert für %s (Gildengeld).", V.Money(cost))) return cost end
    end
    if (Try(GetMoney) or 0) < cost then
        ONE:Print(T("Reparieren kostet %s – so viel Geld hast du nicht dabei.", V.Money(cost)))
        return 0
    end
    Try(RepairAllItems)
    ONE:Print(T("Repariert für %s.", V.Money(cost)))
    return cost
end

local function Container() return C_Container or {} end

-- Graue Gegenstaende mit Verkaufswert: {{bag, slot, wert}}
function V.Junk()
    local out = {}
    local C = Container()
    for bag = 0, 4 do
        local n = Try(C.GetContainerNumSlots or rawget(_G, "GetContainerNumSlots"), bag) or 0
        for slot = 1, n do
            local info = Try(C.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and info.quality == 0 and not info.hasNoValue and not info.isLocked and info.itemID then
                local price = select(11, Try(GetItemInfo, info.itemID)) or 0
                if price > 0 then out[#out + 1] = {bag, slot, price * (info.stackCount or 1)} end
            end
        end
    end
    return out
end

function V:SellJunk()
    if not ONE:FeatureOn("core.sellJunk") then return 0 end
    local list = V.Junk()
    if #list == 0 then return 0 end
    local total, i = 0, 1
    local C = Container()
    local use = C.UseContainerItem or rawget(_G, "UseContainerItem")
    local function Step()
        if not V.open then return end
        for _ = 1, V.BATCH do
            local it = list[i]
            if not it then
                ONE:Print(T("Schrott verkauft: %d Gegenstände für %s.", #list, V.Money(total)))
                return
            end
            Try(use, it[1], it[2])
            total = total + it[3]
            i = i + 1
        end
        if C_Timer and C_Timer.After then C_Timer.After(V.PAUSE, Step) else Step() end
    end
    Step()
    return #list
end

function V:OnMerchant()
    V.open = true
    if Try(IsShiftKeyDown) then return end
    self:Repair()   -- erst reparieren (Geld), dann verkaufen
    self:SellJunk()
end

function V:Initialize()
    if self.started then return end
    self.started = true
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "MERCHANT_SHOW")
    pcall(f.RegisterEvent, f, "MERCHANT_CLOSED")
    f:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_CLOSED" then V.open = false return end
        pcall(V.OnMerchant, V)
    end)
end
