-- Offline-Test: /trip ahcheck – Pruefbefehl Auktionshaus (alte und neue Schnittstelle, gebunden, Zeitlimit)
local root = arg[1] or "src"
local printed, cmds, handler, timers = {}, {}, nil, {}
local ONE = {db = {}}
function ONE:Print(s) printed[#printed + 1] = s end
function ONE:RegisterSlash(n, fn) cmds[n] = fn end
_G.ProjectONE = ONE
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function(_, _, fn) handler = fn end} end
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
date = function() return "2026-11-24" end
C_Container = {GetContainerNumSlots = function(b) return b == 0 and 3 or 0 end,
    GetContainerItemInfo = function(_, s) if s <= 2 then return {itemID = s} end end}
ItemLocation = {CreateFromBagAndSlot = function(_, b, s) return {b, s} end}
C_Item = {IsBound = function(loc) return loc[2] == 1 end}
GetItemInfo = function(id) return "Item" .. id end
local queried
QueryAuctionItems = function(text) queried = text end
CanSendAuctionQuery = function() return true, false end
GetNumAuctionItems = function() return 2, 2 end
GetAuctionItemInfo = function(_, i) return "Leinenstoff", nil, 20, 1, true, 1, nil, 100, 5, 2500 * i, 0, false, nil, "X", nil, 0, 2589 end

assert(loadfile(root .. "/ONE_Dev/AuctionCheck.lua"))("ONE_Dev", {})
assert(cmds.ahcheck, "Befehl angemeldet")
local AC = ONE.AuctionCheck

-- 1) Auktionshaus zu: nur Funktionen + gebunden, keine Suche
cmds.ahcheck("", "")
assert(printed[1]:find("alt 4/11") and printed[1]:find("Suche ja") and printed[1]:find("offen: nein"), printed[1])
assert(printed[2]:find("1 von 2"), printed[2])
assert(not queried and ONE.db.ahCheck.searchSkipped, "ohne offenes AH keine Suche")

-- 2) Auktionshaus offen, alte Suche, Antwort kommt
printed = {}
handler(nil, "AUCTION_HOUSE_SHOW")
cmds.ahcheck("wolle", "Wolle")
assert(queried == "Wolle", "Suchwort wie getippt")
handler(nil, "AUCTION_ITEM_LIST_UPDATE")
local r = ONE.db.ahCheck
assert(r.answered and r.api == "alt" and r.found == 2 and r.rows[2].buyout == 5000)
local all = table.concat(printed, "\n")
assert(all:find("2 Treffer") and all:find("50s 0c"), all)

-- 3) neue Schnittstelle, keine Antwort -> Zeitlimit-Meldung
QueryAuctionItems, GetNumAuctionItems, GetAuctionItemInfo, CanSendAuctionQuery = nil, nil, nil, nil
local sent
C_AuctionHouse = {SendBrowseQuery = function(q) sent = q.searchString end,
    GetBrowseResults = function() return {{itemKey = {itemID = 2589}, totalQuantity = 40, minPrice = 900}} end}
printed, timers = {}, {}
cmds.ahcheck("", "")
assert(sent == "Leinenstoff")
timers[1]()
assert(ONE.db.ahCheck.timeout and printed[#printed]:find("Keine Antwort"), printed[#printed])
-- neue Antwort
printed = {}
cmds.ahcheck("", "")
handler(nil, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
assert(ONE.db.ahCheck.api == "neu" and ONE.db.ahCheck.found == 1)
assert(table.concat(printed, "\n"):find("Item2589 x40 – Sofortkauf 9s 0c"), table.concat(printed, "\n"))
print("OK test_ahcheck_131")
