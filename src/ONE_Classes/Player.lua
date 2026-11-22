local _, classes = ...
local ONE = _G.ProjectONE

-- Liest den eigenen Charakter: Klasse, Stufe, bekannte Zauber (Zauberbuch)
-- und Talente (neues Talentsystem C_Traits, das Forever benutzt).
-- Nichts wird gespeichert oder verschickt.
local Player = {}
classes.Player = Player

local function Path(path)
    local cur = _G
    for part in path:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[part]
    end
    return cur
end
Player.Path = Path

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

function Player.SpellInfo(id)
    local info = Call(Path("C_Spell.GetSpellInfo"), id)
    if type(info) == "table" then return info.name, info.iconID end
    local name, _, icon = Call(GetSpellInfo, id)
    return name, icon
end

-- Zauberbuch: Name -> hoechster bekannter Rang (spaeter im Buch = hoeherer Rang).
-- Je Name: hoechster Rang (id), Symbol und alle bekannten Raenge (ids).
-- Rang aus dem Zusatztext ("Rang 3"); ohne Angabe gilt: spaeter im Buch = hoeher.
function Player:KnownSpells()
    local known = {}
    local order = 0
    local tab = 0
    local function Add(id, name, icon, subName)
        if type(id) ~= "number" then return end
        if not name then name, icon = Player.SpellInfo(id) end
        if type(name) ~= "string" then return end
        order = order + 1
        local rank = type(subName) == "string" and tonumber(subName:match("(%d+)")) or nil
        local entry = known[name] or {ids = {}, best = -1, tab = tab, name = name}
        known[name] = entry
        entry.ids[id] = true
        local score = rank and rank * 100000 + order or order
        if score > entry.best then entry.best, entry.id, entry.icon = score, id, icon end
    end
    local book, bank = Path("C_SpellBook"), Path("Enum.SpellBookSpellBank.Player")
    if book and type(book.GetNumSpellBookSkillLines) == "function" and bank ~= nil then
        for t = 1, (Call(book.GetNumSpellBookSkillLines) or 0) do
            tab = t
            local line = Call(book.GetSpellBookSkillLineInfo, t)
            if type(line) == "table" then
                local offset = line.itemIndexOffset or 0
                for i = offset + 1, offset + (line.numSpellBookItems or 0) do
                    local item = Call(book.GetSpellBookItemInfo, i, bank)
                    if type(item) == "table" and not item.isPassive then Add(item.spellID, item.name, item.iconID, item.subName) end
                end
            end
        end
        return known
    end
    for t = 1, (Call(GetNumSpellTabs) or 0) do
        tab = t
        local _, _, offset, num = Call(GetSpellTabInfo, t)
        for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
            local kind, id = Call(GetSpellBookItemInfo, i, "spell")
            local _, subName = Call(GetSpellBookItemName, i, "spell")
            if kind == "SPELL" then Add(id, nil, nil, subName) end
        end
    end
    return known
end

