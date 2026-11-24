-- Pruefung (24.11.2026): Was erlaubt WoW Forever Addons am Auktionshaus?
-- /trip ahcheck [Suchwort]  (Standard: Leinenstoff)
--  1) Welche Auktionshaus-Funktionen gibt es (alt: QueryAuctionItems …, neu: C_AuctionHouse …)?
--  2) Kann ein Addon Gegenstaende in der Tasche als gebunden erkennen?
--  3) Nur bei offenem Auktionshaus: eine Suche nach dem Suchwort, die ersten Treffer mit Preis.
-- Ergebnis auch in GuildTripDevDB.ahCheck (nach /reload in den SavedVariables lesbar). Kauft/verkauft nichts.
local ONE = _G.ProjectONE
if not ONE then return end
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end

local AC = {open = false, TIMEOUT = 6}
ONE.AuctionCheck = AC

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = {pcall(fn, ...)}
    if not r[1] then AC.lastError = tostring(r[2]) end
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end
local function After(sec, fn) if C_Timer and C_Timer.After then C_Timer.After(sec, fn) end end
local function Money(c)
    if not c then return "?" end
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    return (g > 0 and (g .. "g ") or "") .. ((g > 0 or s > 0) and (s .. "s ") or "") .. k .. "c"
end
local function Path(path)
    local t = _G
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = rawget(t, part)
    end
    return t
end

AC.OLD = {"QueryAuctionItems", "CanSendAuctionQuery", "GetNumAuctionItems", "GetAuctionItemInfo",
    "GetAuctionItemLink", "SortAuctionItems", "GetAuctionDeposit", "CalculateAuctionDeposit",
    "GetAuctionSellItemInfo", "PostAuction", "StartAuction"}
AC.NEW = {"C_AuctionHouse.SendBrowseQuery", "C_AuctionHouse.GetBrowseResults", "C_AuctionHouse.SendSearchQuery",
    "C_AuctionHouse.GetCommoditySearchResultInfo", "C_AuctionHouse.ReplicateItems",
    "C_AuctionHouse.GetNumReplicateItems", "C_AuctionHouse.GetReplicateItemInfo",
    "C_AuctionHouse.CalculateItemDeposit", "C_AuctionHouse.CalculateCommodityDeposit",
    "C_AuctionHouse.GetAuctionHouseCut", "C_AuctionHouse.IsThrottledMessageSystemReady"}
AC.BOUND = {"C_Item.IsBound", "ItemLocation.CreateFromBagAndSlot", "C_TooltipInfo.GetBagItem"}

function AC.Has(list)
    local out, n = {}, 0
    for _, name in ipairs(list) do
        local ok = type(Path(name)) == "function"
        out[name] = ok
        if ok then n = n + 1 end
    end
    return out, n
end

-- Gebundene Gegenstaende in den Taschen zaehlen (zeigt, ob die Abfrage geht)
function AC.BoundCount()
    local isBound, loc = Path("C_Item.IsBound"), Path("ItemLocation")
    if type(isBound) ~= "function" or type(loc) ~= "table" or type(loc.CreateFromBagAndSlot) ~= "function" then return nil end
    local C = rawget(_G, "C_Container") or {}
    local slots = C.GetContainerNumSlots or rawget(_G, "GetContainerNumSlots")
    local info = C.GetContainerItemInfo or rawget(_G, "GetContainerItemInfo")
    local items, bound = 0, 0
    for bag = 0, 4 do
        for slot = 1, Try(slots, bag) or 0 do
            if Try(info, bag, slot) then
                items = items + 1
                local where = Try(loc.CreateFromBagAndSlot, loc, bag, slot)
                if where and Try(isBound, where) then bound = bound + 1 end
            end
        end
    end
    return items, bound
end

