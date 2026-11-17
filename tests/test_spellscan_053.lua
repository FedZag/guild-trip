-- Offline-Test 0.5.3: /trip zauber – Zauberbuch, Talente, Tooltips, Werte erfassen.
local root = arg[1] or "src"
local ONE = {version = "test", db = {}}
local printed, slash = {}, {}
function ONE:Print(m) printed[#printed + 1] = m end
function ONE:RegisterSlash(name, fn) slash[name] = fn; return true end
date = os.date
GetBuildInfo = function() return "1.60.1", "123", "Nov 1 2026", 16001 end
GetLocale = function() return "deDE" end
UnitClass = function() return "Priester", "PRIEST" end
UnitRace = function() return "Untoter" end
UnitLevel = function() return 24 end
UnitHealthMax = function() return 800 end
UnitPowerMax = function() return 900 end
UnitStat = function(_, i) return 10 * i, 10 * i end
GetSpellBonusDamage = function(i) return i == 6 and 12 or 0 end
InCombatLockdown = function() return false end

local spells = {
    [589] = {name = "Schattenwort: Schmerz", rank = "Rang 3", desc = "Verursacht 66 Schattenschaden über 18 Sek.", cost = 50},
    [8092] = {name = "Gedankenschlag", rank = "Rang 2", desc = "", cost = 70},
}
GetSpellInfo = function(id) local s = spells[id]; if s then return s.name, s.rank, 136207, 1500, 0, 30 end end
GetSpellDescription = function(id) return spells[id] and spells[id].desc end
GetSpellPowerCost = function(id) return {{type = 0, name = "MANA", cost = spells[id].cost}} end
GetSpellBaseCooldown = function(id) return id == 8092 and 8000 or 0 end

-- Unsichtbarer Tooltip (alter Weg)
local tipLines = {}
local frames = {}
CreateFrame = function(kind, name)
    if kind == "Frame" then
        local f = {events = {}}
        function f:SetScript(_, fn) self.onEvent = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        frames[#frames + 1] = f
        return f
    end
    assert(kind == "GameTooltip" and name == "GuildTripScanTip")
    local tip = {}
    function tip:SetOwner() end
    function tip:ClearLines() tipLines = {} end
    function tip:SetSpellByID(id) tipLines = {spells[id].name, "Kosten " .. spells[id].cost .. " Mana"} end
    function tip:SetTalent(t, i) tipLines = {"Talent " .. t .. "-" .. i, "Rang 1/5"} end
    function tip:NumLines() return #tipLines end
    for i = 1, 5 do
        _G["GuildTripScanTipTextLeft" .. i] = {GetText = function() return tipLines[i] end}
        _G["GuildTripScanTipTextRight" .. i] = {GetText = function() return nil end}
    end
    return tip
end

-- 1) Alte Zauberbuch-API (Classic)
GetNumSpellTabs = function() return 2 end
GetSpellTabInfo = function(t) if t == 1 then return "Allgemein", 1, 0, 0 end return "Schatten", 2, 0, 2 end
local ids = {589, 8092}
GetSpellBookItemInfo = function(i) return "SPELL", ids[i] end
GetSpellBookItemName = function(i) return spells[ids[i]].name, spells[ids[i]].rank end
GetNumTalentTabs = function() return 3 end
GetTalentTabInfo = function(t) return ({"Disziplin", "Heilig", "Schatten"})[t], 1, t == 3 and 15 or 0 end
GetNumTalents = function(t) return t == 3 and 2 or 1 end
GetTalentInfo = function(t, i) return "Talent" .. i, 1, 1, i, t == 3 and 5 or 0, 5 end

assert(loadfile(root .. "/ONE_Dev/SpellScan.lua"))("ONE_Dev", ONE)
assert(type(slash.zauber) == "function", "Befehl registriert")
slash.zauber("")
local r = ONE.db.spellScan.PRIEST
assert(r and r.class == "Priester" and r.spellbookApi == "GetSpellTabInfo", "alte API genutzt")
assert(#r.spellbook == 2 and #r.spellbook[2].spells == 2, "Reiter und Zauber")
local swp = r.spellbook[2].spells[1]
assert(swp.id == 589 and swp.name == "Schattenwort: Schmerz" and swp.rank == "Rang 3" and swp.castTime == 1500)
assert(swp.cost[1].cost == 50 and swp.description:find("66"), "Kosten und Beschreibung")
assert(swp.tooltip[2] == "Kosten 50 Mana", "Tooltip-Zeilen")
assert(r.spellbook[2].spells[2].baseCooldown == 8000)
assert(#r.talents == 3 and #r.talents[3].talents == 2 and r.talents[3].talents[1].raw[5] == 5, "Talente roh")
assert(r.talents[3].talents[2].tooltip[1] == "Talent 3-2", "Talent-Tooltip")
assert(r.stats.level == 24 and r.stats.mana == 900 and r.stats.schools[6] == 12 and r.stats.stats[5][1] == 50)
assert(r.counts.spells == 2 and r.counts.talents == 4 and r.counts.missingText == 1, "Zaehler (Gedankenschlag ohne Text)")
assert(r.apis.GetTalentInfo == true and r.apis.UnitCastingInfo == false, "API-Pruefung")
assert(printed[#printed]:find("/reload"), "Hinweis zum Speichern")

-- 2) Neue API (C_SpellBook / C_Spell / C_TooltipInfo) hat Vorrang
Enum = {SpellBookSpellBank = {Player = 0}}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {name = "Schatten", iconID = 2, itemIndexOffset = 0, numSpellBookItems = 1} end,
    GetSpellBookItemInfo = function() return {spellID = 8092, name = "Gedankenschlag", subName = "Rang 2", itemType = 1} end,
}
C_Spell = {GetSpellInfo = function(id) return {name = "Gedankenschlag", iconID = 9, castTime = 1500, minRange = 0, maxRange = 30} end}
C_TooltipInfo = {GetSpellByID = function() return {lines = {{leftText = "Gedankenschlag", rightText = "Rang 2"}, {leftText = "Verursacht 80 Schaden"}}} end}
slash.zauber("")
r = ONE.db.spellScan.PRIEST
assert(r.spellbookApi == "C_SpellBook" and r.spellbook[1].spells[1].bookRank == "Rang 2")
assert(r.spellbook[1].spells[1].tooltip[1] == "Gedankenschlag | Rang 2", "C_TooltipInfo genutzt")

-- 3) Fehlende Beschreibung wird gemeldet; im Kampf nichts tun
C_TooltipInfo = nil
spells[8092].desc = ""
tipLines = {}
local tip = ONE.SpellScan.tip
tip.SetSpellByID = function() tipLines = {} end
slash.zauber("")
assert(ONE.db.spellScan.PRIEST.counts.missingText == 1)
local found = false
for _, m in ipairs(printed) do if m:find("Beschreibungen fehlen") then found = true end end
assert(found, "Hinweis auf fehlende Texte")
InCombatLockdown = function() return true end
local before = #printed
assert(ONE.SpellScan:Run() == nil and printed[#printed]:find("nach dem Kampf") and #printed == before + 1)

-- 4) /trip zauber alle: Raenge aller Klassen ueber den Namen finden
InCombatLockdown = function() return false end
C_Spell, C_SpellBook, Enum = nil, nil, nil
local world = {
    [10] = {name = "Feuerball", rank = "Rang 1", desc = "Feuer 15"},
    [11] = {name = "Feuerball", rank = "Rang 2", desc = "Feuer 30"},
    [12] = {name = "Frostblitz", rank = "Rang 1", desc = ""},
    [20] = {name = "Schattenwort: Schmerz", rank = "Rang 1", desc = "Schatten 30"},
    [21] = {name = "Schattenwort: Schmerz", rank = "Rang 2", desc = "Schatten 60"},
    [30] = {name = "Anderes", rank = "", desc = "x"},
    [101] = {name = "Dunkles Opfer", rank = "", desc = "neu"},
    [102] = {name = "Feuerball", rank = "Rang 3", desc = "Feuer 45"},
}
spells = world
GetSpellInfo = function(id) local w = world[id]; if w then return w.name, w.rank, 1, 1500, 0, 30 end end
GetSpellPowerCost = function() return {{type = 0, name = "MANA", cost = 10}} end
local loaded = {}
C_Spell = {RequestLoadSpellData = function(id)
    loaded[#loaded + 1] = id
    if id == 12 then world[12].loads = (world[12].loads or 0) + 1; if world[12].loads >= 2 then world[12].desc = "Frost 20" end end
end}
local queue = {}
C_Timer = {After = function(delay, fn) queue[#queue + 1] = {delay = delay, fn = fn} end}
tip.SetSpellByID = function(_, id) tipLines = {world[id].name, "Tooltip " .. id} end
ONE.ClassSpells = {MAGE = {10, 12, 99}, PRIEST = {20}}
local S = ONE.SpellScan
S.catalogRanges, S.catalogForeverFrom, S.catalogNameChunk, S.catalogDetailChunk, S.catalogLoadBatch = {{1, 40}, {100, 105}}, 100, 15, 2, 4
local done
assert(S:Catalog(function(r) done = r end))
assert(not S:Catalog(), "kein zweiter Lauf gleichzeitig")
local steps, sawWait = 0, false
while #queue > 0 do
    local job = table.remove(queue, 1)
    if job.delay == S.catalogWait then sawWait = true end
    job.fn(); steps = steps + 1
end
assert(sawWait and steps > 4, "in Haeppchen und mit Wartezeit")
assert(done and ONE.db.spellCatalog == done and not S.catalogBusy)
local mage = done.classes.MAGE
assert(mage[1].name == "Feuerball" and #mage[1].ranks == 3 and mage[1].ranks[2].description == "Feuer 30", "Raenge per Name")
assert(mage[1].ranks[1].tooltip and mage[1].ranks[1].tooltip[2] == "Tooltip 10", "Startnummer mit Tooltip")
assert(mage[1].ranks[2].tooltip == nil, "weitere Raenge kompakt")
assert(mage[2].ranks[1].tooltip[2] == "Tooltip 12", "ohne Beschreibung: Tooltip als Ersatz")
assert(mage[3].name == nil and #mage[3].ranks == 0, "unbekannte Startnummer")
assert(#done.classes.PRIEST[1].ranks == 2)
assert(done.counts.spells == 6 and done.counts.unknownBase == 1 and done.counts.missingText == 0, "Zaehler Katalog")
assert(mage[1].ranks[3].id == 102, "Rang im Forever-Bereich gefunden")
assert(done.counts.forever == 2 and done.forever[1].name == "Dunkles Opfer", "Forever-Zauber gemerkt")
assert(mage[2].ranks[1].description == "Frost 20" and done.rounds == 2, "fehlender Text beim zweiten Versuch")
assert(#loaded == 7, "Texte angefordert (6 + 1 Nachladen)")
assert(printed[#printed]:find("/reload"))
S:Slash("alle"); assert(S.catalogBusy, "Befehl startet Suche")

-- 4b) Neues Talentsystem (C_Traits), wenn die alte Talent-API fehlt
GetNumTalentTabs = nil
C_ClassTalents = {GetActiveConfigID = function() return 7 end}
C_Traits = {
    GetConfigInfo = function() return {treeIDs = {300}} end,
    GetTreeNodes = function() return {1, 2} end,
    GetNodeInfo = function(_, node) return {entryIDs = {node * 10}, ranksPurchased = node - 1, maxRanks = 2, posX = node, posY = 0,
        activeEntry = {entryID = node * 10}} end,
    GetEntryInfo = function(_, entry) return {definitionID = entry + 1} end,
    GetDefinitionInfo = function(def) return {spellID = def == 11 and 20 or 21} end,
}
local trees = ONE.SpellScan:Talents()
assert(#trees == 1 and trees[1].api == "C_Traits" and #trees[1].talents == 2, "C_Traits-Baum")
local t2 = trees[1].talents[2]
assert(t2.spell == 21 and t2.name == "Schattenwort: Schmerz" and t2.ranks == 1 and t2.maxRanks == 2 and t2.active == true)

-- 5) Kampf-Pruefung
S.catalogBusy = false
issecretvalue = function(v) return v == "geheim" end
C_UnitAuras = {GetDebuffDataByIndex = function() return {spellId = "geheim", expirationTime = 10, name = "Schmerz"} end,
    GetAuraDataByIndex = function() return nil end}
C_Spell.GetSpellCooldown = function() return {startTime = 1, duration = 0} end
UnitPower = function() return 100 end
queue = {}
S:Slash("kampf")
local probe = frames[#frames]
assert(probe and probe.events.PLAYER_REGEN_DISABLED and S.probeArmed)
probe.onEvent(probe, "PLAYER_REGEN_DISABLED")
assert(not S.probeArmed and #queue == 1)
table.remove(queue, 1).fn()
local cp = ONE.db.combatProbe
assert(cp.targetDebuff.spellId == "GEHEIM" and cp.targetDebuff.expiration == "OK" and cp.playerBuff == "keiner")
assert(cp.cooldown.duration == "OK" and cp.power == "OK" and printed[#printed]:find("gesperrt"), "geheime Werte erkannt")
print("OK test_spellscan_053")
