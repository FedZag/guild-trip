local _, ns = ...
local ONE = _G.ProjectONE or ns -- liegt in ONE_Dev
local function DevDB() return (ONE.DevDB and ONE:DevDB()) or ONE.db end

-- /trip zauber: liest Zauberbuch, Talente, Tooltips und Grundwerte des eigenen
-- Charakters aus und legt sie lokal in ProjectONEDB.spellScan ab (je Klasse der
-- letzte Stand). Grundlage fuer den Klassen-Ratgeber. Nichts wird verschickt.
-- Gespeichert wird erst beim Ausloggen oder /reload (so arbeitet WoW).
local Scan = {}
ONE.SpellScan = Scan

local function IsSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret == true
end

local function Plain(v)
    if IsSecret(v) then return "GEHEIM" end
    local t = type(v)
    if t == "number" then
        if v ~= v then return "NaN" end
        if v == math.floor(v) then return v end
        return math.floor(v * 1000 + 0.5) / 1000
    end
    if t == "string" or t == "boolean" or v == nil then return v end
    return "<" .. t .. ">"
end

local function Pack(...) return {n = select("#", ...), ...} end

-- Geschuetzter Aufruf; liefert alle Rueckgabewerte als einfache Liste.
local function Raw(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = Pack(pcall(fn, ...))
    if not r[1] then return nil end
    local out = {}
    for i = 2, r.n do out[i - 1] = Plain(r[i]) end
    return out
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

local function Path(path)
    local cur = _G
    for part in path:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[part]
    end
    return cur
end

local function SpellName(id)
    local info = Call(Path("C_Spell.GetSpellInfo"), id)
    if type(info) == "table" then return Plain(info.name) end
    return Plain((Call(GetSpellInfo, id)))
end

-- Flache Kopie einer Info-Tabelle (nur einfache Werte).
local function Copy(tbl)
    if type(tbl) ~= "table" or IsSecret(tbl) then return nil end
    local out = {}
    for k, v in pairs(tbl) do
        if type(k) == "string" or type(k) == "number" then
            local p = Plain(v)
            if type(p) ~= "string" or p:sub(1, 1) ~= "<" then out[k] = p end
        end
    end
    return out
end

-- Tooltip-Zeilen eines Zaubers oder Talents. Neuer Weg: C_TooltipInfo,
-- sonst ein unsichtbarer GameTooltip, dessen Textzeilen wir ablesen.
function Scan:TooltipLines(kind, a, b)
    local getter = kind == "spell" and Path("C_TooltipInfo.GetSpellByID")
        or kind == "talent" and Path("C_TooltipInfo.GetTalent")
    local data = getter and Call(getter, a, b)
    local lines = {}
    if type(data) == "table" and type(data.lines) == "table" then
        for _, line in ipairs(data.lines) do
            local left, right = Plain(line.leftText), Plain(line.rightText)
            if type(left) == "string" and left ~= "" then
                lines[#lines + 1] = (type(right) == "string" and right ~= "") and (left .. " | " .. right) or left
            end
        end
        if #lines > 0 then return lines end
    end
    local tip = self:Tooltip()
    if not tip then return lines end
    tip:ClearLines()
    local set = kind == "spell" and tip.SetSpellByID or tip.SetTalent
    if type(set) ~= "function" or not pcall(set, tip, a, b) then return lines end
    for i = 1, (Call(tip.NumLines, tip) or 0) do
        local l, r = _G["GuildTripScanTipTextLeft" .. i], _G["GuildTripScanTipTextRight" .. i]
        local left = l and Plain(Call(l.GetText, l))
        local right = r and Plain(Call(r.GetText, r))
        if type(left) == "string" and left ~= "" then
            lines[#lines + 1] = (type(right) == "string" and right ~= "") and (left .. " | " .. right) or left
        end
    end
    return lines
end

function Scan:Tooltip()
    if self.tip ~= nil then return self.tip or nil end
    local ok, tip = pcall(CreateFrame, "GameTooltip", "GuildTripScanTip", nil, "GameTooltipTemplate")
    if ok and tip then
        if WorldFrame then pcall(tip.SetOwner, tip, WorldFrame, "ANCHOR_NONE") end
        self.tip = tip
    else
        self.tip = false
    end
    return self.tip or nil
end

-- Zauberdetails ueber die neue (C_Spell) oder alte API.
function Scan:SpellDetails(id)
    local d = {id = id}
    local info = Call(Path("C_Spell.GetSpellInfo"), id)
    if type(info) == "table" then
        d.name, d.icon, d.castTime = Plain(info.name), Plain(info.iconID), Plain(info.castTime)
        d.minRange, d.maxRange = Plain(info.minRange), Plain(info.maxRange)
    else
        local r = Raw(GetSpellInfo, id)
        if r then d.name, d.rank, d.icon, d.castTime, d.minRange, d.maxRange = r[1], r[2], r[3], r[4], r[5], r[6] end
    end
    d.rawInfo = Raw(GetSpellInfo, id)
    d.subtext = Plain(Call(Path("C_Spell.GetSpellSubtext"), id) or Call(GetSpellSubtext, id))
    d.description = Plain(Call(Path("C_Spell.GetSpellDescription"), id) or Call(GetSpellDescription, id))
    local costs = Call(Path("C_Spell.GetSpellPowerCost"), id) or Call(GetSpellPowerCost, id)
    if type(costs) == "table" then
        d.cost = {}
        for _, c in ipairs(costs) do
            d.cost[#d.cost + 1] = {type = Plain(c.type), name = Plain(c.name), cost = Plain(c.cost),
                percent = Plain(c.costPercent), perSec = Plain(c.costPerSec)}
        end
    end
    d.baseCooldown = Plain(Call(GetSpellBaseCooldown, id))
    d.passive = Plain(Call(Path("C_Spell.IsSpellPassive"), id) or Call(IsPassiveSpell, id))
    d.tooltip = self:TooltipLines("spell", id)
    return d
end

local BOOK = "spell"

-- Zauberbuch: Reiter (Allgemein, Disziplin, Heilig, Schatten ...) mit ihren Zaubern.
function Scan:Spellbook()
    local tabs = {}
    local book = Path("C_SpellBook")
    local bank = Path("Enum.SpellBookSpellBank.Player")
    if book and type(book.GetNumSpellBookSkillLines) == "function" and bank ~= nil then
        for t = 1, (Call(book.GetNumSpellBookSkillLines) or 0) do
            local line = Call(book.GetSpellBookSkillLineInfo, t)
            if type(line) == "table" then
                local tab = {name = Plain(line.name), icon = Plain(line.iconID), spells = {}}
                local offset = line.itemIndexOffset or 0
                for i = offset + 1, offset + (line.numSpellBookItems or 0) do
                    local item = Call(book.GetSpellBookItemInfo, i, bank)
                    if type(item) == "table" and item.spellID then
                        local d = self:SpellDetails(item.spellID)
                        d.bookName, d.bookRank, d.itemType = Plain(item.name), Plain(item.subName), Plain(item.itemType)
                        tab.spells[#tab.spells + 1] = d
                    end
                end
                tabs[#tabs + 1] = tab
            end
        end
        return tabs, "C_SpellBook"
    end
    for t = 1, (Call(GetNumSpellTabs) or 0) do
        local name, icon, offset, num = Call(GetSpellTabInfo, t)
        local tab = {name = Plain(name), icon = Plain(icon), spells = {}}
        for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
            local kind, id = Call(GetSpellBookItemInfo, i, BOOK)
            local bookName, bookRank = Call(GetSpellBookItemName, i, BOOK)
            if id and (kind == "SPELL" or kind == "FUTURESPELL" or kind == nil) then
                local d = self:SpellDetails(id)
                d.bookName, d.bookRank, d.itemType = Plain(bookName), Plain(bookRank), Plain(kind)
                tab.spells[#tab.spells + 1] = d
            end
        end
        tabs[#tabs + 1] = tab
    end
    return tabs, "GetSpellTabInfo"
end

-- Talente: alte Talentbaum-API (drei Baeume je Klasse). Rohwerte werden mit
-- gespeichert, weil die Reihenfolge der Rueckgaben je Client abweicht.
-- Neues Talentsystem (C_ClassTalents/C_Traits), das Forever benutzt.
-- Talentpunkte: was liefert Forever? (Waehrung des Baums, klassische Zaehler,
-- Konfigurationen und je Knoten ALLE Felder – zum Abgleich nach Zuruecksetzen)
function Scan:TalentPoints()
    local out = {unitCharacterPoints = Raw(UnitCharacterPoints, "player"), talentTabs = Raw(GetNumTalentTabs)}
    local configID = Call(Path("C_ClassTalents.GetActiveConfigID"))
    out.activeConfig = Plain(configID)
    out.lastSelectedSavedConfig = Raw(Path("C_ClassTalents.GetLastSelectedSavedConfigID"), Call(UnitClass, "player") and 0 or 0)
    out.hasUnspent = Raw(Path("C_ClassTalents.HasUnspentTalentPoints"))
    local traits = Path("C_Traits")
    if not configID or type(traits) ~= "table" then return out end
    out.config = Copy(Call(traits.GetConfigInfo, configID))
    local config = Call(traits.GetConfigInfo, configID)
    out.trees = {}
    for _, treeID in ipairs(type(config) == "table" and config.treeIDs or {}) do
        local tree = {treeID = Plain(treeID), currency = {}, nodes = {}}
        for i, c in ipairs(Call(traits.GetTreeCurrencyInfo, configID, treeID, false) or {}) do tree.currency[i] = Copy(c) end
        tree.treeInfo = Copy(Call(traits.GetTreeInfo, configID, treeID))
        local n = 0
        for _, nodeID in ipairs(Call(traits.GetTreeNodes, treeID) or {}) do
            local node = Call(traits.GetNodeInfo, configID, nodeID)
            if type(node) == "table" and n < 60 then
                n = n + 1
                local copy = Copy(node) or {}
                copy.entryIDs = nil
                local active = node.activeEntry
                if type(active) == "table" then copy.activeEntryID, copy.activeEntryRank = Plain(active.entryID), Plain(active.rank) end
                tree.nodes[#tree.nodes + 1] = copy
            end
        end
        out.trees[#out.trees + 1] = tree
    end
    -- Ereignis-Mitschnitt seit dem Laden (Zuruecksetzen beim Lehrer usw.)
    out.events = self.talentEvents
    return out
end

-- Talent-Ereignisse mitschreiben (nur Namen und Zeit), um das Zuruecksetzen zu verstehen
do
    local f = CreateFrame("Frame")
    for _, ev in ipairs({"TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
        "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "CONFIRM_TALENT_WIPE"}) do
        pcall(f.RegisterEvent, f, ev)
    end
    f:SetScript("OnEvent", function(_, event, a1)
        Scan.talentEvents = Scan.talentEvents or {}
        if #Scan.talentEvents < 40 then
            Scan.talentEvents[#Scan.talentEvents + 1] = (Call(date, "%H:%M:%S") or "?") .. " " .. event .. " " .. tostring(Plain(a1))
        end
    end)
end

function Scan:TraitTalents()
    local trees = {}
    local configID = Call(Path("C_ClassTalents.GetActiveConfigID"))
    local traits = Path("C_Traits")
    if not configID or type(traits) ~= "table" then return trees end
    local config = Call(traits.GetConfigInfo, configID)
    local treeIDs = type(config) == "table" and config.treeIDs or {}
    for _, treeID in ipairs(treeIDs) do
        local tree = {api = "C_Traits", configID = Plain(configID), treeID = Plain(treeID), talents = {}}
        for _, nodeID in ipairs(Call(traits.GetTreeNodes, treeID) or {}) do
            local node = Call(traits.GetNodeInfo, configID, nodeID)
            if type(node) == "table" then
                for _, entryID in ipairs(node.entryIDs or {}) do
                    local entry = Call(traits.GetEntryInfo, configID, entryID)
                    local def = type(entry) == "table" and Call(traits.GetDefinitionInfo, entry.definitionID)
                    local spellID = type(def) == "table" and (def.spellID or def.overriddenSpellID)
                    local t = {node = Plain(nodeID), entry = Plain(entryID), spell = Plain(spellID),
                        ranks = Plain(node.ranksPurchased or node.currentRank), maxRanks = Plain(node.maxRanks),
                        x = Plain(node.posX), y = Plain(node.posY), type = Plain(node.type),
                        active = Plain(node.activeEntry and node.activeEntry.entryID == entryID),
                        visible = Plain(node.isVisible), granted = Plain(node.ranksIncreased)}
                    if type(spellID) == "number" then
                        t.name = SpellName(spellID)
                        t.description = Plain(Call(Path("C_Spell.GetSpellDescription"), spellID))
                        t.tooltip = self:TooltipLines("spell", spellID)
                    end
                    tree.talents[#tree.talents + 1] = t
                end
            end
        end
        trees[#trees + 1] = tree
    end
    return trees
end

function Scan:Talents()
    local trees = {}
    if type(GetNumTalentTabs) ~= "function" then return self:TraitTalents() end
    for t = 1, (Call(GetNumTalentTabs) or 0) do
        local tree = {raw = Raw(GetTalentTabInfo, t), talents = {}}
        for i = 1, (Call(GetNumTalents, t) or 0) do
            local raw = Raw(GetTalentInfo, t, i)
            if raw then
                tree.talents[#tree.talents + 1] = {raw = raw, tooltip = self:TooltipLines("talent", t, i)}
            end
        end
        trees[#trees + 1] = tree
    end
    return trees
end

function Scan:Stats()
    local s = {
        level = Plain(Call(UnitLevel, "player")),
        health = Plain(Call(UnitHealthMax, "player")),
        mana = Plain(Call(UnitPowerMax, "player", 0)),
        stats = {}, schools = {},
        healing = Plain(Call(GetSpellBonusHealing)),
        spellCrit = Plain(Call(GetSpellCritChance, 6)),
        manaRegen = Raw(GetManaRegen),
        attackPower = Raw(UnitAttackPower, "player"),
        armor = Raw(UnitArmor, "player"),
    }
    -- 1 Staerke, 2 Beweglichkeit, 3 Ausdauer, 4 Intelligenz, 5 Willenskraft
    for i = 1, 5 do s.stats[i] = Raw(UnitStat, "player", i) end
    -- 2 Heilig, 3 Feuer, 4 Natur, 5 Frost, 6 Schatten, 7 Arkan
    for i = 2, 7 do s.schools[i] = Plain(Call(GetSpellBonusDamage, i)) end
    return s
end

-- Welche Kampf-Daten der Client hergibt (fuer einen spaeteren Live-Hinweis).
Scan.apiProbe = {
    "C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetDebuffDataByIndex", "UnitAura", "UnitDebuff", "UnitBuff",
    "C_Spell.GetSpellCooldown", "GetSpellCooldown", "C_Spell.IsSpellUsable", "IsUsableSpell",
    "UnitCastingInfo", "UnitChannelInfo", "IsSpellInRange", "C_Spell.IsSpellInRange",
    "GetActionInfo", "IsCurrentSpell", "IsAutoRepeatSpell", "issecretvalue",
    "C_TooltipInfo.GetSpellByID", "C_SpellBook.GetSpellBookItemInfo", "GetSpellBookItemInfo",
    "GetTalentInfo", "C_ClassTalents.GetActiveConfigID", "C_Traits.GetConfigInfo", "C_Traits.GetTreeNodes",
    "C_Spell.RequestLoadSpellData", "Spell.CreateFromSpellID",
    "C_AssistedCombat.GetNextCastSpell", "C_AssistedCombat.IsAvailable", "C_AssistedCombat.GetRotationSpells",
}

function Scan:Apis()
    local out = {}
    for _, name in ipairs(self.apiProbe) do out[name] = type(Path(name)) == "function" end
    return out
end

-- Blizzards eingebaute Rotationshilfe (C_AssistedCombat): vorhanden, aktiv,
-- welche Zauber sie kennt und was sie gerade vorschlaegt.
function Scan:Assisted()
    local ac = Path("C_AssistedCombat")
    if type(ac) ~= "table" then return nil end
    local out = {available = Raw(ac.IsAvailable), next = Raw(ac.GetNextCastSpell, false)}
    local rotation = Call(ac.GetRotationSpells)
    if type(rotation) == "table" then
        out.rotation = {}
        for i, id in ipairs(rotation) do
            out.rotation[i] = {id = Plain(id), name = type(id) == "number" and SpellName(id) or nil}
        end
    end
    local cvars = Path("C_CVar.GetCVar")
    if type(cvars) == "function" then
        out.highlight = Plain(Call(cvars, "assistedCombatHighlight"))
    end
    return out
end

function Scan:Collect()
    local className, classFile = Call(UnitClass, "player")
    local build = Raw(GetBuildInfo) or {}
    local tabs, bookApi = self:Spellbook()
    local result = {
        time = Call(date, "%Y-%m-%d %H:%M") or "?",
        addon = ONE.version,
        build = {version = build[1], build = build[2], interface = build[4]},
        locale = Plain(Call(GetLocale)),
        class = Plain(className), classFile = Plain(classFile),
        race = Plain(Call(UnitRace, "player")),
        spellbookApi = bookApi,
        spellbook = tabs,
        talents = self:Talents(),
        talentPoints = self:TalentPoints(),
        stats = self:Stats(),
        apis = self:Apis(),
        assisted = self:Assisted(),
    }
    local spells, missing = 0, 0
    for _, tab in ipairs(tabs) do
        for _, d in ipairs(tab.spells) do
            spells = spells + 1
            if not d.passive and (not d.description or d.description == "") then missing = missing + 1 end
        end
    end
    local talents = 0
    for _, tree in ipairs(result.talents) do talents = talents + #tree.talents end
    result.counts = {spells = spells, missingText = missing, talents = talents}
    return result
end

function Scan:Run()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        ONE:Print("Bitte erst nach dem Kampf: /trip zauber")
        return nil
    end
    local result = self:Collect()
    local db = DevDB()
    db.spellScan = type(db.spellScan) == "table" and db.spellScan or {}
    db.spellScan[result.classFile or "UNKNOWN"] = result
    -- zusaetzlich je Klasse UND Volk (Volks-Priesterzauber; sonst ueberschreibt der
    -- zweite Priester den ersten)
    local okRace, _, raceFile = pcall(UnitRace, "player")
    if okRace and type(raceFile) == "string" then
        result.raceFile = raceFile
        db.spellScan[(result.classFile or "UNKNOWN") .. "-" .. raceFile] = result
    end
    local c = result.counts
    ONE:Print(("Zauber erfasst: %d Zauber, %d Talente (%s, Stufe %s)."):format(
        c.spells, c.talents, tostring(result.class or "?"), tostring(result.stats.level or "?")))
    if c.missingText > 0 then
        ONE:Print(c.missingText .. " Beschreibungen fehlen noch – einfach gleich nochmal /trip zauber eingeben.")
    end
    ONE:Print("Zum Speichern jetzt /reload eingeben (oder ausloggen).")
    return result
end

-- ---------------------------------------------------------------------------
-- /trip zauber alle: Zauber ALLER Klassen aus dem Spiel nachschlagen.
-- 1) Namen der Startliste (ONE.ClassSpells) holen, 2) Zauber-Nummern nach
-- diesen Namen durchsuchen (findet die anderen Raenge); im Forever-Bereich
-- (ab 1.000.000, dort liegen Forevers eigene Zauber) zusaetzlich alle Namen
-- merken, 3) Texte in Paketen anfordern, warten, lesen; fehlende Texte bis zu
-- zweimal neu anfordern. Alles in Haeppchen, damit das Spiel nicht stockt.
Scan.catalogRanges = {{1, 80000}, {1000000, 1400000}}
Scan.catalogForeverFrom = 1000000
Scan.catalogForeverMax = 30000
Scan.catalogNameChunk = 4000
Scan.catalogDetailChunk = 60
Scan.catalogMaxPerName = 25
Scan.catalogLoadBatch = 200
Scan.catalogWait = 3
Scan.catalogRetries = 2

local function Later(delay, fn)
    local timer = Path("C_Timer.After")
    if type(timer) == "function" then timer(delay, fn) else fn() end
end

local function HasText(d) return type(d.description) == "string" and d.description ~= "" end

-- Kurzform fuer jeden Rang (Tooltip nur, wenn die Beschreibung fehlt).
function Scan:SpellCompact(id)
    local d = self:SpellDetails(id)
    d.icon, d.minRange, d.rawInfo = nil, nil, nil
    if HasText(d) then d.tooltip = nil end
    return d
end

function Scan:RequestLoad(id)
    local request = Path("C_Spell.RequestLoadSpellData")
    if type(request) == "function" then pcall(request, id) end
    local mixin = Path("Spell.CreateFromSpellID")
    if type(mixin) == "function" then
        local ok, spell = pcall(mixin, Spell, id)
        if ok and type(spell) == "table" and type(spell.ContinueOnSpellLoad) == "function" then
            pcall(spell.ContinueOnSpellLoad, spell, function() end)
        end
    end
end

-- Fordert Texte paketweise an und ruft danach (mit Wartezeit) done() auf.
function Scan:LoadAll(items, done)
    local i = 1
    local function Step()
        local stop = math.min(#items, i + self.catalogLoadBatch - 1)
        for j = i, stop do self:RequestLoad(items[j].id) end
        i = stop + 1
        if i <= #items then Later(0.2, Step) else Later(self.catalogWait, done) end
    end
    Step()
end

-- Liest Werte fuer items in Haeppchen und ruft danach done() auf.
function Scan:ReadAll(items, done)
    local index = 1
    local function Step()
        local stop = math.min(#items, index + self.catalogDetailChunk - 1)
        for i = index, stop do
            local item = items[i]
            item.d = item.base and self:SpellDetails(item.id) or self:SpellCompact(item.id)
            item.d.rawInfo = nil
        end
        index = stop + 1
        if index <= #items then Later(0, Step) else done() end
    end
    Later(0, Step)
end

function Scan:Catalog(onDone)
    if self.catalogBusy then ONE:Print("Läuft schon – bitte kurz warten."); return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        ONE:Print("Bitte erst nach dem Kampf: /trip zauber alle")
        return false
    end
    self.catalogBusy = true
    local job = {wanted = {}, classes = {}, forever = {}}
    -- 1) Namen der Startliste
    for classFile, ids in pairs(ONE.ClassSpells or {}) do
        local list = {}
        for _, id in ipairs(ids) do
            local name = SpellName(id)
            local entry = {base = id, name = name, ranks = {}}
            list[#list + 1] = entry
            if type(name) == "string" and name ~= "" then
                job.wanted[name] = job.wanted[name] or {}
                table.insert(job.wanted[name], entry)
            end
        end
        job.classes[classFile] = list
    end
    ONE:Print("Suche Zauber aller Klassen … das dauert etwa eine Minute. Bitte nicht kämpfen.")

    local items = {}
    local function Finish(rounds)
        local build = Raw(GetBuildInfo) or {}
        local result = {
            time = Call(date, "%Y-%m-%d %H:%M") or "?", addon = ONE.version,
            build = {version = build[1], build = build[2], interface = build[4]},
            locale = Plain(Call(GetLocale)), ranges = self.catalogRanges, classes = {},
            forever = job.forever, rounds = rounds,
        }
        for _, item in ipairs(items) do table.insert(item.entry.ranks, item.d) end
        local total, noText, unknown = 0, 0, 0
        for classFile, list in pairs(job.classes) do
            for _, entry in ipairs(list) do
                if not entry.name then unknown = unknown + 1 end
                table.sort(entry.ranks, function(a, b) return a.id < b.id end)
                for _, r in ipairs(entry.ranks) do
                    total = total + 1
                    if not HasText(r) then noText = noText + 1 end
                end
            end
            result.classes[classFile] = list
        end
        result.counts = {spells = total, missingText = noText, unknownBase = unknown, forever = #job.forever}
        DevDB().spellCatalog = result
        self.catalogBusy = false
        ONE:Print(("Fertig: %d Zauber-Ränge aller Klassen, %d davon ohne Beschreibung; %d Forever-Zauber gefunden.")
            :format(total, noText, #job.forever))
        ONE:Print("Zum Speichern jetzt /reload eingeben (oder ausloggen).")
        if onDone then onDone(result) end
    end

    -- 3) Laden, lesen, fehlende Texte nochmal versuchen
    local function Round(list, round)
        self:LoadAll(list, function()
            self:ReadAll(list, function()
                local missing = {}
                for _, item in ipairs(list) do if not HasText(item.d) then missing[#missing + 1] = item end end
                if #missing > 0 and round <= self.catalogRetries then
                    ONE:Print(("Lade %d fehlende Beschreibungen nach …"):format(#missing))
                    Round(missing, round + 1)
                else
                    Finish(round)
                end
            end)
        end)
    end

    -- 2) Namenssuche ueber die Nummernbereiche
    local range, nextId = 1, self.catalogRanges[1][1]
    local function Names()
        local r = self.catalogRanges[range]
        local stop = math.min(r[2], nextId + self.catalogNameChunk - 1)
        for id = nextId, stop do
            local name = SpellName(id)
            if name then
                if id >= self.catalogForeverFrom and #job.forever < self.catalogForeverMax then
                    job.forever[#job.forever + 1] = {id = id, name = name}
                end
                local entries = job.wanted[name]
                if entries then
                    for _, entry in ipairs(entries) do
                        entry.count = (entry.count or 0) + 1
                        if entry.count <= self.catalogMaxPerName or id == entry.base then
                            items[#items + 1] = {id = id, entry = entry, base = id == entry.base}
                        end
                    end
                end
            end
        end
        nextId = stop + 1
        if nextId > r[2] then
            range = range + 1
            if not self.catalogRanges[range] then return Round(items, 1) end
            nextId = self.catalogRanges[range][1]
        end
        Later(0, Names)
    end
    Later(0, Names)
    return true
end

-- /trip zauber kampf: prueft im naechsten Kampf einmal, ob Forever die Daten
-- fuer einen Live-Hinweis hergibt oder sie im Kampf sperrt ("geheime Werte").
function Scan:ArmCombatProbe()
    if not self.probeFrame then
        local ok, frame = pcall(CreateFrame, "Frame")
        if not ok or not frame then return false end
        frame:SetScript("OnEvent", function()
            if not Scan.probeArmed then return end
            Scan.probeArmed = false
            Later(2, function() Scan:CombatProbe() end)
        end)
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self.probeFrame = frame
    end
    self.probeArmed = true
    ONE:Print("Kampf-Prüfung bereit: im nächsten Kampf ein Ziel angreifen (z. B. mit Schattenwort: Schmerz).")
    return true
end

local function Check(v)
    if v == nil then return "nil" end
    if IsSecret(v) then return "GEHEIM" end
    return "OK"
end

function Scan:CombatProbe()
    local out = {time = Call(date, "%Y-%m-%d %H:%M") or "?", inCombat = Plain(Call(InCombatLockdown))}
    local debuff = Call(Path("C_UnitAuras.GetDebuffDataByIndex"), "target", 1)
    out.targetDebuff = type(debuff) == "table" and {
        table = Check(debuff), spellId = Check(debuff.spellId), expiration = Check(debuff.expirationTime),
        source = Check(debuff.sourceUnit), name = Plain(debuff.name)} or "keiner"
    local buff = Call(Path("C_UnitAuras.GetAuraDataByIndex"), "player", 1, "HELPFUL")
    out.playerBuff = type(buff) == "table" and {table = Check(buff), spellId = Check(buff.spellId),
        expiration = Check(buff.expirationTime)} or "keiner"
    local cd = Call(Path("C_Spell.GetSpellCooldown"), 8092)
    out.cooldown = type(cd) == "table" and {table = Check(cd), start = Check(cd.startTime), duration = Check(cd.duration)} or Check(cd)
    out.usable = Check(Call(Path("C_Spell.IsSpellUsable"), 589))
    out.inRange = Check(Call(Path("C_Spell.IsSpellInRange"), 589, "target"))
    out.power = Check(Call(UnitPower, "player", 0))
    out.health = Check(Call(UnitHealth, "target"))
    out.casting = Check(Call(UnitCastingInfo, "player"))
    DevDB().combatProbe = out
    local blocked = false
    local function Scanv(v) if v == "GEHEIM" then blocked = true elseif type(v) == "table" then for _, x in pairs(v) do Scanv(x) end end end
    Scanv(out)
    ONE:Print(blocked and "Kampf-Prüfung: einige Kampfdaten sind gesperrt. Bitte /reload, dann schaue ich es mir an."
        or "Kampf-Prüfung: Kampfdaten sind lesbar. Bitte /reload zum Speichern.")
    return out
end

function Scan:Slash(rest)
    rest = (rest or ""):lower()
    if rest == "alle" or rest == "all" then self:Catalog()
    elseif rest == "kampf" or rest == "combat" then self:ArmCombatProbe()
    else self:Run() end
end

ONE:RegisterSlash("zauber", function(rest) Scan:Slash(rest) end,
    "eigene Zauber erfassen · /trip zauber alle: Zauber aller Klassen · /trip zauber kampf: Kampfdaten prüfen")
