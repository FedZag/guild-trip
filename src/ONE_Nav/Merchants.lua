-- Guild Trip: Haendler-Verzeichnis (0.6.5) – "wo bekomme ich Phiolen, Faden, Munition ...?"
-- Das Spiel liefert keine Haendlerliste, fremde Datenbanken uebernehmen wir nicht (Lizenz).
-- Deshalb selbst sammeln: Oeffnet der Spieler einen Haendler, merken wir uns Name, Ort
-- (Spielerposition) und das Angebot, einsortiert in Gruppen (Kategorien). Mit eigenem
-- Haekchen "Haendler-Funde teilen" gehen nur Ort + Gruppen an die Gilde (keine Namen
-- des Finders). Gespeichert kontoweit in ONE.db.nav.merchants.
--
-- Nachricht (Praefix ONEQST1 ueber QuestShare): MV|schluessel|name|karte|x|y|fraktion|gruppe,gruppe,...
local _, nav = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local M = {maxMerchants = 1500}
nav.Merchants = M

-- Gruppen in Anzeige-Reihenfolge (Kennung, deutscher Name)
M.CATEGORIES = {
    {"vial", "Phiolen"}, {"thread", "Faden & Farbstoffe"}, {"trade", "Handwerkswaren"},
    {"food", "Essen & Trinken"}, {"reagent", "Reagenzien"}, {"ammo", "Munition & Köcher"},
    {"recipe", "Rezepte"}, {"bag", "Behälter & Taschen"}, {"weapon", "Nah- & Fernkampfwaffen"}, {"armor", "Rüstung"},
    {"repair", "Reparieren"}, {"misc", "Sonstiges"},
}
M.NAMES = {}
for _, c in ipairs(M.CATEGORIES) do M.NAMES[c[1]] = c[2] end

-- Einzelne Gegenstaende, die eine eigene Gruppe verdienen (Classic-Nummern)
M.ITEMS = {
    [3371] = "vial", [3372] = "vial", [8925] = "vial", [18256] = "vial",            -- Phiolen
    [2320] = "thread", [2321] = "thread", [4291] = "thread", [8343] = "thread", [14341] = "thread", -- Faden
    [2324] = "thread", [2604] = "thread", [2605] = "thread", [4340] = "thread", [4341] = "thread",
    [4342] = "thread", [6260] = "thread", [6261] = "thread", [10290] = "thread",     -- Bleiche, Farbstoffe
}
-- Gegenstandsklassen (GetItemInfoInstant): 0 Verbrauch (5 = Essen/Trinken), 1 Behaelter,
-- 2 Waffe, 4 Ruestung, 5 Reagenz, 6 Projektil, 7 Handwerkswaren, 9 Rezept, 11 Koecher
function M.Classify(itemID, classID, subclassID)
    if itemID and M.ITEMS[itemID] then return M.ITEMS[itemID] end
    if classID == 0 then return subclassID == 5 and "food" or "misc" end
    if classID == 1 then return "bag" end
    if classID == 2 then return "weapon" end
    if classID == 4 then return (subclassID == 0) and "misc" or "armor" end
    if classID == 5 then return "reagent" end
    if classID == 6 or classID == 11 then return "ammo" end
    if classID == 7 then return "trade" end
    if classID == 9 then return "recipe" end
    return "misc"
end

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = (function(...) return {n = select("#", ...), ...} end)(pcall(fn, ...))
    if not r[1] then return nil end
    -- geheime Werte (Forever: GUID/Name eines NPCs, waehrend das Addon „tainted“ ist) gelten als unbekannt
    local n = math.max(2, r.n)
    if type(issecretvalue) == "function" then
        for i = 2, n do
            local ok, s = pcall(issecretvalue, r[i])
            if not ok or s then r[i] = nil end
        end
    end
    return unpack(r, 2, n)
end
local function Clean(text, max)
    text = tostring(text or ""):gsub("[|;,\r\n]", " ")
    if #text > max then text = text:sub(1, max) end
    return text
end
local function Now() return Try(GetServerTime) or Try(time) or 0 end


-- Startpaket (Pack.lua, aus eigenen Funden gebaut) einmal je Sitzung einmischen:
-- nur Schluessel, die noch fehlen; eigene Funde haben immer Vorrang.
local function MergePack(store, list)
    for key, e in pairs(list or {}) do
        if store[key] == nil then
            local copy = {pack = true}
            for k, v in pairs(e) do
                if type(v) == "table" then local t = {} for a, b in pairs(v) do t[a] = type(b) == "table" and {title = b.title, level = b.level} or b end copy[k] = t
                else copy[k] = v end
            end
            store[key] = copy
        end
    end
end

