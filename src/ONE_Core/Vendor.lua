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
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
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

local function Container() return rawget(_G, "C_Container") or {} end

-- Taschenplatz lesen: neuer Client (C_Container, Tabelle) oder alter (GetContainerItemInfo, viele Werte).
-- 0.7.4: vorher nur C_Container – fehlte das, wurde still nichts gefunden.
function V.SlotInfo(bag, slot)
    local C = Container()
    local info = Try(C.GetContainerItemInfo, bag, slot)
    if type(info) == "table" then return info end
    local old = rawget(_G, "GetContainerItemInfo")
    if type(old) ~= "function" then return nil end
    local tex, count, locked, quality, _, _, link, _, noValue, itemID = Try(old, bag, slot)
    if not tex and not link then return nil end
    return {iconFileID = tex, stackCount = count, isLocked = locked, quality = quality,
        hyperlink = link, hasNoValue = noValue, itemID = itemID}
end

-- Gegenstandsdaten: C_Item.GetItemInfo (neuer Client) oder GetItemInfo (alt)
local function ItemInfo(id)
    local fn = (rawget(_G, "C_Item") and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
    return Try(fn, id)
end

-- Graue Gegenstaende mit Verkaufswert: {{bag, slot, wert}}; zweiter Wert = Zahl noch nicht geladener
-- Gegenstaende (Preis unbekannt, Daten werden angefordert), dritter = Zaehler fuer den Pruefbefehl
function V.Junk()
    local out, waiting, seen = {}, 0, {grey = 0, noValue = 0, locked = 0, slots = 0}
    local C = Container()
    for bag = 0, 4 do
        local n = Try(C.GetContainerNumSlots or rawget(_G, "GetContainerNumSlots"), bag) or 0
        seen.slots = seen.slots + n
        for slot = 1, n do
            local info = V.SlotInfo(bag, slot)
            if type(info) == "table" then
                local id = info.itemID or info.hyperlink
                local name, _, quality, _, _, _, _, _, _, _, price
                if id then name, _, quality, _, _, _, _, _, _, _, price = ItemInfo(id) end
                local q = info.quality
                if q == nil or q < 0 then q = quality end
                if q == 0 then
                    seen.grey = seen.grey + 1
                    if info.hasNoValue then seen.noValue = seen.noValue + 1
                    elseif info.isLocked then seen.locked = seen.locked + 1
                    elseif not name and not price then
                        waiting = waiting + 1
                        local req = rawget(_G, "C_Item") and C_Item.RequestLoadItemDataByID
                        if info.itemID then Try(req, info.itemID) end
                    elseif (price or 0) > 0 then
                        out[#out + 1] = {bag, slot, price * (info.stackCount or 1)}
                    else
                        seen.noValue = seen.noValue + 1
                    end
                end
            end
        end
    end
    return out, waiting, seen
end

function V:SellJunk(retry)
    if not ONE:FeatureOn("core.sellJunk") then return 0 end
    local list, waiting = V.Junk()
    -- Preise noch nicht geladen: einmal kurz warten und neu schauen
    if waiting > 0 and not retry and C_Timer and C_Timer.After then
        C_Timer.After(.6, function() if V.open then V:SellJunk(true) end end)
        return 0
    end
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

-- /trip schrott: zeigt, warum (nicht) verkauft wird
function V:Check()
    local C = Container()
    local function Has(fn) return type(fn) == "function" and "ja" or "FEHLT" end
    ONE:Print(T("Schrott verkaufen: %s (Optionen › Allgemein › Händler)",
        ONE:FeatureOn("core.sellJunk") and "AN" or "AUS"))
    ONE:Print(T("Spiel-Schnittstellen: Taschen neu %s, alt %s · Benutzen neu %s, alt %s · Preis %s",
        Has(C.GetContainerItemInfo), Has(rawget(_G, "GetContainerItemInfo")),
        Has(C.UseContainerItem), Has(rawget(_G, "UseContainerItem")),
        Has((rawget(_G, "C_Item") and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo"))))
    local list, waiting, seen = V.Junk()
    local total = 0
    for _, it in ipairs(list) do total = total + it[3] end
    ONE:Print(T("Taschenplätze %d · graue Gegenstände %d · verkaufbar %d (%s) · ohne Wert %d · gesperrt %d · Daten fehlen %d",
        seen.slots, seen.grey, #list, V.Money(total), seen.noValue, seen.locked, waiting))
end

function V:Initialize()
    if self.started then return end
    self.started = true
    if ONE.RegisterSlash then
        ONE:RegisterSlash("schrott", function() V:Check() end, T("Prüfen, ob Schrott verkauft werden kann"))
    end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "MERCHANT_SHOW")
    pcall(f.RegisterEvent, f, "MERCHANT_CLOSED")
    f:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_CLOSED" then V.open = false return end
        pcall(V.OnMerchant, V)
    end)
end