-- Antwort der alten Suche lesen
function AC.ReadOld()
    local n, total = Try(GetNumAuctionItems, "list")
    local rows = {}
    for i = 1, math.min(n or 0, 5) do
        local name, _, count, _, _, _, _, minBid, _, buyout, _, _, _, owner, _, _, itemID = Try(GetAuctionItemInfo, "list", i)
        rows[#rows + 1] = {name = name, count = count, bid = minBid, buyout = buyout, itemID = itemID, owner = owner and true or false}
    end
    return n or 0, total or n or 0, rows
end

function AC.ReadNew()
    local res = Try(Path("C_AuctionHouse.GetBrowseResults"))
    local rows = {}
    if type(res) ~= "table" then return 0, rows end
    for i = 1, math.min(#res, 5) do
        local r = res[i]
        rows[#rows + 1] = {itemID = r.itemKey and r.itemKey.itemID, count = r.totalQuantity, buyout = r.minPrice}
    end
    return #res, rows
end

local function Show(r)
    ONE:Print(("Auktionshaus-Suche '%s' (%s): %d Treffer%s."):format(r.search, r.api, r.found or 0,
        r.total and r.total ~= r.found and (" (gesamt " .. r.total .. ")") or ""))
    for _, row in ipairs(r.rows or {}) do
        local name = row.name or (row.itemID and Try(GetItemInfo, row.itemID)) or tostring(row.itemID)
        ONE:Print(("  %s x%s – Sofortkauf %s"):format(tostring(name), tostring(row.count or "?"), Money(row.buyout)))
    end
end

function AC:Finish(api)
    local r = self.pending
    if not r then return end
    self.pending = nil
    r.api = api
    if api == "alt" then r.found, r.total, r.rows = AC.ReadOld()
    else r.found, r.rows = AC.ReadNew() end
    r.answered = true
    Show(r)
    ONE:Print("Ergebnis gespeichert – nach /reload kann Claude es lesen.")
end

function AC:Search(r)
    r.search = r.search or "Leinenstoff"
    if not AC.open then
        r.searchSkipped = "Auktionshaus nicht offen"
        ONE:Print("Für die Suche: Auktionshaus öffnen und /trip ahcheck noch einmal eingeben.")
        return
    end
    local canQuery, canAll = Try(CanSendAuctionQuery)
    r.canQuery, r.canQueryAll = canQuery, canAll
    self.pending = r
    if type(rawget(_G, "QueryAuctionItems")) == "function" then
        r.tried = "alt"
        if canQuery == false then ONE:Print("Hinweis: Spiel meldet gerade 'noch keine neue Suche' – kurz warten.") end
        Try(QueryAuctionItems, r.search, nil, nil, 0, false, nil, false, false, nil)
    elseif type(Path("C_AuctionHouse.SendBrowseQuery")) == "function" then
        r.tried = "neu"
        Try(C_AuctionHouse.SendBrowseQuery, {searchString = r.search, sorts = {{sortOrder = 0, reverseSort = false}},
            filters = {}, itemClassFilters = {}})
    else
        self.pending = nil
        r.searchSkipped = "keine Suchfunktion"
        ONE:Print("Keine Auktionshaus-Suche für Addons vorhanden.")
        return
    end
    r.error = AC.lastError
    After(AC.TIMEOUT, function()
        if self.pending == r then
            self.pending = nil
            r.timeout = true
            ONE:Print(("Keine Antwort vom Auktionshaus nach %d s (%s)."):format(AC.TIMEOUT, tostring(r.error or "kein Fehler gemeldet")))
        end
    end)
end

function AC:Run(raw)
    AC.lastError = nil
    local r = {when = date and date("%Y-%m-%d %H:%M") or "?", search = raw ~= "" and raw or nil, open = AC.open,
        events = AC.events}
    local old, nOld = AC.Has(AC.OLD)
    local new, nNew = AC.Has(AC.NEW)
    local bnd = AC.Has(AC.BOUND)
    r.old, r.new, r.bound = old, new, bnd
    r.items, r.boundItems = AC.BoundCount()
    ONE:Print(("Auktionshaus-Funktionen: alt %d/%d (Suche %s), neu %d/%d (Suche %s). Auktionshaus offen: %s."):format(
        nOld, #AC.OLD, old.QueryAuctionItems and "ja" or "FEHLT", nNew, #AC.NEW,
        new["C_AuctionHouse.SendBrowseQuery"] and "ja" or "FEHLT", AC.open and "ja" or "nein"))
    ONE:Print(r.items and ("Gebunden-Erkennung: geht – %d von %d Gegenständen in den Taschen sind gebunden."):format(r.boundItems, r.items)
        or "Gebunden-Erkennung: Funktion FEHLT (Ausweichweg: Tooltip lesen).")
    local db = DevDB()
    if db then db.ahCheck = r end
    AC:Search(r)
end

function AC:OnEvent(event)
    AC.events = AC.events or {}
    AC.events[event] = (AC.events[event] or 0) + 1
    if event == "AUCTION_HOUSE_SHOW" then AC.open = true
    elseif event == "AUCTION_HOUSE_CLOSED" then AC.open = false
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then AC:Finish("alt")
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then AC:Finish("neu") end
end

local f = CreateFrame("Frame")
for _, e in ipairs({"AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_ITEM_LIST_UPDATE",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"}) do
    pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event) pcall(AC.OnEvent, AC, event) end)

ONE:RegisterSlash("ahcheck", function(_, raw) AC:Run(raw or "") end, "Auktionshaus für Addons prüfen")