function M:Store()
    if not ONE.db then return {} end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    local s = type(ONE.db.nav.merchants) == "table" and ONE.db.nav.merchants or {}
    ONE.db.nav.merchants = s
    if not self.packMerged and nav.Pack then self.packMerged = true MergePack(s, nav.Pack.merchants) end
    return s
end

-- Teilen nur mit eigenem Haekchen (pro Charakter)
function M:IsSharing()
    local db = ONE.db and type(ONE.db.nav) == "table" and ONE.db.nav
    local me = Try(UnitName, "player")
    return db and type(db.merchantShare) == "table" and me and db.merchantShare[me] == true or false
end
function M:SetSharing(on)
    if not ONE.db then return end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    ONE.db.nav.merchantShare = type(ONE.db.nav.merchantShare) == "table" and ONE.db.nav.merchantShare or {}
    local me = Try(UnitName, "player")
    if me then ONE.db.nav.merchantShare[me] = on and true or nil end
end

-- Angebot des offenen Haendlers: Gruppen + Beispiel-Gegenstaende je Gruppe
function M:ReadOffer()
    local cats, items = {}, {}
    for i = 1, Try(GetMerchantNumItems) or 0 do
        local itemID = Try(GetMerchantItemID, i)
        if not itemID then
            local link = Try(GetMerchantItemLink, i)
            itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
        end
        local name = Try(GetMerchantItemInfo, i)
        local classID, subclassID
        if itemID then
            local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
            local _, _, _, _, _, c, sc = Try(fn, itemID)
            classID, subclassID = c, sc
        end
        local cat = M.Classify(itemID, classID, subclassID)
        cats[cat] = true
        if name then
            items[cat] = items[cat] or {}
            if #items[cat] < 6 then items[cat][#items[cat] + 1] = Clean(name, 40) end
        end
    end
    if Try(CanMerchantRepair) then cats.repair = true end
    return cats, items
end

-- Fund eintragen (eigener oder aus der Gilde). Liefert true, wenn sich etwas geaendert hat.
function M:Add(key, name, mapID, x, y, faction, cats, items, fromGuild)
    if not (key and mapID and x and y and type(cats) == "table" and next(cats)) then return false end
    local store = self:Store()
    local m = store[key]
    local changed = not m
    m = m or {cats = {}}
    store[key] = m
    if not fromGuild or not m.mapID then
        m.name, m.mapID, m.x, m.y, m.faction = Clean(name, 40), mapID, x, y, faction
    end
    for c in pairs(cats) do if M.NAMES[c] and not m.cats[c] then m.cats[c] = true changed = true end end
    if items then m.items = items end
    m.seen = Now()
    if changed then self:Trim() end
    return changed
