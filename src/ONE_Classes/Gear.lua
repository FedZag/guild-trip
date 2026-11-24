-- Guild Trip: "Besser fuer dich?" im Gegenstands-Tooltip (0.6.6).
-- Bewertet einen Gegenstand nach der Werte-Rangfolge deiner Ausrichtung (build.stats,
-- z. B. Schatten: Willenskraft › Intelligenz › Ausdauer) und vergleicht ihn mit dem, was
-- du im gleichen Platz traegst. Eine Zeile unten im Tooltip, sonst nichts.
-- Nur Spieldaten (GetItemStats), keine Datenbank. Abschaltbar (Optionen › Klasse).
local _, classes = ...
local ONE = _G.ProjectONE
local function T(text, ...) if ONE.T then return ONE.T(text, ...) end if select("#", ...) > 0 then return text:format(...) end return text end

local Gear = {}
classes.Gear = Gear

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- alle Rueckgabewerte durchreichen (nicht nur die ersten paar: online ist bei GetGuildRosterInfo der 9.)
    local r = {pcall(fn, ...)}
    if r[1] then return unpack(r, 2, math.max(2, table.maxn(r))) end return nil
end

-- Wert-Namen der Bauplaene -> Wert-Gruppe
Gear.STAT_OF = {
    ["Intelligenz"] = "int", ["Willenskraft"] = "spi", ["Ausdauer"] = "sta", ["Stärke"] = "str",
    ["Beweglichkeit"] = "agi", ["Zauberschaden"] = "sp", ["Heilung"] = "heal", ["Angriffskraft"] = "ap",
    ["Kritische Treffer"] = "crit", ["Trefferchance"] = "hit", ["Rüstung"] = "armor",
}
-- Spieldaten-Schluessel (GetItemStats) -> Wert-Gruppe (Teilwort genuegt)
Gear.KEYS = {
    {"INTELLECT", "int"}, {"SPIRIT", "spi"}, {"STAMINA", "sta"}, {"STRENGTH", "str"}, {"AGILITY", "agi"},
    {"SPELL_HEALING", "heal"}, {"HEALING", "heal"}, {"SPELL_DAMAGE", "sp"}, {"SPELL_POWER", "sp"},
    {"ATTACK_POWER", "ap"}, {"CRIT", "crit"}, {"HIT", "hit"}, {"RESISTANCE0", "armor"},
    {"DAMAGE_PER_SECOND", "dps"}, {"MANA_REGENERATION", "mp5"}, {"DEFENSE", "def"},
}
-- Grundgewichte je Rolle (kleine Werte fuer alles, was die Rolle sonst noch brauchen kann)
Gear.BASE = {
    caster = {int = .5, spi = .3, sta = .3, sp = .8, mp5 = 1, crit = .5, hit = .5, armor = .01},
    healer = {int = .6, spi = .5, sta = .3, heal = .6, sp = .3, mp5 = 1.2, crit = .3, armor = .01},
    melee = {str = .6, agi = .4, sta = .4, ap = .3, crit = .6, hit = .6, dps = 1.5, armor = .02},
    agile = {agi = .6, str = .3, sta = .4, ap = .3, crit = .6, hit = .6, dps = 1.5, armor = .02},
    hunter = {agi = .6, int = .3, sta = .3, ap = .3, crit = .6, hit = .6, dps = 1, armor = .02},
    tank = {sta = .8, armor = .06, def = 1, str = .4, agi = .4, int = .2, sp = .2, dps = .8},
}
-- Rangfolge aus dem Bauplan: 1. Wert 3, 2. Wert 2, 3. Wert 1.3 (staerker als die Grundgewichte)
Gear.RANK_WEIGHT = {3, 2, 1.3}

