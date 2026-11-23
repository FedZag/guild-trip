-- Guild Trip: Meine Figuren (Gesamtpruefung 23.11.2026, Ideen wie Bagnon/Altoholic – nur Ideen).
-- Merkt je Figur (nur auf diesem PC, ProjectONEDB.alts[Realm][Name]): Klasse, Stufe, Gold, Erholt-EP,
-- Ort, zuletzt gesehen, Taschen- und Bankinhalt (Gegenstands-ID -> Anzahl). Zeigt:
-- * Startseite › Meine Figuren (auch /trip figuren): Liste mit Gold gesamt
-- * im Gegenstands-Tooltip: "Deine Figuren: Name 12 (Tasche 10, Bank 2) …" (abschaltbar)
-- Erholt-EP offline geschaetzt: im Gasthaus 5 % einer Stufe je 8 Stunden, draussen ein Viertel, hoechstens 150 %.
local _, ONE = ...
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local A = {RESTED_STEP = 8 * 3600, RESTED_SHARE = .05, RESTED_CAP = 1.5}
ONE.Alts = A

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function G(name) return rawget(_G, name) end
local function Now() return Try(G("time")) or os.time() end

if ONE.RegisterFeature then
    ONE:RegisterFeature("core.altCounts", {label = "Anzahl bei deinen Figuren im Gegenstands-Tooltip",
        tooltip = "Zeigt beim Drüberfahren, wie viele davon deine anderen Figuren in Tasche und Bank haben (nur auf diesem PC gemerkt; die Bank nach dem ersten Öffnen)."})
end

-- ===== Speicher =====
function A:Realm()
    local realm = Try(G("GetRealmName")) or "?"
    if not ONE.db then return {} end
    ONE.db.alts = type(ONE.db.alts) == "table" and ONE.db.alts or {}
    ONE.db.alts[realm] = type(ONE.db.alts[realm]) == "table" and ONE.db.alts[realm] or {}
    return ONE.db.alts[realm]
end
function A:Me()
    local name = Try(G("UnitName"), "player")
    if type(name) ~= "string" or name == "" then return nil end
    local realm = self:Realm()
    realm[name] = type(realm[name]) == "table" and realm[name] or {}
    return realm[name], name
end

-- ===== Einlesen =====
local function Slot(bag, slot)
    local CC = G("C_Container")
    if CC and CC.GetContainerItemInfo then
        local info = Try(CC.GetContainerItemInfo, bag, slot)
        if type(info) == "table" then return info.itemID, info.stackCount or 1 end
        return nil
    end
    local _, count, _, _, _, _, _, _, _, id = Try(G("GetContainerItemInfo"), bag, slot)
    return id, count or 1
end
local function NumSlots(bag)
    local CC = G("C_Container")
    local fn = CC and CC.GetContainerNumSlots or G("GetContainerNumSlots")
    return Try(fn, bag) or 0
end
function A.Scan(bags)
    local out = {}
    for _, bag in ipairs(bags) do
        for slot = 1, NumSlots(bag) do
            local id, n = Slot(bag, slot)
            if type(id) == "number" then out[id] = (out[id] or 0) + (tonumber(n) or 1) end
        end
    end
    return out