end
function M:Trim()
    local store, list = self:Store(), {}
    for key, m in pairs(store) do list[#list + 1] = {key, m.seen or 0} end
    if #list <= self.maxMerchants then return end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    for i = 1, #list - self.maxMerchants do store[list[i][1]] = nil end
end

function M:OnShow()
    if ONE.FeatureOn and not ONE:FeatureOn("nav.merchants") then return end
    local giver = nav.QuestGivers
    local key = giver and giver.KeyFromGUID and giver.KeyFromGUID(Try(UnitGUID, "npc"), Try(UnitName, "npc"))
    local mapID, x, y = nav.Travel.PlayerMapPosition()
    if not (key and mapID) then return end
    local cats, items = self:ReadOffer()
    local name = Try(UnitName, "npc")
    if self:Add(key, name, mapID, x, y, Try(UnitFactionGroup, "player") or "?", cats, items) then self:Share(key) end
end

-- ===== Teilen =====
function M:Message(key)
    local m = self:Store()[key]
    if not (m and m.mapID) then return end
    local cats = {}
    for _, c in ipairs(M.CATEGORIES) do if m.cats[c[1]] then cats[#cats + 1] = c[1] end end
    return table.concat({"MV", key, Clean(m.name, 30), m.mapID, math.floor(m.x * 1000 + .5), math.floor(m.y * 1000 + .5),
        m.faction or "?", table.concat(cats, ",")}, "|")
end
function M:Share(key)
    local QS = nav.QuestShare
    if not (QS and self:IsSharing()) then return false end
    local msg = self:Message(key)
    return msg and QS:Send(msg) or false
end
function M:Receive(p)
    local key, mapID, x, y = p[2], tonumber(p[4]), tonumber(p[5]), tonumber(p[6])
    if not (key and key:match("^[con]") and mapID and x and y) then return false end
    local cats = {}
    for c in (p[8] or ""):gmatch("[%a]+") do if M.NAMES[c] then cats[c] = true end end
    return self:Add(key, p[3], mapID, x / 1000, y / 1000, p[7], cats, nil, true)
end

-- ===== Abfrage fuer die Navi =====
-- filter = "all" oder eine Gruppen-Kennung; nur eigene Fraktion
function M:List(filter)
    local out, faction = {}, Try(UnitFactionGroup, "player") or "?"
    for key, m in pairs(self:Store()) do
        if m.mapID and (m.faction == nil or m.faction == "?" or m.faction == faction)
            and (filter == nil or filter == "all" or m.cats[filter]) then
            out[#out + 1] = {key = key, name = m.name or "?", mapID = m.mapID, x = m.x, y = m.y, cats = m.cats, items = m.items}
        end
    end
    -- Händler-Verzeichnis aus der Questdatenbank (ONE_QuestDB/Services.lua): nur, was noch nicht selbst gefunden ist
    local store = self:Store()
    for key, m in pairs(M.FromQuestDB(faction)) do
        if store[key] == nil and (filter == nil or filter == "all" or m.cats[filter]) then
            out[#out + 1] = {key = key, name = m.name, mapID = m.mapID, x = m.x, y = m.y, cats = m.cats, db = true}
        end
    end
    return out
end
-- Händler aus ONE_QuestDB, einmal je Fraktion umgewandelt: ["c<npc>"] = {name, mapID, x, y, cats}
M.dbCache = {}
-- Hauptstaedte der anderen Fraktion: neutrale Haendler dort (z. B. Winterhauch-Goblins) erreicht man nicht
M.ENEMY_CAPITALS = {Alliance = {[1454] = true, [1456] = true, [1458] = true}, Horde = {[1453] = true, [1455] = true, [1457] = true}}
function M.FromQuestDB(faction)
    if M.dbCache[faction] then return M.dbCache[faction] end
    local d = rawget(_G, "GuildTripQuestDB")
    local out = {}
    if type(d) == "table" and type(d.vendors) == "table" then
        local names = d.svcNames or d.names or {}
        local want = faction == "Alliance" and 1 or faction == "Horde" and 2 or 0
        for id, v in pairs(d.vendors) do
            local enemy = M.ENEMY_CAPITALS[faction] or {}
            if names[id] and (v[4] == 3 or v[4] == want) and not enemy[v[1]] then
                local cats = {}
                for c in tostring(v[5] or ""):gmatch("%S+") do cats[c] = true end
                out["c" .. id] = {name = names[id], mapID = v[1], x = v[2] / 1000, y = v[3] / 1000, cats = cats}
            end
        end
    end
    M.dbCache[faction] = out
    return out
end
-- Kurztext: "Phiolen · Handwerkswaren · Reparieren"
function M.CatText(cats, max)
    local parts = {}
    for _, c in ipairs(M.CATEGORIES) do
        if cats[c[1]] and c[1] ~= "misc" then parts[#parts + 1] = T(c[2]) end
    end
    if max and #parts > max then parts = {unpack(parts, 1, max)} parts[#parts + 1] = "…" end
    return table.concat(parts, " · ")
end

function M:Filter()
    local db = ONE.db and type(ONE.db.nav) == "table" and ONE.db.nav
    return db and db.merchantFilter or "all"
end
function M:SetFilter(v)
    if not ONE.db then return end
    ONE.db.nav = type(ONE.db.nav) == "table" and ONE.db.nav or {}
    ONE.db.nav.merchantFilter = v
end
function M:FilterOptions()
    local out = {{value = "all", text = "Alle Händler"}}
    for _, c in ipairs(M.CATEGORIES) do out[#out + 1] = {value = c[1], text = c[2]} end
    return out
end

function M:Initialize()
    if ONE.UI and ONE.UI.AddShareOption then
        ONE.UI:AddShareOption({id = "merchants", module = "nav", order = 27, label = "Händler-Funde teilen",
            tooltip = "Händler, die du öffnest, gehen mit Ort und Angebots-Gruppen (z. B. Phiolen, Munition) an Gildenmitglieder mit Guild Trip – so füllt sich das Händler-Verzeichnis in der Navi für alle.",
            get = function() return M:IsSharing() end, set = function(on) M:SetSharing(on) end})
    end
    if not CreateFrame then return false end
    local frame = CreateFrame("Frame")
    pcall(frame.RegisterEvent, frame, "MERCHANT_SHOW")
    frame:SetScript("OnEvent", function()
        -- kurz warten: das Angebot ist beim Oeffnen nicht immer sofort vollstaendig
        if C_Timer and C_Timer.After then C_Timer.After(.5, function() pcall(M.OnShow, M) end) else pcall(M.OnShow, M) end
    end)
    self.frame = frame
    return true
end