function Gear.Weights(build, role)
    local w = {}
    for k, v in pairs(Gear.BASE[role or "caster"] or Gear.BASE.caster) do w[k] = v end
    for i, name in ipairs(build and build.stats or {}) do
        local key = Gear.STAT_OF[name]
        if key then w[key] = math.max(w[key] or 0, Gear.RANK_WEIGHT[i] or 1) end
    end
    -- Zauberer: Intelligenz und Zauberschaden gleich schwer (24.11.2026, Spieltest Magier: +2 Int gegen
    -- +2 Zauberschaden ist praktisch gleichwertig, die Rangfolge allein machte daraus "schlechter")
    if (role or "caster") == "caster" then
        local m = math.max(w.int or 0, w.sp or 0)
        w.int, w.sp = m, m
    end
    return w
end

-- Rueckfall ohne Werte-Abfrage (Forever hat GetItemStats nicht als einfachen Befehl):
-- Werte aus den Tooltip-Zeilen lesen ("+3 Intelligenz", "14 Rüstung", Zauberschaden-Anlegeeffekte)
Gear.TEXT = {
    {"Intelligenz", "int"}, {"Intellect", "int"}, {"Willenskraft", "spi"}, {"Spirit", "spi"},
    {"Ausdauer", "sta"}, {"Stamina", "sta"}, {"Stärke", "str"}, {"Strength", "str"},
    {"Beweglichkeit", "agi"}, {"Agility", "agi"},
}
-- Zeilen eines Tooltips auswerten. Liefert alle Werte und getrennt die der Verzauberung
-- (Zeile vom Typ "dauerhafte Verzauberung" oder mit "Verzaubert:" davor).
function Gear.StatsFromLines(lines)
    local out, enchant = {}, {}
    local enchantType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
    for _, line in ipairs(type(lines) == "table" and lines or {}) do
        local t = type(line) == "table" and line.leftText
        local isEnchant = false
        if type(t) == "string" then
            local stripped = t:match("^Verzaubert:%s*(.+)$") or t:match("^Enchanted:%s*(.+)$")
            if stripped then t, isEnchant = stripped, true end
            if enchantType and line.type == enchantType then isEnchant = true end
        end
        local before = {}
        for k, v in pairs(out) do before[k] = v end
        if type(t) == "string" then
            local n, word = t:match("^%+(%d+)%s+(.+)$")
            if n then
                for _, m in ipairs(Gear.TEXT) do
                    if word:find(m[1], 1, true) then out[m[2]] = (out[m[2]] or 0) + tonumber(n) break end
                end
            end
            local armor = t:match("^(%d+)%s+Rüstung") or t:match("^(%d+)%s+Armor")
            if armor then out.armor = (out.armor or 0) + tonumber(armor) end
            local dps = t:match("%(([%d,%.]+)%s+Schaden pro Sekunde%)") or t:match("%(([%d,%.]+)%s+damage per second%)")
            if dps then out.dps = tonumber((dps:gsub(",", "."))) end
            -- Anlegen: … Heilung … um bis zu N / … Schaden … Zauber … um bis zu N
            local up = t:match("um bis zu (%d+)") or t:match("by up to (%d+)")
            if up and (t:find("Anlegen") or t:find("Equip")) then
                local healing = t:find("Heil") or t:find("heal")
                local damage = t:find("Schaden") or t:find("damage")
                -- "Schaden und Heilung" zaehlt fuer beides
                if healing then out.heal = (out.heal or 0) + tonumber(up) end
                if damage and (t:find("Zauber") or t:find("spell")) then out.sp = (out.sp or 0) + tonumber(up) end
            end
            local crit = t:match("kritische.-um (%d+)%%") or t:match("critical.-by (%d+)%%")
            if crit and (t:find("Anlegen") or t:find("Equip")) then out.crit = (out.crit or 0) + tonumber(crit) * 14 end
            local hit = t:match("Trefferchance.-um (%d+)%%") or t:match("chance to hit.-by (%d+)%%")
            if hit and (t:find("Anlegen") or t:find("Equip")) then out.hit = (out.hit or 0) + tonumber(hit) * 10 end
        end
        if isEnchant then
            for k, v in pairs(out) do
                local add = v - (before[k] or 0)
                if add ~= 0 then enchant[k] = (enchant[k] or 0) + add end
            end
        end
    end
    return out, enchant
end
function Gear.StatsFromTooltip(link)
    local data = Call(C_TooltipInfo and C_TooltipInfo.GetHyperlink, link)
    return (Gear.StatsFromLines(type(data) == "table" and data.lines))
