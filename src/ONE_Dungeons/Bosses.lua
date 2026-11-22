-- Guild Trip Dungeons: Bosse und Beute auf der Dungeon-Seite (19.11.2026, Nutzer-OK).
-- Daten: BossData.lua (erzeugt mit scripts/import_codex.lua aus "Dungeon Codex" von Baxter x DLDVLPR,
-- Nutzung unter GPL-3.0-or-later ausdruecklich erlaubt). Oben die Bosse, darunter die Beute des
-- gewaehlten Bosses: Symbol, Name in Qualitaetsfarbe, Platz/Art, Chance (wenn bekannt).
-- Tooltip = echter Gegenstands-Tooltip; Umschalt+Klick verlinkt im Chat (HandleModifiedItemClick).
-- Bossnamen: Spielsprache Deutsch -> im Spiel gesammelter Name (Roster) oder deutscher Name aus den Daten.
local _, dungeons = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local Bosses = {}
dungeons.Bosses = Bosses

local QUALITY = {[0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000"}
local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

-- Bossliste eines Dungeons (Katalog-Schluessel) und ihre Quelle, oder nil.
-- Forever-Dungeons: Dungeon Codex (BossData.lua); klassische: classic-db (BossDataClassic.lua).
-- dataOnly: nur mitgelieferte Daten; sonst ohne Daten die selbst gesammelten Bosse (Roster) als Liste.
function Bosses:For(key, dataOnly)
    if not key or key == "source" then return nil end
    for _, name in ipairs({"BossData", "BossDataClassic"}) do
        local data = dungeons[name]
        local list = data and data[key]
        if type(list) == "table" and #list > 0 then return list, name end
    end
    if dataOnly then return nil end
    local found = self:Found(key)
    if #found > 0 then return found, "Roster" end
    return nil
end

local function RosterEntry(key)
    local roster = ONE.db and type(ONE.db.dungeons) == "table" and ONE.db.dungeons.roster
    local e = type(roster) == "table" and roster[key]
    return type(e) == "table" and type(e.npcs) == "table" and e or nil
end

-- selbst gesammelte Bosse eines Dungeons (fuer Dungeons ohne mitgelieferte Daten)
function Bosses:Found(key)
    local e, out = RosterEntry(key), {}
    if not e then return out end
    for npc, n in pairs(e.npcs) do
        if type(n) == "table" and n.boss then
            out[#out + 1] = {npc = npc, name = type(n.name) == "string" and n.name or ("#" .. npc), items = {}, found = true}
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Beute eines Bosses: mitgelieferte Teile + selbst gefundene (found = Anzahl, looted = Leichen)
function Bosses:LootOf(key, b)
    local items, known = {}, {}
    for _, id in ipairs(b.items or {}) do
        known[id] = true
        items[#items + 1] = {id = id, chance = b.drops and b.drops[id] or nil}
    end
    local e = RosterEntry(key)
    local n = e and e.npcs[b.npc]
    local loot = type(n) == "table" and type(n.loot) == "table" and n.loot or {}
    local looted = type(n) == "table" and tonumber(n.looted) or 0
    local extra = {}
    for id, c in pairs(loot) do
        if known[id] then
            for _, it in ipairs(items) do if it.id == id then it.found, it.looted = c, looted end end
        else
            extra[#extra + 1] = {id = id, found = c, looted = looted, own = true}
        end
    end
    table.sort(extra, function(x, y) if x.found ~= y.found then return x.found > y.found end return x.id < y.id end)
    for _, it in ipairs(extra) do items[#items + 1] = it end
    return items
end

function Bosses:Credit(key)
    local _, from = self:For(key)
    if from == "Roster" then
        return T("Bosse und Beute: von dir im Spiel gesammelt (nur bei dir gespeichert)")
    end
    if from == "BossDataClassic" then
        return T("Bosse und Beute: cmangos classic-db (GPL-3) – Classic-Stand, Forever-Änderungen fehlen")
    end
    local s = dungeons.BossData and dungeons.BossData.source
    return T("Bosse und Beute: Dungeon Codex (Baxter x DLDVLPR), mit Erlaubnis")
        .. (s and s.version and (" · v" .. s.version) or "")
end

local function Seen(key, npc)
    local roster = ONE.db and type(ONE.db.dungeons) == "table" and ONE.db.dungeons.roster
    local e = type(roster) == "table" and roster[key]
    local n = e and type(e.npcs) == "table" and e.npcs[npc]
    return type(n) == "table" and n or nil
end

function Bosses:Name(key, b)
    if ONE.Language and ONE:Language() == "de" then
        local seen = Seen(key, b.npc)
        return (seen and type(seen.name) == "string" and seen.name ~= "" and seen.name) or b.de or b.name
    end
    return b.name
end

function Bosses:Killed(key, b)
    local seen = Seen(key, b.npc)
    if seen and (tonumber(seen.n) or 0) > 0 then return true end
    local roster = ONE.db and type(ONE.db.dungeons) == "table" and ONE.db.dungeons.roster
    local e = type(roster) == "table" and roster[key]
    return (b.encounter and e and type(e.bosses) == "table" and e.bosses[b.encounter] ~= nil) and true or false
end

-- Gegenstand: Name, Qualitaet, Symbol, Platz/Art (laedt nach, wenn noch nicht im Zwischenspeicher)
function Bosses.Item(id)
    local C = G("C_Item")
    local name, link, quality = Call(G("GetItemInfo"), id)
    if not name and C then name = Call(C.GetItemNameByID, id) end
    if quality == nil and C then quality = Call(C.GetItemQualityByID, id) end
    if not name and C then Call(C.RequestLoadItemDataByID, id) end
    local instant = (C and C.GetItemInfoInstant) or G("GetItemInfoInstant")
    local _, _, subType, equipLoc, icon = Call(instant, id)
    local slot = equipLoc and equipLoc ~= "" and G(equipLoc) or nil
    local kind
    if type(slot) == "string" and type(subType) == "string" and subType ~= "" and subType ~= slot then
        kind = slot .. " · " .. subType
    else
        kind = (type(slot) == "string" and slot) or subType or ""
    end
    return {id = id, name = name, link = link, quality = quality, icon = icon, kind = kind}
end

function Bosses.Colored(it)
    local text = it.name or ("#" .. it.id)
    return "|cff" .. (QUALITY[it.quality] or "ffffff") .. text .. "|r"
end

-- Baut Boss- und Beuteliste nebeneinander in die Dungeon-Karte (links Bosse, rechts Beute,
-- beide volle Hoehe). geom = {x, y, width, height}
Bosses.BOSS_W = 184
function Bosses:Build(card, geom)
    local view = {key = nil, list = nil, boss = nil}
    local BW = Bosses.BOSS_W
    local LW = geom.width - BW - 8
    local bossList, lootList
    bossList = ONE.Kit:List(card, {x = geom.x, y = geom.y, width = BW, height = geom.height, rowHeight = 22,
        columns = {
            {key = "name", title = "BOSS", width = BW - 24 - 8, indent = 4},
        },
        render = function(row, b, cells)
            local mark = Bosses:Killed(view.key, b) and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " or ""
            cells.name:SetText(mark .. Bosses:Name(view.key, b) .. (b.rare and ("  |cff9d9d9d(" .. T("selten") .. ")|r") or ""))
            cells.name:SetTextColor(1, .82, 0)
            if not row.selection then
                row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
                row.selection:SetAllPoints(row)
                row.selection:SetColorTexture(1, .82, 0, .14)
            end
            if view.boss == b then row.selection:Show() else row.selection:Hide() end
        end,
        onClick = function(_, b) view.boss = b Bosses.ShowLoot(view) end,
        onEnter = function(row, b)
            local tip = G("GameTooltip")
            if not tip then return end
            tip:SetOwner(row, "ANCHOR_RIGHT")
            tip:SetText(Bosses:Name(view.key, b))
            if b.name ~= Bosses:Name(view.key, b) then tip:AddLine(b.name, .62, .62, .62) end
            if b.level then tip:AddLine(T("Stufe %d", b.level), 1, 1, 1) end
            tip:AddLine(T("%d Gegenstände", #b.items), .8, .8, .8)
            if b.rare then tip:AddLine(T("Seltener Gegner – nicht immer da"), .8, .8, .8) end
            if Bosses:Killed(view.key, b) then tip:AddLine(T("Schon besiegt (von dir gesammelt)"), .5, .9, .5) end
            tip:AddLine(T("Klicken: Beute anzeigen"), .7, .7, .7)
            tip:Show()
        end,
    })
    -- Beute zweizeilig: oben Name in Qualitaetsfarbe, darunter Platz/Art und ggf. Chance
    lootList = ONE.Kit:List(card, {x = geom.x + BW + 8, y = geom.y, width = LW, height = geom.height, rowHeight = 34,
        columns = {
            {key = "item", title = "BEUTE", width = LW - 24 - 8, indent = 30},
        },
        render = function(row, it, cells)
            if it.none then
                if row.icon then row.icon:Hide() if row.icon.__oneRing then row.icon.__oneRing:Hide() end end
                if row.sub then row.sub:SetText("") end
                cells.item:SetText("|cff9d9d9d" .. T("Keine Beute bekannt (oft liegt sie in einer Truhe)") .. "|r")
                return
            end
            local info = Bosses.Item(it.id)
            if not row.icon then
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(26, 26)
                row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
                if ONE.Glass and ONE.Glass.RoundIcon then ONE.Glass:RoundIcon(row, row.icon) end
                cells.item:ClearAllPoints()
                cells.item:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -3)
                row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.sub:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -19)
                row.sub:SetWidth(LW - 24 - 8 - 36)
                row.sub:SetJustifyH("LEFT")
                if ONE.Fit then ONE.Fit:Line(row.sub, row) end
            end
            if info.icon then row.icon:SetTexture(info.icon) row.icon:Show() else row.icon:Hide() end
            if row.icon.__oneRing then row.icon.__oneRing:SetShown(info.icon and true or false) end
            cells.item:SetText(Bosses.Colored(info))
            local sub = info.kind or ""
            if it.chance then sub = (sub ~= "" and (sub .. " · ") or "") .. string.format("%.0f %%", it.chance) end
            if it.found then
                sub = (sub ~= "" and (sub .. " · ") or "") .. "|cff80e680" .. T("bei dir %d von %d", it.found, math.max(it.found, it.looted or 0)) .. "|r"
            end
            row.sub:SetText(sub)
            row.sub:SetTextColor(.7, .7, .7)
        end,
        onClick = function(_, it)
            if it.none then return end
            local info = Bosses.Item(it.id)
            local link = info.link or ("item:" .. it.id)
            local handle = G("HandleModifiedItemClick")
            if info.link and handle then Call(handle, link) end
        end,
        onEnter = function(row, it)
            local tip = G("GameTooltip")
            if not tip or it.none then return end
            tip:SetOwner(row, "ANCHOR_RIGHT")
            if tip.SetHyperlink then pcall(tip.SetHyperlink, tip, "item:" .. it.id) end
            tip:AddLine(" ")
            if view.boss then tip:AddLine(T("Beute von %s", Bosses:Name(view.key, view.boss)), 1, .82, 0) end
            if it.found then
                tip:AddLine(T("Selbst gefunden: %d-mal bei %d Plünderungen", it.found, math.max(it.found, it.looted or 0)), .5, .9, .5)
                if it.own then tip:AddLine(T("Nicht in den mitgelieferten Daten – neu in Forever?"), .7, .7, .7, true) end
            end
            tip:AddLine(T("Umschalt+Klick: im Chat verlinken"), .5, .5, .5)
            tip:Show()
        end,
    })
    view.bossList, view.lootList = bossList, lootList
    -- Gegenstandsnamen kommen vom Server nach: Beute neu zeichnen (gebremst)
    local ev = CreateFrame("Frame", nil, card)
    local pending
    if ev.RegisterEvent then pcall(ev.RegisterEvent, ev, "GET_ITEM_INFO_RECEIVED") end
    ev:SetScript("OnEvent", function()
        if pending or not (lootList.box.IsVisible and lootList.box:IsVisible()) then return end
        pending = true
        local timer = G("C_Timer")
        if timer and timer.After then
            timer.After(.3, function() pending = nil lootList:Update() end)
        else pending = nil lootList:Update() end
    end)
    function view:Show(key)
        local list = Bosses:For(key)
        if self.key ~= key then self.boss = nil end
        self.key, self.list = key, list or {}
        if not self.boss then self.boss = self.list[1] end
        bossList.box:Show() lootList.box:Show()
        bossList:SetItems(self.list)
        Bosses.ShowLoot(self)
    end
    function view:Hide() bossList.box:Hide() lootList.box:Hide() end
    view:Hide()
    return view
end

function Bosses.ShowLoot(view)
    local b = view.boss
    local items = b and Bosses:LootOf(view.key, b) or {}
    if b and #items == 0 then items[1] = {none = true} end
    view.bossList:Update()
    view.lootList:SetItems(items)
end