end
function A.BagIDs()
    local list = {}
    for b = 0, tonumber(G("NUM_BAG_SLOTS")) or 4 do list[#list + 1] = b end
    return list
end
function A.BankIDs()
    local list = {tonumber(G("BANK_CONTAINER")) or -1}
    local first = (tonumber(G("NUM_BAG_SLOTS")) or 4) + 1
    for b = first, first + (tonumber(G("NUM_BANKBAGSLOTS")) or 6) - 1 do list[#list + 1] = b end
    return list
end

function A:Update(what)
    local me = self:Me()
    if not me then return nil end
    local _, class = Try(G("UnitClass"), "player")
    me.class = class or me.class
    me.level = Try(G("UnitLevel"), "player") or me.level
    me.money = Try(G("GetMoney")) or me.money
    me.xp, me.max = Try(G("UnitXP"), "player"), Try(G("UnitXPMax"), "player")
    me.rested = tonumber(Try(G("GetXPExhaustion"))) or 0
    me.resting = Try(G("IsResting")) and true or false
    me.zone = Try(G("GetZoneText")) or me.zone
    me.faction = Try(G("UnitFactionGroup"), "player") or me.faction
    me.seen = Now()
    if what == "bags" or what == "all" then me.bags = A.Scan(A.BagIDs()) end
    if what == "bank" then me.bank = A.Scan(A.BankIDs()) me.bankSeen = Now() end
    return me
end

-- Erholt-EP jetzt (offline weitergerechnet); 0 auf Stufe 60
function A.RestedNow(c, now)
    if type(c) ~= "table" or (c.level or 0) >= 60 then return 0 end
    local max = tonumber(c.max) or 0
    local rested = tonumber(c.rested) or 0
    if max <= 0 then return rested end
    local hours = math.max(0, (now or Now()) - (c.seen or now or 0))
    local gain = hours / A.RESTED_STEP * A.RESTED_SHARE * max * (c.resting and 1 or .25)
    return math.min(max * A.RESTED_CAP, rested + gain)
end

-- Liste fuer die Seite: alle Figuren dieses Realms, nach Stufe
function A:List()
    local out = {}
    local me = Try(G("UnitName"), "player")
    for name, c in pairs(self:Realm()) do
        if type(c) == "table" then out[#out + 1] = {name = name, c = c, me = name == me} end
    end
    table.sort(out, function(a, b)
        if a.me ~= b.me then return a.me end
        if (a.c.level or 0) ~= (b.c.level or 0) then return (a.c.level or 0) > (b.c.level or 0) end
        return a.name < b.name
    end)
    return out
end
function A:TotalMoney()
    local sum = 0
    for _, e in ipairs(self:List()) do sum = sum + (tonumber(e.c.money) or 0) end
    return sum
end
function A:Remove(name)
    local realm = self:Realm()
    if realm[name] and name ~= Try(G("UnitName"), "player") then realm[name] = nil return true end
    return false
end

-- ===== Tooltip =====
-- "Name 12 (Tasche 10, Bank 2)" je Figur mit Bestand; nil ohne
function A:CountText(itemID)
    if not itemID then return nil end
    local parts, total, n, others = {}, 0, 0, false
    for _, e in ipairs(self:List()) do
        local bag = e.c.bags and e.c.bags[itemID] or 0
        local bank = e.c.bank and e.c.bank[itemID] or 0
        if bag + bank > 0 then
            n = n + 1
            total = total + bag + bank
            if not e.me or bank > 0 then others = true end
            local where = {}
            if bag > 0 then where[#where + 1] = T("Tasche %d", bag) end
            if bank > 0 then where[#where + 1] = T("Bank %d", bank) end
            parts[#parts + 1] = e.name .. " " .. (bag + bank) .. " (" .. table.concat(where, ", ") .. ")"
        end
    end
    -- nur die aktuelle Figur mit Taschenbestand: steht schon im Tooltip/der Tasche, keine Zeile
    if n == 0 or not others then return nil end
    return parts, total, n
end
function A:OnTooltip(tooltip)
    if ONE.FeatureOn and not ONE:FeatureOn("core.altCounts") then return false end
    if not (tooltip and tooltip.GetItem and tooltip.AddLine) then return false end
    local _, link = tooltip:GetItem()
    local id = link and tonumber(link:match("item:(%d+)"))
    local parts, total, n = self:CountText(id)
    if not parts then return false end
    tooltip:AddLine(n > 1 and T("Deine Figuren (%d gesamt):", total) or T("Deine Figuren:"), 1, .82, 0)
    for i, p in ipairs(parts) do
        if i > 6 then tooltip:AddLine("…", .8, .8, .8) break end
        tooltip:AddLine("  " .. p, .85, .85, .85)
    end
    if tooltip.Show then tooltip:Show() end
    return true
end
function A:HookTooltips()
    local function Hook(tt) pcall(A.OnTooltip, A, tt) end
    local TDP, E = G("TooltipDataProcessor"), G("Enum")
    if TDP and TDP.AddTooltipPostCall and E and E.TooltipDataType and E.TooltipDataType.Item then
        TDP.AddTooltipPostCall(E.TooltipDataType.Item, function(tt)
            if tt == G("GameTooltip") or tt == G("ItemRefTooltip") then Hook(tt) end
        end)
        return
    end
    for _, tt in ipairs({G("GameTooltip"), G("ItemRefTooltip")}) do
        if tt and tt.HookScript then tt:HookScript("OnTooltipSetItem", Hook) end
    end
end

-- ===== Seite "Meine Figuren" (Startseite) =====
local function ClassColor(class)
    local c = class and G("RAID_CLASS_COLORS") and G("RAID_CLASS_COLORS")[class]
    return c and c.colorStr or "ffffffff"
end
local function Ago(sec)
    sec = math.max(0, sec or 0)
    if sec < 3600 then return T("gerade eben") end
    if sec < 86400 then return T("vor %d Std.", math.floor(sec / 3600)) end
    return T("vor %d Tagen", math.floor(sec / 86400))
end
function A:BuildView(panel)
    local W, H = ONE.UI.Layout.width, ONE.Geometry.tokens.contentHeight
    local Money = ONE.Vendor and ONE.Vendor.Money or function(c) return tostring(c) end
    local head = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -6)
    head:SetWidth(W - 8)
    head:SetJustifyH("LEFT")
    if ONE.Themes then ONE.Themes:RegisterText(head, "accent") end
    local NAMEW, LVLW, GOLDW, RESTW = 150, 46, 130, 90
    local list = ONE.Kit:List(panel, {x = 0, y = -30, width = W, height = H - 60, rowHeight = 24,
        columns = {
            {key = "name", title = "FIGUR", width = NAMEW, indent = 6},
            {key = "level", title = "STUFE", width = LVLW, align = "CENTER"},
            {key = "gold", title = "GOLD", width = GOLDW, align = "RIGHT"},
            {key = "rested", title = "ERHOLT", width = RESTW, align = "RIGHT"},
            {key = "where", title = "ORT", width = math.max(40, W - 24 - NAMEW - LVLW - GOLDW - RESTW - 30)},
        },
        render = function(_, e, cells)
            local c = e.c
            cells.name:SetText("|c" .. ClassColor(c.class) .. e.name .. "|r")
            cells.level:SetText(c.level or "")
            cells.gold:SetText(c.money and Money(c.money) or "")
            local max = tonumber(c.max) or 0
            local r = A.RestedNow(c)
            cells.rested:SetText((max > 0 and (c.level or 0) < 60) and (math.floor(r * 100 / max + .5) .. " %") or "")
            cells.where:SetText((c.zone or "") .. (e.me and "" or ("  ·  " .. Ago(Now() - (c.seen or 0)))))
        end,
        onEnter = function(row, e)
            if not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(e.name)
            local c = e.c
            if c.bankSeen then GameTooltip:AddLine(T("Bank zuletzt gesehen: %s", Ago(Now() - c.bankSeen)), .8, .8, .8)
            else GameTooltip:AddLine(T("Bank noch nicht gesehen – einmal mit dieser Figur die Bank öffnen."), .8, .8, .8, true) end
            GameTooltip:AddLine(T("Erholt: geschätzt seit dem letzten Einloggen (Gasthaus: schneller)."), .7, .7, .7, true)
            if not e.me then GameTooltip:AddLine(T("Umschalt+Rechtsklick: aus der Liste entfernen"), .7, .7, .7) end
            GameTooltip:Show()
        end,
        onClick = function(_, e, button)
            if button == "RightButton" and Try(G("IsShiftKeyDown")) and not e.me then
                A:Remove(e.name)
                ONE.UI:Refresh()
            end
        end,
    })
    local total = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    total:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 8)
    total:SetWidth(W - 12)
    total:SetJustifyH("LEFT")
    if ONE.Themes then ONE.Themes:RegisterText(total, "text") end
    return function()
        A:Update()
        local items = A:List()
        list:SetItems(items)
        head:SetText(T("Deine Figuren auf diesem Realm (nur auf diesem PC gemerkt)"))
        total:SetText(T("Gold gesamt: %s  ·  %d Figuren", Money(A:TotalMoney()), #items))
        -- kein Zusatz oben: der Seitenname "Meine Figuren" steht schon da, Gold gesamt unten
    end
end

function A:Initialize()
    if self.started then return end
    self.started = true
    local f = CreateFrame("Frame")
    for _, e in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED",
        "PLAYERBANKSLOTS_CHANGED", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING",
        "ZONE_CHANGED_NEW_AREA", "PLAYER_LOGOUT"}) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" then A.bankOpen = true end
        if event == "BANKFRAME_OPENED" or (event == "PLAYERBANKSLOTS_CHANGED") or (event == "BAG_UPDATE_DELAYED" and A.bankOpen) then
            pcall(A.Update, A, "bank")
        end
        if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGOUT" then
            pcall(A.Update, A, "bags")
        else
            pcall(A.Update, A)
        end
    end)
    local closer = CreateFrame("Frame")
    pcall(closer.RegisterEvent, closer, "BANKFRAME_CLOSED")
    closer:SetScript("OnEvent", function() A.bankOpen = false end)
    pcall(A.HookTooltips, A)
    if ONE.UI and ONE.UI.RegisterView then
        ONE.UI:RegisterView("alts", function(panel) return A:BuildView(panel) end)
    end
    if ONE.RegisterSlash then
        ONE:RegisterSlash("figuren", function() ONE.UI:Show() ONE.UI:Navigate("alts") end, T("Meine Figuren: Gold, Stufe, Erholt, Taschen"))
    end
end