end
-- Getragenes Teil: echter Tooltip des Platzes (mit Verzauberung), sonst ueber den Link
function Gear.WornStats(slot, link)
    local data = Call(C_TooltipInfo and C_TooltipInfo.GetInventoryItem, "player", slot)
    if type(data) == "table" and type(data.lines) == "table" and #data.lines > 0 then
        local all, enchant = Gear.StatsFromLines(data.lines)
        if next(all) then return all, enchant end
    end
    return Gear.Stats(link), {}
end

-- Werte eines Gegenstands als Gruppen {int = 3, sta = 4, ...}
function Gear.Stats(link)
    local raw = Call(C_Item and C_Item.GetItemStats, link) or Call(GetItemStats, link)
    if type(raw) ~= "table" or next(raw) == nil then return Gear.StatsFromTooltip(link) end
    local out = {}
    for key, value in pairs(raw) do
        if type(key) == "string" and type(value) == "number" then
            for _, k in ipairs(Gear.KEYS) do
                if key:find(k[1], 1, true) then out[k[2]] = (out[k[2]] or 0) + value break end
            end
        end
    end
    return out
end
function Gear.Score(stats, weights)
    local s = 0
    for k, v in pairs(stats or {}) do s = s + v * (weights[k] or 0) end
    return s
end

-- Platz(e) am Charakter je Ausruestungsart
Gear.SLOTS = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5},
    INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9}, INVTYPE_HAND = {10},
    INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14}, INVTYPE_CLOAK = {15}, INVTYPE_WEAPON = {16, 17},
    INVTYPE_2HWEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16}, INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17},
    INVTYPE_HOLDABLE = {17}, INVTYPE_RANGED = {18}, INVTYPE_RANGEDRIGHT = {18}, INVTYPE_THROWN = {18},
    INVTYPE_RELIC = {18},
}
-- Ruestungsart, die die Klasse tragen KANN (hoechste) – Ruestung: 1 Stoff, 2 Leder, 3 Kette, 4 Platte
Gear.MAX_ARMOR = {PRIEST = 1, MAGE = 1, WARLOCK = 1, ROGUE = 2, DRUID = 2, HUNTER = 3, SHAMAN = 3, WARRIOR = 4, PALADIN = 4}
Gear.ARMOR_NAMES = {"Stoff", "Leder", "Kette", "Platte"}

-- Waffen-Unterklasse (GetItemInfoInstant) -> Schluessel der Waffenkunde (Weapons.types)
Gear.WEAPON_KEYS = {[0] = "axe1", [1] = "axe2", [2] = "bow", [3] = "gun", [4] = "mace1", [5] = "mace2", [6] = "polearm",
    [7] = "sword1", [8] = "sword2", [10] = "staff", [13] = "fist", [15] = "dagger", [16] = "thrown", [18] = "crossbow", [19] = "wand"}
-- Darf die Klasse die Waffe fuehren, kann sie aber noch nicht? -> Waffenart (Weapons.types-Eintrag) oder nil
function Gear.WeaponToLearn(link, classFile)
    local W = classes.Weapons
    local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or link
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, _, _, classID, subclassID = Call(fn, itemID)
    local key = classID == 2 and Gear.WEAPON_KEYS[subclassID]
    local w = key and W and W.byKey[key]
    if not (w and not w.free and W.byClass[classFile or ""]) then return nil end
    local can = false
    for _, k in ipairs(W.byClass[classFile]) do if k == key then can = true break end end
    if can and W.Known(w) == false then return w end
    return nil
end

