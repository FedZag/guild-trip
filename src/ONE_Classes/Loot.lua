-- Guild Trip: Beute selbst sammeln (0.6.6) – Grundlage fuer "beste Ausruestung und wo es sie gibt".
-- Forever liefert keine Beute-Daten (Dungeon-Kompendium leer, Lootcheck 15.11.2026), deshalb:
-- beim Pluendern ausruestbare Gegenstaende ab Qualitaet "selten" (gruen) merken – mit Gegner
-- (Name, Boss/Elite/Rare), Gebiet bzw. Dungeon und Position. Keine Spielernamen.
-- Gespeichert kontoweit in ONE.db.classGuide.loot[itemID]; Funde gehen ueber
-- "Zauberdaten teilen" an den Entwickler und ins Startpaket (LootPack.lua).
local _, classes = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local Loot = {maxItems = 3000, maxSources = 5}
classes.Loot = Loot

local function Call(fn, ...)
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
local function Now() return Call(GetServerTime) or Call(time) or 0 end

function Loot:Store()
    if not ONE.db then return {} end
    ONE.db.classGuide = type(ONE.db.classGuide) == "table" and ONE.db.classGuide or {}
    local s = type(ONE.db.classGuide.loot) == "table" and ONE.db.classGuide.loot or {}
    ONE.db.classGuide.loot = s
    return s
end

-- Gegner-Schluessel aus der GUID ("Creature-0-…-NPCID-…" -> c1234, Kisten o1234)
function Loot.SourceKey(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if not kind then return nil end
    return (kind == "GameObject" and "o" or "c") .. id
end

-- Art des Gegners: Boss (in Instanz, "worldboss"/Stufe -1), Elite, Rare, normal
function Loot.Kind(classification, inInstance)
    if classification == "worldboss" then return "boss" end
    if classification == "rareelite" then return "rare" end
    if classification == "rare" then return "rare" end
    if classification == "elite" then return inInstance and "elite" or "elite" end
    return "normal"
end

-- Einen Fund eintragen. item = {id, quality, equipLoc, minLevel, ilvl}, src = {key, name, kind, mapID, x, y, instance}
function Loot:Add(item, src)
    if not (item and item.id and src and src.key) then return false end
    local store = self:Store()
    local e = store[item.id]
    local new = not e
    e = e or {sources = {}}
    store[item.id] = e
    e.q, e.slot, e.minLevel, e.ilvl = item.quality or e.q, item.equipLoc or e.slot, item.minLevel or e.minLevel, item.ilvl or e.ilvl
    e.seen = Now()
    local s = e.sources[src.key]
    if not s then
        local n = 0
        for _ in pairs(e.sources) do n = n + 1 end
        if n >= self.maxSources then return new end
        s = {count = 0}
        e.sources[src.key] = s
        new = true
    end
    s.name, s.kind, s.instance = src.name or s.name, src.kind or s.kind, src.instance or s.instance
    s.mapID, s.x, s.y = src.mapID or s.mapID, src.x or s.x, src.y or s.y
    s.count = (s.count or 0) + 1
    if new then self:Trim() end
    return new
end
function Loot:Trim()
    local store, list = self:Store(), {}
    for id, e in pairs(store) do list[#list + 1] = {id, e.seen or 0} end
    if #list <= self.maxItems then return end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    for i = 1, #list - self.maxItems do store[list[i][1]] = nil end
end

-- Lootfenster lesen
function Loot:OnLoot()
    if ONE.FeatureOn and not ONE:FeatureOn("classes.loot") then return 0 end
    local inInstance = Call(IsInInstance) and true or false
    local instance = inInstance and Call(GetInstanceInfo) or nil
    local mapID = Call(C_Map and C_Map.GetBestMapForUnit, "player")
    local pos = mapID and Call(C_Map.GetPlayerMapPosition, mapID, "player")
    local x, y
    if type(pos) == "table" then x, y = pos.x, pos.y if x == nil and pos.GetXY then x, y = pos:GetXY() end end
    -- Gegner: Ziel, wenn es der gepluenderte ist (Name/Art); sonst nur Nummer
    local targetGUID = Call(UnitGUID, "target")
    local targetName = Call(UnitName, "target")
    local targetClass = Call(UnitClassification, "target")
    local added = 0
    for slot = 1, Call(GetNumLootItems) or 0 do
        local link = Call(GetLootSlotLink, slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID then
            local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
            local _, _, _, equipLoc = Call(fn, itemID)
            local _, _, quality, ilvl, minLevel = Call((C_Item and C_Item.GetItemInfo) or GetItemInfo, link)
            if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG" and (quality or 2) >= 2 then
                local guid = Call(GetLootSourceInfo, slot)
                local key = Loot.SourceKey(guid)
                if key then
                    local same = targetGUID and targetGUID == guid
                    local kind = same and Loot.Kind(targetClass, inInstance) or (key:sub(1, 1) == "o" and "object" or nil)
                    if Loot:Add({id = itemID, quality = quality, equipLoc = equipLoc, minLevel = minLevel, ilvl = ilvl},
                        {key = key, name = same and targetName or nil, kind = kind, instance = instance,
                         mapID = mapID, x = x and math.floor(x * 1000 + .5) / 1000, y = y and math.floor(y * 1000 + .5) / 1000}) then
                        added = added + 1
                    end
                end
            end
        end
    end
    return added
end

-- Fundort-Text fuer den Tooltip: "fällt bei Name (Elite) – Brachland"
function Loot:SourceText(itemID)
    local e = self:Store()[itemID] or (classes.LootPack or {})[itemID]
    if not (e and e.sources) then return nil end
    local best, bestCount
    for _, s in pairs(e.sources) do
        if not bestCount or (s.count or 0) > bestCount then best, bestCount = s, s.count or 0 end
    end
    if not best then return nil end
    local kinds = {boss = T("Boss"), elite = T("Elite"), rare = T("Rar"), object = T("Kiste")}
    local who = best.name or (best.kind == "object" and T("Kiste") or T("Gegner"))
    local kind = best.kind and kinds[best.kind] and best.kind ~= "object" and (" (" .. kinds[best.kind] .. ")") or ""
    local where = best.instance
    if not where and best.mapID then
        local info = Call(C_Map and C_Map.GetMapInfo, best.mapID)
        where = type(info) == "table" and info.name or nil
    end
    return T("Guild Trip: fällt bei %s", who .. kind) .. (where and (" – " .. where) or "")
end

function Loot:Initialize()
    if not CreateFrame then return false end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "LOOT_OPENED") -- nur einmal je Lootfenster (LOOT_READY kaeme zusaetzlich)
    f:SetScript("OnEvent", function() pcall(Loot.OnLoot, Loot) end)
    self.frame = f
    return true
end