-- Talente: Zauber-Nummer -> {ranks, max, x, y, canBuy}
function Player:Talents()
    local talents = {}
    local configID = Call(Path("C_ClassTalents.GetActiveConfigID"))
    local traits = Path("C_Traits")
    if not configID or type(traits) ~= "table" then return talents end
    local config = Call(traits.GetConfigInfo, configID)
    for _, treeID in ipairs(type(config) == "table" and config.treeIDs or {}) do
        for _, nodeID in ipairs(Call(traits.GetTreeNodes, treeID) or {}) do
            local node = Call(traits.GetNodeInfo, configID, nodeID)
            -- Forever hat versteckte Doppel-Knoten weit ausserhalb des Baums (z. B. Jaeger
            -- "Blitzartige Reflexe" bei x 102800, Priester "Heiligspezialisierung" bei y 21300)
            if type(node) == "table" and (node.posY or 0) < 10000 and (node.posX or 0) < 20000 then
                for _, entryID in ipairs(node.entryIDs or {}) do
                    local entry = Call(traits.GetEntryInfo, configID, entryID)
                    local def = type(entry) == "table" and Call(traits.GetDefinitionInfo, entry.definitionID)
                    local spellID = type(def) == "table" and def.spellID
                    if type(spellID) == "number" and not talents[spellID] then
                        local name, icon = Player.SpellInfo(spellID)
                        talents[spellID] = {spell = spellID, name = name, icon = icon,
                            ranks = tonumber(node.ranksPurchased or node.currentRank) or 0,
                            max = tonumber(node.maxRanks) or 1, x = tonumber(node.posX) or 0, y = tonumber(node.posY) or 0,
                            canBuy = node.canPurchaseRank, node = nodeID, entry = entryID, config = configID,
                            tree = treeID, choice = #(node.entryIDs or {}) > 1}
                    end
                end
            end
        end
    end
    return talents
end

-- Freie Talentpunkte (neues System: Waehrung des Baums; sonst klassisch).
function Player:FreePoints()
    local configID = Call(Path("C_ClassTalents.GetActiveConfigID"))
    local traits = Path("C_Traits")
    if configID and type(traits) == "table" and type(traits.GetTreeCurrencyInfo) == "function" then
        local config = Call(traits.GetConfigInfo, configID)
        local total, found = 0, false
        for _, treeID in ipairs(type(config) == "table" and config.treeIDs or {}) do
            for _, c in ipairs(Call(traits.GetTreeCurrencyInfo, configID, treeID, false) or {}) do
                if type(c) == "table" and type(c.quantity) == "number" then total, found = total + c.quantity, true end
            end
        end
        if found then return total end
    end
    return tonumber((Call(UnitCharacterPoints, "player"))) or 0
end

-- Lage im Talentbaum: Gruppe (Ausrichtung 1..n, getrennt durch grosse Luecken
-- in x), Spalte und Reihe im Raster. Schreibt group/col/row in jedes Talent.
function Player.Layout(talents)
    local xs, ys = {}, {}
    for _, t in pairs(talents) do xs[#xs + 1] = t.x; ys[#ys + 1] = t.y end
    table.sort(xs); table.sort(ys)
    local function Step(list)
        local step
        for i = 2, #list do
            local d = list[i] - list[i - 1]
            if d > 0 and (not step or d < step) then step = d end
        end
        return step or 1
    end
    local dx, dy = Step(xs), Step(ys)
    local groups, last = {}, nil
    for _, x in ipairs(xs) do
        if not last or x - last > 1200 then groups[#groups + 1] = x end
        last = x
    end
    for _, t in pairs(talents) do
        local g = 1
        for i, start in ipairs(groups) do if t.x >= start then g = i end end
        t.group = g
        t.col = math.floor((t.x - groups[g]) / dx + .5)
        t.row = math.floor((t.y - (ys[1] or 0)) / dy + .5)
    end
    return #groups
end

-- Punkte je Ausrichtung
function Player.SpecPoints(talents)
    local n = Player.Layout(talents)
    local points = {}
    for i = 1, n do points[i] = 0 end
    for _, t in pairs(talents) do points[t.group] = (points[t.group] or 0) + t.ranks end
    return points
end

-- Wo bin ich? Dungeon-Instanz -> "dungeon", Schlachtzug -> "raid", sonst "solo".
function Player:DetectSituation()
    local inInstance, kind = Call(IsInInstance)
    if inInstance and kind == "raid" then return "raid" end
    if inInstance and kind == "party" then return "dungeon" end
    return "solo"
end

-- Zwischenspeicher: Zauberbuch und Talentbaum komplett zu lesen ist teuer (hunderte
-- Abfragen). Die Buff-Erinnerung fragt bei jeder Aura-Aenderung – ohne Speicher lief
-- das im Kampf staendig und machte das Spiel zaeh (Meldungen 0.6.4). Neu gelesen wird
-- nur nach echten Aenderungen (Ereignisse unten) oder spaetestens nach 30 Sekunden.
Player.cache, Player.maxAge = {}, 30
function Player:Invalidate() self.cache = {} end
function Player:Cached(key, fn)
    local now = type(GetTime) == "function" and GetTime() or 0
    local c = self.cache[key]
    if c and now - c.at < self.maxAge and now >= c.at then return c.value end
    local value = fn(self)
    self.cache[key] = {value = value, at = now}
    return value
end
if type(CreateFrame) == "function" then
    local ok, watch = pcall(CreateFrame, "Frame")
    if ok and watch and watch.RegisterEvent then
        for _, ev in ipairs({"SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED",
            "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_ENTERING_WORLD"}) do
            pcall(watch.RegisterEvent, watch, ev)
        end
        if watch.SetScript then watch:SetScript("OnEvent", function() Player:Invalidate() end) end
    end
end

-- Spielerzustand fuer die Seite und die Tipps.
function Player:Read(choice)
    local _, classFile = Call(UnitClass, "player")
    local p = {classFile = classFile, level = tonumber((Call(UnitLevel, "player"))) or 1}
    p.known = self:Cached("known", self.KnownSpells)
    p.talents = self:Cached("talents", self.Talents)
    p.points = Player.SpecPoints(p.talents)
    local def = classes.Data.classes[classFile or ""]
    local best, bestPoints = def and def.defaultSpec or 1, 0
    for i, pts in ipairs(p.points) do if pts > bestPoints then best, bestPoints = i, pts end end
    p.autoSpec, p.spec = best, choice or best
    p.spent = 0
    for _, pts in ipairs(p.points) do p.spent = p.spent + pts end
    -- id darf auch eine Liste sein (gleicher Zauber, andere Namen je Rang,
    -- z. B. Forevers "Heilige Pein" Rang 1 / "Goettliche Pein" ab Rang 2):
    -- der erste bekannte Eintrag gewinnt.
    -- exact = genau diesen Rang nehmen (z. B. Frostblitz Rang 1 zum Bremsen/Manasparen), sofern bekannt
    function p:Spell(id, exact)
        if type(id) == "table" then
            local first
            for _, one in ipairs(id) do
                local s = self:Spell(one)
                if s.known then return s end
                first = first or s
            end
            return first or {id = 0, known = false}
        end
        local name, icon = Player.SpellInfo(id)
        local mine = name and self.known[name]
        local useID = mine and mine.id or id
        if exact and mine and mine.ids[id] then useID = id end
        return {id = useID, icon = mine and mine.icon or icon, name = name, known = mine ~= nil}
    end
    function p:Knows(id) return self:Spell(id).known end
    function p:TalentRank(id) local t = self.talents[id]; return t and t.ranks or 0 end
    p.free = self:Cached("free", self.FreePoints)
    p.autoSituation = self:DetectSituation()
    local chosen = classes.Data.situationNames[(ONE and ONE.db and ONE.db.classGuide or {}).situation or ""] and ONE.db.classGuide.situation
    p.situation = chosen or p.autoSituation
    return p
end

-- Naechster Talentpunkt laut Plan: erster Eintrag unter Zielrang, der jetzt
-- kaufbar ist; sonst der erste offene.
function Player.NextTalent(p, plan)
    local firstOpen
    for _, step in ipairs(plan or {}) do
        local t = p.talents[step[1]]
        if t and t.ranks < step[2] then
            if t.canBuy then return step, t end
            firstOpen = firstOpen or {step, t}
        end
    end
    if firstOpen then return firstOpen[1], firstOpen[2] end
end