-- Ergebnis fuer einen Gegenstand: {verdict = "better"|"worse"|"same"|"new"|"cannot", diff, specName}
function Gear:Judge(link, p, def, build)
    if type(link) ~= "string" then return nil end
    local itemID = tonumber(link:match("item:(%d+)"))
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, equipLoc, _, classID, subclassID = Call(fn, itemID or link)
    local slots = equipLoc and Gear.SLOTS[equipLoc]
    if not slots then return nil end
    -- Ruestung, die die Klasse nicht tragen kann (Schmuck/Umhang zaehlen nicht)
    local maxArmor = Gear.MAX_ARMOR[p.classFile or ""]
    if classID == 4 and maxArmor and subclassID and subclassID >= 1 and subclassID <= 4 and subclassID > maxArmor
        and equipLoc ~= "INVTYPE_CLOAK" then
        return {verdict = "cannot", armor = Gear.ARMOR_NAMES[subclassID]}
    end
    -- Waffe, die die Klasse nie lernen kann (Chat-Ideen 24.11.2026: Gegenstands-Links mit Waffenkunde)
    local wkey = classID == 2 and Gear.WEAPON_KEYS[subclassID]
    local W = classes.Weapons
    if wkey and W and W.byClass[p.classFile or ""] then
        local can = false
        for _, k in ipairs(W.byClass[p.classFile]) do if k == wkey then can = true break end end
        if not can then return {verdict = "cannot", weapon = W.byKey[wkey] and W.byKey[wkey].name or wkey} end
    end
    local role = def.roles and def.roles[p.spec] or "caster"
    local w = Gear.Weights(build, role)
    local newStats = Gear.Stats(link)
    local newScore = Gear.Score(newStats, w)
    -- Vergleich mit dem schlechteren der passenden Plaetze (Ringe, Schmuck, Einhand)
    local oldScore, oldBase, oldStats, worn
    for _, slot in ipairs(slots) do
        local wornLink = Call(GetInventoryItemLink, "player", slot)
        if wornLink then
            worn = true
            if wornLink == link then return nil end -- das angelegte Teil selbst
            -- mit Verzauberung (die geht beim Tausch verloren) und ohne
            local all, enchant = Gear.WornStats(slot, wornLink)
            local sc = Gear.Score(all, w)
            if not oldScore or sc < oldScore then oldScore, oldBase, oldStats = sc, sc - Gear.Score(enchant, w), all end
        else
            oldScore, oldBase, oldStats = 0, 0, {}
        end
    end
    local spec = def.specs and def.specs[p.spec] or ""
    if not worn then return {verdict = newScore > 0 and "new" or "same", diff = newScore, spec = spec} end
    local function Verdict(old)
        local diff = newScore - (old or 0)
        local tolerance = math.max(.5, math.abs(old or 0) * .05)
        return diff > tolerance and "better" or diff < -tolerance and "worse" or "same", diff
    end
    local verdict, diff = Verdict(oldScore)
    local baseVerdict = Verdict(oldBase)
    local hasEnchant = oldBase and oldScore and math.abs(oldScore - oldBase) > .01
    return {verdict = verdict, diff = diff, old = oldScore, spec = spec, hasEnchant = hasEnchant,
        reasons = Gear.Reasons(newStats, oldStats or {}, w), rank = Gear.Ranks(build),
        -- nur wegen der Verzauberung schlechter: ohne sie waere das neue Teil besser/gleich
        enchantFlip = hasEnchant and verdict == "worse" and baseVerdict ~= "worse"}
end

-- Warum? Die Wert-Unterschiede (neu minus getragen), sortiert nach Gewicht fuer die Ausrichtung
Gear.NAMES = {int = "Intelligenz", spi = "Willenskraft", sta = "Ausdauer", str = "Stärke", agi = "Beweglichkeit",
    sp = "Zauberschaden", heal = "Heilung", ap = "Angriffskraft", crit = "Krit", hit = "Treffer", armor = "Rüstung",
    dps = "Waffenschaden pro Sek.", mp5 = "Mana alle 5 Sek.", def = "Verteidigung"}
function Gear.Reasons(new, old, w)
    local keys, out = {}, {}
    for k in pairs(new) do keys[k] = true end
    for k in pairs(old) do keys[k] = true end
    for k in pairs(keys) do
        local d = (new[k] or 0) - (old[k] or 0)
        if math.abs(d) > .001 and (w[k] or 0) > 0 then out[#out + 1] = {key = k, delta = d, weight = math.abs(d) * w[k]} end
    end
    table.sort(out, function(a, b) return a.weight > b.weight end)
    return out
end
-- Platz eines Werts in der Rangfolge der Ausrichtung (1 = wichtigster)
function Gear.Ranks(build)
    local out = {}
    for i, name in ipairs(build and build.stats or {}) do
        local key = Gear.STAT_OF[name]
        if key and not out[key] then out[key] = i end
    end
    return out
end
-- Der entscheidende Grund in Worten: "+4 Willenskraft (dein wichtigster Wert)"
function Gear.MainReason(r)
    local e = r and r.reasons and r.reasons[1]
    if not e then return nil end
    -- passend zum Urteil: bei "besser" der wichtigste Gewinn, bei "schlechter" der wichtigste Verlust
    for _, x in ipairs(r.reasons) do
        if (r.verdict == "better" and x.delta > 0) or (r.verdict == "worse" and x.delta < 0) then e = x break end
    end
    local text = Gear.DeltaText(e)
    local rank = r.rank and r.rank[e.key]
    if rank == 1 then text = text .. " " .. T("(dein wichtigster Wert)")
    elseif rank then text = text .. " " .. T("(dein Wert Nr. %d)", rank) end
    -- Gegenposten mit nennen (Verlust bei "besser", Gewinn bei "schlechter"), damit die Zeile nicht einseitig ist
    for _, x in ipairs(r.reasons) do
        if x ~= e and (x.delta > 0) ~= (e.delta > 0) then text = text .. ", " .. Gear.DeltaText(x) break end
    end
    return text
end
-- "+2 Zauberschaden" / "−2 Intelligenz"
function Gear.DeltaText(e)
    local n = math.floor(math.abs(e.delta) * 10 + .5) / 10
    return (e.delta > 0 and "+" or "−") .. (n == math.floor(n) and string.format("%d", n) or tostring(n)) .. " " .. T(Gear.NAMES[e.key] or e.key)
end
function Gear.ReasonLine(r, max)
    if not (r and r.reasons and #r.reasons > 0) then return nil end
    local parts = {}
    for i, e in ipairs(r.reasons) do
        if i > (max or 4) then break end
        local n = math.floor(math.abs(e.delta) * 10 + .5) / 10
        local text = (e.delta > 0 and "+" or "−") .. (n == math.floor(n) and string.format("%d", n) or tostring(n)) .. " " .. T(Gear.NAMES[e.key] or e.key)
        parts[#parts + 1] = (e.delta > 0 and "|cff40ff40" or "|cffff5050") .. text .. "|r"
    end
    return "|cffbbbbbb" .. T("Warum:") .. "|r " .. table.concat(parts, " · ")
        .. (r.hasEnchant and ("|cff9d9d9d " .. T("(inkl. deiner Verzauberung)") .. "|r") or "")
end

function Gear:Line(r)
    if not r then return nil end
    local spec = r.spec and r.spec ~= "" and (" (" .. T(r.spec) .. ")") or ""
    if r.enchantFlip then
        return "|cffffd100" .. T("Guild Trip: schlechter – nur wegen deiner Verzauberung (neu verzaubern lohnt sich)") .. "|r"
    end
    -- eine Zeile: Urteil + entscheidender Grund (die Einzelwerte zeigt WoW schon selbst)
    local why = Gear.MainReason(r)
    why = why and (" – " .. why) or spec
    if r.verdict == "better" then
        return "|cff40ff40" .. T("Guild Trip: besser für dich") .. why .. "|r"
            .. (r.hasEnchant and ("|cff9d9d9d " .. T("(deine Verzauberung geht verloren)") .. "|r") or "")
    end
    if r.verdict == "worse" then return "|cffff5050" .. T("Guild Trip: schlechter für dich") .. why .. "|r" end
    if r.verdict == "new" then return "|cff40ff40" .. T("Guild Trip: passt zu dir – der Platz ist noch frei") .. "|r" end
    if r.verdict == "cannot" and r.weapon then return "|cff9d9d9d" .. T("Guild Trip: %s kann deine Klasse nicht führen", T(r.weapon)) .. "|r" end
    if r.verdict == "cannot" then return "|cff9d9d9d" .. T("Guild Trip: %s kann deine Klasse nicht tragen", T(r.armor or "")) .. "|r" end
    -- etwa gleich, aber andere Werte: Gewinn und Verlust nebeneinander ("−2 Intelligenz, +2 Zauberschaden")
    if r.verdict == "same" and why ~= spec then
        return "|cffbbbbbb" .. T("Guild Trip: etwa gleich gut für dich") .. why .. "|r"
    end
    return "|cffbbbbbb" .. T("Guild Trip: etwa gleich gut für dich") .. spec .. "|r"
end

-- Quest-Fuehrung (ONE_Leveling): Verbesserung in Prozent fuer einen Gegenstand (nil = unbekannt/kein Upgrade).
-- Noch nicht geladene Gegenstaende werden beim Server angefragt; beim naechsten Planen sind sie da.
function Gear:UpgradePercent(itemID)
    if type(itemID) ~= "number" then return nil end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, equipLoc = Call(fn, itemID)
    if not (equipLoc and Gear.SLOTS[equipLoc]) then return nil end
    if C_Item and C_Item.IsItemDataCachedByID and not Call(C_Item.IsItemDataCachedByID, itemID) then
        Call(C_Item.RequestLoadItemDataByID, itemID)
        return nil
    end
    local store = ONE.db and ONE.db.classGuide or {}
    local p = classes.Player:Read(store.spec)
    local def = classes.Data.classes[p.classFile or ""]
    if not def then return nil end
    local r = self:Judge("item:" .. itemID, p, def, classes.Data:Build(def, p.spec, p.situation))
    if not r then return nil end
    if r.verdict == "new" then return 100 end
    if r.verdict ~= "better" then return 0 end
    return math.floor((r.diff or 0) / math.max(1, r.old or 0) * 100 + .5)
end

function Gear:OnTooltip(tooltip)
    if ONE.FeatureOn and not ONE:FeatureOn("classes.gear") then return end
    if not (tooltip and tooltip.GetItem and tooltip.AddLine) then return end
    local _, link = tooltip:GetItem()
    if not link then return end
    local store = ONE.db and ONE.db.classGuide or {}
    local p = classes.Player:Read(store.spec)
    local def = classes.Data.classes[p.classFile or ""]
    if not def then return end
    local build = classes.Data:Build(def, p.spec, p.situation)
    local r = self:Judge(link, p, def, build)
    local line = self:Line(r)
    if line then tooltip:AddLine(line, 1, 1, 1, true) end
    -- Waffe, die du noch beim Waffenmeister lernen musst (mit dem naechsten Lehrer)
    local learn = Gear.WeaponToLearn(link, p.classFile)
    if learn then
        local W = classes.Weapons
        local trainer = W.BestTrainer and W:BestTrainer(learn.key)
        local text = trainer and T("Guild Trip: %s musst du erst lernen – Waffenmeister %s", T(learn.name), trainer.npc)
            or T("Guild Trip: %s musst du erst beim Waffenmeister lernen", T(learn.name))
        tooltip:AddLine("|cffffd100" .. text .. "|r", 1, 1, 1, true)
        line = line or text
    end
    -- Fundort aus gesammelter Beute (eigene Funde, Gilde, Startpaket)
    local itemID = tonumber(link:match("item:(%d+)"))
    local src = itemID and classes.Loot and (not ONE.FeatureOn or ONE:FeatureOn("classes.loot")) and classes.Loot:SourceText(itemID)
    if src then tooltip:AddLine("|cffbbbbbb" .. src .. "|r", 1, 1, 1, true) end
    if line or src then tooltip:Show() end
end

function Gear:Initialize()
    local function Hook(tt) pcall(function() Gear:OnTooltip(tt) end) end
    -- neuer Weg (moderner Client), sonst alter Tooltip-Haken
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
            if tt == GameTooltip or tt == ItemRefTooltip then Hook(tt) end
        end)
    else
        for _, tt in ipairs({GameTooltip, ItemRefTooltip}) do
            if tt and tt.HookScript then tt:HookScript("OnTooltipSetItem", Hook) end
        end
    end
end
